// swift-tools-version: 5.9
import PackageDescription

// Pure fitness maths for Noop Aura: heart-rate zones, training load, muscular load, muscle freshness,
// cardio focus and heart-rate recovery. No HealthKit, no UI, no storage — the app adapts its own
// workout and set records into the input types here, so every number is testable with `swift test`.
let package = Package(
    name: "StrandFitness",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "StrandFitness", targets: ["StrandFitness"])],
    targets: [
        .target(name: "StrandFitness"),
        .testTarget(name: "StrandFitnessTests", dependencies: ["StrandFitness"]),
    ]
)
