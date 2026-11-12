import Foundation
import Observation
import OSLog
import WatchConnectivity

private nonisolated let protokoll = Logger(subsystem: "de.kai-gothe.Campus-Ilmenau", category: "Watch")

/// Die Verbindung der Uhr zum iPhone (`WCSession`). Nimmt Mensa der Startseite, Preisgruppe und Filter entgegen,
/// legt den letzten Stand in der eigenen App Group der Uhr ab und fällt ohne Daten auf Ehrenberg, Studierende und
/// keinen Filter zurück (`UhrEinstellungen.vorgabe`).
@Observable
final class UhrVerbindung: NSObject, WCSessionDelegate {
    static let shared = UhrVerbindung()

    /// Die Einstellungen des iPhones, sonst die Vorgabe.
    private(set) var einstellungen: UhrEinstellungen
    /// Das iPhone ist gerade erreichbar (`isReachable`). Ohne Verbindung geht das Abhaken trotzdem; die Änderungen warten.
    private(set) var iPhoneErreichbar = false
    let merkliste: UhrMerkliste

    @ObservationIgnored private let defaults: UserDefaults
    /// Änderungen, die vor der Aktivierung der Sitzung entstanden sind.
    @ObservationIgnored private var wartend: [UhrAenderung] = []

    /// - Parameter defaults: Speicher des letzten Stands, Vorgabe ist die App Group der Uhr (`AppGroup.defaults` auf watchOS).
    init(defaults: UserDefaults = AppGroup.defaults, merkliste: UhrMerkliste? = nil) {
        self.defaults = defaults
        let merkliste = merkliste ?? UhrMerkliste.shared
        self.merkliste = merkliste
        einstellungen = defaults.dictionary(forKey: UhrEinstellungen.speicherSchluessel)
            .flatMap(UhrEinstellungen.init(kontext:)) ?? .vorgabe
        super.init()
        merkliste.sender = { [weak self] in self?.sende($0) }
    }

    /// Für Previews: feste Einstellungen, nichts wird gespeichert.
    init(vorschau einstellungen: UhrEinstellungen, merkliste: UhrMerkliste, iPhoneErreichbar: Bool = true) {
        defaults = UserDefaults(suiteName: "uhr-vorschau-\(UUID().uuidString)") ?? .standard
        self.einstellungen = einstellungen
        self.merkliste = merkliste
        self.iPhoneErreichbar = iPhoneErreichbar
        super.init()
    }

    /// Aktiviert die Sitzung, einmal beim Start der App.
    func starten() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    private func uebernimm(_ kontext: UhrKontext?) {
        // Ein leerer Kontext heißt „noch nichts vom iPhone“: der letzte Stand bleibt.
        guard let kontext else { return }
        if kontext.einstellungen != einstellungen {
            einstellungen = kontext.einstellungen
            defaults.set(kontext.einstellungen.kontext, forKey: UhrEinstellungen.speicherSchluessel)
        }
        if let liste = kontext.merkliste { merkliste.uebernimm(vomIPhone: liste) }
    }

    /// Eine Änderung an das iPhone, auf zwei Wegen: `transferUserInfo` wird zugestellt, sobald das iPhone erreichbar ist,
    /// auch später und auch ohne Verbindung. Ist das iPhone gerade erreichbar, geht sie zusätzlich sofort per
    /// `sendMessage`; die Antwort bringt den neuen Stand. Die doppelte Zustellung ändert auf dem iPhone nichts
    /// (`MerklisteAbgleich`: Duplikat).
    private func sende(_ aenderung: UhrAenderung) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else {
            protokoll.info("Sitzung noch nicht aktiv, Änderung für \(aenderung.id, privacy: .public) wartet")
            wartend.append(aenderung)
            return
        }
        let session = WCSession.default
        session.transferUserInfo(aenderung.kontext)
        protokoll.info("transferUserInfo für \(aenderung.id, privacy: .public), offen: \(session.outstandingUserInfoTransfers.count), erreichbar: \(session.isReachable)")
        if session.isReachable {
            session.sendMessage(aenderung.kontext, replyHandler: { [weak self] antwort in
                let kontext = UhrKontext(kontext: antwort)
                Task { @MainActor in self?.uebernimm(kontext) }
            }, errorHandler: { fehler in
                protokoll.error("sendMessage fehlgeschlagen: \(fehler.localizedDescription, privacy: .public)")
            })
        }
    }

    /// Beim Öffnen: das iPhone nach dem aktuellen Stand fragen, wenn es erreichbar ist. Sonst gilt der letzte Stand.
    func frageNachMerkliste() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated, WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["frage": "merkliste"], replyHandler: { [weak self] antwort in
            let kontext = UhrKontext(kontext: antwort)
            Task { @MainActor in self?.uebernimm(kontext) }
        }, errorHandler: nil)
    }

    // MARK: - WCSessionDelegate (Aufrufe kommen nicht auf dem Main-Thread)

    nonisolated func session(
        _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?
    ) {
        // Das System hält den zuletzt empfangenen Kontext auch über Neustarts der Uhr-App.
        let empfangen = UhrKontext(kontext: session.receivedApplicationContext)
        let erreichbar = session.isReachable
        Task { @MainActor in
            uebernimm(empfangen)
            iPhoneErreichbar = erreichbar
            // Änderungen aus der Zeit vor der Aktivierung gehen jetzt los.
            let offen = wartend
            wartend = []
            offen.forEach(sende)
            frageNachMerkliste()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let empfangen = UhrKontext(kontext: applicationContext)
        Task { @MainActor in uebernimm(empfangen) }
    }

    nonisolated func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        if let error {
            protokoll.error("transferUserInfo fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
        } else {
            protokoll.info("transferUserInfo zugestellt")
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let erreichbar = session.isReachable
        Task { @MainActor in iPhoneErreichbar = erreichbar }
    }
}
