import SwiftUI

// Die Ziege des Einlaufs zu festen Zeiten: Anfang, Mitte des Trabs, mitten im Kopfdrehen und Ende (= Logo), je Light und
// Dark. Vergleichen mit `Laden/generate_einlauf.py` bzw. dem Logo im Kopf der Seitenleiste.

private struct EinlaufZeile: View {
    let zeiten: [Double]

    var body: some View {
        HStack(spacing: 16) {
            ForEach(zeiten, id: \.self) { zeit in
                VStack(spacing: 6) {
                    ZiegeEinlaufBild(zustand: .bei(zeit))
                        .background(Color(.surface))
                    Text(String(format: "%.2f s", zeit)).font(.caption2).foregroundStyle(Color(.textSecondary))
                }
            }
        }
        .padding(16)
        .background(Color(.background))
    }
}

#Preview("Einlauf · Light") {
    EinlaufZeile(zeiten: [1.0, 1.25, 2.52, 2.8, 3.36])
        .foregroundStyle(Color(.brandOrange))
        .preferredColorScheme(.light)
}

#Preview("Einlauf · Dark") {
    EinlaufZeile(zeiten: [1.0, 1.25, 2.52, 2.8, 3.36])
        .foregroundStyle(Color.white)
        .preferredColorScheme(.dark)
}
