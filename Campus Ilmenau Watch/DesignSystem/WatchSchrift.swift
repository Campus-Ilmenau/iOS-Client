import SwiftUI

/// Plus Jakarta Sans ExtraBold, Laufweite −2 %. Nur für Seitentitel (Mensa-Name, 20), den Gerichtnamen im Detail (18)
/// und den Preis (26); alles andere ist Systemschrift.
private struct JakartaSchrift: ViewModifier {
    @ScaledMetric private var groesse: CGFloat

    init(groesse: CGFloat, relativeTo stil: Font.TextStyle) {
        _groesse = ScaledMetric(wrappedValue: groesse, relativeTo: stil)
    }

    func body(content: Content) -> some View {
        content
            .font(.custom("PlusJakartaSans-ExtraBold", fixedSize: groesse))
            .tracking(-groesse * 0.02)
    }
}

extension View {
    /// Seitentitel: Jakarta 20.
    func jakartaSeitentitel() -> some View { modifier(JakartaSchrift(groesse: 20, relativeTo: .title3)) }
    /// Name des Gerichts im Detail: Jakarta 18.
    func jakartaGerichtname() -> some View { modifier(JakartaSchrift(groesse: 18, relativeTo: .headline)) }
    /// Preis im Detail: Jakarta 26.
    func jakartaPreis() -> some View { modifier(JakartaSchrift(groesse: 26, relativeTo: .title2)) }
}

/// Systemschrift in fester Ausgangsgröße (wie im Artboard, 46 mm), die mit der eingestellten Schriftgröße der Uhr wächst.
private struct UhrSchrift: ViewModifier {
    @ScaledMetric private var groesse: CGFloat
    private let gewicht: Font.Weight
    private let festeBreite: Bool

    init(groesse: CGFloat, gewicht: Font.Weight, festeBreite: Bool) {
        _groesse = ScaledMetric(wrappedValue: groesse, relativeTo: .body)
        self.gewicht = gewicht
        self.festeBreite = festeBreite
    }

    func body(content: Content) -> some View {
        content.font(festeBreite ? .system(size: groesse, weight: gewicht).monospaced() : .system(size: groesse, weight: gewicht))
    }
}

extension View {
    /// Systemschrift mit Dynamic Type: `groesse` ist die Größe bei normaler Einstellung.
    func uhrSchrift(_ groesse: CGFloat, _ gewicht: Font.Weight = .regular, monospaced: Bool = false) -> some View {
        modifier(UhrSchrift(groesse: groesse, gewicht: gewicht, festeBreite: monospaced))
    }
}
