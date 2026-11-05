// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StillHere",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "StillHere", targets: ["StillHere"])],
    targets: [
        .target(name: "StillHereCore"),
        .executableTarget(name: "StillHere", dependencies: ["StillHereCore"],
                          resources: [.process("Resources")],
                          linkerSettings: [.linkedFramework("Carbon"), .linkedFramework("IOKit")]),
        .testTarget(name: "StillHereCoreTests", dependencies: ["StillHereCore"])
    ]
)
