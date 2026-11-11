// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "NormalSwitcher",
    platforms: [.macOS(.v26)],
    targets: [.executableTarget(name: "NormalSwitcher", linkerSettings: [
        .linkedFramework("Carbon"), .linkedFramework("AppKit")
    ])]
)
