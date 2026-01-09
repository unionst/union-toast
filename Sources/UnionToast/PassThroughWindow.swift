//
//  PassThroughWindow.swift
//  UnionToast
//
//  Created by Ben Sage on 8/24/25.
//

import UIKit
import SwiftUI

class PassThroughWindow: UIWindow {
    /// Optional rect where hits should be intercepted instead of passed through.
    /// Used by Dynamic Island toasts to define the interactive area.
    var hittableRect: CGRect?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hitView = super.hitTest(point, with: event),
              let rootView = rootViewController?.view else {
            return nil
        }

        // If we have a defined hittable rect, check if the point is inside
        if let rect = hittableRect, rect.contains(point) {
            return hitView
        }

        // If the hit view is not the root view itself, something inside was tapped
        if hitView !== rootView {
            return hitView
        }

        // Fallback: check subviews explicitly
        for subview in rootView.subviews.reversed() {
            let pointInSubview = subview.convert(point, from: rootView)
            if subview.hitTest(pointInSubview, with: event) != nil {
                return hitView
            }
        }
        return nil
    }
}


