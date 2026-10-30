// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FlatMark",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
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
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
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
            resources: [.copy("focaccia.jpeg")]
        ),
        .executableTarget(
            name: "FlatMarkConstructionBenchmark",
            dependencies: ["FlatMark"],
            path: "Benchmarks/Construction",
            exclude: ["Baselines"]
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
