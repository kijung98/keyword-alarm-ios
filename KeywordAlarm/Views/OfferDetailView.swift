import SwiftUI

/// 알람에서 '자세히'를 누르면 뜨는 화면.
/// 자다 깬 상태에서도 한눈에 보이도록 금액·날짜·센터·공정을 아주 크게 보여 준다.
struct OfferDetailView: View {
    let offer: IncentiveOffer
    var settings: AlarmSettings
    var onClose: (() -> Void)? = nil

    @Environment(\.openURL) private var openURL

    var body: some View {
        let now = Date()
        let myLines = offer.relevantPayLines(preferred: settings.preferredCenters)
        let filteredToMine = !settings.preferredCenters.isEmpty && myLines.count < offer.payLines.count
        let topBonus = myLines.map(\.bonus).max() ?? offer.bonusMax

        ScrollView {
            VStack(spacing: 16) {

                // 1. 금액 (가장 크게)
                VStack(spacing: 6) {
                    Text(filteredToMine ? "내 센터 최대 추가지급" : (offer.bonusMin != offer.bonusMax ? "최대 추가지급" : "추가지급"))
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.85))
                    Text(topBonus.map { "+\(IncentiveOffer.won($0))원" } ?? offer.bonusDisplay ?? "금액 확인 필요")
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .foregroundStyle(.white)
                    if offer.bonusMin != offer.bonusMax, let range = offer.bonusDisplay {
                        Text("전체 \(range)").font(.subheadline).foregroundStyle(.white.opacity(0.85))
                    } else if let text = offer.bonusText {
                        Text(text).font(.subheadline).foregroundStyle(.white.opacity(0.85))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 26)
                .background(LinearGradient(colors: [Color(red: 0.08, green: 0.40, blue: 0.96),
                                                    Color(red: 0.04, green: 0.25, blue: 0.75)],
                                           startPoint: .top, endPoint: .bottom),
                            in: RoundedRectangle(cornerRadius: 24))

                // 2. 날짜 (오늘/내일)
                InfoCard(label: "적용일자 · 근무조") {
                    if offer.schedules.isEmpty {
                        Text("날짜를 읽지 못했어요").font(.title3.bold())
                    } else {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(offer.schedules, id: \.self) { s in
                                let offset = s.dayOffset(from: now)
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    Text(s.relativeLabel(from: now))
                                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                                        .foregroundStyle(dayColor(offset))
                                        .frame(minWidth: 84, alignment: .leading)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(s.shiftText.isEmpty ? "근무조 미기재" : s.shiftText)
                                            .font(.title3.bold())
                                        Text(s.shortDate()).font(.subheadline).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                // 3. 센터 · 공정
                HStack(alignment: .top, spacing: 12) {
                    InfoCard(label: "대상센터") {
                        if offer.centerCodes.isEmpty {
                            Text("확인 필요").font(.title2.bold())
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(offer.centerCodes, id: \.self) { code in
                                    let mine = settings.matchesPreferred([code])
                                    HStack(spacing: 6) {
                                        Text(code).font(.title3.bold())
                                        if let mine {
                                            Image(systemName: mine ? "checkmark.seal.fill" : "minus.circle")
                                                .foregroundStyle(mine ? Color.green : Color.secondary)
                                        }
                                    }
                                }
                                if let mine = settings.matchesPreferred(offer.centerCodes) {
                                    Text(mine ? "내 센터 포함" : "⚠️ 내 센터 아님")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(mine ? Color.green : Color.orange)
                                }
                            }
                        }
                    }
                    InfoCard(label: "대상공정") {
                        Text(offer.processLabel ?? "확인 필요")
                            .font(.title2.bold())
                            .minimumScaleFactor(0.6)
                    }
                }

                // 4. 금액표 (센터·근무조·공정별로 금액이 다른 문자)
                if !offer.payLines.isEmpty {
                    InfoCard(label: "근무조별 금액 (세전)") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(offer.payLines.enumerated()), id: \.offset) { _, line in
                                PayLineRow(line: line,
                                           isTop: line.bonus == topBonus,
                                           isMine: line.center.map { settings.matchesPreferred([$0]) ?? false } ?? false)
                            }
                        }
                    }
                }

                // 5. 주의사항
                if !offer.notes.isEmpty || offer.isRecipientOnly {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(offer.notes, id: \.self) { note in
                            Label(note, systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline.bold())
                                .foregroundStyle(.orange)
                        }
                        if offer.isRecipientOnly {
                            Label("문자 받은 번호로 지원해야 지급", systemImage: "person.fill.checkmark")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // 6. 바로 지원
                if let link = offer.applyURL, let url = URL(string: link) {
                    Button {
                        openURL(url)
                    } label: {
                        Label("지원 페이지 열기", systemImage: "arrow.up.right.square.fill")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                Text("수신 \(offer.receivedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .toolbar {
            if let onClose {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기", action: onClose)
                }
            }
        }
    }

    private func dayColor(_ offset: Int?) -> Color {
        guard let offset else { return .secondary }
        if offset < 0 { return .secondary }
        return offset == 0 ? .red : .blue
    }
}

private struct PayLineRow: View {
    let line: PayLine
    let isTop: Bool
    let isMine: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if let center = line.center {
                    Text(center)
                        .font(.caption.bold())
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(isMine ? Color.green.opacity(0.2) : Color(.tertiarySystemFill), in: Capsule())
                }
                Text(line.shift + (line.startTime.map { " \($0)~\(line.endTime ?? "")" } ?? ""))
                    .font(.subheadline.bold())
                Spacer()
                Text("+\(IncentiveOffer.won(line.bonus))원")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(isTop ? Color.red : Color.blue)
            }
            HStack {
                Text(line.processes.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if let total = line.totalPay {
                    Text("총 \(IncentiveOffer.won(total))원")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct InfoCard<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }
}

#Preview("17/39센터 금액표") {
    NavigationStack {
        OfferDetailView(offer: OfferParser.parse(SampleMessages.payTable), settings: AlarmSettings())
    }
}

#Preview("14센터") {
    NavigationStack {
        OfferDetailView(offer: OfferParser.parse(SampleMessages.incentive), settings: AlarmSettings())
    }
}
