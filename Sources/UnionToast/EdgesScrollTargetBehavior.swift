import SwiftUI

@available(iOS 17.0, *)
struct EdgesScrollTargetBehavior: ScrollTargetBehavior {
    func updateTarget(_ target: inout ScrollTarget, context: ScrollTargetBehaviorContext) {
        if context.axes.contains(.vertical) {
            target.rect.origin.y = snapToEdge(
                predicted: target.rect.origin.y,
                contentSize: context.contentSize.height,
                containerSize: context.containerSize.height
            )
        }

        if context.axes.contains(.horizontal) {
            target.rect.origin.x = snapToEdge(
                predicted: target.rect.origin.x,
                contentSize: context.contentSize.width,
                containerSize: context.containerSize.width
            )
        }
    }

    private func snapToEdge(predicted: CGFloat, contentSize: CGFloat, containerSize: CGFloat) -> CGFloat {
        guard contentSize > containerSize else { return 0 }
        let maxOffset = contentSize - containerSize
        let distanceToStart = predicted
        let distanceToEnd = maxOffset - predicted
        return distanceToStart <= distanceToEnd ? 0 : maxOffset
    }
}

@available(iOS 17.0, *)
extension ScrollTargetBehavior where Self == EdgesScrollTargetBehavior {
    static var edges: EdgesScrollTargetBehavior { .init() }
}
