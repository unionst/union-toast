//
//  ToastModifier.swift
//  union-toast
//
//  Created by Ben Sage on 8/24/25.
//

import SwiftUI

struct ToastModifier<ToastContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let dismissDelay: Duration?
    let onDismiss: (() -> Void)?
    let toastContent: () -> ToastContent

    @State private var hasConfiguredOverlay = false
    @State private var sceneDelegate: ToastSceneDelegate?
    @State private var toastManager: ToastManager?

    func body(content: Content) -> some View {
        content
            .onAppear {
                configureToastOverlay()
            }
            .onChange(of: isPresented) {
                if isPresented {
                    sceneDelegate?.updateOverlay(content: toastContent)
                    showToast()
                } else {
                    hideToast()
                }
            }
            .onChange(of: toastManager?.isShowing == false) { _, hidden in
                if hidden {
                    isPresented = false
                }
            }
    }

    private func configureToastOverlay() {
        guard !hasConfiguredOverlay else { return }
        hasConfiguredOverlay = true

        // Try multiple methods to find the active window scene
        var windowScene: UIWindowScene?

        // Method 1: Find the active window scene from connected scenes
        windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }

        // Method 2: If no active scene, try any foreground scene
        if windowScene == nil {
            windowScene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundInactive }
        }

        // Method 3: Fallback to any window scene
        if windowScene == nil {
            windowScene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first
        }

        // Method 4: Try to get from key window (deprecated but might work)
        if windowScene == nil {
            windowScene = UIApplication.shared.windows.first?.windowScene
        }

        guard let scene = windowScene else {
            print("🍞 ToastModifier: Couldn't find window scene")
            return
        }

        let delegate = ToastSceneDelegate()
        delegate.configure(with: scene)
        let manager = delegate.addOverlay(dismissDelay: dismissDelay, onDismiss: onDismiss, content: toastContent)

        sceneDelegate = delegate
        toastManager = manager
    }
    
    private func showToast() {
        toastManager?.show()
    }

    private func hideToast() {
        toastManager?.dismiss()
    }
}
