// swift-tools-version: 6.0
//
//  Package.swift
//  SwiftKLine
//
//  Created by zhwayne on 2025/04/13.
//

import PackageDescription

let package = Package(
    name: "SwiftKLine",
    platforms: [.iOS(.v13), .macOS(.v10_15)],
    products: [
        .library(name: "SwiftKLine", targets: ["SwiftKLine"]),
        .library(name: "SwiftKLineCore", targets: ["SwiftKLineCore"])
    ],
    targets: [
        .target(name: "SwiftKLineCore"),
        .target(name: "SwiftKLineUI", dependencies: ["SwiftKLineCore"]),
        .target(name: "SwiftKLineSwiftUI", dependencies: ["SwiftKLineUI", "SwiftKLineCore"]),
        .target(name: "SwiftKLine", dependencies: [
            "SwiftKLineCore",
            .target(name: "SwiftKLineUI", condition: .when(platforms: [.iOS])),
            .target(name: "SwiftKLineSwiftUI", condition: .when(platforms: [.iOS]))
        ]),
        .executableTarget(name: "SwiftKLineBenchmark", dependencies: ["SwiftKLineCore"], path: "Benchmarks"),
        .testTarget(name: "SwiftKLineCoreTests", dependencies: ["SwiftKLineCore"]),
        // Compile application-owned overlays in a test bundle, never in a library product.
        .testTarget(name: "SwiftKLineExampleTests", dependencies: [
            "SwiftKLine",
            .target(name: "SwiftKLineUI", condition: .when(platforms: [.iOS]))
        ], path: "SwiftKLineExample/TradeMarkers"),
        .testTarget(name: "SwiftKLineTests", dependencies: [
            "SwiftKLine",
            .target(name: "SwiftKLineUI", condition: .when(platforms: [.iOS]))
        ])
    ],
    swiftLanguageModes: [.v6]
)
