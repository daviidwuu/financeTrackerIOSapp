import WidgetKit
import SwiftUI

// MARK: - Data Provider
struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), dailyExpense: 45.0, dailyVault: 0.0, monthlySpend: 1250.0, monthlyBudget: 2000.0, configuration: ConfigurationAppIntent())
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            dailyExpense: WidgetDataManager.shared.getDailySpend(),
            dailyVault: WidgetDataManager.shared.getDailyVault(),
            monthlySpend: WidgetDataManager.shared.getMonthlySpend(),
            monthlyBudget: WidgetDataManager.shared.getMonthlyBudget(),
            configuration: configuration
        )
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let currentDate = Date()
        let calendar = Calendar.current
        
        // Data
        let expense = WidgetDataManager.shared.getDailySpend()
        let vault = WidgetDataManager.shared.getDailyVault()
        let mSpend = WidgetDataManager.shared.getMonthlySpend()
        let mBudget = WidgetDataManager.shared.getMonthlyBudget()
        
        // Create Entries
        var entries: [SimpleEntry] = []
        
        // 1. Current State
        entries.append(SimpleEntry(date: currentDate, dailyExpense: expense, dailyVault: vault, monthlySpend: mSpend, monthlyBudget: mBudget, configuration: configuration))
        
        // 2. Schedule 10 PM Unlock (if currently before 10 PM)
        if let tenPM = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: currentDate), currentDate < tenPM {
            entries.append(SimpleEntry(date: tenPM, dailyExpense: expense, dailyVault: vault, monthlySpend: mSpend, monthlyBudget: mBudget, configuration: configuration))
        }
        
        // Next refresh: Standard 30 mins or at 10 PM, whichever is sooner/appropriate
        let nextUpdateDate = calendar.date(byAdding: .minute, value: 30, to: currentDate)!
        
        return Timeline(entries: entries, policy: .after(nextUpdateDate))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let dailyExpense: Double // Raw expense
    let dailyVault: Double   // Raw vault (income)
    let monthlySpend: Double
    let monthlyBudget: Double
    let configuration: ConfigurationAppIntent
    
    // Logic: Vault Unlocks at 10:00 PM (22:00)
    var isVaultUnlocked: Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        return hour >= 22
    }
    
    // Effective Daily Spend
    var dailySpend: Double {
        if isVaultUnlocked {
            return dailyExpense - dailyVault // Apply Vault (Net Spend)
        } else {
            return dailyExpense // Ignore Vault (Raw Expense)
        }
    }
    
    var dailyBudgetLimit: Double {
        let daysInMonth = Double(Calendar.current.range(of: .day, in: .month, for: date)?.count ?? 30)
        return monthlyBudget / daysInMonth
    }
    
    var dailyRemaining: Double {
        return dailyBudgetLimit - dailySpend
    }
}

// MARK: - Views
struct LockScreenWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme
    
    var mode: WidgetDisplayModeEnum {
        entry.configuration.displayMode
    }

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
                    if entry.dailySpend < 0 {
                        Text("Credit")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.green)
                    } else {
                        Text(formatShort(entry.dailyRemaining))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(entry.dailyRemaining < 0 ? .red : .primary)
                    }
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
                        Text(formatShort(entry.monthlyBudget - entry.monthlySpend))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle((entry.monthlyBudget - entry.monthlySpend) < 0 ? .red : .primary)
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
                // Remaining Mode
                if entry.dailySpend < 0 {
                    // Credit Mode (Full Green Circle)
                    WidgetCircularProgressView(
                        value: 1, // Full
                        total: 1,
                        color: .green
                    )
                    .padding(2)
                    .overlay(
                        VStack(spacing: 0) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                            Text(formatShort(abs(entry.dailySpend)))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.green)
                    )
                    .containerBackground(.clear, for: .widget)
                } else {
                    WidgetCircularProgressView(
                        value: max(entry.dailyRemaining, 0),
                        total: entry.dailyBudgetLimit > 0 ? entry.dailyBudgetLimit : 100,
                        color: .primary // System tint
                    )
                    .padding(2)
                    .overlay(
                        Text(formatShort(entry.dailyRemaining))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.5)
                    )
                    .containerBackground(.clear, for: .widget)
                }
            }
            
        // MARK: Lock Screen - Inline (Monthly Left)
        case .accessoryInline:
            Text("Left: \(formatMoney(entry.monthlyBudget - entry.monthlySpend))")
                .containerBackground(.clear, for: .widget)
            
        // MARK: Home Screen - Small (Daily Focus)
        case .systemSmall:
            VStack(alignment: .leading, spacing: 0) {
                // Header Row: Label + Gauge
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Daily\nLimit")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(UIColor.systemGray))
                            .lineSpacing(0)
                        
                        if !entry.isVaultUnlocked && entry.dailyVault > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 8))
                                Text(formatShort(entry.dailyVault))
                                    .font(.system(size: 8, weight: .bold))
                            }
                            .foregroundStyle(Color.green.opacity(0.8))
                            .padding(.top, 2)
                        }
                    }
                    
                    Spacer()
                    
                    // Thin Ring Gauge (Navigation Style)
                    ZStack {
                        Circle()
                            .stroke(Color(UIColor.tertiarySystemFill), lineWidth: 3)
                            .frame(width: 32, height: 32)
                        
                        if entry.dailySpend < 0 {
                            // Credit: Full Green Ring
                            Circle()
                                .stroke(
                                    Color.green,
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                )
                                .frame(width: 32, height: 32)
                        } else {
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
                }
                
                Spacer()
                
                // Massive Value
                Text(formatShort(entry.dailyRemaining))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
                
                // Footer
                if entry.dailySpend < 0 {
                     Text("CREDIT")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.green)
                        .padding(.top, 2)
                } else {
                    Text(entry.dailyRemaining >= 0 ? "REMAINING" : "OVER")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(entry.dailyRemaining >= 0 ? Color(UIColor.systemGray) : .red)
                        .padding(.top, 2)
                }
            }
            .padding(16)
            .containerBackground(for: .widget) {
                Color(UIColor.systemBackground)
            }
            
        // MARK: Home Screen - Medium (Financial Dashboard - Hero Monthly)
        case .systemMedium:
            HStack(spacing: 12) {
                // LEFT: Daily Card (Compact - Fixed Width)
                // Dynamic Color Logic
                let dailyBackground = {
                    if mode == .spent {
                       return abs(entry.dailySpend) > entry.dailyBudgetLimit
                            ? Color.red.opacity(0.15)
                            : Color(UIColor.secondarySystemFill)
                    } else {
                       if entry.dailySpend < 0 {
                           return Color.green.opacity(0.15)
                       }
                       return entry.dailyRemaining < 0 
                            ? Color.red.opacity(0.15) 
                            : Color(UIColor.secondarySystemFill)
                    }
                }()
                
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        if mode == .spent {
                            Image(systemName: abs(entry.dailySpend) > entry.dailyBudgetLimit ? "exclamationmark.triangle.fill" : "flame.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(abs(entry.dailySpend) > entry.dailyBudgetLimit ? .red : .orange)
                        } else {
                            Image(systemName: entry.dailySpend < 0 ? "arrow.up.circle.fill" : (entry.dailyRemaining < 0 ? "exclamationmark.triangle.fill" : "sun.max.fill"))
                                .font(.system(size: 10))
                                .foregroundStyle(entry.dailySpend < 0 ? .green : (entry.dailyRemaining < 0 ? .red : Color.primary))
                        }
                        
                        VStack(alignment: .leading, spacing: 0) {
                            Text("TODAY")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(Color(UIColor.systemGray))
                            
                            if !entry.isVaultUnlocked && entry.dailyVault > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 6))
                                    Text(formatShort(entry.dailyVault))
                                        .font(.system(size: 6, weight: .bold))
                                }
                                .foregroundStyle(.green)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Compact Donut
                    ZStack {
                        Circle()
                            .stroke(Color(UIColor.quaternarySystemFill), lineWidth: 6)
                        
                        // Ring Value
                        let ringValue = mode == .spent ? abs(entry.dailySpend) : (entry.dailySpend < 0 ? 1 : entry.dailyRemaining)
                        let ringColor = mode == .spent 
                            ? calculateSpentColor(spent: abs(entry.dailySpend), limit: entry.dailyBudgetLimit)
                            : (entry.dailySpend < 0 ? .green : calculateColor(remaining: entry.dailyRemaining, limit: entry.dailyBudgetLimit))
                        
                        Circle()
                            .trim(from: 0, to: min(max((mode == .spent ? ringValue : (entry.dailySpend < 0 ? 1 : ringValue)) / (entry.dailyBudgetLimit > 0 ? entry.dailyBudgetLimit : 1), 0), 1))
                            .stroke(
                                ringColor,
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                        
                        VStack(spacing: 0) {
                            Text(formatShort(ringValue))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.primary)
                                .minimumScaleFactor(0.8)
                                .contentTransition(.numericText())
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
                                .foregroundStyle(entry.dailyRemaining < 0 ? .red : Color.primary)
                                .contentTransition(.numericText())
                        } else {
                            Text("Spent:")
                                .font(.system(size: 9))
                                .foregroundStyle(Color(UIColor.systemGray))
                            Text(formatShort(abs(entry.dailySpend)))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.primary)
                                .contentTransition(.numericText())
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
                                .foregroundStyle(Color.primary)
                                .contentTransition(.numericText())
                            
                            Text("spent")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color(UIColor.systemGray))
                                .padding(.leading, 2)
                        } else {
                            Text(formatShort(entry.monthlyBudget - entry.monthlySpend))
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.primary)
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
                                    .fill(Color(UIColor.tertiarySystemFill))
                                
                                Capsule()
                                    .fill(Color.primary)
                                    .frame(width: min(max(abs(entry.monthlySpend) / (entry.monthlyBudget > 0 ? entry.monthlyBudget : 1), 0), 1) * geo.size.width)
                            }
                        }
                        .frame(height: 12) // Thicker for Hero feel
                        
                        // Spent/Left Value (No Negative Sign)
                        Text(formatShort(mode == .spent ? (entry.monthlyBudget - entry.monthlySpend) : abs(entry.monthlySpend)))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.primary)
                            .contentTransition(.numericText())
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .containerBackground(for: .widget) {
                Color(UIColor.systemBackground)
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
struct BudgetWidget: Widget {
    let kind: String = "FinanceWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            LockScreenWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Budget Overview")
        .description("Monitor your daily spending limit and monthly budget health at a glance.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline, .systemSmall, .systemMedium])
        .contentMarginsDisabled() // Modern look for system widgets
    }
}
