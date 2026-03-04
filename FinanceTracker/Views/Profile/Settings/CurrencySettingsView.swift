import SwiftUI

struct CurrencySettingsView: View {
    @StateObject private var currencyManager = CurrencyManager.shared
    @State private var showRateModal = false
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.backgroundPrimary
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    ScrollOffsetTracker()
                    Spacer().frame(height: 60)
                    
                    MenuSection("Currency Configuration") {
                        MenuControlRow(icon: "dollarsign", iconColor: .green, title: "Main Currency") {
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
                        
                        MenuDivider()
                        
                        MenuRowView(icon: "airplane", title: "Travel Mode", showChevron: false, showToggle: $currencyManager.isTravelModeEnabled, iconColor: .blue)
                        
                        if currencyManager.isTravelModeEnabled {
                            MenuDivider()
                            MenuControlRow(icon: "banknote", iconColor: .orange, title: "Travel Currency") {
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
                            
                            MenuDivider()
                            
                            MenuRowView(icon: "location.fill", title: "Location Auto-select", showChevron: false, showToggle: $currencyManager.isAutoDetectEnabled, iconColor: .purple)
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
                            MenuControlRow(icon: "arrow.left.arrow.right", iconColor: .indigo, title: "1 \(currencyManager.mainCurrency)") {
                                HStack {
                                    Image(systemName: "arrow.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 4)
                                    
                                    if currencyManager.exchangeRate > 0 {
                                        Text("\(String(format: "%.2f", currencyManager.exchangeRate)) \(currencyManager.travelCurrency)")
                                            .fontWeight(.bold)
                                            .foregroundColor(.functionalSuccess)
                                    } else {
                                        ProgressView()
                                    }
                                }
                            }
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
        }
        .overlayHeader(.navigation(title: "Currency Settings", onBack: { dismiss() }))
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
        NavigationStack {
            ZStack {
                Color.backgroundPrimary.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppSpacing.section) {
                        ScrollOffsetTracker()
                        Spacer().frame(height: 80)
                        
                        VStack(spacing: AppSpacing.element) {
                            Text("Exchange Rate")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            HStack(alignment: .center, spacing: AppSpacing.margin) {
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("1")
                                        .font(.system(size: 32, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                    Text(currencyManager.mainCurrency)
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(AppTheme.activeTheme == .system ? .primary : .themeAccent)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    if currencyManager.exchangeRate > 0 {
                                        Text(String(format: "%.2f", currencyManager.exchangeRate))
                                            .font(.system(size: 32, weight: .bold, design: .rounded))
                                            .foregroundColor(AppTheme.activeTheme == .system ? .primary : .themeAccent)
                                    } else {
                                        ProgressView()
                                            .frame(height: 38)
                                    }
                                    Text(currencyManager.travelCurrency)
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(32)
                        .frame(maxWidth: .infinity)
                        .background(Color.cardBackground)
                        .cornerRadius(AppRadius.large)
                        .padding(.horizontal, AppSpacing.margin)
                        
                        Text("Rates are updated periodically and represent an approximate 30-day average.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Spacer()
                        
                        Button(action: {
                            HapticManager.shared.light()
                            dismiss()
                        }) {
                            Text("Got it")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.horizontal, AppSpacing.margin)
                        .padding(.top, AppSpacing.margin)
                    }
                    .padding(.bottom, AppSpacing.margin)
                }
            }
            .overlayHeader(.navigation(
                title: "Exchange Rate",
                onBack: { dismiss() },
                backIcon: "xmark"
            ))
            .navigationBarBackButtonHidden(true)
        }
        .presentationDetents([.fraction(0.6), .medium])
        .presentationDragIndicator(.visible)
    }
}
