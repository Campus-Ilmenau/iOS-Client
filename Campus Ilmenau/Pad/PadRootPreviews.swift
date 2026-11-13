import SwiftUI

// Vorschauen der beiden Hüllen: iPad quer mit Tab-Leiste und mit Seitenleiste (`.regular` → `PadRootView`), iPad im
// schmalen Split View (`.compact` → `PhoneHuelle`) und das iPhone zur Kontrolle, je Light und Dark. Die Tabs zeigen
// Platzhalter (siehe `tabInhaltAlsPlatzhalter`); es geht um Leiste und Seitenleiste. Wie im Simulator hat die Vorschau
// kein NFC, „Thoska“ fehlt hier also wie auf einem echten iPad. Das Ziel der letzten Vorschau steckt im gemeinsamen
// Router, darum setzt `vorschau` ihn jedes Mal zurück.

@MainActor
private func vorschau(nfc: Bool = false, link: DeepLink? = nil) {
    NFCVerfuegbarkeit.ueberschreibung = nfc
    // Ohne Start-Animation wartet der Router nicht (sonst liefe der Einlauf der Ziege in der Vorschau nie).
    AppRouter.gemeinsam.startBeendet()
    AppRouter.gemeinsam.tab = .heute
    if let link { AppRouter.gemeinsam.oeffne(link) }
}

#Preview("iPad quer · Tab-Leiste · Light", traits: .landscapeLeft) {
    let _ = vorschau()
    PadRootView(seitenleisteOffen: false)
        .environment(AppRouter.gemeinsam)
        .environment(\.tabInhaltAlsPlatzhalter, true)
        .preferredColorScheme(.light)
}

#Preview("iPad quer · Tab-Leiste · Dark", traits: .landscapeLeft) {
    let _ = vorschau()
    PadRootView(seitenleisteOffen: false)
        .environment(AppRouter.gemeinsam)
        .environment(\.tabInhaltAlsPlatzhalter, true)
        .preferredColorScheme(.dark)
}

#Preview("iPad quer · Seitenleiste · Light", traits: .landscapeLeft) {
    let _ = vorschau()
    PadRootView(seitenleisteOffen: true)
        .environment(AppRouter.gemeinsam)
        .environment(\.tabInhaltAlsPlatzhalter, true)
        .preferredColorScheme(.light)
}

#Preview("iPad quer · Seitenleiste · Dark", traits: .landscapeLeft) {
    let _ = vorschau()
    PadRootView(seitenleisteOffen: true)
        .environment(AppRouter.gemeinsam)
        .environment(\.tabInhaltAlsPlatzhalter, true)
        .preferredColorScheme(.dark)
}

#Preview("Schmaler Split View · iPhone-Hülle · Light", traits: .landscapeLeft) {
    let _ = vorschau()
    ContentView()
        .environment(\.horizontalSizeClass, .compact)
        .environment(\.tabInhaltAlsPlatzhalter, true)
        .frame(width: 375)
        .preferredColorScheme(.light)
}

#Preview("Schmaler Split View · iPhone-Hülle · Dark", traits: .landscapeLeft) {
    let _ = vorschau()
    ContentView()
        .environment(\.horizontalSizeClass, .compact)
        .environment(\.tabInhaltAlsPlatzhalter, true)
        .frame(width: 375)
        .preferredColorScheme(.dark)
}

#Preview("iPhone · Light") {
    let _ = vorschau(nfc: true)
    ContentView()
        .environment(\.tabInhaltAlsPlatzhalter, true)
        .preferredColorScheme(.light)
}

#Preview("iPhone · Dark") {
    let _ = vorschau(nfc: true)
    ContentView()
        .environment(\.tabInhaltAlsPlatzhalter, true)
        .preferredColorScheme(.dark)
}

#Preview("Link Mensa · iPad quer", traits: .landscapeLeft) {
    let _ = vorschau(link: .mensa(id: "mensaEhrenberg"))
    ContentView()
        .environment(\.tabInhaltAlsPlatzhalter, true)
}

#Preview("Link Mensa · iPhone") {
    let _ = vorschau(nfc: true, link: .mensa(id: "mensaEhrenberg"))
    ContentView()
        .environment(\.tabInhaltAlsPlatzhalter, true)
}
