// swift-tools-version: 5.10
// Package.swift — enables building the Deeper analytics server with Swift Package Manager.
// The macOS GUI app continues to be built with Xcode as before.

import PackageDescription

let package = Package(
    name: "DeeperServer",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.115.0"),
    ],
    targets: [
        // Single executable target: bundles the portable core sources together with
        // the Vapor server entry point so all types share the same module (no need
        // for `public` access modifiers on existing internal types).
        // BeeperOAuthService is excluded because it uses AppKit/AuthenticationServices.
        .executableTarget(
            name: "DeeperServer",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
            ],
            path: ".",
            sources: [
                "Deeper/Models/AnalyticsModels.swift",
                "Deeper/Models/BeeperModels.swift",
                "Deeper/Models/GroupStats.swift",
                "Deeper/Models/MergedPerson.swift",
                "Deeper/Models/PlatformInfo.swift",
                "Deeper/Services/BeeperAPIClient.swift",
                "Deeper/Services/DataStore.swift",
                "Deeper/Services/KeychainHelper.swift",
                "Deeper/Services/PersonMerger.swift",
                "Deeper/Services/ReelsAnalyzer.swift",
                "Deeper/Services/WebSocketManager.swift",
                "Deeper/ViewModels/DashboardViewModel.swift",
                "Sources/DeeperServer/entrypoint.swift",
            ]
        ),
    ]
)
