// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenAIBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "OpenAIBar",
            path: "Sources/OpenAIBar",
            swiftSettings: [.unsafeFlags(["-F", "Vendor/Sparkle"])],
            linkerSettings: [
                .linkedFramework("Sparkle"),
                .unsafeFlags(["-F", "Vendor/Sparkle", "-Xlinker", "-rpath",
                              "-Xlinker", "@executable_path/../Frameworks"])
            ]
        )
    ]
)
