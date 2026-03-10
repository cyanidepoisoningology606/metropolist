// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StoreBuilder",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "TransitModels", targets: ["TransitModels"]),
    ],
    targets: [
        .target(name: "TransitModels"),
        .executableTarget(
            name: "StoreBuilder",
            dependencies: ["TransitModels"]
        ),
    ]
)
