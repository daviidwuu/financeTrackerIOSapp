import SwiftUI

struct CurrencySettingsView: View {
    @StateObject private var currencyManager = CurrencyManager.shared
    @State private var showRateModal = false
    
    var body: some View {
        Form {
            Section(header: Text("Currency Configuration")) {
                // Main Currency
                Picker("Main Currency", selection: $currencyManager.mainCurrency) {
                    ForEach(currencyManager.availableCurrencies, id: \.self) { code in
                        Text(currencyManager.currencyNames[code] ?? code).tag(code)
                    }
                }
                .onChange(of: currencyManager.mainCurrency) {
                    currencyManager.fetchExchangeRate()
                    showRateModal = true
                }
                
                // Travel Mode Toggle
                Toggle("Travel Mode", isOn: $currencyManager.isTravelModeEnabled)
                
                if currencyManager.isTravelModeEnabled {
                    // Travel Currency
                    Picker("Travel Currency", selection: $currencyManager.travelCurrency) {
                        ForEach(currencyManager.availableCurrencies, id: \.self) { code in
                            Text(currencyManager.currencyNames[code] ?? code).tag(code)
                        }
                    }
                    .onChange(of: currencyManager.travelCurrency) {
                        currencyManager.setTravelCurrency(currencyManager.travelCurrency)
                        showRateModal = true
                    }
                    
                    Toggle("Auto-select Travel Currency based on Location", isOn: $currencyManager.isAutoDetectEnabled)
                }
            }
            
            if currencyManager.isTravelModeEnabled {
                Section(header: Text("Current Exchange Rate")) {
                    HStack {
                        Text("1 \(currencyManager.mainCurrency)")
                        Spacer()
                        Image(systemName: "arrow.right")
                        Spacer()
                        if currencyManager.exchangeRate > 0 {
                            Text("\(String(format: "%.2f", currencyManager.exchangeRate)) \(currencyManager.travelCurrency)")
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        } else {
                            ProgressView()
                        }
                    }
                    Text("Refreshed monthly based on 30-day average logic")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Currency Settings")
        .sheet(isPresented: $showRateModal) {
            CurrencyRateModal(currencyManager: currencyManager)
        }
    }
}

struct CurrencyRateModal: View {
    @ObservedObject var currencyManager: CurrencyManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                
                VStack(spacing: 8) {
                    Text("Current Exchange Rate")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline) {
                        Text("1")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(currencyManager.mainCurrency)
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Image(systemName: "arrow.right")
                            .font(.title2)
                            .padding(.horizontal)
                        
                        Text(String(format: "%.2f", currencyManager.exchangeRate))
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.blue)
                        Text(currencyManager.travelCurrency)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(16)
                
                Text("Rate fetched online (approx. 30d average).")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                Button(action: {
                    // Confirm selection (Tick)
                    dismiss()
                }) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("Exchange Rate")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                         dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
