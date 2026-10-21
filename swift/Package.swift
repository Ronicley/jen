// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "JenSwift",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        // An xtool project should contain exactly one library product,
        // representing the main app.
        .library(
            name: "Jen",
            targets: ["Jen"]
        ),
    ],
    targets: [
        .target(
            name: "Jen",
            path: "Sources/swift",
            resources: [.copy("Resources/jen-logo.png")]
        ),
    ]
)
