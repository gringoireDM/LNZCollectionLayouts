// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "LNZCollectionLayouts",
    platforms: [
        .iOS("8.0")
    ],
    products: [
        .library(
            name: "LNZCollectionLayouts",
            targets: ["LNZCollectionLayouts"]
        )
    ],
    targets: [
        .target(
            name: "LNZCollectionLayouts",
            path: "LNZCollectionLayouts/Layouts"
        )
    ]
)
