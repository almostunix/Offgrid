// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "cerbo-app",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "VictronKit",
            targets: ["VictronKit"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/emqx/CocoaMQTT.git", exact: "2.4.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "VictronKit",
            dependencies: [
                .product(name: "CocoaMQTT", package: "CocoaMQTT"),
            ]),
        .testTarget(
            name: "VictronKitTests",
            dependencies: ["VictronKit"],
            resources: [.copy("Fixtures")]),
    ]
)
