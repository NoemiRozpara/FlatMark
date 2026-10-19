// swift-tools-version: 6.4
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
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "FlatMark",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .executableTarget(
            name: "FlatMarkNavigationTestHost",
            dependencies: ["FlatMark"],
            path: "Tests/FlatMarkNavigationTestHost"
        ),
        .target(
            name: "FlatMarkFixtures",
            dependencies: ["FlatMark"],
            path: "Tests/FlatMarkFixtures",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .executableTarget(
            name: "FlatMarkFixtureHost",
            dependencies: ["FlatMark", "FlatMarkFixtures"],
            path: "Tests/FlatMarkFixtureHost"
        ),
        .testTarget(
            name: "FlatMarkTests",
            dependencies: [
                "FlatMark",
                "FlatMarkFixtures",
                .target(name: "FlatMarkNavigationTestHost", condition: .when(platforms: [.macOS])),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
    ]
)
