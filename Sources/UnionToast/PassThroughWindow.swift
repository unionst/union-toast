//
//  PassThroughWindow.swift
//  UnionToast
//
//  Created by Ben Sage on 8/24/25.
//

import UIKit
import SwiftUI

class PassThroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hitView = super.hitTest(point, with: event),
              let rootView = rootViewController?.view else { return nil }

        for subview in rootView.subviews.reversed() {
            let pointInSubview = subview.convert(point, from: rootView)
            if subview.hitTest(pointInSubview, with: event) != nil {
                return hitView
            }
        }
        return nil
    }
}


