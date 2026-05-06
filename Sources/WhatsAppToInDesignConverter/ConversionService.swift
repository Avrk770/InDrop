import CoreGraphics
import Foundation
import ImageIO
import AppKit
import UniformTypeIdentifiers

enum ConversionServiceError: LocalizedError {
    case unsupportedFile(URL)
    case failedToCreateImage(URL)
    case failedToWriteImage(URL, AppPreferences.OutputFormat)
    case replaceFailed(URL)
    case outputAlreadyExists(URL)

    var errorDescription: String? {
        switch self {
        case .unsupportedFile(let url):
            AppStrings.unsupportedFile(filename: url.lastPathComponent)
        case .failedToCreateImage(let url):
            AppStrings.failedToDecode(filename: url.lastPathComponent)
        case .failedToWriteImage(let url, let format):
            AppStrings.failedToWrite(filename: url.lastPathComponent, format: format)
        case .replaceFailed(let url):
            AppStrings.failedToReplace(filename: url.lastPathComponent)
        case .outputAlreadyExists(let url):
            AppStrings.outputAlreadyExists(filename: url.lastPathComponent)
        }
    }
}

struct ConversionService: Sendable {
    let preferences: AppPreferences
    let overrideFormat: AppPreferences.OutputFormat?
    let pdfPageSelection: PDFPageSelection

    init(
        preferences: AppPreferences = .default,
        overrideFormat: AppPreferences.OutputFormat? = nil,
        pdfPageSelection: PDFPageSelection = .all
    ) {
        self.preferences = preferences
        self.overrideFormat = overrideFormat
        self.pdfPageSelection = pdfPageSelection
    }

    private struct SourceImage {
        let image: CGImage
        let pageNumber: Int?
        let pageCount: Int
    }

    func convert(urls: [URL], onUpdate: (@Sendable (ConversionResult) async -> Void)? = nil) async -> [ConversionResult] {
        await withTaskGroup(of: [ConversionResult].self) { group in
            for url in urls {
                group.addTask {
                    await convertSingle(url: url)
                }
            }

            var results: [ConversionResult] = []
            for await batchResults in group {
                results.append(contentsOf: batchResults)
                if let onUpdate {
                    for result in batchResults {
                        await onUpdate(result)
                    }
                }
            }
            return results.sorted {
                ($0.outputURL ?? $0.originalURL).lastPathComponent.localizedStandardCompare(($1.outputURL ?? $1.originalURL).lastPathComponent) == .orderedAscending
            }
        }
    }

    private func convertSingle(url: URL) async -> [ConversionResult] {
        do {
            let outputFormat = try resolvedOutputFormat(for: url)
            let outputURLs = try convertSyncResults(url: url, resolvedOutputFormat: outputFormat)
            return outputURLs.map { outputURL in
                ConversionResult(originalURL: url, outputURL: outputURL, outputFormat: outputFormat, status: .success, errorMessage: nil)
            }
        } catch {
            if case ConversionServiceError.outputAlreadyExists(let existingURL) = error {
                return [ConversionResult(
                    originalURL: url,
                    outputURL: existingURL,
                    outputFormat: try? resolvedOutputFormat(for: url),
                    status: .skipped,
                    errorMessage: error.localizedDescription
                )]
            }
            return [ConversionResult(
                originalURL: url,
                outputURL: nil,
                outputFormat: nil,
                status: .failure,
                errorMessage: error.localizedDescription
            )]
        }
    }

    func convertSync(url: URL) throws -> URL {
        let outputFormat = try resolvedOutputFormat(for: url)
        return try convertSyncResults(url: url, resolvedOutputFormat: outputFormat).first ?? destinationURL(for: url, outputFormat: outputFormat)
    }

    func convertSyncResults(url: URL) throws -> [URL] {
        let outputFormat = try resolvedOutputFormat(for: url)
        return try convertSyncResults(url: url, resolvedOutputFormat: outputFormat)
    }

    private func convertSyncResults(url: URL, resolvedOutputFormat: AppPreferences.OutputFormat) throws -> [URL] {
        let fileManager = FileManager.default
        let images = try makeImages(from: url)
        var outputURLs: [URL] = []

        for imageIndex in images.indices {
            let sourceImage = images[imageIndex]
            let destinationURL = destinationURL(
                for: url,
                outputFormat: resolvedOutputFormat,
                pageIndex: sourceImage.pageNumber,
                pageCount: sourceImage.pageCount
            )
            try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let tempURL = temporaryURL(for: destinationURL)

            defer {
                try? fileManager.removeItem(at: tempURL)
            }

            try writeImage(image: sourceImage.image, to: tempURL, outputFormat: resolvedOutputFormat)
            try validateWrittenImage(at: tempURL)
            let finalURL = try finalizeOutput(originalURL: url, tempURL: tempURL, destinationURL: destinationURL, isLastOutputForOriginal: imageIndex == images.indices.last)
            outputURLs.append(finalURL)
        }

        return outputURLs
    }

    private func makeImages(from url: URL) throws -> [SourceImage] {
        if FileTypeDetector.detect(url) == .pdf {
            return try renderPagesOfPDF(at: url)
        }

        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw ConversionServiceError.unsupportedFile(url)
        }

        guard let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw ConversionServiceError.failedToCreateImage(url)
        }

        return [SourceImage(image: image, pageNumber: nil, pageCount: 1)]
    }

    private func renderPagesOfPDF(at url: URL) throws -> [SourceImage] {
        guard let document = CGPDFDocument(url as CFURL), document.numberOfPages > 0 else {
            throw ConversionServiceError.failedToCreateImage(url)
        }

        let selectedPages = pdfPageSelection.resolvedPages(totalPages: document.numberOfPages)
        guard !selectedPages.isEmpty else {
            throw ConversionServiceError.failedToCreateImage(url)
        }

        return try selectedPages.map { pageNumber in
            guard let page = document.page(at: pageNumber) else {
                throw ConversionServiceError.failedToCreateImage(url)
            }
            return SourceImage(
                image: try renderPDFPage(page, sourceURL: url),
                pageNumber: document.numberOfPages > 1 ? pageNumber : nil,
                pageCount: document.numberOfPages
            )
        }
    }

    private func renderPDFPage(_ page: CGPDFPage, sourceURL url: URL) throws -> CGImage {
        let pageRect = page.getBoxRect(.mediaBox)
        let renderRect = pageRect.isEmpty ? CGRect(x: 0, y: 0, width: 1, height: 1) : pageRect.integral
        let width = max(Int(renderRect.width), 1)
        let height = max(Int(renderRect.height), 1)

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
            throw ConversionServiceError.failedToCreateImage(url)
        }

        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        context.interpolationQuality = .high
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.drawPDFPage(page)

        guard let image = context.makeImage() else {
            throw ConversionServiceError.failedToCreateImage(url)
        }

        return image
    }

    private func writeImage(image: CGImage, to destinationURL: URL, outputFormat: AppPreferences.OutputFormat) throws {
        let typeIdentifier: CFString
        switch outputFormat {
        case .jpeg:
            typeIdentifier = UTType.jpeg.identifier as CFString
        case .png:
            typeIdentifier = UTType.png.identifier as CFString
        }

        guard let destination = CGImageDestinationCreateWithURL(
            destinationURL as CFURL,
            typeIdentifier,
            1,
            nil
        ) else {
            throw ConversionServiceError.failedToWriteImage(destinationURL, outputFormat)
        }

        let options: CFDictionary?
        if outputFormat == .jpeg {
            options = [
                kCGImageDestinationLossyCompressionQuality: effectiveJPEGQuality
            ] as CFDictionary
        } else {
            options = nil
        }

        CGImageDestinationAddImage(destination, image, options)

        guard CGImageDestinationFinalize(destination) else {
            throw ConversionServiceError.failedToWriteImage(destinationURL, outputFormat)
        }
    }

    private func validateWrittenImage(at url: URL) throws {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(imageSource) > 0 else {
            throw ConversionServiceError.failedToCreateImage(url)
        }
    }

    private var effectiveJPEGQuality: Double {
        preferences.jpegQuality
    }

    private func finalizeOutput(originalURL: URL, tempURL: URL, destinationURL: URL, isLastOutputForOriginal: Bool) throws -> URL {
        switch preferences.originalFileAction {
        case .replaceOriginal:
            return try replaceOriginal(at: originalURL, withConvertedFileAt: tempURL, destinationURL: destinationURL, shouldTrashOriginal: isLastOutputForOriginal)
        case .backupOriginal:
            return try backupOriginal(at: originalURL, withConvertedFileAt: tempURL, destinationURL: destinationURL, shouldBackupOriginal: isLastOutputForOriginal)
        case .keepOriginal:
            return try keepOriginal(at: originalURL, withConvertedFileAt: tempURL, destinationURL: destinationURL)
        }
    }

    private func replaceOriginal(at originalURL: URL, withConvertedFileAt tempURL: URL, destinationURL: URL, shouldTrashOriginal: Bool) throws -> URL {
        let fileManager = FileManager.default
        do {
            var trashedURL: NSURL?
            if originalURL.standardizedFileURL == destinationURL.standardizedFileURL {
                try fileManager.trashItem(at: originalURL, resultingItemURL: &trashedURL)
                try fileManager.moveItem(at: tempURL, to: originalURL)
                return originalURL
            }

            let outputURL = try resolvedAvailableDestinationURL(
                originalURL: originalURL,
                preferredURL: destinationURL,
                suffix: "_converted"
            )
            if fileManager.fileExists(atPath: outputURL.path) {
                try fileManager.removeItem(at: outputURL)
            }

            try fileManager.moveItem(at: tempURL, to: outputURL)
            if shouldTrashOriginal, fileManager.fileExists(atPath: originalURL.path) {
                try fileManager.trashItem(at: originalURL, resultingItemURL: &trashedURL)
            }
            return outputURL
        } catch {
            if let conversionError = error as? ConversionServiceError {
                throw conversionError
            }
            throw ConversionServiceError.replaceFailed(originalURL)
        }
    }

    private func backupOriginal(at originalURL: URL, withConvertedFileAt tempURL: URL, destinationURL: URL, shouldBackupOriginal: Bool) throws -> URL {
        let fileManager = FileManager.default
        do {
            let outputURL = originalURL.standardizedFileURL == destinationURL.standardizedFileURL
                ? originalURL
                : try resolvedAvailableDestinationURL(
                    originalURL: originalURL,
                    preferredURL: destinationURL,
                    suffix: "_converted"
                )

            if shouldBackupOriginal, fileManager.fileExists(atPath: originalURL.path) {
                let backupURL = uniqueBackupURL(for: originalURL)
                try fileManager.createDirectory(at: backupURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fileManager.moveItem(at: originalURL, to: backupURL)
            }

            if fileManager.fileExists(atPath: outputURL.path) {
                try fileManager.removeItem(at: outputURL)
            }

            try fileManager.moveItem(at: tempURL, to: outputURL)
            return outputURL
        } catch {
            if let conversionError = error as? ConversionServiceError {
                throw conversionError
            }
            throw ConversionServiceError.replaceFailed(originalURL)
        }
    }

    private func keepOriginal(at originalURL: URL, withConvertedFileAt tempURL: URL, destinationURL: URL) throws -> URL {
        let fileManager = FileManager.default
        let finalURL = try resolvedAvailableDestinationURL(
            originalURL: originalURL,
            preferredURL: destinationURL,
            suffix: "_converted"
        )

        do {
            if fileManager.fileExists(atPath: finalURL.path) {
                try fileManager.removeItem(at: finalURL)
            }
            try fileManager.moveItem(at: tempURL, to: finalURL)
        } catch {
            if let conversionError = error as? ConversionServiceError {
                throw conversionError
            }
            throw ConversionServiceError.replaceFailed(originalURL)
        }

        return finalURL
    }

    private func destinationURL(for originalURL: URL, outputFormat: AppPreferences.OutputFormat, pageIndex: Int? = nil, pageCount: Int = 1) -> URL {
        let outputDirectory = outputDirectory(for: originalURL)
        let baseName = outputBaseName(
            for: originalURL,
            pageIndex: pageIndex,
            pageCount: pageCount
        )
        return outputDirectory
            .appendingPathComponent(baseName)
            .appendingPathExtension(outputFormat.fileExtension)
    }

    private func outputDirectory(for originalURL: URL) -> URL {
        if preferences.outputLocation == .customFolder,
           let customOutputFolderPath = preferences.customOutputFolderPath,
           !customOutputFolderPath.isEmpty {
            return URL(fileURLWithPath: customOutputFolderPath, isDirectory: true)
        }

        let sourceDirectory = originalURL.deletingLastPathComponent()
        if preferences.outputLocation == .convertedFolder {
            return sourceDirectory.appendingPathComponent("Converted", isDirectory: true)
        }
        return sourceDirectory
    }

    private func outputBaseName(for originalURL: URL, pageIndex: Int?, pageCount: Int) -> String {
        let name = originalURL.deletingPathExtension().lastPathComponent
        let pageComponent = pageIndex.map {
            AppStrings.pageFilenameComponent(page: $0, total: pageCount, language: preferences.language)
        }

        switch preferences.filenameTemplate {
        case .automatic:
            if let pageComponent {
                return name + " - " + pageComponent
            }
            return name
        case .name:
            if let pageComponent {
                return name + " - " + pageComponent
            }
            return name
        case .convertedName:
            if let pageComponent {
                return name + "_converted - " + pageComponent
            }
            return name + "_converted"
        case .namePage:
            if let pageComponent {
                return name + " - " + pageComponent
            }
            return name
        }
    }

    private func resolvedAvailableDestinationURL(originalURL: URL, preferredURL: URL, suffix: String) throws -> URL {
        let fileManager = FileManager.default
        let preferredURL = preferredURL.standardizedFileURL == originalURL.standardizedFileURL
            ? destinationURLWithSuffix(preferredURL, suffix: suffix)
            : preferredURL

        guard fileManager.fileExists(atPath: preferredURL.path) else {
            return preferredURL
        }

        switch preferences.existingFileAction {
        case .addNumber:
            return uniqueDestinationURL(preferredURL: preferredURL)
        case .replace:
            return preferredURL
        case .skip:
            throw ConversionServiceError.outputAlreadyExists(preferredURL)
        }
    }

    private func destinationURLWithSuffix(_ url: URL, suffix: String) -> URL {
        url.deletingPathExtension()
            .deletingLastPathComponent()
            .appendingPathComponent(url.deletingPathExtension().lastPathComponent + suffix)
            .appendingPathExtension(url.pathExtension)
    }

    private func uniqueDestinationURL(preferredURL: URL) -> URL {
        let fileManager = FileManager.default
        let directory = preferredURL.deletingLastPathComponent()
        let extensionName = preferredURL.pathExtension
        let baseName = preferredURL.deletingPathExtension().lastPathComponent

        var candidate = directory.appendingPathComponent(baseName).appendingPathExtension(extensionName)

        var copyIndex = 2
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = directory
                .appendingPathComponent("\(baseName)-\(copyIndex)")
                .appendingPathExtension(extensionName)
            copyIndex += 1
        }
        return candidate
    }

    private func uniqueBackupURL(for originalURL: URL) -> URL {
        let backupDirectory = originalURL.deletingLastPathComponent().appendingPathComponent("InDrop Backups", isDirectory: true)
        var candidate = backupDirectory.appendingPathComponent(originalURL.lastPathComponent)
        var copyIndex = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            let baseName = originalURL.deletingPathExtension().lastPathComponent
            candidate = backupDirectory
                .appendingPathComponent("\(baseName)-\(copyIndex)")
                .appendingPathExtension(originalURL.pathExtension)
            copyIndex += 1
        }
        return candidate
    }

    private func temporaryURL(for destinationURL: URL) -> URL {
        let filename = ".\(UUID().uuidString)-\(destinationURL.lastPathComponent)"
        return destinationURL.deletingLastPathComponent().appendingPathComponent(filename)
    }

    private func resolvedOutputFormat(for url: URL) throws -> AppPreferences.OutputFormat {
        if let overrideFormat {
            return overrideFormat
        }

        switch FileTypeDetector.detect(url) {
        case .pdf:
            return preferences.outputFormat
        case .image(.jpeg):
            return .jpeg
        case .image(.png):
            return .png
        case .image:
            return preferences.outputFormat
        case nil:
            throw ConversionServiceError.unsupportedFile(url)
        }
    }

    static func suggestedOutputFormat(for url: URL, preferences: AppPreferences, overrideFormat: AppPreferences.OutputFormat? = nil) -> AppPreferences.OutputFormat {
        if let overrideFormat {
            return overrideFormat
        }

        switch FileTypeDetector.detect(url) {
        case .pdf:
            return preferences.outputFormat
        case .image(.jpeg):
            return .jpeg
        case .image(.png):
            return .png
        case .image, nil:
            return preferences.outputFormat
        }
    }
}
