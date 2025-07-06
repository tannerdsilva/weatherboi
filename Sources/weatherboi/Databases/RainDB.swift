import QuickLMDB
import RAW
import Logging
import bedrock

public struct RainDB:Sendable {
	private let log:Logger
	private let env:Environment
	private let main:Database.Strict<DateUTC, EncodedDouble>
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
		main = try Database.Strict<DateUTC, EncodedDouble>(env:env, name:nil, flags:[.create], tx:newTrans)
		makeLogger.trace("created main database. now committing transaction", metadata:["path":"\(finalPath.path())", "memoryMapSize":"\(memoryMapSize)b"])
		try newTrans.commit()
	}
	public func scribeNewIncrementValue(date:DateUTC, increment:EncodedDouble, logLevel:Logger.Level) throws {
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
}