import SwiftUI
import Observation

@main
struct KeywordAlarmApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .tint(.blue)
        }
    }
}

/// 화면 상태. 값이 바뀌면 즉시 저장되어 단축어 실행 시에도 반영된다.
@MainActor
@Observable
final class AppModel {
    var settings: AlarmSettings {
        didSet { SettingsRepository.save(settings) }
    }
    var history: [HistoryEvent] = []
    var latestOffer: IncentiveOffer?
    var authorizationLabel: String = ""
    var isAuthorized: Bool = false
    /// 알람의 '자세히' 버튼으로 열렸을 때 상세 화면 표시
    var presentedOffer: IncentiveOffer?

    // MARK: 근무 기록
    var workRecords: [WorkRecord] {
        didSet { WorkRepository.saveRecords(workRecords) }
    }
    var paySettings: PaySettings {
        didSet { WorkRepository.saveSettings(paySettings) }
    }
    /// 주 N일 달성 축하 화면 (주휴수당 금액)
    var celebration: WeekSummary?

    init() {
        settings = SettingsRepository.load()
        workRecords = WorkRepository.loadRecords()
        paySettings = WorkRepository.loadSettings()
        refresh()
    }

    func records(on day: DayKey) -> [WorkRecord] {
        workRecords.filter { $0.day == day }
    }

    /// 근무 저장. 이번 저장으로 그 주가 '주 N일'을 처음 달성하면 축하 화면을 띄운다.
    func saveWork(_ record: WorkRecord) {
        let weekStart = record.day.weekStart()
        let before = PayCalculator.weekSummary(start: weekStart, records: workRecords, settings: paySettings)

        if let i = workRecords.firstIndex(where: { $0.id == record.id }) {
            workRecords[i] = record
        } else {
            workRecords.append(record)
        }
        workRecords.sort { $0.day < $1.day }

        let after = PayCalculator.weekSummary(start: weekStart, records: workRecords, settings: paySettings)
        if before.workDays < paySettings.holidayMinDays && after.workDays >= paySettings.holidayMinDays {
            celebration = after
        }
    }

    func deleteWork(_ record: WorkRecord) {
        workRecords.removeAll { $0.id == record.id }
    }

    /// 받은 인센티브 중 그날 근무에 해당하는 것 (근무 기록에 불러오기용)
    func offers(on day: DayKey) -> [IncentiveOffer] {
        OfferRepository.load().filter { offer in
            offer.schedules.contains { $0.year == day.year && $0.month == day.month && $0.day == day.day }
        }
    }

    func refresh() {
        history = HistoryRepository.load()
        latestOffer = OfferRepository.latest()
        authorizationLabel = AlarmService.authorizationLabel
        isAuthorized = AlarmService.isAuthorized
        if OfferRepository.consumeOpenDetailRequest(), let latestOffer {
            presentedOffer = latestOffer
        }
    }

    func requestAuthorization() async {
        await AlarmService.requestAuthorization()
        refresh()
    }

    func fireTestAlarm() async -> String {
        do {
            try await AlarmService.fireTest()
            refresh()
            return "5초 뒤 알람이 울립니다. 화면을 끄고 기다려 보세요. 알람의 '자세히'를 누르면 상세 화면이 열립니다."
        } catch {
            return "알람 권한이 필요합니다. 먼저 '알람 권한 허용'을 눌러 주세요."
        }
    }

    func addKeyword(_ raw: String) {
        let keyword = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty,
              !settings.keywords.contains(where: { KeywordMatcher.normalize($0) == KeywordMatcher.normalize(keyword) })
        else { return }
        settings.keywords.append(keyword)
    }

    func addCenter(_ raw: String) {
        let center = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !center.isEmpty,
              !settings.preferredCenters.contains(where: {
                  AlarmSettings.normalizeCenter($0) == AlarmSettings.normalizeCenter(center)
              })
        else { return }
        settings.preferredCenters.append(center)
    }

    func clearHistory() {
        HistoryRepository.clear()
        refresh()
    }
}
