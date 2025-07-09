import Hummingbird
import ServiceLifecycle
import Logging
import struct QuickLMDB.Transaction

struct HTTPServer:Service {
	/// The HTTP server context used for the web server.
	public struct Context:RequestContext {
		/// Required by Hummingbird to provide the core request context storage.
		public var coreContext:Hummingbird.CoreRequestContextStorage
		/// The SwiftNIO ByteBuffer allocator used to produce responses.
		public let allocator:ByteBufferAllocator
		/// the primary logger for the context
		public let log:Logger

		/// the primary initializer for the context.
		public init(source:Hummingbird.ApplicationRequestContextSource) {
			coreContext = .init(source:source)
			allocator = source.channel.allocator
			log = source.logger
		}
	}

	/*
	Received request for /data/report?&PASSKEY=X&stationtype=AMBWeatherPro_V5.2.2&dateutc=2025-07-04+02:55:57&tempf=76.8&humidity=81&windspeedmph=2.91&windgustmph=5.14&maxdailygust=17.45&winddir=204&winddir_avg10m=210&uv=0&solarradiation=0.00&hourlyrainin=0.000&eventrainin=0.000&dailyrainin=0.004&weeklyrainin=0.004&monthlyrainin=0.004&yearlyrainin=0.004&battout=1&battrain=1&tempinf=85.1&humidityin=65&baromrelin=29.264&baromabsin=29.264&battin=1
	WITH LIGHTNING: /brand/ambientweather?&PASSKEY=X&stationtype=AMBWeatherPro_V5.2.2&dateutc=2025-07-09+01:12:27&tempf=83.3&humidity=71&windspeedmph=5.37&windgustmph=11.63&maxdailygust=17.67&winddir=214&winddir_avg10m=192&uv=0&solarradiation=71.11&hourlyrainin=0.000&eventrainin=0.000&dailyrainin=0.000&weeklyrainin=0.516&monthlyrainin=1.000&yearlyrainin=1.000&battout=1&battrain=1&tempinf=92.8&humidityin=53&baromrelin=29.282&baromabsin=29.282&battin=1&lightning_day=16&lightning_time=1752023497&lightning_distance=24&batt_lightning=0
	Query parameter:  = 
	Query parameter: PASSKEY = X
	Query parameter: stationtype = AMBWeatherPro_V5.2.2
	Query parameter: dateutc = 2025-07-04+02:55:57
	Query parameter: tempf = 76.8
	Query parameter: humidity = 81
	Query parameter: windspeedmph = 2.91
	Query parameter: windgustmph = 5.14
	Query parameter: maxdailygust = 17.45
	Query parameter: winddir = 204
	Query parameter: winddir_avg10m = 210
	Query parameter: uv = 0
	Query parameter: solarradiation = 0.00
	Query parameter: hourlyrainin = 0.000
	Query parameter: eventrainin = 0.000
	Query parameter: dailyrainin = 0.004
	Query parameter: weeklyrainin = 0.004
	Query parameter: monthlyrainin = 0.004
	Query parameter: yearlyrainin = 0.004
	Query parameter: battout = 1
	Query parameter: battrain = 1
	Query parameter: tempinf = 85.1
	Query parameter: humidityin = 65
	Query parameter: baromrelin = 29.264
	Query parameter: baromabsin = 29.264
	Query parameter: battin = 1
	*/

	/*
	https://support.weather.com/s/weather-underground?language=en_US&subcategory=Personal_Weather_Stations&type=wu
	Received request for GET /weatherstation/updateweatherstation?tempf=88.3&humidity=51&dewptf=68.0&windchillf=88.3&winddir=36&windspeedmph=1.34&windgustmph=4.25&rainin=0.000&dailyrainin=0.000&weeklyrainin=0.000&monthlyrainin=0.000&yearlyrainin=0.000&solarradiation=1071.51&UV=9&indoortempf=88.7&indoorhumidity=52&absbaromin=29.264&baromin=29.264&lowbatt=0&dateutc=now&softwaretype=AMBWeatherPro_V5.2.2&action=updateraw&realtime=1&rtfreq=5
	Query parameter: ID = X
	Query parameter: PASSWORD = X
	Query parameter: tempf = 88.3
	Query parameter: humidity = 51
	Query parameter: dewptf = 68.0
	Query parameter: windchillf = 88.3
	Query parameter: winddir = 36
	Query parameter: windspeedmph = 1.34
	Query parameter: windgustmph = 4.25
	Query parameter: rainin = 0.000
	Query parameter: dailyrainin = 0.000
	Query parameter: weeklyrainin = 0.000
	Query parameter: monthlyrainin = 0.000
	Query parameter: yearlyrainin = 0.000
	Query parameter: solarradiation = 1071.51
	Query parameter: UV = 9
	Query parameter: indoortempf = 88.7
	Query parameter: indoorhumidity = 52
	Query parameter: absbaromin = 29.264
	Query parameter: baromin = 29.264
	Query parameter: lowbatt = 0
	Query parameter: dateutc = now
	Query parameter: softwaretype = AMBWeatherPro_V5.2.2
	Query parameter: action = updateraw
	Query parameter: realtime = 1
	Query parameter: rtfreq = 5
	*/
	public struct AmbientWeatherResponder:HTTPResponder {
		private let metadb:MetadataDB
		private let raindb:RainDB
		private let wxdb:WxDB
		public init(metadataDatabase:MetadataDB, rainDatabase:RainDB, weatherDatabase:WxDB) {
			metadb = metadataDatabase
			raindb = rainDatabase
			wxdb = weatherDatabase
		}
	    public func respond(to request:HummingbirdCore.Request, context:HTTPServer.Context) async throws -> HummingbirdCore.Response {
			let logger = context.log

			// extract the wind data from the request
			var windspeed:Substring? = nil
			var winddir:Substring? = nil
			var windgust:Substring? = nil

			// extract the outdoor conditions
			var outdoorTemp:Substring? = nil
			var outdoorHumidity:Substring? = nil
			var uvIndex:Substring? = nil
			var solarRadiation:Substring? = nil

			// extract the indoor conditions
			var indoorTemp:Substring? = nil
			var indoorHumidity:Substring? = nil
			var baroAbs:Substring? = nil

			var rainEvent:Double? = nil
			
			var batteryValues = [String:String]()
			let batteryKeyRegex = try Regex("^batt")
			queryLoop: for (curQueryKey, curQueryValue) in request.uri.queryParameters {
				guard curQueryKey.count > 0 && curQueryValue.count > 0 else {
					continue queryLoop
				}
				switch curQueryKey {
					case "PASSKEY":
						// this is the passkey, we don't need to do anything with it
						logger.trace("received passkey: '\(curQueryValue)'")
						guard try metadb.shouldProceedWithProcessing(deviceIdentifier:EncodedString(String(curQueryValue)), logLevel:.info) == true else {
							logger.warning("passkey '\(curQueryValue)' is not valid, rejecting request")
							return HummingbirdCore.Response(status:.unauthorized)
						}
					case "windspeedmph":
						windspeed = curQueryValue
						logger.trace("windspeed: '\(String(describing:windspeed!))'")
					case "winddir":
						winddir = curQueryValue
						logger.trace("winddir: '\(String(describing:winddir!))'")
					case "windgustmph":
						windgust = curQueryValue
						logger.trace("windgust: '\(String(describing:windgust!))'")
					case "tempf":
						outdoorTemp = curQueryValue
						logger.trace("outdoor temp: '\(String(describing:outdoorTemp!))'")
					case "humidity":
						outdoorHumidity = curQueryValue
						logger.trace("outdoor humidity: '\(String(describing:outdoorHumidity!))'")
					case "uv":
						uvIndex = curQueryValue
						logger.trace("UV index: '\(String(describing:uvIndex!))'")
					case "solarradiation":
						solarRadiation = curQueryValue
						logger.trace("solar radiation: '\(String(describing:solarRadiation!))'")
					case "tempinf":
						indoorTemp = curQueryValue
						logger.trace("indoor temp: '\(String(describing:indoorTemp!))'")
					case "humidityin":
						indoorHumidity = curQueryValue
						logger.trace("indoor humidity: '\(String(describing:indoorHumidity!))'")
					case "baromabsin":
						baroAbs = curQueryValue
						logger.trace("barometric pressure: '\(String(describing:baroAbs!))'")
					case "eventrainin":
						// this is the rain event value
						if let rainValue = Double(curQueryValue) {
							rainEvent = rainValue
							logger.trace("rain event: '\(String(describing:rainEvent!))'")
						} else {
							logger.warning("invalid rain event value: '\(curQueryValue)'")
						}
					default:
						if curQueryKey.contains(batteryKeyRegex) == true {
							batteryValues[String(curQueryKey)] = String(curQueryValue)
							logger.trace("battery value for key '\(curQueryKey)': '\(String(describing:curQueryValue))'")
						}
				}
			}

			let windData = WeatherReport.Wind(windDirection:winddir, windSpeed:windspeed, windGust:windgust)
			let outdoorConditions = WeatherReport.OutdoorConditions(temp:outdoorTemp, humidity:outdoorHumidity, uvIndex:uvIndex, solarRadiation:solarRadiation)
			let indoorConditions = WeatherReport.IndoorConditions(temp:indoorTemp, humidity:indoorHumidity, baro:baroAbs)
			let weatherReport = WeatherReport(wind:windData, outdoorConditions:outdoorConditions, indoorConditions:indoorConditions)
			
			// document the data for the main database and the rain database
			let dateNow = DateUTC()
			func transactData() throws {
				let newTransaction = try Transaction(env:metadb.env, readOnly:false)
				if rainEvent != nil {
					// we have a rain event, so we need to update the rain database
					try metadb.exchangeLastCumulativeRainValue(tx:newTransaction, rainEvent!, afterSwap: { newIncrementalRainValue in
						try raindb.scribeNewIncrementValue(date:dateNow, increment:newIncrementalRainValue, logLevel:logger.logLevel)
					}, logLevel:logger.logLevel)
				}
				// write the battery data to the metadata database
				try! metadb.storeBatteryData(tx:newTransaction, batteryValues, logLevel:logger.logLevel)
				try newTransaction.commit()
				try wxdb.scribeNewData(date:dateNow, weatherReport, logLevel:logger.logLevel)
			}
			do {
				try transactData()
			} catch {
				logger.error("failed to write data to the database: \(error)")
				return HummingbirdCore.Response(status:.internalServerError)
			}
			return HummingbirdCore.Response(status:.ok)
	    }
	}

	let log:Logger
	let appv4:Application<RouterResponder<Context>>
	let appv6:Application<RouterResponder<Context>>
	let weatherDatabase:WxDB
	let metadataDatabase:MetadataDB
	let rainDatabase:RainDB
	/// initialize the HTTP server with the given parameters.
	public init(eventLoopGroupProvider:EventLoopGroupProvider, bindV4:String, bindV6:String, port:Int, metadataDB:MetadataDB, rainDB:RainDB, wxDB:WxDB, logLevel:Logger.Level) throws {
		var makeLogger = Logger(label:"weatherboi.http")
		makeLogger.logLevel = logLevel
		log = makeLogger

		weatherDatabase = wxDB
		metadataDatabase = metadataDB
		rainDatabase = rainDB

		let bindAddressV4 = BindAddress.hostname(bindV4, port:port)
		let bindAddressV6 = BindAddress.hostname(bindV6, port:port)
		
		let appConfigurationV4 = Hummingbird.ApplicationConfiguration(address:bindAddressV4, reuseAddress:true)
		let appConfigurationV6 = Hummingbird.ApplicationConfiguration(address:bindAddressV6, reuseAddress:true)

		let makeRouter = Router(context:Context.self)

		let weatherStationResponder = AmbientWeatherResponder(metadataDatabase:metadataDatabase, rainDatabase:rainDatabase, weatherDatabase:weatherDatabase)
		makeRouter.on("/brand/ambientweather", method:.get, responder:weatherStationResponder)

		appv4 = Hummingbird.Application(router:makeRouter, configuration:appConfigurationV4, eventLoopGroupProvider:eventLoopGroupProvider, logger:makeLogger)
		appv6 = Hummingbird.Application(router:makeRouter, configuration:appConfigurationV6, eventLoopGroupProvider:eventLoopGroupProvider, logger:makeLogger)
	}

	public func run() async throws {
		try await withThrowingTaskGroup(of:Void.self) { group in
			group.addTask {
				try await self.appv4.run()
			}
			group.addTask {
				try await self.appv6.run()
			}
			try await group.waitForAll()
		}
	}
}