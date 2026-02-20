import WidgetKit
import SwiftUI

struct RecentTransactionsProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> RecentEntry {
        RecentEntry(date: Date(), configuration: WidgetBackgroundIntent(), transactions: [
            WidgetDataManager.WidgetTransaction(id: "1", title: "Coffee", amount: -4.50, date: Date(), icon: "cup.and.saucer.fill", colorHex: "#FF9500"),
            WidgetDataManager.WidgetTransaction(id: "2", title: "Groceries", amount: -120.30, date: Date().addingTimeInterval(-3600), icon: "cart.fill", colorHex: "#4CD964")
        ])
    }

    func snapshot(for configuration: WidgetBackgroundIntent, in context: Context) async -> RecentEntry {
        let transactions = WidgetDataManager.shared.getRecentTransactions()
        return RecentEntry(date: Date(), configuration: configuration, transactions: transactions)
    }

    func timeline(for configuration: WidgetBackgroundIntent, in context: Context) async -> Timeline<RecentEntry> {
        let transactions = WidgetDataManager.shared.getRecentTransactions()
        let entry = RecentEntry(date: Date(), configuration: configuration, transactions: transactions)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}

struct RecentEntry: TimelineEntry {
    let date: Date
    let configuration: WidgetBackgroundIntent
    let transactions: [WidgetDataManager.WidgetTransaction]
}

struct RecentTransactionsEntryView : View {
    var entry: RecentTransactionsProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Image(systemName: "list.bullet")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            
            if entry.transactions.isEmpty {
                Spacer()
                Text("No recent transactions")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                VStack(spacing: 8) {
                    let displayLimit = family == .systemSmall ? 3 : 4
                    ForEach(entry.transactions.prefix(displayLimit)) { transaction in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(hex: transaction.colorHex))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: transaction.icon)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(transaction.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                
                                Text(transaction.date, style: .time)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(formatMoney(transaction.amount))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(transaction.amount > 0 ? Color.green : Color.primary)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(16)
        .applyWidgetBackground(style: entry.configuration.backgroundStyle) // Custom modifier
    }
    
    func formatMoney(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        // Hide minus sign for expenses since UI implies it's a spend
        let absoluteAmount = abs(amount)
        return formatter.string(from: NSNumber(value: absoluteAmount)) ?? "$0.00"
    }
}

struct RecentTransactionsWidget: Widget {
    let kind: String = "RecentTransactionsWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: WidgetBackgroundIntent.self, provider: RecentTransactionsProvider()) { entry in
            RecentTransactionsEntryView(entry: entry)
        }
        .configurationDisplayName("Recent Transactions")
        .description("View your latest spending activity.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
