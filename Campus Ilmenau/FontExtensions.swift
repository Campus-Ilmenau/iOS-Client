import SwiftUI

extension Font {
    /// Plus Jakarta Sans ExtraBold für große Titel und Zahlen, gekoppelt an einen Textstil (Dynamic Type).
    /// Die Laufweite von −2 % setzt `View.display(size:relativeTo:)`.
    static func display(size: CGFloat, relativeTo textStyle: Font.TextStyle = .largeTitle) -> Font {
        .custom("PlusJakartaSans-ExtraBold", size: size, relativeTo: textStyle)
    }
}

extension View {
    /// Markenschrift für große Titel und Zahlen: Plus Jakarta Sans ExtraBold, Laufweite −2 %.
    func display(size: CGFloat, relativeTo textStyle: Font.TextStyle = .largeTitle) -> some View {
        font(.display(size: size, relativeTo: textStyle))
            .tracking(-0.02 * size)
    }
}
