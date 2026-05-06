import Foundation
import ImageIO
import UniformTypeIdentifiers

enum DetectedFileType: Equatable {
    case pdf
    case image(DetectedImageType)
}

enum DetectedImageType: Equatable {
    case jpeg
    case png
    case webp
    case heic
    case heif
    case tiff
    case bmp
    case gif
    case other(String)
}

enum FileTypeDetector {
    static let supportedImageExtensions: Set<String> = [
        "jpg", "jpeg", "jfif",
        "png",
        "webp",
        "heic", "heif",
        "tif", "tiff",
        "bmp", "dib",
        "gif",
    ]

    static let supportedImageExtensionList = [
        "jpg", "jpeg", "jfif", "png", "webp", "heic", "heif", "tif", "tiff", "bmp", "gif",
    ]

    static var openPanelContentTypes: [UTType] {
        var types: [UTType] = [.image, .pdf]
        for extensionName in supportedImageExtensionList {
            guard let type = UTType(filenameExtension: extensionName),
                  !types.contains(type) else {
                continue
            }
            types.append(type)
        }
        return types
    }

    static func isSupported(_ url: URL) -> Bool {
        detect(url) != nil
    }

    static func detect(_ url: URL) -> DetectedFileType? {
        guard url.isFileURL else { return nil }
        let extensionName = url.pathExtension.lowercased()
        guard !extensionName.isEmpty else { return nil }

        if extensionName == "pdf" {
            return .pdf
        }

        if supportedImageExtensions.contains(extensionName) {
            return .image(imageTypeForKnownExtension(extensionName, url: url))
        }

        guard let type = UTType(filenameExtension: extensionName),
              type.conforms(to: .image) else {
            return nil
        }

        return .image(imageTypeFromContent(url) ?? .other(type.identifier))
    }

    static func imageTypeFromContent(_ url: URL) -> DetectedImageType? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let sourceType = CGImageSourceGetType(imageSource) as String? else {
            return nil
        }
        return imageType(forIdentifier: sourceType)
    }

    static func imageType(forIdentifier identifier: String) -> DetectedImageType {
        switch identifier {
        case UTType.jpeg.identifier, "public.jpeg", "public.jpeg-2000":
            return .jpeg
        case UTType.png.identifier:
            return .png
        case "org.webmproject.webp", "public.webp":
            return .webp
        case "public.heic":
            return .heic
        case "public.heif":
            return .heif
        case UTType.tiff.identifier:
            return .tiff
        case UTType.bmp.identifier, "com.microsoft.bmp":
            return .bmp
        case UTType.gif.identifier:
            return .gif
        default:
            return .other(identifier)
        }
    }

    private static func imageTypeForKnownExtension(_ extensionName: String, url: URL) -> DetectedImageType {
        if let typeFromContent = imageTypeFromContent(url) {
            return typeFromContent
        }

        switch extensionName {
        case "jpg", "jpeg", "jfif":
            return .jpeg
        case "png":
            return .png
        case "webp":
            return .webp
        case "heic":
            return .heic
        case "heif":
            return .heif
        case "tif", "tiff":
            return .tiff
        case "bmp", "dib":
            return .bmp
        case "gif":
            return .gif
        default:
            return .other(extensionName)
        }
    }
}
