import SwiftUI
import EventKit
import EventKitUI

/// Das Systemblatt „Neuer Termin“ mit vorausgefüllter Veranstaltung. Die Person wählt dort den Kalender
/// und bestätigt selbst. Dafür braucht die App keinen Kalenderzugriff (iOS 17+).
struct KalenderEditor: UIViewControllerRepresentable {
    let eintrag: KalenderEintrag
    /// `true`, wenn der Termin gesichert wurde; `false` bei Abbrechen oder Löschen.
    let onFertig: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFertig: onFertig) }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = EKEventStore()
        let termin = EKEvent(eventStore: store)
        termin.title = eintrag.titel
        termin.startDate = eintrag.beginn
        termin.endDate = eintrag.ende
        termin.isAllDay = eintrag.ganztaegig
        termin.location = eintrag.ort
        termin.url = eintrag.url

        let controller = EKEventEditViewController()
        controller.eventStore = store
        controller.event = termin
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let onFertig: (Bool) -> Void

        init(onFertig: @escaping (Bool) -> Void) { self.onFertig = onFertig }

        func eventEditViewController(
            _ controller: EKEventEditViewController,
            didCompleteWith action: EKEventEditViewAction
        ) {
            onFertig(action == .saved)
        }
    }
}
