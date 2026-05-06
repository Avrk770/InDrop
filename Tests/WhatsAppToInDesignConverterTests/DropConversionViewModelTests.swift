import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import WhatsAppToInDesignConverter

@MainActor
final class DropConversionViewModelTests: XCTestCase {
    func testSettingsStoreRestoresOriginalFileActionPreference() throws {
        let defaults = try isolatedDefaults()
        defaults.set(AppPreferences.OriginalFileAction.replaceOriginal.rawValue, forKey: "settings.originalFileAction")

        let settings = AppSettingsStore(defaults: defaults)

        XCTAssertEqual(settings.originalFileAction, .replaceOriginal)
    }

    func testQueueSkipsUnsupportedFilesBeforeConversion() throws {
        let defaults = try isolatedDefaults()
        let settings = AppSettingsStore(defaults: defaults)
        let viewModel = DropConversionViewModel(settings: settings, defaults: defaults)
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let imageURL = directory.appendingPathComponent("image.png")
        let textURL = directory.appendingPathComponent("notes.txt")
        try writeSolidColorImage(to: imageURL, type: .png)
        try Data("hello".utf8).write(to: textURL)

        viewModel.handleDrop(urls: [imageURL, textURL])

        XCTAssertEqual(viewModel.pendingURLs, [imageURL])
        XCTAssertTrue(viewModel.statusMessage.localizedCaseInsensitiveContains("skipped"))
    }

    func testDirectFormatChoiceStartsManualOverrideWithRequestedFormat() throws {
        let defaults = try isolatedDefaults()
        let settings = AppSettingsStore(defaults: defaults)
        let viewModel = DropConversionViewModel(settings: settings, defaults: defaults)
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let imageURL = directory.appendingPathComponent("image.png")
        try writeSolidColorImage(to: imageURL, type: .png)

        viewModel.handleDrop(urls: [imageURL])
        viewModel.prepareManualConversionFromQueuedFiles(format: .jpeg)

        XCTAssertEqual(viewModel.panelMode, .manualOverride)
        XCTAssertEqual(viewModel.manualOverrideFormat, .jpeg)
        XCTAssertEqual(viewModel.manualOverrideURLs, [imageURL])
    }

    func testQueueAcceptsJFIFFile() throws {
        let defaults = try isolatedDefaults()
        let settings = AppSettingsStore(defaults: defaults)
        let viewModel = DropConversionViewModel(settings: settings, defaults: defaults)
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let jfifURL = directory.appendingPathComponent("image.jfif")
        try writeSolidColorImage(to: jfifURL, type: .jpeg)

        viewModel.handleDrop(urls: [jfifURL])

        XCTAssertEqual(viewModel.pendingURLs, [jfifURL])
    }

    func testQueueAcceptsCommonImageExtensions() throws {
        let defaults = try isolatedDefaults()
        let settings = AppSettingsStore(defaults: defaults)
        let viewModel = DropConversionViewModel(settings: settings, defaults: defaults)
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let urls = ["webp", "heic", "heif", "tiff", "bmp", "gif"].map { extensionName in
            directory.appendingPathComponent("image.\(extensionName)")
        }

        for url in urls {
            try Data("placeholder".utf8).write(to: url)
        }

        viewModel.handleDrop(urls: urls)

        XCTAssertEqual(viewModel.pendingURLs, urls.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending })
    }

    func testQueueExpandsFoldersRecursively() throws {
        let defaults = try isolatedDefaults()
        let settings = AppSettingsStore(defaults: defaults)
        let viewModel = DropConversionViewModel(settings: settings, defaults: defaults)
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let nestedDirectory = directory.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nestedDirectory, withIntermediateDirectories: true)

        let firstImageURL = directory.appendingPathComponent("a.png")
        let secondImageURL = nestedDirectory.appendingPathComponent("b.jpg")
        let unsupportedURL = nestedDirectory.appendingPathComponent("notes.txt")
        try writeSolidColorImage(to: firstImageURL, type: .png)
        try writeSolidColorImage(to: secondImageURL, type: .jpeg)
        try Data("hello".utf8).write(to: unsupportedURL)

        viewModel.handleDrop(urls: [directory])

        XCTAssertEqual(
            viewModel.pendingURLs.map { $0.standardizedFileURL },
            [firstImageURL.standardizedFileURL, secondImageURL.standardizedFileURL]
        )
        XCTAssertTrue(viewModel.statusMessage.localizedCaseInsensitiveContains("skipped"))
    }
}

private func isolatedDefaults() throws -> UserDefaults {
    let suiteName = "InDropTests.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        throw NSError(domain: "InDropTests", code: 1)
    }
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}

private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func writeSolidColorImage(to url: URL, type: UTType) throws {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(
        data: nil,
        width: 4,
        height: 4,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(NSColor.systemBlue.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
    let image = context.makeImage()!

    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else {
        throw NSError(domain: "InDropTests", code: 2)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "InDropTests", code: 3)
    }
}
