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
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        Image(systemName: "banknote")
                            .font(.system(size: 10))
                        Text("Today")
                            .font(.system(size: 10, weight: .bold))
                            .textCase(.uppercase)
                    }
                    Text(formatShort(entry.dailyRemaining))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(entry.dailyRemaining < 0 ? .red : .primary)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.pie")
                            .font(.system(size: 10))
                        Text("Month")
                            .font(.system(size: 10, weight: .bold))
                            .textCase(.uppercase)
                    }
                    Text(formatShort(entry.monthlyBudget + entry.monthlySpend))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
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
                HStack {
                    Text("Focus")
                    Spacer()
                    Text("Month")
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.top, 4)
                
                Spacer()
                
                HStack(alignment: .firstTextBaseline) {
                    Text(formatShort(entry.dailyRemaining))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(calculateColor(remaining: entry.dailyRemaining, limit: entry.dailyBudgetLimit))
                    
                    Spacer()
                    
                    Text(formatShort(entry.monthlyBudget + entry.monthlySpend))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle((entry.monthlyBudget + entry.monthlySpend) < 0 ? .red : .primary)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    // Daily Progress Bar
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
                    .frame(height: 6)
                    
                    Text("Spent \(formatShort(entry.dailySpend)) today")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 4)
            }
            .padding(12)
            .containerBackground(for: .widget) {
                ContainerRelativeShape()
                    .fill(Color(UIColor.systemBackground))
            }
            
        // MARK: Home Screen - Medium (Financial Overview)
        case .systemMedium:
            ZStack {
                // Background Design
                LinearGradient(
                    stops: [
                        .init(color: Color(UIColor.systemBackground), location: 0),
                        .init(color: Color(UIColor.secondarySystemBackground).opacity(0.5), location: 1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                HStack(spacing: 0) {
                    // Left Panel: Daily Focus
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.orange)
                            Text("Daily Focus")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                        }
                        
                        HStack(spacing: 12) {
                            WidgetCircularProgressView(
                                value: max(entry.dailyRemaining, 0),
                                total: entry.dailyBudgetLimit > 0 ? entry.dailyBudgetLimit : 100,
                                color: calculateColor(remaining: entry.dailyRemaining, limit: entry.dailyBudgetLimit)
                            )
                            .frame(width: 52, height: 52)
                            .overlay(
                                Image(systemName: "dollarsign")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(calculateColor(remaining: entry.dailyRemaining, limit: entry.dailyBudgetLimit))
                            )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Remaining")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                Text(formatMoney(entry.dailyRemaining))
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundStyle(calculateColor(remaining: entry.dailyRemaining, limit: entry.dailyBudgetLimit))
                                    .minimumScaleFactor(0.8)
                                    .lineLimit(1)
                            }
                        }
                        
                        // Small Daily Detail
                        HStack(spacing: 4) {
                            Text("Spent \(formatShort(entry.dailySpend))")
                                .font(.system(size: 9, weight: .semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(Capsule())
                            
                            Text("Limit \(formatShort(entry.dailyBudgetLimit))")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 155, alignment: .leading)
                    
                    Divider()
                        .padding(.vertical, 16)
                    
                    // Right Panel: Monthly Breakdown
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                                .foregroundStyle(.blue)
                            Text("Monthly Overview")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                        }
                        
                        VStack(alignment: .leading, spacing: 10) {
                            // High-level Stats
                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("BUDGET")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.secondary)
                                    Text(formatShort(entry.monthlyBudget))
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("SPENT")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.secondary)
                                    Text(formatShort(abs(entry.monthlySpend)))
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.red)
                                }
                                
                                Spacer()
                                
                                // Days Remaining Calc (Simple estimate)
                                let daysLeft = Calendar.current.range(of: .day, in: .month, for: Date())!.count - Calendar.current.component(.day, from: Date())
                                VStack(alignment: .trailing, spacing: 0) {
                                    Text("DAYS LEFT")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.secondary)
                                    Text("\(daysLeft)")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                            }
                            
                            // Monthly Progress Bar
                            VStack(alignment: .leading, spacing: 4) {
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(Color.secondary.opacity(0.15))
                                        
                                        Capsule()
                                            .fill(Color.blue)
                                            .frame(width: min(max(abs(entry.monthlySpend) / (entry.monthlyBudget > 0 ? entry.monthlyBudget : 1), 0), 1) * geo.size.width)
                                    }
                                }
                                .frame(height: 6)
                                
                                HStack {
                                    Text("\(Int((abs(entry.monthlySpend) / (entry.monthlyBudget > 0 ? entry.monthlyBudget : 1)) * 100))% used")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(formatMoney(entry.monthlyBudget + entry.monthlySpend))
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle((entry.monthlyBudget + entry.monthlySpend) < 0 ? .red : .primary)
                                }
                            }
                        }
                    }
                    .padding(.leading, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
            }
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
