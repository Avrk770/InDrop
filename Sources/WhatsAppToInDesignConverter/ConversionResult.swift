import Foundation

enum ConversionStatus: String, Sendable, Codable {
    case processing
    case success
    case skipped
    case failure
}

struct ConversionResult: Identifiable, Sendable, Codable {
    var id: String {
        [
            originalURL.path,
            outputURL?.path ?? "",
            outputFormat?.rawValue ?? "",
            status.rawValue,
        ].joined(separator: "|")
    }

    let originalURL: URL
    let outputURL: URL?
    let outputFormat: AppPreferences.OutputFormat?
    let status: ConversionStatus
    let errorMessage: String?
}
