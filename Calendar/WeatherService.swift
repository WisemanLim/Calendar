import Foundation
import CoreLocation
import SwiftUI
import WeatherKit

// MARK: - WeatherCondition

enum WeatherCondition {
    case clear, partlyCloudy, overcast, fog
    case drizzle, rain, heavyRain, snow, thunderstorm

    var sfSymbol: String {
        switch self {
        case .clear:        return "sun.max.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .overcast:     return "cloud.fill"
        case .fog:          return "cloud.fog.fill"
        case .drizzle:      return "cloud.drizzle.fill"
        case .rain:         return "cloud.rain.fill"
        case .heavyRain:    return "cloud.heavyrain.fill"
        case .snow:         return "snowflake"
        case .thunderstorm: return "cloud.bolt.rain.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .clear:        return Color(red: 1.0, green: 0.75, blue: 0.0)
        case .partlyCloudy: return Color(red: 1.0, green: 0.60, blue: 0.2)
        case .overcast:     return .gray
        case .fog:          return Color.gray.opacity(0.7)
        case .drizzle:      return Color(red: 0.4, green: 0.6, blue: 0.9)
        case .rain:         return Color(red: 0.2, green: 0.4, blue: 0.9)
        case .heavyRain:    return Color(red: 0.0, green: 0.2, blue: 0.8)
        case .snow:         return .cyan
        case .thunderstorm: return Color(red: 0.5, green: 0.1, blue: 0.8)
        }
    }

    // MARK: WeatherKit mapping
    static func from(wkCondition: WeatherKit.WeatherCondition) -> WeatherCondition {
        switch wkCondition {
        case .clear, .mostlyClear, .hot:
            return .clear
        case .partlyCloudy, .sunShowers, .sunFlurries:
            return .partlyCloudy
        case .mostlyCloudy, .cloudy, .breezy, .windy, .blowingDust:
            return .overcast
        case .foggy, .haze, .smoky:
            return .fog
        case .drizzle, .freezingDrizzle:
            return .drizzle
        case .rain, .freezingRain, .sleet, .wintryMix:
            return .rain
        case .heavyRain:
            return .heavyRain
        case .snow, .heavySnow, .blizzard, .blowingSnow, .flurries:
            return .snow
        case .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms,
             .strongStorms, .tropicalStorm, .hurricane:
            return .thunderstorm
        default:
            return .clear
        }
    }

    // WMO weather code mapping (Open-Meteo fallback)
    static func from(wmoCode: Int) -> WeatherCondition {
        switch wmoCode {
        case 0, 1:                   return .clear
        case 2:                      return .partlyCloudy
        case 3:                      return .overcast
        case 45, 48:                 return .fog
        case 51, 53, 55, 56, 57:     return .drizzle
        case 61, 63, 66:             return .rain
        case 65, 67:                 return .heavyRain
        case 71, 73, 75, 77, 85, 86: return .snow
        case 80, 81:                 return .rain
        case 82:                     return .heavyRain
        case 95, 96, 99:             return .thunderstorm
        default:                     return .clear
        }
    }
}

// MARK: - WeatherService

/// 날씨 서비스: WeatherKit(Apple) 우선, 실패 시 Open-Meteo(무료·API키 없음) 폴백.
/// - WeatherKit 사용을 위해 Apple Developer Portal > Identifiers > WeatherKit 활성화 필요.
/// - 위치 권한 거부 또는 양쪽 API 모두 실패 시 dailyWeather 빈 상태 → WeekStripView 이모지 대체.
final class WeatherService: NSObject, ObservableObject {
    @Published var dailyWeather: [String: WeatherCondition] = [:]

    private let locationManager = CLLocationManager()
    private var hasFetched = false

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestLocationAndFetch() {
        guard !hasFetched else { return }
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        default:
            break
        }
    }

    private func fetchWeather(lat: Double, lon: Double) {
        hasFetched = true
        Task {
            await fetchWithWeatherKit(lat: lat, lon: lon)
        }
    }

    // MARK: WeatherKit (primary)

    private func fetchWithWeatherKit(lat: Double, lon: Double) async {
        let location = CLLocation(latitude: lat, longitude: lon)
        do {
            let forecast = try await WeatherKit.WeatherService.shared
                .weather(for: location, including: .daily)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            var result: [String: WeatherCondition] = [:]
            for day in forecast.forecast {
                result[formatter.string(from: day.date)] = .from(wkCondition: day.condition)
            }
            await MainActor.run { self.dailyWeather = result }
        } catch {
            // WeatherKit 실패(entitlement 미설정 포함) → Open-Meteo 폴백
            fetchWithOpenMeteo(lat: lat, lon: lon)
        }
    }

    // MARK: Open-Meteo (fallback)

    private func fetchWithOpenMeteo(lat: Double, lon: Double) {
        let urlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&daily=weathercode&timezone=auto&forecast_days=16&past_days=7"
        guard let url = URL(string: urlStr) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data,
                  let resp = try? JSONDecoder().decode(OpenMeteoResponse.self, from: data) else { return }
            var result: [String: WeatherCondition] = [:]
            for (i, dateStr) in resp.daily.time.enumerated() where i < resp.daily.weathercode.count {
                result[dateStr] = .from(wmoCode: resp.daily.weathercode[i])
            }
            DispatchQueue.main.async { self.dailyWeather = result }
        }.resume()
    }
}

extension WeatherService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        fetchWeather(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 위치 실패 → dailyWeather 빈 상태, 이모지 대체
    }
}

private struct OpenMeteoResponse: Decodable {
    struct Daily: Decodable {
        let time: [String]
        let weathercode: [Int]
    }
    let daily: Daily
}
