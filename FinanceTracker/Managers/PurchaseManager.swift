import Foundation
import RevenueCat
import StoreKit
import Combine

class PurchaseManager: NSObject, ObservableObject {
    static let shared = PurchaseManager()
    
    @Published var customerInfo: CustomerInfo?
    @Published var offerings: Offerings?
    @Published var isPremium = false
    
    private override init() {
        super.init()
    }
    
    func configure(apiKey: String) {
        Purchases.configure(withAPIKey: apiKey)
        Purchases.logLevel = .debug
        
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
                return
            }
            
            DispatchQueue.main.async {
                self?.offerings = offerings
            }
        }
    }
    
    func purchase(package: Package) async throws -> CustomerInfo {
        let result = try await Purchases.shared.purchase(package: package)
        
        // Update local state
        await MainActor.run {
            self.customerInfo = result.customerInfo
            self.updatePremiumStatus(from: result.customerInfo)
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
        // Check for specific entitlement
        let isPremium = info.entitlements["wym King"]?.isActive == true
        self.isPremium = isPremium
        
        // Sync with AppState
        DispatchQueue.main.async {
            AppState.shared.isPremiumUser = isPremium
        }
        
        DebugLogger.log("Premium Status Updated: \(isPremium)")
        DebugLogger.log("Active Entitlements: \(info.entitlements.active.keys)")
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
