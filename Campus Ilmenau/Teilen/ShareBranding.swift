import Foundation

/// Marke unter jedem geteilten Text und auf jedem Bild.
enum ShareBranding {
    /// Platzhalter, bis die Domain feststeht. Die Adresse steht nur hier.
    static let domain = "campus-ilmenau.de"

    /// „Geteilt mit Campus Ilmenau – campus-ilmenau.de“
    static func line(locale: Locale = ShareStrings.appLocale) -> String {
        ShareStrings(locale: locale)("share.brand", domain)
    }
}
