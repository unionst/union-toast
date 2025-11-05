//
//  ToastView.swift
//  UnionToast
//
//  Created by Union St on 1/27/25.
//

import SwiftUI
import UnionScroll
import UnionGestures

struct ToastView<Content: View>: View {
    @Environment(ToastManager.self) private var toastManager

    let content: () -> Content

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var visibleID: String?

    enum ScrollPosition {
        case top
        case bottom
    }
    
    struct ScrollData: Equatable {
        let progress: CGFloat
        let offset: CGFloat
    }

    @State private var suppressNextTempScroll = false
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

    var body: some View {
        GeometryReader { geometryProxy in
            let topPadding = geometryProxy.safeAreaInsets.top + toastManager.contentHeight

            VStack(spacing: 0) {
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        Color.clear
                            .id("unit")
                            .frame(height: topPadding + toastManager.contentHeight)
                            .overlay(alignment: .top) {
                                toastContent(proxy: geometryProxy)
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
                                print("📍 Edge → BOTTOM")
                                willDismissResetTask?.cancel()
                                willDismiss = true
                            } else if new == .top {
                                print("📍 Edge → TOP - resetting to 1.0")
                                willDismissResetTask?.cancel()
                                willDismiss = false
                                animationProgress = 1
                                userScrollActive = false
                                if toastManager.isShowing {
                                    toastManager.resumeTimer()
                                }
                            }
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
                        
                        if suppressNextTempScroll {
                            suppressNextTempScroll = false
                            // Don't change animationProgress - let position tracking handle it
                            return
                        }
                        
                        if toastManager.isShowing {
                            willDismissResetTask?.cancel()
                            willDismiss = false
                            animationProgress = 0
                            withAnimation(animation) {
                                scrollProxy.scrollTo("unit", anchor: .top)
                                animationProgress = 1
                            }
                        } else {
                            withAnimation(animation) {
                                scrollProxy.scrollTo("unit", anchor: .bottom)
                                // Only set to 0 if we're not already animating from a swipe
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
                        }
                    }
                    .defaultScrollAnchor(.bottom)
                    .scrollPosition(id: $visibleID)
                    .scrollIndicators(.hidden)
                    .scrollClipDisabled()
                    .applyDragGesture(drag: simultaneousDragGesture, simultaneousDrag: dragGesture)
                    .scrollTargetBehavior(.edges)
                    .frame(height: toastManager.contentHeight)
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
                        
                        
                        if !isDragging && userScrollActive && dismissStartScrollPos < 1.0 {
                            // Use clamped value for position tracking
                            let clampedScrollProgress = max(0, min(1, scrollProgress))
                            
                            // Check if we're moving towards visible (showing) rather than dismissing
                            let isShowingToast = clampedScrollProgress > dismissStartScrollPos
                            
                            if isShowingToast {
                                // Reset to visible state - we're showing, not dismissing
                                print("📈 Showing toast: \(String(format: "%.3f", clampedScrollProgress)) > start: \(String(format: "%.3f", dismissStartScrollPos))")
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
                            
                            print("🌊 Scroll offset: \(String(format: "%.1f", newOffset)), ScrollPos: \(String(format: "%.3f", clampedScrollProgress))")
                            
                            if clampedScrollProgress > lastTrackedProgress && lastTrackedProgress > 0 {
                                print("🔙 Scroll bouncing back: \(String(format: "%.3f", clampedScrollProgress)) > \(String(format: "%.3f", lastTrackedProgress))")
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
                                // Use unclamped scrollProgress for smooth animation through overshoot
                                let distanceTraveled = dismissStartScrollPos - scrollProgress
                                let maxDistance = dismissStartScrollPos  // From release to fully dismissed (0)
                                let progressRatio = distanceTraveled / maxDistance
                                // Invert: 1.0 at release, 0.0 when fully dismissed
                                // Allow negative values during overshoot for natural bounce
                                animationProgress = (1.0 - progressRatio) * dismissStartAnimProgress
                                animationProgress = max(0, animationProgress)  // But don't go below 0
                                let scale = 0.5 + (animationProgress * 0.5)
                                print("🌊 Anim: \(String(format: "%.3f", animationProgress)), Scale: \(String(format: "%.3f", scale))")
                            }
                        }
                    }
                    .onAppear {
                        if !hasInitializedPosition {
                            hasInitializedPosition = true
                            DispatchQueue.main.async {
                                scrollProxy.scrollTo("unit", anchor: .bottom)
                            }
                        }
                    }
                }
                .disabled(!toastManager.isShowing)

                Spacer()
            }
        }
        .onChange(of: isDragging) { _, newValue in
            if newValue {
                print("▶️ Drag START - currentAnim: \(animationProgress)")
                toastManager.pauseTimer()
                dragStartedFromBottom = (observedEdge == .bottom)
                
                if observedEdge == .top {
                    animationProgress = 1
                    dismissStartScrollPos = 1.0
                    dismissStartAnimProgress = 1.0
                } else if observedEdge == .bottom {
                    // Don't track dismiss animation when starting from bottom
                    dismissStartScrollPos = 1.0
                    dismissStartAnimProgress = 1.0
                }
            } else {
                // Only capture dismiss start if:
                // 1. We're not at bottom edge
                // 2. We started from a visible position (not from bottom)
                let startedFromBottom = animationProgress == 0 || (observedEdge == .bottom && currentScrollPos < 0.1)
                
                if !startedFromBottom && observedEdge != .bottom {
                    dismissStartScrollPos = currentScrollPos
                    dismissStartAnimProgress = animationProgress
                    lastTrackedProgress = currentScrollPos
                }
                print("⏸️ Drag END - captured: scrollPos=\(currentScrollPos), animProgress=\(animationProgress)")
            }
        }
    }

    @ViewBuilder
    func toastContent(proxy outerProxy: GeometryProxy) -> some View {
        content()
            .blur(radius: (1 - animationProgress) * 10)
            .scaleEffect(0.5 + (animationProgress * 0.5))
            .opacity(0.5 + (animationProgress * 0.5))
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { value in
                toastManager.contentHeight = value
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
            .onChanged { _ in
                handleDragChanged()
            }
            .onEnded { value in
                handleDragEnd()
            }
    }
    
    func handleDragChanged() {
        userScrollCooldown?.cancel()
        userScrollActive = true
        isDragging = true
    }
    
    func handleDragEnd() {
        isDragging = false
        
        userScrollCooldown?.cancel()
        userScrollCooldown = Task {
            try? await Task.sleep(for: .milliseconds(250))
            print("⏰ Cooldown - edge: \(String(describing: observedEdge)), animProgress before: \(animationProgress)")
            userScrollActive = false
            willDismiss = false
            
            if toastManager.isShowing && observedEdge != .bottom && dismissStartScrollPos >= 1.0 {
                animationProgress = 1
                dismissStartScrollPos = 1.0
                dismissStartAnimProgress = 1.0
                toastManager.resumeTimer()
                print("⏰ Reset all to 1.0")
            }
            
            guard let edge = observedEdge else {
                return
            }
            let wantShowing = (edge == .top)
            if toastManager.isShowing != wantShowing {
                suppressNextTempScroll = true
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
