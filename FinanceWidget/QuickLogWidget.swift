import WidgetKit
import SwiftUI

struct QuickLogProvider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleLogEntry {
        SimpleLogEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleLogEntry) -> ()) {
        let entry = SimpleLogEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = SimpleLogEntry(date: Date())
        // Update once an hour is fine, purely static
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct SimpleLogEntry: TimelineEntry {
    let date: Date
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
            
        case .accessoryCircular:
             // Lock Screen Button
             ZStack {
                Color.white.opacity(0.1)
                Image(systemName: "plus")
                    .font(.title2)
                    .bold()
            }
            .clipShape(Circle())
            .clipShape(Circle())
            .containerBackground(.clear, for: .widget)
            .widgetURL(URL(string: "financetracker://add-transaction"))
            
        default:
            Text("Not Supported")
        }
    }
}

struct QuickLogWidget: Widget {
    let kind: String = "QuickLogWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickLogProvider()) { entry in
            QuickLogWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Quick Log")
        .description("Instantly open the add transaction screen.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
        .contentMarginsDisabled()
    }
}
