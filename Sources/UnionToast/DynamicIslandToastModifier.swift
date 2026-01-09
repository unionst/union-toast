//
//  DynamicIslandToastModifier.swift
//  UnionToast
//
//  Created by Union on 1/8/26.
//

import SwiftUI

// MARK: - Device Detection

private func hasDynamicIsland() -> Bool {
    guard let windowScene = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .first
    else { return false }

    let safeAreaTop = windowScene.windows.first?.safeAreaInsets.top ?? 0
    return safeAreaTop >= 59
}

// MARK: - Toast State Manager

@Observable
@MainActor
class DynamicIslandToastState {
    var isExpanded: Bool = false
    var dismissTask: Task<Void, Never>?

    func expand() {
        isExpanded = true
    }

    func collapse() {
        isExpanded = false
        dismissTask?.cancel()
        dismissTask = nil
    }

    func scheduleDismiss(after delay: Duration, action: @escaping () -> Void) {
        dismissTask?.cancel()
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            action()
        }
    }
}

// MARK: - Status Bar Hosting Controller

private class StatusBarHostingController<Content: View>: UIHostingController<Content> {
    var isStatusBarHidden: Bool = false {
        didSet {
            setNeedsStatusBarAppearanceUpdate()
        }
    }

    override var prefersStatusBarHidden: Bool {
        return isStatusBarHidden
    }
}

// MARK: - Window Extractor

private struct WindowExtractor: UIViewRepresentable {
    var onWindowFound: (UIWindow) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        DispatchQueue.main.async {
            if let window = view.window {
                onWindowFound(window)
            }
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            if let window = uiView.window {
                onWindowFound(window)
            }
        }
    }
}

// MARK: - Internal Toast View Wrapper

private struct DynamicIslandToastWrapper<Content: View>: View {
    @Bindable var state: DynamicIslandToastState
    var onDismiss: () -> Void
    let content: () -> Content

    var body: some View {
        DynamicIslandToastView(
            isExpanded: $state.isExpanded,
            onDismiss: onDismiss,
            content: content
        )
    }
}

// MARK: - Dynamic Island Toast Modifier

struct DynamicIslandToastModifier<ToastContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let dismissDelay: Duration
    let onDismiss: (() -> Void)?
    let toastContent: () -> ToastContent

    @State private var overlayWindow: PassThroughWindow?
    @State private var overlayController: StatusBarHostingController<DynamicIslandToastWrapper<ToastContent>>?
    @State private var toastState = DynamicIslandToastState()
    @State private var deviceHasDynamicIsland: Bool? = nil

    init(
        isPresented: Binding<Bool>,
        dismissDelay: Duration = .seconds(3),
        onDismiss: (() -> Void)? = nil,
        toastContent: @escaping () -> ToastContent
    ) {
        self._isPresented = isPresented
        self.dismissDelay = dismissDelay
        self.onDismiss = onDismiss
        self.toastContent = toastContent
    }

    func body(content: Content) -> some View {
        if deviceHasDynamicIsland == true {
            // Use Dynamic Island toast
            content
                .background(WindowExtractor { mainWindow in
                    createOverlayWindow(mainWindow)
                })
                .onChange(of: isPresented) { oldValue, newValue in
                    if newValue {
                        toastState.expand()
                        overlayController?.isStatusBarHidden = true
                        // Schedule auto-dismiss
                        toastState.scheduleDismiss(after: dismissDelay) {
                            isPresented = false
                            onDismiss?()
                        }
                    } else {
                        toastState.collapse()
                        overlayController?.isStatusBarHidden = false
                    }
                }
        } else if deviceHasDynamicIsland == false {
            // Fall back to regular toast on non-DI devices
            content
                .modifier(ToastModifier(
                    isPresented: $isPresented,
                    dismissDelay: dismissDelay,
                    onDismiss: onDismiss,
                    toastContent: toastContent
                ))
        } else {
            // Check device on appear
            content
                .onAppear {
                    deviceHasDynamicIsland = hasDynamicIsland()
                }
        }
    }

    private func createOverlayWindow(_ mainWindow: UIWindow) {
        guard overlayWindow == nil,
              let windowScene = mainWindow.windowScene else { return }

        let passthroughWindow = PassThroughWindow(windowScene: windowScene)
        passthroughWindow.windowLevel = .alert + 10
        passthroughWindow.isHidden = false
        passthroughWindow.isUserInteractionEnabled = true
        passthroughWindow.backgroundColor = .clear

        let wrapperView = DynamicIslandToastWrapper(
            state: toastState,
            onDismiss: {
                isPresented = false
                onDismiss?()
            },
            content: toastContent
        )
        let hosting = StatusBarHostingController(rootView: wrapperView)
        hosting.view.backgroundColor = .clear

        passthroughWindow.rootViewController = hosting

        // Sync interface style with main window
        passthroughWindow.overrideUserInterfaceStyle = mainWindow.overrideUserInterfaceStyle

        // Force layout pass
        hosting.view.setNeedsLayout()
        hosting.view.layoutIfNeeded()

        self.overlayWindow = passthroughWindow
        self.overlayController = hosting

        // Set initial state if already presented
        if isPresented {
            toastState.expand()
            hosting.isStatusBarHidden = true
            // Schedule auto-dismiss
            toastState.scheduleDismiss(after: dismissDelay) {
                isPresented = false
                onDismiss?()
            }
        }
    }
}
