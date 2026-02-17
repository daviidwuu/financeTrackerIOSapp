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
