//
//  ToastController.swift
//  union-toast
//
//  Created by Ben Sage on 8/26/25.
//

import SwiftUI
import UIKit
import UnionHaptics

@MainActor
public final class ToastController: NSObject {
    public static let shared = ToastController()
    
    private var sceneDelegate: ToastSceneDelegate?
    private var toastManager: ToastManager?

    private override init() {
        super.init()
    }

    private func setupToastOverlay() {
        let connectedScenes = UIApplication.shared.connectedScenes
        
        guard let windowScene = connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else { 
                return 
            }
        
        let delegate = ToastSceneDelegate()
        delegate.configure(with: windowScene)

        self.sceneDelegate = delegate
    }

    public func show<Content: View>(@ViewBuilder content: @escaping () -> Content) {
        // Ignore if a toast is already showing
        if toastManager?.isShowing == true {
            return
        }
        
        // Setup overlay if not already done
        if sceneDelegate == nil {
            setupToastOverlay()
        }
        
        guard let sceneDelegate = sceneDelegate else { 
            return 
        }
        
        // Dismiss any existing toast first
        toastManager?.dismiss()
        
        // Small delay to ensure clean state, then create new overlay
        Task {
            try? await Task.sleep(for: .milliseconds(16)) // One frame at 60fps
            await MainActor.run {
                sceneDelegate.removeOverlay()
                toastManager = sceneDelegate.addOverlay(content: content)
                
                // Minimal delay for view setup, then show
                Task {
                    try? await Task.sleep(for: .milliseconds(16)) // One more frame
                    await MainActor.run {
                        toastManager?.show()
                    }
                }
            }
        }
    }

    public func forceShow<Content: View>(@ViewBuilder content: @escaping () -> Content) {
        // Force show by temporarily bypassing the isShowing check
        let wasShowing = toastManager?.isShowing
        toastManager?.dismiss()
        
        // Setup overlay if not already done
        if sceneDelegate == nil {
            setupToastOverlay()
        }
        
        guard let sceneDelegate = sceneDelegate else { 
            return 
        }
        
        // Small delay to ensure clean state, then create new overlay
        Task {
            try? await Task.sleep(for: .milliseconds(16))
            await MainActor.run {
                sceneDelegate.removeOverlay()
                toastManager = sceneDelegate.addOverlay(content: content)
                
                Task {
                    try? await Task.sleep(for: .milliseconds(16))
                    await MainActor.run {
                        toastManager?.show()
                    }
                }
            }
        }
    }

    public func dismiss() {
        toastManager?.dismiss()
    }

    public func remove() {
        sceneDelegate?.removeOverlay()
        toastManager = nil
    }
}

// MARK: - Convenience Methods
public extension ToastController {
    static func show<Content: View>(@ViewBuilder content: @escaping () -> Content) {
        shared.show(content: content)
    }
    
    static func showWithHaptic<Content: View>(@ViewBuilder content: @escaping () -> Content, haptic: SensoryFeedback = .success) {
        Haptics.play(haptic)
        Self.show(content: content)
    }
    
    /// Force show a toast, dismissing any existing toast first
    static func forceShow<Content: View>(@ViewBuilder content: @escaping () -> Content) {
        shared.forceShow(content: content)
    }
    
    static func dismiss() {
        shared.dismiss()
    }
    
    static func remove() {
        shared.remove()
    }
}
