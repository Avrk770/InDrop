import AppKit
import Combine
import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class DropConversionViewModel: ObservableObject {
    enum UndoScope {
        case queue
        case results
    }

    struct UndoToast: Identifiable {
        let id = UUID()
        let message: String
        let scope: UndoScope
    }

    enum PanelMode {
        case main
        case settings
        case manualOverride
    }

    enum ViewState {
        case idle
        case dragging
        case queued
        case processing
        case finished
    }

    @Published var state: ViewState = .idle
    @Published var panelMode: PanelMode = .main
    @Published var pendingURLs: [URL] = []
    @Published var selectedPendingURL: URL?
    @Published var manualOverrideURLs: [URL] = []
    @Published var manualOverrideFormat: AppPreferences.OutputFormat
    @Published var manualPDFUsesCustomPages = false
    @Published var manualPDFPageRangeText = ""
    @Published var manualPDFSelectedPages = Set<Int>()
    @Published var results: [ConversionResult] = []
    @Published var selectedResultURL: URL?
    @Published var statusMessage: String
    @Published var completedConversionCount = 0
    @Published var totalConversionCount = 0
    @Published var undoToast: UndoToast?

    private(set) var queueGeneration = 0
    private let conversionService: ConversionService
    private let notificationManager: NotificationManager
    private let settings: AppSettingsStore
    private let defaults: UserDefaults
    private var settingsCancellable: AnyCancellable?
    private var undoAction: UndoAction?
    private var undoDismissTask: Task<Void, Never>?
    private var conversionTask: Task<Void, Never>?

    private enum Keys {
        static let persistedQueuePaths = "queue.pendingPaths"
        static let persistedResultHistory = "results.history"
    }

    private struct PendingSnapshot {
        let urls: [URL]
        let selectedURL: URL?
        let state: ViewState
        let statusMessage: String
    }

    private struct ResultsSnapshot {
        let results: [ConversionResult]
        let selectedURL: URL?
    }

    private enum UndoAction {
        case pending(PendingSnapshot)
        case results(ResultsSnapshot)
    }

    init(
        conversionService: ConversionService? = nil,
        notificationManager: NotificationManager = .shared,
        settings: AppSettingsStore = .shared,
        defaults: UserDefaults = .standard
    ) {
        self.conversionService = conversionService ?? ConversionService(preferences: settings.preferences)
        self.notificationManager = notificationManager
        self.settings = settings
        self.defaults = defaults
        self.manualOverrideFormat = settings.outputFormat
        self.statusMessage = AppStrings.defaultStatus()
        restorePersistedQueue()
        observeSettings()
    }

    var canConvert: Bool {
        !pendingURLs.isEmpty && state != .processing
    }

    var canCancelConversion: Bool {
        state == .processing && conversionTask != nil
    }

    var conversionProgressFraction: Double {
        guard totalConversionCount > 0 else { return 0 }
        return min(Double(completedConversionCount) / Double(totalConversionCount), 1)
    }

    var selectedPreviewURL: URL? {
        if let selectedResultURL {
            return selectedResultURL
        }
        return selectedPendingURL
    }

    var conversionSummary: (converted: Int, skipped: Int, failed: Int)? {
        guard state == .finished, !results.isEmpty else { return nil }
        let converted = results.filter { $0.status == .success }.count
        let skipped = results.filter { $0.status == .skipped }.count
        let failed = results.filter { $0.status == .failure }.count
        return (converted, skipped, failed)
    }

    var hasFailedResults: Bool {
        results.contains { $0.status == .failure || $0.status == .skipped }
    }

    func setDragging(_ isDragging: Bool) {
        guard state != .processing else { return }

        if isDragging {
            state = .dragging
        } else if pendingURLs.isEmpty {
            state = .idle
        } else {
            state = .queued
        }
    }

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        handleDrop(providers: providers, prefersManualFormatSelection: false)
    }

    func handleDrop(providers: [NSItemProvider], prefersManualFormatSelection: Bool) -> Bool {
        let supportedProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }

        guard !supportedProviders.isEmpty else {
            statusMessage = AppStrings.finderDropHint()
            state = .finished
            return false
        }

        Task {
            let urls = await extractURLs(from: supportedProviders)
            queue(urls: urls, prefersManualFormatSelection: prefersManualFormatSelection)
        }
        return true
    }

    func handleDrop(urls: [URL]) {
        handleDrop(urls: urls, prefersManualFormatSelection: false)
    }

    func handleDrop(urls: [URL], prefersManualFormatSelection: Bool) {
        queue(urls: urls, prefersManualFormatSelection: prefersManualFormatSelection)
    }

    func pickFiles(prefersManualFormatSelection: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = SupportedFileTypes.openPanelContentTypes
        panel.resolvesAliases = true
        if let parentWindow = NSApp.keyWindow ?? NSApp.mainWindow {
            panel.beginSheetModal(for: parentWindow) { [weak self] response in
                guard response == .OK else { return }
                Task { @MainActor in
                    self?.handleDrop(urls: panel.urls, prefersManualFormatSelection: prefersManualFormatSelection)
                }
            }
            return
        }

        guard panel.runModal() == .OK else { return }
        handleDrop(urls: panel.urls, prefersManualFormatSelection: prefersManualFormatSelection)
    }

    func showMainPanel() {
        panelMode = .main
        manualOverrideURLs = []
        manualOverrideFormat = settings.outputFormat
        manualPDFUsesCustomPages = false
        manualPDFPageRangeText = ""
        manualPDFSelectedPages = []
    }

    func showSettingsPanel() {
        panelMode = .settings
    }

    func convertPending() {
        convertPending(prefersManualFormatSelection: false)
    }

    func convertPending(prefersManualFormatSelection: Bool) {
        let urls = pendingURLs
        guard !urls.isEmpty else { return }
        guard state != .processing else { return }

        if prefersManualFormatSelection {
            beginManualOverride(with: urls)
        } else {
            guard confirmReplaceOriginalBatchIfNeeded(urls: urls) else { return }
            startProcessing(urls: urls, overrideFormat: nil)
        }
    }

    func convertImmediately(urls: [URL]) {
        let uniqueURLs = Self.discoverSupportedFiles(from: urls).urls

        guard !uniqueURLs.isEmpty else {
            statusMessage = AppStrings.unreadableDrop()
            state = .finished
            return
        }

        guard confirmReplaceOriginalBatchIfNeeded(urls: uniqueURLs) else { return }
        startProcessing(urls: uniqueURLs, overrideFormat: nil)
    }

    func cancelConversion() {
        guard canCancelConversion else { return }
        conversionTask?.cancel()
        statusMessage = AppStrings.conversionCancelled(
            completed: completedConversionCount,
            total: totalConversionCount
        )
    }

    func clearPending() {
        let snapshot = PendingSnapshot(
            urls: pendingURLs,
            selectedURL: selectedPendingURL,
            state: state,
            statusMessage: statusMessage
        )
        let removedCount = pendingURLs.count
        pendingURLs = []
        selectedPendingURL = nil
        state = .idle
        statusMessage = AppStrings.defaultStatus()
        persistPendingQueue()
        guard removedCount > 0 else { return }
        showUndoToast(message: AppStrings.clearedQueue(count: removedCount), scope: .queue, action: .pending(snapshot))
    }

    func reveal(_ result: ConversionResult) {
        NSWorkspace.shared.activateFileViewerSelecting([result.outputURL ?? result.originalURL])
    }

    func reveal(url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func open(url: URL) {
        NSWorkspace.shared.open(url)
    }

    func revealFirstOutputFolder() {
        guard let folder = outputFolders().first else { return }
        NSWorkspace.shared.activateFileViewerSelecting([folder])
    }

    func copyResultsReport() {
        let report = results.map { result in
            let status: String
            switch result.status {
            case .processing:
                status = "Processing"
            case .success:
                status = "Converted"
            case .skipped:
                status = "Skipped"
            case .failure:
                status = "Failed"
            }

            let output = result.outputURL?.path ?? "-"
            let error = result.errorMessage ?? ""
            return [status, result.originalURL.path, output, error]
                .filter { !$0.isEmpty }
                .joined(separator: "\t")
        }.joined(separator: "\n")

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(report, forType: .string)
    }

    func copyPath(url: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url.path, forType: .string)
    }

    func selectPending(_ url: URL) {
        selectedPendingURL = url
    }

    func removePending(_ url: URL) {
        let snapshot = PendingSnapshot(
            urls: pendingURLs,
            selectedURL: selectedPendingURL,
            state: state,
            statusMessage: statusMessage
        )
        pendingURLs.removeAll { $0 == url }
        if selectedPendingURL == url {
            selectedPendingURL = nil
        }
        state = pendingURLs.isEmpty ? .idle : .queued
        statusMessage = pendingURLs.isEmpty ? AppStrings.defaultStatus() : AppStrings.queuedWaiting(count: pendingURLs.count)
        persistPendingQueue()
        showUndoToast(message: AppStrings.removedFromQueue(count: 1), scope: .queue, action: .pending(snapshot))
    }

    func deleteSelectedPending() {
        guard let selectedPendingURL else { return }
        removePending(selectedPendingURL)
    }

    func selectResult(_ url: URL) {
        selectedResultURL = url
    }

    func clearResults() {
        let snapshot = ResultsSnapshot(results: results, selectedURL: selectedResultURL)
        let clearedCount = results.count
        results = []
        selectedResultURL = nil
        persistResultHistory()
        guard clearedCount > 0 else { return }
        showUndoToast(message: AppStrings.clearedResultsMessage(count: clearedCount), scope: .results, action: .results(snapshot))
    }

    func undoLastRemoval() {
        guard let undoAction else { return }
        dismissUndoToast(clearAction: false)

        switch undoAction {
        case let .pending(snapshot):
            pendingURLs = snapshot.urls
            selectedPendingURL = snapshot.selectedURL
            state = snapshot.state
            statusMessage = snapshot.statusMessage
            persistPendingQueue()
        case let .results(snapshot):
            results = snapshot.results
            selectedResultURL = snapshot.selectedURL
            persistResultHistory()
        }

        self.undoAction = nil
    }

    func prepareManualConversionFromQueuedFiles() {
        prepareManualConversionFromQueuedFiles(format: nil)
    }

    func prepareManualConversionFromQueuedFiles(format: AppPreferences.OutputFormat?) {
        guard !pendingURLs.isEmpty else {
            statusMessage = AppStrings.noQueuedFiles()
            state = .idle
            return
        }

        beginManualOverride(with: pendingURLs)
        if let format {
            manualOverrideFormat = format
        }
    }

    func cancelManualOverride() {
        manualOverrideURLs = []
        manualPDFUsesCustomPages = false
        manualPDFPageRangeText = ""
        manualPDFSelectedPages = []
        panelMode = .main
    }

    func confirmManualOverride() {
        let urls = manualOverrideURLs
        guard !urls.isEmpty else { return }

        guard let pdfPageSelection = manualPDFPageSelection else {
            statusMessage = AppStrings.invalidPDFPageRange()
            return
        }

        guard confirmReplaceOriginalBatchIfNeeded(urls: urls) else { return }
        startProcessing(urls: urls, overrideFormat: manualOverrideFormat, pdfPageSelection: pdfPageSelection)
    }

    var manualOverridePDFPageCount: Int? {
        manualOverrideURLs.compactMap(Self.pdfPageCount(for:)).max()
    }

    var manualOverridePDFPreviewURL: URL? {
        manualOverrideURLs.first { Self.pdfPageCount(for: $0) != nil }
    }

    var manualOverrideContainsPDF: Bool {
        manualOverridePDFPageCount != nil
    }

    var manualPDFSelectionSummary: String {
        guard let pageCount = manualOverridePDFPageCount else { return "" }
        guard manualPDFUsesCustomPages else {
            return AppStrings.selectedPDFPageCount(selected: pageCount, total: pageCount)
        }
        guard let pages = PDFPageRangeParser.parse(manualPDFPageRangeText) else {
            return AppStrings.invalidPDFPageRange()
        }
        let validCount = PDFPageSelection.pages(pages).resolvedPages(totalPages: pageCount).count
        guard validCount > 0 else {
            return AppStrings.invalidPDFPageRange()
        }
        return AppStrings.selectedPDFPageCount(selected: validCount, total: pageCount)
    }

    func toggleManualPDFPage(_ page: Int) {
        guard let pageCount = manualOverridePDFPageCount,
              (1...pageCount).contains(page) else {
            return
        }
        manualPDFUsesCustomPages = true
        if manualPDFSelectedPages.contains(page) {
            manualPDFSelectedPages.remove(page)
        } else {
            manualPDFSelectedPages.insert(page)
        }
        manualPDFPageRangeText = Self.pageRangeText(for: manualPDFSelectedPages)
    }

    func selectAllManualPDFPages() {
        manualPDFUsesCustomPages = false
        manualPDFSelectedPages = []
        manualPDFPageRangeText = ""
    }

    func predictedOutputFilename(for url: URL) -> String {
        let format = ConversionService.suggestedOutputFormat(for: url, preferences: settings.preferences)
        return predictedOutputFilename(for: url, format: format)
    }

    func predictedOutputFilename(for url: URL, format: AppPreferences.OutputFormat) -> String {
        let baseName = url.deletingPathExtension().lastPathComponent
        if let pageCount = Self.pdfPageCount(for: url), pageCount > 1 {
            let firstPageName = AppStrings.pageFilenameComponent(page: 1, total: pageCount, language: settings.language)
            return "\(predictedBaseName(name: baseName, pageComponent: firstPageName)).\(format.fileExtension) ..."
        }
        return predictedBaseName(name: baseName, pageComponent: nil) + ".\(format.fileExtension)"
    }

    private func queue(urls: [URL], prefersManualFormatSelection: Bool) {
        let discovery = Self.discoverSupportedFiles(from: urls)
        let newURLs = discovery.urls

        guard !newURLs.isEmpty else {
            statusMessage = AppStrings.unreadableDrop()
            state = .finished
            return
        }

        let rejectedCount = discovery.rejectedCount

        if prefersManualFormatSelection {
            if rejectedCount > 0 {
                statusMessage = AppStrings.addedSupportedFiles(accepted: newURLs.count, rejected: rejectedCount)
            }
            beginManualOverride(with: newURLs)
            return
        }

        var combinedURLs = pendingURLs
        for url in newURLs where !combinedURLs.contains(url) {
            combinedURLs.append(url)
        }

        pendingURLs = combinedURLs
        selectedPendingURL = combinedURLs.last
        results = []
        state = .queued
        queueGeneration += 1
        persistPendingQueue()
        if settings.preferences.autoConvert {
            statusMessage = AppStrings.queuedStarting(count: combinedURLs.count)
            convertPending()
        } else {
            statusMessage = rejectedCount > 0
                ? AppStrings.addedSupportedFiles(accepted: newURLs.count, rejected: rejectedCount)
                : AppStrings.queuedWaiting(count: combinedURLs.count)
        }
    }

    private func startProcessing(
        urls: [URL],
        overrideFormat: AppPreferences.OutputFormat?,
        pdfPageSelection: PDFPageSelection = .all
    ) {
        guard state != .processing else { return }
        conversionTask = Task { [weak self] in
            await self?.process(urls: urls, overrideFormat: overrideFormat, pdfPageSelection: pdfPageSelection)
        }
    }

    private func process(
        urls: [URL],
        overrideFormat: AppPreferences.OutputFormat? = nil,
        pdfPageSelection: PDFPageSelection = .all
    ) async {
        panelMode = .main
        state = .processing
        totalConversionCount = urls.count
        completedConversionCount = 0
        results = urls.map { url in
            ConversionResult(
                originalURL: url,
                outputURL: nil,
                outputFormat: ConversionService.suggestedOutputFormat(for: url, preferences: settings.preferences, overrideFormat: overrideFormat),
                status: .processing,
                errorMessage: nil
            )
        }
        statusMessage = AppStrings.converting(count: urls.count)

        let service = ConversionService(
            preferences: settings.preferences,
            overrideFormat: overrideFormat,
            pdfPageSelection: pdfPageSelection
        )
        pendingURLs = []
        selectedPendingURL = nil
        persistPendingQueue()
        manualOverrideURLs = []
        manualPDFUsesCustomPages = false
        manualPDFPageRangeText = ""
        manualPDFSelectedPages = []

        var convertedResults: [ConversionResult] = []
        for url in urls {
            if Task.isCancelled {
                break
            }

            let singleResults = await service.convert(urls: [url])
            for singleResult in singleResults {
                apply(result: singleResult)
            }
            convertedResults.append(contentsOf: singleResults)
            completedConversionCount += 1
            statusMessage = AppStrings.convertingProgress(
                completed: completedConversionCount,
                total: totalConversionCount
            )
        }

        results = convertedResults
        selectedResultURL = convertedResults.last?.outputURL ?? convertedResults.last?.originalURL

        if Task.isCancelled {
            let remainingURLs = Array(urls.dropFirst(completedConversionCount))
            pendingURLs = remainingURLs
            selectedPendingURL = remainingURLs.first
            state = remainingURLs.isEmpty ? .finished : .queued
            persistPendingQueue()
            statusMessage = AppStrings.conversionCancelled(
                completed: completedConversionCount,
                total: totalConversionCount
            )
            conversionTask = nil
            return
        }

        state = .finished
        statusMessage = makeStatusMessage(results: convertedResults)
        conversionTask = nil
        persistResultHistory(appending: convertedResults)
        openOutputFoldersIfNeeded(for: convertedResults)
        await notificationManager.notify(for: convertedResults)
    }

    private func beginManualOverride(with urls: [URL]) {
        manualOverrideURLs = urls
        manualOverrideFormat = settings.outputFormat
        manualPDFUsesCustomPages = false
        manualPDFPageRangeText = ""
        manualPDFSelectedPages = []
        panelMode = .manualOverride
        results = []
        state = .queued
        statusMessage = AppStrings.queuedWaiting(count: urls.count)
    }

    private var manualPDFPageSelection: PDFPageSelection? {
        guard manualOverrideContainsPDF, manualPDFUsesCustomPages else {
            return .all
        }
        guard let pages = PDFPageRangeParser.parse(manualPDFPageRangeText), !pages.isEmpty else {
            return nil
        }
        return .pages(pages)
    }

    private static func discoverSupportedFiles(from urls: [URL]) -> (urls: [URL], rejectedCount: Int) {
        let fileManager = FileManager.default
        var discoveredURLs: [URL] = []
        var rejectedCount = 0

        for url in urls where url.isFileURL {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
                rejectedCount += 1
                continue
            }

            if isDirectory.boolValue {
                guard let enumerator = fileManager.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                ) else {
                    rejectedCount += 1
                    continue
                }

                for case let fileURL as URL in enumerator {
                    guard (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                        continue
                    }
                    if isSupportedFile(fileURL) {
                        discoveredURLs.append(fileURL)
                    } else {
                        rejectedCount += 1
                    }
                }
            } else if isSupportedFile(url) {
                discoveredURLs.append(url)
            } else {
                rejectedCount += 1
            }
        }

        let uniqueURLs = discoveredURLs
            .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
            .reduce(into: [URL]()) { partialResult, url in
                if !partialResult.contains(url) {
                    partialResult.append(url)
                }
            }
        return (uniqueURLs, rejectedCount)
    }

    private static func pageRangeText(for pages: Set<Int>) -> String {
        let sortedPages = pages.sorted()
        guard let firstPage = sortedPages.first else { return "" }

        var ranges: [String] = []
        var rangeStart = firstPage
        var previousPage = firstPage

        for page in sortedPages.dropFirst() {
            if page == previousPage + 1 {
                previousPage = page
                continue
            }
            ranges.append(rangeStart == previousPage ? "\(rangeStart)" : "\(rangeStart)-\(previousPage)")
            rangeStart = page
            previousPage = page
        }

        ranges.append(rangeStart == previousPage ? "\(rangeStart)" : "\(rangeStart)-\(previousPage)")
        return ranges.joined(separator: ", ")
    }

    private func confirmReplaceOriginalBatchIfNeeded(urls: [URL]) -> Bool {
        guard settings.originalFileAction == .replaceOriginal, urls.count > 1 else { return true }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = AppStrings.replaceOriginalBatchConfirmationTitle()
        alert.informativeText = AppStrings.replaceOriginalBatchConfirmationMessage(count: urls.count)
        alert.addButton(withTitle: AppStrings.replaceBatch())
        alert.addButton(withTitle: AppStrings.cancel())
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func openOutputFoldersIfNeeded(for results: [ConversionResult]) {
        guard settings.openOutputFolderAfterConversion else { return }
        let folders = results
            .compactMap { result -> URL? in
                guard result.status == .success, let outputURL = result.outputURL else { return nil }
                return outputURL.deletingLastPathComponent()
            }
            .reduce(into: [URL]()) { partialResult, folder in
                if !partialResult.contains(folder) {
                    partialResult.append(folder)
                }
            }

        for folder in folders {
            NSWorkspace.shared.open(folder)
        }
    }

    private func apply(result: ConversionResult) {
        if let index = results.firstIndex(where: { $0.id == result.id }) {
            results[index] = result
        } else if let processingIndex = results.firstIndex(where: { $0.originalURL == result.originalURL && $0.status == .processing }) {
            results[processingIndex] = result
        } else {
            results.append(result)
        }
    }

    private func extractURLs(from providers: [NSItemProvider]) async -> [URL] {
        var urls: [URL] = []
        for provider in providers {
            if let url = await Self.loadURL(from: provider) {
                urls.append(url)
            }
        }
        return urls
    }

    private static func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    continuation.resume(returning: url)
                    return
                }

                if let url = item as? URL {
                    continuation.resume(returning: url)
                    return
                }

                continuation.resume(returning: nil)
            }
        }
    }

    private func makeStatusMessage(results: [ConversionResult]) -> String {
        let successCount = results.filter { $0.status == .success }.count
        let skippedCount = results.filter { $0.status == .skipped }.count
        let failureCount = results.filter { $0.status == .failure }.count

        let outputFormats = Set(results.compactMap(\.outputFormat))

        switch (successCount, skippedCount, failureCount) {
        case (0, 0, 0):
            return AppStrings.noFilesProcessed()
        case (_, 0, 0) where outputFormats.count == 1:
            return AppStrings.conversionSucceeded(count: successCount, format: outputFormats.first ?? settings.outputFormat)
        case (_, 0, 0):
            return AppStrings.conversionSucceeded(count: successCount)
        case (0, _, 0):
            return AppStrings.conversionSkippedAll(count: skippedCount)
        case (0, _, _):
            return AppStrings.conversionFailedAll(count: failureCount)
        default:
            return AppStrings.conversionPartial(successCount: successCount, skippedCount: skippedCount, failureCount: failureCount)
        }
    }

    private func outputFolders() -> [URL] {
        results
            .compactMap { result -> URL? in
                guard result.status == .success, let outputURL = result.outputURL else { return nil }
                return outputURL.deletingLastPathComponent()
            }
            .reduce(into: [URL]()) { partialResult, folder in
                if !partialResult.contains(folder) {
                    partialResult.append(folder)
                }
            }
    }

    private func predictedBaseName(name: String, pageComponent: String?) -> String {
        switch settings.filenameTemplate {
        case .automatic, .name:
            if let pageComponent {
                return "\(name) - \(pageComponent)"
            }
            return name
        case .convertedName:
            if let pageComponent {
                return "\(name)_converted - \(pageComponent)"
            }
            return "\(name)_converted"
        case .namePage:
            if let pageComponent {
                return "\(name) - \(pageComponent)"
            }
            return name
        }
    }

    private func persistPendingQueue() {
        defaults.set(pendingURLs.map(\.path), forKey: Keys.persistedQueuePaths)
    }

    private func restorePersistedQueue() {
        let paths = defaults.stringArray(forKey: Keys.persistedQueuePaths) ?? []
        let urls = paths.map(URL.init(fileURLWithPath:)).filter { FileManager.default.fileExists(atPath: $0.path) }
        pendingURLs = urls
        restoreResultHistory()
        if urls.isEmpty {
            statusMessage = AppStrings.defaultStatus()
            state = .idle
        } else {
            state = .queued
            statusMessage = AppStrings.queuedWaiting(count: urls.count)
        }
        if urls.count != paths.count {
            persistPendingQueue()
        }
    }

    private func persistResultHistory(appending newResults: [ConversionResult]? = nil) {
        let sourceResults = newResults.map { restoredResultHistory() + $0 } ?? results
        let successfulExistingResults = sourceResults.filter { result in
            guard result.status == .success, let outputURL = result.outputURL else { return false }
            return FileManager.default.fileExists(atPath: outputURL.path)
        }
        let uniqueResults = successfulExistingResults.reduce(into: [ConversionResult]()) { partialResult, result in
            partialResult.removeAll { $0.id == result.id }
            partialResult.append(result)
        }
        let trimmedResults = Array(uniqueResults.suffix(50))
        if let data = try? JSONEncoder().encode(trimmedResults) {
            defaults.set(data, forKey: Keys.persistedResultHistory)
        }
    }

    private func restoreResultHistory() {
        results = restoredResultHistory()
        selectedResultURL = results.last?.outputURL ?? results.last?.originalURL
    }

    private func restoredResultHistory() -> [ConversionResult] {
        guard let data = defaults.data(forKey: Keys.persistedResultHistory),
              let decodedResults = try? JSONDecoder().decode([ConversionResult].self, from: data) else {
            return []
        }
        return decodedResults.filter { result in
            guard let outputURL = result.outputURL else { return false }
            return FileManager.default.fileExists(atPath: outputURL.path)
        }
    }

    private static func isSupportedFile(_ url: URL) -> Bool {
        SupportedFileTypes.isSupported(url)
    }

    private static func pdfPageCount(for url: URL) -> Int? {
        guard url.pathExtension.caseInsensitiveCompare("pdf") == .orderedSame,
              let document = CGPDFDocument(url as CFURL) else {
            return nil
        }
        return document.numberOfPages
    }

    private func observeSettings() {
        settingsCancellable = settings.$autoConvert
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] isEnabled in
                guard let self, isEnabled else { return }
                guard !self.pendingURLs.isEmpty, self.state != .processing else { return }
                self.statusMessage = AppStrings.queuedStarting(count: self.pendingURLs.count)
                self.convertPending()
            }
    }

    private func showUndoToast(message: String, scope: UndoScope, action: UndoAction) {
        dismissUndoToast(clearAction: true)
        undoAction = action
        let toast = UndoToast(message: message, scope: scope)
        undoToast = toast
        undoDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            await MainActor.run {
                guard let self, self.undoToast?.id == toast.id else { return }
                self.dismissUndoToast(clearAction: true)
            }
        }
    }

    private func dismissUndoToast(clearAction: Bool) {
        undoDismissTask?.cancel()
        undoDismissTask = nil
        undoToast = nil
        if clearAction {
            undoAction = nil
        }
    }
}
