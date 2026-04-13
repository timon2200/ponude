// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Ponude",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Ponude",
            path: "Ponude",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
