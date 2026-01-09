//
//  _ToastExample.swift
//  UnionToast
//
//  Created by Union on 1/8/26.
//

import SwiftUI

/// A comprehensive example view demonstrating all UnionToast features.
///
/// Use this view to test and explore the toast notification system including:
/// - Boolean-based toast presentation
/// - Item-based toast presentation with automatic replacement
/// - Imperative ToastController API
/// - Custom backgrounds and styling
/// - Haptic feedback integration
public struct _ToastExample: View {
    // MARK: - Boolean-based toast state
    @State private var showBasicToast = false
    @State private var showCustomDelayToast = false

    // MARK: - Item-based toast state
    @State private var activeToast: ExampleToast?

    // MARK: - Background examples
    @State private var showTintedToast = false
    @State private var showCustomBackgroundToast = false

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                booleanBasedSection
                itemBasedSection
                controllerSection
                backgroundSection
            }
            .navigationTitle("Toast Examples")
        }
        .toast(isPresented: $showBasicToast) {
            Label("Basic Toast", systemImage: "bell.fill")
        }
        .toast(isPresented: $showCustomDelayToast, dismissDelay: .seconds(2)) {
            Label("Quick Toast (2s)", systemImage: "hare.fill")
        }
        .toast(item: $activeToast) { toast in
            Label(toast.title, systemImage: toast.icon)
                .foregroundStyle(toast.color)
        }
        .toast(isPresented: $showTintedToast) {
            Label("Tinted Background", systemImage: "paintpalette.fill")
                .toastBackground(.blue)
        }
        .toast(isPresented: $showCustomBackgroundToast) {
            Label("Custom Background", systemImage: "square.fill")
                .toastBackground {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.linearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                }
        }
    }

    // MARK: - Sections

    private var booleanBasedSection: some View {
        Section {
            Button("Show Basic Toast") {
                showBasicToast = true
            }

            Button("Show Quick Toast (2s delay)") {
                showCustomDelayToast = true
            }
        } header: {
            Text("Boolean-Based Presentation")
        } footer: {
            Text("Uses .toast(isPresented:) modifier with a binding.")
        }
    }

    private var itemBasedSection: some View {
        Section {
            Button("Success Toast") {
                activeToast = ExampleToast(
                    title: "Success!",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
            }

            Button("Error Toast") {
                activeToast = ExampleToast(
                    title: "Error occurred",
                    icon: "xmark.circle.fill",
                    color: .red
                )
            }

            Button("Warning Toast") {
                activeToast = ExampleToast(
                    title: "Warning",
                    icon: "exclamationmark.triangle.fill",
                    color: .orange
                )
            }

            Button("Info Toast") {
                activeToast = ExampleToast(
                    title: "Information",
                    icon: "info.circle.fill",
                    color: .blue
                )
            }
        } header: {
            Text("Item-Based Presentation")
        } footer: {
            Text("Uses .toast(item:) modifier. New items automatically replace the current toast with choreographed animation.")
        }
    }

    private var controllerSection: some View {
        Section {
            Button("Show via Controller") {
                ToastController.show {
                    Label("Controller Toast", systemImage: "gearshape.fill")
                }
            }

            Button("Show with Haptic (Success)") {
                ToastController.showWithHaptic(haptic: .success) {
                    Label("Success with Haptic", systemImage: "hand.thumbsup.fill")
                }
            }

            Button("Show with Haptic (Warning)") {
                ToastController.showWithHaptic(haptic: .warning) {
                    Label("Warning with Haptic", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }

            Button("Show with Haptic (Error)") {
                ToastController.showWithHaptic(haptic: .error) {
                    Label("Error with Haptic", systemImage: "xmark.octagon.fill")
                        .foregroundStyle(.red)
                }
            }

            Button("Show Long Duration (10s)") {
                ToastController.show(dismissDelay: .seconds(10)) {
                    Label("Long Toast (10s)", systemImage: "clock.fill")
                }
            }

            Button("Dismiss Current Toast", role: .destructive) {
                ToastController.dismiss()
            }
        } header: {
            Text("ToastController (Imperative)")
        } footer: {
            Text("Use ToastController.show() for programmatic toast presentation from anywhere in your app.")
        }
    }

    private var backgroundSection: some View {
        Section {
            Button("Tinted Background (Blue)") {
                showTintedToast = true
            }

            Button("Custom Gradient Background") {
                showCustomBackgroundToast = true
            }

            Button("Material Background via Controller") {
                ToastController.show {
                    Label("Thin Material", systemImage: "rectangle.fill")
                        .toastBackground(.thinMaterial)
                }
            }
        } header: {
            Text("Custom Backgrounds")
        } footer: {
            Text("Customize toast appearance with .toastBackground() modifier.")
        }
    }
}

// MARK: - Example Toast Model

private struct ExampleToast: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
}

// MARK: - Preview

#Preview {
    _ToastExample()
}
