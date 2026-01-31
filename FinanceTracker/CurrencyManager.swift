import Foundation
import Combine

class CurrencyManager: ObservableObject {
    static let shared = CurrencyManager()
    
    // User Preferences
    @Published var mainCurrency: String {
        didSet { UserDefaults.standard.set(mainCurrency, forKey: "mainCurrency") }
    }
    @Published var travelCurrency: String {
        didSet { UserDefaults.standard.set(travelCurrency, forKey: "travelCurrency") }
    }
    @Published var isTravelModeEnabled: Bool {
        didSet { UserDefaults.standard.set(isTravelModeEnabled, forKey: "isTravelModeEnabled") }
    }
    @Published var isAutoDetectEnabled: Bool {
        didSet { UserDefaults.standard.set(isAutoDetectEnabled, forKey: "isCurrencyAutoDetectEnabled") }
    }
    
    // Exchange Rate Data
    @Published var exchangeRate: Double = 1.0 // 1 Main = X Travel
    @Published var lastUpdated: Date?
    
    // Supported Currencies (Simplified List)
    let availableCurrencies = [
        "MYR", "CNY", "THB", "IDR", "VND", "USD", "EUR", "SGD", 
        "JPY", "KRW", "GBP", "AUD", "CAD", "HKD", "TWD", "PHP", 
        "INR", "MXN", "CHF", "NZD", "TRY", "BRL", "RUB", "ZAR"
    ]
    
    let currencyNames: [String: String] = [
        "MYR": "Malaysia (Ringgit)",
        "CNY": "China (RMB)",
        "THB": "Thailand (Baht)",
        "IDR": "Indonesia (Rupiah)",
        "VND": "Vietnam (Dong)",
        "USD": "United States (Dollar)",
        "EUR": "Europe (Euro)",
        "SGD": "Singapore (Dollar)",
        "JPY": "Japan (Yen)",
        "KRW": "South Korea (Won)",
        "GBP": "United Kingdom (Pound)",
        "AUD": "Australia (Dollar)",
        "CAD": "Canada (Dollar)",
        "HKD": "Hong Kong (Dollar)",
        "TWD": "Taiwan (Dollar)",
        "PHP": "Philippines (Peso)",
        "INR": "India (Rupee)",
        "CHF": "Switzerland (Franc)",
        "NZD": "New Zealand (Dollar)",
        "MXN": "Mexico (Peso)",
        "TRY": "Turkey (Lira)",
        "BRL": "Brazil (Real)",
        "RUB": "Russia (Ruble)",
        "ZAR": "South Africa (Rand)"
    ]
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.mainCurrency = UserDefaults.standard.string(forKey: "mainCurrency") ?? "SGD"
        self.travelCurrency = UserDefaults.standard.string(forKey: "travelCurrency") ?? "USD"
        self.isTravelModeEnabled = UserDefaults.standard.bool(forKey: "isTravelModeEnabled")
        self.isAutoDetectEnabled = UserDefaults.standard.bool(forKey: "isCurrencyAutoDetectEnabled") // Default false, strictly manual unless enabled
        
        loadSavedRate()
    }
    
    func setTravelCurrency(_ code: String) {
        // Update local property
        if travelCurrency != code {
            travelCurrency = code
        }
        
        // Always fetch new rate when explicitly set
        fetchExchangeRate()
    }
    
    func fetchExchangeRate() {
        guard mainCurrency != travelCurrency else {
            self.exchangeRate = 1.0
            return
        }
        
        let urlString = "https://open.er-api.com/v6/latest/\(mainCurrency)"
        guard let url = URL(string: urlString) else { return }
        
        // Use Task for async context
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let result = try JSONDecoder().decode(ExchangeRateResponse.self, from: data)
                
                if let rate = result.rates[self.travelCurrency] {
                    await MainActor.run {
                        self.exchangeRate = rate
                        self.lastUpdated = Date()
                        self.saveRate(rate: rate)
                    }
                }
            } catch {
                DebugLogger.log("Error fetching rates: \(error)")
            }
        }
    }
    
    private func saveRate(rate: Double) {
        UserDefaults.standard.set(rate, forKey: "savedExchangeRate_\(mainCurrency)_\(travelCurrency)")
        UserDefaults.standard.set(Date(), forKey: "savedExchangeRateDate")
    }
    
    private func loadSavedRate() {
        let key = "savedExchangeRate_\(mainCurrency)_\(travelCurrency)"
        let saved = UserDefaults.standard.double(forKey: key)
        if saved != 0 {
            self.exchangeRate = saved
        }
        
        // Check if we need to refresh (user said "refreshed every 30d (start of the month)")
        // logic: if now is a different month than lastUpdated, fetch.
        let dateKey = "savedExchangeRateDate"
        if let date = UserDefaults.standard.object(forKey: dateKey) as? Date {
            self.lastUpdated = date
            let components = Calendar.current.dateComponents([.month, .year], from: date)
            let currentComponents = Calendar.current.dateComponents([.month, .year], from: Date())
            
            if components.month != currentComponents.month || components.year != currentComponents.year {
                fetchExchangeRate()
            }
        } else {
            fetchExchangeRate()
        }
    }
    
    // Helper to get currency logic
    func convertToMain(amount: Double, from currency: String) -> Double {
        if currency == mainCurrency { return amount }
        if currency == travelCurrency {
            // exchangeRate is 1 Main = X Travel -> Travel / X = Main
            // e.g. 1 SGD = 5.4 RMB. Amount 540 RMB. 540 / 5.4 = 100 SGD.
            return amount / exchangeRate
        }
        return amount // Fallback
    }
}

struct ExchangeRateResponse: Codable, Sendable {
    let result: String
    let rates: [String: Double]
}
