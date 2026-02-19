import UIKit

// Enable swipe-to-back gesture even when the navigation bar is hidden
// This is a global override to restore iOS standard behavior in SwiftUI views
// that use .navigationBarHidden(true)
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }
    
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Only allow swipe-to-back if there is a view controller to pop to
        return viewControllers.count > 1
    }
}
