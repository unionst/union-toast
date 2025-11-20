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

    private var maxTrackedPresentations: Int = 10

    private var sceneDelegate: ToastSceneDelegate?
    private var toastManager: ToastManager?
    private var lastContent: (() -> any View)?
    private var pendingShowTask: Task<Void, Never>?
    private var presentationDismissHandlers: [(id: UUID, handler: () -> Void)] = []

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

    /// Presents a toast view immediately (or queues it) using the controller instance.
    /// - Parameters:
    ///   - dismissDelay: Optional override for the auto-dismiss delay.
    ///   - content: View builder describing the toast UI.
    public func show<Content: View>(dismissDelay: Duration? = nil, @ViewBuilder content: @escaping () -> Content) {
        pendingShowTask?.cancel()
        cleanupOldPresentationsIfNeeded()

        let wrappedContent: () -> any View = {
            content()
        }

        guard let manager = ensureManager(
            dismissDelay: dismissDelay,
            initialContent: wrappedContent
        ) else {
            return
        }

        if manager.isShowing {
            performReplacement(using: manager, content: wrappedContent, onDismiss: nil)
        } else {
            manager.enqueueShowAction { [weak self] in
                guard let self else { return }
                self.flushPendingDismissHandlers(preserving: nil)

                self.sceneDelegate?.updateOverlay(contentProvider: wrappedContent)
                self.lastContent = wrappedContent
                self.scheduleShow(for: manager, onDismiss: nil)
            }
        }
    }

    /// Presents a toast that is driven by an identifiable item. Replaces the current toast when a new item arrives.
    /// - Parameters:
    ///   - item: Identifiable, equatable payload that drives the toast content.
    ///   - dismissDelay: Optional override for the auto-dismiss timing.
    ///   - onDismiss: Callback invoked when the toast associated with `item` dismisses.
    ///   - content: View builder that renders the toast from the supplied item.
    public func show<Item: Identifiable & Equatable, ToastContent: View>(
        item: Item,
        dismissDelay: Duration? = nil,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> ToastContent
    ) {
        pendingShowTask?.cancel()
        cleanupOldPresentationsIfNeeded()

        let wrappedContent: () -> any View = {
            content(item)
        }

        guard let manager = ensureManager(
            dismissDelay: dismissDelay,
            initialContent: wrappedContent
        ) else {
            return
        }

        if manager.isShowing {
            performReplacement(using: manager, content: wrappedContent, onDismiss: onDismiss)
        } else {
            manager.enqueueShowAction { [weak self] in
                guard let self else { return }
                self.flushPendingDismissHandlers(preserving: nil)

                self.sceneDelegate?.updateOverlay(contentProvider: wrappedContent)
                self.lastContent = wrappedContent
                self.scheduleShow(for: manager, onDismiss: onDismiss)
            }
        }
    }

    /// Dismisses the currently visible toast, if any, without destroying the overlay.
    public func dismiss() {
        pendingShowTask?.cancel()
        pendingShowTask = nil
        flushPendingDismissHandlers(preserving: toastManager?.presentationID)
        toastManager?.dismiss()
    }

    /// Removes the overlay window and clears all pending toasts/handlers.
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
    /// Presents a toast using the shared controller instance.
    /// - Parameters:
    ///   - dismissDelay: Optional override for how long the toast remains visible before auto-dismiss.
    ///   - content: View builder describing the toast's contents.
    static func show<Content: View>(dismissDelay: Duration? = nil, @ViewBuilder content: @escaping () -> Content) {
        shared.show(dismissDelay: dismissDelay, content: content)
    }

    /// Presents a toast and plays the supplied haptic feedback before showing it.
    /// - Parameters:
    ///   - dismissDelay: Optional override for the auto-dismiss duration.
    ///   - haptic: Feedback type to play just before the toast appears.
    ///   - content: View builder describing the toast.
    static func showWithHaptic<Content: View>(dismissDelay: Duration? = nil, haptic: SensoryFeedback = .success, @ViewBuilder content: @escaping () -> Content) {
        Haptics.play(haptic)
        Self.show(dismissDelay: dismissDelay, content: content)
    }

    /// Presents a toast driven by an identifiable item. Calling with a new item replaces the existing toast.
    /// - Parameters:
    ///   - item: Identifiable, equatable value representing the toast payload.
    ///   - dismissDelay: Optional override for how long the toast stays visible.
    ///   - onDismiss: Closure invoked after the toast tied to `item` dismisses.
    ///   - content: View builder that renders the toast for the supplied item.
    static func show<Item: Identifiable & Equatable, ToastContent: View>(
        item: Item,
        dismissDelay: Duration? = nil,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> ToastContent
    ) {
        shared.show(item: item, dismissDelay: dismissDelay, onDismiss: onDismiss, content: content)
    }
    
    /// Dismisses the currently presented toast, if any.
    static func dismiss() {
        shared.dismiss()
    }
    
    /// Removes the overlay window entirely, clearing any pending content and timers.
    static func remove() {
        shared.remove()
    }
}

// MARK: - Private helpers
private extension ToastController {
    func ensureManager(
        dismissDelay: Duration?,
        initialContent: @escaping () -> any View
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
                },
                contentProvider: initialContent
            )
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
                presentationDismissHandlers.append((id: manager.presentationID, handler: onDismiss))
            }

            pendingShowTask = nil
        }
    }

    func handleManagerDismiss(for presentationID: UUID) {
        pendingShowTask?.cancel()
        pendingShowTask = nil

        if let index = presentationDismissHandlers.firstIndex(where: { $0.id == presentationID }) {
            let handler = presentationDismissHandlers.remove(at: index).handler
            handler()
        }

        if toastManager?.isShowing == false {
            lastContent = nil
        }
    }

    func flushPendingDismissHandlers(preserving activeID: UUID?) {
        let handlersToFlush = presentationDismissHandlers.filter { entry in
            guard let activeID else { return true }
            return entry.id != activeID
        }

        for entry in handlersToFlush {
            entry.handler()
        }

        presentationDismissHandlers.removeAll { entry in
            guard let activeID else { return true }
            return entry.id != activeID
        }
    }

    private func cleanupOldPresentationsIfNeeded() {
        guard presentationDismissHandlers.count > maxTrackedPresentations else { return }

        // Remove oldest 50% when limit reached
        let keepCount = maxTrackedPresentations / 2
        presentationDismissHandlers.removeFirst(presentationDismissHandlers.count - keepCount)
    }

    func performReplacement(
        using manager: ToastManager,
        content: @escaping () -> any View,
        onDismiss: (() -> Void)?
    ) {
        manager.enqueueReplacementAction { [weak self] in
            guard let self else { return }
            guard let replacementID = manager.beginReplacement() else {
                return
            }

            self.flushPendingDismissHandlers(preserving: replacementID)

            self.sceneDelegate?.updateOverlayWithPrevious(
                previousContent: self.lastContent ?? content,
                newContent: content,
                replacementID: replacementID
            )

            if let onDismiss {
                self.presentationDismissHandlers.append((id: replacementID, handler: onDismiss))
            }

            self.lastContent = content
        }
    }
}
