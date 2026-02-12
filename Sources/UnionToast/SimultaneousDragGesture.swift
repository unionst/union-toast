import SwiftUI

struct SimultaneousDragGesture: UIGestureRecognizerRepresentable {
    struct Value: Equatable, Sendable {
        var time: Date
        var location: CGPoint
        var startLocation: CGPoint

        var translation: CGSize {
            CGSize(width: location.x - startLocation.x, height: location.y - startLocation.y)
        }

        static func == (a: Value, b: Value) -> Bool {
            a.time == b.time && a.location == b.location && a.startLocation == b.startLocation
        }
    }

    var allowsSwipeToDismiss: Bool = false
    var onBegan: (() -> Void)?
    var onChanged: ((Value) -> Void)?
    var onEnded: ((Value) -> Void)?

    init(allowsSwipeToDismiss: Bool = false) {
        self.allowsSwipeToDismiss = allowsSwipeToDismiss
    }

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let dragGesture = UILongPressGestureRecognizer()
        dragGesture.minimumPressDuration = 0.0
        dragGesture.allowableMovement = CGFloat.greatestFiniteMagnitude
        dragGesture.delegate = context.coordinator
        return dragGesture
    }

    func handleUIGestureRecognizerAction(_ gestureRecognizer: UILongPressGestureRecognizer, context: Context) {
        guard gestureRecognizer.view?.window != nil else {
            context.coordinator.reset()
            return
        }

        switch gestureRecognizer.state {
        case .began:
            context.coordinator.start = safeLocation(from: context)
            context.coordinator.startTime = Date()
            context.coordinator.hasCheckedSwipe = false
            onBegan?()
            onChanged?(safeValue(from: context))
        case .changed:
            if context.coordinator.allowsSwipeToDismiss && !context.coordinator.hasCheckedSwipe {
                if let startTime = context.coordinator.startTime,
                   Date().timeIntervalSince(startTime) < 0.1 {
                    let val = safeValue(from: context)
                    let deltaY = val.translation.height
                    let deltaX = abs(val.translation.width)

                    if deltaY > 20 && deltaY > deltaX * 1.5 {
                        gestureRecognizer.isEnabled = false
                        gestureRecognizer.isEnabled = true
                        context.coordinator.reset()
                        return
                    }
                } else {
                    context.coordinator.hasCheckedSwipe = true
                }
            }
            onChanged?(safeValue(from: context))
        case .ended, .cancelled:
            onEnded?(safeValue(from: context))
            context.coordinator.reset()
        default:
            break
        }
    }

    func safeLocation(from context: Context) -> CGPoint {
        context.converter.location(in: .local)
    }

    func safeValue(from context: Context) -> Value {
        let location = safeLocation(from: context)
        let start = context.coordinator.start ?? location
        return .init(time: Date(), location: location, startLocation: start)
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        .init(allowsSwipeToDismiss: allowsSwipeToDismiss)
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var start: CGPoint?
        var allowsSwipeToDismiss: Bool
        var startTime: Date?
        var hasCheckedSwipe = false

        init(allowsSwipeToDismiss: Bool = false) {
            self.allowsSwipeToDismiss = allowsSwipeToDismiss
            super.init()
        }

        func reset() {
            start = nil
            startTime = nil
            hasCheckedSwipe = false
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            return true
        }
    }
}

extension SimultaneousDragGesture {
    @MainActor @preconcurrency func onBegan(perform action: @escaping () -> Void) -> Self {
        var mutableSelf = self
        mutableSelf.onBegan = action
        return mutableSelf
    }

    @MainActor @preconcurrency func onChanged(perform action: @escaping (Value) -> Void) -> Self {
        var mutableSelf = self
        mutableSelf.onChanged = action
        return mutableSelf
    }

    @MainActor @preconcurrency func onEnded(perform action: @escaping (Value) -> Void) -> Self {
        var mutableSelf = self
        mutableSelf.onEnded = action
        return mutableSelf
    }
}
