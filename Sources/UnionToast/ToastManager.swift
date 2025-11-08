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
    var contentHeight: CGFloat = 0

    private let dismissDelay: Duration
    private let onDismiss: (() -> Void)?

    init(dismissDelay: Duration = .seconds(6.5), onDismiss: (() -> Void)? = nil) {
        self.dismissDelay = dismissDelay
        self.onDismiss = onDismiss
    }

    var newDismissTask: Task<Void, Never>? {
        let taskID = UUID()
        dismissTaskID = taskID
        return Task {
            try? await Task.sleep(for: dismissDelay)
            guard !Task.isCancelled else {
                return
            }
            guard taskID == self.dismissTaskID else {
                return
            }
            await dismiss()
        }
    }

    func show() {
        cancelTask()
        isShowing = true
        dismissTask = newDismissTask
    }
    
    func dismiss() {
        cancelTask()
        guard isShowing else { return }
        isShowing = false
        onDismiss?()
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
        dismissTask = newDismissTask
    }
}
