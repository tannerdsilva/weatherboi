import QuickLMDB
import RAW
import bedrock
import Logging
import QuickJSON

@RAW_convertible_string_type<UTF8>(backing:RAW_byte.self)
@MDB_comparable()
public struct EncodedString:Sendable, Equatable, Hashable, Comparable, ExpressibleByStringLiteral, CustomDebugStringConvertible {
	public var debugDescription:String {
		return String(self)
	}
}
extension EncodedString:RawRepresentable {
	public init(rawValue:String) {
		self.init(rawValue)
	}
	public var rawValue:String {
		return String(self)
	}
}

@RAW_staticbuff(bytes:8)
@RAW_staticbuff_binaryfloatingpoint_type<Double>()
@MDB_comparable()
public struct EncodedDouble:Sendable, ExpressibleByFloatLiteral, Equatable, Comparable, CustomDebugStringConvertible {
	public var debugDescription:String {
		return "\(RAW_native())"
	}
}

@RAW_staticbuff(bytes:4)
@RAW_staticbuff_fixedwidthinteger_type<UInt32>(bigEndian:true)
@MDB_comparable()
public struct FourDigitDecimalPrecisionValue:Sendable, ExpressibleByIntegerLiteral, Equatable, Comparable, CustomDebugStringConvertible {
	public var debugDescription:String {
		return "\(Double(RAW_native()) / 10000.0)"
	}
	public init(_ value:Double) {
		self.init(RAW_native:UInt32(value * 10000.0))
	}
	public static func - (_ lhs:FourDigitDecimalPrecisionValue, _ rhs:FourDigitDecimalPrecisionValue) -> FourDigitDecimalPrecisionValue {
		return FourDigitDecimalPrecisionValue(RAW_native:lhs.RAW_native() - rhs.RAW_native())
	}
	public static func + (_ lhs:FourDigitDecimalPrecisionValue, _ rhs:FourDigitDecimalPrecisionValue) -> FourDigitDecimalPrecisionValue {
		return FourDigitDecimalPrecisionValue(RAW_native:lhs.RAW_native() + rhs.RAW_native())
	}
	public static func += (_ lhs:inout FourDigitDecimalPrecisionValue, _ rhs:FourDigitDecimalPrecisionValue) {
		lhs = lhs + rhs
	}
}

extension Double {
	public init(_ rawValue:FourDigitDecimalPrecisionValue) {
		self = Double(rawValue.RAW_native()) / 10000.0
	}
}

public typealias EncodedByte = RAW_byte

@RAW_staticbuff(concat:bedrock.Date.Seconds.self)
@MDB_comparable()
public struct DateUTC:Sendable, Equatable, Comparable, CustomDebugStringConvertible, Hashable {
	/// represents the time in seconds since the Unix epoch (January 1, 1970)
	private let seconds:bedrock.Date.Seconds
	public init() {
		seconds = bedrock.Date.Seconds(localTime:false)
	}
	private init(seconds unixTime:bedrock.Date.Seconds) {
		seconds = unixTime
	}
	public var debugDescription:String {
		return "\(seconds.timeIntervalSinceUnixDate())"
	}
	public static func + (_ lhs:DateUTC, _ rhs:UInt64) -> DateUTC {
		return Self(seconds:lhs.seconds + rhs)
	}
	public static func - (_ lhs:DateUTC, _ rhs:UInt64) -> DateUTC {
		return Self(seconds:lhs.seconds - rhs)
	}
}

public struct MetadataDB:Sendable {
	enum Metadatas:EncodedString {
		case ambientWeather_lastCumulativeRainValue = "ambientWeather_lastCumulativeRainValue"
	}
	private let log:Logger
	public let env:Environment
	private let metadata:Database

	public init(base:Path, logLevel:Logger.Level) throws {
		let finalPath = base.appendingPathComponent("weatherboidb-metadata.mdb")
		var makeLogger = Logger(label:"\(String(describing:Self.self))")
		makeLogger.logLevel = logLevel
		log = makeLogger
		let memoryMapSize = size_t(finalPath.getFileSize() + 5 * 1024 * 1024 * 1024) // add 5gb to the file size to allow for growth
		env = try Environment(path:finalPath.path(), flags:[.noSubDir], mapSize:memoryMapSize, maxReaders:16, maxDBs:1, mode:[.ownerReadWriteExecute, .groupReadExecute, .otherReadExecute])
		let newTrans = try Transaction(env:env, readOnly:false)
		metadata = try Database(env:env, name:nil, flags:[.create], tx:newTrans)
		try newTrans.commit()
	}

	public func shouldProceedWithProcessing(deviceIdentifier:EncodedString, logLevel:Logger.Level) throws -> Bool {
		var logger = log
		logger.logLevel = logLevel
		logger[metadataKey:"deviceIdentifier"] = "\(deviceIdentifier)"
		logger.trace("checking if we should proceed with processing for device", metadata:["deviceIdentifier":"\(deviceIdentifier)"])
		
		let newTrans = try Transaction(env:env, readOnly:false)
		logger.trace("successfully opened sub-transaction for checking device identifier")
		do {
			let foundKey = try metadata.loadEntry(key:deviceIdentifier, as:EncodedString.self, tx:newTrans)
			logger.trace("found existing database entry for device identifier", metadata:["foundKey":"\(foundKey)"])
			if foundKey == deviceIdentifier {
				logger.debug("device identifier matches the existing entry, proceeding with processing")
			} else {
				logger.warning("device identifier does not match the existing entry, not proceeding with processing", metadata:["existingKey":"\(foundKey)"])
				return false
			}
		} catch LMDBError.notFound {
			logger.debug("no existing entry found for device identifier, the device id will be stored and used as the exclusive allowed identifier for this device")
			try metadata.setEntry(key:deviceIdentifier, value:deviceIdentifier, flags:[], tx:newTrans)
		}
		try newTrans.commit()
		return true
	}

	public func clearCumulativeRainValue(logLevel:Logger.Level) throws {
		var logger = log
		logger.logLevel = logLevel
		logger.trace("clearing cumulative rain value")
		
		let newTrans = try Transaction(env:env, readOnly:false)
		logger.trace("successfully opened sub-transaction for clearing cumulative rain value")
		try metadata.deleteEntry(key:Metadatas.ambientWeather_lastCumulativeRainValue.rawValue, tx:newTrans)
		logger.trace("successfully cleared cumulative rain value")
		try newTrans.commit()
		logger.debug("successfully committed sub-transaction")
	}

	/// converts a cumulative rain value into an incremental value. if the value has incremented, the `afterSwap` closure will be called with the increment value. this closure can be used to store the new incremental value. the new cumulative rain value will not be stored into the database until the handler returns without throwing. if the handler function throws, the cumulative rain value will not be updated and the old value will remain in the database.
	public func exchangeLastCumulativeRainValue(tx:borrowing Transaction, _ inputCumulativeRain:Double, afterSwap:(FourDigitDecimalPrecisionValue) throws -> Void, logLevel:Logger.Level) throws {
		let inputCumulativeRain = FourDigitDecimalPrecisionValue(inputCumulativeRain)
		var logger = log
		logger.logLevel = logLevel
		logger[metadataKey:"inputCumulativeRain"] = "\(inputCumulativeRain)"
		logger.trace("exchanging last cumulative rain value")
		
		// open a new transaction to read and write the metadata
		logger.trace("opening new transaction to read and write metadata")
		let newTrans = try Transaction(env:env, readOnly:false, parent:tx)
		logger.trace("successfully opened sub-transaction for reading and writing metadata")
		let oldValue:FourDigitDecimalPrecisionValue
		do {
			oldValue = try metadata.loadEntry(key:Metadatas.ambientWeather_lastCumulativeRainValue.rawValue, as:FourDigitDecimalPrecisionValue.self, tx:newTrans)!
			logger.trace("successfully loaded old cumulative rain value", metadata:["oldValue":"\(oldValue)"])
		} catch LMDBError.notFound {
			logger.debug("no previous cumulative rain value found, assuming it is 0.0")
			oldValue = 0
		}
		try metadata.setEntry(key:Metadatas.ambientWeather_lastCumulativeRainValue.rawValue, value:inputCumulativeRain, flags:[], tx:newTrans)
		logger.debug("successfully set new cumulative rain value", metadata:["newValue":"\(inputCumulativeRain)"])
		if oldValue < inputCumulativeRain {
			// the new value increased. calculate the difference and call the afterSwap closure
			logger.trace("old value is less than input cumulative rain. calling afterSwap closure with the difference")
			try afterSwap(inputCumulativeRain - oldValue)
		} else if oldValue > inputCumulativeRain {
			if inputCumulativeRain > 0 {
				logger.trace("old value is greater than input cumulative rain but input cumulative rain is greater than 0.0. calling afterSwap closure with the difference")
				// the delta is the actual value of the input cumulative rain. this should never happen theoretically but in absolute technicality, it might be possible, so I will handle it as best as I can. if the input cumulative rain is less than the old value but above 0, we will assume the input cumulative rain is the complete increment.
				try afterSwap(inputCumulativeRain)
			}
		}
		try newTrans.commit()
		logger.debug("successfully committed sub-transaction")
	}

	public func storeBatteryData(tx:borrowing Transaction, _ batteryData:[String:String], logLevel:Logger.Level) throws {
		var logger = log
		logger.logLevel = logLevel
		logger[metadataKey:"battery_count"] = "\(batteryData.count)"
		logger.trace("storing battery data as JSON encoded dictionary")
		let newTrans = try Transaction(env:env, readOnly:false, parent:tx)
		logger.trace("successfully opened sub-transaction for storing battery data")
		let encodedBytes = try QuickJSON.encode(batteryData)
		logger.trace("successfully encoded battery data into JSON bytes")
		try metadata.setEntry(key:Metadatas.ambientWeather_lastCumulativeRainValue.rawValue, value:encodedBytes, flags:[], tx:newTrans)
		logger.trace("successfully stored battery data into database")
		try newTrans.commit()
		logger.debug("successfully committed sub-transaction")
	}
}

/// the weather database.
public struct WxDB:Sendable {
	/// the database names that will be stored in the database
	public enum Databases:String {
		// wind
		case winddir = "winddir_deg"
		case windspeedmph = "windspeed_mph"
		case windgustmph = "windgust_mph"
		// conditions outdoor
		case tempOutF = "temp_outdoor_f"
		case humidityOut = "humidity_outdoor"
		case uvIndex = "uv_index"
		case solarRadiation = "solarrad"
		// conditions indoor
		case tempInF = "temp_indoor_f"
		case humidityIn = "humidity_indoor"
		case baroIn = "baro_indoor_inhg"
	}

	let env:Environment

	let log:Logger

	// wind
	let winddir:Database.Strict<DateUTC, EncodedDouble>
	let windspeed:Database.Strict<DateUTC, EncodedDouble>
	let windgust:Database.Strict<DateUTC, EncodedDouble>
	// outdoor conditions
	let tempOut:Database.Strict<DateUTC, EncodedDouble>
	let humidityOut:Database.Strict<DateUTC, EncodedDouble>
	let uvIndex:Database.Strict<DateUTC, EncodedByte>
	let solarRadiation:Database.Strict<DateUTC, EncodedDouble>
	// conditions indoor
	let tempIn:Database.Strict<DateUTC, EncodedDouble>
	let humidityIn:Database.Strict<DateUTC, EncodedDouble>
	let baro:Database.Strict<DateUTC, EncodedDouble>

	public init(base:Path, logLevel:Logger.Level) throws {
		// initialize the logging infrastructure
		var makeLogger = Logger(label:"\(String(describing:Self.self))")
		makeLogger.logLevel = logLevel
		log = makeLogger

		let finalPath = base.appendingPathComponent("weatherboi-wxdb_conditions.mdb")
		let memoryMapSize = size_t(finalPath.getFileSize() + 512 * 1024 * 1024 * 1024) // add 512gb to the file size to allow for growth
		
		makeLogger.info("initializing weather database", metadata:["path":"\(finalPath.path())", "memoryMapSize":"\(memoryMapSize)"])

		// create the environment
		env = try Environment(path:finalPath.path(), flags:[.noSubDir], mapSize:memoryMapSize, maxReaders:8, maxDBs:24, mode:[.ownerReadWriteExecute, .groupReadExecute, .otherReadExecute])
		
		makeLogger.trace("created environment", metadata:["path":"\(finalPath.path())", "memoryMapSize":"\(memoryMapSize)"])

		// create the initial transaction
		let newTrans = try Transaction(env:env, readOnly:false)
		// initialize wind databases
		winddir = try Database.Strict<DateUTC, EncodedDouble>(env:env, name:Databases.winddir.rawValue, flags:[.create], tx:newTrans)
		windspeed = try Database.Strict<DateUTC, EncodedDouble>(env:env, name:Databases.windspeedmph.rawValue, flags:[.create], tx:newTrans)
		windgust = try Database.Strict<DateUTC, EncodedDouble>(env:env, name:Databases.windgustmph.rawValue, flags:[.create], tx:newTrans)
		// initialize outdoor conditions databases
		tempOut = try Database.Strict<DateUTC, EncodedDouble>(env:env, name:Databases.tempOutF.rawValue, flags:[.create], tx:newTrans)
		humidityOut = try Database.Strict<DateUTC, EncodedDouble>(env:env, name:Databases.humidityOut.rawValue, flags:[.create], tx:newTrans)
		uvIndex = try Database.Strict<DateUTC, EncodedByte>(env:env, name:Databases.uvIndex.rawValue, flags:[.create], tx:newTrans)
		solarRadiation = try Database.Strict<DateUTC, EncodedDouble>(env:env, name:Databases.solarRadiation.rawValue, flags:[.create], tx:newTrans)
		// initialize indoor conditions databases
		tempIn = try Database.Strict<DateUTC, EncodedDouble>(env:env, name:Databases.tempInF.rawValue, flags:[.create], tx:newTrans)
		humidityIn = try Database.Strict<DateUTC, EncodedDouble>(env:env, name:Databases.humidityIn.rawValue, flags:[.create], tx:newTrans)
		baro = try Database.Strict<DateUTC, EncodedDouble>(env:env, name:Databases.baroIn.rawValue, flags:[.create], tx:newTrans)
		// commit the transaction
		try newTrans.commit()
	}

	public func scribeNewData(date:DateUTC, _ data:WeatherReport, logLevel:Logger.Level) throws {
		var logger = log
		logger.logLevel = logLevel
		logger[metadataKey:"store_date"] = "\(date)"
		logger.trace("scribing new data")

		let newTrans = try Transaction(env:env, readOnly:false)
		
		// scribe the wind data
		if data.wind.windDirection != nil {
			try winddir.cursor(tx:newTrans) { cursor in
				do {
					let existingDate = try cursor.opLast().key
					guard existingDate < date else {
						logger.error("attempted to write wind direction for date that was older than the latest date in the database", metadata:["existingDate":"\(existingDate)"])
						throw LMDBError.keyExists
					}
				} catch LMDBError.notFound {}
				try cursor.setEntry(key:date, value:data.wind.windDirection!, flags:[.append])
			}
			logger.trace("wrote wind direction", metadata:["windDirection":"\(data.wind.windDirection!)"])
		}
		if data.wind.windSpeed != nil {
			try windspeed.cursor(tx:newTrans) { cursor in
				do {
					let existingDate = try cursor.opLast().key
					guard existingDate < date else {
						logger.error("attempted to write wind speed for date that was older than the latest date in the database", metadata:["existingDate":"\(existingDate)"])
						throw LMDBError.keyExists
					}
				} catch LMDBError.notFound {}
				try cursor.setEntry(key:date, value:data.wind.windSpeed!, flags:[.append])
			}
			logger.trace("wrote wind speed", metadata:["windSpeed":"\(data.wind.windSpeed!)"])
		}
		if data.wind.windGust != nil {
			try windgust.cursor(tx:newTrans) { cursor in
				do {
					let existingDate = try cursor.opLast().key
					guard existingDate < date else {
						logger.error("attempted to write wind gust for date that was older than the latest date in the database", metadata:["existingDate":"\(existingDate)"])
						throw LMDBError.keyExists
					}
				} catch LMDBError.notFound {}
				try cursor.setEntry(key:date, value:data.wind.windGust!, flags:[.append])
			}
			logger.trace("wrote wind gust", metadata:["windGust":"\(data.wind.windGust!)"])
		}

		// scribe the outdoor conditions
		if data.outdoorConditions.temp != nil {
			try tempOut.cursor(tx:newTrans) { cursor in
				do {
					let existingDate = try cursor.opLast().key
					guard existingDate < date else {
						logger.error("attempted to write outdoor temperature for date that was older than the latest date in the database", metadata:["existingDate":"\(existingDate)"])
						throw LMDBError.keyExists
					}
				} catch LMDBError.notFound {}
				try cursor.setEntry(key:date, value:data.outdoorConditions.temp!, flags:[.append])
			}
			logger.trace("wrote outdoor temperature", metadata:["tempOut":"\(data.outdoorConditions.temp!)"])
		}
		if data.outdoorConditions.humidity != nil {
			try humidityOut.cursor(tx:newTrans) { cursor in
				do {
					let existingDate = try cursor.opLast().key
					guard existingDate < date else {
						logger.error("attempted to write outdoor humidity for date that was older than the latest date in the database", metadata:["existingDate":"\(existingDate)"])
						throw LMDBError.keyExists
					}
				} catch LMDBError.notFound {}
				try cursor.setEntry(key:date, value:data.outdoorConditions.humidity!, flags:[.append])
			}
			logger.trace("wrote outdoor humidity", metadata:["humidityOut":"\(data.outdoorConditions.humidity!)"])
		}
		if data.outdoorConditions.uvIndex != nil {
			try uvIndex.cursor(tx:newTrans) { cursor in
				do {
					let existingDate = try cursor.opLast().key
					guard existingDate < date else {
						logger.error("attempted to write UV index for date that was older than the latest date in the database", metadata:["existingDate":"\(existingDate)"])
						throw LMDBError.keyExists
					}
				} catch LMDBError.notFound {}
				try cursor.setEntry(key:date, value:data.outdoorConditions.uvIndex!, flags:[.append])
			}
			logger.trace("wrote UV index", metadata:["uvIndex":"\(data.outdoorConditions.uvIndex!)"])
		}
		if data.outdoorConditions.solarRadiation != nil {
			try solarRadiation.cursor(tx:newTrans) { cursor in
				do {
					let existingDate = try cursor.opLast().key
					guard existingDate < date else {
						logger.error("attempted to write solar radiation for date that was older than the latest date in the database", metadata:["existingDate":"\(existingDate)"])
						throw LMDBError.keyExists
					}
				} catch LMDBError.notFound {}
				try cursor.setEntry(key:date, value:data.outdoorConditions.solarRadiation!, flags:[.append])
			}
			logger.trace("wrote solar radiation", metadata:["solarRadiation":"\(data.outdoorConditions.solarRadiation!)"])
		}

		// scribe the indoor conditions
		if data.indoorConditions.temp != nil {
			try tempIn.cursor(tx:newTrans) { cursor in
				do {
					let existingDate = try cursor.opLast().key
					guard existingDate < date else {
						logger.error("attempted to write indoor temperature for date that was older than the latest date in the database", metadata:["existingDate":"\(existingDate)"])
						throw LMDBError.keyExists
					}
				} catch LMDBError.notFound {}
				try cursor.setEntry(key:date, value:data.indoorConditions.temp!, flags:[.append])
			}
			logger.trace("wrote indoor temperature", metadata:["tempIn":"\(data.indoorConditions.temp!)"])
		}
		if data.indoorConditions.humidity != nil {
			try humidityIn.cursor(tx:newTrans) { cursor in
				do {
					let existingDate = try cursor.opLast().key
					guard existingDate < date else {
						logger.error("attempted to write indoor humidity for date that was older than the latest date in the database", metadata:["existingDate":"\(existingDate)"])
						throw LMDBError.keyExists
					}
				} catch LMDBError.notFound {}
				try cursor.setEntry(key:date, value:data.indoorConditions.humidity!, flags:[.append])
			}
			logger.trace("wrote indoor humidity", metadata:["humidityIn":"\(data.indoorConditions.humidity!)"])
		}
		if data.indoorConditions.baro != nil {
			try baro.cursor(tx:newTrans) { cursor in
				do {
					let existingDate = try cursor.opLast().key
					guard existingDate < date else {
						logger.error("attempted to write indoor barometric pressure for date that was older than the latest date in the database", metadata:["existingDate":"\(existingDate)"])
						throw LMDBError.keyExists
					}
				} catch LMDBError.notFound {}
				try cursor.setEntry(key:date, value:data.indoorConditions.baro!, flags:[.append])
			}
			logger.trace("wrote indoor barometric pressure", metadata:["baro":"\(data.indoorConditions.baro!)"])
		}

		// commit the transaction
		try newTrans.commit()
		logger.debug("successfully wrote weather data")
	}
}
