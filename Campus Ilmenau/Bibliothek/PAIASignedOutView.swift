import SwiftUI

/// Platzhalter der Bibliothek ohne gültige Sitzung (nach „Abbrechen“ im Login-Sheet):
/// Schloss, Titel je nach Grund, Hinweis und „Anmelden“.
struct PAIASignedOutView: View {
    let sessionExpired: Bool
    let onLogin: () -> Void

    var body: some View {
        ScrollView {
            Card(verticalPadding: 32, horizontalPadding: 20) {
                VStack(spacing: 0) {
                    Image(systemName: "lock")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(Color(.textTertiary))
                        .accessibilityHidden(true)

                    Text(sessionExpired ? "Sitzung abgelaufen" : "Nicht angemeldet")
                        .font(.headline)
                        .foregroundStyle(Color(.textPrimary))
                        .padding(.top, 10)

                    Text("Melde dich an, um deine ausgeliehenen Medien zu sehen.")
                        .foregroundStyle(Color(.textSecondary))
                        .multilineTextAlignment(.center)
                        .padding(.top, 6)
                        .padding(.bottom, 18)

                    PrimaryButton("Anmelden", action: onLogin)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(16)
        }
        .background(Color(.background))
    }
}
