fileprivate func checkNil(_ data: inout [UInt8]) -> Bool{
	defer {
		data.removeFirst(1)
	}
	if data.first == 0 {
		return true
	}
	return false
}
public struct WeatherReport {
	/// Initializer for http server
	init(wind:Wind, outdoorConditions:OutdoorConditions, indoorConditions:IndoorConditions) {
		self.wind = wind
		self.outdoorConditions = outdoorConditions
		self.indoorConditions = indoorConditions
	}
	/// Initializer for syncing
	public init(_ data: consuming [UInt8]) {
		
		var winddir: EncodedUInt16?
		if (!checkNil(&data)) {
			winddir = data.withUnsafeBufferPointer { ptr in
				return EncodedUInt16(RAW_staticbuff: ptr.baseAddress!)
			}
			data.removeFirst(MemoryLayout<EncodedUInt16>.size)
		}
		
		var windSpeed: UInt16TwoDigitDecimalValue?
		if (!checkNil(&data)) {
			windSpeed = data.withUnsafeBufferPointer { ptr in
				return UInt16TwoDigitDecimalValue(RAW_staticbuff: ptr.baseAddress!)
			}
			data.removeFirst(MemoryLayout<UInt16TwoDigitDecimalValue>.size)
		}
		
		var windGust: UInt16TwoDigitDecimalValue?
		if (!checkNil(&data)) {
			windGust = data.withUnsafeBufferPointer { ptr in
				return UInt16TwoDigitDecimalValue(RAW_staticbuff: ptr.baseAddress!)
			}
			data.removeFirst(MemoryLayout<UInt16TwoDigitDecimalValue>.size)
		}
		
		wind = Wind(windDirection: winddir, windSpeed: windSpeed, windGust: windGust)
		
		var tempOutdoor: EncodedDouble?
		if (!checkNil(&data)) {
			tempOutdoor = data.withUnsafeBufferPointer { ptr in
				return EncodedDouble(RAW_staticbuff: ptr.baseAddress!)
			}
			data.removeFirst(MemoryLayout<EncodedDouble>.size)
		}
		
		var humidityOutdoor: UInt16TwoDigitDecimalValue?
		if (!checkNil(&data)) {
			humidityOutdoor = data.withUnsafeBufferPointer { ptr in
				return UInt16TwoDigitDecimalValue(RAW_staticbuff: ptr.baseAddress!)
			}
			data.removeFirst(MemoryLayout<UInt16TwoDigitDecimalValue>.size)
		}
		
		var uvIndex: EncodedByte?
		if (!checkNil(&data)) {
			uvIndex = data.withUnsafeBufferPointer { ptr in
				return EncodedByte(RAW_staticbuff: ptr.baseAddress!)
			}
			data.removeFirst(MemoryLayout<EncodedByte>.size)
		}
		
		var solarRadiation: EncodedUInt16?
		if (!checkNil(&data)) {
			solarRadiation = data.withUnsafeBufferPointer { ptr in
				return EncodedUInt16(RAW_staticbuff: ptr.baseAddress!)
			}
			data.removeFirst(MemoryLayout<EncodedUInt16>.size)
		}
		
		outdoorConditions = OutdoorConditions(temp: tempOutdoor, humidity: humidityOutdoor, uvIndex: uvIndex, solarRadiation: solarRadiation)
		
		var tempIndoor: EncodedDouble?
		if (!checkNil(&data)) {
			tempIndoor = data.withUnsafeBufferPointer { ptr in
				return EncodedDouble(RAW_staticbuff: ptr.baseAddress!)
			}
			data.removeFirst(MemoryLayout<EncodedDouble>.size)
		}
		
		var humidityIndoor: UInt16TwoDigitDecimalValue?
		if (!checkNil(&data)) {
			humidityIndoor = data.withUnsafeBufferPointer { ptr in
				return UInt16TwoDigitDecimalValue(RAW_staticbuff: ptr.baseAddress!)
			}
			data.removeFirst(MemoryLayout<UInt16TwoDigitDecimalValue>.size)
		}
		
		var baro: UInt32FourDigitDecimalValue?
		if (!checkNil(&data)) {
			baro = data.withUnsafeBufferPointer { ptr in
				return UInt32FourDigitDecimalValue(RAW_staticbuff: ptr.baseAddress!)
			}
			data.removeFirst(MemoryLayout<UInt32FourDigitDecimalValue>.size)
		}
		
		indoorConditions = IndoorConditions(temp: tempIndoor, humidity: humidityIndoor, baro: baro)
	}
	/// the container for wind data
	public struct Wind {
		/// the direction of the wind in degrees. 0 is north, 90 is east, 180 is south, and 270 is west.
		public let windDirection:EncodedUInt16?
		/// the speed of the wind in miles per hour
		public let windSpeed:UInt16TwoDigitDecimalValue?
		/// the gust speed of the wind in miles per hour
		public let windGust:UInt16TwoDigitDecimalValue?
	}
	/// the container for outdoor conditions
	public struct OutdoorConditions {
		/// the temperature in degrees Fahrenheit
		public let temp:EncodedDouble?
		/// the humidity percentage
		public let humidity:UInt16TwoDigitDecimalValue?
		/// the UV index
		public let uvIndex:EncodedByte?
		/// the solar radiation in watts per square meter
		public let solarRadiation:EncodedUInt16?
	}
	/// the container for indoor conditions
	public struct IndoorConditions {
		/// the temperature in degrees Fahrenheit
		public let temp:EncodedDouble?
		/// the humidity percentage
		public let humidity:UInt16TwoDigitDecimalValue?
		/// the barometric pressure in inches of mercury
		public let baro:UInt32FourDigitDecimalValue?
	}
	/// stores the wind data for the weather report
	public let wind:Wind
	/// stores the outdoor conditions for the weather report
	public let outdoorConditions:OutdoorConditions
	/// stores the indoor conditions for the weather report
	public let indoorConditions:IndoorConditions
}

extension WeatherReport.Wind {
	/// primary initializer for the wind data as it comes from the http server
	public init(windDirection wdInput:Substring?, windSpeed wsInput:Substring?, windGust wgInput:Substring?) {
		if let wd = wdInput, let wdDouble = UInt16(wd) {
			windDirection = EncodedUInt16(RAW_native:wdDouble)
		} else {
			windDirection = nil
		}
		if let ws = wsInput, let wsDouble = Double(ws) {
			windSpeed = UInt16TwoDigitDecimalValue(wsDouble)
		} else {
			windSpeed = nil
		}
		if let wg = wgInput, let wgDouble = Double(wg) {
			windGust = UInt16TwoDigitDecimalValue(wgDouble)
		} else {
			windGust = nil
		}
	}
}

extension WeatherReport.OutdoorConditions {
	/// primary initializer for the outdoor conditions as it comes from the http server
	public init(temp tInput:Substring?, humidity hInput:Substring?, uvIndex uInput:Substring?, solarRadiation srInput:Substring?) {
		if let t = tInput, let tDouble = Double(t) {
			temp = EncodedDouble(RAW_native:tDouble)
		} else {
			temp = nil
		}
		if let h = hInput, let hDouble = Double(h) {
			humidity = UInt16TwoDigitDecimalValue(hDouble)
		} else {
			humidity = nil
		}
		if let u = uInput, let uByte = UInt8(u) {
			uvIndex = EncodedByte(RAW_native:uByte)
		} else {
			uvIndex = nil
		}
		if let sr = srInput, let srDouble = UInt16(sr) {
			solarRadiation = EncodedUInt16(RAW_native:srDouble)
		} else {
			solarRadiation = nil
		}
	}
}

extension WeatherReport.IndoorConditions {
	/// primary initializer for the indoor conditions as it comes from the http server
	public init(temp tInput:Substring?, humidity hInput:Substring?, baro bInput:Substring?) {
		if let t = tInput, let tDouble = Double(t) {
			temp = EncodedDouble(RAW_native:tDouble)
		} else {
			temp = nil
		}
		if let h = hInput, let hDouble = Double(h) {
			humidity = UInt16TwoDigitDecimalValue(hDouble)
		} else {
			humidity = nil
		}
		if let b = bInput, let bDouble = Double(b) {
			baro = UInt32FourDigitDecimalValue(bDouble)
		} else {
			baro = nil
		}
	}
}
