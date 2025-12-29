// swift-tools-version:6.2
import PackageDescription

let package = Package(
	name: "RSCore",
	platforms: [.iOS(.v26)],
	products: [
		.library(name: "RSCore", type: .dynamic, targets: ["RSCore"]),
		.library(name: "RSCoreObjC", type: .dynamic, targets: ["RSCoreObjC"])
	],
	targets: [
		.target(
			name: "RSCore",
			dependencies: ["RSCoreObjC"],
			swiftSettings: [
				.enableUpcomingFeature("NonisolatedNonsendingByDefault"),
				.enableUpcomingFeature("InferIsolatedConformances"),
			]
		),
		.target(
			name: "RSCoreObjC",
			dependencies: [],
			cSettings: [
				.headerSearchPath("include")
			]
		),
		.testTarget(
			name: "RSCoreTests",
			dependencies: ["RSCore"],
			resources: [.copy("Resources")],
			swiftSettings: [.swiftLanguageMode(.v5)]
		),
	]
)
