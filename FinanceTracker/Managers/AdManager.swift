import Foundation
import AppTrackingTransparency
import AdSupport
import GoogleMobileAds
import Combine

class AdManager: ObservableObject {
    static let shared = AdManager()
    
    @Published var isPersonalizedAdAllowed: Bool = false
    
    private init() {}
    
    func requestATT() {
        if #available(iOS 14, *) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                ATTrackingManager.requestTrackingAuthorization { status in
                    DispatchQueue.main.async {
                        switch status {
                        case .authorized:
                            self.isPersonalizedAdAllowed = true
                            print("ATT Status: Authorized")
                        case .denied, .restricted, .notDetermined:
                            self.isPersonalizedAdAllowed = false
                            print("ATT Status: Not Authorized")
                        @unknown default:
                            self.isPersonalizedAdAllowed = false
                        }
                    }
                }
            }
        }
    }
}
