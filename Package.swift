// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WhatsAppToInDesignConverter",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "InDrop",
            targets: ["WhatsAppToInDesignConverter"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "WhatsAppToInDesignConverter",
            resources: [
                .process("Resources/AppIconSource.png"),
                .copy("Resources/AppIcon.icns"),
            ]
        ),
        .testTarget(
            name: "WhatsAppToInDesignConverterTests",
            dependencies: ["WhatsAppToInDesignConverter"]
        ),
    ]
)
