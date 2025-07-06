import ArgumentParser
import Hummingbird
import NIO
import class Foundation.FileManager
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
		var databasePath:String = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("weatherboi_lmdb").path

		@Argument(help:"the port to bind the http server for listening on")
		var port:UInt16

		func run() async throws {
			let homeDirectory = Path(databasePath)
			let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
			let metadataDB = try MetadataDB(base:homeDirectory, logLevel:.trace)
			let rainDB = try RainDB(base:homeDirectory, logLevel:.trace)
			let mainDB = try WxDB(base:homeDirectory, logLevel:.trace)
			let server = try HTTPServer(eventLoopGroupProvider:.shared(eventLoopGroup), port:Int(port), metadataDB:metadataDB, rainDB:rainDB, wxDB:mainDB, logLevel:.info)
			try await ServiceGroup(services:[server], gracefulShutdownSignals:[.sigterm, .sigint], logger:Logger(label:"weatherboi.server")).run()
		}
	}
}