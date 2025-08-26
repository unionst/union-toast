//
//  UIViewController+Toast.swift
//  UnionToast
//
//  Created by Union on 1/27/25.
//

import UIKit
import SwiftUI

public extension UIViewController {
    /// Present a toast view controller
    /// 
    /// Works exactly like `present(_:animated:completion:)` for view controllers,
    /// but displays the content as a toast notification at the top of the screen.
    /// 
    /// - Parameters:
    ///   - toastViewController: The view controller to present as toast content
    ///   - animated: Whether to animate the presentation (default: true)
    ///   - completion: Optional completion handler called after presentation
    /// 
    /// Example:
    /// ```swift
    /// let myViewController = MyCustomViewController()
    /// present(myViewController, animated: true) {
    ///     print("Toast presented!")
    /// }
    /// ```
    func presentToast(
        _ toastViewController: UIViewController,
        animated: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        let toastController = ToastHostingController(viewController: toastViewController)
        presentToastController(toastController, animated: animated, completion: completion)
    }
    
    /// Dismiss the currently presented toast
    /// 
    /// - Parameters:
    ///   - animated: Whether to animate the dismissal (default: true)
    ///   - completion: Optional completion handler called after dismissal
    func dismissToast(animated: Bool = true, completion: (() -> Void)? = nil) {
        guard let toastController = findToastController() else {
            completion?()
            return
        }
        
        toastController.dismissToast(animated: animated, completion: completion)
    }
    
    // MARK: - Private Methods
    
    private func presentToastController(
        _ toastController: ToastHostingController,
        animated: Bool,
        completion: (() -> Void)?
    ) {
        // Dismiss any existing toast first
        if let existingToast = findToastController() {
            existingToast.dismissToast(animated: false) { [weak self] in
                self?.addToastController(toastController, animated: animated, completion: completion)
            }
        } else {
            addToastController(toastController, animated: animated, completion: completion)
        }
    }
    
    private func addToastController(
        _ toastController: ToastHostingController,
        animated: Bool,
        completion: (() -> Void)?
    ) {
        // Add as child view controller
        addChild(toastController)
        view.addSubview(toastController.view)
        toastController.didMove(toParent: self)
        
        // Setup constraints
        toastController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            toastController.view.topAnchor.constraint(equalTo: view.topAnchor),
            toastController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toastController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toastController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Present the toast
        toastController.presentToast(animated: animated, completion: completion)
    }
    
    private func findToastController() -> (any ToastControllerProtocol)? {
        return children.first { $0 is any ToastControllerProtocol } as? (any ToastControllerProtocol)
    }
}

// MARK: - Toast Controller Protocol

protocol ToastControllerProtocol: UIViewController {
    func presentToast(animated: Bool, completion: (() -> Void)?)
    func dismissToast(animated: Bool, completion: (() -> Void)?)
}

// MARK: - Toast Hosting Controller

class ToastHostingController: UIHostingController<ToastWrapper>, ToastControllerProtocol {
    @Published private var isPresented = false
    private let contentViewController: UIViewController
    
    init(viewController: UIViewController) {
        self.contentViewController = viewController
        let wrapper = ToastWrapper(isPresented: .constant(false), viewController: viewController)
        super.init(rootView: wrapper)
        
        // Make the background transparent
        view.backgroundColor = .clear
        
        // Update the root view with proper binding
        updateRootView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateRootView() {
        let binding = Binding<Bool>(
            get: { self.isPresented },
            set: { self.isPresented = $0 }
        )
        
        rootView = ToastWrapper(isPresented: binding, viewController: contentViewController)
    }
    
    func presentToast(animated: Bool, completion: (() -> Void)?) {
        isPresented = true
        
        if animated {
            // Wait for SwiftUI animation to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                completion?()
            }
        } else {
            completion?()
        }
    }
    
    func dismissToast(animated: Bool, completion: (() -> Void)?) {
        isPresented = false
        
        let delay = animated ? 0.3 : 0.0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.removeFromParent()
            completion?()
        }
    }
    
    private func removeFromParent() {
        willMove(toParent: nil)
        view.removeFromSuperview()
        removeFromParent()
    }
}

// MARK: - Toast Wrapper View

struct ToastWrapper: View {
    @Binding var isPresented: Bool
    let viewController: UIViewController
    
    var body: some View {
        Color.clear
            .toast(isPresented: $isPresented) {
                UIViewControllerRepresentableWrapper(viewController: viewController)
            }
    }
}

// MARK: - UIViewController Representable

struct UIViewControllerRepresentableWrapper: UIViewControllerRepresentable {
    let viewController: UIViewController
    
    func makeUIViewController(context: Context) -> UIViewController {
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No updates needed
    }
}