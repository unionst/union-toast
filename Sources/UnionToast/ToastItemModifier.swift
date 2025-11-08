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
    @State private var presentationToItemID: [UUID: Item.ID] = [:]
    @State private var pendingShowTask: Task<Void, Never>?
    @State private var lastPresentedItem: Item?

    func body(content: Content) -> some View {
        content
            .onAppear {
                configureToastOverlay()
            }
            .onChange(of: item) { _, newValue in
                handleItemChange(newValue)
            }
            .onChange(of: toastManager?.isShowing == false) { hidden in
                if hidden {
                    clearBindingIfNeeded(for: toastManager?.presentationID)
                }
            }
    }

    private func handleItemChange(_ newItem: Item?) {
        if !hasConfiguredOverlay {
            configureToastOverlay()
        }

        guard let delegate = sceneDelegate else {
            return
        }

        guard let newItem else {
            pendingShowTask?.cancel()
            pendingShowTask = nil
            toastManager?.dismiss()
            lastPresentedItem = nil
            return
        }

        let onDismissHandler: (UUID) -> Void = { presentationID in
            if clearBindingIfNeeded(for: presentationID) {
                onDismiss?()
            }
        }

        if toastManager == nil {
            let manager = delegate.addOverlay(
                dismissDelay: dismissDelay,
                onDismiss: onDismissHandler
            ) {
                toastContent(newItem)
            }
            toastManager = manager
            lastPresentedItem = newItem
            scheduleShow(for: newItem, using: manager)
            return
        }

        guard let manager = toastManager else {
            return
        }

        if !manager.isShowing {
            delegate.updateOverlay {
                toastContent(newItem)
            }
            lastPresentedItem = newItem
            scheduleShow(for: newItem, using: manager)
            return
        }

        pendingShowTask?.cancel()
        let previousItem = lastPresentedItem ?? newItem
        let replacementID = manager.beginReplacement()

        delegate.updateOverlay(
            previousContent: { toastContent(previousItem) },
            replacementPresentationID: replacementID
        ) {
            toastContent(newItem)
        }

        if let newID = replacementID {
            presentationToItemID[newID] = newItem.id
        }
        lastPresentedItem = newItem
    }

    @discardableResult
    private func clearBindingIfNeeded(for presentationID: UUID?) -> Bool {
        guard let presentationID,
              let dismissedItemID = presentationToItemID[presentationID] else {
            return false
        }

        presentationToItemID.removeValue(forKey: presentationID)

        if item?.id == dismissedItemID || item == nil {
            item = nil
            return true
        }

        return false
    }

    private func scheduleShow(for item: Item, using manager: ToastManager) {
        pendingShowTask?.cancel()
        pendingShowTask = Task { @MainActor in
            if Task.isCancelled { return }
            try? await Task.sleep(for: .milliseconds(16))
            if Task.isCancelled { return }
            manager.show()
            if Task.isCancelled { return }
            presentationToItemID[manager.presentationID] = item.id
            pendingShowTask = nil
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
            print("🍞 ToastItemModifier: Couldn't find window scene")
            return
        }

        let delegate = ToastSceneDelegate()
        delegate.configure(with: scene)
        sceneDelegate = delegate
    }
}

