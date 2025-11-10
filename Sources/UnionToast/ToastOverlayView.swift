//
//  ToastOverlayView.swift
//  UnionToast
//
//  Created by Union on 1/27/25.
//

import SwiftUI

struct ToastOverlayView: View {
    let manager: ToastManager
    let previousContent: (() -> any View)?
    let replacementPresentationID: UUID?
    let content: () -> any View

    init(
        manager: ToastManager,
        previousContent: (() -> any View)? = nil,
        replacementPresentationID: UUID? = nil,
        content: @escaping () -> any View
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
                    previousContent: previousContent.map { provider in
                        { AnyView(provider()) }
                    },
                    replacementPresentationID: replacementPresentationID
                ) {
                    AnyView(content())
                }
            }
            .environment(manager)
    }
}
