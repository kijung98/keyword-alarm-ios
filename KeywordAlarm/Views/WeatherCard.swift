import SwiftUI

/// 홈 화면 날씨 카드: 3일/7일 예보 + 우산 알림 + 출근길 비 예보
struct WeatherCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var store = WeatherStore()

    var body: some View {
        @Bindable var model = model
        let region = WeatherRegion.named(model.settings.weatherRegion)
        let shown = Array(store.days.prefix(3))
        let rainy = shown.first { $0.needsUmbrella }

        VStack(alignment: .leading, spacing: 14) {
            // 머리글: 지역 · 3일/7일
            HStack {
                Menu {
                    Picker("지역", selection: $model.settings.weatherRegion) {
                        ForEach(WeatherRegion.all) { Text($0.name).tag($0.name) }
                    }
                } label: {
                    Label(region.name, systemImage: "location.fill")
                        .font(.subheadline.bold())
                }
                Spacer()
                Text("3일 예보").font(.caption).foregroundStyle(.secondary)
            }

            // 우산 알림
            if let rainy {
                HStack(spacing: 10) {
                    Image(systemName: "umbrella.fill")
                        .symbolRenderingMode(.multicolor)
                        .font(.title2)
                    Text("\(dayLabel(rainy.date)) 비 \(rainy.rainChance)% · 우산 챙기세요!")
                        .font(.subheadline.bold())
                    Spacer()
                }
                .padding(12)
                .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            }
            if let c = store.commute, c.chance >= 40 {
                Label("\(dayLabel(c.date)) 출근길(\(c.date.formatted(date: .omitted, time: .shortened)) 무렵) 비 \(c.chance)%",
                      systemImage: "figure.walk")
                    .font(.footnote.bold())
                    .foregroundStyle(.blue)
            }

            // 예보
            if shown.isEmpty {
                VStack(spacing: 8) {
                    HStack {
                        if store.isLoading { ProgressView() }
                        Text(store.errorMessage ?? "날씨를 불러오는 중…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if store.errorMessage != nil {
                        Button {
                            Task { await store.load(region: region, commuteStartMinute: model.paySettings.defaultStartMinute, force: true) }
                        } label: {
                            Label("다시 시도", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        if let detail = store.errorDetail {
                            Text(detail)
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                                .lineLimit(3)
                                .textSelection(.enabled)
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 90)
            } else {
                HStack(spacing: 10) {
                    ForEach(shown) { day in
                        BigDay(day: day, label: dayLabel(day.date), dateText: dateText(day.date))
                    }
                }
            }

            // 애플 날씨 출처 표시 (WeatherKit 사용 조건)
            if let link = store.attributionLink {
                HStack(spacing: 6) {
                    AsyncImage(url: scheme == .dark ? store.attributionLogoDark : store.attributionLogoLight) { img in
                        img.resizable().scaledToFit()
                    } placeholder: { Text(" Weather").font(.caption2) }
                    .frame(height: 12)
                    Link("데이터 출처", destination: link).font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
        }
        .task(id: region.name) {
            await store.load(region: region, commuteStartMinute: model.paySettings.defaultStartMinute)
        }
        .refreshable {
            await store.load(region: region, commuteStartMinute: model.paySettings.defaultStartMinute, force: true)
        }
    }

    /// 오늘 / 내일 / 모레
    private func dayLabel(_ date: Date) -> String {
        let cal = Calendar.current
        let diff = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date)).day ?? 0
        switch diff {
        case 0: return "오늘"
        case 1: return "내일"
        case 2: return "모레"
        default: return dateText(date)
        }
    }

    /// 10/13(화)
    private func dateText(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M/d(E)"
        return f.string(from: date)
    }
}

/// 3일 보기: 큰 카드
private struct BigDay: View {
    let day: DayForecast
    let label: String
    var dateText: String = ""

    var body: some View {
        VStack(spacing: 6) {
            VStack(spacing: 0) {
                Text(label).font(.subheadline.bold())
                Text(dateText).font(.caption2).foregroundStyle(.secondary)
            }
            Image(systemName: day.symbol)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 38))
                .frame(height: 44)
            Text("\(day.high)° / \(day.low)°").font(.subheadline.weight(.semibold))
            HStack(spacing: 2) {
                Image(systemName: "drop.fill").font(.caption2)
                Text("\(day.rainChance)%").font(.caption.bold())
            }
            .foregroundStyle(day.needsUmbrella ? Color.blue : Color.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(day.needsUmbrella ? Color.blue.opacity(0.1) : Color(.tertiarySystemFill),
                    in: RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .topTrailing) {
            if day.needsUmbrella {
                Image(systemName: "umbrella.fill").font(.caption).foregroundStyle(.blue).padding(6)
            }
        }
    }
}
