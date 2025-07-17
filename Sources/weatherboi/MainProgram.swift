import ArgumentParser
import class Foundation.FileManager
import struct Foundation.Date
import class Foundation.ISO8601DateFormatter
import bedrock
import Logging
import struct QuickLMDB.Transaction

@main
struct CLI:AsyncParsableCommand {
	static func defaultDBBasePath() -> Path {
		return Path(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("weatherboi_lmdb").path)
	}

	static let configuration = CommandConfiguration(
		commandName:"weatherboi",
		abstract:"a highly efficient daemon for capturing, storing, and redistributing data from on-premises weather stations.",
		version:"\(GitRepositoryInfo.tag) (\(GitRepositoryInfo.commitHash))\(GitRepositoryInfo.commitRevisionHash != nil ? " commit revision: \(GitRepositoryInfo.commitRevisionHash!.prefix(8))" : "")",
		subcommands:[
			Run.self,
			Rain.self
		]
	)

	struct Rain:AsyncParsableCommand {
		static let configuration = CommandConfiguration(
			commandName:"rain",
			abstract:"a subcommand for rain-related operations.",
			subcommands:[
				Scribe.self,
				List.self,
				Clear.self,
				CurrentRate.self
			]
		)

		struct Clear:ParsableCommand {
			static let configuration = CommandConfiguration(
				commandName:"clear",
				abstract:"a subcommand for clearing rain data."
			)

			@Option(help:"the path to the database directory, defaults to the user's home directory")
			var databasePath:Path = CLI.defaultDBBasePath()

			func run() throws {
				let logger = Logger(label:"weatherboi.rain.clear")
				let homeDirectory = Path(FileManager.default.homeDirectoryForCurrentUser.path)
				try RainDB.deleteDatabase(base:homeDirectory, logLevel:.trace)
				let metaDB = try MetadataDB(base:homeDirectory, logLevel:.trace)
				try metaDB.clearCumulativeRainValue(logLevel:.trace)
				logger.info("successfully cleared rain database")
			}
		}

		struct Scribe:ParsableCommand {
			static let configuration = CommandConfiguration(
				commandName:"scribe",
				abstract:"a subcommand for scribing rain data."
			)

			@Option(help:"the path to the database directory, defaults to the user's home directory")
			var databasePath:Path = CLI.defaultDBBasePath()

			@Argument
			var cumulativeAmount:Double

			func run() throws {
				let logger = Logger(label:"weatherboi.rain.scribe")
				let metaDB = try MetadataDB(base:databasePath, logLevel:.trace)
				let rainDB = try RainDB(base:databasePath, logLevel:.trace)
				let newTX = try Transaction(env:metaDB.env, readOnly:false)
				try metaDB.exchangeLastCumulativeRainValue(tx:newTX, cumulativeAmount, afterSwap: { newValue in
					try rainDB.scribeNewIncrementValue(date:DateUTC(), increment:newValue, logLevel:.debug)
				}, logLevel: .trace)
				try newTX.commit()
			}
		}

		struct PullData:AsyncParsableCommand {
			static let configuration = CommandConfiguration(
				commandName:"pull-data",
				abstract:"a subcommand for pulling rain data from a remote source."
			)

			@Option(help:"the path to the database directory, defaults to the user's home directory")
			var databasePath:Path = CLI.defaultDBBasePath()

			@Argument(help:"the date to pull data for, in the format ISO8601 (e.g., 2023-10-01T00:00:00Z)")
			var pullDate:String = ISO8601DateFormatter().string(from:Date())

			@Argument(help:"the number of data points to pull data for, defaults to 360")
			var numberOfDataPoints:UInt32 = 360

			@Argument(help:"the interval in seconds between data points, defaults to 60")
			var interval:UInt64 = 60

			func run() async throws {
				let logger = Logger(label:"weatherboi.rain.pull-data")
				let wxdb = try WxDB(base:databasePath, logLevel:.trace)
				try await wxdb.pullData(date:DateUTC(seconds:bedrock.Date.Seconds(RAW_native:UInt64(ISO8601DateFormatter().date(from:pullDate)!.timeIntervalSince1970))), dataPointCount:numberOfDataPoints, dataPointInterval:interval)
				logger.info("successfully pulled rain data")
			}
		}

		struct CurrentRate:ParsableCommand {
			static let configuration = CommandConfiguration(
				commandName:"current-rate",
				abstract:"a subcommand for calculating the current rain rate."
			)

			@Option(help:"the path to the database directory, defaults to the user's home directory")
			var databasePath:Path = CLI.defaultDBBasePath()

			func run() throws {
				let logger = Logger(label:"weatherboi.rain.current-rate")
				let rainDB = try RainDB(base:databasePath, logLevel:.trace)
				let currentRate = try rainDB.calculateRainPerHour(at:DateUTC(), logLevel:.trace)
				logger.info("current rain rate: \(currentRate)")
			}
		}

		struct List:ParsableCommand {
			static let configuration = CommandConfiguration(
				commandName:"list",
				abstract:"a subcommand for listing rain data."
			)

			@Option(help:"the path to the database directory, defaults to the user's home directory")
			var databasePath:Path = CLI.defaultDBBasePath()

			func run() throws {
				let logger = Logger(label:"weatherboi.rain.list")
				let rainDB = try RainDB(base:databasePath, logLevel:.trace)
				let allData = try rainDB.listAllRainData(logLevel:.debug)
				var sumValue:Double = 0
				for (date, value) in allData.sorted(by: { $0.key < $1.key }) {
					logger.info("rain data for \(date): \(value)")
					sumValue += Double(value)
				}
				logger.info("total rain data: \(UInt32(sumValue))")
			}
		}
	}
}


extension Path:@retroactive ExpressibleByArgument {
	public init?(argument:String) {
		self.init(argument)
	}
	public var description:String {
		return self.path()
	}
}