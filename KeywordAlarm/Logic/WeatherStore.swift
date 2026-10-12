import Foundation
import CoreLocation
import WeatherKit
import Observation

/// 날씨 지역 (위치 권한 없이 고르는 방식 — 개인정보 부담 없음)
struct WeatherRegion: Identifiable, Hashable {
    let name: String
    let latitude: Double
    let longitude: Double
    var id: String { name }

    static let all: [WeatherRegion] = [
        WeatherRegion(name: "인천", latitude: 37.4563, longitude: 126.7052),
        WeatherRegion(name: "인천 서구", latitude: 37.5452, longitude: 126.6760),
        WeatherRegion(name: "김포", latitude: 37.6153, longitude: 126.7156),
        WeatherRegion(name: "부천", latitude: 37.5034, longitude: 126.7660),
        WeatherRegion(name: "서울", latitude: 37.5665, longitude: 126.9780),
        WeatherRegion(name: "고양", latitude: 37.6584, longitude: 126.8320),
        WeatherRegion(name: "안산", latitude: 37.3219, longitude: 126.8309),
        WeatherRegion(name: "용인", latitude: 37.2411, longitude: 127.1776),
        WeatherRegion(name: "이천", latitude: 37.2720, longitude: 127.4350),
        WeatherRegion(name: "평택", latitude: 36.9921, longitude: 127.1129),
        WeatherRegion(name: "천안", latitude: 36.8151, longitude: 127.1139),
        WeatherRegion(name: "대전", latitude: 36.3504, longitude: 127.3845),
        WeatherRegion(name: "대구", latitude: 35.8714, longitude: 128.6014),
        WeatherRegion(name: "광주", latitude: 35.1595, longitude: 126.8526),
        WeatherRegion(name: "부산", latitude: 35.1796, longitude: 129.0756)
    ]

    static func named(_ name: String) -> WeatherRegion {
        all.first { $0.name == name } ?? all[0]
    }
}

struct DayForecast: Identifiable, Equatable {
    let date: Date
    let symbol: String
    let condition: String
    let high: Int
    let low: Int
    let rainChance: Int        // %
    var id: Date { date }

    var needsUmbrella: Bool { rainChance >= 50 }
}

/// 출근 시간대 비 예보 (예: 오늘 17~19시 비 70%)
struct CommuteRain: Equatable {
    let date: Date
    let chance: Int
}

/// WeatherKit(애플 날씨)으로 일별·출근 시간대 예보를 가져온다.
/// 사전 준비: Apple Developer 사이트 → Identifiers → 앱 ID → Capabilities와 App Services에서 WeatherKit 켜기
@MainActor
@Observable
final class WeatherStore {
    var days: [DayForecast] = []
    var commute: CommuteRain?
    var attributionLogoLight: URL?
    var attributionLogoDark: URL?
    var attributionLink: URL?
    var errorMessage: String?
    var errorDetail: String?
    var isLoading = false
    private var lastKey: String?
    private var lastLoaded: Date?

    /// 30분 안에 같은 지역을 다시 부르면 저장된 값을 쓴다 (호출 수 절약)
    func load(region: WeatherRegion, commuteStartMinute: Int, force: Bool = false) async {
        let key = region.name
        if !force, key == lastKey, let last = lastLoaded, Date().timeIntervalSince(last) < 1800, !days.isEmpty { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let location = CLLocation(latitude: region.latitude, longitude: region.longitude)
            let (daily, hourly) = try await WeatherService.shared.weather(for: location, including: .daily, .hourly)
            days = daily.forecast.prefix(3).map { d in
                DayForecast(date: d.date,
                            symbol: d.symbolName,
                            condition: d.condition.description,
                            high: Int(d.highTemperature.converted(to: .celsius).value.rounded()),
                            low: Int(d.lowTemperature.converted(to: .celsius).value.rounded()),
                            rainChance: Int((d.precipitationChance * 100).rounded()))
            }
            commute = Self.nextCommuteRain(hourly: Array(hourly.forecast), startMinute: commuteStartMinute)
            if attributionLink == nil {
                let a = try await WeatherService.shared.attribution
                attributionLogoLight = a.combinedMarkLightURL
                attributionLogoDark = a.combinedMarkDarkURL
                attributionLink = a.legalPageURL
            }
            errorMessage = nil
            errorDetail = nil
            lastKey = key
            lastLoaded = Date()
        } catch {
            let text = "\(error)"
            errorDetail = text
            let lower = text.lowercased()
            if lower.contains("jwt") || lower.contains("auth") || lower.contains("401") || lower.contains("entitle") {
                errorMessage = "WeatherKit 사용 허가가 아직 적용되지 않았어요. 개발자 사이트 App Services에서 WeatherKit을 켜고 30분쯤 뒤 다시 시도하세요."
            } else if lower.contains("offline") || lower.contains("network") || lower.contains("internet") {
                errorMessage = "인터넷 연결을 확인해 주세요."
            } else {
                errorMessage = "날씨를 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
            }
        }
    }

    /// 다음 출근(출근 1시간 전 ~ 출근 시각) 중 가장 높은 강수 확률
    private static func nextCommuteRain(hourly: [HourWeather], startMinute: Int) -> CommuteRain? {
        let cal = Calendar.current
        let now = Date()
        for offset in 0...1 {
            guard let day = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: now)),
                  let start = cal.date(byAdding: .minute, value: startMinute, to: day),
                  start > now else { continue }
            let from = start.addingTimeInterval(-3600)
            let window = hourly.filter { $0.date >= from.addingTimeInterval(-1800) && $0.date <= start }
            guard let maxChance = window.map(\.precipitationChance).max() else { return nil }
            return CommuteRain(date: start, chance: Int((maxChance * 100).rounded()))
        }
        return nil
    }
}
