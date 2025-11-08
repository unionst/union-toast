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
        shape: AnyShape = AnyShape(RoundedRectangle(cornerRadius: 24, style: .continuous)),
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

extension EnvironmentValues {
    var toastBackgroundConfiguration: ToastBackgroundConfiguration {
        get { self[ToastBackgroundConfigurationKey.self] }
        set { self[ToastBackgroundConfigurationKey.self] = newValue }
    }
}

public extension View {
    func toastBackground(
        _ style: AnyShapeStyle,
        shape: AnyShape = AnyShape(RoundedRectangle(cornerRadius: 24, style: .continuous)),
        glassEffect: ToastBackgroundConfiguration.GlassEffectOption = .automatic,
        stroke: AnyShapeStyle? = nil,
        padding: EdgeInsets? = nil,
        shadow: ToastBackgroundConfiguration.Shadow? = ToastBackgroundConfiguration.default.shadow
    ) -> some View {
        var configuration = ToastBackgroundConfiguration.default
        configuration.style = style
        configuration.shape = shape
        configuration.glassEffect = glassEffect
        configuration.strokeStyle = stroke ?? configuration.strokeStyle
        if let padding {
            configuration.padding = padding
        }
        configuration.shadow = shadow
        return environment(\.toastBackgroundConfiguration, configuration)
    }
    
    func toastBackground<Style: ShapeStyle, ShapeType: Shape>(
        _ style: Style,
        shape: ShapeType,
        glassEffect: ToastBackgroundConfiguration.GlassEffectOption = .automatic,
        stroke: Style? = nil,
        padding: EdgeInsets? = nil,
        shadow: ToastBackgroundConfiguration.Shadow? = ToastBackgroundConfiguration.default.shadow
    ) -> some View {
        toastBackground(
            AnyShapeStyle(style),
            shape: AnyShape(shape),
            glassEffect: glassEffect,
            stroke: stroke.map(AnyShapeStyle.init),
            padding: padding,
            shadow: shadow
        )
    }
    
    func toastBackground<Style: ShapeStyle>(
        _ style: Style,
        glassEffect: ToastBackgroundConfiguration.GlassEffectOption = .automatic,
        stroke: Style? = nil,
        padding: EdgeInsets? = nil,
        shadow: ToastBackgroundConfiguration.Shadow? = ToastBackgroundConfiguration.default.shadow
    ) -> some View {
        toastBackground(
            AnyShapeStyle(style),
            shape: AnyShape(RoundedRectangle(cornerRadius: 24, style: .continuous)),
            glassEffect: glassEffect,
            stroke: stroke.map(AnyShapeStyle.init),
            padding: padding,
            shadow: shadow
        )
    }
}

struct ToastBackgroundWrapper: ViewModifier {
    let configuration: ToastBackgroundConfiguration
    
    func body(content: Content) -> some View {
        let shape = configuration.shape
        
        let base = content
            .frame(maxWidth: .infinity)
            .padding(configuration.padding)
            .toastApplyBaseBackgroundIfNeeded(configuration: configuration, shape: shape)
            .clipShape(shape)

        base
            .toastApplyGlassEffectIfNeeded(shape: shape, configuration: configuration)
            .toastApplyStrokeIfNeeded(shape: shape, configuration: configuration)
            .toastApplyShadowIfNeeded(configuration: configuration)
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
