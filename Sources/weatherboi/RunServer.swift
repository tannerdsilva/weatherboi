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

		func run() async throws {
			let homeDirectory = Path(FileManager.default.homeDirectoryForCurrentUser.path)
			let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
			let mainDB = try WxDB(base:homeDirectory, logLevel:.trace)
			let server = try HTTPServer(eventLoopGroupProvider: .shared(eventLoopGroup), port: 8080, wxDB:mainDB, logLevel:.trace)
			try await ServiceGroup(services:[server], gracefulShutdownSignals:[.sigterm, .sigint], logger:Logger(label:"weatherboi.server")).run()
		}
	}
}