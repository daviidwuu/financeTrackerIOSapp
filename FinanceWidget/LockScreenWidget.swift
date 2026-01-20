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
            WidgetCircularProgressView(
                value: max(entry.dailyRemaining, 0),
                total: entry.dailyBudgetLimit > 0 ? entry.dailyBudgetLimit : 100,
                color: .primary // System tint on Lock Screen
            )
            .padding(2)
            .overlay(
                Text(formatShort(entry.dailyRemaining))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
            )
            .containerBackground(.clear, for: .widget)
            
        // MARK: Lock Screen - Inline (Monthly Left)
        case .accessoryInline:
            Text("Left: \(formatMoney(entry.monthlyBudget + entry.monthlySpend))")
                .containerBackground(.clear, for: .widget)
            
        // MARK: Home Screen - Small (Daily Focus)
        // MARK: Home Screen - Small (Daily Focus)
        // MARK: Home Screen - Small (Daily Focus)
        case .systemSmall:
            VStack(alignment: .leading, spacing: 0) {
                Text("Daily Left")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                
                Spacer()
                
                Text(formatMoney(entry.dailyRemaining))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(calculateColor(remaining: entry.dailyRemaining, limit: entry.dailyBudgetLimit))
                    .contentTransition(.numericText())
                    .lineLimit(1)
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 6) {
                    // Progress Bar
                    GeometryReader { geo in
                        Capsule()
                            .fill(Color.secondary.opacity(0.15))
                            .overlay(
                                Capsule()
                                    .fill(calculateColor(remaining: entry.dailyRemaining, limit: entry.dailyBudgetLimit))
                                    .frame(width: min(max(entry.dailyRemaining / (entry.dailyBudgetLimit > 0 ? entry.dailyBudgetLimit : 1), 0), 1) * geo.size.width),
                                alignment: .leading
                            )
                    }
                    .frame(height: 8)
                    
                    HStack {
                        Text("Spent \(formatShort(entry.dailySpend))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text("of \(formatShort(entry.dailyBudgetLimit))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 4)
            }
            .padding()
            .containerBackground(for: .widget) {
                ContainerRelativeShape()
                    .fill(Color(UIColor.systemBackground))
            }
            
        // MARK: Home Screen - Medium (Financial Overview)
        case .systemMedium:
            HStack(spacing: 0) {
                // Left Panel: Daily Focus
                VStack(alignment: .leading) {
                    Text("Daily Left")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
                    Spacer()
                    
                    WidgetCircularProgressView(
                        value: max(entry.dailyRemaining, 0),
                        total: entry.dailyBudgetLimit > 0 ? entry.dailyBudgetLimit : 100,
                        color: calculateColor(remaining: entry.dailyRemaining, limit: entry.dailyBudgetLimit)
                    )
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text("\(Int(max(entry.dailyRemaining, 0) / (entry.dailyBudgetLimit > 0 ? entry.dailyBudgetLimit : 1) * 100))%")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                    )
                    
                    Spacer()
                    
                    Text(formatMoney(entry.dailyRemaining))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(calculateColor(remaining: entry.dailyRemaining, limit: entry.dailyBudgetLimit))
                        .minimumScaleFactor(0.8)
                }
                .frame(width: 90)
                
                Divider()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                
                // Right Panel: Monthly Breakdown
                VStack(alignment: .leading, spacing: 0) {
                    Text("Monthly Overview")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.bottom, 12)
                    
                    // Budget Row
                    HStack {
                        Text("Budget")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatShort(entry.monthlyBudget))
                            .font(.callout)
                            .fontWeight(.semibold)
                    }
                    .padding(.bottom, 6)
                    
                    // Spent Row
                    HStack {
                        Text("Spent")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatShort(abs(entry.monthlySpend)))
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundStyle(.red)
                    }
                    .padding(.bottom, 10)
                    
                    // Remaining Row (Prominent)
                    HStack(alignment: .firstTextBaseline) {
                        Text("Remaining")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatMoney(entry.monthlyBudget + entry.monthlySpend))
                            .font(.title3)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)
                            .foregroundStyle((entry.monthlyBudget + entry.monthlySpend) < 0 ? .red : .primary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(16)
            .containerBackground(for: .widget) {
                ContainerRelativeShape()
                    .fill(Color(UIColor.systemBackground))
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
    
    func calculateColor(remaining: Double, limit: Double) -> Color {
        if remaining < 0 {
            return .red
        }
        
        guard limit > 0 else { return .green }
        
        let percentage = remaining / limit
        
        if percentage > 0.5 {
            return .green
        } else if percentage > 0.2 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Helper Views
struct WidgetCircularProgressView: View {
    let value: Double
    let total: Double
    let color: Color
    
    var progress: Double {
        guard total > 0 else { return 0 }
        return min(max(value / total, 0), 1.0)
    }
    
    var body: some View {
        ZStack {
            // Track (Empty part)
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 12)
            
            // Fill (Active part)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .scaleEffect(x: -1, y: 1) // Mirror to fill Left side first (Counter-Clockwise)
        }
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
