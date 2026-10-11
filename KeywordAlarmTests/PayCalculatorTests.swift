import XCTest
@testable import KeywordAlarm

final class PayCalculatorTests: XCTestCase {

    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }()

    private func record(_ m: Int, _ d: Int, start: Int = 8 * 60, end: Int = 17 * 60) -> WorkRecord {
        WorkRecord(day: DayKey(year: 2026, month: m, day: d), startMinute: start, endMinute: end,
                   breakMinutes: 60, hourlyWage: 10_320)
    }

    // MARK: 하루

    func testNightShiftPay() {
        // 오후조 18:00~04:00, 휴게 1시간 → 실근무 9시간 (기본 8 + 연장 1), 야간 6시간 × 9/10
        var r = record(10, 11, start: 18 * 60, end: 4 * 60)
        r.incentive = 30_000
        let p = PayCalculator.dayPay(r)
        XCTAssertEqual(p.workedHours, 9, accuracy: 0.001)
        XCTAssertEqual(p.base, 82_560)       // 8 × 10,320
        XCTAssertEqual(p.overtime, 15_480)   // 1 × 10,320 × 1.5
        XCTAssertEqual(p.night, 27_864)      // 5.4 × 10,320 × 0.5
        XCTAssertEqual(p.total, 155_904)
    }

    func testDayShiftHasNoNightPremium() {
        let p = PayCalculator.dayPay(record(10, 5))
        XCTAssertEqual(p.total, 82_560)
        XCTAssertEqual(p.night, 0)
    }

    func testDailyPayOverride() {
        var r = record(10, 11, start: 18 * 60, end: 4 * 60)
        r.dailyPayOverride = 125_280   // 문자에 나온 일급
        r.overtimeHours = 1            // 추가 연장 1시간
        let p = PayCalculator.dayPay(r)
        XCTAssertEqual(p.base, 125_280)
        XCTAssertEqual(p.night, 0)
        XCTAssertEqual(p.overtime, 15_480)
    }

    func testDailyIncomeTax() {
        XCTAssertEqual(PayCalculator.dailyIncomeTax(200_000), 1_350)
        XCTAssertEqual(PayCalculator.dailyIncomeTax(180_000), 0)   // 810원 → 소액부징수
        XCTAssertEqual(PayCalculator.dailyIncomeTax(82_560), 0)
    }

    // MARK: 주휴

    func testFiveDayWeekGetsHolidayPay() {
        let records = (4...8).map { record(10, $0) }   // 10/4(일)~10/8(목), 8시간씩
        let w = PayCalculator.weekSummary(start: DayKey(year: 2026, month: 10, day: 4), records: records,
                                          settings: PaySettings(), calendar: calendar)
        XCTAssertEqual(w.workDays, 5)
        XCTAssertTrue(w.qualifiesCompany)
        XCTAssertEqual(w.appliedHolidayPay, 82_560)   // 40/40 × 8 × 10,320
    }

    func testFourDayWeekLegalVsCompany() {
        let records = (4...7).map { record(10, $0) }   // 4일 32시간
        let w = PayCalculator.weekSummary(start: DayKey(year: 2026, month: 10, day: 4), records: records,
                                          settings: PaySettings(), calendar: calendar)
        XCTAssertFalse(w.qualifiesCompany)
        XCTAssertTrue(w.qualifiesLegal)
        XCTAssertEqual(w.appliedHolidayPay, 0)        // 회사 기준(주 5일)으로는 0
        XCTAssertEqual(w.legalHolidayPay, 66_048)     // 법 기준이면 32/40 × 8 × 10,320
        XCTAssertEqual(w.daysToCompanyRule, 1)

        var legal = PaySettings()
        legal.holidayRule = .legalHours
        XCTAssertEqual(PayCalculator.weekSummary(start: DayKey(year: 2026, month: 10, day: 4), records: records,
                                                 settings: legal, calendar: calendar).appliedHolidayPay, 66_048)
    }

    func testWeekStartsOnSunday() {
        XCTAssertEqual(DayKey(year: 2026, month: 10, day: 8).weekStart(calendar: calendar),
                       DayKey(year: 2026, month: 10, day: 4))
    }

    // MARK: 월

    func testMonthWithInsurance() {
        // 10/4~10/8 (5일) + 10/11~10/13 (3일) = 8일
        let records = (4...8).map { record(10, $0) } + (11...13).map { record(10, $0) }
        let m = PayCalculator.monthSummary(year: 2026, month: 10, records: records,
                                           settings: PaySettings(), calendar: calendar)
        XCTAssertEqual(m.workDays, 8)
        XCTAssertEqual(m.base, 660_480)
        XCTAssertEqual(m.holidayPay, 82_560)          // 10/4 주만 5일
        XCTAssertEqual(m.gross, 743_040)
        XCTAssertTrue(m.insuranceLikely)
        XCTAssertEqual(m.deductions.employment, 6_680)
        XCTAssertEqual(m.deductions.pension, 35_290)
        XCTAssertEqual(m.deductions.health, 26_710)
        XCTAssertEqual(m.deductions.longTermCare, 3_500)
        XCTAssertEqual(m.deductions.incomeTax, 0)
        XCTAssertEqual(m.net, 670_860)
    }

    func testMonthBelowInsuranceThreshold() {
        let records = (4...8).map { record(10, $0) } + (11...12).map { record(10, $0) }   // 7일 56시간
        let m = PayCalculator.monthSummary(year: 2026, month: 10, records: records,
                                           settings: PaySettings(), calendar: calendar)
        XCTAssertFalse(m.insuranceLikely)
        XCTAssertEqual(m.daysToInsurance, 1)
        XCTAssertEqual(m.deductions.pension, 0)
        XCTAssertGreaterThan(m.deductions.employment, 0)
    }

    func testMonthlyBonusRule() {
        var s = PaySettings()
        s.bonusRules = [MonthlyBonusRule(name: "15일 만근", minDays: 15, amount: 100_000)]
        let records = (1...15).map { record(10, $0) }
        let m = PayCalculator.monthSummary(year: 2026, month: 10, records: records, settings: s, calendar: calendar)
        XCTAssertEqual(m.bonusTotal, 100_000)
        XCTAssertTrue(m.bonuses[0].achieved)
    }

    func testShortWon() {
        XCTAssertEqual(PayCalculator.shortWon(125_904), "12.6만")
        XCTAssertEqual(PayCalculator.shortWon(80_000), "8만")
        XCTAssertEqual(PayCalculator.shortWon(1_250_000), "125만")
    }
}
