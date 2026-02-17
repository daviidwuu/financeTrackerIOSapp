import WidgetKit
import SwiftUI

struct QuickLogProvider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleLogEntry {
        SimpleLogEntry(date: Date(), categories: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleLogEntry) -> ()) {
        let categories = WidgetDataManager.shared.getQuickLogCategories()
        let entry = SimpleLogEntry(date: Date(), categories: categories)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let categories = WidgetDataManager.shared.getQuickLogCategories()
        let entry = SimpleLogEntry(date: Date(), categories: categories)
        // Update whenever app is opened (handled by reloadAllTimelines)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct SimpleLogEntry: TimelineEntry {
    let date: Date
    let categories: [WidgetDataManager.WidgetCategory]
}

struct QuickLogWidgetEntryView : View {
    var entry: QuickLogProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            Link(destination: URL(string: "financetracker://add-transaction")!) {
                VStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.white)
                    Text("Quick Log")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.blue.gradient)
                .containerBackground(for: .widget) {
                    ContainerRelativeShape()
                        .fill(Color.blue.gradient)
                }
            }
            .widgetURL(URL(string: "financetracker://add-transaction"))
            
        case .systemMedium:
            HStack(spacing: 12) {
                if entry.categories.isEmpty {
                    // Fallback if no categories set yet
                    Link(destination: URL(string: "financetracker://add-transaction")!) {
                        VStack {
                            Image(systemName: "plus")
                                .font(.title)
                            Text("Add Transaction")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                } else {
                    ForEach(entry.categories.prefix(4)) { category in
                        Link(destination: URL(string: "financetracker://add-transaction?category=\(category.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!) {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: category.colorHex).opacity(0.2))
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: category.icon)
                                        .font(.system(size: 20))
                                        .foregroundStyle(Color(hex: category.colorHex))
                                }
                                
                                Text(category.name)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                    .foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
            .padding()
            .containerBackground(for: .widget) {
                Color.black
            }
            
        case .accessoryCircular:
             // Lock Screen Button
             ZStack {
                Color.white.opacity(0.1)
                Image(systemName: "plus")
                    .font(.title2)
                    .bold()
            }
            .clipShape(Circle())
            .containerBackground(.clear, for: .widget)
            .widgetURL(URL(string: "financetracker://add-transaction"))
            
        default:
            Text("Not Supported")
        }
    }
}

// Helper extension for Color hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct QuickLogWidget: Widget {
    let kind: String = "QuickLogWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickLogProvider()) { entry in
            QuickLogWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Quick Action")
        .description("One-tap access to log transactions instantly from your home screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
        .contentMarginsDisabled()
    }
}
