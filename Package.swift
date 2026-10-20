// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacSpaceKeeper",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "MacSpaceKeeper", targets: ["MacSpaceKeeper"])],
    targets: [
        .executableTarget(name: "MacSpaceKeeper", path: "Sources/MacSpaceKeeper"),
        .testTarget(name: "MacSpaceKeeperTests", dependencies: ["MacSpaceKeeper"])
    ]
)
