//
//  UIViewController+Toast.swift
//  UnionToast
//
//  Created by Union on 1/27/25.
//

import UIKit
import SwiftUI

/// A toast controller that manages toast presentation, similar to UIAlertController
public class UIToastController: UIViewController {
    private let contentViewController: UIViewController
    private let toastHostingController: ToastHostingController
    
    /// Create a toast controller with a view controller
    /// 
    /// Similar to `UIAlertController(title:message:preferredStyle:)`
    /// 
    /// - Parameter viewController: The view controller to display as toast content
    /// 
    /// Example:
    /// ```swift
    /// let myVC = MyCustomViewController()
    /// let toast = UIToastController(viewController: myVC)
    /// present(toast, animated: true)
    /// ```
    public init(viewController: UIViewController) {
        self.contentViewController = viewController
        self.toastHostingController = ToastHostingController(viewController: viewController)
        super.init(nibName: nil, bundle: nil)
        
        // Make background transparent
        view.backgroundColor = .clear
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }
    
    /// Create a toast controller with SwiftUI content
    /// 
    /// - Parameter content: SwiftUI view builder for the toast content
    /// 
    /// Example:
    /// ```swift
    /// let toast = UIToastController {
    ///     Text("Hello, World!")
    ///         .padding()
    ///         .background(.blue)
    ///         .cornerRadius(8)
    /// }
    /// present(toast, animated: true)
    /// ```
    public convenience init<Content: View>(@ViewBuilder content: @escaping () -> Content) {
        let hostingController = UIHostingController(rootView: content())
        hostingController.view.backgroundColor = .clear
        self.init(viewController: hostingController)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        // Add the toast hosting controller as a child
        addChild(toastHostingController)
        view.addSubview(toastHostingController.view)
        toastHostingController.didMove(toParent: self)
        
        // Setup constraints
        toastHostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            toastHostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            toastHostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toastHostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toastHostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        toastHostingController.presentToast(animated: animated)
    }
    
    /// Dismiss the toast
    /// 
    /// - Parameters:
    ///   - animated: Whether to animate the dismissal
    ///   - completion: Optional completion handler
    public func dismiss(animated: Bool = true, completion: (() -> Void)? = nil) {
        toastHostingController.dismissToast(animated: animated) { [weak self] in
            self?.dismiss(animated: false, completion: completion)
        }
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