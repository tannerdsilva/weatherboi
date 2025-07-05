import ArgumentParser
import Hummingbird
import NIO
import class Foundation.FileManager
import ServiceLifecycle
import Logging

extension CLI {
	struct Run:AsyncParsableCommand {
		static let configuration = CommandConfiguration(
			commandName: "run",
			abstract: "Run the weatherboi server."
		)

		func run() async throws {
			let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
			let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
			let server = try HTTPServer(eventLoopGroupProvider: .shared(eventLoopGroup), port: 8080)
			try await ServiceGroup(services:[server], gracefulShutdownSignals:[.sigterm, .sigint], logger:Logger(label:"weatherboi.server")).run()
		}
	}
}