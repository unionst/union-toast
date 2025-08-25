//
//  ToastOverlayView.swift
//  UnionToast
//
//  Created by Union on 1/27/25.
//

import SwiftUI

struct ToastOverlayView<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        Color.clear
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                ToastView {
                    content
                }
            }
    }
}
