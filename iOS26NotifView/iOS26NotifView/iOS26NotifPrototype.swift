//
//  iOS26NotifPrototype.swift
//  iOS26NotifView
//
//  Created by Ben Elhadad on 10/7/25.
//

import SwiftUI

struct iOS26MessageNotifcation: View {
    var body: some View {
        ZStack {
            iOS26NotificationBackground()
            
            HStack{
                Image(systemName: "bell.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
                    .padding()
                Spacer()
            }
            HStack(spacing: 12) {
                Spacer()
                Text("This is a short message.")
                    .font(.subheadline)
                    .foregroundColor(.white)
                Spacer()
            }
        }
    }
}

struct iOS26Prototype: View {
    @State private var showToast = false
    @State private var showMyButton = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image("IMG_3608")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                
                if #available(iOS 26.0, *) {
                    VStack {
                        iOS26MessageNotifcation()
                            .scaleEffect(showMyButton ? 1.0 : 0)
                            .opacity(showMyButton ? 1.0 : 0)
                            .offset(y: showMyButton
                                    ? -geometry.size.height * 0.3
                                : -geometry.size.height
                            )
                            .animation(
                                .interpolatingSpring(
                                    mass: 2.3,
                                    stiffness: 35.0,
                                    damping: 13,
                                    initialVelocity: 2
                                ),
                                value: showMyButton
                            )
                        
                        Button("Show iOS26 Prototype") {
                            showMyButton.toggle()
                        }
                        .foregroundStyle(.blue)
                        .padding()
                        .background(.white)
                        .padding()
                    }
                } else {
                    Button("Default") {
                        showMyButton.toggle()
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .ignoresSafeArea()
        }
    }
}


#Preview {
    iOS26Prototype()
}


