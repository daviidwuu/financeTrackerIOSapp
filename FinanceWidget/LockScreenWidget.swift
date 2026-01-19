import WidgetKit
import SwiftUI

// MARK: - Data Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), dailySpend: 45.0, monthlySpend: 1250.0, monthlyBudget: 2000.0)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(
            date: Date(),
            dailySpend: WidgetDataManager.shared.getDailySpend(),
            monthlySpend: WidgetDataManager.shared.getMonthlySpend(),
            monthlyBudget: WidgetDataManager.shared.getMonthlyBudget()
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentDate = Date()
        let nextUpdateDate = Calendar.current.date(byAdding: .minute, value: 30, to: currentDate)!
        
        let entry = SimpleEntry(
            date: currentDate,
            dailySpend: WidgetDataManager.shared.getDailySpend(),
            monthlySpend: WidgetDataManager.shared.getMonthlySpend(),
            monthlyBudget: WidgetDataManager.shared.getMonthlyBudget()
        )

        let timeline = Timeline(entries: [entry], policy: .after(nextUpdateDate))
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let dailySpend: Double
    let monthlySpend: Double
    let monthlyBudget: Double
    
    // Derived Helper: Estimated Daily Budget based on Month length
    var dailyBudgetLimit: Double {
        let daysInMonth = Double(Calendar.current.range(of: .day, in: .month, for: date)?.count ?? 30)
        return monthlyBudget / daysInMonth
    }
    
    // New Derived Helper: Amount Left for Today
    var dailyRemaining: Double {
        return dailyBudgetLimit + dailySpend
    }
}

// MARK: - Views
struct LockScreenWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        switch family {
        // MARK: Lock Screen - Rectangular (Summary)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Image(systemName: "banknote")
                        .font(.caption2)
                    Text("Today: \(formatMoney(entry.dailyRemaining))") // Changed to Remaining
                        .font(.caption)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .foregroundStyle(entry.dailyRemaining < 0 ? .red : .primary)
                }
                HStack {
                    Image(systemName: "chart.pie")
                        .font(.caption2)
                    Text("Month: \(formatMoney(entry.monthlyBudget + entry.monthlySpend))")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .foregroundStyle((entry.monthlyBudget + entry.monthlySpend) < 0 ? .red : .primary)
                }
            }
            .containerBackground(.clear, for: .widget)

        // MARK: Lock Screen - Circular (Daily Ring - "Fuel Gauge")
        case .accessoryCircular:
            // Value: Remaining Amount
            // Range: 0...DailyLimit
            // Visual: Starts full (Remaining = Limit), goes to empty (Remaining = 0)
            Gauge(value: max(entry.dailyRemaining, 0), in: 0...(entry.dailyBudgetLimit > 0 ? entry.dailyBudgetLimit : 100)) {
                Text("Daily")
            } currentValueLabel: {
                Text(formatShort(entry.dailyRemaining))
            }
            .gaugeStyle(.accessoryCircular)
            .tint(entry.dailyRemaining < 0 ? .red : .primary) // Red if overspent (negative)
            .containerBackground(.clear, for: .widget)
            
        // MARK: Lock Screen - Inline (Monthly Left)
        case .accessoryInline:
            Text("Left: \(formatMoney(entry.monthlyBudget + entry.monthlySpend))")
                .containerBackground(.clear, for: .widget)
            
        // MARK: Home Screen - Small (Daily Focus)
        case .systemSmall:
            VStack(alignment: .leading) {
                Text("Daily Available") // Changed Title
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fontWeight(.medium)
                
                Spacer()
                
                ZStack {
                    // Daily Ring (Fuel Gauge)
                    Gauge(value: max(entry.dailyRemaining, 0), in: 0...(entry.dailyBudgetLimit > 0 ? entry.dailyBudgetLimit : 100)) {
                        Text("Left")
                    } currentValueLabel: {
                        VStack(spacing: 0) {
                            Text(formatMoney(entry.dailyRemaining))
                                .fontWeight(.bold)
                                .fontDesign(.rounded)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(entry.dailyRemaining < 0 ? .red : .primary)
                        }
                    }
                    .gaugeStyle(.accessoryCircular)
                    .scaleEffect(1.5)
                    .tint(entry.dailyRemaining < 0 ? .red : .blue)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                
                Spacer()
                
                Text("Limit: \(formatShort(entry.dailyBudgetLimit))/day")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding()
            .containerBackground(for: .widget) {
                ContainerRelativeShape()
                    .fill(Color(.systemBackground))
            }
            
        // MARK: Home Screen - Medium (Dashboard)
        case .systemMedium:
            HStack(spacing: 20) {
                // Left Column: Daily Ring
                VStack {
                    Text("Today")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(.secondary)
                    
                    Gauge(value: max(entry.dailyRemaining, 0), in: 0...(entry.dailyBudgetLimit > 0 ? entry.dailyBudgetLimit : 100)) {
                        Text("Left")
                    } currentValueLabel: {
                        Text(formatShort(entry.dailyRemaining))
                            .font(.caption)
                            .bold()
                            .foregroundStyle(entry.dailyRemaining < 0 ? .red : .primary)
                    }
                    .gaugeStyle(.accessoryCircular)
                    .tint(entry.dailyRemaining < 0 ? .red : .blue)
                    .scaleEffect(1.2)
                }
                .frame(width: 80)
                
                Divider()
                
                // Right Column: Monthly Stats (Unchanged)
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Monthly Budget")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        HStack(alignment: .firstTextBaseline) {
                            Text(formatMoney(entry.monthlyBudget + entry.monthlySpend))
                                .font(.title2)
                                .bold()
                                .fontDesign(.rounded)
                                .foregroundStyle((entry.monthlyBudget + entry.monthlySpend) < 0 ? .red : .primary)
                            
                            Text("left")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Spent")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(formatShort(abs(entry.monthlySpend))) / \(formatShort(entry.monthlyBudget))")
                                .font(.caption2)
                                .bold()
                        }
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 8)
                                
                                Capsule()
                                    .fill(abs(entry.monthlySpend) > entry.monthlyBudget ? Color.red : Color.blue)
                                    .frame(width: min(CGFloat(abs(entry.monthlySpend) / (entry.monthlyBudget > 0 ? entry.monthlyBudget : 1)) * geo.size.width, geo.size.width), height: 8)
                            }
                        }
                        .frame(height: 8)
                    }
                }
            }
            .padding()
            .containerBackground(for: .widget) {
                ContainerRelativeShape()
                    .fill(Color(.systemBackground))
            }

        default:
            Text("Full View")
        }
    }
    
    // MARK: - Helpers
    func formatMoney(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
    }
    
    func formatShort(_ amount: Double) -> String {
        if abs(amount) >= 1000 {
            return String(format: "$%.1fk", amount/1000)
        }
        return String(format: "$%.0f", amount)
    }
}

// MARK: - Configuration
struct LockScreenWidget: Widget {
    let kind: String = "FinanceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LockScreenWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Finance Status")
        .description("Track daily habits and monthly budget.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline, .systemSmall, .systemMedium])
        .contentMarginsDisabled() // Modern look for system widgets
    }
}
