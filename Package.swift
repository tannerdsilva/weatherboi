// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription
let package = Package(
    name: "weatherboi",
	platforms:[
		.macOS(.v15)
	],
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
		// .package(url:"https://github.com/tannerdsilva/bedrock.git", "4.0.0"..<"5.0.0")
		.package(name:"bedrock", path:"../bedrock"),
	],
    targets: [
		.plugin(
			name: "GitCommitInfoPlugin",
			capability: .buildTool()
		),
        .executableTarget(
            name: "weatherboi",
            dependencies:[
            	.product(name:"ArgumentParser", package:"swift-argument-parser"),
				.product(name:"Hummingbird", package:"hummingbird"),
				.product(name:"RAW", package:"rawdog"),
				.product(name:"QuickJSON", package:"QuickJSON"),
				.product(name:"QuickLMDB", package:"QuickLMDB"),
				.product(name:"ServiceLifecycle", package:"swift-service-lifecycle"),
				.product(name:"AsyncHTTPClient", package:"async-http-client"),
				.product(name:"Logging", package:"swift-log"),
				.product(name:"bedrock", package:"bedrock"),
            ],
            plugins:[
            	"GitCommitInfoPlugin"
            ]
		),
    ]
)
