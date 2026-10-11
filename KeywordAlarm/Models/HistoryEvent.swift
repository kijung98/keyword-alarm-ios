import Foundation

/// 단축어가 앱을 호출할 때마다 남기는 기록.
/// 개인정보 보호를 위해 문자 전문은 저장하지 않고, 판정 결과와 일치한 키워드만 남긴다.
struct HistoryEvent: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var result: CheckResult
    var matchedKeyword: String?
    /// 문자에서 읽은 요약 (예: "💰+30,000원 · 오늘 오후조 18:00 · 인천14 · HUB")
    var summary: String? = nil
}

enum CheckResult: String, Codable {
    case fired          // 알람 울림
    case noMatch        // 키워드 없음
    case outsideTime    // 감시 시간대 아님
    case disabled       // 감시 꺼짐
    case cooldown       // 직전에 이미 울림
    case otherCenter    // 내 센터가 아님 (센터 제한 켰을 때)
    case pastDate       // 적용일자가 이미 지남
    case notAuthorized  // 알람 권한 없음
    case failed         // 알람 예약 실패

    var label: String {
        switch self {
        case .fired: "알람 울림"
        case .noMatch: "키워드 없음"
        case .outsideTime: "감시 시간 아님"
        case .disabled: "감시 꺼짐"
        case .cooldown: "중복 방지로 건너뜀"
        case .otherCenter: "다른 센터라 건너뜀"
        case .pastDate: "지난 날짜라 건너뜀"
        case .notAuthorized: "알람 권한 없음"
        case .failed: "알람 예약 실패"
        }
    }

    var symbol: String {
        switch self {
        case .fired: "alarm.fill"
        case .noMatch: "text.magnifyingglass"
        case .outsideTime: "clock"
        case .disabled: "pause.circle"
        case .cooldown: "hourglass"
        case .otherCenter: "building.2"
        case .pastDate: "calendar.badge.minus"
        case .notAuthorized, .failed: "exclamationmark.triangle.fill"
        }
    }
}

enum HistoryRepository {
    private static let key = "keywordAlarm.history.v1"
    private static let maxCount = 50

    static func load(defaults: UserDefaults = .standard) -> [HistoryEvent] {
        guard let data = defaults.data(forKey: key),
              let events = try? JSONDecoder().decode([HistoryEvent].self, from: data)
        else { return [] }
        return events
    }

    static func append(_ event: HistoryEvent, defaults: UserDefaults = .standard) {
        var events = load(defaults: defaults)
        events.insert(event, at: 0)
        if events.count > maxCount { events = Array(events.prefix(maxCount)) }
        if let data = try? JSONEncoder().encode(events) {
            defaults.set(data, forKey: key)
        }
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }

    /// 마지막으로 실제 알람이 울린 시각 (중복 방지용)
    static func lastFiredDate(defaults: UserDefaults = .standard) -> Date? {
        lastFired(defaults: defaults)?.date
    }

    static func lastFired(defaults: UserDefaults = .standard) -> HistoryEvent? {
        load(defaults: defaults).first(where: { $0.result == .fired })
    }
}
