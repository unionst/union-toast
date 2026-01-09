//
//  DynamicIslandToastView.swift
//  UnionToast
//
//  Created by Union on 1/8/26.
//

import SwiftUI

struct DynamicIslandToastView<Content: View>: View {
    @Binding var isExpanded: Bool
    var onDismiss: () -> Void
    let content: () -> Content

    init(
        isExpanded: Binding<Bool>,
        onDismiss: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._isExpanded = isExpanded
        self.onDismiss = onDismiss
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            let safeArea = proxy.safeAreaInsets
            let size = proxy.size

            // Dynamic Island detection
            let haveDynamicIsland: Bool = safeArea.top >= 59

            // Dynamic Island dimensions
            let dynamicIslandWidth: CGFloat = 120
            let dynamicIslandHeight: CGFloat = 36
            let topOffset: CGFloat = 11 + max((safeArea.top - 59), 0)

            // Expanded properties
            let expandedWidth = size.width - 20
            let expandedHeight: CGFloat = haveDynamicIsland ? 90 : 70
            let scaleX: CGFloat = isExpanded ? 1 : (dynamicIslandWidth / expandedWidth)
            let scaleY: CGFloat = isExpanded ? 1 : (dynamicIslandHeight / expandedHeight)

            toastBackground
                .overlay {
                    toastContent(haveDynamicIsland: haveDynamicIsland)
                        // Keeping the exact expanded size and using the scale to shrink and fit
                        // Avoids any text wraps and other such things!
                        .frame(width: expandedWidth, height: expandedHeight)
                        .scaleEffect(x: scaleX, y: scaleY)
                }
                .frame(
                    width: isExpanded ? expandedWidth : dynamicIslandWidth,
                    height: isExpanded ? expandedHeight : dynamicIslandHeight
                )
                .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .gesture(
                    DragGesture(minimumDistance: 5)
                        .onEnded { value in
                            if value.translation.height < -10 {
                                onDismiss()
                            }
                        }
                )
                .offset(
                    y: haveDynamicIsland ? topOffset : (isExpanded ? safeArea.top + 10 : -80)
                )
                // For Non Dynamic Island Based Phones!
                .opacity(haveDynamicIsland ? 1 : (isExpanded ? 1 : 0))
                // For Dynamic Island Based Phones!
                // Showing capsule when the effect is active and hiding it when it's not
                .animation(.linear(duration: 0.02).delay(isExpanded ? 0 : 0.28)) { content in
                    content
                        .opacity(haveDynamicIsland ? (isExpanded ? 1 : 0) : 1)
                }
                .geometryGroup()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea()
                .allowsHitTesting(isExpanded)
                .animation(.bouncy(duration: 0.5, extraBounce: 0), value: isExpanded)
        }
    }

    @Environment(\.colorScheme) private var colorScheme

    @ViewBuilder
    var toastBackground: some View {
        if #available(iOS 26.0, *) {
            ConcentricRectangle(corners: .concentric(minimum: .fixed(30)), isUniform: true)
                .fill(.black)
                .overlay {
                    if colorScheme == .dark {
                        ConcentricRectangle(corners: .concentric(minimum: .fixed(30)), isUniform: true)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                            .padding(-0.5)
                    }
                }
        } else {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.black)
                .overlay {
                    if colorScheme == .dark {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                            .padding(-0.5)
                    }
                }
        }
    }

    @ViewBuilder
    func toastContent(haveDynamicIsland: Bool) -> some View {
        content()
            .foregroundStyle(.white)
            .labelStyle(DynamicIslandLabelStyle())
    }
}

// MARK: - Dynamic Island Label Style

struct DynamicIslandLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            configuration.icon
                .font(.system(size: 40))
                .frame(width: 50)

            configuration.title
                .font(.callout)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
    }
}
