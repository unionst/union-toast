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
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var toastContentHeight: CGFloat = 0

    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { proxy in
            let topPadding = proxy.safeAreaInsets.top + toastContentHeight

            VStack(spacing: 0) {
                ScrollView {
                    VStack {
                        toastContent(proxy: proxy)
                        Spacer().frame(height: topPadding)
                    }
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
                .simultaneousGesture(dragGesture)
                .frame(height: toastContentHeight)
                .scrollTargetBehavior(.edges)

                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .allowsHitTesting(toastManager.isShowing)
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
//        let verticalOffset = -outerProxy.safeAreaInsets.top - toastContentHeight

        if toastManager.isShowing {
            content
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { value in
                    toastContentHeight = value
                }
        }
    }

    var dragGesture: some Gesture {
        DragGesture()
            .onChanged { _ in
                isDragging = true
            }
            .onEnded { value in
                isDragging = false
            }
    }
}

#Preview {
    ToastView {
        Text("hello world")
            .padding()
    }
    .environment({
        let manager = ToastManager()
        manager.isShowing = true
        return manager
    }())
}
