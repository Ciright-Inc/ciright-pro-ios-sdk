// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "QuickAuthIOSSDK",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "QuickAuthIOSSDK",
            targets: ["QuickAuthIOSSDK"]
        )
    ],
    targets: [
        .target(
            name: "QuickAuthIOSSDK",
            dependencies: ["IPificationSDK"],
            path: "Sources/QuickAuthIOSSDK",
            linkerSettings: [
                .linkedFramework("Security"),
                .linkedFramework("UIKit")
            ]
        ),
        .binaryTarget(
            name: "IPificationSDK",
            path: "Dependencies/AuthProvider.xcframework"
        )
    ]
)
