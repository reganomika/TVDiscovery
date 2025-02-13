// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "TVDiscovery",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "TVDiscovery",
            targets: ["TVDiscovery"]),
    ],
    dependencies: [
        // Здесь можно указать зависимости от других пакетов
    ],
    targets: [
        .target(
            name: "TVDiscovery",
            dependencies: []),
        .testTarget(
            name: "TVDiscoveryTests",
            dependencies: ["TVDiscovery"]),
    ]
)
