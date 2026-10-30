// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SlitCore",
    platforms: [.iOS(.v18), .macOS(.v13)],
    products: [.library(name: "SlitCore", targets: ["SlitCore"])],
    targets: [
        .target(name: "SlitCore"),
        .testTarget(name: "SlitCoreTests", dependencies: ["SlitCore"])
    ],
    swiftLanguageModes: [.v5]
)
