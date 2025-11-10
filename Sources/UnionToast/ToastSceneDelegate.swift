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
    
    func addOverlay<Content: View>(
        dismissDelay: Duration? = nil,
        onDismiss: ((UUID) -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> ToastManager {
        addOverlay(
            dismissDelay: dismissDelay,
            onDismiss: onDismiss,
            contentProvider: { content() }
        )
    }

    func addOverlay(
        dismissDelay: Duration? = nil,
        onDismiss: ((UUID) -> Void)? = nil,
        contentProvider: @escaping () -> any View
    ) -> ToastManager {
        guard let scene = windowScene else {
            print("🍞 ToastSceneDelegate: No window scene available")
            if let dismissDelay {
                return ToastManager(dismissDelay: dismissDelay, onDismiss: onDismiss)
            }
            return ToastManager(onDismiss: onDismiss)
        }

        if overlayWindow != nil {
            print("🍞 ToastSceneDelegate: Removing existing overlay")
            removeOverlay()
        }

        let manager: ToastManager
        if let dismissDelay {
            manager = ToastManager(dismissDelay: dismissDelay, onDismiss: onDismiss)
        } else {
            manager = ToastManager(onDismiss: onDismiss)
        }
        self.toastManager = manager
        
        let hosting = UIHostingController(
            rootView: ToastOverlayView(
                manager: manager,
                content: contentProvider
            )
        )
        hosting.view.backgroundColor = .clear

        let passthroughOverlayWindow = PassThroughWindow(windowScene: scene)
        passthroughOverlayWindow.windowLevel = .alert + 10
        passthroughOverlayWindow.rootViewController = hosting
        passthroughOverlayWindow.isHidden = false
        passthroughOverlayWindow.isUserInteractionEnabled = true
        
        // Force layout pass to pre-render the view hierarchy
        hosting.view.setNeedsLayout()
        hosting.view.layoutIfNeeded()
        
        // Also force display to ensure any CALayers are rendered
        hosting.view.setNeedsDisplay()
        let layer = hosting.view.layer.presentation() ?? hosting.view.layer
        layer.setNeedsDisplay()
        layer.displayIfNeeded()

        self.overlayWindow = passthroughOverlayWindow
        self.hostingController = hosting
        return manager
    }
    
    func updateOverlay<Content: View>(
        previousContent: (() -> any View)? = nil,
        replacementPresentationID: UUID? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        updateOverlay(
            previousContent: previousContent,
            replacementPresentationID: replacementPresentationID,
            contentProvider: { content() }
        )
    }

    func updateOverlay(
        previousContent: (() -> any View)? = nil,
        replacementPresentationID: UUID? = nil,
        contentProvider: @escaping () -> any View
    ) {
        guard let manager = toastManager,
              let overlayWindow = overlayWindow else {
            return
        }

        let hosting = UIHostingController(
            rootView: ToastOverlayView(
                manager: manager,
                previousContent: previousContent,
                replacementPresentationID: replacementPresentationID,
                content: contentProvider
            )
        )
        hosting.view.backgroundColor = .clear

        overlayWindow.rootViewController = hosting
        self.hostingController = hosting

        hosting.view.setNeedsLayout()
        hosting.view.layoutIfNeeded()
    }

    func updateOverlayWithPrevious<Previous: View, Next: View>(
        previousContent: @escaping () -> Previous,
        newContent: @escaping () -> Next,
        replacementID: UUID
    ) {
        updateOverlayWithPrevious(
            previousContent: { previousContent() },
            newContent: { newContent() },
            replacementID: replacementID
        )
    }

    func updateOverlayWithPrevious(
        previousContent: @escaping () -> any View,
        newContent: @escaping () -> any View,
        replacementID: UUID
    ) {
        guard let manager = toastManager,
              let overlayWindow = overlayWindow else {
            return
        }

        let hosting = UIHostingController(
            rootView: ToastOverlayView(
                manager: manager,
                previousContent: previousContent,
                replacementPresentationID: replacementID,
                content: newContent
            )
        )
        hosting.view.backgroundColor = .clear

        overlayWindow.rootViewController = hosting
        self.hostingController = hosting

        hosting.view.setNeedsLayout()
        hosting.view.layoutIfNeeded()
    }

    func removeOverlay() {
        overlayWindow?.isHidden = true
        overlayWindow = nil
        toastManager = nil
        hostingController = nil
    }
}
