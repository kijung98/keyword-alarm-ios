import Foundation
import SwiftUI
import AlarmKit
import AppIntents

/// 알람에 함께 실어 보내는 정보 (나중에 잠금화면 위젯을 만들 때 사용 가능)
struct KeywordAlarmMetadata: AlarmMetadata {
    var keyword: String
    var center: String?
    var bonus: String?
    var whenText: String?
    var process: String?
}

typealias KeywordAlarmConfiguration = AlarmManager.AlarmConfiguration<KeywordAlarmMetadata>

/// AlarmKit 래퍼. 무음 모드·집중 모드를 뚫고 시계 앱처럼 울린다.
enum AlarmService {

    enum AlarmError: Error {
        case notAuthorized
    }

    static var isAuthorized: Bool {
        AlarmManager.shared.authorizationState == .authorized
    }

    static var authorizationLabel: String {
        switch AlarmManager.shared.authorizationState {
        case .authorized: "허용됨"
        case .denied: "거부됨 (설정 앱에서 허용 필요)"
        case .notDetermined: "아직 요청 안 함"
        @unknown default: "알 수 없음"
        }
    }

    /// 앱 화면에서 한 번 호출해 권한을 받아 둔다.
    /// (단축어로 백그라운드 실행될 때는 권한 팝업을 띄울 수 없기 때문)
    @discardableResult
    static func requestAuthorization() async -> Bool {
        do {
            let state = try await AlarmManager.shared.requestAuthorization()
            return state == .authorized
        } catch {
            return false
        }
    }

    /// 몇 초 뒤 울리는 1회성 알람을 예약한다.
    /// - title: 잠금화면 알람에 크게 표시되는 한 줄 (예: "💰+30,000원 · 오늘 오후조 18:00 · 인천14 · HUB")
    /// - showDetailButton: true면 알람에 '자세히' 버튼이 생기고, 누르면 앱의 상세 화면이 열린다
    @discardableResult
    static func fire(title: String,
                     metadata: KeywordAlarmMetadata,
                     showDetailButton: Bool,
                     delaySeconds: TimeInterval = 2) async throws -> UUID {
        guard isAuthorized else { throw AlarmError.notAuthorized }

        let id = UUID()

        let stopButton = AlarmButton(text: "끄기",
                                     textColor: .white,
                                     systemImageName: "stop.circle.fill")
        let detailButton = AlarmButton(text: "자세히",
                                       textColor: .white,
                                       systemImageName: "doc.text.magnifyingglass")

        let secondaryButton: AlarmButton? = showDetailButton ? detailButton : nil
        let secondaryBehavior: AlarmPresentation.Alert.SecondaryButtonBehavior? = showDetailButton ? .custom : nil
        let secondaryIntent: (any LiveActivityIntent)? = showDetailButton
            ? OpenOfferDetailIntent(alarmID: id.uuidString)
            : nil

        let alert = AlarmPresentation.Alert(title: LocalizedStringResource(stringLiteral: title),
                                            stopButton: stopButton,
                                            secondaryButton: secondaryButton,
                                            secondaryButtonBehavior: secondaryBehavior)

        let attributes = AlarmAttributes(presentation: AlarmPresentation(alert: alert),
                                         metadata: metadata,
                                         tintColor: Color.blue)

        let fireDate = Date().addingTimeInterval(max(1, delaySeconds))

        let configuration = KeywordAlarmConfiguration(countdownDuration: nil,
                                                      schedule: .fixed(fireDate),
                                                      attributes: attributes,
                                                      stopIntent: nil,
                                                      secondaryIntent: secondaryIntent)

        _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
        return id
    }

    /// 테스트 알람 (실제 문자 대신 예시 정보로 상세 화면까지 확인할 수 있게)
    static func fireTest() async throws {
        // 금액표가 있는 17/39센터 형식으로 테스트 (상세 화면의 금액표까지 확인 가능)
        let sample = OfferParser.parse(SampleMessages.payTable, receivedAt: Date())
        // 예시 문자의 날짜를 오늘로 바꿔서 '오늘'로 보이게
        var offer = sample
        let today = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        offer.schedules = offer.schedules.map {
            var s = $0
            s.year = today.year ?? s.year; s.month = today.month ?? s.month; s.day = today.day ?? s.day
            return s
        }
        OfferRepository.append(offer)
        let preferred = SettingsRepository.load().preferredCenters
        try await fire(title: "[테스트] " + offer.alarmTitle(now: Date(), preferredCenters: preferred),
                       metadata: offer.alarmMetadata(keyword: "테스트", now: Date()),
                       showDetailButton: true,
                       delaySeconds: 5)
    }
}

extension IncentiveOffer {
    func alarmMetadata(keyword: String, now: Date) -> KeywordAlarmMetadata {
        let s = primarySchedule(now: now)
        let when = s.map { "\($0.relativeLabel(from: now)) \($0.shiftText)" }
        return KeywordAlarmMetadata(keyword: keyword,
                                    center: centerLabel,
                                    bonus: bonusDisplay,
                                    whenText: when,
                                    process: processLabel)
    }
}

/// 단축어·앱 화면 공통 처리: 판정 → 기록 → 알람
enum MessageChecker {
    @discardableResult
    static func handle(message: String, now: Date = Date()) async -> AlarmDecider.Decision {
        let settings = SettingsRepository.load()
        let lastFired = HistoryRepository.lastFired()
        var decision = AlarmDecider.decide(message: message,
                                           settings: settings,
                                           now: now,
                                           lastFired: lastFired?.date,
                                           lastFiredSummary: lastFired?.summary)

        let summary = decision.offer?.alarmTitle(now: now, preferredCenters: settings.preferredCenters)

        if decision.result == .fired {
            let offer = decision.offer
            if let offer { OfferRepository.append(offer) }

            // 내 센터 목록이 있는데 다른 센터면 제목 앞에 표시
            var title = summary ?? settings.alarmTitle
            if let offer, settings.matchesPreferred(offer.centerCodes) == false {
                title = "⚠️다른센터 " + title
            }

            do {
                try await AlarmService.fire(title: title,
                                            metadata: offer?.alarmMetadata(keyword: decision.matchedKeyword ?? "", now: now)
                                                ?? KeywordAlarmMetadata(keyword: decision.matchedKeyword ?? ""),
                                            showDetailButton: offer != nil)
            } catch AlarmService.AlarmError.notAuthorized {
                decision.result = .notAuthorized
            } catch {
                decision.result = .failed
            }
        }

        HistoryRepository.append(HistoryEvent(date: now,
                                              result: decision.result,
                                              matchedKeyword: decision.matchedKeyword,
                                              summary: summary))
        return decision
    }
}

/// 테스트·미리보기용 예시 문자 (물류센터 인센티브 문자 형식, 회사명·링크는 제거)
enum SampleMessages {
    static let incentive = """
    (광고) 인천14센터 긴급 모집 안내
    이 문자를 받으신 사원님은 ★일급 외 추가지급 혜택★이 있어 아래와 같이 안내 드립니다.
    ▷ 대상자 : 본 문자 수신자에 한함
    ▷ 대상센터 : 인천 14센터
    ▷ 적용일자 및 근무조 : 2026-10-11 (일) 오후조 18:00~04:00, 2026-10-11 (일) 심야조 20:00~06:00
    ▷ 대상공정 : 허브(HUB)
    ★ 추가지급 혜택 : 일급 + 30,000
    ※ 인센티브 문자를 수신한 번호로 지원해야 지급됩니다.
    """

    static let payTable = """
    인천 17/39 신선센터 채용팀 입니다.
    10월 11일(일) 바로 내일 인천 17/39센터에서 아래와 같이 특별지급을 진행합니다.
    ㅁ인천 17센터
    ▶주간1(08:00~17:00) : 출고(OB), 입고(IB) : 83,120원+40,000원, 검품(QC) : 83,120원+30,000원
    ▶주간3(15:00~00:00) : 출고(OB), 입고(IB) : 93,510원+30,000원
    ㅁ인천 39센터
    ▶주간1(08:00~17:00) : 출고(OB), 입고(IB) : 83,120원+45,000원
    ▶주간3(15:00~00:00) : 출고(OB), 입고(IB) : 93,510원+40,000원
    *해당 문자를 받으시는 분들만 해당됩니다.
    """
}
