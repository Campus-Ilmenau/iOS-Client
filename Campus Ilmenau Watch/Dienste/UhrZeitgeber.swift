import SwiftUI

/// Gibt der Ansicht die aktuelle Uhrzeit und aktualisiert sie jede Minute. Previews legen eine feste Zeit fest.
struct UhrZeitgeber<Inhalt: View>: View {
    var festgelegt: Date?
    @ViewBuilder var inhalt: (Date) -> Inhalt

    var body: some View {
        if let festgelegt {
            inhalt(festgelegt)
        } else {
            TimelineView(.everyMinute) { kontext in
                inhalt(kontext.date)
            }
        }
    }
}
