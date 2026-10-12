import SwiftUI
import UIKit

/// 단축어 자동화 설정 안내 (iOS 26 기준).
/// 이 앱의 성패는 사용자가 이 설정을 끝까지 해내느냐에 달려 있어서,
/// 입력할 글자는 모두 [복사] 버튼으로 붙여넣을 수 있게 했다.
struct GuideView: View {
    @Environment(\.openURL) private var openURL
    @State private var copied: String?

    /// 개발자가 만든 단축어를 iCloud 링크로 공유하면 여기에 넣는다 (없으면 버튼 숨김)
    /// 단축어 앱 → 단축어 길게 누르기 → 공유 → 'iCloud 링크 복사'
    static let sharedShortcutURL: String? = nil

    static let aiSentence = "인센콜 앱의 '문자 확인 후 알람' 동작 하나만 넣고, 문자 내용에는 단축어 입력을 연결해줘. 다른 동작은 넣지 마."

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("아이폰은 앱이 문자를 직접 읽을 수 없어서, 아이폰 기본 '단축어' 앱이 문자를 감지해 인센콜을 깨웁니다. 처음 한 번만 설정하면 되고, 1~2분이면 끝나요.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        if let url = URL(string: "shortcuts://") { openURL(url) }
                    } label: {
                        Label("단축어 앱 열기", systemImage: "arrow.up.forward.app").font(.headline)
                    }
                }

                // 방법 A
                Section {
                    StepRow(n: 1, title: "자동화 탭 → +",
                            detail: "단축어 앱 맨 아래 '자동화' 탭 → 오른쪽 위 '+' (처음이면 가운데 '새로운 자동화')")
                    StepRow(n: 2, title: "'메시지' 선택",
                            detail: "목록에서 초록 말풍선 '메시지'를 누릅니다. ⚠️ 검색창에 '메시지'를 치는 화면이 아닙니다.")
                    StepRow(n: 3, title: "'메시지에 다음 포함'에 붙여넣기",
                            detail: "발신자는 비워 두고, 아래 키워드를 복사해 붙여넣으세요.") {
                        HStack {
                            CopyChip(text: "인센티브", copied: $copied)
                            CopyChip(text: "특별지급", copied: $copied)
                        }
                    }
                    StepRow(n: 4, title: "'즉시 실행' 선택 → 다음",
                            detail: "⚠️ '실행 전 확인'을 고르면 자는 동안 동작하지 않습니다. '실행 시 알림'은 꺼도 됩니다.")
                    StepRow(n: 5, title: "'새로운 빈 단축어' → 인센콜 검색",
                            detail: "아래 검색창에 붙여넣고 '문자 확인 후 알람'을 누릅니다.") {
                        CopyChip(text: "인센콜", copied: $copied)
                    }
                    StepRow(n: 6, title: "파란 '문자 내용' → '단축어 입력'",
                            detail: "카드가 '[단축어 입력]에서 키워드 확인'으로 바뀌면 오른쪽 위 '완료'.")
                    StepRow(n: 7, title: "한 번 더: 「특별지급」",
                            detail: "1~6을 반복하고 3번에서만 '특별지급'을 붙여넣습니다. 센터마다 쓰는 말이 달라서 두 개가 필요해요.")
                } header: {
                    Text("방법 A · 자동화에서 바로 만들기 (추천)")
                } footer: {
                    Text("자동화 목록에 '메시지에 \"인센티브\" 포함 시', '메시지에 \"특별지급\" 포함 시' 두 줄이 보이면 완성입니다.")
                }

                // 방법 B
                Section {
                    Text("단축어 탭에서 '+'를 누르면 나오는 '단축어 설명' 칸에 아래 문장을 붙여넣으면 동작이 자동으로 만들어집니다.")
                        .font(.subheadline)
                    Text(Self.aiSentence)
                        .font(.callout)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    CopyChip(text: Self.aiSentence, label: "문장 복사", copied: $copied)
                    Text("만든 뒤 이름을 '인센콜 실행'으로 바꾸고, 방법 A의 1~4를 한 다음 5번에서 '새로운 빈 단축어' 대신 목록의 '인센콜 실행'을 고르세요.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("방법 B · AI에게 한 문장으로 만들기")
                } footer: {
                    Text("Apple Intelligence가 켜진 기기에서만 보입니다. AI가 '앱 동작을 찾을 수 없다'고 하면 인센콜 앱을 한 번 열고, 단축어 앱을 완전히 껐다 켠 뒤 다시 시도하거나 방법 A를 쓰세요.")
                }

                if let link = Self.sharedShortcutURL, let url = URL(string: link) {
                    Section {
                        Button { openURL(url) } label: {
                            Label("완성된 단축어 받기", systemImage: "square.and.arrow.down").font(.headline)
                        }
                    } footer: {
                        Text("받은 뒤 방법 A의 1~4를 하고, 5번에서 받은 단축어를 고르면 됩니다.")
                    }
                }

                Section("실제 문자로 확인") {
                    Label("홈 탭 '시간대 제한'을 잠깐 끄기 (감시 시간 밖이면 안 울려요)", systemImage: "1.circle")
                    Label("다른 폰에서 '인센티브 테스트' 문자 보내기 → 무음·화면 꺼짐 상태로 대기", systemImage: "2.circle")
                    Label("기록 탭에 '알람 울림'이 남으면 성공 → 시간대 제한 다시 켜기", systemImage: "3.circle")
                }
                .font(.subheadline)

                Section("잘 안 될 때") {
                    Label("기록이 아예 없음 → 자동화가 '즉시 실행'인지 확인", systemImage: "exclamationmark.circle")
                    Label("'키워드 없음' → 6번 '단축어 입력' 연결이 빠짐", systemImage: "exclamationmark.circle")
                    Label("검색에 인센콜이 안 나옴 → 인센콜 앱을 한 번 열고, 단축어 앱을 완전히 종료 후 다시 열기", systemImage: "exclamationmark.circle")
                    Label("'알람 권한 없음' → 홈 탭에서 권한 허용", systemImage: "exclamationmark.circle")
                    Label("'감시 시간 아님' → 홈 탭 시간대·요일 확인", systemImage: "exclamationmark.circle")
                }
                .font(.subheadline)
            }
            .navigationTitle("설정 안내")
            .overlay(alignment: .bottom) {
                if let copied {
                    Text("복사됨 · \(copied.count > 12 ? String(copied.prefix(12)) + "…" : copied)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.black.opacity(0.8), in: Capsule())
                        .padding(.bottom, 100)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring, value: copied)
        }
    }
}

private struct StepRow<Extra: View>: View {
    let n: Int
    let title: String
    let detail: String
    @ViewBuilder var extra: Extra

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Color.blue, in: Circle())
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
                extra
            }
        }
        .padding(.vertical, 4)
    }
}

extension StepRow where Extra == EmptyView {
    init(n: Int, title: String, detail: String) {
        self.init(n: n, title: title, detail: detail) { EmptyView() }
    }
}

/// 누르면 클립보드에 복사되는 버튼
private struct CopyChip: View {
    let text: String
    var label: String? = nil
    @Binding var copied: String?

    var body: some View {
        Button {
            UIPasteboard.general.string = text
            copied = text
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            Task {
                try? await Task.sleep(for: .seconds(1.6))
                if copied == text { copied = nil }
            }
        } label: {
            Label(label ?? text, systemImage: copied == text ? "checkmark" : "doc.on.doc")
                .font(.subheadline.bold())
        }
        .buttonStyle(.bordered)
        .tint(copied == text ? .green : .blue)
    }
}
