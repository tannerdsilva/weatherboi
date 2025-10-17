import ArgumentParser
import bedrock
import wireguard_userspace_nio
import RAW_dh25519
import RAW
import Logging
import bedrock_ip
import negentropy_swift
import QuickLMDB

extension CLI {
	struct Sync:AsyncParsableCommand {
		static let configuration = CommandConfiguration(
			commandName: "sync",
			abstract: "Sync with another weatherboi server."
		)
		
		@Option(help:"the path to the database directory, defaults to the user's home directory")
		var databasePath:Path = CLI.defaultDBBasePath()

		@Argument(help: "The IP address of the responder.")
		var ipAddress:String
		@Argument(help: "The port number that the I am is listening on.")
		var myPort:Int
		@Argument(help:"The private key that the initiator will use to forge an initial handshake.")
		var myPrivateKey:MemoryGuarded<RAW_dh25519.PrivateKey>
		@Argument(help:"The port and public key that the responder is expected to be operating with.")
		var peers:Peer

		func run() async throws {
			let mainDB = try WxDB(base:databasePath, logLevel:.debug)
			let cliLogger = Logger(label: "wg.initiator")
			cliLogger.logLevel = .debug
			
			_ = try await withThrowingTaskGroup(body: { foo in
				var myPeers:[PeerInfo] = []
				myPeers.append(PeerInfo(publicKey:peers.publicKey, ipAddress:ipAddress, port: peers.port, internalKeepAlive: .seconds(30)))
				let myInterface = try WGInterface<[UInt8]>(staticPrivateKey:myPrivateKey, mtu:1400, initialConfiguration:myPeers, logLevel:.info, listeningPort: myPort)
				
				foo.addTask {
					try await myInterface.run()
				}
				
				cliLogger.info("WireGuard interface started. Waiting for channel initialization...")
				try await myInterface.waitForChannelInit()
				
				// Negentropy syncing task
				cliLogger.debug("Initializing Negentropy object")
				var ne = try Negentropy(storage: mainDB.windspeed, frameSizeLimit: 20_000, buckets: 20, logLevel:.debug)
				
				// Send syncing initiation message
				cliLogger.debug("Initiating Negentropy Sync")
				let msg = try ne.initiate()
				try await myInterface.write(publicKey: peers.publicKey, data: msg)
				cliLogger.debug("Sent initial Negentropy Sync message")
				
				var allHave:[DateUTC] = []
				var allNeed:[DateUTC] = []
				var breakCount = 9999
				
				let iterator = myInterface.makeAsyncIterator()
				syncLoop: while(true) {
					// Wait to receive message of data
					rcvData: do {
						if let (_, incomingData) = try await iterator.next() {
							
							// Checking if it's an initiator type message, react accordingly
							do {
								var have:[DateUTC] = []
								var need:[DateUTC] = []
								let newMsg = try ne.reconcile(query: incomingData, haveIds: &have, needIds: &need)
								allHave.append(contentsOf: have)
								allNeed.append(contentsOf: need)
								
								if(newMsg != nil) {
									try await myInterface.write(publicKey: peers.publicKey, data: newMsg!)
								} else {
									cliLogger.info("Negentropy messaging complete. Sending data/query messages.")
									// Send all of the data for the ID's we have
									breakCount = allHave.count
									for date in allHave {
										let dateArray = date.RAW_access { ptr in
											return Array(UnsafeBufferPointer(start: ptr.baseAddress!, count: MemoryLayout<DateUTC>.size))
										}
										let weatherReport = try mainDB.getWeatherReport(date: date)
										try await myInterface.write(publicKey: peers.publicKey, data: dateArray + weatherReport)
									}
									// Send data query messages for the ID's we need
									for date in allNeed {
										let dateArray = date.RAW_access { ptr in
											return Array(UnsafeBufferPointer(start: ptr.baseAddress!, count: MemoryLayout<DateUTC>.size))
										}
										try await myInterface.write(publicKey: peers.publicKey, data: dateArray)
									}
								}
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
							
							// Checking if it's a data message
							let date = incomingData.withUnsafeBufferPointer { ptr in
								return DateUTC(RAW_staticbuff: ptr.baseAddress!)
							}
							let weatherData = incomingData.dropFirst(MemoryLayout<DateUTC>.size)
							let weatherReport = WeatherReport(Array(weatherData))
							try mainDB.scribeNewData(date: date, weatherReport, logLevel: .debug, flags: [])
							breakCount -= 1
							if(breakCount <= 0) {
								break syncLoop
							}
						}
					}
				}
				foo.cancelAll()
			})
		}
	}
}
