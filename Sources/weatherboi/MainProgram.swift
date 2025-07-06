import ArgumentParser
import class Foundation.FileManager
import bedrock
import Logging
import struct QuickLMDB.Transaction

@main
struct CLI:AsyncParsableCommand {
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

			@Argument
			var cumulativeAmount:Double

			func run() throws {
				let logger = Logger(label:"weatherboi.rain.scribe")
				let homeDirectory = Path(FileManager.default.homeDirectoryForCurrentUser.path)
				let metaDB = try MetadataDB(base:homeDirectory, logLevel:.trace)
				let rainDB = try RainDB(base:homeDirectory, logLevel:.trace)
				let newTX = try Transaction(env:metaDB.env, readOnly:false)
				try metaDB.exchangeLastCumulativeRainValue(tx:newTX, cumulativeAmount, afterSwap: { newValue in
					try rainDB.scribeNewIncrementValue(date:DateUTC(), increment:newValue, logLevel:.debug)
				}, logLevel: .trace)
				try newTX.commit()
			}
		}

		struct CurrentRate:ParsableCommand {
			static let configuration = CommandConfiguration(
				commandName:"current-rate",
				abstract:"a subcommand for calculating the current rain rate."
			)

			func run() throws {
				let logger = Logger(label:"weatherboi.rain.current-rate")
				let homeDirectory = Path(FileManager.default.homeDirectoryForCurrentUser.path)
				let rainDB = try RainDB(base:homeDirectory, logLevel:.trace)
				let currentRate = try rainDB.calculateRainPerHour(at:DateUTC(), logLevel:.trace)
				logger.info("current rain rate: \(currentRate)")
			}
		}

		struct List:ParsableCommand {
			static let configuration = CommandConfiguration(
				commandName:"list",
				abstract:"a subcommand for listing rain data."
			)

			func run() throws {
				let logger = Logger(label:"weatherboi.rain.list")
				let homeDirectory = Path(FileManager.default.homeDirectoryForCurrentUser.path)
				let rainDB = try RainDB(base:homeDirectory, logLevel:.trace)
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
