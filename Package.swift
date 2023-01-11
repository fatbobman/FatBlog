// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "FatbobmanBlog",
    products: [
        .executable(
            name: "FatbobmanBlog",
            targets: ["FatbobmanBlog"]
        )
    ],
    dependencies: [
        //        .package(name: "Publish", url: "https://github.com/johnsundell/publish.git", from: "0.6.0"),
//        .package(name: "Publish", url: "https://github.com/fatbobman/Publish.git", from: "0.7.1"),
        .package(url: "https://github.com/fatbobman/Publish.git", .branchItem("MyFork")),
        .package(name:"HighlightJSPublishPlugin", url: "https://github.com/fatbobman/HighlightJSPublishPlugin.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "FatbobmanBlog",
            dependencies: [
                "Publish",
                "HighlightJSPublishPlugin"
            ]
        )
    ]
)
