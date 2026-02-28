import Foundation
import GoogleMobileAds
import Combine
import UIKit

class NativeAdViewModel: NSObject, ObservableObject, GADNativeAdLoaderDelegate, GADAdLoaderDelegate {
    @Published var nativeAd: GADNativeAd?
    @Published var isLoading: Bool = false
    @Published var isError: Bool = false
    
    private var adLoader: GADAdLoader!
    private let adUnitID = AppConfig.adMobNativeAdUnitID
    
    override init() {
        super.init()
        refreshAd()
    }
    
    func refreshAd() {
        guard !isLoading else { return }
        isLoading = true
        isError = false
        
        let multipleAdsOptions = GADMultipleAdsAdLoaderOptions()
        multipleAdsOptions.numberOfAds = 1
        
        adLoader = GADAdLoader(
            adUnitID: adUnitID,
            // Depending on architecture, you might need a valid UIViewController here.
            // nil often works for test ads if the view isn't driving presentation logic immediately.
            rootViewController: nil,
            adTypes: [.native],
            options: [multipleAdsOptions]
        )
        
        adLoader.delegate = self
        adLoader.load(AdManager.shared.makeAdRequest())
    }
    
    // MARK: - NativeAdLoaderDelegate
    
    func adLoader(_ adLoader: GADAdLoader, didReceive nativeAd: GADNativeAd) {
        DispatchQueue.main.async {
            self.nativeAd = nativeAd
            self.isLoading = false
            // Note: you must set the rootViewController on nativeAd if it has click actions
            // that present full screen overlays.
        }
    }
    
    func adLoader(_ adLoader: GADAdLoader, didFailToReceiveAdWithError error: Error) {
        DispatchQueue.main.async {
            DebugLogger.log("Native ad failed: \(error.localizedDescription)")
            self.isLoading = false
            self.isError = true
        }
    }
}
