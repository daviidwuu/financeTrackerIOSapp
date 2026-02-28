import Foundation
import AppTrackingTransparency
import AdSupport
import GoogleMobileAds
import Combine

class AdManager: ObservableObject {
    static let shared = AdManager()
    
    @Published var isPersonalizedAdAllowed: Bool = false
    
    private init() {}
    
    func makeAdRequest() -> GADRequest {
        let request = GADRequest()
        if !isPersonalizedAdAllowed {
            let extras = GADExtras()
            extras.additionalParameters = ["npa": "1"]
            request.register(extras)
        }
        return request
    }
    
    func requestATT() {
        if #available(iOS 14, *) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                ATTrackingManager.requestTrackingAuthorization { status in
                    DispatchQueue.main.async {
                        switch status {
                        case .authorized:
                            self.isPersonalizedAdAllowed = true
                        case .denied, .restricted, .notDetermined:
                            self.isPersonalizedAdAllowed = false
                        @unknown default:
                            self.isPersonalizedAdAllowed = false
                        }
                    }
                }
            }
        }
    }
}
