//
//  ToastModifier.swift
//  union-toast
//
//  Created by Ben Sage on 8/24/25.
//

import SwiftUI

struct ToastModifier<ToastContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let content: () -> ToastContent

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

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first ?? UIApplication.shared.windows.first?.windowScene else {
            print("Couldn't find window scene")
            return
        }

        let delegate = ToastSceneDelegate()
        delegate.configure(with: windowScene)
        let manager = delegate.addOverlay(content: content)

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
