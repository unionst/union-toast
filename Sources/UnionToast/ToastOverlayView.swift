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

    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                ToastView(content: content)
            }
            .environment(manager)
    }
}
