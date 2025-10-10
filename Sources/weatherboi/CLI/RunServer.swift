import ArgumentParser
import Hummingbird
import NIO
import ServiceLifecycle
import Logging
import bedrock
import RAW_dh25519
import RAW_base64
import RAW
import wireguard_userspace_nio
import negentropy_swift

extension CLI {
	struct Run:AsyncParsableCommand {
		static let configuration = CommandConfiguration(
			commandName: "run",
			abstract: "Run the weatherboi server."
		)

		@Option(help:"the path to the database directory, defaults to the user's home directory")
		var databasePath:Path = CLI.defaultDBBasePath()

		@Argument(help:"the ipv4 address to bind the http server for listening on")
		var bindV4:String

		@Argument(help:"the ipv6 address to bind the http server for listening on")
		var bindV6:String

		@Argument(help:"the port to bind the http server for listening on")
		var port:UInt16
		
		@Argument(help: "The IP address of the responder.")
		var ipAddress:String
		@Argument(help: "The port number that the I am is listening on.")
		var myPort:Int
		@Argument(help:"The private key that the initiator will use to forge an initial handshake.")
		var myPrivateKey:MemoryGuarded<RAW_dh25519.PrivateKey>
		@Argument(help:"The port and public key that the responder is expected to be operating with.")
		var peers:Peer

		func run() async throws {
			let cliLogger = Logger(label: "wg-test-tool.initiator")
			
			let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
			let metadataDB = try MetadataDB(base:databasePath, logLevel:.debug)
			let rainDB = try RainDB(base:databasePath, logLevel:.debug)
			let mainDB = try WxDB(base:databasePath, logLevel:.debug)
			let server = try HTTPServer(eventLoopGroupProvider:.shared(eventLoopGroup), bindV4:bindV4, bindV6:bindV6, port:Int(port), metadataDB:metadataDB, rainDB:rainDB, wxDB:mainDB, logLevel:.debug)
			_ = try await withThrowingTaskGroup(body: { foo in
				foo.addTask {
					try await ServiceGroup(services:[server], gracefulShutdownSignals:[.sigterm, .sigint], logger:Logger(label:"weatherboi.server")).run()
				}
				
				var myPeers:[PeerInfo] = []
				myPeers.append(PeerInfo(publicKey:peers.publicKey, ipAddress:ipAddress, port: peers.port, internalKeepAlive: .seconds(30)))
				let myInterface = try WGInterface<[UInt8]>(staticPrivateKey:myPrivateKey, mtu:1400, initialConfiguration:myPeers, logLevel:.debug, listeningPort: myPort)
				
				foo.addTask {
					try await myInterface.run()
				}
				
				cliLogger.info("WireGuard interface started. Waiting for channel initialization...")
				try await myInterface.waitForChannelInit()
				
				// Task for receiving sync calls
				foo.addTask {
					var ne = try Negentropy(storage: mainDB.windspeed, frameSizeLimit: 20_000, buckets: 20, logLevel:.info)
					
					let iterator = myInterface.makeAsyncIterator()
					syncLoop: while(true) {
						// Wait to receive message of data
						rcvData: do {
							if let (_, incomingData) = try await iterator.next() {
								
								// Checking if it's a responder type message, react accordingly
								do {
									let newMsg = try ne.reconcile(query: incomingData)
									try await myInterface.write(publicKey: peers.publicKey, data: newMsg)
									break rcvData
								} catch { }
								
								// Checking if it's a data query message
								if(incomingData.count == MemoryLayout<DateUTC>.size) {
									let date = incomingData.withUnsafeBufferPointer { arrPtr in
										return DateUTC(RAW_staticbuff: arrPtr.baseAddress!)
									}
									let weatherReport = try mainDB.getWeatherReport(date: date)
									try await myInterface.write(publicKey: peers.publicKey, data: incomingData + weatherReport)
									break rcvData
								}
//								
//								// Checking if it's a data message
//								let date = incomingData.withUnsafeBufferPointer { ptr in
//									return DateUTC(RAW_staticbuff: ptr.baseAddress!)
//								}
//								let weatherData = incomingData.dropFirst(MemoryLayout<DateUTC>.size)
//								let weatherReport = WeatherReport(Array(weatherData))
//								try mainDB.scribeNewData(date: date, weatherReport, logLevel: .debug)
							}
						}
					}
				}
			})
		}
	}
}
