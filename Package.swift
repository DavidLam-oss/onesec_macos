// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OnesecCore",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .executable(
            name: "OnesecCore",
            targets: ["OnesecCore"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/daltoniam/Starscream.git", from: "4.0.0"),
        .package(url: "https://github.com/SwiftyBeaver/SwiftyBeaver.git", .upToNextMajor(from: "2.0.0")),
        .package(url: "GitHub - apple/swift-argument-parser: Straightforward, type-safe argument parsing for Swift", from: "1.3.0"),
        .package(url: "GitHub - alta/swift-opus: Opus audio codec for Swift Package Manager", from: "0.0.2"),
        .package(
            url: "GitHub - apple/swift-collections: Commonly used data structures for Swift",
            .upToNextMinor(from: "1.3.0") // or `.upToNextMajor
        ),

    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "OnesecCore",
            dependencies: [
                .product(name: "Starscream", package: "Starscream"),
                .product(name: "SwiftyBeaver", package: "SwiftyBeaver"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "Opus", package: "swift-opus"),
            ],
            path: "Sources",
            resources: [
                .process("Resources/Sounds"),
            ],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"]),
            ]
        ),
        .testTarget(
            name: "OnesecCoreTests",
            dependencies: ["OnesecCore"]
        ),
    ]
)
