// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "FlatMark",
    platforms: [
        .iOS(.v17),
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "FlatMark",
            targets: ["FlatMark"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftlang/swift-markdown.git",
            .upToNextMinor(from: "0.8.0")
        ),
        // Test-only: reviewed image baselines, pixel comparison, and diff artifacts.
        .package(
            url: "https://github.com/pointfreeco/swift-snapshot-testing.git",
            .upToNextMinor(from: "1.19.6")
        ),
    ],
    targets: [
        .target(
            name: "FlatMark",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
            ]
        ),
        // Shared fixture data for package tests and test hosts; not part of any product.
        .target(
            name: "FlatMarkFixtures",
            dependencies: ["FlatMark"],
            path: "Support/FlatMarkFixtures",
            exclude: ["ASSETS.md"],
            resources: [.copy("focaccia.jpeg"), .copy("leaf.png")]
        ),
        .executableTarget(
            name: "FlatMarkConstructionBenchmark",
            dependencies: ["FlatMark"],
            path: "Benchmarks/Construction"
        ),
        .executableTarget(
            name: "FlatMarkNavigationTestHost",
            dependencies: ["FlatMark"],
            path: "Tests/FlatMarkNavigationTestHost"
        ),
        .testTarget(
            name: "FlatMarkTests",
            dependencies: [
                "FlatMark",
                "FlatMarkFixtures",
                .target(name: "FlatMarkNavigationTestHost", condition: .when(platforms: [.macOS])),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
