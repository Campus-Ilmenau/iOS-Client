import SwiftUI
import Observation
import OSLog
import WatchConnectivity

private nonisolated let protokoll = Logger(subsystem: "de.kai-gothe.Campus-Ilmenau", category: "Watch")

extension UhrEinstellungen {
    /// Der aktuelle Stand auf dem iPhone: Mensa der Startseite und Preisgruppe aus der App Group, dazu Filter und gemerkte
    /// Veranstaltungen.
    static func aktuell(defaults: UserDefaults = AppGroup.defaults) -> UhrEinstellungen {
        UhrEinstellungen(
            mensa: defaults.string(forKey: AppGroup.heuteMensaSchluessel).flatMap(MensaVenue.init(rawValue:)) ?? .mensaEhrenberg,
            preisgruppe: defaults.string(forKey: AppGroup.preisgruppeSchluessel).flatMap(MensaPriceGroup.init(rawValue:)) ?? .studierende,
            filter: MensaFilterStore.load(defaults: defaults),
            gemerkteEvents: Array(EventsMerkStore.shared.ids)
        )
    }
}

extension UhrKontext {
    /// Der aktuelle Stand auf dem iPhone: Einstellungen und die ganze Merkliste (ID, Titel, `foundAt`, `changedAt`).
    static func aktuell(defaults: UserDefaults = AppGroup.defaults, merkliste: BibMerklisteStore = .shared) -> UhrKontext {
        UhrKontext(
            einstellungen: .aktuell(defaults: defaults),
            merkliste: merkliste.eintraege.map {
                UhrMerklisteEintrag(id: $0.id, titel: $0.anzeigeTitel, foundAt: $0.foundAt, changedAt: $0.changedAt)
            }
        )
    }
}

/// Die Verbindung des iPhones zur Apple Watch (`WCSession`).
///
/// - iPhone → Uhr: Einstellungen und die ganze Merkliste per `updateApplicationContext` bei jeder Änderung; auf Nachfrage
///   (`sendMessage`) die Antwort mit demselben Stand.
/// - Uhr → iPhone: Änderungen `{id, found, changedAt}` per `transferUserInfo`. Sie gehen durch `BibMerklisteStore.uebernimm`
///   (Konfliktregel in `MerklisteAbgleich`); danach schickt das iPhone den neuen Stand an die Uhr.
/// - Sagt, ob eine Uhr gekoppelt und die Watch-App installiert ist.
///
/// Keine Konto- oder Bibliotheksdaten: Der Bibliotheks-Token bleibt im Speicher des iPhones.
@Observable
final class WatchVerbindung: NSObject, WCSessionDelegate {
    static let shared = WatchVerbindung()

    /// Eine Uhr ist mit diesem iPhone gekoppelt (`isPaired`).
    private(set) var istGekoppelt = false
    /// Die Watch-App ist auf der gekoppelten Uhr installiert (`isWatchAppInstalled`).
    private(set) var istWatchAppInstalliert = false

    /// Gekoppelt und Watch-App installiert. Davon hängt später der Wortlaut der Fußnote in der Merkliste ab.
    var istWatchBereit: Bool { istGekoppelt && istWatchAppInstalliert }

    /// Zuletzt geschickter Stand, damit gleiche Werte nicht noch einmal übertragen werden.
    @ObservationIgnored private var zuletztGesendet: UhrKontext?
    @ObservationIgnored private var beobachter: Task<Void, Never>?

    /// Aktiviert die Sitzung (einmal beim Start der App) und schickt künftig jede Änderung der Einstellungen.
    func starten() {
        guard WCSession.isSupported(), beobachter == nil else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()

        // Mensa, Preisgruppe und Filter liegen alle in der App Group; jede Änderung dort meldet diese Mitteilung.
        beobachter = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: UserDefaults.didChangeNotification) {
                self?.sendeEinstellungen()
            }
        }
        beobachteMerkliste()
    }

    /// Jede Änderung der Merkliste (Merken, Entfernen, Abhaken, Änderung von der Uhr) geht an die Uhr.
    private func beobachteMerkliste() {
        withObservationTracking {
            _ = BibMerklisteStore.shared.eintraege
        } onChange: { [weak self] in
            // `onChange` kommt vor der Änderung; erst danach den neuen Stand lesen.
            Task { @MainActor in
                self?.sendeEinstellungen()
                self?.beobachteMerkliste()
            }
        }
    }

    /// Schickt den aktuellen Stand (Einstellungen und Merkliste), wenn eine Uhr bereit ist und er sich seit dem letzten Mal
    /// geändert hat.
    func sendeEinstellungen() {
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        let aktuell = UhrKontext.aktuell()
        guard aktuell != zuletztGesendet else { return }
        do {
            try session.updateApplicationContext(aktuell.kontext)
            zuletztGesendet = aktuell
        } catch {
            // Wird beim nächsten Ändern oder beim nächsten Kopplungswechsel erneut versucht.
        }
    }

    private func uebernimmZustand(gekoppelt: Bool, installiert: Bool) {
        istGekoppelt = gekoppelt
        istWatchAppInstalliert = installiert
        // Eine frisch installierte Watch-App oder neue Uhr hat noch nichts bekommen.
        zuletztGesendet = nil
        sendeEinstellungen()
    }

    // MARK: - WCSessionDelegate (Aufrufe kommen nicht auf dem Main-Thread)

    nonisolated func session(
        _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?
    ) {
        let gekoppelt = session.isPaired, installiert = session.isWatchAppInstalled
        Task { @MainActor in uebernimmZustand(gekoppelt: gekoppelt, installiert: installiert) }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        let gekoppelt = session.isPaired, installiert = session.isWatchAppInstalled
        Task { @MainActor in uebernimmZustand(gekoppelt: gekoppelt, installiert: installiert) }
    }

    /// Eine Änderung der Uhr anwenden, dann den neuen Stand zurückschicken. Die Liste zeigt es sofort, ohne Hinweis.
    /// Die Uhr schickt jede Änderung auf zwei Wegen (`sendMessage` und `transferUserInfo`); die zweite Zustellung ist
    /// ein Duplikat und ändert nichts.
    private func wende(_ aenderung: UhrAenderung, weg: String) {
        let entscheidung = withAnimation { BibMerklisteStore.shared.uebernimm(aenderung) }
        protokoll.info("Änderung der Uhr (\(weg, privacy: .public)) für \(aenderung.id, privacy: .public), gefunden \(aenderung.found): \(String(describing: entscheidung), privacy: .public)")
        // Auch bei verworfenen Änderungen: Die Uhr soll den Stand des iPhones bekommen.
        zuletztGesendet = nil
        sendeEinstellungen()
    }

    /// Änderungen der Uhr, die über `transferUserInfo` kommen (werden auch später zugestellt).
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let aenderung = UhrAenderung(kontext: userInfo) else {
            protokoll.error("userInfo der Uhr nicht lesbar: \(userInfo.keys.sorted().joined(separator: ","), privacy: .public)")
            return
        }
        Task { @MainActor in wende(aenderung, weg: "transferUserInfo") }
    }

    /// Nachrichten der Uhr: eine Änderung (sofort, wenn die Uhr das iPhone erreicht) oder die Frage nach dem Stand beim
    /// Öffnen. Die Antwort ist immer der aktuelle Stand.
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        let aenderung = UhrAenderung(kontext: message)
        Task { @MainActor in
            if let aenderung { wende(aenderung, weg: "sendMessage") } else { protokoll.info("Nachfrage der Uhr nach dem Stand") }
            replyHandler(UhrKontext.aktuell().kontext)
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Bei einem Wechsel der Uhr beginnt eine neue Sitzung.
        session.activate()
    }
}
