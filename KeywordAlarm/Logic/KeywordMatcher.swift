import Foundation

/// 문자 내용에서 키워드를 찾는 순수 로직 (UI·알람과 분리해서 테스트하기 쉽게).
enum KeywordMatcher {

    /// 띄어쓰기·줄바꿈 제거 + 소문자화.
    /// "추가 지급"과 "추가지급"을 같은 것으로 본다.
    static func normalize(_ text: String) -> String {
        text.lowercased().filter { !$0.isWhitespace }
    }

    /// "+ 30,000", "+30,000원", "+50000" 같은 금액 표현 ('원'은 없어도 됨)
    /// 천 단위 쉼표가 있거나 4자리 이상일 때만 인정해서 "+1" 같은 오탐을 줄인다
    static let amountPattern = #"\+\s*([0-9]{1,3}(,[0-9]{3})+|[0-9]{4,})\s*(원)?"#

    /// 일치한 키워드를 돌려준다. 없으면 nil.
    static func firstMatch(in message: String, settings: AlarmSettings) -> String? {
        let normalizedMessage = normalize(message)
        guard !normalizedMessage.isEmpty else { return nil }

        for keyword in settings.keywords {
            let k = normalize(keyword)
            if !k.isEmpty && normalizedMessage.contains(k) {
                return keyword
            }
        }

        if settings.detectAmountPattern,
           let range = message.range(of: amountPattern, options: .regularExpression) {
            return String(message[range])
        }
        return nil
    }
}

/// 시간대·요일 판정
enum TimeWindow {
    static func isActive(_ date: Date, settings: AlarmSettings, calendar: Calendar = .current) -> Bool {
        let comps = calendar.dateComponents([.hour, .minute, .weekday], from: date)
        let minuteOfDay = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        let weekday = comps.weekday ?? 1

        if settings.useTimeWindow {
            let start = settings.startMinute
            let end = settings.endMinute
            let inWindow: Bool
            if start == end {
                inWindow = true                                   // 24시간
            } else if start < end {
                inWindow = minuteOfDay >= start && minuteOfDay < end
            } else {
                inWindow = minuteOfDay >= start || minuteOfDay < end  // 자정 넘김 (예: 22:00~06:00)
            }
            if !inWindow { return false }

            // 자정을 넘기는 시간대에서 새벽 구간은 '전날' 요일로 본다
            if !settings.weekdays.isEmpty {
                var effectiveWeekday = weekday
                if start > end && minuteOfDay < end {
                    effectiveWeekday = weekday == 1 ? 7 : weekday - 1
                }
                return settings.weekdays.contains(effectiveWeekday)
            }
            return true
        }

        if !settings.weekdays.isEmpty {
            return settings.weekdays.contains(weekday)
        }
        return true
    }
}

/// 알람을 울릴지 최종 판정
enum AlarmDecider {
    struct Decision: Equatable {
        var result: CheckResult
        var matchedKeyword: String?
        /// 키워드가 일치했을 때 문자에서 읽어 낸 센터·날짜·공정·금액
        var offer: IncentiveOffer?
    }

    static func decide(message: String,
                       settings: AlarmSettings,
                       now: Date,
                       lastFired: Date?,
                       lastFiredSummary: String? = nil,
                       calendar: Calendar = .current) -> Decision {
        guard settings.isEnabled else { return Decision(result: .disabled) }
        guard TimeWindow.isActive(now, settings: settings, calendar: calendar) else {
            return Decision(result: .outsideTime)
        }
        guard let keyword = KeywordMatcher.firstMatch(in: message, settings: settings) else {
            return Decision(result: .noMatch)
        }

        let offer = OfferParser.parse(message, receivedAt: now)

        // 적용일자가 전부 지난 날짜면 건너뜀 (날짜를 못 읽었으면 울림 쪽으로)
        if settings.skipPastDates && offer.isPast(now: now, calendar: calendar) {
            return Decision(result: .pastDate, matchedKeyword: keyword, offer: offer)
        }
        // 내 센터만 받기: 확실히 다른 센터일 때만 건너뜀 (센터를 못 읽었으면 울림 쪽으로)
        if settings.onlyPreferredCenters && settings.matchesPreferred(offer.centerCodes) == false {
            return Decision(result: .otherCenter, matchedKeyword: keyword, offer: offer)
        }
        // 중복 방지: 같은 내용(센터·날짜·금액)의 문자가 또 오면 건너뜀.
        // 다른 센터·다른 날짜의 인센티브는 중복 방지 시간 안이라도 울린다.
        let summary = offer.alarmTitle(now: now, preferredCenters: settings.preferredCenters, calendar: calendar)
        if let last = lastFired,
           now.timeIntervalSince(last) < Double(settings.cooldownMinutes * 60),
           lastFiredSummary == nil || lastFiredSummary == summary {
            return Decision(result: .cooldown, matchedKeyword: keyword, offer: offer)
        }
        return Decision(result: .fired, matchedKeyword: keyword, offer: offer)
    }
}
