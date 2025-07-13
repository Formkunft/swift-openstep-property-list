// swift-tools-version: 6.1
import PackageDescription

let package = Package(
	name: "swift-openstep-property-list",
	products: [
		.library(
			name: "OpenStepPropertyList",
			targets: ["OpenStepPropertyList"]),
	],
	traits: [
		.trait(
			name: "TraitFoundation",
			description: "Use Foundation framework"),
		.trait(
			name: "TraitSpan",
			description: "Use Span values"),
		.default(
			enabledTraits: [
				"TraitFoundation",
			]),
	],
	dependencies: [
		.package(url: "https://github.com/Formkunft/swift-collection-parser", .upToNextMajor(from: "2.0.0")),
	],
	targets: [
		.target(
			name: "OpenStepPropertyList",
			dependencies: [
				.product(name: "CollectionParser", package: "swift-collection-parser"),
			]
		),
		.testTarget(
			name: "OpenStepPropertyListTests",
			dependencies: ["OpenStepPropertyList"]),
	]
)
