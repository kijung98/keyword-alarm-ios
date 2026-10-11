import SwiftUI

/// 단축어 자동화 설정 안내. 이 앱의 성패는 사용자가 이 설정을 끝까지 해내느냐에 달려 있다.
struct GuideView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    private struct Step: Identifiable {
        let id: Int
        let title: String
        let detail: String
    }

    private var steps: [Step] {
        let mainKeyword = model.settings.keywords.first ?? "인센티브"
        return [
            Step(id: 1, title: "알람 권한 허용",
                 detail: "홈 탭에서 '알람 권한 허용'을 누르고 테스트 알람이 울리는지 확인합니다."),
            Step(id: 2, title: "단축어 앱 → 자동화 탭",
                 detail: "아래 버튼으로 단축어 앱을 열고, 하단 '자동화' 탭에서 오른쪽 위 + 를 누릅니다."),
            Step(id: 3, title: "'메시지' 선택",
                 detail: "목록에서 '메시지'를 고르고 '메시지에 다음 포함'에 「인센티브」를 입력합니다. 같은 방법으로 「특별지급」 자동화를 하나 더 만드세요. 센터마다 쓰는 말이 달라서 두 개가 모두 필요합니다."),
            Step(id: 4, title: "'즉시 실행' 선택",
                 detail: "'실행 전 확인'이 아니라 반드시 '즉시 실행'을 고르세요. 그래야 자는 동안에도 동작합니다. '실행 시 알림'은 꺼도 됩니다."),
            Step(id: 5, title: "동작 추가: 키워드알람",
                 detail: "'새로운 빈 단축어' → 동작 검색에서 '키워드알람'을 찾아 '문자 확인 후 알람'을 추가합니다."),
            Step(id: 6, title: "'문자 내용'에 단축어 입력 연결",
                 detail: "'문자 내용' 칸을 눌러 '단축어 입력'(받은 메시지)을 선택하고 완료를 누릅니다."),
            Step(id: 7, title: "실제 문자로 최종 확인",
                 detail: "다른 폰에서 「\(mainKeyword)」가 들어간 문자를 보내 보세요. 기록 탭에 '알람 울림'이 남으면 성공입니다.")
        ]
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("아이폰은 앱이 문자를 직접 읽을 수 없어서, 아이폰 기본 '단축어' 앱이 문자를 감지해 키워드알람을 깨우는 방식으로 동작합니다. 처음 한 번만 설정하면 됩니다.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("설정 순서") {
                    ForEach(steps) { step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(step.id)")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(Color.blue, in: Circle())
                            VStack(alignment: .leading, spacing: 4) {
                                Text(step.title).font(.headline)
                                Text(step.detail).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    Button {
                        if let url = URL(string: "shortcuts://") { openURL(url) }
                    } label: {
                        Label("단축어 앱 열기", systemImage: "arrow.up.forward.app")
                            .font(.headline)
                    }
                }

                Section("잘 안 될 때") {
                    Label("기록 탭에 아무것도 없다면 → 자동화가 실행되지 않은 것입니다. 3~6단계를 다시 확인하세요.", systemImage: "1.circle")
                    Label("'알람 권한 없음'이 찍힌다면 → 홈 탭에서 권한을 허용하세요.", systemImage: "2.circle")
                    Label("'감시 시간 아님'이 찍힌다면 → 홈 탭의 시간대·요일을 확인하세요.", systemImage: "3.circle")
                }
                .font(.subheadline)
            }
            .navigationTitle("설정 안내")
        }
    }
}
