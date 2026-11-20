// swift-tools-version: 6.3

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "MacrosTests",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(
            name: "macrotest",
            targets: [
                "MacroTest",
            ]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/leviouwendijk/Schema.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/swiftlang/swift-syntax.git",
            from: "603.0.0"
        ),
        .package(path: ".."),
    ],
    targets: [
        .executableTarget(
            name: "MacroTest",
            dependencies: [
                .product(name: "Macros", package: "Macros"),
                .product(name: "MacroEngine", package: "Macros"),
                "Schema",
                .product(
                    name: "SwiftSyntax",
                    package: "swift-syntax"
                ),
                .product(
                    name: "SwiftSyntaxBuilder",
                    package: "swift-syntax"
                ),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
