// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ShiftType",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "ShiftTypeCore",
            path: "Core"
        ),
        .executableTarget(
            name: "ShiftType",
            dependencies: ["ShiftTypeCore"],
            path: "Sources"
        ),
        .executableTarget(
            name: "ShiftTypeSelfTests",
            dependencies: ["ShiftTypeCore"],
            path: "Tests"
        ),
    ]
)
