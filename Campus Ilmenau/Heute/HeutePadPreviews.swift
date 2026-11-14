import SwiftUI

// Vorschauen der iPad-Anordnung von „Heute“ (iPad Pro 13″): ohne Seitenleiste (1376 pt), mit Seitenleiste (1096 pt,
// Seitenleiste 280 pt), hochkant (1032 pt) und Split View ⅓ (438 pt, die iPhone-Anordnung), jeweils Mittag und Abend.
// Light und Dark über „Color Scheme“ der Vorschau. Die Breiten sind die der Ansicht, nicht des Geräts.
// Quer: Orientierung „Landscape Left“ der Vorschau wählen. Die Vorschau muss auf einem iPad laufen; auf dem iPhone bleibt die Anordnung untereinander.

@MainActor
private struct HeutePadVorschau: View {
    let uhr: String
    let breite: CGFloat

    var body: some View {
        // Die Ansicht hat genau `breite`; der Rest der Vorschau ist Hintergrund (Seitenleiste, zweite Hälfte beim Split View).
        HeuteView(model: HeuteVorschau.modell(uhr))
            .frame(width: breite)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(.surfaceSecondary))
    }
}

#Preview("iPad ohne Seitenleiste · Mittag") {
    HeutePadVorschau(uhr: "11:45", breite: 1376)
}

#Preview("iPad ohne Seitenleiste · Abend") {
    HeutePadVorschau(uhr: "17:40", breite: 1376)
}

#Preview("iPad mit Seitenleiste · Mittag") {
    HeutePadVorschau(uhr: "11:45", breite: 1096)
}

#Preview("iPad mit Seitenleiste · Abend") {
    HeutePadVorschau(uhr: "17:40", breite: 1096)
}

#Preview("iPad hochkant · Mittag") {
    HeutePadVorschau(uhr: "11:45", breite: 1032)
}

#Preview("iPad hochkant · Abend") {
    HeutePadVorschau(uhr: "17:40", breite: 1032)
}

#Preview("Split View ⅓ · Mittag") {
    HeutePadVorschau(uhr: "11:45", breite: 438)
}

#Preview("Split View ⅓ · Abend") {
    HeutePadVorschau(uhr: "17:40", breite: 438)
}

// Die Schwelle: 699 pt noch untereinander, 700 pt zwei Spalten.
#Preview("Schwelle 699 pt") {
    HeutePadVorschau(uhr: "17:40", breite: 699)
}

#Preview("Schwelle 700 pt") {
    HeutePadVorschau(uhr: "17:40", breite: 700)
}
