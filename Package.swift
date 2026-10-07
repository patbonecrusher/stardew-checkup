// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "StardewCheckup",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "StardewCheckup",
            path: "Sources/StardewCheckup",
            swiftSettings: [.unsafeFlags(["-parse-as-library"])]
        )
    ]
)
