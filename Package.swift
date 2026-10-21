// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Qingo",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Qingo", targets: ["Qingo"])],
    targets: [
        .executableTarget(name: "Qingo", path: "Sources/Qingo"),
        .testTarget(name: "QingoTests", dependencies: ["Qingo"])
    ]
)
