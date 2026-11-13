import WidgetKit
import SwiftUI

/// Die Watch-Widgets für Zifferblatt und Smart Stack: Mensa heute, Heute Abend und die Merkliste. Die Rechnung steht in
/// `WatchShared/UhrWidgets.swift` und `Shared/`, die Familien zeichnen nur. Die Daten legt die Watch-App in ihrer
/// App Group ab; sie lädt die Zeitleisten neu, wenn sie etwas Neues hat.
@main
struct Watch_WidgetsBundle: WidgetBundle {
    var body: some Widget {
        MensaWatchWidget()
        AbendWatchWidget()
        MerklisteWatchWidget()
    }
}
