//
//  ToastOverlayView.swift
//  UnionToast
//
//  Created by Union on 1/27/25.
//

import SwiftUI

struct ToastOverlayView<Content: View>: View {
    let manager: ToastManager
    let content: () -> Content
    let previousContent: (() -> Content)?
    let replacementPresentationID: UUID?

    init(
        manager: ToastManager,
        previousContent: (() -> Content)? = nil,
        replacementPresentationID: UUID? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.manager = manager
        self.previousContent = previousContent
        self.replacementPresentationID = replacementPresentationID
        self.content = content
    }

    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                ToastView(
                    previousContent: previousContent,
                    replacementPresentationID: replacementPresentationID
                ) {
                    content()
                }
            }
            .environment(manager)
    }
}
