import AppKit
import Foundation

@MainActor
final class AppSettingsStore: ObservableObject {
    static let shared = AppSettingsStore()
    @Published var launchAtLogin: Bool {
        didSet {
            guard !isRefreshingLaunchAtLoginState else { return }
            applyLaunchAtLoginPreference(launchAtLogin)
        }
    }
    @Published private(set) var launchAtLoginRequiresApproval = false
    @Published private(set) var launchAtLoginErrorMessage: String?

    @Published var language: AppPreferences.Language {
        didSet { defaults.set(language.rawValue, forKey: Keys.language) }
    }

    @Published var outputFormat: AppPreferences.OutputFormat {
        didSet { defaults.set(outputFormat.rawValue, forKey: Keys.outputFormat) }
    }

    @Published var outputLocation: AppPreferences.OutputLocation {
        didSet { defaults.set(outputLocation.rawValue, forKey: Keys.outputLocation) }
    }

    @Published var customOutputFolderPath: String? {
        didSet { defaults.set(customOutputFolderPath, forKey: Keys.customOutputFolderPath) }
    }

    @Published var filenameTemplate: AppPreferences.FilenameTemplate {
        didSet { defaults.set(filenameTemplate.rawValue, forKey: Keys.filenameTemplate) }
    }

    @Published var existingFileAction: AppPreferences.ExistingFileAction {
        didSet { defaults.set(existingFileAction.rawValue, forKey: Keys.existingFileAction) }
    }

    @Published var originalFileAction: AppPreferences.OriginalFileAction {
        didSet { defaults.set(originalFileAction.rawValue, forKey: Keys.originalFileAction) }
    }

    @Published var jpegQuality: Double {
        didSet { defaults.set(jpegQuality, forKey: Keys.jpegQuality) }
    }

    @Published var autoConvert: Bool {
        didSet { defaults.set(autoConvert, forKey: Keys.autoConvert) }
    }

    @Published var openOutputFolderAfterConversion: Bool {
        didSet { defaults.set(openOutputFolderAfterConversion, forKey: Keys.openOutputFolderAfterConversion) }
    }

    var preferences: AppPreferences {
        AppPreferences(
            language: language,
            outputFormat: outputFormat,
            outputLocation: outputLocation,
            customOutputFolderPath: customOutputFolderPath,
            filenameTemplate: filenameTemplate,
            existingFileAction: existingFileAction,
            originalFileAction: originalFileAction,
            jpegQuality: jpegQuality,
            autoConvert: autoConvert,
            openOutputFolderAfterConversion: openOutputFolderAfterConversion,
            launchAtLogin: launchAtLogin
        )
    }

    private let defaults: UserDefaults
    private var isRefreshingLaunchAtLoginState = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        language = AppPreferences.Language(rawValue: defaults.string(forKey: Keys.language) ?? "") ?? AppPreferences.default.language
        outputFormat = AppPreferences.OutputFormat(rawValue: defaults.string(forKey: Keys.outputFormat) ?? "") ?? AppPreferences.default.outputFormat
        outputLocation = AppPreferences.OutputLocation(rawValue: defaults.string(forKey: Keys.outputLocation) ?? "") ?? AppPreferences.default.outputLocation
        customOutputFolderPath = defaults.string(forKey: Keys.customOutputFolderPath)
        filenameTemplate = AppPreferences.FilenameTemplate(rawValue: defaults.string(forKey: Keys.filenameTemplate) ?? "") ?? AppPreferences.default.filenameTemplate
        existingFileAction = AppPreferences.ExistingFileAction(rawValue: defaults.string(forKey: Keys.existingFileAction) ?? "") ?? AppPreferences.default.existingFileAction
        originalFileAction = AppPreferences.OriginalFileAction(rawValue: defaults.string(forKey: Keys.originalFileAction) ?? "") ?? AppPreferences.default.originalFileAction

        let storedQuality = defaults.object(forKey: Keys.jpegQuality) as? Double
        jpegQuality = storedQuality ?? AppPreferences.default.jpegQuality
        autoConvert = defaults.object(forKey: Keys.autoConvert) as? Bool ?? AppPreferences.default.autoConvert
        openOutputFolderAfterConversion = defaults.object(forKey: Keys.openOutputFolderAfterConversion) as? Bool ?? AppPreferences.default.openOutputFolderAfterConversion
        let launchState = LaunchAtLoginManager.currentState()
        launchAtLogin = launchState.isEnabled
        launchAtLoginRequiresApproval = launchState.requiresApproval
        launchAtLoginErrorMessage = nil
    }

    func chooseCustomOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.title = AppStrings.chooseOutputFolder(language)

        if let currentPath = customOutputFolderPath {
            panel.directoryURL = URL(fileURLWithPath: currentPath, isDirectory: true)
        }

        let completion: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.customOutputFolderPath = url.path
            self?.outputLocation = .customFolder
        }

        if let parentWindow = NSApp.keyWindow ?? NSApp.mainWindow {
            panel.beginSheetModal(for: parentWindow, completionHandler: completion)
        } else {
            completion(panel.runModal())
        }
    }

    func refreshLaunchAtLoginState() {
        let state = LaunchAtLoginManager.currentState()
        isRefreshingLaunchAtLoginState = true
        launchAtLogin = state.isEnabled
        launchAtLoginRequiresApproval = state.requiresApproval
        if !state.requiresApproval {
            launchAtLoginErrorMessage = nil
        }
        isRefreshingLaunchAtLoginState = false
    }

    private func applyLaunchAtLoginPreference(_ enabled: Bool) {
        do {
            try LaunchAtLoginManager.setEnabled(enabled)
            launchAtLoginErrorMessage = nil
        } catch {
            launchAtLoginErrorMessage = AppStrings.launchAtLoginError()
        }

        refreshLaunchAtLoginState()
    }

    private enum Keys {
        static let language = "settings.language"
        static let outputFormat = "settings.outputFormat"
        static let outputLocation = "settings.outputLocation"
        static let customOutputFolderPath = "settings.customOutputFolderPath"
        static let filenameTemplate = "settings.filenameTemplate"
        static let existingFileAction = "settings.existingFileAction"
        static let originalFileAction = "settings.originalFileAction"
        static let jpegQuality = "settings.jpegQuality"
        static let autoConvert = "settings.autoConvert"
        static let openOutputFolderAfterConversion = "settings.openOutputFolderAfterConversion"
    }
}
