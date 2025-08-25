//
//  View+Toast.swift
//  UnionToast
//
//  Created by Union on 1/27/25.
//

import SwiftUI

public extension View {
    func toast<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(ToastModifier(isPresented: isPresented, content: content))
    }
    
    func toast(
        isPresented: Binding<Bool>,
        text: String
    ) -> some View {
        toast(isPresented: isPresented) {
            Text(text)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.white)
        }
    }
    
    func toast(
        isPresented: Binding<Bool>,
        icon: Image,
        text: String
    ) -> some View {
        toast(isPresented: isPresented) {
            HStack(spacing: 8) {
                icon
                    .foregroundColor(.white)
                
                Text(text)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)
            }
        }
    }
}
