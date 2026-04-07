import SwiftUI
import UIKit

/// Intercepts taps on a specific tab index at the UIKit delegate level so that
/// iOS never starts the tab-switch animation. Place this as an overlay/background
/// on the TabView so it is always in the hierarchy from the first frame.
struct TabBarActionInterceptor: UIViewRepresentable {
    let actionTabIndex: Int
    let action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(actionTabIndex: actionTabIndex, action: action)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isHidden = true
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.action = action
        DispatchQueue.main.async {
            context.coordinator.install(from: uiView)
        }
    }

    /// Sits between SwiftUI's UITabBarControllerDelegate and the UITabBarController.
    /// Intercepts shouldSelect for the action tab; forwards everything else to
    /// SwiftUI's original delegate so normal tab switching continues to work.
    final class Coordinator: NSObject, UITabBarControllerDelegate {
        let actionTabIndex: Int
        var action: () -> Void
        private weak var tabBarController: UITabBarController?
        private weak var originalDelegate: UITabBarControllerDelegate?

        init(actionTabIndex: Int, action: @escaping () -> Void) {
            self.actionTabIndex = actionTabIndex
            self.action = action
        }

        func install(from view: UIView) {
            guard tabBarController == nil,
                  let root = view.window?.rootViewController,
                  let tbc = findTabBarController(in: root) else { return }
            originalDelegate = tbc.delegate
            tbc.delegate = self
            tabBarController = tbc
        }

        private func findTabBarController(in vc: UIViewController) -> UITabBarController? {
            if let tbc = vc as? UITabBarController { return tbc }
            for child in vc.children {
                if let found = findTabBarController(in: child) { return found }
            }
            return nil
        }

        // MARK: - UITabBarControllerDelegate

        func tabBarController(
            _ tabBarController: UITabBarController,
            shouldSelect viewController: UIViewController
        ) -> Bool {
            if let index = tabBarController.viewControllers?.firstIndex(of: viewController),
               index == actionTabIndex {
                action()
                return false  // Prevent the tab switch entirely
            }
            // Forward to SwiftUI's original delegate for all other tabs.
            return originalDelegate?.tabBarController?(tabBarController, shouldSelect: viewController) ?? true
        }

        // MARK: - Message Forwarding
        // Any other delegate methods (e.g. didSelect, animation customization) are
        // forwarded to SwiftUI's original delegate automatically.

        override func responds(to aSelector: Selector!) -> Bool {
            super.responds(to: aSelector) || originalDelegate?.responds(to: aSelector) == true
        }

        override func forwardingTarget(for aSelector: Selector!) -> Any? {
            if originalDelegate?.responds(to: aSelector) == true { return originalDelegate }
            return super.forwardingTarget(for: aSelector)
        }
    }
}
