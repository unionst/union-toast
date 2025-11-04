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

    @State private var suppressNextTempScroll = false
    @State private var observedEdge: ScrollPosition?
    @State private var pendingEdge: ScrollPosition?
    @State private var userScrollActive = false
    @State private var userScrollCooldown: Task<Void, Never>?
    @State private var hasInitializedPosition = false
    @State private var animationProgress: CGFloat = 0

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
                    .onChange(of: observedEdge) { _, new in
                        if pendingEdge == new { pendingEdge = nil }
                    }
                    .onChange(of: toastManager.isShowing) {
                        if suppressNextTempScroll {
                            suppressNextTempScroll = false
                            if !toastManager.isShowing {
                                animationProgress = 0
                            }
                            return
                        }

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
                            withAnimation(animation) {
                                scrollProxy.scrollTo("unit", anchor: .top)
                                animationProgress = 1
                            }
                        } else {
                            withAnimation(animation) {
                                scrollProxy.scrollTo("unit", anchor: .bottom)
                                animationProgress = 0
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
            } else {
                if toastManager.isShowing {
                    toastManager.resumeTimer()
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
            .opacity(animationProgress)
        
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
            .onEnded { _ in
                userScrollCooldown?.cancel()
                userScrollCooldown = Task {
                    try? await Task.sleep(for: .milliseconds(250))
                    userScrollActive = false
                    guard let edge = observedEdge else { return }
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
                isDragging = false
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
