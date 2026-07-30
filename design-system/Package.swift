// swift-tools-version: 6.0
import PackageDescription

// Three independent design systems, extracted from the Home Rec concept
// prototypes. Each is a self-contained library with its own tokens and no
// dependency on the others, so any one of them can be lifted into its own
// repository without untangling shared code first.
let package = Package(
    name: "HomeRecDesignSystems",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "GlassKit", targets: ["GlassKit"]),
        .library(name: "StageKit", targets: ["StageKit"]),
        .library(name: "PocketOperatorKit", targets: ["PocketOperatorKit"]),
        .executable(name: "DesignSystemGallery", targets: ["DesignSystemGallery"]),
    ],
    targets: [
        .target(name: "GlassKit", swiftSettings: [.swiftLanguageMode(.v5)]),
        .target(name: "StageKit", swiftSettings: [.swiftLanguageMode(.v5)]),
        .target(name: "PocketOperatorKit", swiftSettings: [.swiftLanguageMode(.v5)]),
        // The only place the three kits meet. It depends on them; they never
        // depend on it or on each other, so lifting any one kit out stays a
        // directory move.
        .executableTarget(
            name: "DesignSystemGallery",
            dependencies: ["GlassKit", "StageKit", "PocketOperatorKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
