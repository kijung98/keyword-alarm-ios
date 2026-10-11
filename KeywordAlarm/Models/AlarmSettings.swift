import Foundation

/// 앱의 모든 설정값. UserDefaults에 JSON으로 저장된다.
struct AlarmSettings: Codable, Equatable {
    /// 감시 ON/OFF
    var isEnabled: Bool = true
    /// 감시할 키워드 목록 (띄어쓰기·대소문자 무시하고 비교)
    /// 쿠팡 인센티브 문자 기준 기본값 (인천14·28/26/36·17/39센터 실제 문자로 검증).
    /// 일반 모집 문자의 "주휴수당 추가 지급"에는 걸리지 않음
    var keywords: [String] = ["인센티브", "특별지급", "추가지급 혜택"]
    /// "+ 30,000", "+30,000원" 같은 금액 패턴도 감지할지
    var detectAmountPattern: Bool = false

    /// 시간대 제한 사용 여부
    var useTimeWindow: Bool = true
    /// 감시 시작 시각 (자정 기준 분). 기본 10:00
    var startMinute: Int = 10 * 60
    /// 감시 종료 시각 (자정 기준 분). 기본 15:00
    var endMinute: Int = 15 * 60
    /// 감시 요일 (Calendar 기준 1=일 ... 7=토). 비어 있으면 매일
    var weekdays: Set<Int> = []

    /// 한 번 울린 뒤 다시 울리지 않는 시간(분). 같은 문자가 연달아 와도 한 번만 울리게.
    var cooldownMinutes: Int = 10

    /// 알람 화면에 표시할 기본 제목 (문자에서 정보를 못 읽었을 때 사용)
    var alarmTitle: String = "기다리던 문자가 도착했어요!"

    /// 내가 다니는 센터 (예: "인천14", "인천 14센터"). 띄어쓰기·'센터' 글자 무시하고 비교
    var preferredCenters: [String] = []
    /// 등록한 센터의 문자만 알람 (끄면 모든 센터 알람 + 다른 센터 표시만)
    var onlyPreferredCenters: Bool = false
    /// 적용일자가 모두 지난 날짜면 울리지 않기
    var skipPastDates: Bool = true

    init() {}

    /// 설정 항목이 늘어나도 예전 저장값을 잃지 않도록, 없는 항목은 기본값으로 채운다.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AlarmSettings()
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? d.isEnabled
        keywords = try c.decodeIfPresent([String].self, forKey: .keywords) ?? d.keywords
        detectAmountPattern = try c.decodeIfPresent(Bool.self, forKey: .detectAmountPattern) ?? d.detectAmountPattern
        useTimeWindow = try c.decodeIfPresent(Bool.self, forKey: .useTimeWindow) ?? d.useTimeWindow
        startMinute = try c.decodeIfPresent(Int.self, forKey: .startMinute) ?? d.startMinute
        endMinute = try c.decodeIfPresent(Int.self, forKey: .endMinute) ?? d.endMinute
        weekdays = try c.decodeIfPresent(Set<Int>.self, forKey: .weekdays) ?? d.weekdays
        cooldownMinutes = try c.decodeIfPresent(Int.self, forKey: .cooldownMinutes) ?? d.cooldownMinutes
        alarmTitle = try c.decodeIfPresent(String.self, forKey: .alarmTitle) ?? d.alarmTitle
        preferredCenters = try c.decodeIfPresent([String].self, forKey: .preferredCenters) ?? d.preferredCenters
        onlyPreferredCenters = try c.decodeIfPresent(Bool.self, forKey: .onlyPreferredCenters) ?? d.onlyPreferredCenters
        skipPastDates = try c.decodeIfPresent(Bool.self, forKey: .skipPastDates) ?? d.skipPastDates
    }

    /// 센터 이름 비교용: "인천 14센터" → "인천14", "인천 17 신선센터" → "인천17"
    static func normalizeCenter(_ name: String) -> String {
        KeywordMatcher.normalize(name)
            .replacingOccurrences(of: "센터", with: "")
            .replacingOccurrences(of: "신선", with: "")
    }

    /// 내가 등록한 센터 이름(예: "인천14", "인천 14센터", "14")이 문자의 센터 코드(예: "인천14")와 같은지.
    /// 숫자만 등록했으면 번호만 비교한다.
    static func centerMatches(preferred: String, code: String) -> Bool {
        let p = normalizeCenter(preferred)
        let c = normalizeCenter(code)
        guard !p.isEmpty else { return false }
        if p.allSatisfy(\.isNumber) {
            return String(c.drop { !$0.isNumber }) == String(Int(p) ?? -1)
        }
        let pRegion = String(p.prefix { !$0.isNumber })
        let pNumber = Int(String(p.drop { !$0.isNumber })) ?? -1
        let cRegion = String(c.prefix { !$0.isNumber })
        let cNumber = Int(String(c.drop { !$0.isNumber })) ?? -2
        return pRegion == cRegion && pNumber == cNumber
    }

    /// 문자의 센터 중 하나라도 내 센터인지. 내 센터 목록이 비었거나 센터를 못 읽었으면 nil(판단 불가)
    func matchesPreferred(_ codes: [String]) -> Bool? {
        guard !preferredCenters.isEmpty, !codes.isEmpty else { return nil }
        return codes.contains { code in preferredCenters.contains { Self.centerMatches(preferred: $0, code: code) } }
    }

    /// 내 센터 코드만 골라냄
    func preferredCodes(in codes: [String]) -> [String] {
        codes.filter { code in preferredCenters.contains { Self.centerMatches(preferred: $0, code: code) } }
    }
}

/// 설정 저장/불러오기. 앱 화면과 단축어(App Intent) 양쪽에서 같은 저장소를 쓴다.
enum SettingsRepository {
    private static let key = "keywordAlarm.settings.v1"

    static func load(defaults: UserDefaults = .standard) -> AlarmSettings {
        guard let data = defaults.data(forKey: key),
              let settings = try? JSONDecoder().decode(AlarmSettings.self, from: data)
        else { return AlarmSettings() }
        return settings
    }

    static func save(_ settings: AlarmSettings, defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: key)
        }
    }
}
