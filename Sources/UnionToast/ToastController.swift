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
    private var lastContent: (() -> AnyView)?
    private var pendingShowTask: Task<Void, Never>?
    private var presentationDismissHandlers: [UUID: () -> Void] = [:]

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

    public func show<Content: View>(dismissDelay: Duration? = nil, @ViewBuilder content: @escaping () -> Content) {
        guard toastManager?.isShowing != true else { return }

        let wrappedContent: () -> AnyView = {
            AnyView(content())
        }

        guard let manager = ensureManager(
            dismissDelay: dismissDelay,
            initialContent: wrappedContent
        ) else {
            return
        }

        flushPendingDismissHandlers(preserving: manager.isShowing ? manager.presentationID : nil)

        sceneDelegate?.updateOverlay {
            wrappedContent()
        }

        lastContent = wrappedContent
        scheduleShow(for: manager, onDismiss: nil)
    }

    public func forceShow<Content: View>(dismissDelay: Duration? = nil, @ViewBuilder content: @escaping () -> Content) {
        remove()
        show(dismissDelay: dismissDelay, content: content)
    }

    public func show<Item: Identifiable & Equatable, ToastContent: View>(
        item: Item,
        dismissDelay: Duration? = nil,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> ToastContent
    ) {
        pendingShowTask?.cancel()

        let wrappedContent: () -> AnyView = {
            AnyView(content(item))
        }

        guard let manager = ensureManager(
            dismissDelay: dismissDelay,
            initialContent: wrappedContent
        ) else {
            return
        }

        flushPendingDismissHandlers(preserving: manager.isShowing ? manager.presentationID : nil)

        if manager.isShowing {
            let previousContent = lastContent
            let replacementID = manager.beginReplacement()

            sceneDelegate?.updateOverlay(
                previousContent: previousContent,
                replacementPresentationID: replacementID
            ) {
                wrappedContent()
            }

            if let replacementID, let onDismiss {
                presentationDismissHandlers[replacementID] = onDismiss
            }

            lastContent = wrappedContent
        } else {
            sceneDelegate?.updateOverlay {
                wrappedContent()
            }
            lastContent = wrappedContent
            scheduleShow(for: manager, onDismiss: onDismiss)
        }
    }

    public func dismiss() {
        pendingShowTask?.cancel()
        pendingShowTask = nil
        flushPendingDismissHandlers(preserving: toastManager?.presentationID)
        toastManager?.dismiss()
    }

    public func remove() {
        pendingShowTask?.cancel()
        pendingShowTask = nil
        flushPendingDismissHandlers(preserving: nil)
        sceneDelegate?.removeOverlay()
        toastManager = nil
        lastContent = nil
        presentationDismissHandlers.removeAll()
    }
}

// MARK: - Convenience Methods
public extension ToastController {
    static func show<Content: View>(dismissDelay: Duration? = nil, @ViewBuilder content: @escaping () -> Content) {
        shared.show(dismissDelay: dismissDelay, content: content)
    }

    static func showWithHaptic<Content: View>(dismissDelay: Duration? = nil, haptic: SensoryFeedback = .success, @ViewBuilder content: @escaping () -> Content) {
        Haptics.play(haptic)
        Self.show(dismissDelay: dismissDelay, content: content)
    }

    /// Force show a toast, dismissing any existing toast first
    static func forceShow<Content: View>(dismissDelay: Duration? = nil, @ViewBuilder content: @escaping () -> Content) {
        shared.forceShow(dismissDelay: dismissDelay, content: content)
    }

    static func show<Item: Identifiable & Equatable, ToastContent: View>(
        item: Item,
        dismissDelay: Duration? = nil,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> ToastContent
    ) {
        shared.show(item: item, dismissDelay: dismissDelay, onDismiss: onDismiss, content: content)
    }
    
    static func dismiss() {
        shared.dismiss()
    }
    
    static func remove() {
        shared.remove()
    }
}

// MARK: - Private helpers
private extension ToastController {
    func ensureManager(
        dismissDelay: Duration?,
        initialContent: @escaping () -> AnyView
    ) -> ToastManager? {
        if sceneDelegate == nil {
            setupToastOverlay()
        }

        guard let sceneDelegate = sceneDelegate else {
            return nil
        }

        if toastManager == nil {
            toastManager = sceneDelegate.addOverlay(
                dismissDelay: dismissDelay,
                onDismiss: { [weak self] presentationID in
                    self?.handleManagerDismiss(for: presentationID)
                }
            ) {
                initialContent()
            }
        }

        return toastManager
    }

    func scheduleShow(for manager: ToastManager, onDismiss: (() -> Void)?) {
        pendingShowTask?.cancel()
        pendingShowTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(16))
            guard !Task.isCancelled else { return }

            manager.show()
            flushPendingDismissHandlers(preserving: manager.presentationID)

            if let onDismiss {
                presentationDismissHandlers[manager.presentationID] = onDismiss
            }

            pendingShowTask = nil
        }
    }

    func handleManagerDismiss(for presentationID: UUID) {
        pendingShowTask?.cancel()
        pendingShowTask = nil

        if let handler = presentationDismissHandlers.removeValue(forKey: presentationID) {
            handler()
        }

        if toastManager?.isShowing == false {
            lastContent = nil
        }
    }

    func flushPendingDismissHandlers(preserving activeID: UUID?) {
        let idsToFlush = presentationDismissHandlers.keys.compactMap { id -> UUID? in
            guard let activeID else { return id }
            return id == activeID ? nil : id
        }

        for id in idsToFlush {
            if let handler = presentationDismissHandlers.removeValue(forKey: id) {
                handler()
            }
        }
    }
}
