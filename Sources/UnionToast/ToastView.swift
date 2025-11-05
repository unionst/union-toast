//
//  ToastView.swift
//  UnionToast
//
//  Created by Union St on 1/27/25.
//

import SwiftUI
import UnionScroll

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
                                willDismissResetTask?.cancel()
                                willDismiss = true
                            } else if new == .top {
                                willDismissResetTask?.cancel()
                                willDismiss = false
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
                            if !toastManager.isShowing {
                                animationProgress = 0
                            }
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
                                animationProgress = 0
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
                    .simultaneousGesture(dragGesture)
                    .scrollTargetBehavior(.edges)
                    .frame(height: toastManager.contentHeight)
                    .onScrollGeometryChange(for: CGFloat.self) { geometry in
                        geometry.contentOffset.y
                    } action: { oldOffset, newOffset in
                        let safeTop = geometryProxy.safeAreaInsets.top
                        let contentHeight = toastManager.contentHeight
                        
                        let visibleOffset = -safeTop
                        let dismissedOffset = contentHeight + safeTop
                        let range = dismissedOffset - visibleOffset
                        
                        guard range > 0 else { return }
                        
                        let normalizedOffset = (newOffset - visibleOffset) / range
                        let scrollProgress = 1.0 - max(0, min(1, normalizedOffset))
                        currentScrollPos = scrollProgress
                        
                        if !isDragging && willDismiss && dismissStartScrollPos > 0 {
                            let ratio = scrollProgress / dismissStartScrollPos
                            animationProgress = ratio * dismissStartAnimProgress
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
                toastManager.pauseTimer()
                if observedEdge == .top {
                    animationProgress = 1
                }
            } else {
                dismissStartScrollPos = currentScrollPos
                dismissStartAnimProgress = animationProgress
                
                if toastManager.isShowing && !willDismiss {
                    toastManager.resumeTimer()
                    animationProgress = 1
                }
            }
        }
    }

    @ViewBuilder
    func toastContent(proxy outerProxy: GeometryProxy) -> some View {
        content()
            .blur(radius: (1 - animationProgress) * 10)
            .scaleEffect(
                x: 0.6 + (animationProgress * 0.4),
                y: max(0.2, 1.4 - (animationProgress * 0.4)),
                anchor: .top
            )
        
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { value in
                toastManager.contentHeight = value
            }
    }

    var dragGesture: some Gesture {
        DragGesture()
            .onChanged { _ in
                userScrollCooldown?.cancel()
                userScrollActive = true
                isDragging = true
            }
            .onEnded { value in
                isDragging = false
                
                let threshold: CGFloat = 0.5
                if currentScrollPos < threshold {
                    willDismiss = true
                } else {
                    willDismiss = false
                    animationProgress = 1
                }
                
                userScrollCooldown?.cancel()
                userScrollCooldown = Task {
                    try? await Task.sleep(for: .milliseconds(250))
                    userScrollActive = false
                    willDismiss = false
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
