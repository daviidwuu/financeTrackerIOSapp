import WidgetKit
import SwiftUI

struct RecentTransactionsProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecentEntry {
        RecentEntry(date: Date(), transactions: [
            WidgetDataManager.WidgetTransaction(id: "1", title: "Coffee", amount: -4.50, date: Date(), icon: "cup.and.saucer.fill", colorHex: "#FF9500"),
            WidgetDataManager.WidgetTransaction(id: "2", title: "Groceries", amount: -120.30, date: Date().addingTimeInterval(-3600), icon: "cart.fill", colorHex: "#4CD964")
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (RecentEntry) -> ()) {
        let transactions = WidgetDataManager.shared.getRecentTransactions()
        let entry = RecentEntry(date: Date(), transactions: transactions)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let transactions = WidgetDataManager.shared.getRecentTransactions()
        let entry = RecentEntry(date: Date(), transactions: transactions)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct RecentEntry: TimelineEntry {
    let date: Date
    let transactions: [WidgetDataManager.WidgetTransaction]
}

struct RecentTransactionsEntryView : View {
    var entry: RecentTransactionsProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Recent")
                        .font(.system(size: 12, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundStyle(Color(UIColor.systemGray))
                    
                    Spacer()
                }
                
                if entry.transactions.isEmpty {
                    Spacer()
                    Text("No recent transactions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    VStack(spacing: 10) {
                        ForEach(entry.transactions.prefix(family == .systemSmall ? 2 : 4)) { transaction in
                            HStack(spacing: 8) {
                                // Icon
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: transaction.colorHex).opacity(0.2))
                                        .frame(width: 28, height: 28)
                                    
                                    Image(systemName: transaction.icon)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color(hex: transaction.colorHex))
                                }
                                
                                // Title
                                Text(transaction.title)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                // Amount
                                Text(formatMoney(transaction.amount))
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(transaction.amount < 0 ? .white : .green)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding(16)
        }
        .containerBackground(for: .widget) {
            Color.black
        }
    }
    
    func formatMoney(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: abs(amount))) ?? ""
    }
}

struct RecentTransactionsWidget: Widget {
    let kind: String = "RecentTransactionsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecentTransactionsProvider()) { entry in
            RecentTransactionsEntryView(entry: entry)
        }
        .configurationDisplayName("Recent Transactions")
        .description("View your latest spending activity.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
