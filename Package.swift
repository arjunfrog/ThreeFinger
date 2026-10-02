// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "ThreeFinger",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "CMultitouch"),
        .executableTarget(name: "ThreeFinger", dependencies: ["CMultitouch"]),
        .testTarget(name: "ThreeFingerTests", dependencies: ["ThreeFinger"]),
    ]
)
