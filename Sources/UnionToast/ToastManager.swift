//
//  ToastManager.swift
//  UnionToast
//
//  Created by Union on 1/27/25.
//

import SwiftUI
import Observation
import UnionHaptics

@Observable @MainActor
class ToastManager {
    var isShowing = false
    private var dismissTask: Task<Void, Never>?

    private let dismissTime = 6.5

    var newDismissTask: Task<Void, Never>? {
        Task {
            try? await Task.sleep(for: .seconds(dismissTime))
            guard !Task.isCancelled else { return }
            await dismiss()
        }
    }

    func show() {
        cancelTask()

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isShowing = true
        }
        
        dismissTask = newDismissTask
    }
    
    func dismiss() {
        cancelTask()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            isShowing = false
        }
        
        Task {
            try? await Task.sleep(for: .seconds(0.4))
            isShowing = false
        }
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
