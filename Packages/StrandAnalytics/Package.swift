// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "StrandAnalytics",
    platforms: [.macOS(.v13), .iOS(.v16), .watchOS(.v10)],
    products: [.library(name: "StrandAnalytics", targets: ["StrandAnalytics"])],
    dependencies: [
        .package(path: "../WhoopProtocol"),
        .package(path: "../WhoopStore"),
        // Multi-domain Fitness Age scoring. Foundation-only and deterministic, so the mapping from NOOP's
        // own metrics onto its inputs stays here in the pure package where `swift test` covers it without
        // an app, a strap, or HealthKit. Pinned EXACT: upstream states minor releases may change results.
        .package(url: "https://github.com/superageapp/ios-core.git", exact: "0.4.0"),
    ],
    targets: [
        .target(name: "StrandAnalytics", dependencies: [
            "WhoopProtocol", "WhoopStore",
            .product(name: "SuperAgeCore", package: "ios-core"),
        ]),
        // WhoopStore is declared on the TEST target as well as the library: the Oura respiration
        // scoring-exclusion tests assert on `OuraRespScale` (the seam that keeps the ring's 0x6A rows
        // out of the stager), and a transitively-visible module is not something a test should rely on.
        .testTarget(name: "StrandAnalyticsTests", dependencies: ["StrandAnalytics", "WhoopStore"]),
    ]
)
