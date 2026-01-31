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
                // Header
                HStack(alignment: .center) {
                    Circle()
                        .fill(calculateColor(remaining: entry.dailyRemaining, limit: entry.dailyBudgetLimit))
                        .frame(width: 8, height: 8)
                    Text("Daily Focus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.bottom, 8)
                
                // Main Value
                Text(formatShort(entry.dailyRemaining))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                
                Text(entry.dailyRemaining >= 0 ? "remaining" : "over budget")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Progress Bar
                VStack(alignment: .leading, spacing: 5) {
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
                    
                    HStack {
                        Text("\(Int((entry.dailySpend / (entry.dailyBudgetLimit > 0 ? entry.dailyBudgetLimit : 1)) * 100))%")
                             .font(.caption2)
                             .fontWeight(.medium)
                             .foregroundStyle(.secondary)
                         
                         Spacer()
                         
                         Text(formatShort(entry.dailyBudgetLimit))
                             .font(.caption2)
                             .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
            .containerBackground(for: .widget) {
                ContainerRelativeShape()
                    // Subtle background gradient for depth
                    .fill(LinearGradient(
                        colors: [
                            Color(UIColor.systemBackground),
                            Color(UIColor.secondarySystemBackground).opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            }
            
        // MARK: Home Screen - Medium (Financial Overview)
        case .systemMedium:
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    // LEFT: Daily Focus (Circular Ring)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Daily Focus")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 12)
                        
                        HStack(spacing: 12) {
                            // Ring
                            WidgetCircularProgressView(
                                value: max(entry.dailyRemaining, 0),
                                total: entry.dailyBudgetLimit > 0 ? entry.dailyBudgetLimit : 100,
                                color: calculateColor(remaining: entry.dailyRemaining, limit: entry.dailyBudgetLimit)
                            )
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "dollarsign")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(calculateColor(remaining: entry.dailyRemaining, limit: entry.dailyBudgetLimit))
                            )
                            
                            // Text
                            VStack(alignment: .leading, spacing: 0) {
                                Text(formatShort(entry.dailyRemaining))
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                                    .contentTransition(.numericText())
                                Text("Remaining")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxHeight: .infinity)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider()
                        .padding(.vertical, 12)
                    
                    // RIGHT: Monthly Overview (Linear Bar)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Monthly Overview")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 12)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            // Budget / Spent Rows
                            HStack {
                                Text("Budget")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(formatShort(entry.monthlyBudget))
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Text("Spent")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(formatShort(abs(entry.monthlySpend)))
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.red)
                            }
                            
                            // Separator
                            Rectangle()
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 1)
                                .padding(.vertical, 2)
                            
                            // Remaining & Bar
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text("Left")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text(formatShort(entry.monthlyBudget + entry.monthlySpend))
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundStyle((entry.monthlyBudget + entry.monthlySpend) < 0 ? .red : .primary)
                                }
                                
                                // Linear Bar
                                GeometryReader { geo in
                                    Capsule()
                                        .fill(Color.secondary.opacity(0.1))
                                        .overlay(
                                            Capsule()
                                                .fill(Color.orange) // Monthly Accent
                                                .frame(width: min(max(abs(entry.monthlySpend) / (entry.monthlyBudget > 0 ? entry.monthlyBudget : 1), 0), 1) * geo.size.width),
                                            alignment: .leading
                                        )
                                }
                                .frame(height: 6)
                            }
                        }
                        .frame(maxHeight: .infinity, alignment: .center)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .containerBackground(for: .widget) {
                ContainerRelativeShape()
                    // Revert to cleaner subtle background
                    .fill(LinearGradient(
                        colors: [
                            Color(UIColor.systemBackground),
                            Color(UIColor.secondarySystemBackground).opacity(0.4)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
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
