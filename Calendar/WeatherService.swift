import Foundation
import CoreLocation
import SwiftUI
import WeatherKit

// MARK: - WeatherCondition

enum WeatherCondition: String, Codable, Equatable {
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
/// - WeatherKit: Apple Developer Portal > Identifiers > WeatherKit 활성화 필요.
/// - 위치 권한 거부 또는 양쪽 API 모두 실패 시 dailyWeather 빈 상태 → WeekStripView 이모지 대체.
final class WeatherService: NSObject, ObservableObject {
    @Published var dailyWeather: [String: WeatherCondition] = [:]
    @Published var dailyTemperature: [String: Int] = [:]

    private let locationManager = CLLocationManager()
    private var hasFetched = false
    private let cacheKey = "wc.dailyWeather"
    private let temperatureCacheKey = "wc.dailyTemperature"
    private let lastFetchDateKey = "wc.lastFetchDate"

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode([String: WeatherCondition].self, from: data) {
            dailyWeather = cached
        }
        if let data = UserDefaults.standard.data(forKey: temperatureCacheKey),
           let cached = try? JSONDecoder().decode([String: Int].self, from: data) {
            dailyTemperature = cached
        }
    }

    func requestLocationAndFetch() {
        if let last = UserDefaults.standard.object(forKey: lastFetchDateKey) as? Date,
           Calendar.current.isDateInToday(last) {
            guard !hasFetched else { return }
        } else {
            hasFetched = false
        }
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        default:
            print("[Weather] 위치 권한 거부됨 — 날씨 조회 불가")
        }
    }

    private func fetchWeather(lat: Double, lon: Double) {
        guard !hasFetched else { return }
        hasFetched = true
        locationManager.stopUpdatingLocation()
        print("[Weather] 위치 획득 (\(String(format: "%.4f", lat)), \(String(format: "%.4f", lon))) — 날씨 조회 시작")
        Task {
            await fetchWithWeatherKit(lat: lat, lon: lon)
        }
    }

    // MARK: WeatherKit (primary)

    private func fetchWithWeatherKit(lat: Double, lon: Double) async {
        print("[Weather] WeatherKit 조회 중...")
        let location = CLLocation(latitude: lat, longitude: lon)
        do {
            let forecast = try await WeatherKit.WeatherService.shared
                .weather(for: location, including: .daily)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            var result: [String: WeatherCondition] = [:]
            var tempResult: [String: Int] = [:]
            for day in forecast.forecast {
                let key = formatter.string(from: day.date)
                result[key] = .from(wkCondition: day.condition)
                tempResult[key] = Int(day.highTemperature.converted(to: .celsius).value.rounded())
            }
            print("[Weather] WeatherKit 성공: \(result.count)일")
            await MainActor.run {
                if result != self.dailyWeather {
                    self.dailyWeather = result
                    if let data = try? JSONEncoder().encode(result) {
                        UserDefaults.standard.set(data, forKey: self.cacheKey)
                    }
                }
                self.dailyTemperature = tempResult
                if let data = try? JSONEncoder().encode(tempResult) {
                    UserDefaults.standard.set(data, forKey: self.temperatureCacheKey)
                }
                UserDefaults.standard.set(Date(), forKey: self.lastFetchDateKey)
            }
        } catch {
            print("[Weather] WeatherKit 실패: \(error.localizedDescription) — Open-Meteo 폴백")
            fetchWithOpenMeteo(lat: lat, lon: lon)
        }
    }

    // MARK: Open-Meteo (fallback)
    // 파라미터: weather_code (신규 API명칭; 구버전 weathercode도 CodingKeys로 대응)

    private func fetchWithOpenMeteo(lat: Double, lon: Double) {
        let urlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&daily=weather_code,temperature_2m_max&timezone=auto&forecast_days=16&past_days=7"
        guard let url = URL(string: urlStr) else { return }
        print("[Weather] Open-Meteo 조회 중: \(urlStr)")
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self else { return }
            if let error {
                print("[Weather] Open-Meteo 네트워크 오류: \(error.localizedDescription)")
                return
            }
            guard let data else {
                print("[Weather] Open-Meteo 응답 데이터 없음")
                return
            }
            guard let resp = try? JSONDecoder().decode(OpenMeteoResponse.self, from: data) else {
                let preview = String(data: data.prefix(300), encoding: .utf8) ?? "(non-utf8)"
                print("[Weather] Open-Meteo 디코드 실패. 응답 미리보기: \(preview)")
                return
            }
            var result: [String: WeatherCondition] = [:]
            var tempResult: [String: Int] = [:]
            for (i, dateStr) in resp.daily.time.enumerated() where i < resp.daily.weatherCode.count {
                guard let code = resp.daily.weatherCode[i] else { continue }
                result[dateStr] = .from(wmoCode: code)
                if i < resp.daily.temperatureMax.count, let t = resp.daily.temperatureMax[i] {
                    tempResult[dateStr] = Int(t.rounded())
                }
            }
            print("[Weather] Open-Meteo 성공: \(result.count)일")
            DispatchQueue.main.async {
                if result != self.dailyWeather {
                    self.dailyWeather = result
                    if let data = try? JSONEncoder().encode(result) {
                        UserDefaults.standard.set(data, forKey: self.cacheKey)
                    }
                }
                self.dailyTemperature = tempResult
                if let data = try? JSONEncoder().encode(tempResult) {
                    UserDefaults.standard.set(data, forKey: self.temperatureCacheKey)
                }
                UserDefaults.standard.set(Date(), forKey: self.lastFetchDateKey)
            }
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
            print("[Weather] 위치 권한 허용 — 위치 조회 시작")
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[Weather] 위치 조회 실패: \(error.localizedDescription) — 이모지 대체 표시")
    }
}

private struct OpenMeteoResponse: Decodable {
    struct Daily: Decodable {
        let time: [String]
        let weatherCode: [Int?]
        let temperatureMax: [Double?]

        enum CodingKeys: String, CodingKey {
            case time
            case weatherCode = "weather_code"
            case temperatureMax = "temperature_2m_max"
        }
    }
    let daily: Daily
}
