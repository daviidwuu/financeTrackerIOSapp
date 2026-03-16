import WidgetKit
import SwiftUI

struct QuickLogProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleLogEntry {
        SimpleLogEntry(date: Date(), configuration: WidgetBackgroundIntent(), categories: [])
    }

    func snapshot(for configuration: WidgetBackgroundIntent, in context: Context) async -> SimpleLogEntry {
        let categories = WidgetDataManager.shared.getQuickLogCategories()
        return SimpleLogEntry(date: Date(), configuration: configuration, categories: categories)
    }

    func timeline(for configuration: WidgetBackgroundIntent, in context: Context) async -> Timeline<SimpleLogEntry> {
        let categories = WidgetDataManager.shared.getQuickLogCategories()
        let entry = SimpleLogEntry(date: Date(), configuration: configuration, categories: categories)
        // Update whenever app is opened (handled by reloadAllTimelines)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}

struct SimpleLogEntry: TimelineEntry {
    let date: Date
    let configuration: WidgetBackgroundIntent
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
                        .foregroundStyle(Color.primary)
                        .symbolEffect(.bounce, options: .nonRepeating)
                    Text("Quick Log")
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(UIColor.secondarySystemBackground))
                .applyWidgetBackground(style: entry.configuration.backgroundStyle) // Custom modifier
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
                                .foregroundColor(.white)
                            Text("Add Transaction")
                                .font(.caption)
                                .bold()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                } else {
                    // Layout up to 4 quick action buttons
                    let displayLimit = min(4, entry.categories.count)
                    ForEach(entry.categories.prefix(displayLimit)) { category in
                        Link(destination: URL(string: "financetracker://add-transaction?category=\(category.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!) {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: category.colorHex).opacity(0.15))
                                        .frame(width: 48, height: 48)
                                    
                                    Image(systemName: category.icon)
                                        .font(.title3)
                                        .foregroundStyle(Color(hex: category.colorHex))
                                }
                                
                                Text(category.name)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                    .foregroundStyle(Color.primary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
            .padding()
            .applyWidgetBackground(style: entry.configuration.backgroundStyle) // Custom modifier
            
        case .accessoryCircular:
             // Lock Screen Button
             ZStack {
                Image(systemName: "plus")
                    .font(.title2)
                    .bold()
            }
            .clipShape(Circle())
            .containerBackground(.clear, for: .widget)
            .widgetURL(URL(string: "financetracker://add-transaction"))
            
        default:
            Text("Unsupported Widget Size")
        }
    }
}

// SwiftUI Helper for environments
struct OptionalEnvironmentView<Content: View>: View {
    let content: (ColorScheme) -> Content
    @Environment(\.colorScheme) var scheme
    var body: some View {
        content(scheme)
    }
}

extension View {
    func applyWidgetBackground(style: WidgetBackgroundAppEnum? = nil) -> some View {
        return self.containerBackground(for: .widget) {
            OptionalEnvironmentView { scheme -> AnyView in
                let theme = WidgetDataManager.shared.getAppTheme()
                if theme == .system {
                    // Fallback to basic pure/system if theme is system
                    if style == .pure {
                        return AnyView(scheme == .dark ? Color.black : Color.white)
                    } else {
                        return AnyView(Color(UIColor.systemBackground))
                    }
                } else {
                    return AnyView(scheme == .dark ? Color(theme.backgroundColorDark) : Color(theme.backgroundColorLight))
                }
            }
        }
    }
}



struct QuickLogWidget: Widget {
    let kind: String = "QuickLogWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: WidgetBackgroundIntent.self, provider: QuickLogProvider()) { entry in
            QuickLogWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Quick Action")
        .description("One-tap access to log transactions instantly from your home screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
        .contentMarginsDisabled()
    }
}
