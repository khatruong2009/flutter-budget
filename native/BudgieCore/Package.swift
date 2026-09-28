// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BudgieCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "BudgieCore", targets: ["BudgieCore"]),
    ],
    targets: [
        .target(name: "BudgieCore"),
        .testTarget(name: "BudgieCoreTests", dependencies: ["BudgieCore"]),
    ]
)
