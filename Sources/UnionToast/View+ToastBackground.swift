//
//  View+ToastBackground.swift
//  UnionToast
//
//  Created by Union on 11/8/25.
//

import SwiftUI

public struct ToastBackgroundConfiguration: Sendable, Equatable {
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
    public var glassTint: Color?
    public var shadow: Shadow?
    
    public static func == (lhs: ToastBackgroundConfiguration, rhs: ToastBackgroundConfiguration) -> Bool {
        lhs.padding == rhs.padding &&
        lhs.glassEffect == rhs.glassEffect &&
        lhs.glassTint == rhs.glassTint &&
        lhs.shadow == rhs.shadow
    }
    
    public init(
        style: AnyShapeStyle,
        strokeStyle: AnyShapeStyle? = nil,
        shape: AnyShape = AnyShape(Capsule()),
        padding: EdgeInsets = EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16),
        glassEffect: GlassEffectOption = .automatic,
        glassTint: Color? = nil,
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
        self.glassTint = glassTint
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

enum ToastBackgroundOverride: Sendable, Equatable {
    case none
    case shapeStyle(ToastBackgroundConfiguration)
    case custom
}

private struct ToastBackgroundOverridePreferenceKey: PreferenceKey {
    static let defaultValue: ToastBackgroundOverride = .none
    
    static func reduce(value: inout ToastBackgroundOverride, nextValue: () -> ToastBackgroundOverride) {
        let next = nextValue()
        if next != .none {
            value = next
        }
    }
}

extension EnvironmentValues {
    var toastBackgroundConfiguration: ToastBackgroundConfiguration {
        get { self[ToastBackgroundConfigurationKey.self] }
        set { self[ToastBackgroundConfigurationKey.self] = newValue }
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
    
    func toastBackground(_ tint: Color) -> some View {
        self.modifier(ToastBackgroundTintModifier(tint: tint))
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
            .preference(key: ToastBackgroundOverridePreferenceKey.self, value: .custom)
    }
}

struct ToastBackgroundShapeStyleModifier<Style: ShapeStyle>: ViewModifier {
    @Environment(\.toastBackgroundConfiguration) private var configuration
    let style: Style

    func body(content: Content) -> some View {
        let modifiedConfig = ToastBackgroundConfiguration(
            style: AnyShapeStyle(style),
            strokeStyle: configuration.strokeStyle,
            shape: configuration.shape,
            padding: configuration.padding,
            glassEffect: configuration.glassEffect,
            glassTint: configuration.glassTint,
            shadow: configuration.shadow
        )

        content
            .preference(key: ToastBackgroundOverridePreferenceKey.self, value: .shapeStyle(modifiedConfig))
    }
}

struct ToastBackgroundTintModifier: ViewModifier {
    @Environment(\.toastBackgroundConfiguration) private var configuration
    let tint: Color

    func body(content: Content) -> some View {
        let modifiedConfig = ToastBackgroundConfiguration(
            style: AnyShapeStyle(Color.clear),
            strokeStyle: nil,
            shape: configuration.shape,
            padding: configuration.padding,
            glassEffect: .automatic,
            glassTint: tint,
            shadow: configuration.shadow
        )

        content
            .preference(key: ToastBackgroundOverridePreferenceKey.self, value: .shapeStyle(modifiedConfig))
    }
}

struct ConditionalToastBackgroundWrapper: ViewModifier {
    @Environment(\.toastBackgroundConfiguration) private var defaultConfiguration

    func body(content: Content) -> some View {
        content
            .padding(defaultConfiguration.padding)
            .clipShape(defaultConfiguration.shape)
            .backgroundPreferenceValue(ToastBackgroundOverridePreferenceKey.self) { override in
                ToastBackgroundView(override: override, defaultConfiguration: defaultConfiguration)
            }
            .padding(.horizontal)
    }
}

private struct ToastBackgroundView: View {
    let override: ToastBackgroundOverride
    let defaultConfiguration: ToastBackgroundConfiguration
    
    var body: some View {
        let config: ToastBackgroundConfiguration? = {
            switch override {
            case .custom:
                return nil
            case .shapeStyle(let c):
                return c
            case .none:
                return defaultConfiguration
            }
        }()
        
        if let config {
            GeometryReader { geo in
                config.shape.fill(config.style)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .toastApplyGlassEffectIfNeeded(shape: config.shape, configuration: config)
                    .toastApplyShadowIfNeeded(configuration: config)
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
        self.background(configuration.style, in: shape)
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
                self.glassEffect(.regular.interactive().tint(configuration.glassTint ?? .white.opacity(0)), in: shape)
            case .clear:
                self.glassEffect(.clear.tint(configuration.glassTint ?? .white.opacity(0)), in: shape)
            case .regular:
                self.glassEffect(.regular.tint(configuration.glassTint ?? .white.opacity(0)), in: shape)
            case .regularInteractive:
                self.glassEffect(.regular.interactive().tint(configuration.glassTint ?? .white.opacity(0)), in: shape)
            case .clearInteractive:
                self.glassEffect(.clear.interactive().tint(configuration.glassTint ?? .white.opacity(0)), in: shape)
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
