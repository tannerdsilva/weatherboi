// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription
let package = Package(
    name: "weatherboi",
    products: [
        .executable(
            name: "weatherboi",
            targets: ["weatherboi"]
        ),
    ],
	dependencies:[
		.package(url:"https://github.com/tannerdsilva/QuickJSON.git", revision:"0b39243100c1ac7158dc6ec9983797caaded8b25") /* v2 gm commit */,
		// vx dependencies ready to go
		.package(url:"https://github.com/swift-server/async-http-client.git", "1.24.2"..<"2.0.0"),
		.package(url:"https://github.com/apple/swift-log.git", "1.6.3"..<"2.0.0"),
		.package(url:"https://github.com/tannerdsilva/rawdog.git", "17.0.0"..<"18.0.0"),
		.package(url:"https://github.com/hummingbird-project/hummingbird.git", "2.9.0"..<"3.0.0"),
		.package(url:"https://github.com/swift-server/swift-service-lifecycle.git", "2.6.3"..<"3.0.0"),
		.package(url:"https://github.com/apple/swift-argument-parser.git", "1.5.0"..<"2.0.0"),
		.package(url:"https://github.com/tannerdsilva/QuickLMDB.git", "11.1.0"..<"12.0.0"),
		.package(url:"https://github.com/tannerdsilva/bedrock.git", "2.1.0"..<"3.0.0")
	],
    targets: [
		.plugin(
			name: "GitCommitInfoPlugin",
			capability: .buildTool()
		),
        .executableTarget(
            name: "weatherboi",
            dependencies:[
            	.product(name:"ArgumentParser", package:"swift-argument-parser")
            ],
            plugins:[
            	"GitCommitInfoPlugin"
            ]
		),
    ]
)
