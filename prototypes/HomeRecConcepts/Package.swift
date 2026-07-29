// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HomeRecConcepts",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "HomeRecConcepts",
            path: "Sources/HomeRecConcepts",
            resources: [.copy("Resources/Fonts")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
