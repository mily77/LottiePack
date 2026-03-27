import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @AppStorage("jsonExportFormatting") private var jsonExportFormattingRawValue = JSONExportFormatting.compressed.rawValue

    private var jsonExportFormatting: Binding<JSONExportFormatting> {
        Binding(
            get: { JSONExportFormatting(rawValue: jsonExportFormattingRawValue) ?? .compressed },
            set: { jsonExportFormattingRawValue = $0.rawValue }
        )
    }

    var body: some View {
        Form {
            Picker(L10n.tr("settings.language.label"), selection: $preferences.language) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }

            Text(L10n.tr("settings.language.hint"))
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker(L10n.tr("settings.json_format.label"), selection: jsonExportFormatting) {
                ForEach(JSONExportFormatting.allCases) { formatting in
                    Text(formatting.label).tag(formatting)
                }
            }

            Text(L10n.tr("settings.json_format.hint"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 420)
    }
}
