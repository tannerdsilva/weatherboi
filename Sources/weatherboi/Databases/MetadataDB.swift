import QuickLMDB
import RAW
import bedrock

@RAW_convertible_string_type<UTF8>(backing:RAW_byte.self)
@MDB_comparable()
public struct EncodedString:Sendable {}

@RAW_staticbuff(bytes:8)
@RAW_staticbuff_binaryfloatingpoint_type<Double>()
@MDB_comparable()
public struct EncodedDouble:Sendable {}

public typealias EncodedByte = RAW_byte

@RAW_staticbuff(concat:bedrock.Date.Seconds.self)
@MDB_comparable()
public struct DateUTC:Sendable {
	private let seconds:bedrock.Date.Seconds
	public init() {
		self.seconds = bedrock.Date.Seconds(localTime:false)
	}
}

public struct MetadataDB {
	let env:Environment
	let db:Database

	public init(base:Path) throws {
		let finalPath = base.appendingPathComponent("weatherboidb-metadata.mdb")
		let memoryMapSize = size_t(finalPath.getFileSize())
		env = try Environment(path:finalPath.path(), flags:[.noSubDir], mapSize:memoryMapSize, maxReaders:16, maxDBs:8, mode:[.ownerReadWriteExecute, .groupReadExecute, .otherReadExecute])
		let newTrans = try Transaction(env:env, readOnly:false)
		db = try Database(env:env, name:nil, flags:[.create], tx:newTrans)
		try newTrans.commit()
	}
}

/// the weather database.
public struct WxDB {
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
		// rain
		case rainEvent = "rain_event_inches"
		case rainHourly = "rain_hourly_inches"
		case rainDaily = "rain_daily_inches"
		case rainWeekly = "rain_weekly_inches"
		case rainMonthly = "rain_monthly_inches"
		case rainYearly = "rain_yearly_inches"
	}
	public struct WeatherReport {
		/// the container for wind data
		public struct Wind {
			/// the direction of the wind in degrees. 0 is north, 90 is east, 180 is south, and 270 is west.
			public let windDirection:EncodedDouble?
			/// the speed of the wind in miles per hour
			public let windSpeed:EncodedDouble?
			/// the gust speed of the wind in miles per hour
			public let windGust:EncodedDouble?
		}
		/// the container for outdoor conditions
		public struct OutdoorConditions {
			/// the temperature in degrees Fahrenheit
			public let tempOut:EncodedDouble?
			/// the humidity percentage
			public let humidityOut:EncodedDouble?
			/// the UV index
			public let uvIndex:EncodedByte?
			/// the solar radiation in watts per square meter
			public let solarRadiation:EncodedDouble?
		}
		/// the container for indoor conditions
		public struct IndoorConditions {
			/// the temperature in degrees Fahrenheit
			public let tempIn:EncodedDouble?
			/// the humidity percentage
			public let humidityIn:EncodedDouble?
			/// the barometric pressure in inches of mercury
			public let baro:EncodedDouble?
		}
		/// the container for rain data
		public struct Rain {
			/// the amount of rain in inches for the current event. a rain event is defined as continuous rain, and resets if accumulated rain is less than 1mm (0.039 inches) in a 24 hour period.
			public let rainEvent:EncodedDouble?
			/// the amount of rain in inches for the last hour
			public let rainHourly:EncodedDouble?
			/// the amount of rain in inches for the last day
			public let rainDaily:EncodedDouble?
			/// the amount of rain in inches for the last week
			public let rainWeekly:EncodedDouble?
			/// the amount of rain in inches for the last month
			public let rainMonthly:EncodedDouble?
			/// the amount of rain in inches for the last year
			public let rainYearly:EncodedDouble?
		}
		/// stores the wind data for the weather report
		public let wind:Wind
		/// stores the outdoor conditions for the weather report
		public let outdoorConditions:OutdoorConditions
		/// stores the indoor conditions for the weather report
		public let indoorConditions:IndoorConditions
		/// stores the rain data for the weather report
		public let rain:Rain
	}


	let env:Environment
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
	// rain
	let rainEvent:Database.Strict<DateUTC, EncodedDouble>
	let rainHourly:Database.Strict<DateUTC, EncodedDouble>
	let rainDaily:Database.Strict<DateUTC, EncodedDouble>
	let rainWeekly:Database.Strict<DateUTC, EncodedDouble>
	let rainMonthly:Database.Strict<DateUTC, EncodedDouble>
	let rainYearly:Database.Strict<DateUTC, EncodedDouble>

	public init(base:Path) throws {
		let finalPath = base.appendingPathComponent("weatherboidb-wxdata.mdb")
		let memoryMapSize = size_t(finalPath.getFileSize() + 50 * 1024 * 1024 * 1024) // add 50gb to the file size to allow for growth
		// create the environment
		env = try Environment(path:finalPath.path(), flags:[.noSubDir], mapSize:memoryMapSize, maxReaders:8, maxDBs:16, mode:[.ownerReadWriteExecute, .groupReadExecute, .otherReadExecute])
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
		baroIn = try Database.Strict<DateUTC, EncodedDouble>(env:env, name:Databases.baroIn.rawValue, flags:[.create], tx:newTrans)
		// initialize rain databases
		rainEvent = try Database.Strict<DateUTC, EncodedDouble>(env:env, name:Databases.rainEvent.rawValue, flags:[.create], tx:newTrans)
		rainHourly = try Database.Strict<DateUTC, EncodedDouble>(env:env, name:Databases.rainHourly.rawValue, flags:[.create], tx:newTrans)
		rainDaily = try Database.Strict<DateUTC, EncodedDouble>(env:env, name:Databases.rainDaily.rawValue, flags:[.create], tx:newTrans)
		rainWeekly = try Database.Strict<DateUTC, EncodedDouble>(env:env, name:Databases.rainWeekly.rawValue, flags:[.create], tx:newTrans)
		rainMonthly = try Database.Strict<DateUTC, EncodedDouble>(env:env, name:Databases.rainMonthly.rawValue, flags:[.create], tx:newTrans)
		rainYearly = try Database.Strict<DateUTC, EncodedDouble>(env:env, name:Databases.rainYearly.rawValue, flags:[.create], tx:newTrans)
		// commit the transaction
		try newTrans.commit()
	}

	public func scribeNewData(date:DateUTC, _ data:WeatherReport) throws {
		let newTrans = try Transaction(env:env, readOnly:false)
		// scribe the wind data
		if data.wind.windDirection != nil {
			try winddir.setEntry(key:date, value:data.wind.windDirection!, tx:newTrans)
		}
		if data.wind.windSpeed != nil {
			try windspeed.setEntry(key:date, value:data.wind.windSpeed!, tx:newTrans)
		}
		if data.wind.windGust != nil {
			try windgust.setEntry(key:date, value:data.wind.windGust!, tx:newTrans)
		}
		// scribe the outdoor conditions
		if data.outdoorConditions.tempOut != nil {
			try tempOut.setEntry(key:date, value:data.outdoorConditions.tempOut!, tx:newTrans)
		}
		if data.outdoorConditions.humidityOut != nil {
			try humidityOut.setEntry(key:date, value:data.outdoorConditions.humidityOut!, tx:newTrans)
		}
		if data.outdoorConditions.uvIndex != nil {
			try uvIndex.setEntry(key:date, value:data.outdoorConditions.uvIndex!, tx:newTrans)
		}
		if data.outdoorConditions.solarRadiation != nil {
			try solarRadiation.setEntry(key:date, value:data.outdoorConditions.solarRadiation!, tx:newTrans)
		}
		// scribe the indoor conditions
		if data.indoorConditions.tempIn != nil {
			try tempIn.setEntry(key:date, value:data.indoorConditions.tempIn!, tx:newTrans)
		}
		if data.indoorConditions.humidityIn != nil {
			try humidityIn.setEntry(key:date, value:data.indoorConditions.humidityIn!, tx:newTrans)
		}
		if data.indoorConditions.baro != nil {
			try baro.setEntry(key:date, value:data.indoorConditions.baro!, tx:newTrans)
		}
		// scribe the rain data
		if data.rain.rainEvent != nil {
			try rainEvent.setEntry(key:date, value:data.rain.rainEvent!, tx:newTrans)
		}
		if data.rain.rainHourly != nil {
			try rainHourly.setEntry(key:date, value:data.rain.rainHourly!, tx:newTrans)
		}
		if data.rain.rainDaily != nil {
			try rainDaily.setEntry(key:date, value:data.rain.rainDaily!, tx:newTrans)
		}
		if data.rain.rainWeekly != nil {
			try rainWeekly.setEntry(key:date, value:data.rain.rainWeekly!, tx:newTrans)
		}
		if data.rain.rainMonthly != nil {
			try rainMonthly.setEntry(key:date, value:data.rain.rainMonthly!, tx:newTrans)
		}
		if data.rain.rainYearly != nil {
			try rainYearly.setEntry(key:date, value:data.rain.rainYearly!, tx:newTrans)
		}
		// commit the transaction
		try newTrans.commit()
	}
}



@MDB_comparable
public struct EncodedDoubles:Sendable, RAW_convertible, RAW_comparable, RAW_accessible {
	public mutating func RAW_access_mutating<R, E>(_ body:(UnsafeMutableBufferPointer<UInt8>) throws(E) -> R) throws(E) -> R {
		func getPtr(_ unsafePtr:UnsafePointer<EncodedDouble>, count:Int) throws(E) -> R {
			return try body(UnsafeMutableBufferPointer<UInt8>(start:UnsafeMutableRawPointer(mutating:unsafePtr).assumingMemoryBound(to:UInt8.self), count:count * MemoryLayout<EncodedDouble.RAW_staticbuff_storetype>.size))
		}
		return try getPtr(&elements, count:elements.count)
	}

	public var elements:[EncodedDouble]

	public init(encodedDoubles:[EncodedDouble]) {
		elements = encodedDoubles
	}

	public init?(RAW_decode: UnsafeRawPointer, count: RAW.size_t) {
		guard count % MemoryLayout<EncodedDouble.RAW_staticbuff_storetype>.size == 0 else {
			return nil
		}
		let numberOfEntries = count / MemoryLayout<EncodedDouble.RAW_staticbuff_storetype>.size
		var buildRepValues = [EncodedDouble]()
		var readSeeker = RAW_decode
		for _ in 0..<numberOfEntries {
			buildRepValues.append(EncodedDouble(RAW_staticbuff_seeking:&readSeeker))
		}
		self.elements = buildRepValues
	}

	public borrowing func RAW_encode(count:inout size_t) {
		withUnsafePointer(to:self) { selfPtr in
			count += selfPtr.pointer(to:\Self.elements)!.pointee.count * MemoryLayout<EncodedDouble.RAW_staticbuff_storetype>.size
		}
	}

	public borrowing func RAW_encode(dest: UnsafeMutablePointer<UInt8>) -> UnsafeMutablePointer<UInt8> {
		return withUnsafePointer(to:self) { selfPtr in
			return selfPtr.pointer(to:\Self.elements)!.pointee.withUnsafeBufferPointer { buff in
				var seeker = dest
				var i = 0
				let fullCount = buff.count
				while i < fullCount {
					defer {
						i += 1
					}
					seeker = buff[i].RAW_encode(dest:seeker)
				}
				return seeker
			}
		}
	}

	public borrowing func RAW_access<R, E>(_ body: (UnsafeBufferPointer<UInt8>) throws(E) -> R) throws(E) -> R {
		func getPtr(_ unsafePtr:UnsafePointer<EncodedDouble>, count:Int) throws(E) -> R {
			return try body(UnsafeBufferPointer<UInt8>(start:UnsafeRawPointer(unsafePtr).assumingMemoryBound(to:UInt8.self), count: count * MemoryLayout<EncodedDouble.RAW_staticbuff_storetype>.size))
		}
		return try getPtr(elements, count:elements.count)
	}
}
