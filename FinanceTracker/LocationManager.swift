import Foundation
import CoreLocation
import Combine
import SwiftUI

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    @Published var currentCountryCode: String?
    @Published var currentCountryName: String?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }
    
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func checkLocation() {
        guard CurrencyManager.shared.isTravelModeEnabled else { return }
        
        let status = locationManager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.requestLocation()
        }
    }
    
    // CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self, let placemark = placemarks?.first, error == nil else { return }
            
            if let countryCode = placemark.isoCountryCode,
               let countryName = placemark.country {
                
                self.handleCountryUpdate(code: countryCode, name: countryName)
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DebugLogger.log("Location Manager Error: \(error)")
    }
    
    private func handleCountryUpdate(code: String, name: String) {
        let lastCode = UserDefaults.standard.string(forKey: "lastCountryCode")
        
        if lastCode != code {
            // Country changed!
            UserDefaults.standard.set(code, forKey: "lastCountryCode")
            
            // 1. Notify user
            if lastCode != nil { // Only notify if we had a previous country (don't spam on fresh install)
               sendCountryChangeNotification(countryName: name)
            }
            
            // 2. Auto-select currency if enabled
            if CurrencyManager.shared.isAutoDetectEnabled {
                if let currency = countryCurrencyMapping[code] {
                    DispatchQueue.main.async {
                        CurrencyManager.shared.setTravelCurrency(currency)
                    }
                }
            }
        }
        
        DispatchQueue.main.async {
            self.currentCountryCode = code
            self.currentCountryName = name
        }
    }
    
    private func sendCountryChangeNotification(countryName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Welcome to \(countryName)!"
        content.body = "Tap to set up your Travel Currency settings."
        content.sound = .default
        content.userInfo = ["type": "travel_update", "country": countryName]
        
        let request = UNNotificationRequest(identifier: "country_change", content: content, trigger: nil) // Immediate
        UNUserNotificationCenter.current().add(request)
    }
    
    // Simple Mapping for key countries
    private let countryCurrencyMapping: [String: String] = [
        "US": "USD", "SG": "SGD", "CN": "CNY", "JP": "JPY", "GB": "GBP",
        "AU": "AUD", "CA": "CAD", "CH": "CHF", "NZ": "NZD", "KR": "KRW",
        "IN": "INR", "MX": "MXN", "TW": "TWD", "TH": "THB", "MY": "MYR",
        "ID": "IDR", "VN": "VND", "PH": "PHP", "TR": "TRY", "BR": "BRL",
        "RU": "RUB", "ZA": "ZAR",
        "DE": "EUR", "FR": "EUR", "IT": "EUR", "ES": "EUR", "NL": "EUR" // Eurozone
    ]
}
