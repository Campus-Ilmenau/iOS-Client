import UIKit

/// Mit ausgeblendeter Navigationsleiste (eigene Zurück-Taste) bricht die Wischgeste „zurück“ weg.
/// Dieser Delegate stellt sie wieder her, solange mehr als eine Ansicht im Stapel liegt.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
