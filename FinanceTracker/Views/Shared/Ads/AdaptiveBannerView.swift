import SwiftUI
import GoogleMobileAds

/// The actual wrapper around GADBannerView
struct BannerViewController: UIViewControllerRepresentable {
    let adUnitID: String
    
    final class Coordinator: NSObject, GADBannerViewDelegate {
        func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
            DebugLogger.log("Banner ad loaded: \(bannerView.adUnitID ?? "")")
        }
        
        func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
            DebugLogger.log("Banner ad failed: \(bannerView.adUnitID ?? "") - \(error.localizedDescription)")
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewViewController = UIViewController()
        let bannerView = GADBannerView(adSize: GADAdSizeBanner)
        bannerView.adUnitID = adUnitID
        bannerView.rootViewController = viewViewController
        bannerView.delegate = context.coordinator
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        
        viewViewController.view.addSubview(bannerView)
        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: viewViewController.view.centerXAnchor),
            bannerView.centerYAnchor.constraint(equalTo: viewViewController.view.centerYAnchor),
            bannerView.widthAnchor.constraint(equalToConstant: GADAdSizeBanner.size.width),
            bannerView.heightAnchor.constraint(equalToConstant: GADAdSizeBanner.size.height)
        ])
        bannerView.load(AdManager.shared.makeAdRequest())
        
        return viewViewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

/// The stylized SwiftUI view that holds the banner
struct AdaptiveBannerView: View {
    @EnvironmentObject var appState: AppState
    let adUnitID = AppConfig.adMobBannerAdUnitID
    
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
