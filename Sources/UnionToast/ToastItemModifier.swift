//
//  ToastItemModifier.swift
//  UnionToast
//
//  Created by Rudrank Riyam on 11/8/25.
//

import SwiftUI

struct ToastItemModifier<Item, ToastContent: View>: ViewModifier where Item: Identifiable & Equatable {
    @Binding var item: Item?
    let dismissDelay: Duration?
    let onDismiss: (() -> Void)?
    let toastContent: (Item) -> ToastContent

    @State private var hasConfiguredOverlay = false
    @State private var sceneDelegate: ToastSceneDelegate?
    @State private var toastManager: ToastManager?
    @State private var presentationToItemID: [(presentationID: UUID, itemID: Item.ID)] = []
    @State private var pendingShowTask: Task<Void, Never>?
    @State private var lastPresentedItem: Item?
    @State private var pendingReplacementItem: Item?
    @State private var replacementTransitionTask: Task<Void, Never>?
    @State private var isHandlingChange = false

    private let maxTrackedPresentations = 100

    func body(content: Content) -> some View {
        content
            .onAppear {
                configureToastOverlay()
            }
            .onChange(of: item) { _, newValue in
                handleItemChange(newValue)
            }
    }

    private func handleItemChange(_ newItem: Item?) {
        guard !isHandlingChange else { return }
        isHandlingChange = true
        defer { isHandlingChange = false }

        if !hasConfiguredOverlay {
            configureToastOverlay()
        }

        cleanupOldPresentationsIfNeeded()

        guard let delegate = sceneDelegate else {
            return
        }

        guard let newItem else {
            pendingShowTask?.cancel()
            pendingShowTask = nil
            replacementTransitionTask?.cancel()
            replacementTransitionTask = nil
            pendingReplacementItem = nil

            if let manager = toastManager {
                cancelPendingReplacements(excluding: manager.presentationID)
            } else {
                cancelPendingReplacements(excluding: nil)
            }

            toastManager?.dismiss()
            lastPresentedItem = nil
            return
        }

        let onDismissHandler: (UUID) -> Void = { presentationID in
            if clearBindingIfNeeded(for: presentationID) {
                onDismiss?()
            }
        }

        if let manager = toastManager {
            if manager.isShowing {
                beginSequentialReplacement(for: newItem, using: manager, delegate: delegate)
                return
            }

            replacementTransitionTask?.cancel()
            replacementTransitionTask = nil
            pendingReplacementItem = nil

            delegate.updateOverlay {
                toastContent(newItem)
            }
            lastPresentedItem = newItem
            scheduleShow(for: newItem, using: manager)
        } else {
            let manager = delegate.addOverlay(
                dismissDelay: dismissDelay,
                onDismiss: onDismissHandler
            ) {
                toastContent(newItem)
            }
            toastManager = manager
            lastPresentedItem = newItem
            scheduleShow(for: newItem, using: manager)
        }
    }

    @discardableResult
    private func clearBindingIfNeeded(for presentationID: UUID?) -> Bool {
        guard let presentationID,
              let index = presentationToItemID.firstIndex(where: { $0.presentationID == presentationID }) else {
            return false
        }
        
        let dismissedItemID = presentationToItemID.remove(at: index).itemID

        if item?.id == dismissedItemID {
            item = nil
        }
        
        if lastPresentedItem?.id == dismissedItemID {
            lastPresentedItem = nil
        }

        return true
    }

    private func scheduleShow(for item: Item, using manager: ToastManager) {
        pendingShowTask?.cancel()
        pendingShowTask = Task { @MainActor in
            if Task.isCancelled { return }
            try? await Task.sleep(for: .milliseconds(16))
            if Task.isCancelled { return }
            manager.show()
            if Task.isCancelled { return }
            presentationToItemID.append((presentationID: manager.presentationID, itemID: item.id))
            if pendingReplacementItem?.id == item.id {
                pendingReplacementItem = nil
            }
            pendingShowTask = nil
        }
    }

    private func cancelPendingReplacements(excluding activeID: UUID?) {
        let entriesToCancel = presentationToItemID.filter { entry in
            guard let activeID else { return true }
            return entry.presentationID != activeID
        }

        for entry in entriesToCancel {
            if clearBindingIfNeeded(for: entry.presentationID) {
                onDismiss?()
            }
        }
    }

    private func cleanupOldPresentationsIfNeeded() {
        guard presentationToItemID.count > maxTrackedPresentations else { return }

        // Remove oldest 50% when limit reached
        let keepCount = maxTrackedPresentations / 2
        presentationToItemID.removeFirst(presentationToItemID.count - keepCount)
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

        guard let scene = windowScene else {
            return
        }

        let delegate = ToastSceneDelegate()
        delegate.configure(with: scene)
        sceneDelegate = delegate
    }

    private func beginSequentialReplacement(for newItem: Item, using manager: ToastManager, delegate: ToastSceneDelegate) {
        pendingShowTask?.cancel()
        pendingReplacementItem = newItem
        replacementTransitionTask?.cancel()
        replacementTransitionTask = nil

        // Trigger simultaneous replacement animation
        guard let replacementID = manager.beginReplacement() else { return }

        // Capture item ID at task creation to avoid race condition
        let capturedItemID = newItem.id

        replacementTransitionTask = Task { @MainActor in
            defer {
                if pendingReplacementItem?.id == capturedItemID {
                    pendingReplacementItem = nil
                }
                replacementTransitionTask = nil
            }

            guard pendingReplacementItem?.id == capturedItemID else { return }

            // Update content with previous content for simultaneous animation
            delegate.updateOverlayWithPrevious(
                previousContent: {
                    if let last = self.lastPresentedItem {
                        self.toastContent(last)
                    } else {
                        self.toastContent(newItem)
                    }
                },
                newContent: {
                    self.toastContent(newItem)
                },
                replacementID: replacementID
            )
            lastPresentedItem = newItem
            presentationToItemID.append((presentationID: replacementID, itemID: newItem.id))
        }
    }

    private var outgoingSettleDuration: Duration {
        .milliseconds(40)
    }

    private var interToastDelay: Duration {
        .milliseconds(40)
    }
}

