//
//  FinanceWidgetLiveActivity.swift
//  FinanceWidget
//
//  Created by david wu on 1/19/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct FinanceWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct FinanceWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FinanceWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension FinanceWidgetAttributes {
    fileprivate static var preview: FinanceWidgetAttributes {
        FinanceWidgetAttributes(name: "World")
    }
}

extension FinanceWidgetAttributes.ContentState {
    fileprivate static var smiley: FinanceWidgetAttributes.ContentState {
        FinanceWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: FinanceWidgetAttributes.ContentState {
         FinanceWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: FinanceWidgetAttributes.preview) {
   FinanceWidgetLiveActivity()
} contentStates: {
    FinanceWidgetAttributes.ContentState.smiley
    FinanceWidgetAttributes.ContentState.starEyes
}
