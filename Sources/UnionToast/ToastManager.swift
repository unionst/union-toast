//
//  ToastManager.swift
//  UnionToast
//
//  Created by Union on 1/27/25.
//

import SwiftUI
import Observation

@Observable @MainActor
class ToastManager {
    private(set) var isShowing = false
    private var dismissTask: Task<Void, Never>?
    private var dismissTaskID = UUID()
    private(set) var presentationID = UUID()
    private(set) var replacementPresentationID: UUID?
    private(set) var isReplacing = false
    private var pendingDismissPresentationID: UUID?
    var contentHeight: CGFloat = 0

    private let dismissDelay: Duration
    private let onDismiss: ((UUID) -> Void)?

    init(dismissDelay: Duration = .seconds(6.5), onDismiss: ((UUID) -> Void)? = nil) {
        self.dismissDelay = dismissDelay
        self.onDismiss = onDismiss
    }

    private func makeDismissTask(for id: UUID) -> Task<Void, Never>? {
        return Task {
            try? await Task.sleep(for: dismissDelay)
            guard !Task.isCancelled else {
                return
            }
            guard id == self.dismissTaskID else {
                return
            }
            dismiss()
        }
    }

    func show() {
        cancelReplacement()
        cancelTask()
        let newPresentationID = UUID()
        presentationID = newPresentationID
        dismissTaskID = newPresentationID
        isShowing = true
        dismissTask = makeDismissTask(for: newPresentationID)
    }
    
    func dismiss() {
        cancelTask()
        guard isShowing else { return }
        isShowing = false
        cancelReplacement()
        onDismiss?(presentationID)
    }

    private func cancelTask() {
        dismissTask?.cancel()
        dismissTask = nil
    }

    func pauseTimer() {
        dismissTask?.cancel()
        dismissTask = nil
    }
    
    func resumeTimer() {
        guard isShowing else { return }
        guard !isReplacing else { return }
        dismissTaskID = presentationID
        dismissTask = makeDismissTask(for: presentationID)
    }

    @discardableResult
    func beginReplacement() -> UUID? {
        guard isShowing else { return nil }

        cancelTask()
        let newID = UUID()
        replacementPresentationID = newID
        pendingDismissPresentationID = presentationID
        isReplacing = true
        return newID
    }

    func completeReplacement() {
        guard isReplacing, let newID = replacementPresentationID else { return }

        let outgoingID = pendingDismissPresentationID

        // Delay state updates to reduce background re-rendering during animation
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))

            replacementPresentationID = nil
            isReplacing = false
            presentationID = newID
            dismissTaskID = newID
            isShowing = true
            dismissTask = makeDismissTask(for: newID)

            if let outgoingID {
                pendingDismissPresentationID = nil
                onDismiss?(outgoingID)
            }
        }
    }

    func cancelReplacement() {
        replacementPresentationID = nil
        pendingDismissPresentationID = nil
        isReplacing = false
    }
}
