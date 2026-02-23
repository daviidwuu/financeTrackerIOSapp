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
    
    enum PlanType {
        case monthly
        case annual
    }
    
    var annualPackage: Package? {
        purchaseManager.offerings?.current?.annual
    }
    
    var monthlyPackage: Package? {
        purchaseManager.offerings?.current?.monthly
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Background
                (colorScheme == .dark ? Color.black : Color.white)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with Restore Button
                    HStack {
                        Button("Restore") {
                            restorePurchases()
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                                .opacity(0.8)
                        }
                    }
                    .padding(.horizontal, 20)
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
                                
                                Text("wymKING")
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
                            if purchaseManager.offerings != nil {
                                VStack(spacing: 12) {
                                    if let annual = annualPackage {
                                        PlanCard(
                                            title: "Annual Plan",
                                            price: annual.storeProduct.localizedPriceString,
                                            subtitle: "Best Value",
                                            priceSubtitle: calculateMonthlyPrice(for: annual),
                                            isSelected: selectedPlan == .annual,
                                            action: { selectedPlan = .annual }
                                        )
                                    }
                                    
                                    if let monthly = monthlyPackage {
                                        PlanCard(
                                            title: "Monthly Plan",
                                            price: monthly.storeProduct.localizedPriceString,
                                            subtitle: "Flexible",
                                            isSelected: selectedPlan == .monthly,
                                            action: { selectedPlan = .monthly }
                                        )
                                    }
                                }
                                .padding(.horizontal, AppSpacing.margin)
                                .padding(.top, 10)
                            } else {
                                ProgressView()
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
                    .disabled(isLoading || purchaseManager.offerings == nil)
                    .opacity(isLoading || purchaseManager.offerings == nil ? 0.6 : 1.0)
                    .padding(.horizontal, AppSpacing.margin)
                    
                    HStack(spacing: 12) {
                        Button("Terms of Service") { }
                        Text("•")
                        Button("Privacy Policy") { }
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
        }
        .onAppear {
            purchaseManager.fetchOfferings()
        }
    }
    
    private func calculateMonthlyPrice(for package: Package) -> String {
        let price = package.storeProduct.price
        let monthlyPrice = NSDecimalNumber(decimal: price).doubleValue / 12.0
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = package.storeProduct.priceFormatter?.locale
        return (formatter.string(from: NSNumber(value: monthlyPrice)) ?? "") + " / month"
    }
    
    private func makePurchase() {
        guard let package = (selectedPlan == .annual ? annualPackage : monthlyPackage) else { return }
        
        isLoading = true
        errorMessage = nil
        HapticManager.shared.medium()
        
        Task {
            do {
                _ = try await purchaseManager.purchase(package: package)
                isLoading = false
                dismiss()
            } catch {
                isLoading = false
                // Handle user cancelled error gracefully
                if let purchaseError = error as? RevenueCat.ErrorCode, purchaseError == .purchaseCancelledError {
                    return
                }
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func restorePurchases() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                _ = try await purchaseManager.restorePurchases()
                isLoading = false
                showRestoreAlert = true
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
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
