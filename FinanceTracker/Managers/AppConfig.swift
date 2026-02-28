import Foundation

enum AppConfig {
    private static func plistString(_ key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
    
    private static func plistURL(_ key: String) -> URL? {
        guard let raw = plistString(key)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty,
              let url = URL(string: raw),
              let host = url.host?.lowercased(),
              host != "example.com"
        else { return nil }
        return url
    }
    
    static var revenueCatAPIKey: String? {
        func normalize(_ value: String?) -> String? {
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty,
                  value != "REPLACE_WITH_PRODUCTION_KEY"
            else { return nil }
            return value
        }

        let production = normalize(plistString("RevenueCatAPIKey"))
        let debug = normalize(plistString("RevenueCatAPIKeyDebug"))
        return production ?? debug
    }

    static var revenueCatEntitlementID: String {
        plistString("RevenueCatEntitlementID") ?? "King"
    }
    
    static var adMobBannerAdUnitID: String {
        plistString("AdMobBannerAdUnitID") ?? "ca-app-pub-3940256099942544/2934735716"
    }
    
    static var adMobNativeAdUnitID: String {
        plistString("AdMobNativeAdUnitID") ?? "ca-app-pub-3940256099942544/3986624511"
    }
    
    static var termsURL: URL? {
        plistURL("TermsOfServiceURL")
    }
    
    static var privacyURL: URL? {
        plistURL("PrivacyPolicyURL")
    }
    
    static var manageSubscriptionsURL: URL? {
        URL(string: "https://apps.apple.com/account/subscriptions")
    }
    
    static var shortVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0"
    }
    
    static var buildNumber: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "0"
    }
    
    static var versionDisplayString: String {
        "Version \(shortVersion) (Build \(buildNumber))"
    }
}
