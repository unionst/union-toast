//
//  ToastSceneDelegate.swift
//  UnionToast
//
//  Created by Union on 1/27/25.
//

import UIKit
import SwiftUI

@Observable
@MainActor
class ToastSceneDelegate: NSObject {
    weak var windowScene: UIWindowScene?
    var overlayWindow: PassThroughWindow?
    var toastManager: ToastManager?
    var hostingController: UIViewController?
    
    func configure(with windowScene: UIWindowScene) {
        self.windowScene = windowScene
    }
    
    func addOverlay<Content: View>(dismissDelay: Duration? = nil, @ViewBuilder content: @escaping () -> Content) -> ToastManager {
        guard let scene = windowScene else {
            print("🍞 ToastSceneDelegate: No window scene available")
            return dismissDelay != nil ? ToastManager(dismissDelay: dismissDelay!) : ToastManager()
        }

        // Remove existing overlay if present
        if overlayWindow != nil {
            print("🍞 ToastSceneDelegate: Removing existing overlay")
            removeOverlay()
        }

        let manager = dismissDelay != nil ? ToastManager(dismissDelay: dismissDelay!) : ToastManager()
        self.toastManager = manager
        
        let hosting = UIHostingController(
            rootView: ToastOverlayView(manager: manager, content: content)
        )
        hosting.view.backgroundColor = .clear

        let passthroughOverlayWindow = PassThroughWindow(windowScene: scene)
        passthroughOverlayWindow.windowLevel = .alert + 1000
        passthroughOverlayWindow.rootViewController = hosting
        passthroughOverlayWindow.isHidden = false
        passthroughOverlayWindow.isUserInteractionEnabled = true



        self.overlayWindow = passthroughOverlayWindow
        self.hostingController = hosting
        return manager
    }
    
    func updateOverlay<Content: View>(@ViewBuilder content: @escaping () -> Content) {
        guard let manager = toastManager, let hosting = hostingController as? UIHostingController<ToastOverlayView<Content>> else { return }
        
        hosting.rootView = ToastOverlayView(manager: manager, content: content)
    }
    
    func removeOverlay() {
        overlayWindow?.isHidden = true
        overlayWindow = nil
        toastManager = nil
        hostingController = nil
    }
}
