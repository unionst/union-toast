
//  NotificationView.swift
//  LibraryTestApp
//
//  Created by Ben Elhadad on 10/7/25.
//

import SwiftUI

struct iOS26NotificationBackground: View {
    var cornerRadius: CGFloat = 24
    var width: CGFloat = 380
    var height: CGFloat = 60

    var body: some View {
        ZStack {
            //fill
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            //edges
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [ Color.white.opacity(0.4), Color.white.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.3
                )
                .blendMode(.overlay)
            
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                        .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 5)
        }
        .frame(width: width, height: height)
    }
}

#Preview {
    iOS26NotificationBackground()
}
