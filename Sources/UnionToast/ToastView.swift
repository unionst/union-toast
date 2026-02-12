//
//  ToastView.swift
//  UnionToast
//
//  Created by Union St on 1/27/25.
//

import SwiftUI

struct ToastView<Content: View>: View {
    @Environment(ToastManager.self) private var toastManager

    let content: () -> Content
    let previousContent: (() -> Content)?
    let replacementPresentationID: UUID?

    init(
        previousContent: (() -> Content)? = nil,
        replacementPresentationID: UUID? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.previousContent = previousContent
        self.replacementPresentationID = replacementPresentationID
        self.content = content
    }

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var visibleID: String?
    @State private var lastDragVelocity: CGFloat = 0
    @State private var dragStartScrollPos: CGFloat = 0

    enum ScrollPosition {
        case top
        case bottom
    }
    
    struct ScrollData: Equatable {
        let progress: CGFloat
        let offset: CGFloat
    }

    enum ReplacementPhase {
        case idle
        case outgoing
        case incoming
    }

    @State private var observedEdge: ScrollPosition?
    @State private var pendingEdge: ScrollPosition?
    @State private var userScrollActive = false
    @State private var userScrollCooldown: Task<Void, Never>?
    @State private var hasInitializedPosition = false
    @State private var animationProgress: CGFloat = 0
    @State private var willDismiss = false
    @State private var currentScrollPos: CGFloat = 1.0
    @State private var dismissStartScrollPos: CGFloat = 1.0
    @State private var dismissStartAnimProgress: CGFloat = 1.0
    @State private var willDismissResetTask: Task<Void, Never>?
    @State private var lastTrackedProgress: CGFloat = 0
    @State private var dragStartedFromBottom = false
    @State private var replacementPhase: ReplacementPhase = .idle
    @State private var displayPreviousContent = false
    @State private var replacementOutgoingProgress: CGFloat = 1
    @State private var replacementIncomingProgress: CGFloat = 1
    @State private var activeReplacementID: UUID?
    @State private var replacementAnimationTask: Task<Void, Never>?
    @State private var dismissCompletionTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geometryProxy in
            let topPadding = geometryProxy.safeAreaInsets.top + toastManager.contentHeight

            VStack(spacing: 0) {
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        Color.clear
                            .id("unit")
                            .frame(height: topPadding + toastManager.contentHeight)
                            .allowsHitTesting(false)
                            .overlay(alignment: .top) {
                                toastContent(proxy: geometryProxy)
                                    .contentShape(.interaction, Rectangle())
                            }
                            .onGeometryChange(for: ScrollPosition?.self) { proxy in
                                let f = proxy.frame(in: .scrollView)
                                let c = proxy.bounds(of: .scrollView) ?? .zero
                                guard !c.isEmpty else { return nil }
                                let tol: CGFloat = 1
                                if f.minY >= c.minY - tol { return .top }
                                if f.maxY <= c.maxY + tol { return .bottom }
                                return nil
                            } action: { pos in
                                guard observedEdge != pos else { return }
                                observedEdge = pos
                            }
                    }
                    .onChange(of: observedEdge) { old, new in
                        if pendingEdge == new { pendingEdge = nil }
                        
                        if !isDragging && userScrollActive {
                            if new == .bottom {
                                willDismissResetTask?.cancel()
                                willDismiss = true
                            } else if new == .top {
                                willDismissResetTask?.cancel()
                                willDismiss = false
                                animationProgress = 1
                                userScrollActive = false
                                if toastManager.isShowing {
                                    toastManager.resumeTimer()
                                }
                            }
                        }

                        if new == .bottom && !toastManager.isShowing {
                            dismissCompletionTask?.cancel()
                            dismissCompletionTask = nil
                            toastManager.notifyDismissAnimationCompleted()
                        }
                    }
                    .onChange(of: toastManager.isShowing) {
                        var animation: Animation = .default

                        if #available(iOS 26.0, *) {
                            animation = .interpolatingSpring(
                                mass: 1.0,
                                stiffness: 98,
                                damping: 13,
                                initialVelocity: 5
                            )
                        }

                        if toastManager.isShowing {
                            dismissCompletionTask?.cancel()
                            dismissCompletionTask = nil
                            willDismissResetTask?.cancel()
                            willDismiss = false
                            animationProgress = 0
                            withAnimation(animation) {
                                scrollProxy.scrollTo("unit", anchor: .top)
                                animationProgress = 1
                            }
                        } else {
                            // Use explicit transaction to ensure both animations use same timing
                            let transaction = Transaction(animation: animation)

                            withTransaction(transaction) {
                                scrollProxy.scrollTo("unit", anchor: .bottom)
                                if animationProgress == 1.0 {
                                    animationProgress = 0
                                }
                            }

                            willDismissResetTask?.cancel()
                            willDismissResetTask = Task {
                                try? await Task.sleep(for: .seconds(1))
                                willDismiss = false
                                willDismissResetTask = nil
                            }

                            dismissCompletionTask?.cancel()
                            dismissCompletionTask = Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(500))
                                guard !toastManager.isShowing else { return }
                                toastManager.notifyDismissAnimationCompleted()
                                dismissCompletionTask = nil
                            }
                        }
                    }
                    .defaultScrollAnchor(.bottom)
                    .scrollPosition(id: $visibleID)
                    .scrollIndicators(.hidden)
                    .scrollClipDisabled()
                    .applyDragGesture(drag: simultaneousDragGesture, simultaneousDrag: dragGesture)
                    .scrollTargetBehavior(.edges)
                    .frame(
                        width: max(toastManager.contentWidth, 1),
                        height: max(toastManager.contentHeight, 1)
                    )
                    .onScrollGeometryChange(for: CGFloat.self) { geometry in
                        geometry.contentOffset.y
                    } action: { oldOffset, newOffset in
                        let safeTop = geometryProxy.safeAreaInsets.top
                        let contentHeight = toastManager.contentHeight

                        let visibleOffset = -safeTop
                        // Toast is fully dismissed when its bottom edge passes the top of screen
                        let dismissedOffset = contentHeight  // Toast completely off-screen
                        let range = dismissedOffset - visibleOffset

                        guard range > 0 else { return }

                        let normalizedOffset = (newOffset - visibleOffset) / range
                        // Don't clamp to allow natural overshoot behavior
                        let scrollProgress = 1.0 - normalizedOffset
                        currentScrollPos = max(0, min(1, scrollProgress))  // Only clamp for storage

                        // Update animation progress during drag for immediate visual feedback
                        if isDragging && userScrollActive {
                            let clampedScrollProgress = max(0, min(1, scrollProgress))
                            animationProgress = clampedScrollProgress
                        }

                        if !isDragging && userScrollActive && dismissStartScrollPos < 1.0 {
                            // Use clamped value for position tracking
                            let clampedScrollProgress = max(0, min(1, scrollProgress))

                            // Check if we're moving towards visible (showing) rather than dismissing
                            let isShowingToast = clampedScrollProgress > dismissStartScrollPos

                            if isShowingToast {
                                userScrollActive = false
                                animationProgress = 1
                                dismissStartScrollPos = 1.0
                                dismissStartAnimProgress = 1.0
                                lastTrackedProgress = 0
                                if toastManager.isShowing {
                                    toastManager.resumeTimer()
                                }
                                return
                            }

                            if clampedScrollProgress > lastTrackedProgress && lastTrackedProgress > 0 {
                                userScrollActive = false
                                animationProgress = 1
                                dismissStartScrollPos = 1.0
                                dismissStartAnimProgress = 1.0
                                lastTrackedProgress = 0
                                if toastManager.isShowing {
                                    toastManager.resumeTimer()
                                }
                                return
                            }

                            lastTrackedProgress = clampedScrollProgress

                            if dismissStartScrollPos > 0 {
                                let distanceTraveled = dismissStartScrollPos - scrollProgress
                                let maxDistance = dismissStartScrollPos
                                let progressRatio = distanceTraveled / maxDistance
                                animationProgress = (1.0 - progressRatio) * dismissStartAnimProgress
                                animationProgress = max(0, animationProgress)
                            }
                        }
                    }
                    .onAppear {
                        if !hasInitializedPosition {
                            hasInitializedPosition = true
                            if toastManager.isShowing {
                                scrollProxy.scrollTo("unit", anchor: .top)
                                animationProgress = 1
                            } else {
                                scrollProxy.scrollTo("unit", anchor: .bottom)
                            }
                        }
                    }
                }
                .disabled(!toastManager.isShowing)

                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .onChange(of: isDragging) { _, newValue in
            if newValue {
                toastManager.pauseTimer()
                dragStartedFromBottom = (observedEdge == .bottom)

                if observedEdge == .top {
                    animationProgress = 1
                    dismissStartScrollPos = 1.0
                    dismissStartAnimProgress = 1.0
                } else if observedEdge == .bottom {
                    dismissStartScrollPos = 1.0
                    dismissStartAnimProgress = 1.0
                }
            } else {
                let startedFromBottom = animationProgress == 0 || (observedEdge == .bottom && currentScrollPos < 0.1)

                if !startedFromBottom && observedEdge != .bottom {
                    dismissStartScrollPos = currentScrollPos
                    dismissStartAnimProgress = animationProgress
                    lastTrackedProgress = currentScrollPos
                }
            }
        }
        .onChange(of: toastManager.replacementPresentationID) { oldID, newID in
            guard oldID != newID else { return }

            if let newID {
                startReplacementAnimationIfNeeded(for: newID)
            } else {
                cancelReplacementAnimation()
            }
        }
        .onDisappear {
            cancelReplacementAnimation()
        }
    }

    @ViewBuilder
    func toastContent(proxy outerProxy: GeometryProxy) -> some View {
        let effectiveProgress = replacementPhase == .idle ? animationProgress : replacementIncomingProgress
        let isDisappearing = replacementPhase == .idle && !toastManager.isShowing
        let isReplacementIncoming = replacementPhase != .idle

        ZStack(alignment: .top) {
            if displayPreviousContent, let previousContent {
                applyOutgoingEffects(
                    to: decoratedContent(previousContent()),
                    progress: replacementOutgoingProgress
                )
                    .allowsHitTesting(false)
            }

            if isDisappearing {
                applyDismissalEffects(
                    to: decoratedContent(content())
                        .fixedSize()
                        .onGeometryChange(for: CGSize.self) { proxy in
                            proxy.size
                        } action: { size in
                            toastManager.contentHeight = size.height
                            toastManager.contentWidth = size.width
                        },
                    progress: effectiveProgress
                )
            } else if isReplacementIncoming {
                applyReplacementIncomingEffects(
                    to: decoratedContent(content())
                        .fixedSize()
                        .onGeometryChange(for: CGSize.self) { proxy in
                            proxy.size
                        } action: { size in
                            toastManager.contentHeight = size.height
                            toastManager.contentWidth = size.width
                        },
                    progress: effectiveProgress
                )
            } else {
                applyIncomingEffects(
                    to: decoratedContent(content())
                        .fixedSize()
                        .onGeometryChange(for: CGSize.self) { proxy in
                            proxy.size
                        } action: { size in
                            toastManager.contentHeight = size.height
                            toastManager.contentWidth = size.width
                        },
                    progress: effectiveProgress
                )
            }
        }
    }

    var simultaneousDragGesture: SimultaneousDragGesture {
        SimultaneousDragGesture()
            .onChanged { _ in
                handleDragChanged()
            }
            .onEnded { _ in
                handleDragEnd()
            }
    }
    
    var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                handleDragChanged(velocity: value.velocity)
            }
            .onEnded { value in
                handleDragEnd(velocity: value.velocity)
            }
    }

    func handleDragChanged(velocity: CGSize = .zero) {
        userScrollCooldown?.cancel()
        userScrollActive = true

        if !isDragging {
            dragStartScrollPos = currentScrollPos
        }

        isDragging = true
        lastDragVelocity = velocity.height
    }

    func shouldDismiss(dragDistance: CGFloat, velocity: CGFloat) -> Bool {
        let toastHeight = toastManager.contentHeight

        // Threshold 1: Fast downward flick (positive velocity = downward)
        if velocity > 800 {
            return true
        }

        // Threshold 2: Dragged past 33% of toast height
        if dragDistance > toastHeight * 0.33 {
            return true
        }

        // Threshold 3: Minimum 50pt drag
        if dragDistance > 50 {
            return true
        }

        return false
    }

    func handleDragEnd(velocity: CGSize = .zero) {
        isDragging = false

        // Calculate drag distance in points
        let dragDistanceRatio = dragStartScrollPos - currentScrollPos
        let toastHeight = toastManager.contentHeight
        let dragDistancePoints = dragDistanceRatio * toastHeight

        // Check custom thresholds
        if shouldDismiss(dragDistance: dragDistancePoints, velocity: velocity.height) {
            // Trigger dismissal with animation
            // Don't suppress so the scroll animation happens
            // But we need to manually animate animationProgress to 0
            toastManager.dismiss()
            dragStartScrollPos = 0

            // Manually animate to 0 since scroll callbacks won't fire during programmatic scroll
            withAnimation(.interpolatingSpring(mass: 1.0, stiffness: 98, damping: 13, initialVelocity: 5)) {
                animationProgress = 0
            }
            return
        }

        userScrollCooldown?.cancel()
        userScrollCooldown = Task {
            try? await Task.sleep(for: .milliseconds(250))
            userScrollActive = false
            willDismiss = false
            dragStartScrollPos = 0

            if toastManager.isShowing && observedEdge != .bottom {
                animationProgress = 1
                dismissStartScrollPos = 1.0
                dismissStartAnimProgress = 1.0
                toastManager.resumeTimer()
            }
            
            guard let edge = observedEdge else {
                return
            }
            let wantShowing = (edge == .top)
            if toastManager.isShowing != wantShowing {
                // Don't suppress - let the natural scroll animation play
                if wantShowing {
                    toastManager.show()
                } else {
                    toastManager.dismiss()
                }
            }
        }
    }

    func checkID(_ id: String?) {
        if id == "bottom" {
            toastManager.dismiss()
        }
    }

    @ViewBuilder
    func decoratedContent<Inner: View>(_ view: Inner) -> some View {
        view
            .modifier(ConditionalToastBackgroundWrapper())
    }
}

// MARK: - Replacement Helpers

private extension ToastView {
    func startReplacementAnimationIfNeeded(for replacementID: UUID) {
        guard previousContent != nil else { return }

        // Prevent duplicate calls for the same replacement
        guard activeReplacementID != replacementID else { return }

        // Cancel any previous animation and set the new ID
        replacementAnimationTask?.cancel()
        replacementAnimationTask = nil
        activeReplacementID = replacementID
        displayPreviousContent = true
        replacementIncomingProgress = 0
        replacementPhase = .outgoing

        let outgoingDuration = replacementOutgoingDuration
        let incomingDelay = replacementIncomingDelay
        let incomingDuration = replacementIncomingDuration

        let outgoingAnimation = Animation.easeOut(duration: outgoingDuration)
        withAnimation(outgoingAnimation) {
            replacementOutgoingProgress = 0.01
        }

        replacementAnimationTask = Task { @MainActor in
            if incomingDelay > 0 {
                try? await Task.sleep(for: .seconds(incomingDelay))
            }
            guard !Task.isCancelled else { return }

            replacementPhase = .incoming
            var incomingAnimation: Animation = .default

            if #available(iOS 26.0, *) {
                incomingAnimation = Animation.interpolatingSpring(
                    mass: 1.0,
                    stiffness: 92,
                    damping: 14,
                    initialVelocity: 6
                ).speed(1.1)
            }

            withAnimation(incomingAnimation) {
                replacementIncomingProgress = 1
                animationProgress = 1
            }

            let totalDuration = max(outgoingDuration, incomingDelay + incomingDuration)
            try? await Task.sleep(for: .seconds(totalDuration) + .milliseconds(350))
            guard !Task.isCancelled else { return }

            replacementOutgoingProgress = 0

            toastManager.completeReplacement()

            // Wait for the manager's delayed state update before resetting our state
            try? await Task.sleep(for: .milliseconds(100))

            resetReplacementAnimationState()
            toastManager.notifyReplacementAnimationSettled()
        }
    }

    func cancelReplacementAnimation() {
        replacementAnimationTask?.cancel()
        replacementAnimationTask = nil
        resetReplacementAnimationState()
    }

    func resetReplacementAnimationState() {
        displayPreviousContent = false
        replacementPhase = .idle
        replacementOutgoingProgress = 1
        replacementIncomingProgress = 1
        activeReplacementID = nil
    }

    var replacementOutgoingDuration: Double {
        if #available(iOS 26.0, *) {
            return 0.38
        } else {
            return 0.3
        }
    }

    var replacementIncomingDuration: Double {
        if #available(iOS 26.0, *) {
            return 0.32
        } else {
            return 0.4
        }
    }

    var replacementIncomingDelay: Double {
        return 0.0
    }

    @ViewBuilder
    func applyIncomingEffects<V: View>(to view: V, progress: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            view
                .scaleEffect(0.40 + (progress * 0.60))
                .blur(radius: (1 - progress) * 8)
                .offset(y: (1 - progress) * 24)
        } else {
            view
                .opacity(progress)
                .offset(y: (1 - progress) * 12)
        }
    }

    @ViewBuilder
    func applyReplacementIncomingEffects<V: View>(to view: V, progress: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            view
                .scaleEffect(0.40 + (progress * 0.60))
                .blur(radius: (1 - progress) * 8)
                .offset(y: -(1 - progress) * 120)
        } else {
            view
                .offset(y: -(1 - progress) * 150)
        }
    }

    @ViewBuilder
    func applyOutgoingEffects<V: View>(to view: V, progress: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            view
                .scaleEffect(0.40 + (progress * 0.60))
                .blur(radius: (1 - progress) * 8)
                .offset(y: -(1 - progress) * 120)
        } else {
            let opacityValue: CGFloat = progress > 0.01 ? 1.0 : max(0, progress / 0.01)
            view
                .scaleEffect(0.8 + (progress * 0.2))
                .opacity(opacityValue)
        }
    }

    @ViewBuilder
    func applyDismissalEffects<V: View>(to view: V, progress: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            view
                .scaleEffect(0.40 + (progress * 0.60))
                .blur(radius: (1 - progress) * 16)
                .offset(y: -(1 - progress) * 120)
        } else {
            view
        }
    }
}

#Preview {
    @Previewable @State var manager = ToastManager()

    ToastView {
        Text("hello world")
            .padding()
            .background(.red)
    }
    .environment(manager)
    .task {
        try? await Task.sleep(for: .seconds(2))
        manager.show()
    }
}
