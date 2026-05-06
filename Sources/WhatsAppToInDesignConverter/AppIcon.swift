import AppKit

enum AppIcon {
    private static let resourceBundleName = "WhatsAppToInDesignConverter_WhatsAppToInDesignConverter"

    static func makeApplicationIcon(size: CGFloat = 1024) -> NSImage {
        if let bundleIcon = mainBundleIconImage() {
            return bundleIcon
        }

        if let bundleIcon = bundleIconImage() {
            return bundleIcon
        }

        guard let sourceImage = sourceImage() else {
            return makeFallbackApplicationIcon(size: size)
        }
        return renderedPNGIcon(from: sourceImage, size: size)
    }

    private static func mainBundleIconImage() -> NSImage? {
        guard let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    private static var resourcesBundle: Bundle? {
        if let resourceURL = Bundle.main.resourceURL {
            let appBundleURL = resourceURL.appendingPathComponent("\(resourceBundleName).bundle")
            if let bundle = Bundle(url: appBundleURL) {
                return bundle
            }
        }

        let rootBundleURL = Bundle.main.bundleURL.appendingPathComponent("\(resourceBundleName).bundle")
        if let bundle = Bundle(url: rootBundleURL) {
            return bundle
        }

        return Bundle.module
    }

    private static func bundleIconImage() -> NSImage? {
        guard let url = resourcesBundle?.url(forResource: "AppIcon", withExtension: "icns") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    private static func sourceImage() -> NSImage? {
        guard let url = resourcesBundle?.url(forResource: "AppIconSource", withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    private static func renderedPNGIcon(from sourceImage: NSImage, size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let bounds = CGRect(origin: .zero, size: image.size)
        let iconRect = bounds.insetBy(dx: size * 0.032, dy: size * 0.032)
        let cornerRadius = size * 0.223
        let iconPath = NSBezierPath(roundedRect: iconRect, xRadius: cornerRadius, yRadius: cornerRadius)

        NSGraphicsContext.current?.saveGraphicsState()
        iconPath.addClip()
        sourceImage.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1)

        let gloss = NSGradient(colors: [
            NSColor.white.withAlphaComponent(0.18),
            NSColor.white.withAlphaComponent(0.05),
            .clear,
        ])!
        gloss.draw(in: iconPath, angle: 90)
        NSGraphicsContext.current?.restoreGraphicsState()

        image.drawMacIconShadow(around: iconPath, size: size)

        NSColor.white.withAlphaComponent(0.14).setStroke()
        iconPath.lineWidth = max(2, size * 0.01)
        iconPath.stroke()

        image.unlockFocus()
        return image
    }

    private static func makeFallbackApplicationIcon(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let bounds = CGRect(origin: .zero, size: image.size)
        let outerRect = bounds.insetBy(dx: size * 0.08, dy: size * 0.08)
        let outerPath = NSBezierPath(roundedRect: outerRect, xRadius: size * 0.22, yRadius: size * 0.22)
        let outerGradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.09, green: 0.57, blue: 0.82, alpha: 1),
            NSColor(calibratedRed: 0.12, green: 0.72, blue: 0.72, alpha: 1),
        ])!
        outerGradient.draw(in: outerPath, angle: 90)

        NSColor.white.withAlphaComponent(0.18).setStroke()
        outerPath.lineWidth = size * 0.012
        outerPath.stroke()
        image.unlockFocus()
        return image
    }
}

private extension NSImage {
    func drawMacIconShadow(around path: NSBezierPath, size: CGFloat) {
        NSGraphicsContext.current?.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowBlurRadius = size * 0.03
        shadow.shadowOffset = NSSize(width: 0, height: -(size * 0.012))
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
        shadow.set()
        NSColor.clear.setFill()
        path.fill()
        NSGraphicsContext.current?.restoreGraphicsState()
    }
}
