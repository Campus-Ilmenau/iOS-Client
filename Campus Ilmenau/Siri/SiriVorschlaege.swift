import Foundation

/// Die iPhone-Seite der Meldungen an Siri: Ob eine Ansicht gerade von außen geöffnet wurde (Siri, Widget, Vorschlag,
/// Deeplink), weiß der `AppRouter`. `SiriMeldung` und `SiriMelder` selbst liegen in `SiriShared/SiriMeldung.swift`, denn
/// die Uhr meldet nach denselben Regeln.
extension SiriMelder {
    @discardableResult
    func melde(_ meldung: SiriMeldung, in ansicht: Ansicht, router: AppRouter?, jetzt: Date = .now) -> Bool {
        melde(meldung, in: ansicht, vonAussen: router?.kamGeradeVonAussen(jetzt: jetzt) == true)
    }
}
