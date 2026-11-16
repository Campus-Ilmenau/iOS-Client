import SwiftUI

// Vorschauen der iPad-Anordnung der Bibliothek (iPad Pro 13″, Testdaten, keine echten Konten): drei Spalten (1376 pt),
// zwei Spalten mit Seitenleiste (1096 pt) samt Mitteilungen-Popover, Medien- und Vormerkungs-Blatt, abgemeldet.
// Light und Dark über „Color Scheme“ der Vorschau, quer über „Orientation“. Die Breite kommt vom Rahmen.

enum BibliothekPadMuster {
    /// Testdaten: Fälligkeit in Tagen ab heute. Die Adressen `edition` sind erfunden (PPN nur als Muster).
    static func item(
        _ titel: String, signatur: String? = nil, status: PAIAItemStatus = .held, tage: Int? = nil, verlaengert: Int = 0,
        verlaengerbar: Bool? = true, ort: String? = nil, warteschlange: Int? = nil, kommentar: String? = nil, ppn: String? = nil
    ) -> PAIALoanItem {
        let ende = tage.flatMap { Calendar.current.date(byAdding: .day, value: $0, to: Calendar.current.startOfDay(for: .now))?.addingTimeInterval(43_200) }
        return PAIALoanItem(
            item: "https://example.org/item/\(titel.hashValue)", edition: ppn.map { "http://uri.gbv.de/document/opac-de-ilm1:ppn:\($0)" },
            about: titel, label: signatur, queue: warteschlange, renewals: verlaengert, reminder: 0, starttime: nil, endtime: ende,
            cancancel: false, canrenew: verlaengerbar, storage: ort, storageid: nil, comment: kommentar, status: status
        )
    }

    static let ausleihen: [PAIALoanItem] = [
        item("Einführung in die Informatik", signatur: "INF 001 G958(2)", tage: -2, verlaengert: 2, verlaengerbar: false, ppn: "1009895648"),
        item("Grundlagen der Elektrotechnik 1", signatur: "ELT 100 S421(3)", tage: 2, verlaengert: 1, ppn: "1009895649"),
        item("Werkstoffkunde", signatur: "WER 120 B379(11)", tage: 5),
        item("Analysis für Ingenieure", signatur: "MAT 200 M454", tage: 12)
    ]

    static let vormerkungen: [PAIALoanItem] = [
        item("Regelungstechnik 1", signatur: "MSR 300 L971", status: .provided, tage: 6, ort: "Ausleihtheke", ppn: "1009895650"),
        item("Physik für Ingenieure", signatur: "PHY 100 H523(9)", status: .ordered, ort: "Magazin"),
        item("Technische Mechanik 2: Elastostatik", signatur: "MEC 210 G795", status: .reserved, warteschlange: 2)
    ]

    static var alle: [PAIALoanItem] { ausleihen + vormerkungen }

    static let mitteilungen: [PAIANotification] = {
        func n(_ about: String, tage: Int, id: String) -> PAIANotification {
            PAIANotification(id: id, about: about, date: Calendar.current.date(byAdding: .day, value: -tage, to: .now) ?? .now, item: nil, url: nil)
        }
        return [
            n("„Regelungstechnik 1“ liegt zur Abholung bereit.", tage: 1, id: "1"),
            n("„Einführung in die Informatik“ ist überfällig. Bitte gib das Medium zurück.", tage: 1, id: "2"),
            n("„Statistik kompakt“ wurde nicht abgeholt.", tage: 15, id: "3")
        ]
    }()
}

@MainActor
private struct BibliothekPadVorschau: View {
    let breite: CGFloat
    var session: BibliothekScreen.Session = .signedIn(username: "0001234567")
    var items: [PAIALoanItem] = BibliothekPadMuster.alle
    var fehler: String?
    @State private var meldung: String?
    @State private var dienst = LibraryCatalogService()

    var body: some View {
        let raster = PadRaster(breite: breite)
        PadRasterMessung { _ in
            BibliothekPadScreen(
                session: session,
                items: items,
                notifications: BibliothekPadMuster.mitteilungen,
                isLoading: false,
                errorMessage: $meldung,
                spalten: raster.bibliothekSpalten,
                onOpenCatalog: {}, onLogin: {}, onLogout: {},
                onRenew: { _ in "Verlängert" },
                onRefresh: {},
                merklisteCount: 3,
                onOpenMerkliste: {}, onShowAusweis: {},
                catalogService: dienst,
                coverLoader: LibraryCoverLoader(service: dienst)
            )
        }
        .onAppear { meldung = fehler }
        .frame(width: breite)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.surfaceSecondary))
    }
}

#Preview("Drei Spalten") {
    BibliothekPadVorschau(breite: 1376)
}

#Preview("Zwei Spalten mit Seitenleiste") {
    BibliothekPadVorschau(breite: 1096)
}

#Preview("Fehler beim Verlängern") {
    BibliothekPadVorschau(breite: 1376, fehler: "Verlängerung fehlgeschlagen: Das Medium ist vorgemerkt.")
}

#Preview("Nicht angemeldet") {
    BibliothekPadVorschau(breite: 1376, session: .signedOut(expired: false), items: [])
}

#Preview("Leer") {
    BibliothekPadVorschau(breite: 1376, items: [])
}

#Preview("Mitteilungen-Popover") {
    PAIANotificationsContent(notifications: BibliothekPadMuster.mitteilungen, isLoading: false, onDone: {}, onRefresh: {})
        .frame(width: 380, height: 420)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(40)
        .background(Color(.surfaceSecondary))
}

private struct DetailBlattVorschau: View {
    let ziel: BibliothekDetailZiel
    var mitKatalog = true
    @State private var dienst = LibraryCatalogService()

    var body: some View {
        BibliothekDetailBlatt(
            ziel: ziel,
            items: BibliothekPadMuster.alle,
            catalogService: dienst,
            coverLoader: LibraryCoverLoader(service: dienst),
            vorschauModell: mitKatalog ? .preview(.ausgeliehen) : nil,
            onRenew: { _ in "Verlängert" }
        )
        .frame(width: 640, height: 760)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(40)
        .background(Color(.surfaceSecondary))
    }
}

#Preview("Medium-Blatt") {
    DetailBlattVorschau(ziel: BibliothekDetailZiel(item: BibliothekPadMuster.ausleihen[1], ausleihe: true))
}

#Preview("Medium-Blatt überfällig") {
    DetailBlattVorschau(ziel: BibliothekDetailZiel(item: BibliothekPadMuster.ausleihen[0], ausleihe: true))
}

#Preview("Medium-Blatt ohne Katalog") {
    DetailBlattVorschau(ziel: BibliothekDetailZiel(item: BibliothekPadMuster.ausleihen[2], ausleihe: true), mitKatalog: false)
}

#Preview("Vormerkung-Blatt") {
    DetailBlattVorschau(ziel: BibliothekDetailZiel(item: BibliothekPadMuster.vormerkungen[0], ausleihe: false))
}

#Preview("Vormerkung-Blatt ohne Satz") {
    DetailBlattVorschau(ziel: BibliothekDetailZiel(item: BibliothekPadMuster.vormerkungen[2], ausleihe: false), mitKatalog: false)
}
