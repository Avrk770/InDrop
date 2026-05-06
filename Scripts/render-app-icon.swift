import AppKit
import Foundation

struct IconRenderer {
    let sourceImage: NSImage
    let trimmedSourceImage: CGImage

    func writeIconSet(to outputDirectory: URL) throws {
        let entries: [(name: String, size: Int)] = [
            ("icon_16x16.png", 16),
            ("icon_16x16@2x.png", 32),
            ("icon_32x32.png", 32),
            ("icon_32x32@2x.png", 64),
            ("icon_128x128.png", 128),
            ("icon_128x128@2x.png", 256),
            ("icon_256x256.png", 256),
            ("icon_256x256@2x.png", 512),
            ("icon_512x512.png", 512),
            ("icon_512x512@2x.png", 1024),
        ]

        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        for entry in entries {
            let imageData = try renderPNG(size: entry.size)
            try imageData.write(to: outputDirectory.appendingPathComponent(entry.name))
        }
    }

    private func renderPNG(size: Int) throws -> Data {
        let pixelSize = NSSize(width: size, height: size)
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: size,
            pixelsHigh: size,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw RendererError.bitmapCreationFailed
        }

        bitmap.size = pixelSize

        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            NSGraphicsContext.restoreGraphicsState()
            throw RendererError.contextCreationFailed
        }
        NSGraphicsContext.current = context

        let bounds = CGRect(origin: .zero, size: pixelSize)
        NSColor.clear.setFill()
        bounds.fill()

        let inset = CGFloat(size) * 0.1
        let targetRect = bounds.insetBy(dx: inset, dy: inset)
        NSGraphicsContext.current?.cgContext.draw(trimmedSourceImage, in: targetRect)

        NSGraphicsContext.restoreGraphicsState()

        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw RendererError.pngEncodingFailed
        }
        return data
    }

    enum RendererError: Error {
        case bitmapCreationFailed
        case contextCreationFailed
        case pngEncodingFailed
        case sourceCGImageMissing
        case sourceImageFullyTransparent
    }
}

enum Main {
    static func run() throws {
        guard CommandLine.arguments.count == 3 else {
            throw UsageError.invalidArguments
        }

        let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

        guard let sourceImage = NSImage(contentsOf: sourceURL) else {
            throw UsageError.couldNotLoadSource
        }

        let renderer = try IconRenderer(sourceImage: sourceImage, trimmedSourceImage: trimTransparentBounds(from: sourceImage))
        try renderer.writeIconSet(to: outputURL)
    }

    static func trimTransparentBounds(from image: NSImage) throws -> CGImage {
        var proposedRect = CGRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
            throw IconRenderer.RendererError.sourceCGImageMissing
        }

        guard let dataProvider = cgImage.dataProvider,
              let pixelData = dataProvider.data,
              let bytes = CFDataGetBytePtr(pixelData) else {
            throw IconRenderer.RendererError.sourceCGImageMissing
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = cgImage.bytesPerRow
        let alphaInfo = cgImage.alphaInfo

        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * 4
                let alpha: UInt8

                switch alphaInfo {
                case .premultipliedFirst, .first, .noneSkipFirst:
                    alpha = bytes[offset]
                case .premultipliedLast, .last, .noneSkipLast:
                    alpha = bytes[offset + 3]
                default:
                    alpha = bytes[offset + 3]
                }

                guard alpha > 0 else { continue }
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard maxX >= minX, maxY >= minY else {
            throw IconRenderer.RendererError.sourceImageFullyTransparent
        }

        let cropRect = CGRect(
            x: minX,
            y: minY,
            width: maxX - minX + 1,
            height: maxY - minY + 1
        )

        guard let croppedImage = cgImage.cropping(to: cropRect) else {
            throw IconRenderer.RendererError.sourceCGImageMissing
        }

        return croppedImage
    }

    enum UsageError: Error, LocalizedError {
        case invalidArguments
        case couldNotLoadSource

        var errorDescription: String? {
            switch self {
            case .invalidArguments:
                return "Usage: render-app-icon.swift <source-png> <output-iconset-dir>"
            case .couldNotLoadSource:
                return "Could not load source PNG."
            }
        }
    }
}

do {
    try Main.run()
} catch {
    FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
    exit(1)
}
