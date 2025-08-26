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
    
    func configure(with windowScene: UIWindowScene) {
        self.windowScene = windowScene
    }
    
    func addOverlay<Content: View>(@ViewBuilder content: @escaping () -> Content) -> ToastManager {
        guard let scene = windowScene else {
            print("🍞 ToastSceneDelegate: No window scene available")
            return ToastManager()
        }
        
        // Remove existing overlay if present
        if overlayWindow != nil {
            print("🍞 ToastSceneDelegate: Removing existing overlay")
            removeOverlay()
        }

        let manager = ToastManager()
        self.toastManager = manager
        
        let hostingController = UIHostingController(
            rootView: ToastOverlayView { content() }
                .environment(manager)
        )
        hostingController.view.backgroundColor = .clear

        let passthroughOverlayWindow = PassThroughWindow(windowScene: scene)
        passthroughOverlayWindow.windowLevel = .alert + 1000
        passthroughOverlayWindow.rootViewController = hostingController
        passthroughOverlayWindow.isHidden = false
        passthroughOverlayWindow.isUserInteractionEnabled = true



        self.overlayWindow = passthroughOverlayWindow
        return manager
    }
    
    func removeOverlay() {
        overlayWindow?.isHidden = true
        overlayWindow = nil
        toastManager = nil
    }
}
