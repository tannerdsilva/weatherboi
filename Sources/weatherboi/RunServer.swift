import ArgumentParser
import Hummingbird
import NIO
import ServiceLifecycle
import Logging
import bedrock

extension CLI {
	struct Run:AsyncParsableCommand {
		static let configuration = CommandConfiguration(
			commandName: "run",
			abstract: "Run the weatherboi server."
		)

		@Option(help:"the path to the database directory, defaults to the user's home directory")
		var databasePath:String = CLI.defaultDBBasePath()

		@Argument(help:"the ipv4 address to bind the http server for listening on")
		var bindV4:String

		@Argument(help:"the ipv6 address to bind the http server for listening on")
		var bindV6:String

		@Argument(help:"the port to bind the http server for listening on")
		var port:UInt16

		func run() async throws {
			let homeDirectory = Path(databasePath)
			let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
			let metadataDB = try MetadataDB(base:homeDirectory, logLevel:.debug)
			let rainDB = try RainDB(base:homeDirectory, logLevel:.debug)
			let mainDB = try WxDB(base:homeDirectory, logLevel:.debug)
			let server = try HTTPServer(eventLoopGroupProvider:.shared(eventLoopGroup), bindV4:bindV4, bindV6:bindV6, port:Int(port), metadataDB:metadataDB, rainDB:rainDB, wxDB:mainDB, logLevel:.debug)
			try await ServiceGroup(services:[server], gracefulShutdownSignals:[.sigterm, .sigint], logger:Logger(label:"weatherboi.server")).run()
		}
	}
}