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
    var contentHeight: CGFloat = 0

    private let dismissDelay: Duration

    init(dismissDelay: Duration = .seconds(6.5)) {
        self.dismissDelay = dismissDelay
    }

    var newDismissTask: Task<Void, Never>? {
        Task {
            try? await Task.sleep(for: dismissDelay)
            guard !Task.isCancelled else { return }
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
        isShowing = false
    }

    private func cancelTask() {
        dismissTask?.cancel()
        dismissTask = nil
    }

    func pauseTimer() {
        dismissTask?.cancel()
    }
    
    func resumeTimer() {
        guard isShowing else { return }
        dismissTask = newDismissTask
    }
}
