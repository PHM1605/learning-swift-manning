// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let repo = "https://github.com/apple/example-package-deckofplayingcards.git"

let package = Package(
    name: "Dealer",
    dependencies: [
        .package(url: repo, from: "3.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "Dealer",
            dependencies: [
                .product(
                    name:"DeckOfPlayingCards",
                    package: "example-package-deckofplayingcards"
                )
            ]
        )
    ]
)
