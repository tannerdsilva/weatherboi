// swift-tools-version: 6.2
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
		.package(url:"https://github.com/tannerdsilva/rawdog.git", "20.0.0"..<"21.0.0"),
		.package(url:"https://github.com/hummingbird-project/hummingbird.git", "2.9.0"..<"3.0.0"),
		.package(url:"https://github.com/apple/swift-argument-parser.git", "1.6.1"..<"2.0.0"),
		.package(url:"https://github.com/swift-server/swift-service-lifecycle", "2.4.0"..<"3.0.0"),
		.package(url:"https://github.com/tannerdsilva/QuickLMDB.git", "14.0.0"..<"14.1.0"),
		.package(url:"https://github.com/tannerdsilva/bedrock.git", "7.0.1"..<"8.0.0"),
		.package(url:"https://github.com/bwyma1/negentropy-swift", revision:"446fdf3a99678df9f6add22c7046e02bb8bc3e70"),
		.package(url:"https://github.com/tannerdsilva/wireguard-swift", revision:"dd0f51771d422c458fa23126a85efe9f1abde0b8")
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
				.product(name:"RAW_base64", package:"rawdog"),
				.product(name:"wireguard-userspace-nio", package:"wireguard-swift"),
				.product(name:"negentropy-swift", package:"negentropy-swift")
            ],
            plugins:[
            	"GitCommitInfoPlugin"
            ]
		),
    ]
)
