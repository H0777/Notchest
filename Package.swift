// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Notchest",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Notchest", targets: ["Notchest"]),
        .executable(name: "NotchestCommand", targets: ["NotchestCommand"])
    ],
    targets: [
        .target(name: "SwiftTerm", path: "Vendor/SwiftTerm", exclude: ["Mac/README.md", "Apple/Metal/Shaders.metal", "LICENSE"]),
        .executableTarget(name: "Notchest", dependencies: ["SwiftTerm"]),
        .executableTarget(name: "NotchestCommand"),
        .testTarget(name: "NotchestTests", dependencies: ["Notchest"])
    ]
)
