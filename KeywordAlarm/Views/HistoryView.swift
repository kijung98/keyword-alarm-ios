import SwiftUI

struct HistoryView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            Group {
                if model.history.isEmpty {
                    ContentUnavailableView("아직 기록이 없어요",
                                           systemImage: "clock",
                                           description: Text("단축어 자동화가 실행되면 여기에 결과가 남습니다. 문자 전문은 저장하지 않습니다."))
                } else {
                    List(model.history) { event in
                        HStack(spacing: 12) {
                            Image(systemName: event.result.symbol)
                                .foregroundStyle(event.result == .fired ? .blue : .secondary)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.result.label).font(.headline)
                                if let summary = event.summary {
                                    Text(summary).font(.subheadline).foregroundStyle(.blue)
                                } else if let keyword = event.matchedKeyword {
                                    Text("키워드: \(keyword)").font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text(event.date, format: .dateTime.month().day().hour().minute())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("기록")
            .toolbar {
                if !model.history.isEmpty {
                    Button("지우기", role: .destructive) { model.clearHistory() }
                }
            }
            .refreshable { model.refresh() }
        }
    }
}
