import SwiftUI

extension View {
    @ViewBuilder
    func applyDragGesture(drag: SimultaneousDragGesture, simultaneousDrag: some Gesture) -> some View {
        if #available(iOS 26.0, *) {
            self.gesture(drag)
        } else {
            self.simultaneousGesture(simultaneousDrag, including: .gesture)
        }
    }
}
