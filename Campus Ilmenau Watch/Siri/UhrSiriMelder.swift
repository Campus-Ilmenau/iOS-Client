import Foundation

/// Die Meldungen der Watch-App an Siri (Donations), mit denselben Regeln wie auf dem iPhone (`SiriMelder`): höchstens
/// einmal pro Ansicht und Öffnen, nichts, was gerade von außen kam (Siri-Button, Komplikation, Smart Stack, Vorschlag).
@MainActor
enum UhrSiriMelder {
    static let gemeinsam = SiriMelder()

    /// Die Ansicht wird neu geöffnet: Ab jetzt zählt wieder eine Meldung.
    static func neueOeffnung(_ ansicht: SiriMelder.Ansicht) {
        gemeinsam.neueOeffnung(ansicht)
    }

    @discardableResult
    static func melde(_ meldung: SiriMeldung, in ansicht: SiriMelder.Ansicht, jetzt: Date = .now) -> Bool {
        gemeinsam.melde(meldung, in: ansicht, vonAussen: UhrEingang.kamGeradeVonAussen(jetzt: jetzt))
    }
}
