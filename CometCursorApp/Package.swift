// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CometCursorApp",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "CometCursorApp",
            path: "Sources/CometCursorApp",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("CoreGraphics"),
            ]
        )
    ]
)
