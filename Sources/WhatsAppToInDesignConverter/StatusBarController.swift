import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popoverController: StatusPopoverController
    private let viewModel: DropConversionViewModel
    private var settingsCancellable: AnyCancellable?
    private var launchPresentationAttempts = 0

    init(viewModel: DropConversionViewModel) {
        self.viewModel = viewModel
        self.popoverController = StatusPopoverController(viewModel: viewModel)
        super.init()
        popoverController.setOnClose { [weak self] in
            self?.statusView?.isPanelPresented = false
            self?.viewModel.setDragging(false)
        }
        configureStatusItem()
        configureSettingsObserver()
    }

    private func configureStatusItem() {
        let length = NSStatusBar.system.thickness + 6
        statusItem.length = length
        guard let button = statusItem.button else { return }
        button.image = nil
        button.title = "⇩"
        button.font = .systemFont(ofSize: 16, weight: .semibold)
        button.isBordered = false
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp])

        let view = StatusItemDropView(frame: NSRect(x: 0, y: 0, width: length, height: NSStatusBar.system.thickness))
        view.autoresizingMask = [.width, .height]
        button.subviews.forEach { $0.removeFromSuperview() }
        button.addSubview(view, positioned: .above, relativeTo: nil)

        view.onLeftClick = { [weak self] in
            self?.togglePanel()
        }
        view.onRightClick = { [weak self, weak view] event in
            guard let self, let view else { return }
            self.showContextMenu(for: view, event: event)
        }
        view.onDragEntered = { [weak self] in
            guard let self else { return }
            self.viewModel.setDragging(true)
            self.showPanel(activate: false)
        }
        view.onDragExited = { [weak self] in
            self?.viewModel.setDragging(false)
        }
        view.onDropURLs = { [weak self] urls in
            guard let self else { return }
            let prefersManualFormatSelection = NSEvent.modifierFlags.contains(.option)
            self.viewModel.handleDrop(urls: urls, prefersManualFormatSelection: prefersManualFormatSelection)
            self.showPanel(activate: true)
            self.popoverController.refresh()
        }
        view.refreshLocalization()
    }

    private func configureSettingsObserver() {
        settingsCancellable = AppSettingsStore.shared.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.statusView?.refreshLocalization()
            }
    }

    private static func makeStatusItemImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()
        NSColor.labelColor.setStroke()

        let tray = NSBezierPath()
        tray.lineWidth = 1.55
        tray.lineCapStyle = .round
        tray.lineJoinStyle = .round
        tray.move(to: NSPoint(x: 3.2, y: 6))
        tray.line(to: NSPoint(x: 5.8, y: 3.9))
        tray.line(to: NSPoint(x: 12.2, y: 3.9))
        tray.line(to: NSPoint(x: 14.8, y: 6))
        tray.move(to: NSPoint(x: 3.2, y: 6))
        tray.line(to: NSPoint(x: 3.2, y: 8))
        tray.move(to: NSPoint(x: 14.8, y: 6))
        tray.line(to: NSPoint(x: 14.8, y: 8))
        tray.stroke()

        let arrow = NSBezierPath()
        arrow.lineWidth = 1.55
        arrow.lineCapStyle = .round
        arrow.lineJoinStyle = .round
        arrow.move(to: NSPoint(x: 9, y: 14.2))
        arrow.line(to: NSPoint(x: 9, y: 7.35))
        arrow.move(to: NSPoint(x: 6.55, y: 9.7))
        arrow.line(to: NSPoint(x: 9, y: 7.35))
        arrow.line(to: NSPoint(x: 11.45, y: 9.7))
        arrow.stroke()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private func togglePanel() {
        if popoverController.isVisible {
            hidePanel()
        } else {
            showPanel(activate: true)
        }
    }

    @objc
    private func statusItemClicked() {
        togglePanel()
    }

    func presentPanelOnLaunch() {
        presentPanelOnLaunchWhenReady()
    }

    private func showPanel(activate: Bool) {
        let anchorView = statusItem.button ?? statusView
        guard let anchorView,
              anchorView.window != nil else { return }

        popoverController.show(relativeTo: anchorView, activate: activate)
        statusView?.isPanelPresented = true
    }

    private func hidePanel() {
        popoverController.hide()
        viewModel.setDragging(false)
        statusView?.isPanelPresented = false
    }

    private var statusView: StatusItemDropView? {
        statusItem.button?.subviews.compactMap { $0 as? StatusItemDropView }.first
    }

    private func presentPanelOnLaunchWhenReady() {
        let anchorView = statusItem.button ?? statusView
        guard let button = anchorView else { return }

        if button.window != nil {
            launchPresentationAttempts = 0
            showPanel(activate: true)
            return
        }

        guard launchPresentationAttempts < 20 else {
            launchPresentationAttempts = 0
            return
        }

        launchPresentationAttempts += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.presentPanelOnLaunchWhenReady()
        }
    }

    private func showContextMenu(for view: NSView, event: NSEvent) {
        let menu = NSMenu()

        let openItem = NSMenuItem(title: "Open InDrop", action: #selector(openPanelFromMenu), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        let settingsItem = NSMenuItem(title: AppStrings.settings(), action: #selector(openSettingsFromMenu), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit InDrop", action: #selector(quitFromMenu), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }

    @objc
    private func openPanelFromMenu() {
        showPanel(activate: true)
    }

    @objc
    private func openSettingsFromMenu() {
        showPanel(activate: true)
        viewModel.showSettingsPanel()
        popoverController.refresh()
    }

    @objc
    private func quitFromMenu() {
        NSApp.terminate(nil)
    }
}

@MainActor
private final class StatusPopoverController: NSObject, NSPopoverDelegate {
    private let panelWidth: CGFloat = 410
    private var refreshCancellable: AnyCancellable?
    private let hostingController: NSHostingController<StatusMenuContentView>
    private let viewModel: DropConversionViewModel
    private let popover: NSPopover
    private weak var anchorView: NSView?
    private var onClose: (() -> Void)?

    var isVisible: Bool {
        popover.isShown
    }

    init(viewModel: DropConversionViewModel) {
        self.viewModel = viewModel
        let hostingController = NSHostingController(rootView: StatusMenuContentView(viewModel: viewModel))
        self.hostingController = hostingController
        self.popover = NSPopover()

        super.init()
        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self
        popover.contentViewController = hostingController

        refreshCancellable = viewModel.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show(relativeTo view: NSView, activate: Bool) {
        viewModel.showMainPanel()
        hostingController.rootView = StatusMenuContentView(viewModel: viewModel)
        anchorView = view
        refresh()

        if activate {
            NSApp.activate(ignoringOtherApps: true)
        }

        if popover.isShown {
            return
        }

        popover.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
    }

    func hide() {
        popover.close()
    }

    func refresh() {
        hostingController.view.layoutSubtreeIfNeeded()
        let targetSize = fittingPanelSize()

        guard popover.isShown,
              let window = popover.contentViewController?.view.window else {
            popover.contentSize = targetSize
            return
        }

        let anchoredMaxY = window.frame.maxY
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0
        popover.contentSize = targetSize
        window.setFrameOrigin(NSPoint(x: window.frame.origin.x, y: anchoredMaxY - window.frame.height))
        NSAnimationContext.endGrouping()
    }

    private func fittingPanelSize() -> NSSize {
        hostingController.view.layoutSubtreeIfNeeded()
        let fittingSize = hostingController.view.fittingSize
        let visibleHeight = anchorView?.window?.screen?.visibleFrame.height
            ?? NSScreen.main?.visibleFrame.height
            ?? 720
        let maxHeight = max(320, visibleHeight - 24)
        let height = min(max(220, fittingSize.height), maxHeight)
        return NSSize(width: panelWidth, height: height)
    }

    func popoverDidClose(_ notification: Notification) {
        onClose?()
    }

    func setOnClose(_ handler: @escaping () -> Void) {
        onClose = handler
    }
}

@MainActor
private final class StatusItemDropView: NSView {
    var onLeftClick: (() -> Void)?
    var onRightClick: ((NSEvent) -> Void)?
    var onDragEntered: (() -> Void)?
    var onDragExited: (() -> Void)?
    var onDropURLs: (([URL]) -> Void)?
    var isPanelPresented: Bool = false {
        didSet {
            updateAppearance()
        }
    }

    private var isTargeted = false {
        didSet {
            updateAppearance()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        unregisterDraggedTypes()
        registerForDraggedTypes([.fileURL])
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isOpaque: Bool {
        false
    }

    override func draw(_ dirtyRect: NSRect) {
        let shouldHighlight = isTargeted || isPanelPresented
        if shouldHighlight {
            let bounds = self.bounds.insetBy(dx: 1, dy: 1)
            highlightedBackgroundColor().setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6).fill()

            if isTargeted {
                dragOutlineColor().setStroke()
                let outline = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6)
                outline.lineWidth = 1.25
                outline.stroke()
            }
        }

        if superview is NSStatusBarButton == false {
            drawIcon()
        }
    }

    func refreshLocalization() {
        toolTip = AppStrings.statusItemTooltip()
        updateAppearance()
    }

    private func updateAppearance() {
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
    }

    override func mouseDown(with event: NSEvent) {
        onLeftClick?()
    }

    override func rightMouseUp(with event: NSEvent) {
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?(event)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let urls = fileURLs(from: sender)
        guard !urls.isEmpty else { return [] }
        isTargeted = true
        onDragEntered?()
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let urls = fileURLs(from: sender)
        let canAcceptDrop = !urls.isEmpty
        isTargeted = canAcceptDrop
        if canAcceptDrop {
            onDragEntered?()
            return .copy
        }
        onDragExited?()
        return []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isTargeted = false
        onDragExited?()
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        !fileURLs(from: sender).isEmpty
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = fileURLs(from: sender)
        isTargeted = false
        onDragExited?()
        guard !urls.isEmpty else { return false }
        onDropURLs?(urls)
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        isTargeted = false
        onDragExited?()
    }

    private func fileURLs(from draggingInfo: NSDraggingInfo) -> [URL] {
        let classes: [AnyClass] = [NSURL.self]
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true,
        ]

        return draggingInfo.draggingPasteboard.readObjects(forClasses: classes, options: options) as? [URL] ?? []
    }

    private func highlightedBackgroundColor() -> NSColor {
        if effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor.white.withAlphaComponent(0.22)
        }
        return NSColor.black.withAlphaComponent(0.14)
    }

    private func dragOutlineColor() -> NSColor {
        if effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor.controlAccentColor.withAlphaComponent(0.9)
        }
        return NSColor.controlAccentColor.withAlphaComponent(0.7)
    }

    private func drawIcon() {
        let strokeColor = (isTargeted || isPanelPresented) ? NSColor.selectedMenuItemTextColor : NSColor.labelColor
        strokeColor.setStroke()
        let tray = NSBezierPath()
        tray.lineWidth = 1.55
        tray.lineCapStyle = .round
        tray.lineJoinStyle = .round
        tray.move(to: NSPoint(x: 3.2, y: 6))
        tray.line(to: NSPoint(x: 5.8, y: 3.9))
        tray.line(to: NSPoint(x: 12.2, y: 3.9))
        tray.line(to: NSPoint(x: 14.8, y: 6))
        tray.move(to: NSPoint(x: 3.2, y: 6))
        tray.line(to: NSPoint(x: 3.2, y: 8))
        tray.move(to: NSPoint(x: 14.8, y: 6))
        tray.line(to: NSPoint(x: 14.8, y: 8))

        let arrow = NSBezierPath()
        arrow.lineWidth = 1.55
        arrow.lineCapStyle = .round
        arrow.lineJoinStyle = .round
        arrow.move(to: NSPoint(x: 9, y: 14.2))
        arrow.line(to: NSPoint(x: 9, y: 7.35))
        arrow.move(to: NSPoint(x: 6.55, y: 9.7))
        arrow.line(to: NSPoint(x: 9, y: 7.35))
        arrow.line(to: NSPoint(x: 11.45, y: 9.7))

        let iconBounds = NSRect(x: round((bounds.width - 18) / 2), y: round((bounds.height - 18) / 2), width: 18, height: 18)
        let transform = AffineTransform(
            translationByX: iconBounds.origin.x,
            byY: iconBounds.origin.y
        )
        tray.transform(using: transform)
        arrow.transform(using: transform)
        tray.stroke()
        arrow.stroke()
    }
}
