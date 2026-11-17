import SwiftUI

#if DEBUG
// Vorschauen von „Mehr & Einstellungen“ auf dem iPad (iPad Pro 13″): quer ohne und mit Seitenleiste (Mensa gewählt),
// hochkant, Darstellung, Bibliothekskonto angemeldet und nicht angemeldet, Sprache, Über die App. Light und Dark über
// „Color Scheme“ der Vorschau, hochkant über „Orientation“. Die Breite kommt vom Rahmen. „Abmelden“ und „Anmelden“ schalten
// hier nur den Zustand um (kein Konto). Die Adressen von Datenschutz und Impressum sind Platzhalter, damit die Zeilen zu sehen sind.

@MainActor
private struct MehrPadVorschau: View {
    @State private var bereich: MehrBereich
    @State private var konto: MehrKonto
    let breite: CGFloat?
    let filter: MensaFilter

    init(
        _ bereich: MehrBereich = .mensa,
        konto: MehrKonto = .angemeldet(benutzernummer: "0001234567"),
        breite: CGFloat? = 1376,
        filter: MensaFilter = MensaFilter()
    ) {
        _bereich = State(initialValue: bereich)
        _konto = State(initialValue: konto)
        self.breite = breite
        self.filter = filter
    }

    private static let zeiten: [MensaVenue: String] = [
        .mensaEhrenberg: "11:00–14:00 Uhr",
        .cafeteriaEhrenberg: "08:00–14:00 Uhr · Abendessen ab 16:30",
        .nanoteria: "08:00–15:00 Uhr",
        .roentgenbau: "08:00–14:00 Uhr"
    ]

    var body: some View {
        PadRasterMessung { raster in
            MehrPad(
                konto: konto,
                raster: raster,
                bereich: $bereich,
                onAnmelden: { konto = .angemeldet(benutzernummer: "0001234567") },
                onAbmelden: { konto = .abgemeldet },
                oeffnungszeiten: Self.zeiten,
                datenschutz: URL(string: "https://example.org/datenschutz"),
                impressum: URL(string: "https://example.org/impressum"),
                filterVorgabe: filter
            )
        }
        .frame(width: breite)
        .frame(maxWidth: breite == nil ? .infinity : nil, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.surfaceSecondary))
    }
}

#Preview("Quer ohne Seitenleiste") { MehrPadVorschau() }

#Preview("Quer mit Seitenleiste") { MehrPadVorschau(breite: 1096) }

#Preview("Hochkant") { MehrPadVorschau(breite: nil) }

#Preview("Darstellung") { MehrPadVorschau(.darstellung) }

#Preview("Bibliothekskonto angemeldet") { MehrPadVorschau(.konto) }

#Preview("Bibliothekskonto nicht angemeldet") { MehrPadVorschau(.konto, konto: .abgemeldet) }

#Preview("Sprache") { MehrPadVorschau(.sprache) }

#Preview("Über die App") { MehrPadVorschau(.ueber) }

#Preview("Mensa mit Filter") { MehrPadVorschau(filter: MensaFilter(diet: .vegan)) }
#endif
