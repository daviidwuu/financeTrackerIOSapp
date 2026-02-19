import SwiftUI

struct CurrencySettingsView: View {
    @StateObject private var currencyManager = CurrencyManager.shared
    @State private var showRateModal = false
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack(alignment: .top) {
            // Background
            (colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 60)
                    
                    MenuSection("Currency Configuration") {
                        HStack {
                            Text("Main Currency")
                                .font(.body)
                                .foregroundColor(.primary)
                            Spacer()
                            Picker("Main Currency", selection: $currencyManager.mainCurrency) {
                                ForEach(currencyManager.availableCurrencies, id: \.self) { code in
                                    Text(currencyManager.currencyNames[code] ?? code).tag(code)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .tint(.secondary)
                            .onChange(of: currencyManager.mainCurrency) { _, _ in
                                HapticManager.shared.light()
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color(UIColor.secondarySystemBackground))
                        
                        MenuDivider()
                        
                        MenuRowView(title: "Travel Mode", showChevron: false, showToggle: $currencyManager.isTravelModeEnabled)
                        
                        if currencyManager.isTravelModeEnabled {
                            MenuDivider()
                            HStack {
                                Text("Travel Currency")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Spacer()
                                Picker("Travel Currency", selection: $currencyManager.travelCurrency) {
                                    ForEach(currencyManager.availableCurrencies, id: \.self) { code in
                                        Text(currencyManager.currencyNames[code] ?? code).tag(code)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .tint(.secondary)
                                .onChange(of: currencyManager.travelCurrency) { _, _ in
                                    HapticManager.shared.light()
                                }
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(Color(UIColor.secondarySystemBackground))
                            
                            MenuDivider()
                            
                            MenuRowView(title: "Auto-select Travel Currency based on Location", showChevron: false, showToggle: $currencyManager.isAutoDetectEnabled)
                        }
                    }
                    .padding(.top, 0)
                    .onChange(of: currencyManager.mainCurrency) { _, _ in
                        currencyManager.fetchExchangeRate()
                        showRateModal = true
                    }
                    .onChange(of: currencyManager.travelCurrency) { _, _ in
                        currencyManager.setTravelCurrency(currencyManager.travelCurrency)
                        showRateModal = true
                    }
                    
                    if currencyManager.isTravelModeEnabled {
                        MenuSection("Current Exchange Rate") {
                            HStack {
                                Text("1 \(currencyManager.mainCurrency)")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                Spacer()
                                if currencyManager.exchangeRate > 0 {
                                    Text("\(String(format: "%.2f", currencyManager.exchangeRate)) \(currencyManager.travelCurrency)")
                                        .fontWeight(.bold)
                                        .foregroundColor(.functionalSuccess)
                                } else {
                                    ProgressView()
                                }
                            }
                            .padding(AppSpacing.element)
                        }
                        
                        Text("Refreshed monthly based on 30-day average logic")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    
                    Spacer()
                }
                .padding(.top, 20)
            }
            
            // Fixed Navigation Bar
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .frame(width: 44, height: 44)
                        .background((colorScheme == .dark ? Color.white : Color.black).opacity(0.05))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Text("Currency Settings")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                Spacer()
                
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, AppSpacing.margin + AppSpacing.compact)
            .padding(.top, 16)
        }
        .navigationBarBackButtonHidden(true)
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
                .cornerRadius(AppRadius.medium)
                
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
