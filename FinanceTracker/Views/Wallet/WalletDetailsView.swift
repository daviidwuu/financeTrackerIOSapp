import SwiftUI

struct WalletDetailsView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var initialBalance: Double

    let totalBalance: Double
    let aggregatedIncome: Double
    let aggregatedExpense: Double
    let currentMonthIncome: Double
    let currentMonthExpense: Double
    let totalBudget: Double

    @State private var amount: String = ""
    @FocusState private var isFocused: Bool

    // MARK: - Computed Insights

    private var monthNet: Double { currentMonthIncome - currentMonthExpense }

    private var savingsRate: Double? {
        guard currentMonthIncome > 0 else { return nil }
        return (currentMonthIncome - currentMonthExpense) / currentMonthIncome * 100
    }

    private var budgetUtilization: Double? {
        guard totalBudget > 0 else { return nil }
        return min(currentMonthExpense / totalBudget, 1.0)
    }

    private var allTimeNet: Double { aggregatedIncome - aggregatedExpense }

    // MARK: - Formatting

    private func fmt(_ value: Double) -> String {
        value < 0
            ? String(format: "-$%.2f", abs(value))
            : String(format: "$%.2f", value)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                ModalHeader(
                    title: "Net Worth",
                    currentStep: 1,
                    totalSteps: 1,
                    onBack: nil,
                    onClose: { dismiss() }
                )
                .padding()

                ScrollView {
                    VStack(spacing: AppSpacing.element) {
                        heroSection
                        thisMonthSection
                        insightSection
                        allTimeSection
                        startingBalanceSection
                    }
                    .padding(.horizontal, AppSpacing.margin)
                    .padding(.bottom, AppSpacing.margin)
                }

                saveButton
            }
        }
        .onAppear {
            if initialBalance != 0 {
                amount = String(format: "%.2f", initialBalance)
            }
        }
    }

    // MARK: - Sections

    private var heroSection: some View {
        VStack(spacing: AppSpacing.compact) {
            Text(fmt(totalBalance))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(totalBalance >= 0 ? .primary : .functionalError)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            HStack(spacing: AppSpacing.micro) {
                Image(systemName: monthNet >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption.weight(.semibold))
                Text("\(fmt(abs(monthNet))) this month")
                    .font(.subheadline)
            }
            .foregroundColor(monthNet >= 0 ? .functionalSuccess : .functionalError)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.element)
    }

    private var thisMonthSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.compact) {
            sectionLabel("THIS MONTH")

            HStack(spacing: 0) {
                statCell(title: "Income",  value: currentMonthIncome, icon: "arrow.down.circle.fill", color: .functionalSuccess)
                divider
                statCell(title: "Spent",   value: currentMonthExpense, icon: "arrow.up.circle.fill",   color: .functionalError)
                divider
                statCell(title: "Net",     value: monthNet,            icon: monthNet >= 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill", color: monthNet >= 0 ? .functionalSuccess : .functionalError)
            }
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
        }
    }

    @ViewBuilder
    private var insightSection: some View {
        if let rate = savingsRate {
            let isHealthy = rate >= 20
            HStack(spacing: AppSpacing.compact) {
                Image(systemName: isHealthy ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(isHealthy ? .functionalSuccess : .orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isHealthy ? "Healthy savings rate" : "Low savings rate")
                        .font(.subheadline).fontWeight(.semibold)
                    Text(rate >= 0
                         ? "You saved \(Int(rate))% of income this month."
                         : "You spent \(Int(abs(rate)))% more than you earned.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(Int(rate))%")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundColor(isHealthy ? .functionalSuccess : .orange)
            }
            .padding(AppSpacing.element)
            .background((isHealthy ? Color.functionalSuccess : Color.orange).opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
        }

        if let utilization = budgetUtilization {
            VStack(alignment: .leading, spacing: AppSpacing.compact) {
                HStack {
                    Text("Budget used")
                        .font(.subheadline).fontWeight(.semibold)
                    Spacer()
                    Text("\(Int(utilization * 100))% of \(fmt(totalBudget))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: AppRadius.small)
                            .fill(Color.primary.opacity(0.08))
                        RoundedRectangle(cornerRadius: AppRadius.small)
                            .fill(utilizationColor(utilization))
                            .frame(width: geo.size.width * utilization)
                    }
                }
                .frame(height: 8)
            }
            .padding(AppSpacing.element)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
        }
    }

    private var allTimeSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.compact) {
            sectionLabel("ALL TIME")

            VStack(spacing: 0) {
                allTimeRow(title: "Total Income", value: aggregatedIncome, color: .functionalSuccess, icon: "plus.circle.fill")
                Divider().padding(.leading, 52)
                allTimeRow(title: "Total Spent",  value: aggregatedExpense, color: .functionalError,   icon: "minus.circle.fill")
                Divider().padding(.leading, 52)
                allTimeRow(title: "Net",          value: allTimeNet,        color: allTimeNet >= 0 ? .functionalSuccess : .functionalError, icon: allTimeNet >= 0 ? "equal.circle.fill" : "exclamationmark.circle.fill")
            }
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
        }
    }

    private var startingBalanceSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.compact) {
            sectionLabel("STARTING BALANCE")

            VStack(alignment: .leading, spacing: AppSpacing.compact) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("$")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    TextField("0.00", text: $amount)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .focused($isFocused)
                }
                .padding(.horizontal, AppSpacing.element)
                .padding(.top, AppSpacing.element)

                Text("This base amount is added to your transaction history to calculate your net worth.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, AppSpacing.element)
                    .padding(.bottom, AppSpacing.element)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
            .onTapGesture {
                HapticManager.shared.light()
                isFocused = true
            }
        }
    }

    private var saveButton: some View {
        Button(action: saveBalance) {
            Text("Save Changes")
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(amount.isEmpty)
        .padding(.horizontal, AppSpacing.margin)
        .padding(.bottom, AppSpacing.compact)
    }

    // MARK: - Component Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption).fontWeight(.bold)
            .foregroundColor(.secondary)
            .padding(.leading, AppSpacing.micro)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(width: 1)
            .padding(.vertical, AppSpacing.element)
    }

    private func statCell(title: String, value: Double, icon: String, color: Color) -> some View {
        VStack(spacing: AppSpacing.micro) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(fmt(value))
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundColor(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.element)
    }

    private func allTimeRow(title: String, value: Double, color: Color, icon: String) -> some View {
        HStack(spacing: AppSpacing.element) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            Spacer()
            Text(fmt(value))
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundColor(color)
        }
        .padding(.vertical, AppSpacing.compact + 2)
        .padding(.horizontal, AppSpacing.element)
    }

    private func utilizationColor(_ ratio: Double) -> Color {
        switch ratio {
        case ..<0.6:  return .functionalSuccess
        case ..<0.85: return .orange
        default:      return .functionalError
        }
    }

    private func saveBalance() {
        if let value = CurrencyInput.parse(amount) {
            initialBalance = value
            HapticManager.shared.success()
            dismiss()
        }
    }
}
