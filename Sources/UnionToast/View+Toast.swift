//
//  View+Toast.swift
//  UnionToast
//
//  Created by Ben Sage on 8/24/25.
//

import SwiftUI

public extension View {

    /// Present a toast with custom SwiftUI content
    ///
    /// - Parameters:
    ///   - isPresented: A binding that controls whether the toast is presented
    ///   - dismissDelay: The duration before the toast automatically dismisses (default: 6.5 seconds)
    ///   - content: A SwiftUI view builder that creates the toast content
    /// - Returns: A view with the toast modifier applied
    ///
    /// Example:
    /// ```swift
    /// .toast(isPresented: $showToast, dismissDelay: .seconds(3)) {
    ///     Text("Hello, World!")
    ///         .padding()
    ///         .background(.blue)
    ///         .cornerRadius(8)
    /// }
    /// ```
    func toast<Content: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        dismissDelay: Duration? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(ToastModifier(isPresented: isPresented, dismissDelay: dismissDelay, onDismiss: onDismiss, toastContent: content))
    }
}
