//
//  View+ToastBackground.swift
//  UnionToast
//
//  Created by Union on 11/8/25.
//

import SwiftUI

public struct ToastBackgroundConfiguration: Sendable {
    public enum GlassEffectOption: Equatable, Sendable {
        case automatic
        case disabled
        case regular
        case clear
        case regularInteractive
        case clearInteractive
    }
    
    public struct Shadow: Equatable, Sendable {
        public var color: Color
        public var radius: CGFloat
        public var x: CGFloat
        public var y: CGFloat
        
        public init(color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            self.color = color
            self.radius = radius
            self.x = x
            self.y = y
        }
    }
    
    public var style: AnyShapeStyle
    public var strokeStyle: AnyShapeStyle?
    public var shape: AnyShape
    public var padding: EdgeInsets
    public var glassEffect: GlassEffectOption
    public var shadow: Shadow?
    
    public init(
        style: AnyShapeStyle,
        strokeStyle: AnyShapeStyle? = nil,
        shape: AnyShape = AnyShape(Capsule()),
        padding: EdgeInsets = EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16),
        glassEffect: GlassEffectOption = .automatic,
        shadow: Shadow? = Shadow(
            color: Color.black.opacity(0.10),
            radius: 28,
            x: 0,
            y: 14
        )
    ) {
        self.style = style
        self.strokeStyle = strokeStyle
        self.shape = shape
        self.padding = padding
        self.glassEffect = glassEffect
        self.shadow = shadow
    }
}

public extension ToastBackgroundConfiguration {
    static var `default`: ToastBackgroundConfiguration {
        ToastBackgroundConfiguration(style: AnyShapeStyle(.regularMaterial))
    }
}

private struct ToastBackgroundConfigurationKey: EnvironmentKey {
    static let defaultValue: ToastBackgroundConfiguration = .default
}

enum ToastBackgroundOverride: Sendable {
    case none
    case shapeStyle
    case custom
}

private struct ToastBackgroundOverrideKey: EnvironmentKey {
    static let defaultValue: ToastBackgroundOverride = .none
}

extension EnvironmentValues {
    var toastBackgroundConfiguration: ToastBackgroundConfiguration {
        get { self[ToastBackgroundConfigurationKey.self] }
        set { self[ToastBackgroundConfigurationKey.self] = newValue }
    }
    
    var toastBackgroundOverride: ToastBackgroundOverride {
        get { self[ToastBackgroundOverrideKey.self] }
        set { self[ToastBackgroundOverrideKey.self] = newValue }
    }
}

public extension View {
    func toastBackground<V: View>(
        alignment: Alignment = .center,
        @ViewBuilder content: () -> V
    ) -> some View {
        self.modifier(ToastBackgroundContentModifier(alignment: alignment, background: content))
    }
    
    func toastBackground<S: ShapeStyle>(
        _ style: S
    ) -> some View {
        self.modifier(ToastBackgroundShapeStyleModifier(style: style))
    }
}

struct ToastBackgroundContentModifier<Background: View>: ViewModifier {
    let alignment: Alignment
    let background: Background
    
    init(alignment: Alignment, @ViewBuilder background: () -> Background) {
        self.alignment = alignment
        self.background = background()
    }
    
    func body(content: Content) -> some View {
        content
            .background(alignment: alignment) {
                background
            }
            .environment(\.toastBackgroundOverride, .custom)
    }
}

struct ToastBackgroundShapeStyleModifier<Style: ShapeStyle>: ViewModifier {
    @Environment(\.toastBackgroundConfiguration) private var configuration
    let style: Style
    
    func body(content: Content) -> some View {
        let shape = configuration.shape
        content
            .padding(.horizontal, 16)
            .background {
                Rectangle()
                    .fill(style)
            }
            .clipShape(shape)
            .toastApplyStrokeIfNeeded(shape: shape, configuration: configuration)
            .toastApplyShadowIfNeeded(configuration: configuration)
            .environment(\.toastBackgroundOverride, .shapeStyle)
    }
}

struct ToastBackgroundWrapper: ViewModifier {
    let configuration: ToastBackgroundConfiguration
    let applyHorizontalPadding: Bool
    @Environment(\.toastBackgroundOverride) private var toastBackgroundOverride
    
    func body(content: Content) -> some View {
        switch toastBackgroundOverride {
        case .custom, .shapeStyle:
            content
            
        case .none:
            let shape = configuration.shape
            
            let base = content
                .padding(configuration.padding)
                .toastApplyBaseBackgroundIfNeeded(configuration: configuration, shape: shape)
                .clipShape(shape)

            let styled = base
                .toastApplyGlassEffectIfNeeded(shape: shape, configuration: configuration)
                .toastApplyStrokeIfNeeded(shape: shape, configuration: configuration)
                .toastApplyShadowIfNeeded(configuration: configuration)
            
            if applyHorizontalPadding {
                styled.padding(.horizontal)
            } else {
                styled
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func toastApplyBaseBackgroundIfNeeded(
        configuration: ToastBackgroundConfiguration,
        shape: AnyShape
    ) -> some View {
#if compiler(>=6.2)
        if #available(iOS 26.0, *),
           configuration.glassEffect != .disabled {
            self
        } else {
            self.background(configuration.style, in: shape)
        }
#else
        self.background(configuration.style, in: shape)
#endif
    }

    @ViewBuilder
    func toastApplyGlassEffectIfNeeded(
        shape: AnyShape,
        configuration: ToastBackgroundConfiguration
    ) -> some View {
#if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            switch configuration.glassEffect {
            case .disabled:
                self
            case .automatic:
                self.glassEffect(.regular, in: shape)
            case .clear:
                self.glassEffect(.clear, in: shape)
            case .regular:
                self.glassEffect(.regular, in: shape)
            case .regularInteractive:
                self.glassEffect(.regular.interactive(), in: shape)
            case .clearInteractive:
                self.glassEffect(.clear.interactive(), in: shape)
            }
        } else {
            self
        }
#else
        self
#endif
    }

    @ViewBuilder
    func toastApplyStrokeIfNeeded(
        shape: AnyShape,
        configuration: ToastBackgroundConfiguration
    ) -> some View {
        if let stroke = configuration.strokeStyle {
            self.overlay {
                shape.stroke(stroke, lineWidth: 1)
            }
        } else {
            self
        }
    }

    @ViewBuilder
    func toastApplyShadowIfNeeded(
        configuration: ToastBackgroundConfiguration
    ) -> some View {
        if let shadow = configuration.shadow {
            self.shadow(
                color: shadow.color,
                radius: shadow.radius,
                x: shadow.x,
                y: shadow.y
            )
        } else {
            self
        }
    }
}
