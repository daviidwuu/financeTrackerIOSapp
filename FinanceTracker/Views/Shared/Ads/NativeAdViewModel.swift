import Foundation
import GoogleMobileAds
import Combine
import UIKit

class NativeAdViewModel: NSObject, ObservableObject, GADNativeAdLoaderDelegate, GADAdLoaderDelegate {
    @Published var nativeAd: GADNativeAd?
    @Published var isLoading: Bool = false
    @Published var isError: Bool = false
    
    private var adLoader: GADAdLoader!
    // Standard test ad unit ID for Native Advanced
    // WAS: ca-app-pub-1865245598004495~1854386845 (This was an App ID, not an Ad Unit ID)
    private let adUnitID = "ca-app-pub-3940256099942544/3986624511"
    
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
        adLoader.load(GADRequest())
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
            print("Native ad failed to load with error: \(error.localizedDescription)")
            self.isLoading = false
            self.isError = true
        }
    }
}
