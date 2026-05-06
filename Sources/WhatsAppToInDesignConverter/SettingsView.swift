import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettingsStore

    var body: some View {
        Form {
            Picker(AppStrings.language(), selection: $settings.language) {
                ForEach(AppPreferences.Language.allCases) { language in
                    Text(language.title).tag(language)
                }
            }

            Picker(AppStrings.outputFormat(), selection: $settings.outputFormat) {
                ForEach(AppPreferences.OutputFormat.allCases) { format in
                    Text(format.title(in: settings.language)).tag(format)
                }
            }

            Text(AppStrings.outputFormatHelp())
                .font(.caption)
                .foregroundStyle(.secondary)
                .localizedParagraph(settings.language)

            Picker(AppStrings.outputLocation(), selection: $settings.outputLocation) {
                ForEach(AppPreferences.OutputLocation.allCases) { location in
                    Text(location.title(in: settings.language)).tag(location)
                }
            }

            if settings.outputLocation == .customFolder {
                Button(settings.customOutputFolderPath ?? AppStrings.chooseOutputFolder()) {
                    settings.chooseCustomOutputFolder()
                }
            }

            Picker(AppStrings.afterConversion(), selection: $settings.originalFileAction) {
                ForEach(AppPreferences.OriginalFileAction.allCases) { action in
                    Text(action.title(in: settings.language)).tag(action)
                }
            }

            if settings.originalFileAction == .replaceOriginal {
                Text(AppStrings.replaceOriginalWarning())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .localizedParagraph(settings.language)
            } else if settings.originalFileAction == .backupOriginal {
                Text(AppStrings.backupOriginalHelp())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .localizedParagraph(settings.language)
            }

            Toggle(AppStrings.openOutputFolderAfterConversion(), isOn: $settings.openOutputFolderAfterConversion)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(AppStrings.jpegQualitySection())
                    Spacer()
                    Text("\(Int(settings.jpegQuality * 100))%")
                        .foregroundStyle(.secondary)
                }

                Slider(value: $settings.jpegQuality, in: 0.6...1.0, step: 0.05)
                    .disabled(settings.outputFormat != .jpeg)

                if settings.outputFormat != .jpeg {
                    Text(AppStrings.jpegQualityHelp())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Toggle(AppStrings.convertImmediately(), isOn: $settings.autoConvert)

            VStack(alignment: .leading, spacing: 8) {
                Toggle(AppStrings.launchAtLogin(), isOn: $settings.launchAtLogin)

                if settings.launchAtLoginRequiresApproval {
                    Text(AppStrings.launchAtLoginApproval())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .localizedParagraph(settings.language)
                } else if let errorMessage = settings.launchAtLoginErrorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .localizedParagraph(settings.language)
                } else {
                    Text(AppStrings.launchAtLoginHelp())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .localizedParagraph(settings.language)
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 420)
        .localizedLayout(settings.language)
    }
}
