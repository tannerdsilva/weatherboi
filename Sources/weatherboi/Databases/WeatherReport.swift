public struct WeatherReport {
	/// the container for wind data
	public struct Wind {
		/// the direction of the wind in degrees. 0 is north, 90 is east, 180 is south, and 270 is west.
		public let windDirection:EncodedUInt16
		/// the speed of the wind in miles per hour
		public let windSpeed:UInt16TwoDigitDecimalValue
		/// the gust speed of the wind in miles per hour
		public let windGust:UInt16TwoDigitDecimalValue
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
	public init?(windDirection wdInput:Substring?, windSpeed wsInput:Substring?, windGust wgInput:Substring?) {
		if let wd = wdInput, let wdDouble = UInt16(wd) {
			windDirection = EncodedUInt16(RAW_native:wdDouble)
		} else {
			return nil
		}
		if let ws = wsInput, let wsDouble = Double(ws) {
			windSpeed = UInt16TwoDigitDecimalValue(wsDouble)
		} else {
			return nil
		}
		if let wg = wgInput, let wgDouble = Double(wg) {
			windGust = UInt16TwoDigitDecimalValue(wgDouble)
		} else {
			return nil
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