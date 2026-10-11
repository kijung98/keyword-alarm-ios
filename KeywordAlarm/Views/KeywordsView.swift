import SwiftUI

struct KeywordsView: View {
    @Environment(AppModel.self) private var model
    @State private var newKeyword = ""
    @State private var sample = "이 문자를 받으신 사원님은 ★일급 외 추가지급 혜택★이 있어 아래와 같이 안내 드립니다. ★ 추가지급 혜택 : 일급 + 30,000"
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("예: 추가지급", text: $newKeyword)
                            .focused($focused)
                            .submitLabel(.done)
                            .onSubmit(add)
                        Button("추가", action: add)
                            .disabled(newKeyword.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    ForEach(model.settings.keywords, id: \.self) { keyword in
                        Label(keyword, systemImage: "tag")
                    }
                    .onDelete { model.settings.keywords.remove(atOffsets: $0) }
                } header: {
                    Text("키워드")
                } footer: {
                    Text("키워드 중 하나라도 문자에 들어 있으면 알람이 울립니다. 띄어쓰기는 무시합니다 (\"추가 지급\" = \"추가지급\"). 왼쪽으로 밀면 삭제됩니다.")
                }

                Section {
                    Toggle("금액 패턴 감지 (+ 30,000 등)", isOn: $model.settings.detectAmountPattern)
                } footer: {
                    Text("문구가 바뀌어도 '+ 30,000' 같은 금액이 있으면 울립니다. 다른 광고 문자에도 반응할 수 있으니 보조용으로만 켜세요.")
                }

                Section {
                    TextField("받을 문자 예시를 붙여 넣어 보세요", text: $sample, axis: .vertical)
                        .lineLimit(2...5)
                    let match = KeywordMatcher.firstMatch(in: sample, settings: model.settings)
                    Label(match.map { "알람이 울립니다 · '\($0)' 일치" } ?? "울리지 않습니다 · 일치하는 키워드 없음",
                          systemImage: match == nil ? "bell.slash" : "bell.fill")
                        .foregroundStyle(match == nil ? Color.secondary : Color.blue)
                    if match != nil {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("알람 제목 미리보기").font(.caption).foregroundStyle(.secondary)
                            Text(OfferParser.parse(sample).alarmTitle(now: Date()))
                                .font(.headline)
                        }
                    }
                } header: {
                    Text("문구 테스트")
                } footer: {
                    Text("실제 알람은 울리지 않고 판정만 보여 줍니다. 시간대 설정은 여기서 반영되지 않습니다.")
                }
            }
            .navigationTitle("키워드")
            .toolbar { EditButton() }
        }
    }

    private func add() {
        model.addKeyword(newKeyword)
        newKeyword = ""
        focused = false
    }
}
