import Foundation

/// 시간대 문제 없이 '날짜'만 다루기 위한 키 (예: 2026-10-11)
struct DayKey: Codable, Hashable, Comparable, Identifiable {
    var year: Int
    var month: Int
    var day: Int

    var id: String { String(format: "%04d-%02d-%02d", year, month, day) }

    init(year: Int, month: Int, day: Int) {
        self.year = year; self.month = month; self.day = day
    }

    init(_ date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year!, month: c.month!, day: c.day!)
    }

    func date(calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func adding(days: Int, calendar: Calendar = .current) -> DayKey {
        DayKey(calendar.date(byAdding: .day, value: days, to: date(calendar: calendar))!, calendar: calendar)
    }

    /// 1=일 ... 7=토
    func weekday(calendar: Calendar = .current) -> Int {
        calendar.component(.weekday, from: date(calendar: calendar))
    }

    /// 쿠팡 기준 주 시작(일요일)
    func weekStart(calendar: Calendar = .current) -> DayKey {
        adding(days: -(weekday(calendar: calendar) - 1), calendar: calendar)
    }

    static func < (a: DayKey, b: DayKey) -> Bool {
        (a.year, a.month, a.day) < (b.year, b.month, b.day)
    }

    var shortLabel: String { "\(month)/\(day)" }
}

/// 하루 근무 기록
struct WorkRecord: Codable, Identifiable, Equatable {
    var id = UUID()
    var day: DayKey
    var center: String = ""             // 예: 인천14
    var shift: String = ""              // 예: 오후조
    var startMinute: Int = 18 * 60      // 자정 기준 분
    var endMinute: Int = 4 * 60         // 시작보다 작으면 다음날로 계산
    var breakMinutes: Int = 60
    var hourlyWage: Int = 10_320
    /// 문자에 나온 일급(예: 125,280원)을 그대로 쓰고 싶을 때. 넣으면 기본급+야간 계산 대신 이 값을 사용
    var dailyPayOverride: Int? = nil
    /// 근무 끝난 뒤 추가 연장 시간 (8시간 초과분은 자동으로 연장 처리되므로 그 외 추가분만)
    var overtimeHours: Double = 0
    /// 밤 10시~오전 6시 근무 50% 가산 적용
    var applyNightPremium: Bool = true
    /// 인센티브·특별지급 금액
    var incentive: Int = 0
    var memo: String = ""
}

/// 월 근무일수 보너스 규칙 (예: 월 15일 이상 근무 시 +100,000원)
struct MonthlyBonusRule: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var minDays: Int
    var amount: Int
}

/// 주휴수당 판단 기준
enum HolidayPayRule: String, Codable, CaseIterable, Identifiable {
    case companyDays    // 회사 기준: 주 N일 이상 (쿠팡 공지 기준 주 5일)
    case legalHours     // 법 기준: 주 15시간 이상

    var id: String { rawValue }
    var label: String {
        switch self {
        case .companyDays: "회사 기준 (주 N일 이상)"
        case .legalHours: "법 기준 (주 15시간 이상)"
        }
    }
}

/// 급여 계산 설정
struct PaySettings: Codable, Equatable {
    var defaultHourlyWage: Int = 10_320        // 2026년 최저임금
    var defaultStartMinute: Int = 18 * 60
    var defaultEndMinute: Int = 4 * 60
    var defaultBreakMinutes: Int = 60
    var defaultCenter: String = ""

    var holidayRule: HolidayPayRule = .companyDays
    var holidayMinDays: Int = 5                 // 회사 기준 일수 & 축하 기준

    var applyDeductions: Bool = true
    var insuranceMinDays: Int = 8               // 국민연금·건강보험 판단 기준 (월 8일)
    var insuranceMinHours: Double = 60          // 또는 월 60시간

    var monthlyGoal: Int = 0
    var bonusRules: [MonthlyBonusRule] = []

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PaySettings()
        defaultHourlyWage = try c.decodeIfPresent(Int.self, forKey: .defaultHourlyWage) ?? d.defaultHourlyWage
        defaultStartMinute = try c.decodeIfPresent(Int.self, forKey: .defaultStartMinute) ?? d.defaultStartMinute
        defaultEndMinute = try c.decodeIfPresent(Int.self, forKey: .defaultEndMinute) ?? d.defaultEndMinute
        defaultBreakMinutes = try c.decodeIfPresent(Int.self, forKey: .defaultBreakMinutes) ?? d.defaultBreakMinutes
        defaultCenter = try c.decodeIfPresent(String.self, forKey: .defaultCenter) ?? d.defaultCenter
        holidayRule = try c.decodeIfPresent(HolidayPayRule.self, forKey: .holidayRule) ?? d.holidayRule
        holidayMinDays = try c.decodeIfPresent(Int.self, forKey: .holidayMinDays) ?? d.holidayMinDays
        applyDeductions = try c.decodeIfPresent(Bool.self, forKey: .applyDeductions) ?? d.applyDeductions
        insuranceMinDays = try c.decodeIfPresent(Int.self, forKey: .insuranceMinDays) ?? d.insuranceMinDays
        insuranceMinHours = try c.decodeIfPresent(Double.self, forKey: .insuranceMinHours) ?? d.insuranceMinHours
        monthlyGoal = try c.decodeIfPresent(Int.self, forKey: .monthlyGoal) ?? d.monthlyGoal
        bonusRules = try c.decodeIfPresent([MonthlyBonusRule].self, forKey: .bonusRules) ?? d.bonusRules
    }

    func newRecord(on day: DayKey) -> WorkRecord {
        WorkRecord(day: day, center: defaultCenter,
                   startMinute: defaultStartMinute, endMinute: defaultEndMinute,
                   breakMinutes: defaultBreakMinutes, hourlyWage: defaultHourlyWage)
    }
}

/// 근무 기록·급여 설정 저장소
enum WorkRepository {
    private static let recordsKey = "keywordAlarm.workRecords.v1"
    private static let settingsKey = "keywordAlarm.paySettings.v1"

    static func loadRecords(defaults: UserDefaults = .standard) -> [WorkRecord] {
        guard let data = defaults.data(forKey: recordsKey),
              let records = try? JSONDecoder().decode([WorkRecord].self, from: data) else { return [] }
        return records
    }

    static func saveRecords(_ records: [WorkRecord], defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(records) { defaults.set(data, forKey: recordsKey) }
    }

    static func loadSettings(defaults: UserDefaults = .standard) -> PaySettings {
        guard let data = defaults.data(forKey: settingsKey),
              let s = try? JSONDecoder().decode(PaySettings.self, from: data) else { return PaySettings() }
        return s
    }

    static func saveSettings(_ settings: PaySettings, defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: settingsKey) }
    }
}
