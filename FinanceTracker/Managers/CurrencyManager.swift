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
    @Published var exchangeRate: Double = 1.0 // 1 Main = X Travel (backward compat)
    @Published var lastUpdated: Date?
    
    // FIX #9: Store all rates keyed by currency code for multi-currency conversion
    // Key = currency code, Value = rate relative to mainCurrency (1 Main = X Target)
    private var allRates: [String: Double] = [:]
    
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
                
                await MainActor.run {
                    // FIX #9: Store ALL rates for multi-currency support
                    self.allRates = result.rates
                    
                    if let rate = result.rates[self.travelCurrency] {
                        self.exchangeRate = rate
                    }
                    self.lastUpdated = Date()
                    self.saveRate()
                }
            } catch {
                DebugLogger.log("Error fetching rates: \(error)")
            }
        }
    }
    
    private func saveRate() {
        // Save the travel currency rate for backward compat
        UserDefaults.standard.set(exchangeRate, forKey: "savedExchangeRate_\(mainCurrency)_\(travelCurrency)")
        UserDefaults.standard.set(Date(), forKey: "savedExchangeRateDate")
        
        // FIX #9: Also persist all rates
        if let data = try? JSONEncoder().encode(allRates) {
            UserDefaults.standard.set(data, forKey: "savedAllRates_\(mainCurrency)")
        }
    }
    
    private func loadSavedRate() {
        let key = "savedExchangeRate_\(mainCurrency)_\(travelCurrency)"
        let saved = UserDefaults.standard.double(forKey: key)
        if saved != 0 {
            self.exchangeRate = saved
        }
        
        // FIX #9: Load cached all-rates dictionary
        if let data = UserDefaults.standard.data(forKey: "savedAllRates_\(mainCurrency)"),
           let rates = try? JSONDecoder().decode([String: Double].self, from: data) {
            self.allRates = rates
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
    
    // FIX #9: Convert from ANY currency to main using stored rates
    func convertToMain(amount: Double, from currency: String) -> Double {
        if currency == mainCurrency { return amount }
        
        // Try the all-rates dictionary first (supports any cached currency)
        if let rate = allRates[currency], rate > 0 {
            // allRates[currency] = how many units of `currency` per 1 mainCurrency
            // So: amount_in_currency / rate = amount_in_main
            return amount / rate
        }
        
        // Legacy fallback: only works for travel currency
        if currency == travelCurrency {
            return amount / exchangeRate
        }
        
        DebugLogger.log("Warning: No exchange rate available for \(currency) → \(mainCurrency). Returning unconverted.")
        return amount // Fallback: no rate available
    }
    
    /// FIX 1.1: Returns conversion rate from `source` to `target` using cached allRates.
    /// allRates is keyed as: 1 mainCurrency = X targetCurrency.
    /// To convert source→target: amount * (targetRate / sourceRate)
    /// Returns 1.0 if rates are unavailable (safe fallback).
    func getRate(from source: String, to target: String) -> Double {
        if source == target { return 1.0 }
        
        // Both currencies need a rate relative to mainCurrency
        // allRates[X] = how many units of X per 1 mainCurrency
        // So: 1 source = (1/sourceRate) mainCurrency = (targetRate/sourceRate) target
        
        // Edge case: source IS mainCurrency
        if source == mainCurrency {
            if let targetRate = allRates[target], targetRate > 0 {
                return targetRate // 1 main = targetRate target
            }
            // Legacy fallback for travel currency
            if target == travelCurrency { return exchangeRate }
            DebugLogger.log("⚠️ Missing rate for \(source)→\(target), returning 1.0")
            return 1.0
        }
        
        // Edge case: target IS mainCurrency
        if target == mainCurrency {
            if let sourceRate = allRates[source], sourceRate > 0 {
                return 1.0 / sourceRate // 1 source = (1/sourceRate) main
            }
            if source == travelCurrency && exchangeRate > 0 { return 1.0 / exchangeRate }
            DebugLogger.log("⚠️ Missing rate for \(source)→\(target), returning 1.0")
            return 1.0
        }
        
        // General case: source→main→target
        guard let sourceRate = allRates[source], sourceRate > 0,
              let targetRate = allRates[target], targetRate > 0 else {
            DebugLogger.log("⚠️ Missing rate for \(source)→\(target), returning 1.0")
            return 1.0
        }
        return targetRate / sourceRate
    }
}

struct ExchangeRateResponse: Codable, Sendable {
    let result: String
    let rates: [String: Double]
}
