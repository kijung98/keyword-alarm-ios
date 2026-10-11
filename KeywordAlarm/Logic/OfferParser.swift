import Foundation

// MARK: - 데이터

/// 근무 일정 한 건 (예: 2026-10-11 오후조 18:00~04:00)
struct ShiftSchedule: Codable, Equatable, Hashable {
    var year: Int?
    var month: Int?
    var day: Int?
    var shiftName: String?   // 오후조, 심야조, 주간1 ...
    var startTime: String?   // "18:00"
    var endTime: String?     // "04:00"

    func date(calendar: Calendar = .current) -> Date? {
        guard let year, let month, let day else { return nil }
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    /// "10/11(일)"
    func shortDate(calendar: Calendar = .current) -> String {
        let weekdays = ["일", "월", "화", "수", "목", "금", "토"]
        guard let month, let day else { return "날짜 미기재" }
        guard let d = date(calendar: calendar) else { return "\(month)/\(day)" }
        return "\(month)/\(day)(\(weekdays[calendar.component(.weekday, from: d) - 1]))"
    }

    /// "오후조 18:00~04:00"
    var shiftText: String {
        var parts: [String] = []
        if let shiftName { parts.append(shiftName) }
        if let startTime { parts.append(endTime.map { "\(startTime)~\($0)" } ?? startTime) }
        return parts.joined(separator: " ")
    }

    /// 오늘=0, 내일=1, 어제=-1. 날짜를 모르면 nil
    func dayOffset(from now: Date, calendar: Calendar = .current) -> Int? {
        guard let d = date(calendar: calendar) else { return nil }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
                                       to: calendar.startOfDay(for: d)).day
    }

    func relativeLabel(from now: Date, calendar: Calendar = .current) -> String {
        guard let offset = dayOffset(from: now, calendar: calendar) else { return "날짜 확인" }
        switch offset {
        case 0: return "오늘"
        case 1: return "내일"
        case 2: return "모레"
        case -1: return "어제"
        case let n where n > 2: return "\(n)일 후"
        default: return "지난 일정"
        }
    }
}

/// 금액표 한 줄 (예: 인천39 · 주간1(08:00~17:00) · 출고(OB), 입고(IB) · 83,120원 + 45,000원)
struct PayLine: Codable, Equatable, Hashable {
    var center: String?        // 센터 코드 "인천39" (문자에 센터 구분이 없으면 nil)
    var shift: String          // "주간1", "오후조"
    var startTime: String?
    var endTime: String?
    var processes: [String]    // ["출고(OB)", "입고(IB)"]
    var basePay: Int?
    var bonus: Int
    var totalPay: Int?
}

/// 인센티브 문자에서 뽑아낸 핵심 정보.
/// 문자 원문은 저장하지 않고 이 요약만 기기에 저장한다.
struct IncentiveOffer: Codable, Equatable, Identifiable {
    var id = UUID()
    var receivedAt: Date
    var centerCodes: [String]      // ["인천17", "인천39"]
    var schedules: [ShiftSchedule]
    var payLines: [PayLine]
    var processCodes: [String]     // ["OB", "IB", "QC"]
    var bonusText: String?         // "일급 + 30,000" (문자에 적힌 그대로)
    var bonusMin: Int?
    var bonusMax: Int?
    var applyURL: String?
    var isRecipientOnly: Bool
    var notes: [String]            // "심야조는 28센터만 운영 중입니다" 같은 ★ 강조 안내

    // MARK: 표시용

    /// "인천 17·39센터"
    var centerLabel: String? {
        guard !centerCodes.isEmpty else { return nil }
        return Self.groupCenters(centerCodes).map { "\($0.region) \($0.numbers.joined(separator: "·"))센터" }
            .joined(separator: ", ")
    }

    /// "인천17·39"
    var centerShort: String? {
        guard !centerCodes.isEmpty else { return nil }
        return Self.groupCenters(centerCodes).map { $0.region + $0.numbers.joined(separator: "·") }
            .joined(separator: ",")
    }

    /// "+30,000원" 또는 "+30,000~45,000원"
    var bonusDisplay: String? {
        guard let bonusMax else { return bonusText }
        if let bonusMin, bonusMin != bonusMax {
            return "+\(Self.won(bonusMin))~\(Self.won(bonusMax))원"
        }
        return "+\(Self.won(bonusMax))원"
    }

    /// 공정 표시 "OB·IB·QC"
    var processLabel: String? {
        processCodes.isEmpty ? nil : processCodes.joined(separator: "·")
    }

    /// 내 센터 금액표만 (내 센터 정보가 없거나 센터 구분이 없는 문자면 전체)
    func relevantPayLines(preferred: [String]) -> [PayLine] {
        let mine = payLines.filter { line in
            guard let c = line.center else { return false }
            return preferred.contains { AlarmSettings.centerMatches(preferred: $0, code: c) }
        }
        return mine.isEmpty ? payLines : mine
    }

    /// 가장 가까운(오늘 이후 우선) 일정
    func primarySchedule(now: Date, calendar: Calendar = .current) -> ShiftSchedule? {
        let upcoming = schedules.filter { ($0.dayOffset(from: now, calendar: calendar) ?? 0) >= 0 }
        return upcoming.first ?? schedules.first
    }

    /// 모든 일정이 지난 날짜인지 (날짜를 하나도 못 읽었으면 false → 울림)
    func isPast(now: Date, calendar: Calendar = .current) -> Bool {
        let dated = schedules.compactMap { $0.dayOffset(from: now, calendar: calendar) }
        guard !dated.isEmpty else { return false }
        return dated.allSatisfy { $0 < 0 }
    }

    /// 알람 화면 제목 한 줄. 잘려도 중요한 것이 먼저 보이도록 금액 → 날짜 → 센터 → 공정 순.
    /// 예) "💰최대 +45,000원 · 내일 주간1 08:00 외 1 · 인천17·39 · OB·IB·QC"
    func alarmTitle(now: Date, preferredCenters: [String] = [], calendar: Calendar = .current) -> String {
        var parts: [String] = []

        // 금액: 내 센터 금액표가 있으면 그 중 최고액
        let lines = relevantPayLines(preferred: preferredCenters)
        let maxBonus = lines.map(\.bonus).max() ?? bonusMax
        let minBonus = lines.map(\.bonus).min() ?? bonusMin
        if let maxBonus {
            let prefix = (minBonus != nil && minBonus != maxBonus) ? "최대 " : ""
            parts.append("💰\(prefix)+\(Self.won(maxBonus))원")
        } else if let bonusText {
            parts.append("💰" + bonusText)
        }

        if let s = primarySchedule(now: now, calendar: calendar) {
            var when = s.relativeLabel(from: now, calendar: calendar)
            if let name = s.shiftName { when += " " + name }
            if let start = s.startTime { when += " " + start }
            if schedules.count > 1 { when += " 외 \(schedules.count - 1)" }
            parts.append(when)
        }
        if let c = centerShort { parts.append(c) }
        if let p = processLabel { parts.append(p) }
        return parts.isEmpty ? "인센티브 문자가 도착했어요!" : parts.joined(separator: " · ")
    }

    // MARK: 도우미

    static func won(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "ko_KR")
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// ["인천17","인천39","부천1"] → [(인천,[17,39]), (부천,[1])]
    static func groupCenters(_ codes: [String]) -> [(region: String, numbers: [String])] {
        var result: [(region: String, numbers: [String])] = []
        for code in codes {
            let region = String(code.prefix { !$0.isNumber })
            let number = String(code.drop { !$0.isNumber })
            if let i = result.firstIndex(where: { $0.region == region }) {
                result[i].numbers.append(number)
            } else {
                result.append((region, [number]))
            }
        }
        return result
    }
}

// MARK: - 해석기

/// 쿠팡 센터별 인센티브 문자를 읽어 IncentiveOffer로 바꾼다.
/// 지원 형식 (실제 문자 기준):
///  1) 인천14형: "▷ 대상센터 : …", "▷ 적용일자 및 근무조 : 2026-10-11 (일) 오후조 18:00~04:00", "★ 추가지급 혜택 : 일급 + 30,000"
///  2) 인천28형: "#대상일자 : 2026년 10월 11일", "오후 : 허브 - 125,280원 + 30000원(추가 지급) = 155,280원", "18~04시"
///  3) 인천17/39형: "ㅁ인천 17센터" 구역 + "▶주간1(08:00~17:00) : 출고(OB), 입고(IB) : 83,120원+40,000원"
/// 형식이 달라도 찾을 수 있는 항목만 채우고, 못 찾은 항목은 비워 둔다.
enum OfferParser {

    static let shiftWords = "(?:오전|주간|오후|심야|야간|새벽)"
    private static let amount = "([0-9]{1,3}(?:,[0-9]{3})+|[0-9]{4,})"
    private static let notRegion: Set<String> = ["오전", "주간", "오후", "심야", "야간", "새벽", "신선", "대상", "해당", "모집"]
    private static let processMap: [(String, String)] = [("허브", "HUB"), ("입고", "IB"), ("출고", "OB"),
                                                        ("검품", "QC"), ("집품", "PICK"), ("포장", "PACK")]

    static func parse(_ message: String, receivedAt: Date = Date(), calendar: Calendar = .current) -> IncentiveOffer {
        let text = message.replacingOccurrences(of: "\r", with: "")
        let dates = parseDates(text, receivedAt: receivedAt, calendar: calendar)
        let payLines = parsePayLines(text)
        let (bonusMin, bonusMax) = parseBonus(text, payLines: payLines)

        return IncentiveOffer(receivedAt: receivedAt,
                              centerCodes: parseCenters(text),
                              schedules: parseSchedules(text, dates: dates),
                              payLines: payLines,
                              processCodes: parseProcesses(text, payLines: payLines),
                              bonusText: firstGroup(#"추가[ \t]*지급[ \t]*(?:혜택|금액)[ \t]*[:：][ \t]*([^\n]+)"#, in: text),
                              bonusMin: bonusMin,
                              bonusMax: bonusMax,
                              applyURL: parseApplyURL(text),
                              isRecipientOnly: parseRecipientOnly(text),
                              notes: parseNotes(text))
    }

    // MARK: 센터

    static func parseCenters(_ text: String) -> [String] {
        var codes: [String] = []
        let pattern = #"([가-힣]{2,3})[ \t]*(\d{1,3}(?:[ \t]*[,/·][ \t]*\d{1,3})*)[ \t]*(?:신선[ \t]*)?센터"#
        for g in allGroups(pattern, in: text) {
            guard let region = g[0], let numbers = g[1] else { continue }
            // "심야조는 28센터", "오후,심야 28,26,36센터" 같은 문장 속 단어는 지역명이 아님
            if notRegion.contains(region) || "는은이가를조에".contains(region.last!) { continue }
            for n in numbers.split(whereSeparator: { ",/·".contains($0) }) {
                guard let value = Int(n.trimmingCharacters(in: .whitespaces)) else { continue }
                let code = region + String(value)
                if !codes.contains(code) { codes.append(code) }
            }
        }
        return codes
    }

    // MARK: 날짜

    struct DayOnly: Equatable { var year: Int; var month: Int; var day: Int }

    static func parseDates(_ text: String, receivedAt: Date, calendar: Calendar) -> [DayOnly] {
        var result: [DayOnly] = []
        func add(_ d: DayOnly) { if !result.contains(d) { result.append(d) } }

        for g in allGroups(#"(\d{4})[-./](\d{1,2})[-./](\d{1,2})"#, in: text) {
            if let y = g[0].flatMap(Int.init), let m = g[1].flatMap(Int.init), let d = g[2].flatMap(Int.init) {
                add(DayOnly(year: y, month: m, day: d))
            }
        }
        let receivedYear = calendar.component(.year, from: receivedAt)
        let receivedMonth = calendar.component(.month, from: receivedAt)
        for g in allGroups(#"(?:(\d{4})[ \t]*년[ \t]*)?(\d{1,2})[ \t]*월[ \t]*(\d{1,2})[ \t]*일"#, in: text) {
            guard let m = g[1].flatMap(Int.init), let d = g[2].flatMap(Int.init), (1...12).contains(m) else { continue }
            var y = g[0].flatMap(Int.init) ?? receivedYear
            if g[0] == nil && receivedMonth == 12 && m == 1 { y += 1 }   // 12월에 받은 "1월 2일"
            add(DayOnly(year: y, month: m, day: d))
        }
        // 날짜가 전혀 없으면 "오늘/내일" 표현으로 추정
        if result.isEmpty {
            let offset = text.contains("내일") ? 1 : (text.contains("오늘") ? 0 : nil)
            if let offset, let d = calendar.date(byAdding: .day, value: offset, to: receivedAt) {
                let c = calendar.dateComponents([.year, .month, .day], from: d)
                add(DayOnly(year: c.year!, month: c.month!, day: c.day!))
            }
        }
        return result
    }

    // MARK: 근무조 일정

    static func parseSchedules(_ text: String, dates: [DayOnly]) -> [ShiftSchedule] {
        var result: [ShiftSchedule] = []
        func add(_ s: ShiftSchedule) { if !result.contains(s) { result.append(s) } }

        // A) "적용일자 및 근무조 : 2026-10-11 (일) 오후조 18:00~04:00, …"
        if let line = firstGroup(#"적용[ \t]*일자[^\n:：]*[:：][ \t]*([^\n]+)"#, in: text) {
            let p = #"(\d{4})[-./](\d{1,2})[-./](\d{1,2})[ \t]*(?:\([가-힣]\))?[ \t]*([가-힣]{1,4}조)?[ \t]*(\d{1,2}:\d{2})?[ \t]*(?:~[ \t]*(\d{1,2}:\d{2}))?"#
            for g in allGroups(p, in: line) {
                add(ShiftSchedule(year: g[0].flatMap(Int.init), month: g[1].flatMap(Int.init), day: g[2].flatMap(Int.init),
                                  shiftName: g[3], startTime: g[4], endTime: g[5]))
            }
            if !result.isEmpty { return result }
        }

        let d0 = dates.first

        // B) "주간1(08:00~17:00)"
        let b = "(" + shiftWords + #"[ \t]*\d?)[ \t]*(?:조)?[ \t]*\([ \t]*(\d{1,2}:\d{2})[ \t]*~[ \t]*(\d{1,2}:\d{2})[ \t]*\)"#
        for g in allGroups(b, in: text) {
            add(ShiftSchedule(year: d0?.year, month: d0?.month, day: d0?.day,
                              shiftName: g[0]?.replacingOccurrences(of: " ", with: ""), startTime: g[1], endTime: g[2]))
        }
        if !result.isEmpty { return result }

        // C) 급여 줄 "오후 : …" 의 근무조 이름 + "18~04시, 21~06시" 시간 (순서대로 짝지음)
        var names: [String] = []
        for g in allGroups("^[ \\t]*(" + shiftWords + #")[ \t]*\d?[ \t]*(?:조)?[ \t]*[:：]"#, in: text, anchorsMatchLines: true) {
            if let n = g[0], !names.contains(n) { names.append(n) }
        }
        let times: [(String, String)] = allGroups(#"(\d{1,2})[ \t]*~[ \t]*(\d{1,2})[ \t]*시"#, in: text).compactMap { g in
            guard let a = g[0].flatMap(Int.init), let b = g[1].flatMap(Int.init) else { return nil }
            return (String(format: "%02d:00", a), String(format: "%02d:00", b))
        }
        for (i, name) in names.enumerated() {
            let t: (String, String)? = i < times.count ? times[i] : nil
            add(ShiftSchedule(year: d0?.year, month: d0?.month, day: d0?.day,
                              shiftName: name + "조", startTime: t?.0, endTime: t?.1))
        }
        if !result.isEmpty { return result }

        // D) 날짜만
        for d in dates { add(ShiftSchedule(year: d.year, month: d.month, day: d.day)) }
        return result
    }

    // MARK: 금액표

    static func parsePayLines(_ text: String) -> [PayLine] {
        var result: [PayLine] = []
        var currentCenter: String?

        let header = #"^[ \t]*[ㅁ□■▣◆▶]?[ \t]*([가-힣]{2,3})[ \t]*(\d{1,3})[ \t]*(?:신선[ \t]*)?센터[ \t]*$"#
        let shiftLine = "^[ \\t]*▶?[ \\t]*(" + shiftWords + #"[ \t]*\d?)[ \t]*(?:조)?[ \t]*(?:\([ \t]*(\d{1,2}:\d{2})[ \t]*~[ \t]*(\d{1,2}:\d{2})[ \t]*\))?[ \t]*[:：](.*)$"#
        let pay = #"([가-힣A-Za-z() ,]+?)[ \t]*[:：]?[ \t]*-?[ \t]*([0-9][0-9,]*)[ \t]*원[ \t]*\+[ \t]*([0-9][0-9,]*)[ \t]*원(?:[^=\n,]*=[ \t]*([0-9][0-9,]*)[ \t]*원)?"#

        for line in text.components(separatedBy: "\n") {
            if let h = allGroups(header, in: line).first, let region = h[0], let n = h[1].flatMap(Int.init),
               !notRegion.contains(region) {
                currentCenter = region + String(n)
                continue
            }
            guard let s = allGroups(shiftLine, in: line).first, let shiftRaw = s[0], let rest = s[3] else { continue }
            var shift = shiftRaw.replacingOccurrences(of: " ", with: "")
            if !shift.contains(where: \.isNumber) && !shift.hasSuffix("조") { shift += "조" }   // "오후" → "오후조"

            for p in allGroups(pay, in: rest) {
                guard let bonus = p[2].flatMap(number) else { continue }
                let base = p[1].flatMap(number)
                let processes = (p[0] ?? "")
                    .trimmingCharacters(in: CharacterSet(charactersIn: " :-,"))
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                result.append(PayLine(center: currentCenter, shift: shift,
                                      startTime: s[1], endTime: s[2],
                                      processes: processes, basePay: base, bonus: bonus,
                                      totalPay: p[3].flatMap(number) ?? base.map { $0 + bonus }))
            }
        }
        return result
    }

    // MARK: 공정

    static func parseProcesses(_ text: String, payLines: [PayLine]) -> [String] {
        var codes: [String] = []
        func add(_ c: String) { if !codes.contains(c) { codes.append(c) } }

        let sources: [String]
        if let line = firstGroup(#"대상[ \t]*공정[ \t]*[:：][ \t]*([^\n]+)"#, in: text) {
            sources = [line]
        } else {
            sources = payLines.flatMap(\.processes)
        }
        for s in sources {
            let coded = allGroups(#"\(([A-Za-z]+)\)"#, in: s).compactMap { $0[0]?.uppercased() }
            if coded.isEmpty {
                for (ko, code) in processMap where s.contains(ko) { add(code) }
            } else {
                coded.forEach(add)
            }
        }
        if codes.isEmpty {
            for g in allGroups(#"(허브|입고|출고|검품|HUB|IB|OB|QC)[ \t]*(?:\([A-Za-z]+\))?[ \t]*(?:공정|근무)"#, in: text) {
                guard let w = g[0] else { continue }
                add(processMap.first(where: { $0.0 == w })?.1 ?? w.uppercased())
            }
        }
        return codes
    }

    // MARK: 금액

    static func parseBonus(_ text: String, payLines: [PayLine]) -> (Int?, Int?) {
        if !payLines.isEmpty {
            let values = payLines.map(\.bonus)
            return (values.min(), values.max())
        }
        let patterns = [
            #"추가[ \t]*지급[ \t]*(?:혜택|금액)[ \t]*[:：][^\n0-9]*"# + amount,   // 추가지급 혜택 : 일급 + 30,000 / 추가 지급금액 : 30000원
            #"(?:인센티브|특별[ \t]*지급)[ \t]*"# + amount + #"[ \t]*원"#,          // 인센티브 30000원
            #"\+[ \t]*"# + amount                                                  // + 30,000
        ]
        for p in patterns {
            if let v = firstGroup(p, in: text).flatMap(number) { return (v, v) }
        }
        return (nil, nil)
    }

    // MARK: 기타

    static func parseApplyURL(_ text: String) -> String? {
        if let url = firstGroup(#"(?:셀프[ \t]*스케줄링|업무[ \t]*신청|쿠펀치[ \t]*지원)[^\n]*\n(?:[^\n]*\n)?[ \t]*(https?://\S+)"#, in: text) {
            return url
        }
        return allGroups(#"(https?://\S+)"#, in: text).compactMap { $0[0] }
            .first { !$0.lowercased().contains("shuttle") && !$0.contains("forms.office") }
    }

    static func parseRecipientOnly(_ text: String) -> Bool {
        let n = KeywordMatcher.normalize(text)
        return ["수신자에한함", "문자를수신하시고", "문자를받으시는분들만", "수신한번호", "받은휴대전화번호"].contains { n.contains($0) }
    }

    /// ★ 로 강조한 짧은 안내 중 금액·모집 문구가 아닌 것 (예: "심야조는 28센터만 운영 중입니다")
    static func parseNotes(_ text: String) -> [String] {
        var notes: [String] = []
        for g in allGroups(#"★+([^★\n]{4,40})★+"#, in: text) {
            guard let s = g[0]?.trimmingCharacters(in: .whitespaces) else { continue }
            if s.range(of: #"지급|모집|[0-9]{4,}|[0-9]{1,3},[0-9]{3}"#, options: .regularExpression) != nil { continue }
            if !notes.contains(s) { notes.append(s) }
        }
        return notes
    }

    // MARK: 정규식 도우미

    private static func number(_ s: String) -> Int? {
        Int(s.replacingOccurrences(of: ",", with: ""))
    }

    static func firstGroup(_ pattern: String, in text: String) -> String? {
        guard let value = allGroups(pattern, in: text).first?.first ?? nil else { return nil }
        let trimmed = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "★☆"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// 매치마다 캡처 그룹 배열을 돌려준다 (없는 그룹은 nil)
    static func allGroups(_ pattern: String, in text: String, anchorsMatchLines: Bool = false) -> [[String?]] {
        let options: NSRegularExpression.Options = anchorsMatchLines ? [.anchorsMatchLines] : []
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { match in
            (1..<max(1, match.numberOfRanges)).map { i in
                let r = match.range(at: i)
                return r.location == NSNotFound ? nil : ns.substring(with: r)
            }
        }
    }
}

// MARK: - 저장소

/// 받은 인센티브 정보 저장소 (상세 화면용)
enum OfferRepository {
    private static let key = "keywordAlarm.offers.v2"
    private static let openDetailKey = "keywordAlarm.openOfferDetail"
    private static let maxCount = 20

    static func load(defaults: UserDefaults = .standard) -> [IncentiveOffer] {
        guard let data = defaults.data(forKey: key),
              let offers = try? JSONDecoder().decode([IncentiveOffer].self, from: data)
        else { return [] }
        return offers
    }

    static func latest(defaults: UserDefaults = .standard) -> IncentiveOffer? {
        load(defaults: defaults).first
    }

    static func append(_ offer: IncentiveOffer, defaults: UserDefaults = .standard) {
        var offers = load(defaults: defaults)
        offers.insert(offer, at: 0)
        if offers.count > maxCount { offers = Array(offers.prefix(maxCount)) }
        if let data = try? JSONEncoder().encode(offers) { defaults.set(data, forKey: key) }
    }

    /// 알람의 '자세히' 버튼 → 앱이 열리면 상세 화면을 띄우라는 표시
    static func requestOpenDetail(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: openDetailKey)
    }

    static func consumeOpenDetailRequest(defaults: UserDefaults = .standard) -> Bool {
        let flag = defaults.bool(forKey: openDetailKey)
        if flag { defaults.set(false, forKey: openDetailKey) }
        return flag
    }
}
