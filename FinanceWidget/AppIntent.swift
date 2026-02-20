//
//  AppIntent.swift
//  FinanceWidget
//
//  Created by david wu on 1/19/26.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Widget Configuration"
    static var description = IntentDescription("Choose what data to display.")

    @Parameter(title: "Display Mode", default: .remaining)
    var displayMode: WidgetDisplayModeEnum
    
    @Parameter(title: "Background Style", default: .pure)
    var backgroundStyle: WidgetBackgroundAppEnum
}

enum WidgetDisplayModeEnum: String, AppEnum {
    case remaining
    case spent

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Display Mode"

    static var caseDisplayRepresentations: [WidgetDisplayModeEnum : DisplayRepresentation] = [
        .remaining: "Remaining Budget",
        .spent: "Total Spent"
    ]
}

enum WidgetBackgroundAppEnum: String, AppEnum {
    case pure
    case system
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Background Style"
    static var caseDisplayRepresentations: [WidgetBackgroundAppEnum : DisplayRepresentation] = [
        .pure: "Pure (Black/White)",
        .system: "System (Default iOS)"
    ]
}

struct WidgetBackgroundIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Widget Background"
    static var description = IntentDescription("Choose the background style for the widget.")
    
    @Parameter(title: "Background Style", default: .pure)
    var backgroundStyle: WidgetBackgroundAppEnum
}
