import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var model = model

        TabView {
            Tab("홈", systemImage: "alarm") { HomeView() }
            Tab("근무", systemImage: "calendar") { WorkView() }
            Tab("키워드", systemImage: "text.badge.checkmark") { KeywordsView() }
            Tab("설정 안내", systemImage: "list.number") { GuideView() }
            Tab("기록", systemImage: "clock.arrow.circlepath") { HistoryView() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.refresh() }
        }
        // 알람의 '자세히' 버튼으로 앱이 열리면 상세 화면을 전체로 띄움
        .fullScreenCover(item: $model.presentedOffer) { offer in
            NavigationStack {
                OfferDetailView(offer: offer, settings: model.settings) {
                    model.presentedOffer = nil
                }
                .navigationTitle("인센티브 상세")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

// MARK: - 홈

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var testMessage: String?
    @State private var newCenter = ""

    private func addCenter() {
        model.addCenter(newCenter)
        newCenter = ""
    }

    private let weekdayLabels: [(Int, String)] = [(2, "월"), (3, "화"), (4, "수"), (5, "목"), (6, "금"), (7, "토"), (1, "일")]

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            Form {
                // 상태 카드
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: model.settings.isEnabled ? "alarm.waves.left.and.right.fill" : "alarm")
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundStyle(model.settings.isEnabled ? .blue : .secondary)
                            .frame(width: 56)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.settings.isEnabled ? "감시 중" : "꺼짐")
                                .font(.title2.bold())
                            Text(statusSubtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $model.settings.isEnabled)
                            .labelsHidden()
                    }
                    .padding(.vertical, 8)
                }

                // 최근 인센티브
                if let offer = model.latestOffer {
                    Section("최근 인센티브") {
                        NavigationLink {
                            OfferDetailView(offer: offer, settings: model.settings)
                                .navigationTitle("인센티브 상세")
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(offer.bonusDisplay ?? "금액 확인 필요")
                                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.blue)
                                Text(offer.alarmTitle(now: Date()))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                Text(offer.receivedAt, format: .relative(presentation: .named))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // 권한 + 테스트
                Section {
                    LabeledContent("알람 권한", value: model.authorizationLabel)
                    if !model.isAuthorized {
                        Button {
                            Task { await model.requestAuthorization() }
                        } label: {
                            Label("알람 권한 허용", systemImage: "checkmark.shield")
                        }
                    }
                    Button {
                        Task { testMessage = await model.fireTestAlarm() }
                    } label: {
                        Label("테스트 알람 (5초 뒤)", systemImage: "bell.and.waves.left.and.right")
                    }
                    if let testMessage {
                        Text(testMessage).font(.footnote).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("준비")
                } footer: {
                    Text("잠들기 전에 테스트 알람으로 무음 모드에서도 울리는지 꼭 확인하세요.")
                }

                // 시간대
                Section {
                    Toggle("시간대 제한", isOn: $model.settings.useTimeWindow)
                    if model.settings.useTimeWindow {
                        DatePicker("시작", selection: minuteBinding($model.settings.startMinute),
                                   displayedComponents: .hourAndMinute)
                        DatePicker("종료", selection: minuteBinding($model.settings.endMinute),
                                   displayedComponents: .hourAndMinute)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("요일").font(.subheadline)
                        HStack(spacing: 6) {
                            ForEach(weekdayLabels, id: \.0) { item in
                                let day = item.0
                                let on = model.settings.weekdays.contains(day)
                                Button(item.1) {
                                    if on { model.settings.weekdays.remove(day) }
                                    else { model.settings.weekdays.insert(day) }
                                }
                                .buttonStyle(.plain)
                                .frame(width: 36, height: 36)
                                .background(on ? Color.blue : Color(.secondarySystemFill), in: Circle())
                                .foregroundStyle(on ? .white : .primary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("감시 시간")
                } footer: {
                    Text("요일을 하나도 고르지 않으면 매일 감시합니다. 시간대 밖에 온 문자로는 알람이 울리지 않습니다.")
                }

                // 내 센터
                Section {
                    ForEach(model.settings.preferredCenters, id: \.self) { center in
                        Label(center, systemImage: "building.2")
                    }
                    .onDelete { model.settings.preferredCenters.remove(atOffsets: $0) }
                    HStack {
                        TextField("예: 인천14", text: $newCenter)
                            .onSubmit(addCenter)
                        Button("추가", action: addCenter)
                            .disabled(newCenter.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    Toggle("내 센터 문자만 알람", isOn: $model.settings.onlyPreferredCenters)
                        .disabled(model.settings.preferredCenters.isEmpty)
                    Toggle("지난 날짜 문자는 알람 안 함", isOn: $model.settings.skipPastDates)
                } header: {
                    Text("내 센터")
                } footer: {
                    Text("센터를 등록하면 알람과 상세 화면에 '내 센터 / 다른 센터'가 표시됩니다. '내 센터 문자만 알람'을 켜면 다른 센터 인센티브는 울리지 않고 기록에만 남습니다.")
                }

                // 기타
                Section {
                    Stepper("중복 방지 \(model.settings.cooldownMinutes)분",
                            value: $model.settings.cooldownMinutes, in: 0...60, step: 5)
                    TextField("기본 알람 제목", text: $model.settings.alarmTitle)
                } header: {
                    Text("알람")
                } footer: {
                    Text("같은 내용(센터·날짜·금액)의 문자가 이 시간 안에 또 오면 다시 울리지 않습니다. 다른 센터·다른 날짜 인센티브는 바로 울립니다. 기본 제목은 문자에서 정보를 못 읽었을 때 쓰입니다.")
                }
            }
            .navigationTitle("키워드알람")
        }
    }

    private var statusSubtitle: String {
        let s = model.settings
        let kw = s.keywords.isEmpty ? "키워드 없음" : s.keywords.prefix(2).joined(separator: ", ") + (s.keywords.count > 2 ? " 외" : "")
        guard s.useTimeWindow else { return "\(kw) · 하루 종일" }
        return "\(kw) · \(Self.hm(s.startMinute))~\(Self.hm(s.endMinute))"
    }

    static func hm(_ minute: Int) -> String {
        String(format: "%02d:%02d", minute / 60, minute % 60)
    }

    /// 자정 기준 분(Int) ↔ DatePicker용 Date 변환
    private func minuteBinding(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding<Date>(
            get: {
                Calendar.current.date(bySettingHour: minutes.wrappedValue / 60,
                                      minute: minutes.wrappedValue % 60,
                                      second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                minutes.wrappedValue = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            }
        )
    }
}
