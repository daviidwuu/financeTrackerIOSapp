// MARK: - FC_TransactionRow.swift
// Frontend layer — TransactionRow component catalog for Figma.
// Source: Views/Components/TransactionRow.swift
//
// The real TransactionRow uses @EnvironmentObject for budgetRepo + appState
// to resolve category icon/color at runtime. These previews show the exact
// same visual output with static data so they work without Firebase.

import SwiftUI

// MARK: - Figma-ready visual replica
// Pixel-identical to TransactionRow but accepts resolved data as parameters.
// Use this struct anywhere you need a preview-safe transaction row.

struct FC_TransactionRowView: View {
    let categoryIcon: String
    let categoryColor: Color
    let categoryName: String
    let note: String?
    let date: Date
    let amount: Double
    let hasSplit: Bool
    let originalAmount: Double?
    let currencyCode: String?

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.element) {
            // Category icon circle
            Circle()
                .fill(categoryColor.opacity(0.1))
                .frame(width: AppSize.avatarList, height: AppSize.avatarList)
                .overlay(
                    Image(systemName: categoryIcon)
                        .font(.system(size: 20))
                        .foregroundColor(categoryColor)
                )

            // Labels
            VStack(alignment: .leading, spacing: AppSpacing.micro) {
                Text(categoryName)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(amount > 0 ? Color.functionalSuccess : .primary)

                if let note = note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Text(formattedDate)
                    .font(.caption2)
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }

            Spacer()

            // Split indicator
            if hasSplit {
                Image(systemName: "person.2.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Amount
            VStack(alignment: .trailing, spacing: AppSpacing.micro) {
                Text(formattedAmount)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(amount > 0 ? Color.functionalSuccess : .primary)

                if let orig = originalAmount, let code = currencyCode {
                    Text(foreignFormatted(orig, code: code))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(AppSpacing.element)
        .contentShape(Rectangle())
    }

    // MARK: - Helpers

    private var formattedDate: String {
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        let time = fmt.string(from: date)
        if cal.isDateInToday(date)     { return "Today at \(time)" }
        if cal.isDateInYesterday(date) { return "Yesterday at \(time)" }
        fmt.setLocalizedDateFormatFromTemplate("MMMd")
        return "\(fmt.string(from: date)) at \(time)"
    }

    private var formattedAmount: String {
        let prefix = amount >= 0 ? "+" : "-"
        return "\(prefix)$\(String(format: "%.2f", abs(amount)))"
    }

    private func foreignFormatted(_ amount: Double, code: String) -> String {
        "\(code) \(String(format: "%.2f", amount))"
    }
}

// MARK: - Preview Catalog

#Preview("TransactionRow — All States") {
    ScrollView {
        VStack(spacing: 0) {
            Text("Transaction Rows").font(AppTypography.sectionHeader)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.margin)

            // All mock transactions
            ForEach(FC_MockData.transactions) { tx in
                let cat = FC_MockData.category(id: tx.categoryId)
                FC_TransactionRowView(
                    categoryIcon:   cat.icon,
                    categoryColor:  cat.color,
                    categoryName:   cat.name,
                    note:           tx.note,
                    date:           tx.date,
                    amount:         tx.amount,
                    hasSplit:       tx.hasSplit,
                    originalAmount: nil,
                    currencyCode:   nil
                )
                .background(Color.cardBackground)
                .cornerRadius(AppRadius.medium)
                .padding(.horizontal, AppSpacing.margin)
                .padding(.bottom, AppSpacing.compact)
            }

            Divider().padding(.vertical, AppSpacing.section)

            Text("Special States").font(AppTypography.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSpacing.margin)
                .padding(.bottom, AppSpacing.compact)

            // Income (green amount)
            FC_TransactionRowView(
                categoryIcon:  "dollarsign.circle.fill",
                categoryColor: Color.functionalSuccess,
                categoryName:  "Income",
                note:          "Monthly salary",
                date:          Date(),
                amount:        4200.00,
                hasSplit:      false,
                originalAmount: nil,
                currencyCode:  nil
            )
            .background(Color.cardBackground)
            .cornerRadius(AppRadius.medium)
            .padding(.horizontal, AppSpacing.margin)
            .padding(.bottom, AppSpacing.compact)

            // With split indicator
            FC_TransactionRowView(
                categoryIcon:  "fork.knife",
                categoryColor: Color(hex: "#FF9500"),
                categoryName:  "Food & Drink",
                note:          "Dinner with friends",
                date:          Date(),
                amount:        -22.50,
                hasSplit:      true,
                originalAmount: nil,
                currencyCode:  nil
            )
            .background(Color.cardBackground)
            .cornerRadius(AppRadius.medium)
            .padding(.horizontal, AppSpacing.margin)
            .padding(.bottom, AppSpacing.compact)

            // With foreign currency
            FC_TransactionRowView(
                categoryIcon:  "airplane",
                categoryColor: Color(hex: "#007AFF"),
                categoryName:  "Transport",
                note:          "Eurostar ticket",
                date:          Date(),
                amount:        -89.00,
                hasSplit:      false,
                originalAmount: 82.50,
                currencyCode:  "EUR"
            )
            .background(Color.cardBackground)
            .cornerRadius(AppRadius.medium)
            .padding(.horizontal, AppSpacing.margin)
            .padding(.bottom, AppSpacing.compact)

            // No note
            FC_TransactionRowView(
                categoryIcon:  "bag.fill",
                categoryColor: Color(hex: "#AF52DE"),
                categoryName:  "Shopping",
                note:          nil,
                date:          Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
                amount:        -120.00,
                hasSplit:      false,
                originalAmount: nil,
                currencyCode:  nil
            )
            .background(Color.cardBackground)
            .cornerRadius(AppRadius.medium)
            .padding(.horizontal, AppSpacing.margin)
            .padding(.bottom, AppSpacing.compact)
        }
        .padding(.top, AppSpacing.section)
    }
    .background(Color.backgroundPrimary.ignoresSafeArea())
}

#Preview("TransactionRow — In List Context") {
    // How transaction rows appear inside a List (HomeView / AllTransactionsView)
    List {
        Section {
            ForEach(FC_MockData.transactions.prefix(5)) { tx in
                let cat = FC_MockData.category(id: tx.categoryId)
                FC_TransactionRowView(
                    categoryIcon:  cat.icon,
                    categoryColor: cat.color,
                    categoryName:  cat.name,
                    note:          tx.note,
                    date:          tx.date,
                    amount:        tx.amount,
                    hasSplit:      tx.hasSplit,
                    originalAmount: nil,
                    currencyCode:  nil
                )
                .appListRow()
            }
        } header: {
            Text("Today").font(AppTypography.caption).foregroundColor(.secondary)
        }
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .background(Color.backgroundPrimary.ignoresSafeArea())
}
