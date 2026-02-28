import SwiftUI
import RevenueCat

struct SubscriptionWizardView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var selectedPlan: PlanType = .annual
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showRestoreAlert = false
    @State private var showTerms = false
    @State private var showPrivacy = false
    
    enum PlanType {
        case monthly
        case annual
    }
    
    private var offering: Offering? {
        purchaseManager.offerings?.current ?? purchaseManager.offerings?.all.values.first
    }
    
    var annualPackage: Package? {
        offering?.annual ?? package(matching: .year)
    }
    
    var monthlyPackage: Package? {
        offering?.monthly ?? package(matching: .month)
    }
    
    private var canPurchaseSelectedPlan: Bool {
        switch selectedPlan {
        case .annual:
            return annualPackage != nil
        case .monthly:
            return monthlyPackage != nil
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Background
                (colorScheme == .dark ? Color.black : Color.white)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ZStack {
                        HStack(spacing: 10) {
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .frame(width: 44, height: 44)
                                    .background(Color.primary.opacity(0.05))
                                    .clipShape(Circle())
                            }
                            
                            Spacer()
                            
                            Button(action: { restorePurchases() }) {
                                Text("Restore")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color.primary.opacity(0.05))
                                    .clipShape(Capsule())
                            }
                        }
                        
                        Text("Subscription")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, AppSpacing.margin + AppSpacing.compact)
                    .padding(.top, 16)
                    
                    ScrollView {
                        VStack(spacing: AppSpacing.section) {
                            
                            // Hero Section
                            VStack(spacing: 16) {
                                Text("king")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: "#F5A623")) // Gold
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color(hex: "#F5A623").opacity(0.15))
                                    .cornerRadius(12)
                                    .padding(.top, 20)
                                
                                Text("King")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                                    .multilineTextAlignment(.center)
                                
                                Text("Take control with zero interruptions. Unlock the full potential of your finances.")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, AppSpacing.margin)
                            }
                            .padding(.top, 20)
                            
                            // Features List
                            VStack(alignment: .leading, spacing: 20) {
                                FeatureRow(icon: "nosign", title: "Ad-Free Experience", description: "Remove all native and banner ads.")
                                FeatureRow(icon: "sparkles", title: "Premium Features", description: "Early access to upcoming tools.")
                                FeatureRow(icon: "headphones", title: "Priority Support", description: "Get answers to your questions faster.")
                            }
                            .padding(.horizontal, AppSpacing.margin)
                            .padding(.top, 10)
                            
                            // Pricing Cards
                            if offering != nil {
                                VStack(spacing: 12) {
                                    if let annual = annualPackage {
                                        PlanCard(
                                            title: "Annual Plan",
                                            price: formatPrice(price: annual.storeProduct.price, formatter: annual.storeProduct.priceFormatter),
                                            subtitle: "Best Value",
                                            priceSubtitle: calculateMonthlyPrice(annualPrice: annual.storeProduct.price, formatter: annual.storeProduct.priceFormatter),
                                            isSelected: selectedPlan == .annual,
                                            action: { selectedPlan = .annual }
                                        )
                                    }
                                    
                                    if let monthly = monthlyPackage {
                                        PlanCard(
                                            title: "Monthly Plan",
                                            price: formatPrice(price: monthly.storeProduct.price, formatter: monthly.storeProduct.priceFormatter),
                                            subtitle: "Flexible",
                                            isSelected: selectedPlan == .monthly,
                                            action: { selectedPlan = .monthly }
                                        )
                                    }
                                    
                                    if annualPackage == nil && monthlyPackage == nil {
                                        Text("Subscriptions are unavailable right now.")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                            .padding(.top, 12)
                                    }
                                }
                                .padding(.horizontal, AppSpacing.margin)
                                .padding(.top, 10)
                            } else {
                                VStack(spacing: 12) {
                                    if purchaseManager.offerings == nil {
                                        ProgressView()
                                    } else {
                                        Text("Subscriptions are unavailable right now.")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, AppSpacing.margin)
                                    }
                                    
                                    if let error = purchaseManager.offeringsError {
                                        Text(error)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, AppSpacing.margin)
                                    }
                                    
                                    Button("Try Again") {
                                        purchaseManager.fetchOfferings()
                                    }
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color.primary.opacity(0.05))
                                    .clipShape(Capsule())
                                }
                                .padding(.top, 40)
                            }
                            
                            // Bottom Padding for fixed button
                            Spacer().frame(height: 140)
                        }
                    }
                    .scrollIndicators(.hidden)
                }
                
                // Fixed Bottom Area (CTA + Footer)
                VStack(spacing: 16) {
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    Button(action: {
                        makePurchase()
                    }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(colorScheme == .dark ? .black : .white)
                                    .padding(.trailing, 8)
                            }
                            Text(isLoading ? "Processing..." : "Subscribe Now")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(colorScheme == .dark ? Color.white : Color.black)
                        .clipShape(Capsule())
                    }
                    .disabled(isLoading || offering == nil || !canPurchaseSelectedPlan)
                    .opacity(isLoading || offering == nil || !canPurchaseSelectedPlan ? 0.6 : 1.0)
                    .padding(.horizontal, AppSpacing.margin)
                    
                    Text("Auto-renewable subscription. Cancel anytime in App Store settings.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.margin)
                    
                    HStack(spacing: 12) {
                        if let url = AppConfig.termsURL {
                            Link("Terms of Service", destination: url)
                        } else {
                            Button("Terms of Service") { showTerms = true }
                        }
                        Text("•")
                        if let url = AppConfig.privacyURL {
                            Link("Privacy Policy", destination: url)
                        } else {
                            Button("Privacy Policy") { showPrivacy = true }
                        }
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 20)
                }
                .background(
                    LinearGradient(
                        colors: [
                            (colorScheme == .dark ? Color.black : Color.white).opacity(0),
                            (colorScheme == .dark ? Color.black : Color.white)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .navigationBarHidden(true)
            .alert("Purchase Restored", isPresented: $showRestoreAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your purchases have been successfully restored.")
            }
            .sheet(isPresented: $showTerms) {
                LegalDocumentView(document: .terms)
            }
            .sheet(isPresented: $showPrivacy) {
                LegalDocumentView(document: .privacy)
            }
        }
        .onAppear {
            purchaseManager.fetchOfferings()
        }
        .task(id: purchaseManager.offerings == nil ? 0 : 1) {
            guard offering != nil else { return }
            
            if selectedPlan == .annual, annualPackage == nil, monthlyPackage != nil {
                selectedPlan = .monthly
            } else if selectedPlan == .monthly, monthlyPackage == nil, annualPackage != nil {
                selectedPlan = .annual
            }
        }
    }
    
    private func formatPrice(price: Decimal, formatter: NumberFormatter?) -> String {
        if let formatter {
            let value = formatter.string(from: NSDecimalNumber(decimal: price)) ?? ""
            if !value.isEmpty { return value }
        }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        let value = formatter.string(from: NSDecimalNumber(decimal: price)) ?? ""
        if !value.isEmpty { return value }
        return NSDecimalNumber(decimal: price).stringValue
    }
    
    private func calculateMonthlyPrice(annualPrice: Decimal, formatter: NumberFormatter?) -> String {
        let annual = NSDecimalNumber(decimal: annualPrice)
        let monthly = annual.dividing(by: 12, withBehavior: NSDecimalNumberHandler(roundingMode: .plain, scale: 2, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false))
        
        if let formatter {
            let value = formatter.string(from: monthly) ?? ""
            if !value.isEmpty { return value + " / month" }
        }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        let value = formatter.string(from: monthly) ?? ""
        if !value.isEmpty { return value + " / month" }
        return monthly.stringValue + " / month"
    }
    
    private func package(matching unit: SubscriptionPeriod.Unit) -> Package? {
        offering?.availablePackages.first(where: {
            $0.storeProduct.subscriptionPeriod?.unit == unit
        })
    }
    
    private func makePurchase() {
        guard let package = (selectedPlan == .annual ? annualPackage : monthlyPackage) else { return }
        
        isLoading = true
        errorMessage = nil
        HapticManager.shared.medium()
        
        Task {
            do {
                _ = try await purchaseManager.purchase(package: package)
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                if let rcError = error as? RevenueCat.ErrorCode, rcError == .purchaseCancelledError {
                    await MainActor.run {
                        isLoading = false
                    }
                    return
                }
                
                let nsError = error as NSError
                if nsError.domain.contains("RevenueCat.ErrorCode"),
                   nsError.code == RevenueCat.ErrorCode.purchaseCancelledError.errorCode {
                    await MainActor.run {
                        isLoading = false
                    }
                    return
                }
                
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func restorePurchases() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                _ = try await purchaseManager.restorePurchases()
                await MainActor.run {
                    isLoading = false
                    showRestoreAlert = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Subcomponents

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct PlanCard: View {
    let title: String
    let price: String
    let subtitle: String?
    var priceSubtitle: String? = nil
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        let titleColor = isSelected ? (colorScheme == .dark ? Color.black : Color.white) : Color.primary
        let subtitleColor = isSelected ? (colorScheme == .dark ? Color.black : Color.white).opacity(0.8) : Color.secondary
        let backgroundColor = isSelected ? (colorScheme == .dark ? Color.white : Color.black) : Color.clear
        let borderColor = isSelected ? Color.clear : (colorScheme == .dark ? Color.white : Color.black).opacity(0.2)
        
        Button(action: {
            HapticManager.shared.light()
            action()
        }, label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(titleColor)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(subtitleColor)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(price)
                        .font(.headline)
                        .foregroundColor(titleColor)
                    
                    if let priceSubtitle = priceSubtitle {
                        Text(priceSubtitle)
                            .font(.caption)
                            .foregroundColor(subtitleColor)
                    }
                }
            }
            .contentShape(Rectangle())
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(borderColor, lineWidth: 1)
            )
        })
        .buttonStyle(.plain)
    }
}

#Preview {
    SubscriptionWizardView()
}
