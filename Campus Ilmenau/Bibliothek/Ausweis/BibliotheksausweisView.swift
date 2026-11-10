import SwiftUI

/// Bibliotheksausweis nach `BibAusweis.dc.html`: Vollbild ohne TabBar, zum Scannen an der Ausleihtheke.
/// Schließt nach 2 Minuten von selbst und sofort, wenn die App nicht mehr aktiv ist. Die Helligkeit
/// steht so lange auf 1.
struct BibliotheksausweisView: View {
    enum Schliessgrund {
        case fertig
        case zeit
        case hintergrund
    }

    let daten: BibliotheksausweisDaten
    /// Sekunden bis zum automatischen Schließen.
    var dauer: TimeInterval = 120
    let onClose: (Schliessgrund) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme

    @State private var start = Date()
    /// Auf volle Sekunden gerundet, damit die Uhr mit der Systemuhr tickt.
    @State private var takt = Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down))
    @State private var alteHelligkeit: CGFloat?
    /// Die Szene war seit dem Öffnen mindestens einmal aktiv.
    @State private var warAktiv = false

    var body: some View {
        VStack(spacing: 0) {
            kopfzeile
            ScrollView {
                VStack(spacing: 0) {
                    karte
                    lichtbildHinweis
                    if let hinweis = daten.hinweis {
                        bibliotheksHinweis(hinweis)
                    }
                    fussnote
                }
                .padding(.bottom, 34)
            }
        }
        .background(Color(.background))
        .task {
            try? await Task.sleep(for: .seconds(dauer))
            if !Task.isCancelled { onClose(.zeit) }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            // Auch im App-Umschalter darf der Ausweis nicht zu sehen sein. Direkt nach Face ID ist die Szene
            // aber noch kurz `.inactive`, wenn der Ausweis aufgeht: Das zählt erst, wenn sie einmal aktiv war.
            if phase == .active {
                warAktiv = true
            } else if warAktiv || phase == .background {
                onClose(.hintergrund)
            }
        }
        .onAppear { helligkeitErhoehen() }
        .onDisappear { helligkeitZuruecksetzen() }
    }

    // MARK: - Kopfzeile

    private var kopfzeile: some View {
        let fertig = Button { onClose(.fertig) } label: {
            Text("Fertig")
                .font(.headline)
                .foregroundStyle(Color(.accent))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        let titel = Text("Bibliotheksausweis")
            .font(.headline)
            .foregroundStyle(Color(.textPrimary))
            .accessibilityAddTraits(.isHeader)

        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                // Bei großer Schrift ist für einen mittigen Titel kein Platz: Titel links, „Fertig“ rechts.
                HStack(alignment: .center, spacing: 12) {
                    titel.frame(maxWidth: .infinity, alignment: .leading)
                    fertig
                }
            } else {
                ZStack {
                    titel
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 88)
                    fertig.frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    // MARK: - Karte

    private var karte: some View {
        VStack(spacing: 0) {
            if dynamicTypeSize.isAccessibilitySize {
                // Weißer Text darf nicht auf dem grünen Band liegen: Bei großer Schrift steht nur die Ziege
                // auf den Bändern, der Text darunter.
                DiagonalBands(.hero, height: 92) { ziege.padding(.horizontal, 20).padding(.vertical, 26) }
            } else {
                DiagonalBands(.hero, height: nil) { kartenkopf }
            }
            kartenkoerper
            liveZeile
        }
        .background(Color(.surface))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color(.brandNight).opacity(0.12), radius: 15, x: 0, y: 10)
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    private var ziege: some View {
        Image(.symbolWhite)
            .resizable()
            .scaledToFit()
            .frame(width: 40, height: 40)
            .accessibilityHidden(true)
    }

    private var kartenkopf: some View {
        HStack(spacing: 12) {
            ziege
            // Rechts bleibt Platz, damit weißer Text nie auf dem grünen Band liegt.
            VStack(alignment: .leading, spacing: 0) {
                Text("Universitätsbibliothek Ilmenau")
                    .font(.headline)
                Text("Ausweis in Campus Ilmenau")
                    .font(.footnote)
                    .opacity(0.85)
            }
            .minimumScaleFactor(0.85)
            .padding(.trailing, 96)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color(.onBlue))
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var kartenkoerper: some View {
        VStack(alignment: .leading, spacing: 0) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Universitätsbibliothek Ilmenau")
                        .font(.headline)
                        .foregroundStyle(Color(.textPrimary))
                    Text("Ausweis in Campus Ilmenau")
                        .font(.footnote)
                        .foregroundStyle(Color(.textSecondary))
                }
                .accessibilityElement(children: .combine)
                .padding(.bottom, 16)
            }
            if let name = daten.name {
                beschriftung("Name")
                Text(name)
                    .display(size: 26, relativeTo: .title)
                    .foregroundStyle(Color(.textPrimary))
                    .padding(.top, 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let gruppe = daten.nutzergruppe {
                Chip(LocalizedStringKey(gruppe))
                    .padding(.top, 6)
            }
            nummerUndGueltigkeit
                .padding(.top, 12)
            if let statusText = daten.statusText {
                statusKasten(statusText)
                    .padding(.top, 12)
            }
            if !daten.benutzernummer.isEmpty {
                StrichcodeFeld(nummer: daten.benutzernummer)
                    .padding(.top, 16)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var nummerUndGueltigkeit: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
        layout {
            if !daten.benutzernummer.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    beschriftung("Benutzernummer")
                    Text(daten.benutzernummer)
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                        .foregroundStyle(Color(.textPrimary))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let gueltig = daten.gueltigBis {
                VStack(alignment: .leading, spacing: 2) {
                    beschriftung("Gültig bis")
                    Text(gueltig)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color(daten.gueltigBisIstKritisch() ? .danger : .textPrimary))
                }
            }
        }
    }

    private func beschriftung(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .tracking(0.5)
            .foregroundStyle(Color(.textTertiary))
    }

    private func statusKasten(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle")
                .font(.subheadline.weight(.semibold))
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(Color(.danger))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.dangerSoft), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Live-Zeile

    /// Uhr mit Sekunden, Restzeit, pulsierender Punkt und Lichtstreifen: So sieht das Personal, dass es kein Screenshot ist.
    private var liveZeile: some View {
        TimelineView(.periodic(from: takt, by: 1)) { context in
            let rest = Int((dauer - context.date.timeIntervalSince(start)).rounded(.up))
            HStack(spacing: 8) {
                HStack(spacing: 7) {
                    PulsPunkt()
                    Text("Live · \(context.date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits)))")
                        .monospacedDigit()
                }
                Spacer(minLength: 8)
                Text("Schließt in \(BibliotheksausweisDaten.restzeit(sekunden: rest))")
                    .monospacedDigit()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Live angezeigt, schließt in \(max(0, rest) / 60) Minuten \(max(0, rest) % 60) Sekunden")
        }
        .font(.footnote)
        .foregroundStyle(Color(.textSecondary))
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, minHeight: 36)
        .background(Color(.surfaceSecondary))
        .overlay {
            if !reduceMotion {
                Lichtstreifen(deckkraft: colorScheme == .dark ? 0.14 : 0.55)
            }
        }
        .clipped()
    }

    // MARK: - Hinweise

    private var lichtbildHinweis: some View {
        Card {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "person.text.rectangle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color(.onWarningFill))
                    .frame(width: 36, height: 36)
                    .background(Color(.warningFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nur mit Lichtbildausweis gültig")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(.textPrimary))
                    Text("Nimm zusätzlich deinen Personalausweis oder Reisepass mit. Die Bibliothek kann ihn bei der Ausleihe sehen wollen.")
                        .font(.footnote)
                        .foregroundStyle(Color(.textSecondary))
                }
            }
        }
        .accessibilityElement(children: .combine)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private func bibliotheksHinweis(_ text: String) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 4) {
                beschriftung("Hinweis der Bibliothek")
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(Color(.textPrimary))
            }
        }
        .accessibilityElement(children: .combine)
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private var fussnote: some View {
        Text("Die Helligkeit ist erhöht. Die Angaben kommen aus deinem Bibliothekskonto und werden nicht gespeichert.")
            .font(.footnote)
            .foregroundStyle(Color(.textTertiary))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 28)
            .padding(.top, 14)
    }

    // MARK: - Helligkeit

    private var bildschirm: UIScreen? {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.screen
    }

    private func helligkeitErhoehen() {
        guard alteHelligkeit == nil, let bildschirm else { return }
        alteHelligkeit = bildschirm.brightness
        bildschirm.brightness = 1
    }

    private func helligkeitZuruecksetzen() {
        guard let alteHelligkeit, let bildschirm else { return }
        bildschirm.brightness = alteHelligkeit
        self.alteHelligkeit = nil
    }
}

// MARK: - Strichcode

/// Weißes Feld mit Strichcode und Ziffern. Immer Schwarz auf Weiß, auch im Dark Mode, damit Scanner ihn lesen.
private struct StrichcodeFeld: View {
    let nummer: String
    @Environment(\.displayScale) private var displayScale

    /// Ruhezone links und rechts, mindestens 18 pt; das Bild bringt zusätzlich seine eigene mit.
    private let ruhezone: CGFloat = 18

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                if let bild = Strichcode.bild(für: nummer, verfügbareBreite: geo.size.width, displayScale: displayScale) {
                    Image(decorative: bild.cgImage, scale: displayScale)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: bild.breite, height: geo.size.height)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 84)
            Text(nummer)
                .font(.system(.callout, design: .monospaced).weight(.medium))
                .tracking(4)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .foregroundStyle(Color.black)
        .padding(.horizontal, ruhezone)
        .padding(.top, 16)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.black.opacity(0.08)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Strichcode der Benutzernummer \(nummer)")
        .accessibilityAddTraits(.isImage)
    }
}

// MARK: - Live-Zeile: Bausteine

private struct PulsPunkt: View {
    @State private var gedimmt = false

    var body: some View {
        Circle()
            .fill(Color(.green))
            .frame(width: 8, height: 8)
            .opacity(gedimmt ? 0.35 : 1)
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: gedimmt)
            .onAppear { gedimmt = true }
            .accessibilityHidden(true)
    }
}

/// Heller Streifen, der alle 2,6 s von links nach rechts über die Zeile läuft.
private struct Lichtstreifen: View {
    let deckkraft: Double
    private let periode: TimeInterval = 2.6
    private let breite: CGFloat = 90

    var body: some View {
        TimelineView(.animation) { context in
            GeometryReader { geo in
                let phase = context.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: periode) / periode
                LinearGradient(
                    colors: [.clear, Color.white.opacity(deckkraft), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: breite)
                .offset(x: -breite + phase * (geo.size.width + breite))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
