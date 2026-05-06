import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import WhatsAppToInDesignConverter

final class ConversionServiceTests: XCTestCase {
    func testDefaultPreferencesKeepOriginalFiles() {
        XCTAssertEqual(AppPreferences.default.originalFileAction, .keepOriginal)
    }

    func testKeepsPNGAsPNGDuringDefaultReencode() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let sourceURL = directory.appendingPathComponent("sample.png")
        try writeSolidColorImage(to: sourceURL, type: .png)

        let service = ConversionService(
            preferences: AppPreferences(
                outputFormat: .jpeg,
                originalFileAction: .replaceOriginal,
                jpegQuality: 0.9,
                autoConvert: false,
                launchAtLogin: false
            )
        )
        let outputURL = try service.convertSync(url: sourceURL)

        XCTAssertEqual(outputURL.lastPathComponent, "sample.png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertEqual(imageType(at: outputURL), UTType.png.identifier)
    }

    func testSmartReencodeKeepsJPEGAsJPEGEvenWhenDefaultIsPNG() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let sourceURL = directory.appendingPathComponent("sample.jpg")
        try writeSolidColorImage(to: sourceURL, type: .jpeg)

        let service = ConversionService(
            preferences: AppPreferences(
                outputFormat: .png,
                originalFileAction: .replaceOriginal,
                jpegQuality: 0.9,
                autoConvert: false,
                launchAtLogin: false
            )
        )

        let outputURL = try service.convertSync(url: sourceURL)

        XCTAssertEqual(outputURL.pathExtension.lowercased(), "jpg")
        XCTAssertEqual(imageType(at: outputURL), UTType.jpeg.identifier)
    }

    func testJFIFConvertsAsJPEGOutput() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let sourceURL = directory.appendingPathComponent("sample.jfif")
        try writeSolidColorImage(to: sourceURL, type: .jpeg)

        let service = ConversionService(
            preferences: AppPreferences(
                outputFormat: .png,
                originalFileAction: .replaceOriginal,
                jpegQuality: 0.9,
                autoConvert: false,
                launchAtLogin: false
            )
        )

        let outputURL = try service.convertSync(url: sourceURL)

        XCTAssertEqual(outputURL.lastPathComponent, "sample.jpg")
        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertEqual(imageType(at: outputURL), UTType.jpeg.identifier)
    }

    func testSmartReencodeKeepsPNGAsPNGEvenWhenDefaultIsJPEG() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let sourceURL = directory.appendingPathComponent("sample.png")
        try writeSolidColorImage(to: sourceURL, type: .png)

        let service = ConversionService(
            preferences: AppPreferences(
                outputFormat: .jpeg,
                originalFileAction: .replaceOriginal,
                jpegQuality: 0.9,
                autoConvert: false,
                launchAtLogin: false
            )
        )

        let outputURL = try service.convertSync(url: sourceURL)

        XCTAssertEqual(outputURL.pathExtension.lowercased(), "png")
        XCTAssertEqual(imageType(at: outputURL), UTType.png.identifier)
    }

    func testUnsupportedInputFallsBackToConfiguredDefaultFormat() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let sourceURL = directory.appendingPathComponent("sample.tiff")
        try writeSolidColorImage(to: sourceURL, type: .tiff)

        let service = ConversionService(
            preferences: AppPreferences(
                outputFormat: .jpeg,
                originalFileAction: .replaceOriginal,
                jpegQuality: 0.9,
                autoConvert: false,
                launchAtLogin: false
            )
        )

        let outputURL = try service.convertSync(url: sourceURL)

        XCTAssertEqual(outputURL.lastPathComponent, "sample.jpg")
        XCTAssertEqual(imageType(at: outputURL), UTType.jpeg.identifier)
    }

    func testCommonImageFormatsConvertToDefaultJPEG() throws {
        let formats: [(extensionName: String, identifier: String)] = [
            ("tiff", UTType.tiff.identifier),
            ("bmp", UTType.bmp.identifier),
            ("gif", UTType.gif.identifier),
        ]

        for format in formats {
            try assertImageFormatConvertsToJPEG(extensionName: format.extensionName, typeIdentifier: format.identifier)
        }
    }

    func testModernImageFormatsConvertToDefaultJPEGWhenAvailable() throws {
        let formats: [(extensionName: String, identifier: String)] = [
            ("webp", "org.webmproject.webp"),
            ("heic", "public.heic"),
            ("heif", "public.heif"),
        ]

        for format in formats {
            guard canWriteImage(typeIdentifier: format.identifier) else {
                continue
            }
            try assertImageFormatConvertsToJPEG(extensionName: format.extensionName, typeIdentifier: format.identifier)
        }
    }

    func testManualOverrideForcesRequestedOutputFormat() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let sourceURL = directory.appendingPathComponent("sample.jpg")
        try writeSolidColorImage(to: sourceURL, type: .jpeg)

        let service = ConversionService(
            preferences: AppPreferences(
                outputFormat: .jpeg,
                originalFileAction: .replaceOriginal,
                jpegQuality: 0.9,
                autoConvert: false,
                launchAtLogin: false
            ),
            overrideFormat: .png
        )

        let outputURL = try service.convertSync(url: sourceURL)

        XCTAssertEqual(outputURL.lastPathComponent, "sample.png")
        XCTAssertEqual(imageType(at: outputURL), UTType.png.identifier)
    }

    func testPDFUsesConfiguredDefaultOutputFormat() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let sourceURL = directory.appendingPathComponent("sample.pdf")
        try writeSinglePagePDF(to: sourceURL)

        let service = ConversionService(
            preferences: AppPreferences(
                outputFormat: .png,
                originalFileAction: .replaceOriginal,
                jpegQuality: 0.9,
                autoConvert: false,
                launchAtLogin: false
            )
        )

        let outputURL = try service.convertSync(url: sourceURL)

        XCTAssertEqual(outputURL.lastPathComponent, "sample.png")
        XCTAssertEqual(imageType(at: outputURL), UTType.png.identifier)
    }

    func testPDFConvertsEveryPageToSeparateOutputFiles() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let sourceURL = directory.appendingPathComponent("multipage.pdf")
        try writePDF(to: sourceURL, pageCount: 3)

        let service = ConversionService(
            preferences: AppPreferences(
                outputFormat: .jpeg,
                originalFileAction: .keepOriginal,
                jpegQuality: 0.9,
                autoConvert: false,
                launchAtLogin: false
            )
        )

        let outputURLs = try service.convertSyncResults(url: sourceURL)

        XCTAssertEqual(outputURLs.map(\.lastPathComponent), [
            "multipage - Page 01.jpg",
            "multipage - Page 02.jpg",
            "multipage - Page 03.jpg",
        ])
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertTrue(outputURLs.allSatisfy { FileManager.default.fileExists(atPath: $0.path) })
    }

    func testPDFConvertsSelectedPageRangeOnly() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let sourceURL = directory.appendingPathComponent("multipage.pdf")
        try writePDF(to: sourceURL, pageCount: 5)

        let service = ConversionService(
            preferences: AppPreferences(
                outputFormat: .jpeg,
                originalFileAction: .keepOriginal,
                jpegQuality: 0.9,
                autoConvert: false,
                launchAtLogin: false
            ),
            pdfPageSelection: .pages([2, 4, 5])
        )

        let outputURLs = try service.convertSyncResults(url: sourceURL)

        XCTAssertEqual(outputURLs.map(\.lastPathComponent), [
            "multipage - Page 02.jpg",
            "multipage - Page 04.jpg",
            "multipage - Page 05.jpg",
        ])
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
    }

    func testPDFPageRangeParserAcceptsRangesAndSingles() {
        XCTAssertEqual(PDFPageRangeParser.parse("1-3, 7, 10-12"), [1, 2, 3, 7, 10, 11, 12])
        XCTAssertEqual(PDFPageRangeParser.parse("3, 1, 3"), [1, 3])
    }

    func testPDFPageRangeParserRejectsInvalidInput() {
        XCTAssertNil(PDFPageRangeParser.parse(""))
        XCTAssertNil(PDFPageRangeParser.parse("0"))
        XCTAssertNil(PDFPageRangeParser.parse("4-2"))
        XCTAssertNil(PDFPageRangeParser.parse("1,,3"))
        XCTAssertNil(PDFPageRangeParser.parse("abc"))
    }

    func testWritesToCustomOutputFolder() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let outputDirectory = directory.appendingPathComponent("exports", isDirectory: true)
        let sourceURL = directory.appendingPathComponent("sample.tiff")
        try writeSolidColorImage(to: sourceURL, type: .tiff)

        let service = ConversionService(
            preferences: AppPreferences(
                outputFormat: .png,
                outputLocation: .customFolder,
                customOutputFolderPath: outputDirectory.path,
                originalFileAction: .keepOriginal,
                jpegQuality: 0.9,
                autoConvert: false,
                launchAtLogin: false
            )
        )

        let outputURL = try service.convertSync(url: sourceURL)

        XCTAssertEqual(outputURL.deletingLastPathComponent(), outputDirectory)
        XCTAssertEqual(outputURL.lastPathComponent, "sample.png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
    }

    func testWritesToConvertedFolder() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let sourceURL = directory.appendingPathComponent("sample.tiff")
        try writeSolidColorImage(to: sourceURL, type: .tiff)

        let service = ConversionService(
            preferences: AppPreferences(
                outputFormat: .jpeg,
                outputLocation: .convertedFolder,
                originalFileAction: .keepOriginal,
                jpegQuality: 0.9,
                autoConvert: false,
                launchAtLogin: false
            )
        )

        let outputURL = try service.convertSync(url: sourceURL)

        XCTAssertEqual(outputURL.deletingLastPathComponent().lastPathComponent, "Converted")
        XCTAssertEqual(outputURL.lastPathComponent, "sample.jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
    }

    func testFilenameTemplateCanAppendConvertedSuffix() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let sourceURL = directory.appendingPathComponent("sample.png")
        try writeSolidColorImage(to: sourceURL, type: .png)

        let service = ConversionService(
            preferences: AppPreferences(
                outputFormat: .png,
                filenameTemplate: .convertedName,
                originalFileAction: .keepOriginal,
                jpegQuality: 0.9,
                autoConvert: false,
                launchAtLogin: false
            )
        )

        let outputURL = try service.convertSync(url: sourceURL)

        XCTAssertEqual(outputURL.lastPathComponent, "sample_converted.png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
    }

    func testSkipExistingOutputReportsSkippedResult() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let sourceURL = directory.appendingPathComponent("sample.tiff")
        let existingOutputURL = directory.appendingPathComponent("sample.jpg")
        try writeSolidColorImage(to: sourceURL, type: .tiff)
        try writeSolidColorImage(to: existingOutputURL, type: .jpeg)

        let service = ConversionService(
            preferences: AppPreferences(
                outputFormat: .jpeg,
                existingFileAction: .skip,
                originalFileAction: .keepOriginal,
                jpegQuality: 0.9,
                autoConvert: false,
                launchAtLogin: false
            )
        )

        let results = await service.convert(urls: [sourceURL])

        XCTAssertEqual(results.first?.status, .skipped)
        XCTAssertEqual(results.first?.outputURL, existingOutputURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
    }

    func testBackupOriginalMovesSourceIntoBackupFolder() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let sourceURL = directory.appendingPathComponent("sample.jpg")
        try writeSolidColorImage(to: sourceURL, type: .jpeg)

        let service = ConversionService(
            preferences: AppPreferences(
                outputFormat: .jpeg,
                originalFileAction: .backupOriginal,
                jpegQuality: 0.9,
                autoConvert: false,
                launchAtLogin: false
            )
        )

        let outputURL = try service.convertSync(url: sourceURL)
        let backupURL = directory.appendingPathComponent("InDrop Backups", isDirectory: true).appendingPathComponent("sample.jpg")

        XCTAssertEqual(outputURL, sourceURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupURL.path))
    }

    func testRewritesExistingJPEGInPlace() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let sourceURL = directory.appendingPathComponent("sample.jpg")
        try writeSolidColorImage(to: sourceURL, type: .jpeg)

        let service = ConversionService(
            preferences: AppPreferences(
                outputFormat: .jpeg,
                originalFileAction: .replaceOriginal,
                jpegQuality: 0.9,
                autoConvert: false,
                launchAtLogin: false
            )
        )
        let outputURL = try service.convertSync(url: sourceURL)

        XCTAssertEqual(outputURL, sourceURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertEqual(imageType(at: sourceURL), UTType.jpeg.identifier)
    }

    func testKeepsOriginalWhenConfiguredToDoSo() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let sourceURL = directory.appendingPathComponent("sample.jpg")
        try writeSolidColorImage(to: sourceURL, type: .jpeg)

        let service = ConversionService(
            preferences: AppPreferences(
                outputFormat: .jpeg,
                originalFileAction: .keepOriginal,
                jpegQuality: 0.9,
                autoConvert: false,
                launchAtLogin: false
            )
        )

        let outputURL = try service.convertSync(url: sourceURL)

        XCTAssertEqual(outputURL.lastPathComponent, "sample_converted.jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
    }

    func testDefaultReencodeKeepsJPEGFormatEvenWhenDefaultSettingIsPNG() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let sourceURL = directory.appendingPathComponent("sample.jpg")
        try writeSolidColorImage(to: sourceURL, type: .jpeg)

        let service = ConversionService(
            preferences: AppPreferences(
                outputFormat: .png,
                originalFileAction: .replaceOriginal,
                jpegQuality: 0.9,
                autoConvert: false,
                launchAtLogin: false
            )
        )

        let outputURL = try service.convertSync(url: sourceURL)

        XCTAssertEqual(outputURL.lastPathComponent, "sample.jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertEqual(imageType(at: outputURL), UTType.jpeg.identifier)
    }

    func testFailsForUnsupportedFiles() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let sourceURL = directory.appendingPathComponent("notes.txt")
        try Data("hello".utf8).write(to: sourceURL)

        let service = ConversionService()

        XCTAssertThrowsError(try service.convertSync(url: sourceURL)) { error in
            XCTAssertTrue(error is ConversionServiceError)
        }
    }
}

private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func writeSolidColorImage(to url: URL, type: UTType) throws {
    try writeSolidColorImage(to: url, typeIdentifier: type.identifier)
}

private func writeSolidColorImage(to url: URL, typeIdentifier: String) throws {
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

    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, typeIdentifier as CFString, 1, nil) else {
        throw NSError(domain: "test", code: 1)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "test", code: 2)
    }
}

private func assertImageFormatConvertsToJPEG(extensionName: String, typeIdentifier: String) throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    let sourceURL = directory.appendingPathComponent("sample.\(extensionName)")
    try writeSolidColorImage(to: sourceURL, typeIdentifier: typeIdentifier)

    let service = ConversionService(
        preferences: AppPreferences(
            outputFormat: .jpeg,
            originalFileAction: .replaceOriginal,
            jpegQuality: 0.9,
            autoConvert: false,
            launchAtLogin: false
        )
    )

    let outputURL = try service.convertSync(url: sourceURL)

    XCTAssertEqual(outputURL.lastPathComponent, "sample.jpg")
    XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
    XCTAssertEqual(imageType(at: outputURL), UTType.jpeg.identifier)
}

private func canWriteImage(typeIdentifier: String) -> Bool {
    let identifiers = CGImageDestinationCopyTypeIdentifiers() as NSArray
    return identifiers.contains(typeIdentifier)
}

private func imageType(at url: URL) -> String? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let type = CGImageSourceGetType(source) else {
        return nil
    }
    return type as String
}

private func writeSinglePagePDF(to url: URL) throws {
    try writePDF(to: url, pageCount: 1)
}

private func writePDF(to url: URL, pageCount: Int) throws {
    var mediaBox = CGRect(x: 0, y: 0, width: 40, height: 40)
    guard let consumer = CGDataConsumer(url: url as CFURL),
          let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
        throw NSError(domain: "test", code: 3)
    }

    for pageIndex in 0..<pageCount {
        context.beginPDFPage(nil)
        context.setFillColor(pageIndex.isMultiple(of: 2) ? NSColor.systemRed.cgColor : NSColor.systemGreen.cgColor)
        context.fill(CGRect(x: 4, y: 4, width: 32, height: 32))
        context.endPDFPage()
    }
    context.closePDF()
}
