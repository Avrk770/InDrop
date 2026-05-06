import Foundation

struct AppPreferences: Sendable {
    enum Language: String, CaseIterable, Sendable, Identifiable, Codable {
        case english
        case hebrew

        var id: String { rawValue }

        var localeIdentifier: String {
            switch self {
            case .english:
                "en"
            case .hebrew:
                "he"
            }
        }

        var title: String {
            switch self {
            case .english:
                "English"
            case .hebrew:
                "עברית"
            }
        }
    }

    enum OutputFormat: String, CaseIterable, Sendable, Identifiable, Codable {
        case jpeg
        case png

        var id: String { rawValue }

        func title(in language: Language = .english) -> String {
            switch (self, language) {
            case (.jpeg, .hebrew):
                "JPEG"
            case (.png, .hebrew):
                "PNG"
            case (.jpeg, _):
                "JPEG"
            case (.png, _):
                "PNG"
            }
        }

        var fileExtension: String {
            switch self {
            case .jpeg:
                "jpg"
            case .png:
                "png"
            }
        }
    }

    enum OriginalFileAction: String, CaseIterable, Sendable, Identifiable, Codable {
        case keepOriginal
        case backupOriginal
        case replaceOriginal

        var id: String { rawValue }

        func title(in language: Language = .english) -> String {
            switch (self, language) {
            case (.keepOriginal, .hebrew):
                "השאר מקור"
            case (.backupOriginal, .hebrew):
                "גבה מקור"
            case (.replaceOriginal, .hebrew):
                "החלף מקור"
            case (.keepOriginal, _):
                "Keep original"
            case (.backupOriginal, _):
                "Backup original"
            case (.replaceOriginal, _):
                "Replace original"
            }
        }

    }

    enum OutputLocation: String, CaseIterable, Sendable, Identifiable, Codable {
        case sameFolder
        case convertedFolder
        case customFolder

        var id: String { rawValue }

        func title(in language: Language = .english) -> String {
            switch (self, language) {
            case (.sameFolder, .hebrew):
                "ליד המקור"
            case (.convertedFolder, .hebrew):
                "תיקיית Converted"
            case (.customFolder, .hebrew):
                "תיקייה נבחרת"
            case (.sameFolder, _):
                "Same folder"
            case (.convertedFolder, _):
                "Converted folder"
            case (.customFolder, _):
                "Chosen folder"
            }
        }
    }

    enum FilenameTemplate: String, CaseIterable, Sendable, Identifiable, Codable {
        case automatic
        case name
        case convertedName
        case namePage

        var id: String { rawValue }

        func title(in language: Language = .english) -> String {
            switch (self, language) {
            case (.automatic, .hebrew):
                "אוטומטי"
            case (.name, .hebrew):
                "{name}"
            case (.convertedName, .hebrew):
                "{name}_converted"
            case (.namePage, .hebrew):
                "{name} - Page {page}"
            case (.automatic, _):
                "Automatic"
            case (.name, _):
                "{name}"
            case (.convertedName, _):
                "{name}_converted"
            case (.namePage, _):
                "{name} - Page {page}"
            }
        }
    }

    enum ExistingFileAction: String, CaseIterable, Sendable, Identifiable, Codable {
        case addNumber
        case replace
        case skip

        var id: String { rawValue }

        func title(in language: Language = .english) -> String {
            switch (self, language) {
            case (.addNumber, .hebrew):
                "הוסף מספר"
            case (.replace, .hebrew):
                "החלף"
            case (.skip, .hebrew):
                "דלג"
            case (.addNumber, _):
                "Add number"
            case (.replace, _):
                "Replace"
            case (.skip, _):
                "Skip"
            }
        }
    }

    let language: Language
    let outputFormat: OutputFormat
    let outputLocation: OutputLocation
    let customOutputFolderPath: String?
    let filenameTemplate: FilenameTemplate
    let existingFileAction: ExistingFileAction
    let originalFileAction: OriginalFileAction
    let jpegQuality: Double
    let autoConvert: Bool
    let openOutputFolderAfterConversion: Bool
    let launchAtLogin: Bool

    init(
        language: Language = AppPreferences.defaultLanguage,
        outputFormat: OutputFormat,
        outputLocation: OutputLocation = .sameFolder,
        customOutputFolderPath: String? = nil,
        filenameTemplate: FilenameTemplate = .automatic,
        existingFileAction: ExistingFileAction = .addNumber,
        originalFileAction: OriginalFileAction,
        jpegQuality: Double,
        autoConvert: Bool,
        openOutputFolderAfterConversion: Bool = false,
        launchAtLogin: Bool
    ) {
        self.language = language
        self.outputFormat = outputFormat
        self.outputLocation = outputLocation
        self.customOutputFolderPath = customOutputFolderPath
        self.filenameTemplate = filenameTemplate
        self.existingFileAction = existingFileAction
        self.originalFileAction = originalFileAction
        self.jpegQuality = jpegQuality
        self.autoConvert = autoConvert
        self.openOutputFolderAfterConversion = openOutputFolderAfterConversion
        self.launchAtLogin = launchAtLogin
    }

    static var defaultLanguage: Language {
        .english
    }

    static var `default`: AppPreferences {
        AppPreferences(
            language: defaultLanguage,
            outputFormat: .jpeg,
            outputLocation: .sameFolder,
            customOutputFolderPath: nil,
            filenameTemplate: .automatic,
            existingFileAction: .addNumber,
            originalFileAction: .keepOriginal,
            jpegQuality: 0.9,
            autoConvert: false,
            openOutputFolderAfterConversion: false,
            launchAtLogin: false
        )
    }
}
