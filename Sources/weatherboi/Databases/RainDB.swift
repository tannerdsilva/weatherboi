import QuickLMDB
import RAW
import Logging
import bedrock
import class Foundation.FileManager

public struct RainDB:Sendable {
	private let log:Logger
	private let env:Environment
	private let main:Database.Strict<DateUTC, FourDigitDecimalPrecisionValue>
	public static func deleteDatabase(base:Path, logLevel:Logger.Level) throws {
		let finalPath = base.appendingPathComponent("weatherboi-wxdb_rain.mdb")
		var makeLogger = Logger(label:"\(String(describing:Self.self))")
		makeLogger.logLevel = logLevel
		makeLogger.debug("deleting rain database", metadata:["path":"\(finalPath.path())"])
		try FileManager.default.removeItem(atPath:finalPath.path())
		makeLogger.info("successfully deleted rain database")
	}

	public init(base:Path, logLevel:Logger.Level) throws {
		let finalPath = base.appendingPathComponent("weatherboi-wxdb_rain.mdb")
		let memoryMapSize = size_t(finalPath.getFileSize() + 512 * 1024 * 1024 * 1024) // add 64gb to the file size to allow for growth
		var makeLogger = Logger(label:"\(String(describing:Self.self))")
		makeLogger.logLevel = logLevel
		log = makeLogger
		makeLogger.debug("initializing rain database", metadata:["path":"\(finalPath.path())", "memoryMapSize":"\(memoryMapSize)b"])
		env = try Environment(path:finalPath.path(), flags:[.noSubDir], mapSize:memoryMapSize, maxReaders:8, maxDBs:1, mode:[.ownerReadWriteExecute, .groupReadExecute, .otherReadExecute])
		makeLogger.trace("created environment. now creating initial transaction", metadata:["path":"\(finalPath.path())", "memoryMapSize":"\(memoryMapSize)b"])
		let newTrans = try Transaction(env:env, readOnly:false)
		makeLogger.trace("created initial transaction. now creating main database", metadata:["path":"\(finalPath.path())", "memoryMapSize":"\(memoryMapSize)b"])
		main = try Database.Strict<DateUTC, FourDigitDecimalPrecisionValue>(env:env, name:nil, flags:[.create], tx:newTrans)
		makeLogger.trace("created main database. now committing transaction", metadata:["path":"\(finalPath.path())", "memoryMapSize":"\(memoryMapSize)b"])
		try newTrans.commit()
	}

	public func scribeNewIncrementValue(date:DateUTC, increment:FourDigitDecimalPrecisionValue, logLevel:Logger.Level) throws {
		var logger = log
		logger.logLevel = logLevel
		logger[metadataKey:"store_date"] = "\(date)"
		logger[metadataKey:"rain_increment_value"] = "\(increment)"
		logger.trace("opening transaction to write data")
		let newTrans = try Transaction(env:env, readOnly:false)
		logger.trace("transaction successfully opened")
		try main.cursor(tx:newTrans) { cursor in
			do {
				let existingDate = try cursor.opLast().key
				guard existingDate < date else {
					logger.error("attempted to write rain data for date that was older than the latest date in the database", metadata:["existingDate":"\(existingDate)"])
					throw LMDBError.keyExists
				}
			} catch LMDBError.notFound {}
			logger.trace("date validated as incremental. now writing rain value.")
			try cursor.setEntry(key:date, value:increment, flags:[.append])			
		}
		try newTrans.commit()
		logger.debug("successfully wrote incremental rain data")
	}

	public func calculateRainPerHour(at inputDate:DateUTC, logLevel:Logger.Level) throws -> FourDigitDecimalPrecisionValue {
		var logger = log
		logger.logLevel = logLevel
		logger[metadataKey:"input_date"] = "\(inputDate)"
		var targetDate = inputDate - (60 * 10) // 10 minutes before the input date
		logger.trace("looking for rain data from input date to target date", metadata:["target_date":"\(targetDate)"])
		let newTrans = try Transaction(env:env, readOnly:true)
		logger.trace("transaction successfully opened", metadata:["target_date":"\(targetDate)"])
		return try main.cursor(tx:newTrans) { cursor in
			var cumulativeRain:FourDigitDecimalPrecisionValue = 0
			logger.trace("cursor successfully opened. now using lmdb range seek to the target date", metadata:["target_date":"\(targetDate)"])
			var currentRain:FourDigitDecimalPrecisionValue
			do {
				(targetDate, currentRain) = try cursor.opSetRange(key:targetDate)
			} catch LMDBError.notFound {
				logger.trace("no rain data found for target date. returning 0", metadata:["target_date":"\(targetDate)"])
				return 0
			}
			guard targetDate < inputDate else {
				logger.trace("first target date exceeds input date. returning 0", metadata:["target_date":"\(targetDate)", "input_date":"\(inputDate)"])
				return 0
			}
			seekForwardLoop: repeat {
				cumulativeRain += currentRain
				logger.debug("found rain data for target date", metadata:["target_date":"\(targetDate)", "current_increment":"\(currentRain)", "current_cumulative_rain":"\(cumulativeRain)"])
				do {
					(targetDate, currentRain) = try cursor.opNext()
				} catch LMDBError.notFound {
					logger.trace("no more rain data found in cursor. breaking seek loop", metadata:["current_cumulative_rain":"\(cumulativeRain)"])
					break seekForwardLoop
				}
			} while targetDate < inputDate
			return cumulativeRain
		}
	}

	public func listAllRainData(logLevel:Logger.Level) throws -> [DateUTC:FourDigitDecimalPrecisionValue] {
		var logger = log
		logger.logLevel = logLevel
		logger.trace("opening transaction to read data")
		let newTrans = try Transaction(env:env, readOnly:true)
		logger.trace("transaction successfully opened")
		var allData:[DateUTC:FourDigitDecimalPrecisionValue] = [:]
		try main.cursor(tx:newTrans) { cursor in
			logger.trace("cursor successfully opened")
			for (key, value) in cursor {
				logger.trace("found rain data for date \(key) with value \(value)")
				allData[key] = value
			}
		}
		try newTrans.commit()
		return allData
	}
}