import AppIntents
import Foundation

/// 단축어 자동화에서 호출하는 핵심 동작.
/// 자동화: [메시지 수신 시] → [인센콜: 문자 확인 후 알람 (문자 내용 = 단축어 입력)]
struct CheckMessageIntent: AppIntent {
    static var title: LocalizedStringResource = "문자 확인 후 알람"
    static var description = IntentDescription("받은 문자에 등록한 키워드가 있으면 무음 모드에서도 큰 알람을 울립니다.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "문자 내용")
    var messageText: String

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$messageText)에서 키워드 확인")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> & ProvidesDialog {
        let decision = await MessageChecker.handle(message: messageText)
        let fired = decision.result == .fired
        return .result(value: fired, dialog: IntentDialog(stringLiteral: decision.result.label))
    }
}

/// 설정 확인용: 바로 알람을 울려 본다.
struct TestAlarmIntent: AppIntent {
    static var title: LocalizedStringResource = "키워드 알람 테스트"
    static var description = IntentDescription("5초 뒤 테스트 알람을 울립니다.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            try await AlarmService.fireTest()
            return .result(dialog: "5초 뒤 알람이 울립니다.")
        } catch {
            return .result(dialog: "알람 권한이 없습니다. 인센콜 앱을 열어 권한을 허용해 주세요.")
        }
    }
}

/// 알람의 '자세히' 버튼. 앱을 열고 최근 인센티브 상세 화면을 띄운다.
struct OpenOfferDetailIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "인센티브 자세히 보기"
    static var openAppWhenRun: Bool = true
    static var isDiscoverable: Bool = false

    @Parameter(title: "알람 ID")
    var alarmID: String

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    init() {
        self.alarmID = ""
    }

    func perform() async throws -> some IntentResult {
        OfferRepository.requestOpenDetail()
        return .result()
    }
}

/// 단축어 앱에 자동으로 노출 (사용자가 '앱' 목록에서 바로 찾을 수 있게)
struct KeywordAlarmShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: CheckMessageIntent(),
                    phrases: ["\(.applicationName)로 문자 확인"],
                    shortTitle: "문자 확인 후 알람",
                    systemImageName: "alarm.waves.left.and.right")
        AppShortcut(intent: TestAlarmIntent(),
                    phrases: ["\(.applicationName) 테스트"],
                    shortTitle: "알람 테스트",
                    systemImageName: "bell.badge")
    }
}
