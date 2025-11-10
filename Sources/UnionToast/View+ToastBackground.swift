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
    public var shadow: Shadow?
    
    public static func == (lhs: ToastBackgroundConfiguration, rhs: ToastBackgroundConfiguration) -> Bool {
        lhs.padding == rhs.padding &&
        lhs.glassEffect == rhs.glassEffect &&
        lhs.shadow == rhs.shadow
    }
    
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
            shadow: configuration.shadow
        )
        
        content
            .preference(key: ToastBackgroundOverridePreferenceKey.self, value: .shapeStyle(modifiedConfig))
    }
}

struct ConditionalToastBackgroundWrapper: ViewModifier {
    @Environment(\.toastBackgroundConfiguration) private var defaultConfiguration
    @State private var override: ToastBackgroundOverride = .none
    
    func body(content: Content) -> some View {
        Group {
            switch override {
            case .custom:
                content
                
            case .shapeStyle(let config):
                applyBackground(to: content, configuration: config)
                
            case .none:
                applyBackground(to: content, configuration: defaultConfiguration)
            }
        }
        .onPreferenceChange(ToastBackgroundOverridePreferenceKey.self) { value in
            override = value
        }
    }
    
    @ViewBuilder
    private func applyBackground(to content: Content, configuration: ToastBackgroundConfiguration) -> some View {
        let shape = configuration.shape
        
        let base = content
            .padding(configuration.padding)
            .toastApplyBaseBackgroundIfNeeded(configuration: configuration, shape: shape)
            .clipShape(shape)

        base
            .toastApplyGlassEffectIfNeeded(shape: shape, configuration: configuration)
            .toastApplyStrokeIfNeeded(shape: shape, configuration: configuration)
            .toastApplyShadowIfNeeded(configuration: configuration)
            .padding(.horizontal)
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
