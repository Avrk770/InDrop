import UniformTypeIdentifiers

enum SupportedFileTypes {
    static var openPanelContentTypes: [UTType] {
        FileTypeDetector.openPanelContentTypes
    }

    static func isSupported(_ url: URL) -> Bool {
        FileTypeDetector.isSupported(url)
    }
}
