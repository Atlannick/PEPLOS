//
//  StylistWeatherController.swift
//  PEPLOS
//

import Combine
import CoreLocation
import Foundation

/// Requests location authorization once when needed, then loads current weather for coordinates.
@MainActor
final class StylistWeatherController: NSObject, ObservableObject {
    @Published private(set) var weatherLine: String = ""
    @Published private(set) var statusLine: String = ""
    /// SF Symbol name for current conditions (aligned with WMO code or wttr description). Default before first successful load.
    @Published private(set) var weatherSymbolName: String = "cloud.sun.fill"
    /// Current air temperature in °C when available (used for outfit / weather copy). `nil` if weather is not loaded or failed.
    @Published private(set) var temperatureCelsius: Double?

    private let locationManager = CLLocationManager()
    private var hasRequestedAuthorization = false
    /// Cancels the previous in-flight weather request when a new location update arrives.
    private var weatherFetchTask: Task<Void, Never>?

    override init() {
        super.init()
        locationManager.delegate = self
        /// Coarser fix is returned sooner than sub‑meter GPS; good enough for regional weather grids.
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    func startIfNeeded() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            guard !hasRequestedAuthorization else { return }
            hasRequestedAuthorization = true
            statusLine = "Requesting location access…"
            locationManager.requestWhenInUseAuthorization()

        case .authorizedAlways, .authorizedWhenInUse:
            statusLine = "Getting location…"
            locationManager.requestLocation()

        case .denied, .restricted:
            statusLine = "Turn on Location in Settings to see local weather."
            weatherLine = ""
            weatherSymbolName = "cloud.sun.fill"
            temperatureCelsius = nil

        @unknown default:
            statusLine = ""
        }
    }
}

extension StylistWeatherController: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                statusLine = "Getting location…"
                manager.requestLocation()
            case .denied, .restricted:
                statusLine = "Turn on Location in Settings to see local weather."
                weatherLine = ""
                weatherSymbolName = "cloud.sun.fill"
                temperatureCelsius = nil
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            await fetchWeather(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            statusLine = "Could not determine location."
            weatherLine = ""
            weatherSymbolName = "cloud.sun.fill"
            temperatureCelsius = nil
        }
    }

    private func fetchWeather(latitude: Double, longitude: Double) async {
        weatherFetchTask?.cancel()
        let lat = latitude
        let lon = longitude
        let task = Task { [weak self] in
            guard let self else { return }
            await self.runWeatherFetch(latitude: lat, longitude: lon)
        }
        weatherFetchTask = task
        await task.value
    }

    private func runWeatherFetch(latitude: Double, longitude: Double) async {
        if Task.isCancelled { return }
        statusLine = "Loading weather…"
        let fahrenheit = Self.prefersFahrenheitDisplay()

        /// Run both providers at once so we wait for the slower of the two, not the sum (much faster than sequential).
        async let wttrTask = fetchWttr(latitude: latitude, longitude: longitude, fahrenheit: fahrenheit)
        async let openMeteoTask = fetchOpenMeteo(latitude: latitude, longitude: longitude, fahrenheit: fahrenheit)
        let (wttr, openMeteo) = await (wttrTask, openMeteoTask)

        if Task.isCancelled { return }

        if let merged = mergeWeather(wttr: wttr, openMeteo: openMeteo, fahrenheit: fahrenheit) {
            apply(merged)
            return
        }

        statusLine = "Could not load weather."
        weatherLine = ""
        weatherSymbolName = "cloud.sun.fill"
        temperatureCelsius = nil
    }

    /// Prefer wttr for the numbers/text (station‑style, often closer to what you see outside); Open‑Meteo for icon when available.
    private func mergeWeather(wttr: ResolvedWeather?, openMeteo: ResolvedWeather?, fahrenheit: Bool) -> ResolvedWeather? {
        switch (wttr, openMeteo) {
        case (nil, nil):
            return nil
        case let (w?, nil):
            return w
        case let (nil, o?):
            return o
        case let (w?, o?):
            return ResolvedWeather(
                line: w.line,
                celsius: w.celsius,
                symbolName: o.symbolName
            )
        }
    }

    private struct ResolvedWeather {
        let line: String
        let celsius: Double
        let symbolName: String
    }

    private func apply(_ r: ResolvedWeather) {
        weatherLine = r.line
        weatherSymbolName = r.symbolName
        statusLine = ""
        temperatureCelsius = r.celsius
    }

    // MARK: - Open-Meteo

    private static func openMeteoURL(latitude: Double, longitude: Double, fahrenheit: Bool, legacyCurrentWeather: Bool) -> URL? {
        var parts = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        if legacyCurrentWeather {
            parts.queryItems = [
                URLQueryItem(name: "latitude", value: String(latitude)),
                URLQueryItem(name: "longitude", value: String(longitude)),
                URLQueryItem(name: "timezone", value: "auto"),
                URLQueryItem(name: "current_weather", value: "true"),
                URLQueryItem(name: "temperature_unit", value: fahrenheit ? "fahrenheit" : "celsius"),
            ]
        } else {
            parts.queryItems = [
                URLQueryItem(name: "latitude", value: String(latitude)),
                URLQueryItem(name: "longitude", value: String(longitude)),
                URLQueryItem(name: "timezone", value: "auto"),
                URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,weather_code"),
                URLQueryItem(name: "temperature_unit", value: fahrenheit ? "fahrenheit" : "celsius"),
            ]
        }
        return parts.url
    }

    /// Uses `current=temperature_2m,apparent_temperature,weather_code` (2 m air + “feels like”); second attempt uses legacy `current_weather` if needed.
    private func fetchOpenMeteo(latitude: Double, longitude: Double, fahrenheit: Bool) async -> ResolvedWeather? {
        let maxAttempts = 2
        for attempt in 0..<maxAttempts {
            if Task.isCancelled { return nil }
            guard let url = Self.openMeteoURL(latitude: latitude, longitude: longitude, fahrenheit: fahrenheit, legacyCurrentWeather: attempt == 1) else { return nil }
            do {
                var request = URLRequest(url: url)
                request.setValue("PEPLOS/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.timeoutInterval = 12
                let (data, response) = try await URLSession.shared.data(for: request)
                if Task.isCancelled { return nil }

                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                if status == 429 || (500...599).contains(status) || status != 200 {
                    if attempt + 1 < maxAttempts {
                        try await Task.sleep(nanoseconds: 250_000_000)
                        continue
                    }
                    break
                }
                if let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   text.hasPrefix("<") {
                    if attempt + 1 < maxAttempts {
                        try await Task.sleep(nanoseconds: 250_000_000)
                        continue
                    }
                    break
                }

                let decoded = try JSONDecoder().decode(OpenMeteoEnvelope.self, from: data)
                if decoded.error == true {
                    let reason = decoded.reason?.lowercased() ?? ""
                    let transient = reason.contains("concurrent") || reason.contains("many") || reason.contains("rate")
                    if transient, attempt + 1 < maxAttempts {
                        try await Task.sleep(nanoseconds: 300_000_000)
                        continue
                    }
                    break
                }

                if let cur = decoded.current,
                   let code = cur.weather_code,
                   let displayTemp = cur.apparent_temperature ?? cur.temperature_2m {
                    let celsiusForScoring: Double
                    if fahrenheit {
                        celsiusForScoring = (displayTemp - 32) * 5 / 9
                    } else {
                        celsiusForScoring = displayTemp
                    }
                    let condition = Self.describeWeatherCode(code)
                    let unit = fahrenheit ? "°F" : "°C"
                    let tempInt = Int(displayTemp.rounded())
                    return ResolvedWeather(
                        line: "\(tempInt)\(unit) · \(condition)",
                        celsius: celsiusForScoring,
                        symbolName: Self.sfSymbolName(forWMOCode: code)
                    )
                }

                /// Older responses without `current` block.
                if let cw = decoded.current_weather {
                    let condition = Self.describeWeatherCode(cw.weathercode)
                    let unit = fahrenheit ? "°F" : "°C"
                    let temp = Int(cw.temperature.rounded())
                    let celsius: Double
                    if fahrenheit {
                        celsius = (cw.temperature - 32) * 5 / 9
                    } else {
                        celsius = cw.temperature
                    }
                    return ResolvedWeather(
                        line: "\(temp)\(unit) · \(condition)",
                        celsius: celsius,
                        symbolName: Self.sfSymbolName(forWMOCode: cw.weathercode)
                    )
                }
                if attempt + 1 < maxAttempts {
                    try await Task.sleep(nanoseconds: 200_000_000)
                    continue
                }
            } catch is CancellationError {
                return nil
            } catch {
                if attempt + 1 < maxAttempts {
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    continue
                }
            }
        }
        return nil
    }

    private struct OpenMeteoEnvelope: Decodable {
        let error: Bool?
        let reason: String?
        let current: CurrentBlock?
        let current_weather: LegacyCurrent?

        struct CurrentBlock: Decodable {
            let temperature_2m: Double?
            let apparent_temperature: Double?
            let weather_code: Int?
        }

        struct LegacyCurrent: Decodable {
            let temperature: Double
            let weathercode: Int
        }
    }

    // MARK: - wttr.in

    private func fetchWttr(latitude: Double, longitude: Double, fahrenheit: Bool) async -> ResolvedWeather? {
        let coord = String(format: "%.5f,%.5f", latitude, longitude)
        guard let url = URL(string: "https://wttr.in/\(coord)?format=j1") else { return nil }
        if Task.isCancelled { return nil }
        do {
            var request = URLRequest(url: url)
            request.setValue("PEPLOS/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 12
            let (data, response) = try await URLSession.shared.data(for: request)
            if Task.isCancelled { return nil }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else { return nil }
            let decoded = try JSONDecoder().decode(WttrEnvelope.self, from: data)
            guard let cur = decoded.current_condition.first else { return nil }
            let desc = cur.weatherDesc.first?.value ?? "Weather"
            let symbol = Self.sfSymbolName(forWeatherDescription: desc)

            let tempC = Double(cur.temp_C) ?? 0
            let tempF = Double(cur.temp_F) ?? 0
            let feelsC = Double(cur.FeelsLikeC ?? cur.temp_C) ?? tempC
            let feelsF = Double(cur.FeelsLikeF ?? cur.temp_F) ?? tempF

            if fahrenheit {
                let display = feelsF
                let t = Int(display.rounded())
                let celsiusForScoring = (feelsF - 32) * 5 / 9
                return ResolvedWeather(line: "\(t)°F · \(desc)", celsius: celsiusForScoring, symbolName: symbol)
            } else {
                let display = feelsC
                let t = Int(display.rounded())
                return ResolvedWeather(line: "\(t)°C · \(desc)", celsius: feelsC, symbolName: symbol)
            }
        } catch is CancellationError {
            return nil
        } catch {
            return nil
        }
    }

    private struct WttrEnvelope: Decodable {
        let current_condition: [CurrentCondition]
        struct CurrentCondition: Decodable {
            let temp_C: String
            let temp_F: String
            let FeelsLikeC: String?
            let FeelsLikeF: String?
            let weatherDesc: [WeatherDesc]
            struct WeatherDesc: Decodable {
                let value: String
            }
        }
    }

    /// Re-fetches weather so `weatherLine` matches the user’s temperature unit preference.
    func refreshWeatherForCurrentUnit() {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            statusLine = "Loading weather…"
            locationManager.requestLocation()
        default:
            break
        }
    }

    private static func prefersFahrenheitDisplay() -> Bool {
        let raw = UserDefaults.standard.string(forKey: PeplosSettingsKeys.temperatureUnit)
            ?? TemperatureUnit.celsius.rawValue
        return TemperatureUnit(rawValue: raw) == .fahrenheit
    }

    /// SF Symbol for WMO weather code (Open-Meteo `weathercode`).
    private static func sfSymbolName(forWMOCode code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1: return "sun.max.fill"
        case 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 56, 57: return "cloud.sleet.fill"
        case 61, 63, 65: return "cloud.rain.fill"
        case 66, 67: return "cloud.sleet.fill"
        case 71, 73, 75: return "cloud.snow.fill"
        case 77: return "snowflake"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 85, 86: return "cloud.snow.fill"
        case 95: return "cloud.bolt.fill"
        case 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.sun.fill"
        }
    }

    /// SF Symbol from wttr.in / free-text description (WorldWeatherOnline-style phrases).
    private static func sfSymbolName(forWeatherDescription description: String) -> String {
        let d = description.lowercased()
        if d.contains("thunder") || d.contains("storm") {
            return d.contains("hail") ? "cloud.bolt.rain.fill" : "cloud.bolt.fill"
        }
        if d.contains("blizzard") || d.contains("snow") || d.contains("sleet") || d.contains("ice pellets") {
            return "cloud.snow.fill"
        }
        if d.contains("rain") || d.contains("drizzle") || d.contains("shower") {
            return d.contains("heavy") ? "cloud.heavyrain.fill" : "cloud.rain.fill"
        }
        if d.contains("fog") || d.contains("mist") || d.contains("haze") {
            return "cloud.fog.fill"
        }
        if d.contains("overcast") {
            return "cloud.fill"
        }
        if d.contains("cloudy") || d.contains("partly") || d.contains("broken") {
            return "cloud.sun.fill"
        }
        if d.contains("clear") || d.contains("sunny") {
            return "sun.max.fill"
        }
        return "cloud.sun.fill"
    }

    /// WMO weather interpretation codes (Open-Meteo).
    private static func describeWeatherCode(_ code: Int) -> String {
        switch code {
        case 0: return "Clear"
        case 1: return "Mainly clear"
        case 2: return "Partly cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Foggy"
        case 51, 53, 55: return "Drizzle"
        case 56, 57: return "Freezing drizzle"
        case 61, 63, 65: return "Rain"
        case 66, 67: return "Freezing rain"
        case 71, 73, 75: return "Snow"
        case 77: return "Snow grains"
        case 80, 81, 82: return "Rain showers"
        case 85, 86: return "Snow showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Thunderstorm with hail"
        default: return "Mixed conditions"
        }
    }
}
