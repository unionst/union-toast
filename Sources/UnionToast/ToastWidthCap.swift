import SwiftUI

struct ToastWidthCap: ViewModifier {
    let limit: CGFloat
    @State private var idealWidth: CGFloat = 0

    func body(content: Content) -> some View {
        let capped = limit > 0 && idealWidth >= limit
        content
            .frame(width: capped ? limit : nil)
            .fixedSize(horizontal: !capped, vertical: true)
            .background {
                content
                    .fixedSize()
                    .hidden()
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.width
                    } action: { width in
                        idealWidth = width
                    }
            }
    }
}
