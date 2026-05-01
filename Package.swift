// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ZhareHubSDK",
    platforms: [
        .iOS(.v26),
        .macCatalyst(.v26)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ZhareHubSDK",
            targets: ["ZhareHubSDK"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/hariharan-rs-19343/SUICore.git", branch: "main"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.10.0"),
        .package(url: "https://github.com/marmelroy/Zip.git", from: "2.1.2")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ZhareHubSDK",
            dependencies: ["SUICore", "Alamofire", "Zip"]
        ),
        .testTarget(
            name: "ZhareHubSDKTests",
            dependencies: ["ZhareHubSDK"]
        ),
    ]
)  
