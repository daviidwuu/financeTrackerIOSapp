import SwiftUI
import GoogleMobileAds

struct NativeAdView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = NativeAdViewModel()
    
    var hasBackground: Bool = true
    
    var body: some View {
        if !appState.isPremiumUser {
            Group {
                if let nativeAd = viewModel.nativeAd {
                    NativeAdRepresentable(nativeAd: nativeAd, hasBackground: hasBackground)
                        .frame(height: 80) // Match the 80 height of TransactionRow (48 icon + 16 top/bottom padding)
                } else if !viewModel.isError {
                    // Shimmer or loading state, or just empty space
                    HStack(spacing: AppSpacing.element) {
                        Circle()
                            .fill(Color.secondary.opacity(0.1))
                            .frame(width: 48, height: 48)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.1))
                                .frame(width: 120, height: 16)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.1))
                                .frame(width: 200, height: 12)
                        }
                        Spacer()
                    }
                    .padding(AppSpacing.element)
                    .background(hasBackground ? Color(uiColor: .secondarySystemBackground) : Color.clear)
                    .cornerRadius(hasBackground ? AppRadius.medium : 0)
                }
            }
        }
    }
}

// MARK: - UIKit Bridge
fileprivate struct NativeAdRepresentable: UIViewRepresentable {
    let nativeAd: GADNativeAd
    let hasBackground: Bool
    
    func makeUIView(context: Context) -> GADNativeAdView {
        let nativeAdView = GADNativeAdView()
        
        // 1. Create the UI Hierarchy to match MockNativeAdView
        
        // Background
        nativeAdView.backgroundColor = hasBackground ? .secondarySystemBackground : .clear
        nativeAdView.layer.cornerRadius = hasBackground ? 16 : 0 // AppRadius.medium
        
        // Icon View
        let iconView = UIImageView()
        iconView.layer.cornerRadius = 24
        iconView.clipsToBounds = true
        iconView.contentMode = .scaleAspectFill
        iconView.backgroundColor = .systemGray6
        nativeAdView.iconView = iconView
        
        // Ad Tag
        let adTagLabel = UILabel()
        adTagLabel.text = "Ad"
        adTagLabel.font = .systemFont(ofSize: 10, weight: .bold)
        adTagLabel.backgroundColor = UIColor.secondaryLabel.withAlphaComponent(0.2)
        adTagLabel.textColor = .label
        adTagLabel.textAlignment = .center
        adTagLabel.layer.cornerRadius = 6 // Capsule-like
        adTagLabel.clipsToBounds = true
        // Add padding to Ad tag via constraints later
        
        // Headline
        let headlineLabel = UILabel()
        headlineLabel.font = .systemFont(ofSize: 15, weight: .semibold) // body font equivalent
        headlineLabel.textColor = .label
        nativeAdView.headlineView = headlineLabel
        
        // Body
        let bodyLabel = UILabel()
        bodyLabel.font = .systemFont(ofSize: 12, weight: .regular) // caption font equivalent
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.numberOfLines = 2
        nativeAdView.bodyView = bodyLabel
        
        // Call To Action (Using a chevron to match MockNativeAdView instead of a full text button for a cleaner "transaction row" look, but we still need the click target)
        let callToActionIcon = UIImageView(image: UIImage(systemName: "chevron.right"))
        callToActionIcon.tintColor = .tertiaryLabel
        callToActionIcon.contentMode = .scaleAspectFit
        nativeAdView.callToActionView = callToActionIcon // The whole nativeAdView is clickable, but this registers the CTA view
        
        // 2. Add subviews
        nativeAdView.addSubview(iconView)
        nativeAdView.addSubview(adTagLabel)
        nativeAdView.addSubview(headlineLabel)
        nativeAdView.addSubview(bodyLabel)
        nativeAdView.addSubview(callToActionIcon)
        
        // Disable autoresizing masks
        [iconView, adTagLabel, headlineLabel, bodyLabel, callToActionIcon].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        // 3. Layout Constraints (Matching padding: AppSpacing.element = 16 generally)
        NSLayoutConstraint.activate([
            // Icon View (Left aligned)
            iconView.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: nativeAdView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 48),
            iconView.heightAnchor.constraint(equalToConstant: 48),
            
            // Ad Tag Label (Next to Icon, top aligned with Headline)
            adTagLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 16),
            adTagLabel.topAnchor.constraint(equalTo: nativeAdView.topAnchor, constant: 16),
            adTagLabel.widthAnchor.constraint(equalToConstant: 24),
            adTagLabel.heightAnchor.constraint(equalToConstant: 16),
            
            // Headline Label (Next to Ad Tag)
            headlineLabel.leadingAnchor.constraint(equalTo: adTagLabel.trailingAnchor, constant: 6),
            headlineLabel.centerYAnchor.constraint(equalTo: adTagLabel.centerYAnchor),
            headlineLabel.trailingAnchor.constraint(lessThanOrEqualTo: callToActionIcon.leadingAnchor, constant: -8),
            
            // Body Label (Below Headline)
            bodyLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 16),
            bodyLabel.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 4),
            bodyLabel.trailingAnchor.constraint(equalTo: callToActionIcon.leadingAnchor, constant: -8),
            
            // Chevron CTA (Right aligned)
            callToActionIcon.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -16),
            callToActionIcon.centerYAnchor.constraint(equalTo: nativeAdView.centerYAnchor),
            callToActionIcon.widthAnchor.constraint(equalToConstant: 12),
            callToActionIcon.heightAnchor.constraint(equalToConstant: 12)
        ])
        
        return nativeAdView
    }
    
    func updateUIView(_ uiView: GADNativeAdView, context: Context) {
        // Populate the UI with actual ad data
        uiView.nativeAd = nativeAd
        
        (uiView.headlineView as? UILabel)?.text = nativeAd.headline
        (uiView.bodyView as? UILabel)?.text = nativeAd.body
        
        // Icon
        if let iconImage = nativeAd.icon?.image {
            (uiView.iconView as? UIImageView)?.image = iconImage
        } else {
            // Fallback generic ad icon if none provided
            (uiView.iconView as? UIImageView)?.image = UIImage(systemName: "sparkles")
            (uiView.iconView as? UIImageView)?.tintColor = .orange
        }
        
        // Ensure clickability. Google requires the NativeAdView to know what ad is driving the click.
        // It's handled automatically as long as uiView.nativeAd is set.
        
        // key fix: Set the rootViewController so that clicks can present overlays
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            nativeAd.rootViewController = rootVC
        } else {
            nativeAd.rootViewController = uiView.window?.rootViewController
        }
    }
}
