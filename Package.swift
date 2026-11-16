// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Ambiente",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "AmbienteCore"),
        .executableTarget(name: "Ambiente", dependencies: ["AmbienteCore"]),
        .testTarget(name: "AmbienteCoreTests", dependencies: ["AmbienteCore"]),
    ],
    swiftLanguageModes: [.v5]
)
