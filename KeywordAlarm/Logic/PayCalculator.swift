import Foundation

/// 급여 계산 규칙 (2026년 기준, 2026-10 조사).
/// 모든 금액은 '추정'이며 실제 지급액은 회사 급여명세서가 기준이다.
///
/// - 최저임금: 시간당 10,320원
/// - 연장근로: 하루 8시간 초과분 + 추가 연장시간 → 시급 × 1.5
/// - 야간근로: 22:00~06:00 근무시간 → 시급 × 0.5 가산
/// - 주휴수당: 주(일~토) 단위. 금액 = min(주 근무시간, 40) ÷ 40 × 8 × 평균시급
///     · 법 기준: 주 15시간 이상 (근로기준법)
///     · 회사 기준: 주 N일 이상 (쿠팡 공지 '일~토 기준 주 5일'. 고용노동부가 2025.11 개선 명령)
/// - 공제(추정): 고용보험 0.9% / 월 8일 또는 60시간 이상이면 국민연금 4.75%·건강보험 3.595%·장기요양(건강보험료의 13.14%)
///     · 일용근로소득세: (일급 − 150,000) × 2.7%, 1,000원 미만이면 0 / 지방소득세 = 소득세의 10%
enum PayRates {
    static let minimumWage2026 = 10_320
    static let overtimeMultiplier = 1.5
    static let nightPremium = 0.5
    static let employmentInsurance = 0.009
    static let nationalPension = 0.0475
    static let healthInsurance = 0.03595
    static let longTermCareOfHealth = 0.1314
    static let dailyTaxDeduction = 150_000
    static let dailyTaxRate = 0.027        // 6% × (1 − 55% 세액공제)
    static let smallTaxExemption = 1_000
    static let localTaxRate = 0.1
}

struct DayPay: Equatable {
    var workedHours: Double      // 실근무 (휴게 제외)
    var regularHours: Double     // 8시간까지
    var overtimeHours: Double
    var nightHours: Double
    var base: Int
    var overtime: Int
    var night: Int
    var incentive: Int

    var total: Int { base + overtime + night + incentive }
}

struct WeekSummary: Identifiable, Equatable {
    var start: DayKey            // 일요일
    var end: DayKey              // 토요일
    var workDays: Int
    var regularHours: Double     // 주휴 계산용 (하루 8시간까지 합계)
    var averageWage: Double
    var qualifiesCompany: Bool   // 주 N일 이상
    var qualifiesLegal: Bool     // 주 15시간 이상
    var companyHolidayPay: Int
    var legalHolidayPay: Int
    var appliedHolidayPay: Int   // 설정한 기준으로 지급되는 금액
    var daysToCompanyRule: Int   // 회사 기준까지 남은 일수

    var id: String { start.id }
}

struct Deductions: Equatable {
    var employment = 0
    var pension = 0
    var health = 0
    var longTermCare = 0
    var incomeTax = 0
    var localTax = 0

    var total: Int { employment + pension + health + longTermCare + incomeTax + localTax }
}

struct BonusProgress: Identifiable, Equatable {
    var rule: MonthlyBonusRule
    var achieved: Bool
    var id: UUID { rule.id }
}

struct MonthSummary: Equatable {
    var year: Int
    var month: Int
    var workDays: Int
    var totalHours: Double
    var base: Int
    var overtime: Int
    var night: Int
    var incentive: Int
    var holidayPay: Int
    var bonuses: [BonusProgress]
    var bonusTotal: Int
    var weeks: [WeekSummary]
    var insuranceLikely: Bool
    var daysToInsurance: Int
    var deductions: Deductions

    var gross: Int { base + overtime + night + incentive + holidayPay + bonusTotal }
    var net: Int { gross - deductions.total }
}

enum PayCalculator {

    // MARK: 하루

    static func dayPay(_ r: WorkRecord) -> DayPay {
        let span = spanMinutes(start: r.startMinute, end: r.endMinute)
        let worked = max(0, Double(span - r.breakMinutes)) / 60
        let wage = Double(r.hourlyWage)

        let regular = min(worked, 8)
        let otHours = max(0, worked - 8) + max(0, r.overtimeHours)

        let nightRaw = Double(nightOverlapMinutes(start: r.startMinute, span: span)) / 60
        // 휴게시간은 근무 시간에 고르게 있었다고 보고 야간 시간도 같은 비율로 줄인다
        let nightHours = span > 0 ? nightRaw * (worked * 60 / Double(span)) : 0

        let base: Int
        let night: Int
        if let override = r.dailyPayOverride {
            base = override            // 문자에 나온 일급에 기본·야간이 이미 포함
            night = 0
        } else {
            base = Int((regular * wage).rounded())
            night = r.applyNightPremium ? Int((nightHours * wage * PayRates.nightPremium).rounded()) : 0
        }
        // 일급을 직접 넣은 경우 8시간 초과 자동 연장은 일급에 포함됐다고 보고, 추가 연장시간만 계산
        let paidOT = r.dailyPayOverride != nil ? max(0, r.overtimeHours) : otHours
        let overtime = Int((paidOT * wage * PayRates.overtimeMultiplier).rounded())

        return DayPay(workedHours: worked, regularHours: regular, overtimeHours: paidOT, nightHours: nightHours,
                      base: base, overtime: overtime, night: night, incentive: max(0, r.incentive))
    }

    static func spanMinutes(start: Int, end: Int) -> Int {
        let s = ((start % 1440) + 1440) % 1440
        let e = ((end % 1440) + 1440) % 1440
        return e > s ? e - s : (e == s ? 0 : e + 1440 - s)
    }

    /// [start, start+span) 과 22:00~06:00 이 겹치는 분
    static func nightOverlapMinutes(start: Int, span: Int) -> Int {
        let s = start, e = start + span
        var total = 0
        for k in -1...2 {
            let ns = k * 1440 + 22 * 60
            let ne = k * 1440 + 30 * 60
            total += max(0, min(e, ne) - max(s, ns))
        }
        return total
    }

    // MARK: 주

    static func weekSummary(start: DayKey, records: [WorkRecord], settings: PaySettings,
                            calendar: Calendar = .current) -> WeekSummary {
        let end = start.adding(days: 6, calendar: calendar)
        let inWeek = records.filter { $0.day >= start && $0.day <= end }
        let days = Set(inWeek.map(\.day)).count
        let pays = inWeek.map(dayPay)
        let regularHours = pays.map(\.regularHours).reduce(0, +)
        let wageHours = zip(inWeek, pays).map { Double($0.hourlyWage) * $1.regularHours }.reduce(0, +)
        let avgWage = regularHours > 0 ? wageHours / regularHours : Double(settings.defaultHourlyWage)

        let amount = Int((min(regularHours, 40) / 40 * 8 * avgWage).rounded())
        let company = days >= settings.holidayMinDays && regularHours >= 15
        let legal = regularHours >= 15
        let applied: Int = switch settings.holidayRule {
        case .companyDays: company ? amount : 0
        case .legalHours: legal ? amount : 0
        }
        return WeekSummary(start: start, end: end, workDays: days, regularHours: regularHours,
                           averageWage: avgWage, qualifiesCompany: company, qualifiesLegal: legal,
                           companyHolidayPay: company ? amount : 0, legalHolidayPay: legal ? amount : 0,
                           appliedHolidayPay: applied,
                           daysToCompanyRule: max(0, settings.holidayMinDays - days))
    }

    // MARK: 월

    static func monthSummary(year: Int, month: Int, records: [WorkRecord], settings: PaySettings,
                             calendar: Calendar = .current) -> MonthSummary {
        let inMonth = records.filter { $0.day.year == year && $0.day.month == month }
        let pays = inMonth.map(dayPay)
        let workDays = Set(inMonth.map(\.day)).count
        // 총 근무시간 = 실근무 + 추가 연장
        let totalHours = zip(inMonth, pays).map { $1.workedHours + max(0, $0.overtimeHours) }.reduce(0, +)

        // 주휴: 토요일이 이번 달에 속한 주를 이번 달 몫으로 계산 (주가 끝나야 확정되므로)
        let first = DayKey(year: year, month: month, day: 1)
        var weeks: [WeekSummary] = []
        var ws = first.weekStart(calendar: calendar)
        while true {
            let we = ws.adding(days: 6, calendar: calendar)
            if (we.year, we.month) > (year, month) { break }
            if we.year == year && we.month == month {
                weeks.append(weekSummary(start: ws, records: records, settings: settings, calendar: calendar))
            }
            ws = ws.adding(days: 7, calendar: calendar)
        }
        let holiday = weeks.map(\.appliedHolidayPay).reduce(0, +)

        let bonuses = settings.bonusRules.sorted { $0.minDays < $1.minDays }
            .map { BonusProgress(rule: $0, achieved: workDays >= $0.minDays) }
        let bonusTotal = bonuses.filter(\.achieved).map(\.rule.amount).reduce(0, +)

        let base = pays.map(\.base).reduce(0, +)
        let ot = pays.map(\.overtime).reduce(0, +)
        let night = pays.map(\.night).reduce(0, +)
        let incentive = pays.map(\.incentive).reduce(0, +)
        let gross = base + ot + night + incentive + holiday + bonusTotal

        let insurance = workDays >= settings.insuranceMinDays || totalHours >= settings.insuranceMinHours
        var d = Deductions()
        if settings.applyDeductions && gross > 0 {
            d.employment = won(Double(gross) * PayRates.employmentInsurance)
            if insurance {
                d.pension = won(Double(gross) * PayRates.nationalPension)
                d.health = won(Double(gross) * PayRates.healthInsurance)
                d.longTermCare = won(Double(d.health) * PayRates.longTermCareOfHealth)
            }
            for p in pays {
                let tax = dailyIncomeTax(p.total)
                d.incomeTax += tax
                d.localTax += won(Double(tax) * PayRates.localTaxRate)
            }
        }

        return MonthSummary(year: year, month: month, workDays: workDays, totalHours: totalHours,
                            base: base, overtime: ot, night: night, incentive: incentive,
                            holidayPay: holiday, bonuses: bonuses, bonusTotal: bonusTotal, weeks: weeks,
                            insuranceLikely: insurance,
                            daysToInsurance: max(0, settings.insuranceMinDays - workDays),
                            deductions: d)
    }

    /// 일용근로소득세 (하루 단위)
    static func dailyIncomeTax(_ dailyPay: Int) -> Int {
        let tax = won(Double(max(0, dailyPay - PayRates.dailyTaxDeduction)) * PayRates.dailyTaxRate)
        return tax < PayRates.smallTaxExemption ? 0 : tax
    }

    /// 10원 미만 버림
    static func won(_ value: Double) -> Int {
        Int(value / 10) * 10
    }

    /// "12.3만" 같은 짧은 표시
    static func shortWon(_ value: Int) -> String {
        if value >= 10_000 {
            let man = Double(value) / 10_000
            return man >= 100 ? "\(Int(man))만" : String(format: "%.1f만", man).replacingOccurrences(of: ".0만", with: "만")
        }
        return IncentiveOffer.won(value)
    }
}
