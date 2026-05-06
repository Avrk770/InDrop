import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct StatusMenuContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings = AppSettingsStore.shared
    @ObservedObject var viewModel: DropConversionViewModel
    @State private var isMainDropTargeted = false
    @State private var showsAutoConvertConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if viewModel.panelMode == .settings {
                SettingsPanelContent(
                    settings: settings,
                    onAutoConvertToggle: handleAutoConvertToggle(_:)
                )
            } else if viewModel.panelMode == .manualOverride {
                ManualOverrideContent(viewModel: viewModel)
            } else {
                mainContent
            }
        }
        .padding(.horizontal, Layout.outerPadding)
        .padding(.vertical, 12)
        .frame(width: Layout.panelWidth)
        .localizedLayout(settings.language)
        .onDeleteCommand(perform: viewModel.deleteSelectedPending)
        .background {
            KeyboardShortcutActions(viewModel: viewModel)
        }
        .confirmationDialog(
            AppStrings.autoConvertConfirmationTitle(),
            isPresented: $showsAutoConvertConfirmation,
            titleVisibility: .visible
        ) {
            Button(AppStrings.convertNow()) {
                settings.autoConvert = true
            }
            Button(AppStrings.cancel(), role: .cancel) {}
        } message: {
            Text(AppStrings.autoConvertConfirmationMessage(count: viewModel.pendingURLs.count))
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(viewModel.panelMode == .settings ? AppStrings.settings() : AppStrings.appTitle())
                .font(.system(size: 17, weight: .semibold))

            Spacer()

            Button {
                if viewModel.panelMode == .settings {
                    viewModel.showMainPanel()
                } else {
                    viewModel.showSettingsPanel()
                }
            } label: {
                if viewModel.panelMode == .settings {
                    Label(AppStrings.done(), systemImage: "checkmark")
                        .labelStyle(.titleAndIcon)
                } else {
                    Image(systemName: "gearshape")
                        .accessibilityLabel(AppStrings.settings())
                }
            }
                    .foregroundStyle(.primary)
            .buttonStyle(HeaderActionButtonStyle())
            .focusEffectDisabled()
            .help(viewModel.panelMode == .settings ? AppStrings.done() : AppStrings.settings())
        }
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            DropZoneView(
                state: viewModel.state,
                isTargeted: isMainDropTargeted,
                onPickFiles: {
                    let prefersManualFormatSelection = NSEvent.modifierFlags.contains(.option)
                    viewModel.pickFiles(prefersManualFormatSelection: prefersManualFormatSelection)
                }
            )

            if viewModel.state != .idle || !viewModel.results.isEmpty {
                StatusMessageBanner(state: viewModel.state, message: viewModel.statusMessage)
            }

            if viewModel.state == .processing {
                ConversionProgressPanel(
                    completed: viewModel.completedConversionCount,
                    total: viewModel.totalConversionCount,
                    fraction: viewModel.conversionProgressFraction,
                    onCancel: viewModel.cancelConversion
                )
            }

            if shouldShowUndoNotice(scope: nil) {
                inlineUndoNotice
            }

            if !viewModel.pendingURLs.isEmpty, viewModel.state != .processing {
                FocusQueuePanel(
                    count: viewModel.pendingURLs.count,
                    sampleURL: viewModel.pendingURLs.first,
                    canConvert: viewModel.canConvert && !settings.autoConvert,
                    showsActions: !settings.autoConvert,
                    onClear: viewModel.clearPending,
                    onConvert: {
                        viewModel.convertPending(prefersManualFormatSelection: false)
                    }
                )
            }

            if let summary = viewModel.conversionSummary {
                ConversionSummaryPanel(
                    converted: summary.converted,
                    skipped: summary.skipped,
                    failed: summary.failed,
                    canCopyReport: viewModel.hasFailedResults,
                    onRevealFolder: viewModel.revealFirstOutputFolder,
                    onCopyReport: viewModel.copyResultsReport
                )

                if shouldShowUndoNotice(scope: .results) {
                    inlineUndoNotice
                }
            }
        }
        .animation(.linear(duration: 0.06), value: isMainDropTargeted)
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isMainDropTargeted) { providers in
            let prefersManualFormatSelection = NSEvent.modifierFlags.contains(.option)
            return viewModel.handleDrop(providers: providers, prefersManualFormatSelection: prefersManualFormatSelection)
        }
        .onChange(of: isMainDropTargeted) { _, targeted in
            viewModel.setDragging(targeted)
        }
    }

    private func handleAutoConvertToggle(_ newValue: Bool) {
        if newValue,
           !settings.autoConvert,
           !viewModel.pendingURLs.isEmpty {
            showsAutoConvertConfirmation = true
            return
        }

        settings.autoConvert = newValue
    }

    private func shouldShowUndoNotice(scope: DropConversionViewModel.UndoScope?) -> Bool {
        guard let undoToast = viewModel.undoToast else { return false }
        if let scope {
            return undoToast.scope == scope
        }

        switch undoToast.scope {
        case .queue:
            return viewModel.pendingURLs.isEmpty
        case .results:
            return viewModel.results.isEmpty
        }
    }

    private var inlineUndoNotice: some View {
        Group {
            if let undoToast = viewModel.undoToast {
                InlineUndoNotice(message: undoToast.message, onUndo: viewModel.undoLastRemoval)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

private struct StatusMessageBanner: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings = AppSettingsStore.shared
    let state: DropConversionViewModel.ViewState
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: iconName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 15)

            Text(message)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(textColor)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .localizedParagraph(settings.language)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: Layout.smallRadius, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Layout.smallRadius, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        }
    }

    private var iconName: String {
        switch state {
        case .processing:
            "arrow.triangle.2.circlepath"
        case .queued:
            "tray.full"
        case .finished:
            isIssueMessage
                ? "exclamationmark.triangle.fill"
                : "checkmark.circle.fill"
        case .dragging:
            "arrow.down.circle.fill"
        case .idle:
            "info.circle.fill"
        }
    }

    private var iconColor: Color {
        switch state {
        case .finished where isIssueMessage:
            return .orange
        case .finished:
            return .green
        case .processing, .queued, .dragging:
            return .accentColor
        case .idle:
            return colorScheme == .dark ? Color.white.opacity(0.62) : .secondary
        }
    }

    private var textColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.72) : Color.primary.opacity(0.72)
    }

    private var backgroundColor: Color {
        if state == .finished, isIssueMessage {
            return Color.orange.opacity(colorScheme == .dark ? 0.16 : 0.1)
        }
        return colorScheme == .dark ? Color.white.opacity(0.045) : Color.black.opacity(0.035)
    }

    private var borderColor: Color {
        if state == .finished, isIssueMessage {
            return Color.orange.opacity(0.22)
        }
        return colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }

    private var isIssueMessage: Bool {
        message.localizedCaseInsensitiveContains("could")
            || message.localizedCaseInsensitiveContains("skipped")
            || message.localizedCaseInsensitiveContains("cancel")
            || message.contains("לא ניתן")
            || message.contains("דולג")
            || message.contains("דולגו")
            || message.contains("בוטל")
    }
}

private struct ConversionProgressPanel: View {
    let completed: Int
    let total: Int
    let fraction: Double
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(AppStrings.convertingProgress(completed: completed, total: total))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Button(AppStrings.cancelConversion(), action: onCancel)
                    .buttonStyle(.borderless)
                    .font(.system(size: 12, weight: .semibold))
            }

            ProgressView(value: fraction)
                .progressViewStyle(.linear)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: Layout.smallRadius, style: .continuous)
                .fill(Color.accentColor.opacity(0.08))
        )
        .overlay {
            RoundedRectangle(cornerRadius: Layout.smallRadius, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.18), lineWidth: 1)
        }
    }
}

private struct ConversionSummaryPanel: View {
    let converted: Int
    let skipped: Int
    let failed: Int
    let canCopyReport: Bool
    let onRevealFolder: () -> Void
    let onCopyReport: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 5) {
                Text(AppStrings.conversionSummary())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    SummaryPill(text: AppStrings.convertedCount(count: converted), tint: .green)
                    if skipped > 0 {
                        SummaryPill(text: AppStrings.skippedCount(count: skipped), tint: .orange)
                    }
                    if failed > 0 {
                        SummaryPill(text: AppStrings.failedCount(count: failed), tint: .red)
                    }
                }
            }

            Spacer(minLength: 8)

            Button(action: onRevealFolder) {
                Image(systemName: "folder")
                    .accessibilityLabel(AppStrings.revealFolder())
            }
            .buttonStyle(IconOnlyButtonStyle(tint: .accentColor))
            .help(AppStrings.revealFolder())
            .disabled(converted == 0)

            if canCopyReport {
                Button(action: onCopyReport) {
                    Image(systemName: "doc.on.doc")
                        .accessibilityLabel(AppStrings.copyReport())
                }
                .buttonStyle(IconOnlyButtonStyle(tint: .secondary))
                .help(AppStrings.copyReport())
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: Layout.smallRadius, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        )
        .overlay {
            RoundedRectangle(cornerRadius: Layout.smallRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.045), lineWidth: 1)
        }
    }
}

private struct FocusQueuePanel: View {
    @ObservedObject private var settings = AppSettingsStore.shared
    let count: Int
    let sampleURL: URL?
    let canConvert: Bool
    let showsActions: Bool
    let onClear: () -> Void
    let onConvert: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "tray.full")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 26, height: 26)
                .background(
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(AppStrings.queuedWaiting(count: count))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .localizedParagraph(settings.language)

                if let sampleURL {
                    Text(sampleTitle(for: sampleURL))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .localizedParagraph(settings.language)
                }
            }

            Spacer(minLength: 8)

            if showsActions {
                Button(action: onClear) {
                    Image(systemName: "trash")
                        .accessibilityLabel(AppStrings.clearAll())
                }
                .buttonStyle(IconOnlyButtonStyle(tint: .secondary))
                .help(AppStrings.clearAll())

                Button(AppStrings.convert(), action: onConvert)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canConvert)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: Layout.smallRadius, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        )
        .overlay {
            RoundedRectangle(cornerRadius: Layout.smallRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.045), lineWidth: 1)
        }
    }

    private func sampleTitle(for url: URL) -> String {
        guard count > 1 else { return url.lastPathComponent }
        return "\(url.lastPathComponent) + \(count - 1)"
    }
}

private struct SummaryPill: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))
            )
            .foregroundStyle(tint)
    }
}

private struct AdvancedSettingsDisclosure<Content: View>: View {
    @Binding var isExpanded: Bool
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(nil) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 11, height: 11)
                        .transaction { transaction in
                            transaction.animation = nil
                        }

                    Text(AppStrings.advancedSection())
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.primary.opacity(0.62))
                        .textCase(.uppercase)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                content
                    .transaction { transaction in
                        transaction.animation = nil
                    }
            }
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }
}

private struct SettingsPanelContent: View {
    @ObservedObject var settings: AppSettingsStore
    let onAutoConvertToggle: @MainActor (Bool) -> Void
    @State private var showsAdvancedSettings = false
    @State private var showsReplaceOriginalConfirmation = false
    @State private var pendingOriginalFileAction: AppPreferences.OriginalFileAction?

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            SettingsSection(title: AppStrings.generalSection()) {
                SettingsField(title: AppStrings.language()) {
                    Picker(AppStrings.language(), selection: $settings.language) {
                        ForEach(AppPreferences.Language.allCases) { language in
                            Text(language.title).tag(language)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 170)
                }

                rowDivider

                SettingsToggleRow(
                    title: AppStrings.convertImmediately(),
                    subtitle: AppStrings.convertImmediatelyHelp(),
                    isOn: settings.autoConvert,
                    onToggle: onAutoConvertToggle
                )

                rowDivider

                SettingsToggleRow(
                    title: AppStrings.launchAtLogin(),
                    subtitle: launchAtLoginSubtitle,
                    isOn: settings.launchAtLogin,
                    onToggle: { newValue in settings.launchAtLogin = newValue }
                )
            }

            SettingsSection(title: AppStrings.conversionSection()) {
                SettingsField(title: AppStrings.outputFormat()) {
                    Picker(AppStrings.outputFormat(), selection: $settings.outputFormat) {
                        ForEach(AppPreferences.OutputFormat.allCases) { format in
                            Text(format.title(in: settings.language)).tag(format)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 170)
                }

                rowDivider

                SettingsField(title: AppStrings.outputLocation()) {
                    Picker(AppStrings.outputLocation(), selection: $settings.outputLocation) {
                        ForEach(AppPreferences.OutputLocation.allCases) { location in
                            Text(location.title(in: settings.language)).tag(location)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 170)
                }

                if settings.outputLocation == .customFolder {
                    HStack(spacing: 8) {
                        Text(settings.customOutputFolderPath ?? AppStrings.chooseOutputFolder())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .localizedParagraph(settings.language)

                        Spacer()

                        Button(AppStrings.chooseOutputFolder()) {
                            settings.chooseCustomOutputFolder()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                rowDivider

                SettingsField(title: AppStrings.afterConversion()) {
                    Picker(AppStrings.afterConversion(), selection: originalFileActionBinding) {
                        ForEach(AppPreferences.OriginalFileAction.allCases) { action in
                            Text(action.title(in: settings.language)).tag(action)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 170)
                }

                if settings.originalFileAction == .replaceOriginal {
                    SettingsInfoNote(
                        message: AppStrings.replaceOriginalWarning(),
                        language: settings.language,
                        iconName: "exclamationmark.triangle.fill",
                        tint: .orange,
                        isWarning: true
                    )
                } else if settings.originalFileAction == .backupOriginal {
                    SettingsInfoNote(
                        message: AppStrings.backupOriginalHelp(),
                        language: settings.language
                    )
                }
            }

            AdvancedSettingsDisclosure(isExpanded: $showsAdvancedSettings) {
                advancedSettings
            }
        }
        .confirmationDialog(
            AppStrings.replaceOriginalConfirmationTitle(),
            isPresented: $showsReplaceOriginalConfirmation,
            titleVisibility: .visible
        ) {
            Button(AppStrings.useReplaceOriginal(), role: .destructive) {
                settings.originalFileAction = pendingOriginalFileAction ?? .replaceOriginal
                pendingOriginalFileAction = nil
            }
            Button(AppStrings.cancel(), role: .cancel) {
                pendingOriginalFileAction = nil
            }
        } message: {
            Text(AppStrings.replaceOriginalConfirmationMessage())
        }
    }

    private var advancedSettings: some View {
        VStack(alignment: .leading, spacing: 11) {
            SettingsInfoNote(
                message: AppStrings.outputFormatHelp(),
                language: settings.language
            )

            if settings.outputFormat == .jpeg {
                rowDivider
                jpegQualityControl
            }

            rowDivider

            SettingsToggleRow(
                title: AppStrings.openOutputFolderAfterConversion(),
                subtitle: AppStrings.openOutputFolderAfterConversionHelp(),
                isOn: settings.openOutputFolderAfterConversion,
                onToggle: { newValue in settings.openOutputFolderAfterConversion = newValue }
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: Layout.smallRadius, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        )
        .overlay {
            RoundedRectangle(cornerRadius: Layout.smallRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.045), lineWidth: 1)
        }
    }

    private var jpegQualityControl: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Text(AppStrings.jpegQualitySection())
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.72))
                Spacer()
                Text("\(Int(settings.jpegQuality * 100))%")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            Slider(value: $settings.jpegQuality, in: 0.6...1.0, step: 0.05)
                .tint(.accentColor)
                .controlSize(.regular)

            HStack {
                Text("60%")
                Spacer()
                Text("100%")
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(Color.primary.opacity(0.38))
        }
    }

    private var launchAtLoginSubtitle: String {
        if let errorMessage = settings.launchAtLoginErrorMessage {
            return errorMessage
        }
        if settings.launchAtLoginRequiresApproval {
            return AppStrings.launchAtLoginApproval()
        }
        return AppStrings.launchAtLoginHelp()
    }

    private var originalFileActionBinding: Binding<AppPreferences.OriginalFileAction> {
        Binding(
            get: { settings.originalFileAction },
            set: { newValue in
                if newValue == .replaceOriginal, settings.originalFileAction != .replaceOriginal {
                    pendingOriginalFileAction = newValue
                    showsReplaceOriginalConfirmation = true
                    return
                }

                settings.originalFileAction = newValue
            }
        )
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 1)
    }
}

private struct ManualOverrideContent: View {
    @ObservedObject private var settings = AppSettingsStore.shared
    @ObservedObject var viewModel: DropConversionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppStrings.manualOverrideTitle())
                    .font(.system(size: 16, weight: .semibold))

                Text(AppStrings.manualOverrideSubtitle())
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .localizedParagraph(settings.language)
            }

            SettingsField(title: AppStrings.manualOutputFormat()) {
                Picker(AppStrings.manualOutputFormat(), selection: $viewModel.manualOverrideFormat) {
                    ForEach(AppPreferences.OutputFormat.allCases) { format in
                        Text(format.title(in: AppStrings.currentLanguage())).tag(format)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 170)
            }

            if viewModel.manualOverrideContainsPDF {
                SettingsSection(title: AppStrings.pdfPagesSection()) {
                    if let pdfURL = viewModel.manualOverridePDFPreviewURL,
                       let pageCount = viewModel.manualOverridePDFPageCount {
                        PDFPageThumbnailGrid(
                            url: pdfURL,
                            pageCount: pageCount,
                            selectedPages: viewModel.manualPDFSelectedPages,
                            usesCustomPages: viewModel.manualPDFUsesCustomPages,
                            onTogglePage: viewModel.toggleManualPDFPage(_:),
                            onSelectAll: viewModel.selectAllManualPDFPages
                        )
                    }

                    Toggle(AppStrings.selectedPDFPages(), isOn: $viewModel.manualPDFUsesCustomPages)
                        .font(.system(size: 13, weight: .medium))
                        .toggleStyle(.checkbox)

                    if viewModel.manualPDFUsesCustomPages {
                        TextField(
                            AppStrings.pdfPageRangePlaceholder(),
                            text: $viewModel.manualPDFPageRangeText
                        )
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, weight: .medium))
                    }

                    HStack(alignment: .top, spacing: 7) {
                        Image(systemName: viewModel.manualPDFUsesCustomPages ? "number" : "doc.on.doc")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 14)

                        Text(viewModel.manualPDFUsesCustomPages ? viewModel.manualPDFSelectionSummary : AppStrings.pdfPageRangeHelp())
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .localizedParagraph(settings.language)

                        Spacer(minLength: 0)
                    }
                }
            }

            if !viewModel.manualOverrideURLs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(AppStrings.manualOverrideFiles())
                        .font(.subheadline.weight(.semibold))

                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(viewModel.manualOverrideURLs, id: \.path) { url in
                                HStack(alignment: .top, spacing: 10) {
                                    QueuedFileThumbnail(url: url)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(url.lastPathComponent)
                                            .font(.subheadline.weight(.medium))
                                            .lineLimit(2)

                                        Text(viewModel.predictedOutputFilename(for: url, format: viewModel.manualOverrideFormat))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }

                                    Spacer()
                                }
                                .padding(.horizontal, 9)
                                .padding(.vertical, 7)
                            }
                        }
                    }
                    .frame(height: Layout.listHeight(for: viewModel.manualOverrideURLs.count))
                    .background(
                        RoundedRectangle(cornerRadius: Layout.smallRadius, style: .continuous)
                            .fill(Color.primary.opacity(0.028))
                    )
                }
            }

            HStack(spacing: 10) {
                Button(AppStrings.back(), action: viewModel.cancelManualOverride)
                    .buttonStyle(.bordered)

                Spacer()

                Button(AppStrings.apply(), action: viewModel.confirmManualOverride)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(viewModel.manualOverrideURLs.isEmpty)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Layout.smallRadius, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        )
        .overlay {
            RoundedRectangle(cornerRadius: Layout.smallRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.045), lineWidth: 1)
        }
    }
}

private struct PDFPageThumbnailGrid: View {
    let url: URL
    let pageCount: Int
    let selectedPages: Set<Int>
    let usesCustomPages: Bool
    let onTogglePage: (Int) -> Void
    let onSelectAll: () -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 58, maximum: 72), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(AppStrings.allPDFPages())
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(AppStrings.allPDFPages(), action: onSelectAll)
                    .buttonStyle(.borderless)
                    .font(.system(size: 12, weight: .semibold))
            }

            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(1...pageCount, id: \.self) { page in
                        PDFPageThumbnailButton(
                            url: url,
                            page: page,
                            isSelected: !usesCustomPages || selectedPages.contains(page),
                            onToggle: { onTogglePage(page) }
                        )
                    }
                }
                .padding(2)
            }
            .frame(height: min(CGFloat((pageCount + 3) / 4) * 84, 178))
        }
    }
}

private struct PDFPageThumbnailButton: View {
    let url: URL
    let page: Int
    let isSelected: Bool
    let onToggle: () -> Void
    @State private var image: NSImage?
    @State private var isHovered = false

    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Group {
                        if let image {
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 54, height: 62)
                                .background(Color.white)
                        } else {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.secondary.opacity(0.12))
                                .frame(width: 54, height: 62)
                                .overlay {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: isSelected ? 2 : 1)
                    }

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                            .background(Color(NSColor.windowBackgroundColor), in: Circle())
                            .offset(x: 5, y: -5)
                    }
                }

                Text("\(page)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 3)
            .frame(width: 64)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.05) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .task(id: "\(url.path)-\(page)") {
            image = await renderPDFPageThumbnail(url: url, page: page)
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    var emphasized = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(0.62))
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 11) {
                content
            }
            .padding(.horizontal, 10)
            .padding(.vertical, emphasized ? 10 : 9)
            .background(
                RoundedRectangle(cornerRadius: Layout.smallRadius, style: .continuous)
                    .fill(emphasized ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.035))
                    .overlay {
                        RoundedRectangle(cornerRadius: Layout.smallRadius, style: .continuous)
                            .strokeBorder(emphasized ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.045), lineWidth: 1)
                    }
            )
        }
    }
}

private struct SettingsToggleRow: View {
    @ObservedObject private var settings = AppSettingsStore.shared
    let title: String
    let subtitle: String
    let isOn: Bool
    let onToggle: @MainActor (Bool) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .localizedParagraph(settings.language)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: Binding(
                get: { isOn },
                set: { newValue in
                    onToggle(newValue)
                }
            ))
                .labelsHidden()
                .controlSize(.small)
        }
    }
}

private struct SettingsField<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.72))
            Spacer()
            content
        }
    }
}

private struct SettingsInfoNote: View {
    let message: String
    let language: AppPreferences.Language
    var iconName = "info.circle.fill"
    var tint: Color = .secondary
    var isWarning = false

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: iconName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 14)

            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isWarning ? Color.primary.opacity(0.72) : .secondary)
                .fixedSize(horizontal: false, vertical: true)
                .localizedParagraph(language)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isWarning ? Color.orange.opacity(0.1) : Color.primary.opacity(0.025))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isWarning ? Color.orange.opacity(0.2) : Color.primary.opacity(0.04), lineWidth: 1)
        }
    }
}

private struct QueuedFileThumbnail: View {
    let url: URL

    var body: some View {
        AsyncThumbnailView(url: url)
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: Layout.thumbnailRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Layout.thumbnailRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08))
        }
    }
}

private struct AsyncThumbnailView: View {
    let url: URL
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.secondary.opacity(0.12))
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task(id: url) {
            image = await loadImage()
        }
    }

    private func loadImage() async -> NSImage? {
        await Task.detached(priority: .utility) {
            if url.pathExtension.caseInsensitiveCompare("pdf") == .orderedSame {
                return renderPDFThumbnail(url: url)
            }
            return NSImage(contentsOf: url)
        }.value
    }
}

private func renderPDFThumbnail(url: URL) -> NSImage? {
    renderPDFPageThumbnailSync(url: url, page: 1, longestSide: 160)
}

private func renderPDFPageThumbnail(url: URL, page: Int) async -> NSImage? {
    await Task.detached(priority: .utility) {
        renderPDFPageThumbnailSync(url: url, page: page, longestSide: 118)
    }.value
}

private func renderPDFPageThumbnailSync(url: URL, page pageNumber: Int, longestSide: CGFloat) -> NSImage? {
    guard let document = CGPDFDocument(url as CFURL),
          let page = document.page(at: pageNumber) else {
        return nil
    }

    let pageRect = page.getBoxRect(.mediaBox)
    let scale = min(longestSide / max(pageRect.width, pageRect.height), 2)
    let width = max(Int(pageRect.width * scale), 1)
    let height = max(Int(pageRect.height * scale), 1)

    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return nil
    }

    context.setFillColor(NSColor.white.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: scale, y: -scale)
    context.drawPDFPage(page)

    guard let image = context.makeImage() else { return nil }
    return NSImage(cgImage: image, size: NSSize(width: width, height: height))
}

private enum Layout {
    static let panelWidth: CGFloat = 410
    static let outerPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 12
    static let smallRadius: CGFloat = 9
    static let thumbnailRadius: CGFloat = 7
    static let listRowHeight: CGFloat = 56
    static let listMaxHeight: CGFloat = 224

    static func listHeight(for rowCount: Int) -> CGFloat {
        guard rowCount > 0 else { return 0 }
        return min(CGFloat(rowCount) * listRowHeight, listMaxHeight)
    }
}

private struct KeyboardShortcutActions: View {
    @ObservedObject var viewModel: DropConversionViewModel

    var body: some View {
        Button(AppStrings.chooseImages()) {
            let prefersManualFormatSelection = NSEvent.modifierFlags.contains(.option)
            viewModel.pickFiles(prefersManualFormatSelection: prefersManualFormatSelection)
        }
        .keyboardShortcut("o")
        .frame(width: 0, height: 0)
        .opacity(0.001)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct InlineUndoNotice: View {
    @Environment(\.colorScheme) private var colorScheme
    let message: String
    let onUndo: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.6) : .secondary)
                .lineLimit(2)

            Button(AppStrings.undo(), action: onUndo)
                .buttonStyle(.borderless)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.accentColor)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 2)
    }
}

private struct HeaderActionButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .frame(minWidth: 28, minHeight: 28)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(isHovered ? 0.12 : 0.055), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onHover { isHovered = $0 }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isPressed {
            return Color.primary.opacity(0.12)
        }
        if isHovered {
            return Color.primary.opacity(0.07)
        }
        return Color.primary.opacity(0.04)
    }
}

private struct IconOnlyButtonStyle: ButtonStyle {
    let tint: Color
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 26, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .onHover { isHovered = $0 }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isPressed {
            return tint.opacity(0.18)
        }
        if isHovered {
            return tint.opacity(0.1)
        }
        return .clear
    }
}
