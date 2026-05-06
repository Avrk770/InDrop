import AppKit
import Foundation
import UserNotifications

@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private let center: UNUserNotificationCenter?
    private let revealActionIdentifier = "REVEAL_LAST_CONVERTED_FILE"
    private let categoryIdentifier = "CONVERSION_COMPLETE"
    private var lastRevealURLs: [URL] = []
    private let notificationsAvailable: Bool

    private override init() {
        notificationsAvailable = Bundle.main.bundleURL.pathExtension == "app"
        center = notificationsAvailable ? UNUserNotificationCenter.current() : nil
        super.init()
        if let center {
            center.delegate = self
        }
    }

    func configure() {
        guard let center else { return }
        let language = AppPreferences.defaultLanguage

        let revealAction = UNNotificationAction(
            identifier: revealActionIdentifier,
            title: AppStrings.revealFolder(language),
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [revealAction],
            intentIdentifiers: []
        )
        center.setNotificationCategories([category])
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func notify(for results: [ConversionResult]) async {
        guard let center else { return }
        let language = AppPreferences.defaultLanguage

        let successCount = results.filter { $0.status == .success }.count
        let skippedCount = results.filter { $0.status == .skipped }.count
        let failureCount = results.filter { $0.status == .failure }.count
        let outputFormats = Set(results.compactMap(\.outputFormat))

        guard successCount + skippedCount + failureCount > 0 else { return }

        lastRevealURLs = results.compactMap { result in
            result.status == .success ? result.outputURL : nil
        }

        let content = UNMutableNotificationContent()
        content.title = skippedCount == 0 && failureCount == 0 ? AppStrings.notificationComplete(language) : AppStrings.notificationIssues(language)
        if skippedCount == 0, failureCount == 0 {
            if outputFormats.count == 1, let format = outputFormats.first {
                content.body = AppStrings.conversionSucceeded(language, count: successCount, format: format)
            } else {
                content.body = AppStrings.conversionSucceeded(language, count: successCount)
            }
        } else if successCount == 0, failureCount == 0 {
            content.body = AppStrings.conversionSkippedAll(language, count: skippedCount)
        } else {
            content.body = AppStrings.conversionPartial(language, successCount: successCount, skippedCount: skippedCount, failureCount: failureCount)
        }
        content.categoryIdentifier = lastRevealURLs.isEmpty ? "" : categoryIdentifier

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        try? await center.add(request)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let shouldReveal = response.actionIdentifier == revealActionIdentifier
        if shouldReveal {
            Task { @MainActor in
                if !lastRevealURLs.isEmpty {
                    NSWorkspace.shared.activateFileViewerSelecting(lastRevealURLs)
                }
            }
        }
        completionHandler()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
