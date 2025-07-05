import Hummingbird
import ServiceLifecycle

struct HTTPServer:Service {
	/// The HTTP server context used for the web server.
	public struct Context:RequestContext {
		/// Required by Hummingbird to provide the core request context storage.
		public var coreContext:Hummingbird.CoreRequestContextStorage
		/// The SwiftNIO ByteBuffer allocator used to produce responses.
		public let allocator:ByteBufferAllocator
		/// The primary initializer for the context.
		public init(source:Hummingbird.ApplicationRequestContextSource) {
			coreContext = .init(source:source)
			allocator = source.channel.allocator
		}
	}

	/*
	Received request for /data/report?&PASSKEY=X&stationtype=AMBWeatherPro_V5.2.2&dateutc=2025-07-04+02:55:57&tempf=76.8&humidity=81&windspeedmph=2.91&windgustmph=5.14&maxdailygust=17.45&winddir=204&winddir_avg10m=210&uv=0&solarradiation=0.00&hourlyrainin=0.000&eventrainin=0.000&dailyrainin=0.004&weeklyrainin=0.004&monthlyrainin=0.004&yearlyrainin=0.004&battout=1&battrain=1&tempinf=85.1&humidityin=65&baromrelin=29.264&baromabsin=29.264&battin=1
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
	public struct WeatherStationResponder:HTTPResponder {
	    public func respond(to request:HummingbirdCore.Request, context:HTTPServer.Context) async throws -> HummingbirdCore.Response {
			print("Received request for \(request.uri.string)")
	        for query in request.uri.queryParameters {
	            print("Query parameter: \(query.key) = \(query.value)")
	        }
			return HummingbirdCore.Response(status:.ok)
	    }
	}

	let appv4:Application<RouterResponder<Context>>
	let appv6:Application<RouterResponder<Context>>

	public init(eventLoopGroupProvider:EventLoopGroupProvider, port:Int) throws {
		let bindAddressV4 = BindAddress.hostname("10.54.10.39", port:port)
		let bindAddressV6 = BindAddress.hostname("::1", port:port)
		
		let appConfigurationV4 = Hummingbird.ApplicationConfiguration(address:bindAddressV4, reuseAddress:true)
		let appConfigurationV6 = Hummingbird.ApplicationConfiguration(address:bindAddressV6, reuseAddress:true)

		let makeRouter = Router(context:Context.self)

		let weatherStationResponder = WeatherStationResponder()
		makeRouter.on("/data/report", method:.get, responder:weatherStationResponder)

		appv4 = Hummingbird.Application(router:makeRouter, configuration:appConfigurationV4, eventLoopGroupProvider:eventLoopGroupProvider)
		appv6 = Hummingbird.Application(router:makeRouter, configuration:appConfigurationV6, eventLoopGroupProvider:eventLoopGroupProvider)
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