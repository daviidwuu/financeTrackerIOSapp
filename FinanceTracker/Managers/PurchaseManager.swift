import Foundation
import RevenueCat
import StoreKit
import Combine

class PurchaseManager: NSObject, ObservableObject {
    static let shared = PurchaseManager()
    
    @Published var customerInfo: CustomerInfo?
    @Published var offerings: Offerings?
    @Published var offeringsError: String?
    @Published var isPremium = false
    
    private override init() {
        super.init()
    }
    
    func configure(apiKey: String) {
        Purchases.configure(withAPIKey: apiKey)
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .info
        #endif
        
        // Listen for changes in customer info (premium status)
        Purchases.shared.delegate = self
        
        // Fetch initial info
        fetchOfferings()
        refreshCustomerInfo()
    }
    
    func fetchOfferings() {
        Purchases.shared.getOfferings { [weak self] (offerings, error) in
            if let error = error {
                DebugLogger.log("Error fetching offerings: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.offerings = nil
                    self?.offeringsError = error.localizedDescription
                }
                return
            }
            
            DispatchQueue.main.async {
                self?.offerings = offerings
                self?.offeringsError = nil
            }
        }
    }
    
    func purchase(package: Package) async throws -> CustomerInfo {
        let result = try await Purchases.shared.purchase(package: package)
        
        let entitlementID = AppConfig.revenueCatEntitlementID
        let entitlementActive = result.customerInfo.entitlements[entitlementID]?.isActive == true
        let anyEntitlementActive = !result.customerInfo.entitlements.active.isEmpty
        let anySubscriptionActive = !result.customerInfo.activeSubscriptions.isEmpty
        let isPremiumFromResult = entitlementActive || anyEntitlementActive || anySubscriptionActive
        
        if isPremiumFromResult {
            await MainActor.run {
                self.customerInfo = result.customerInfo
                self.updatePremiumStatus(from: result.customerInfo)
            }
        } else {
            await MainActor.run {
                self.customerInfo = result.customerInfo
                self.isPremium = true
                AppState.shared.isPremiumUser = true
                AppState.shared.userPremiumRepo.setPremium(userId: AppState.shared.currentUserId, isPremium: true)
            }
            
            DebugLogger.log("Purchase succeeded but premium not active yet; refreshing CustomerInfo.")
            refreshCustomerInfo()
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                self?.refreshCustomerInfo()
            }
        }
        
        return result.customerInfo
    }
    
    func restorePurchases() async throws -> CustomerInfo {
        let customerInfo = try await Purchases.shared.restorePurchases()
        
        await MainActor.run {
            self.customerInfo = customerInfo
            self.updatePremiumStatus(from: customerInfo)
        }
        
        return customerInfo
    }
    
    func refreshCustomerInfo() {
        Purchases.shared.getCustomerInfo { [weak self] (info, error) in
            guard let info = info, error == nil else { return }
            
            DispatchQueue.main.async {
                self?.customerInfo = info
                self?.updatePremiumStatus(from: info)
            }
        }
    }
    
    private func updatePremiumStatus(from info: CustomerInfo) {
        let entitlementID = AppConfig.revenueCatEntitlementID
        let entitlementActive = info.entitlements[entitlementID]?.isActive == true
        let anyEntitlementActive = !info.entitlements.active.isEmpty
        let anySubscriptionActive = !info.activeSubscriptions.isEmpty
        
        let isPremium = entitlementActive || anyEntitlementActive || anySubscriptionActive
        
        let apply = {
            self.isPremium = isPremium
            AppState.shared.isPremiumUser = isPremium
            AppState.shared.userPremiumRepo.setPremium(userId: AppState.shared.currentUserId, isPremium: isPremium)
        }
        
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async {
                apply()
            }
        }
        
        let userId = AppState.shared.currentUserId
        if !userId.isEmpty {
            Task {
                try? await FirebaseManager.shared.updateUserProfile(userId: userId, data: ["isPremium": isPremium])
            }
        }
        
        DebugLogger.log("Premium Status Updated: \(isPremium)")
        DebugLogger.log("Entitlement ID: \(entitlementID)")
        DebugLogger.log("Active Entitlements: \(info.entitlements.active.keys)")
        DebugLogger.log("Active Subscriptions: \(info.activeSubscriptions)")
    }
}

extension PurchaseManager: PurchasesDelegate {
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        DispatchQueue.main.async {
            self.customerInfo = customerInfo
            self.updatePremiumStatus(from: customerInfo)
        }
    }
}
