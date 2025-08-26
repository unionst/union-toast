//
//  ToastView.swift
//  UnionToast
//
//  Created by Union on 1/27/25.
//

import SwiftUI
import UnionScroll

struct ToastView<Content: View>: View {
    @Environment(ToastManager.self) private var toastManager

    @ViewBuilder var content: Content

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

    var body: some View {
        GeometryReader { geometryProxy in
            let topPadding = geometryProxy.safeAreaInsets.top + toastManager.contentHeight

            VStack(spacing: 0) {
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        Color.clear.opacity(0.1)
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
                        guard let new else { return }
                        if pendingEdge == new { pendingEdge = nil; return }
                        if userScrollActive {
                            let want = new == .top
                            if toastManager.isShowing != want {
                                suppressNextTempScroll = true
                                toastManager.show()
                            }
                        }
                    }
                    .onChange(of: toastManager.isShowing) { _, new in
                        if suppressNextTempScroll { suppressNextTempScroll = false; return }
                        pendingEdge = new ? .top : .bottom
                        withAnimation {
                            scrollProxy.scrollTo("unit", anchor: new ? .top : .bottom)
                        }
                    }
                    .defaultScrollAnchor(.bottom)
                    .scrollPosition(id: $visibleID)
                    .scrollIndicators(.hidden)
                    .scrollClipDisabled()
                    .simultaneousGesture(dragGesture)
                    .scrollTargetBehavior(.edges)
                    .frame(height: toastManager.contentHeight)
                }

                Spacer()
            }
        }
//        .allowsHitTesting(toastManager.isShowing)
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
        content
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
                userScrollCooldown?.cancel()
                userScrollCooldown = Task {
                    try? await Task.sleep(for: .milliseconds(250))
                    userScrollActive = false
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

struct CustomScrollTargetBehavior: ScrollTargetBehavior {
    func updateTarget(
        _ target: inout ScrollTarget,
        context: ScrollTargetBehaviorContext
    ) {
        guard context.axes.contains(.vertical) else { return }

        let content = context.contentSize.height
        let container = context.containerSize.height
        let bottom = max(0, content - container)

        let predicted = min(max(0, target.rect.minY), bottom)
        let snapY = predicted <= bottom - predicted ? 0 : bottom

        target.rect.origin.y = snapY
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
