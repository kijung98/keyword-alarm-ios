import XCTest
@testable import KeywordAlarm

final class KeywordMatcherTests: XCTestCase {

    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    private func settings(_ configure: (inout AlarmSettings) -> Void = { _ in }) -> AlarmSettings {
        var s = AlarmSettings()
        configure(&s)
        return s
    }

    private func parse(_ message: String, _ received: Date) -> IncentiveOffer {
        OfferParser.parse(message, receivedAt: received, calendar: calendar)
    }

    // MARK: - 키워드: 세 센터 인센티브 문자는 울리고, 일반 모집 문자는 안 울림

    func testDefaultKeywordsCatchAllIncentiveFormats() {
        let s = settings()
        XCTAssertNotNil(KeywordMatcher.firstMatch(in: RealMessages.inc14, settings: s))
        XCTAssertNotNil(KeywordMatcher.firstMatch(in: RealMessages.inc28, settings: s))
        XCTAssertNotNil(KeywordMatcher.firstMatch(in: RealMessages.inc17_39, settings: s))
        XCTAssertNil(KeywordMatcher.firstMatch(in: RealMessages.normal14, settings: s))
    }

    func testKeywordIgnoresSpaces() {
        let s = settings { $0.keywords = ["특별지급"] }
        XCTAssertEqual(KeywordMatcher.firstMatch(in: "지각, 조퇴시 특별 지급 불가", settings: s), "특별지급")
    }

    func testAmountPattern() {
        let s = settings { $0.keywords = []; $0.detectAmountPattern = true }
        XCTAssertNotNil(KeywordMatcher.firstMatch(in: RealMessages.inc14, settings: s))   // "+ 30,000"
        XCTAssertNil(KeywordMatcher.firstMatch(in: RealMessages.normal14, settings: s))
        XCTAssertNil(KeywordMatcher.firstMatch(in: "1+1 행사", settings: s))
    }

    // MARK: - 형식 1: 인천 14센터

    func testParseIncheon14() {
        let now = date(2026, 10, 11, 10, 40)
        let o = parse(RealMessages.inc14, now)
        XCTAssertEqual(o.centerCodes, ["인천14"])
        XCTAssertEqual(o.centerLabel, "인천 14센터")
        XCTAssertEqual(o.processCodes, ["HUB"])
        XCTAssertEqual(o.bonusMax, 30000)
        XCTAssertEqual(o.bonusDisplay, "+30,000원")
        XCTAssertEqual(o.schedules, [
            ShiftSchedule(year: 2026, month: 10, day: 11, shiftName: "오후조", startTime: "18:00", endTime: "04:00"),
            ShiftSchedule(year: 2026, month: 10, day: 11, shiftName: "심야조", startTime: "20:00", endTime: "06:00")
        ])
        XCTAssertEqual(o.applyURL, "https://coufc.coupang.com/inc14/contents/2/1215")
        XCTAssertTrue(o.isRecipientOnly)
        XCTAssertEqual(o.alarmTitle(now: now, calendar: calendar), "💰+30,000원 · 오늘 오후조 18:00 외 1 · 인천14 · HUB")
    }

    // MARK: - 형식 2: 인천 28·26·36센터

    func testParseIncheon28() {
        let now = date(2026, 10, 11, 14, 0)
        let o = parse(RealMessages.inc28, now)
        XCTAssertEqual(o.centerCodes, ["인천28", "인천26", "인천36"])
        XCTAssertEqual(o.centerShort, "인천28·26·36")
        XCTAssertEqual(o.processCodes, ["HUB"])
        XCTAssertEqual(o.bonusMax, 30000)
        XCTAssertEqual(o.schedules.map(\.shiftText), ["오후조 18:00~04:00", "심야조 21:00~06:00"])
        XCTAssertEqual(o.schedules.first?.relativeLabel(from: now, calendar: calendar), "오늘")
        XCTAssertEqual(o.payLines.map(\.totalPay), [155280, 149715])
        XCTAssertEqual(o.notes, ["심야조는 28센터만 운영 중입니다"])
        XCTAssertEqual(o.applyURL, "https://coufc.coupang.com/inc28/contents/2/1183")
        XCTAssertEqual(o.alarmTitle(now: now, calendar: calendar), "💰+30,000원 · 오늘 오후조 18:00 외 1 · 인천28·26·36 · HUB")
    }

    // MARK: - 형식 3: 인천 17/39 신선센터 (센터·근무조·공정별 금액표)

    func testParseIncheon17and39() {
        let now = date(2026, 10, 10, 11, 0)   // 전날 받은 문자 → '내일'
        let o = parse(RealMessages.inc17_39, now)
        XCTAssertEqual(o.centerCodes, ["인천17", "인천39"])
        XCTAssertEqual(o.processCodes, ["OB", "IB", "QC"])
        XCTAssertEqual(o.bonusMin, 30000)
        XCTAssertEqual(o.bonusMax, 45000)
        XCTAssertEqual(o.bonusDisplay, "+30,000~45,000원")
        XCTAssertEqual(o.schedules.map(\.shiftText), ["주간1 08:00~17:00", "주간3 15:00~00:00"])
        XCTAssertEqual(o.schedules.first?.relativeLabel(from: now, calendar: calendar), "내일")

        XCTAssertEqual(o.payLines.count, 5)
        XCTAssertEqual(o.payLines[0], PayLine(center: "인천17", shift: "주간1", startTime: "08:00", endTime: "17:00",
                                              processes: ["출고(OB)", "입고(IB)"], basePay: 83120, bonus: 40000, totalPay: 123120))
        XCTAssertEqual(o.payLines[1].processes, ["검품(QC)"])
        XCTAssertEqual(o.payLines[3].center, "인천39")
        XCTAssertEqual(o.payLines[3].bonus, 45000)
        XCTAssertEqual(o.applyURL, "https://job.coupangcorp.com/fc_temp/")
        XCTAssertTrue(o.isRecipientOnly)

        XCTAssertEqual(o.alarmTitle(now: now, calendar: calendar),
                       "💰최대 +45,000원 · 내일 주간1 08:00 외 1 · 인천17·39 · OB·IB·QC")
        // 내 센터가 17센터면 17센터 최고액(40,000원) 기준
        XCTAssertEqual(o.alarmTitle(now: now, preferredCenters: ["인천17"], calendar: calendar),
                       "💰최대 +40,000원 · 내일 주간1 08:00 외 1 · 인천17·39 · OB·IB·QC")
    }

    // MARK: - 내 센터

    func testCenterMatching() {
        XCTAssertTrue(AlarmSettings.centerMatches(preferred: "인천 14센터", code: "인천14"))
        XCTAssertTrue(AlarmSettings.centerMatches(preferred: "인천14", code: "인천14"))
        XCTAssertTrue(AlarmSettings.centerMatches(preferred: "14", code: "인천14"))
        XCTAssertTrue(AlarmSettings.centerMatches(preferred: "인천 17 신선센터", code: "인천17"))
        XCTAssertFalse(AlarmSettings.centerMatches(preferred: "인천1", code: "인천14"))
        XCTAssertFalse(AlarmSettings.centerMatches(preferred: "부천14", code: "인천14"))
    }

    func testOnlyPreferredCenters() {
        let now = date(2026, 10, 11, 10, 40)
        let other = settings { $0.useTimeWindow = false; $0.preferredCenters = ["부천1"]; $0.onlyPreferredCenters = true }
        XCTAssertEqual(AlarmDecider.decide(message: RealMessages.inc14, settings: other, now: now,
                                           lastFired: nil, calendar: calendar).result, .otherCenter)

        // 28·26·36 묶음 문자: 그중 하나라도 내 센터면 울림
        let mine = settings { $0.useTimeWindow = false; $0.preferredCenters = ["인천26"]; $0.onlyPreferredCenters = true }
        XCTAssertEqual(AlarmDecider.decide(message: RealMessages.inc28, settings: mine, now: now,
                                           lastFired: nil, calendar: calendar).result, .fired)
    }

    // MARK: - 날짜·중복

    func testSkipsPastDates() {
        let s = settings { $0.useTimeWindow = false }
        let d = AlarmDecider.decide(message: RealMessages.inc14, settings: s,
                                    now: date(2026, 10, 12, 11, 0), lastFired: nil, calendar: calendar)
        XCTAssertEqual(d.result, .pastDate)
    }

    func testCooldownOnlyForSameOffer() {
        let s = settings { $0.useTimeWindow = false; $0.cooldownMinutes = 10 }
        let now = date(2026, 10, 11, 11, 0)
        let summary14 = parse(RealMessages.inc14, now).alarmTitle(now: now, calendar: calendar)

        // 14센터 문자가 두 번 → 두 번째는 건너뜀
        XCTAssertEqual(AlarmDecider.decide(message: RealMessages.inc14, settings: s, now: now,
                                           lastFired: now.addingTimeInterval(-300), lastFiredSummary: summary14,
                                           calendar: calendar).result, .cooldown)
        // 14센터 직후 28센터 문자 → 내용이 다르므로 울림
        XCTAssertEqual(AlarmDecider.decide(message: RealMessages.inc28, settings: s, now: now,
                                           lastFired: now.addingTimeInterval(-300), lastFiredSummary: summary14,
                                           calendar: calendar).result, .fired)
    }

    // MARK: - 시간대

    func testTimeWindow() {
        let s = settings { $0.useTimeWindow = true; $0.startMinute = 600; $0.endMinute = 900 }
        XCTAssertTrue(TimeWindow.isActive(date(2026, 10, 12, 10, 40), settings: s, calendar: calendar))
        XCTAssertFalse(TimeWindow.isActive(date(2026, 10, 12, 9, 59), settings: s, calendar: calendar))
        XCTAssertFalse(TimeWindow.isActive(date(2026, 10, 12, 15, 0), settings: s, calendar: calendar))
    }

    func testOvernightWindowUsesPreviousWeekday() {
        let s = settings { $0.startMinute = 22 * 60; $0.endMinute = 6 * 60; $0.weekdays = [2] }
        XCTAssertTrue(TimeWindow.isActive(date(2026, 10, 13, 3, 0), settings: s, calendar: calendar))   // 화 03:00
        XCTAssertTrue(TimeWindow.isActive(date(2026, 10, 12, 23, 0), settings: s, calendar: calendar))  // 월 23:00
        XCTAssertFalse(TimeWindow.isActive(date(2026, 10, 14, 3, 0), settings: s, calendar: calendar))  // 수 03:00
    }
}
