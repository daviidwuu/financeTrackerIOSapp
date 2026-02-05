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
    
    var mode: WidgetDisplayMode = .remaining

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
            if mode == .spent {
                WidgetCircularProgressView(
                    value: abs(entry.dailySpend),
                    total: entry.dailyBudgetLimit > 0 ? entry.dailyBudgetLimit : 100,
                    color: calculateSpentColor(spent: abs(entry.dailySpend), limit: entry.dailyBudgetLimit)
                )
                .padding(2)
                .overlay(
                    Text(formatShort(abs(entry.dailySpend)))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.5)
                )
                .containerBackground(.clear, for: .widget)
            } else {
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
            }
            
        // MARK: Lock Screen - Inline (Monthly Left)
        case .accessoryInline:
            Text("Left: \(formatMoney(entry.monthlyBudget + entry.monthlySpend))")
                .containerBackground(.clear, for: .widget)
            
        // MARK: Home Screen - Small (Daily Focus)
        // MARK: Home Screen - Small (Daily Focus)
        // MARK: Home Screen - Small (Daily Focus)
        // MARK: Home Screen - Small (Daily Focus - True Black Redesign)
        case .systemSmall:
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 0) {
                    // Header Row: Label + Gauge
                    HStack(alignment: .top) {
                        Text("Daily\nLimit")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(UIColor.systemGray))
                            .lineSpacing(0)
                        
                        Spacer()
                        
                        // Thin Ring Gauge (Navigation Style)
                        ZStack {
                            Circle()
                                .stroke(Color(UIColor.darkGray).opacity(0.4), lineWidth: 3)
                                .frame(width: 32, height: 32)
                            
                            Circle()
                                .trim(from: 0, to: min(max(entry.dailyRemaining / (entry.dailyBudgetLimit > 0 ? entry.dailyBudgetLimit : 1), 0), 1))
                                .stroke(
                                    calculateColor(remaining: entry.dailyRemaining, limit: entry.dailyBudgetLimit),
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .frame(width: 32, height: 32)
                        }
                    }
                    
                    Spacer()
                    
                    // Massive Value
                    Text(formatShort(entry.dailyRemaining))
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                        .contentTransition(.numericText())
                    
                    // Footer
                    Text(entry.dailyRemaining >= 0 ? "REMAINING" : "OVER")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(entry.dailyRemaining >= 0 ? Color(UIColor.systemGray2) : .red)
                        .padding(.top, 2)
                }
                .padding(16)
            }
            .containerBackground(for: .widget) {
                Color.black
            }
            
        // MARK: Home Screen - Medium (Financial Dashboard - Hero Monthly)
        case .systemMedium:
            ZStack {
                Color.black.ignoresSafeArea()
                
                HStack(spacing: 12) {
                    // LEFT: Daily Card (Compact - Fixed Width)
                    // Dynamic Color Logic
                    let dailyBackground = {
                        if mode == .spent {
                           return abs(entry.dailySpend) > entry.dailyBudgetLimit
                                ? Color(UIColor.systemRed).opacity(0.15)
                                : Color(UIColor.systemGray6).opacity(0.12)
                        } else {
                           return entry.dailyRemaining < 0 
                                ? Color(UIColor.systemRed).opacity(0.15) 
                                : Color(UIColor.systemGray6).opacity(0.12)
                        }
                    }()
                    
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            if mode == .spent {
                                Image(systemName: abs(entry.dailySpend) > entry.dailyBudgetLimit ? "exclamationmark.triangle.fill" : "flame.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(abs(entry.dailySpend) > entry.dailyBudgetLimit ? .red : .orange)
                            } else {
                                Image(systemName: entry.dailyRemaining < 0 ? "exclamationmark.triangle.fill" : "sun.max.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white)
                            }
                            Text("TODAY")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(Color(UIColor.systemGray))
                        }
                        
                        Spacer()
                        
                        // Compact Donut
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.1), lineWidth: 6)
                            
                            // Ring Value
                            let ringValue = mode == .spent ? abs(entry.dailySpend) : entry.dailyRemaining
                            let ringColor = mode == .spent 
                                ? calculateSpentColor(spent: abs(entry.dailySpend), limit: entry.dailyBudgetLimit)
                                : calculateColor(remaining: entry.dailyRemaining, limit: entry.dailyBudgetLimit)
                            
                            Circle()
                                .trim(from: 0, to: min(max(ringValue / (entry.dailyBudgetLimit > 0 ? entry.dailyBudgetLimit : 1), 0), 1))
                                .stroke(
                                    ringColor,
                                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                            
                            VStack(spacing: 0) {
                                Text(formatShort(ringValue))
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                        .frame(width: 55, height: 55)
                        .frame(maxWidth: .infinity)
                        
                        Spacer()
                        
                        // Footer Stat
                        HStack(spacing: 4) {
                            if mode == .spent {
                                Text("Save:")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color(UIColor.systemGray))
                                Text(formatShort(entry.dailyRemaining))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(entry.dailyRemaining < 0 ? .red : .white)
                            } else {
                                Text("Spent:")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color(UIColor.systemGray))
                                Text(formatShort(abs(entry.dailySpend)))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(16) // HIG Standard Padding (was 12)
                    .frame(width: 115) // Slightly widened to accommodate padding (was 110)
                    .background(dailyBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                (mode == .spent ? (abs(entry.dailySpend) > entry.dailyBudgetLimit) : (entry.dailyRemaining < 0)) 
                                ? Color.red.opacity(0.3) : Color.clear, 
                                lineWidth: 1
                            )
                    )
                    
                    // RIGHT: Monthly Overview (HERO - Takes available space)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("MONTHLY")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(Color(UIColor.systemGray))
                            .padding(.bottom, 12)
                        
                        // Main Stats Row
                        HStack(alignment: .lastTextBaseline) {
                            if mode == .spent {
                                Text(formatShort(abs(entry.monthlySpend)))
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .contentTransition(.numericText())
                                
                                Text("spent")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color(UIColor.systemGray))
                                    .padding(.leading, 2)
                            } else {
                                Text(formatShort(entry.monthlyBudget + entry.monthlySpend))
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .contentTransition(.numericText())
                                
                                Text("left")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color(UIColor.systemGray))
                                    .padding(.leading, 2)
                            }
                        }
                        
                        Spacer()
                        
                        // Progress Section
                        VStack(alignment: .leading, spacing: 6) {
                            // Labels
                            HStack {
                                Text(mode == .spent ? "Left" : "Spent")
                                    .font(.caption2)
                                    .foregroundStyle(Color(UIColor.systemGray))
                                Spacer()
                                Text(formatShort(entry.monthlyBudget))
                                    .font(.caption2)
                                    .foregroundStyle(Color(UIColor.systemGray))
                                Text("Limit")
                                    .font(.caption2)
                                    .foregroundStyle(Color(UIColor.systemGray2))
                            }
                            
                            // Wide Progress Bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.1))
                                    
                                    Capsule()
                                        .fill(.white)
                                        .frame(width: min(max(abs(entry.monthlySpend) / (entry.monthlyBudget > 0 ? entry.monthlyBudget : 1), 0), 1) * geo.size.width)
                                }
                            }
                            .frame(height: 12) // Thicker for Hero feel
                            
                            // Spent/Left Value (No Negative Sign)
                            // In Spent mode, footer shows "Left: $X"
                            // In Remaining mode, footer shows "Spent: $X"
                            Text(formatShort(mode == .spent ? (entry.monthlyBudget + entry.monthlySpend) : abs(entry.monthlySpend)))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .containerBackground(for: .widget) {
                Color.black
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
    
    // New Helper for Spent Mode Color
    func calculateSpentColor(spent: Double, limit: Double) -> Color {
        guard limit > 0 else { return .red }
        let percentage = spent / limit
        
        if percentage < 0.5 {
            return .green
        } else if percentage < 0.8 {
            return .orange
        } else {
            return .red
        }
    }
}

enum WidgetDisplayMode {
    case remaining
    case spent
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
            LockScreenWidgetEntryView(entry: entry, mode: .remaining)
        }
        .configurationDisplayName("wym")
        .description("Track daily habits and monthly budget.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline, .systemSmall, .systemMedium])
        .contentMarginsDisabled() // Modern look for system widgets
    }
}

struct SpentWidget: Widget {
    let kind: String = "SpentWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LockScreenWidgetEntryView(entry: entry, mode: .spent)
        }
        .configurationDisplayName("wym Spent")
        .description("Track how much you have spent.")
        .supportedFamilies([.accessoryCircular, .systemMedium])
        .contentMarginsDisabled()
    }
}
