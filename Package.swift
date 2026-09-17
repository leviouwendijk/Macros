// swift-tools-version: 6.3

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "Macros",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "Macros",
            targets: [
                "Macros",
            ]
        ),
        .library(
            name: "MacroEngine",
            targets: [
                "MacroEngine",
            ]
        ),
        .executable(
            name: "macrotest",
            targets: [
                "MacroTest",
            ]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/leviouwendijk/Primitives.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Schema.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/swiftlang/swift-syntax.git",
            from: "603.0.0"
        ),
    ],
    targets: [
        .target(
            name: "Macros",
            dependencies: [
                .product(
                    name: "Primitives",
                    package: "Primitives"
                ),
                .product(
                    name: "Schema",
                    package: "Schema"
                ),
                "MacrosPlugin",
            ]
        ),
        .target(
            name: "MacroEngine",
            dependencies: [
                .product(
                    name: "SwiftSyntax",
                    package: "swift-syntax"
                ),
                .product(
                    name: "SwiftSyntaxBuilder",
                    package: "swift-syntax"
                ),
                .product(
                    name: "SwiftSyntaxMacros",
                    package: "swift-syntax"
                ),
            ]
        ),
        .executableTarget(
            name: "MacroTest",
            dependencies: [
                "Macros",
                "Schema",
            ]
        ),
        .macro(
            name: "MacrosPlugin",
            dependencies: [
                .product(
                    name: "Primitives",
                    package: "Primitives"
                ),
                .product(
                    name: "SwiftCompilerPlugin",
                    package: "swift-syntax"
                ),
                .product(
                    name: "SwiftSyntax",
                    package: "swift-syntax"
                ),
                .product(
                    name: "SwiftSyntaxBuilder",
                    package: "swift-syntax"
                ),
                .product(
                    name: "SwiftSyntaxMacros",
                    package: "swift-syntax"
                ),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
