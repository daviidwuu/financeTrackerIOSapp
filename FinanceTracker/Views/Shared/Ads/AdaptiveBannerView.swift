import SwiftUI
import GoogleMobileAds

/// The actual wrapper around GADBannerView
struct BannerViewController: UIViewControllerRepresentable {
    let adUnitID: String
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewViewController = UIViewController()
        let bannerView = GADBannerView(adSize: GADAdSizeBanner)
        bannerView.adUnitID = adUnitID
        bannerView.rootViewController = viewViewController
        
        viewViewController.view.addSubview(bannerView)
        viewViewController.view.frame = CGRect(origin: .zero, size: GADAdSizeBanner.size)
        bannerView.load(GADRequest())
        
        return viewViewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

/// The stylized SwiftUI view that holds the banner
struct AdaptiveBannerView: View {
    @EnvironmentObject var appState: AppState
    // Standard Test Banner ID
    // WAS: ca-app-pub-1865245598004495~1854386845 (This was an App ID, not an Ad Unit ID)
    let adUnitID = "ca-app-pub-3940256099942544/2934735716"
    
    var body: some View {
        if !appState.isPremiumUser {
            HStack {
                Spacer()
                BannerViewController(adUnitID: adUnitID)
                    .frame(width: GADAdSizeBanner.size.width, height: GADAdSizeBanner.size.height)
                Spacer()
            }
            .padding(.vertical, AppSpacing.element)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
            )
        }
    }
}
