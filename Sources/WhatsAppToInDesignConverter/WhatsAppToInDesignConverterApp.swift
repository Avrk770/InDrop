import AppKit
import SwiftUI

@main
struct WhatsAppToInDesignConverterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = AppSettingsStore.shared

    var body: some Scene {
        Settings {
            SettingsView(settings: settings)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let applicationIcon = AppIcon.makeApplicationIcon()
        NSApp.applicationIconImage = applicationIcon
        NotificationManager.shared.configure()
        let viewModel = DropConversionViewModel()
        let statusBarController = StatusBarController(viewModel: viewModel)
        self.statusBarController = statusBarController

        // A menu bar app can feel like it "didn't open" when launched from Finder.
        // Present the popover on launch so the user gets immediate feedback.
        DispatchQueue.main.async {
            statusBarController.presentPanelOnLaunch()
        }
    }
}
