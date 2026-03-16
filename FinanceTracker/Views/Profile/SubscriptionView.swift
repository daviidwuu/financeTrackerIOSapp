import SwiftUI
import RevenueCat

struct SubscriptionView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
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
        ZStack(alignment: .bottom) {
            // Background
            Color.backgroundPrimary
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 60)
                        
                        // Hero Section
                        VStack(spacing: 12) {
                            Text("king")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "#F5A623")) // Gold
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(Color(hex: "#F5A623").opacity(0.15))
                                .cornerRadius(AppRadius.medium)
                                .shadow(color: Color(hex: "#F5A623").opacity(0.3), radius: 8, x: 0, y: 4)
                            
                            Text("Unlock the full potential of your finances.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, AppSpacing.margin)
                        }
                        
                        // Features List
                        VStack(alignment: .leading, spacing: 16) {
                            FeatureRow(icon: "nosign", title: "Ad-Free", description: "Zero interruptions. Remove all ads.")
                            FeatureRow(icon: "paintbrush.fill", title: "Custom Themes", description: "Personalize your app with premium themes.")
                            FeatureRow(icon: "star.fill", title: "Pro Badges", description: "Exclusive badges visible to your friends.")
                            FeatureRow(icon: "sparkles", title: "More Pro Features", description: "Coming soon. Get early access to new tools.")
                        }
                        .padding(.horizontal, AppSpacing.margin)
                        .padding(.top, 8)
                        
                        // Pricing Cards
                        if offering != nil {
                            VStack(spacing: 16) {
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
                                }
                            }
                            .padding(.horizontal, AppSpacing.margin)
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
                                
                                Button("Try Again") { HapticManager.shared.light(); 
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
                            .padding(.top, 20)
                        }
                        
                        // Bottom Padding for fixed button area
                        Spacer().frame(height: 140)
                    }
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize) // Prevents bouncing if content fits

            // Fixed Bottom Area (CTA + Footer)
            VStack(spacing: 12) {
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Button(action: { HapticManager.shared.light(); 
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
                
                Text("A 'King' subscription is available as an Annual Plan or Monthly Plan. It automatically renews unless canceled at least 24 hours before the end of the current period. You can manage and cancel your subscriptions in your App Store account settings.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.margin)
                
                HStack(spacing: 12) {
                    if let url = AppConfig.termsURL {
                        Link("Terms of Use", destination: url)
                    } else {
                        Button("Terms of Use") { HapticManager.shared.light();  showTerms = true }
                    }
                    Text("•")
                    if let url = AppConfig.privacyURL {
                        Link("Privacy Policy", destination: url)
                    } else {
                        Button("Privacy Policy") { HapticManager.shared.light();  showPrivacy = true }
                    }
                }
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.bottom, 16)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color.backgroundPrimary.opacity(0),
                        Color.backgroundPrimary,
                        Color.backgroundPrimary
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .overlayHeader(.navigation(
            title: "Subscription",
            onBack: { dismiss() },
            trailing: AnyView(
                Button(action: { HapticManager.shared.light();  restorePurchases() }) {
                    Text("Restore")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(Capsule())
                }
            )
        ))
        .navigationBarBackButtonHidden(true)
        .alert("Purchase Restored", isPresented: $showRestoreAlert) {
            Button("OK", role: .cancel) { HapticManager.shared.light();  }
        } message: {
            Text("Your purchases have been successfully restored.")
        }
        .sheet(isPresented: $showTerms) {
            LegalDocumentView(document: .terms)
        }
        .sheet(isPresented: $showPrivacy) {
            LegalDocumentView(document: .privacy)
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
                // Auto-create recurring transaction for the subscription
                await createSubscriptionRecurring(for: package)
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
    
    private func createSubscriptionRecurring(for package: Package) async {
        let userId = appState.currentUserId
        guard !userId.isEmpty else { return }

        let isAnnual = package.storeProduct.subscriptionPeriod?.unit == .year
        let name = isAnnual ? "wym annually" : "wym monthly"
        let frequency = isAnnual ? "Yearly" : "Monthly"
        let amount = NSDecimalNumber(decimal: package.storeProduct.price).doubleValue

        // Find or create Bills category
        var categoryId: String? = nil
        if let bills = appState.budgetRepo.getCategoryByName(for: "Bills") {
            categoryId = bills.id
        } else {
            // Create Bills category
            let newBills = FirestoreModels.CategoryBudget(
                category: "Bills",
                totalAmount: 0,
                icon: "doc.text.fill",
                colorHex: "#FF3B30",
                frequency: "Monthly",
                type: "expense",
                userId: userId,
                monthStartDate: Calendar.current.startOfDay(for: Date()),
                createdAt: Date()
            )
            try? await appState.budgetRepo.addBudget(newBills)
            // Wait briefly for listener to pick up the new category
            try? await Task.sleep(nanoseconds: 500_000_000)
            categoryId = appState.budgetRepo.getCategoryByName(for: "Bills")?.id
        }

        let recurring = FirestoreModels.RecurringTransaction(
            name: name,
            amount: -abs(amount),
            frequency: frequency,
            startDate: Date(),
            categoryId: categoryId,
            icon: "doc.text.fill",
            colorHex: "#FF3B30",
            note: "Auto-created from subscription",
            type: "expense",
            userId: userId,
            createdAt: Date(),
            source: "subscription"
        )
        try? await appState.recurringRepo.addRecurringTransaction(recurring)
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
        let borderColor = isSelected ? Color(hex: "#F5A623") : (colorScheme == .dark ? Color.white : Color.black).opacity(0.15)
        
        Button(action: { HapticManager.shared.light(); 
            action()
        }, label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
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
                
                VStack(alignment: .trailing, spacing: 2) {
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
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(backgroundColor)
            )
            .shadow(color: isSelected ? Color(hex: "#F5A623").opacity(0.2) : Color.clear, radius: 8, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
            )
        })
        .buttonStyle(.plain)
    }
}

// MARK: - Legacy Alias (used by WelcomeView as a sheet)

/// Wraps SubscriptionView in its own NavigationStack for sheet presentation.
struct SubscriptionWizardView: View {
    var body: some View {
        NavigationStack {
            SubscriptionView()
        }
    }
}

#Preview {
    SubscriptionView()
}
