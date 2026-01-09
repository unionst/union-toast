//
//  View+Toast.swift
//  UnionToast
//
//  Created by Ben Sage on 8/24/25.
//

import SwiftUI

/// The visual style for toast presentation
public enum ToastStyle {
    /// Standard toast that slides down from the top
    case regular
    /// Dynamic Island-style toast that animates from the island on supported devices,
    /// falls back to regular toast on devices without Dynamic Island
    case dynamicIsland
}

public extension View {

    /// Present a toast with custom SwiftUI content
    ///
    /// - Parameters:
    ///   - isPresented: A binding that controls whether the toast is presented
    ///   - style: The visual style for the toast (default: .regular)
    ///   - dismissDelay: The duration before the toast automatically dismisses (default: 6.5 seconds for regular, 3 seconds for dynamicIsland)
    ///   - onDismiss: Optional closure called when the toast dismisses
    ///   - content: A SwiftUI view builder that creates the toast content
    /// - Returns: A view with the toast modifier applied
    ///
    /// Example:
    /// ```swift
    /// .toast(isPresented: $showToast, style: .dynamicIsland) {
    ///     Label("Success!", systemImage: "checkmark.circle.fill")
    /// }
    /// ```
    @ViewBuilder
    func toast<Content: View>(
        isPresented: Binding<Bool>,
        style: ToastStyle = .regular,
        onDismiss: (() -> Void)? = nil,
        dismissDelay: Duration? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        switch style {
        case .regular:
            modifier(ToastModifier(isPresented: isPresented, dismissDelay: dismissDelay, onDismiss: onDismiss, toastContent: content))
        case .dynamicIsland:
            modifier(DynamicIslandToastModifier(
                isPresented: isPresented,
                dismissDelay: dismissDelay ?? .seconds(3),
                onDismiss: onDismiss,
                toastContent: content
            ))
        }
    }

    /// Present a toast using an optional Identifiable item as the data source.
    ///
    /// When `item` becomes non-`nil`, the toast renders the supplied content closure.
    /// When the toast dismisses—either automatically, via swipe, or programmatically—
    /// the binding resets to `nil` and `onDismiss` executes.
    ///
    /// - Parameters:
    ///   - item: A binding to an optional Identifiable & Equatable item
    ///   - style: The visual style for the toast (default: .regular)
    ///   - onDismiss: Optional closure called when the toast dismisses
    ///   - dismissDelay: The duration before the toast automatically dismisses (default: 6.5 seconds)
    ///   - maxTrackedPresentations: Maximum number of presentations to track before cleanup (default: 10)
    ///   - content: A SwiftUI view builder that creates the toast content from the item
    func toast<Item, Content>(
        item: Binding<Item?>,
        style: ToastStyle = .regular,
        onDismiss: (() -> Void)? = nil,
        dismissDelay: Duration? = nil,
        maxTrackedPresentations: Int = 10,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View where Item: Identifiable & Equatable, Content: View {
        modifier(ToastItemModifier(
            item: item,
            dismissDelay: dismissDelay,
            onDismiss: onDismiss,
            toastContent: content,
            maxTrackedPresentations: maxTrackedPresentations
        ))
    }

}
