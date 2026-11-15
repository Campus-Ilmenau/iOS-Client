import SwiftUI

// Vorschauen der iPad-Anordnung der Mensa (iPad Pro 13″): Querformat ohne Seitenleiste (1376 pt, vier Spalten), mit
// Seitenleiste (1096 pt) und Hochformat (1032 pt, zwei Spalten), dazu Filter-Popover, „keins passend“ und das Gericht
// als Sheet. Light und Dark über „Color Scheme“ der Vorschau; quer über „Orientation“. Die Breite der Ansicht kommt vom
// Rahmen, nicht vom Gerät. Die Vorschau muss auf einem iPad laufen.

@MainActor
private struct MensaPadVorschau: View {
    let breite: CGFloat
    @State var venue: MensaVenue = .mensaEhrenberg
    @State var mealtime: MensaMealtime = .lunch
    @State var dayIndex = 0
    var loadState: MensaLoadState = .loaded
    var meals: [MensaMeal] = MensaPreviewData.meals
    @State var filter = MensaFilter()
    @State var zeigtFilter = false

    var body: some View {
        let raster = PadRaster(breite: breite)
        NavigationStack {
            PadRasterMessung { _ in
                MensaPadScreen(
                    days: MensaFormatting.workdays(from: MensaPreviewData.now),
                    selectedDayIndex: $dayIndex,
                    selectedVenue: $venue,
                    mealtime: $mealtime,
                    loadState: loadState,
                    allMeals: meals,
                    filter: $filter,
                    canteens: MensaPreviewData.canteens,
                    now: MensaPreviewData.now,
                    spalten: raster.mensaSpalten,
                    onRetry: {},
                    zeigtFilter: $zeigtFilter,
                    onOpenMeal: { _ in }
                )
            }
            .frame(width: breite)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(.surfaceSecondary))
        }
    }
}

#Preview("Quer ohne Seitenleiste") {
    MensaPadVorschau(breite: 1376)
}

#Preview("Quer mit Seitenleiste") {
    MensaPadVorschau(breite: 1096)
}

#Preview("Hochkant") {
    MensaPadVorschau(breite: 1032)
}

// Die Schwelle zu vier Spalten: Karten bei 1150 pt (je 259 pt breit) und eine Stufe darunter mit zwei Spalten.
#Preview("Schwelle 1150 pt") {
    MensaPadVorschau(breite: 1150)
}

#Preview("Schwelle 1149 pt") {
    MensaPadVorschau(breite: 1149)
}

#Preview("Eine Spalte keins passend") {
    // Nur die Mensa Ehrenberg hat Gerichte, die zu „vegan + Bio“ … gar nichts passt in den anderen: Hier bleibt Ehrenberg
    // gefüllt, die übrigen Spalten zeigen „Nichts passt“.
    MensaPadVorschau(breite: 1376, filter: MensaFilter(diet: .vegetarisch, onlyBio: true))
}

#Preview("Ladefehler") {
    MensaPadVorschau(breite: 1376, loadState: .failed)
}

#Preview("Filter-Popover") {
    MensaFilterPopover(
        filter: .constant(MensaFilter(diet: .vegetarisch, onlyBio: true, excludedAllergens: ["Gluten"])),
        allergens: MensaFilter.allergens(onDay: MensaPreviewData.meals, keeping: ["Gluten"])
    )
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .padding(40)
    .background(Color(.surfaceSecondary))
}

#Preview("Gericht-Sheet") {
    NavigationStack {
        MensaMealDetailView(meal: MensaPreviewData.meals[1], canteens: MensaPreviewData.canteens)
    }
    .frame(width: 540, height: 620)
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    .padding(40)
    .background(Color(.surfaceSecondary))
}
