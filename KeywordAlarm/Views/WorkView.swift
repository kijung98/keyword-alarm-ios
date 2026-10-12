import SwiftUI
import Charts

/// 근무 기록 탭: 달력 · 이번 주 주휴 진행 · 월간 수입 요약
struct WorkView: View {
    @Environment(AppModel.self) private var model
    @State private var month = DayKey(year: DayKey(Date()).year, month: DayKey(Date()).month, day: 1)
    @State private var editing: WorkRecord?
    @State private var showSettings = false

    var body: some View {
        let summary = PayCalculator.monthSummary(year: month.year, month: month.month,
                                                 records: model.workRecords, settings: model.paySettings)
        let previous = previousMonthSummary()

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    MonthSwitcher(month: $month)

                    MonthTotalCard(summary: summary, previous: previous, goal: model.paySettings.monthlyGoal)

                    if isCurrentMonth {
                        ThisWeekCard(week: PayCalculator.weekSummary(start: DayKey(Date()).weekStart(),
                                                                     records: model.workRecords,
                                                                     settings: model.paySettings),
                                     settings: model.paySettings)
                    }

                    CalendarCard(month: month, records: model.workRecords,
                                 holidayPremium: model.paySettings.applyHolidayPremium) { day in
                        editing = model.records(on: day).first ?? model.paySettings.newRecord(on: day)
                    }

                    if model.paySettings.applyHolidayPremium {
                        UpcomingHolidayCard(settings: model.paySettings, records: model.workRecords) { day in
                            editing = model.records(on: day).first ?? model.paySettings.newRecord(on: day)
                        }
                    }

                    YearChartCard(year: month.year, records: model.workRecords,
                                  settings: model.paySettings, month: $month)

                    MilestonesCard(summary: summary, settings: model.paySettings)

                    if !summary.weeks.isEmpty {
                        WeeksCard(weeks: summary.weeks, settings: model.paySettings)
                    }

                    BreakdownCard(summary: summary, applyDeductions: model.paySettings.applyDeductions)

                    Text("금액은 입력값으로 계산한 추정치입니다. 실제 지급액은 급여명세서를 기준으로 확인하세요.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("근무 기록")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let today = DayKey(Date())
                        editing = model.records(on: today).first ?? model.paySettings.newRecord(on: today)
                    } label: {
                        Label("오늘 근무", systemImage: "plus.circle.fill")
                    }
                }
            }
            .sheet(item: $editing) { record in
                WorkEditorView(record: record, isNew: !model.workRecords.contains { $0.id == record.id })
            }
            .sheet(isPresented: $showSettings) {
                PaySettingsView()
            }
        }
        .overlay {
            if let week = model.celebration {
                CelebrationView(week: week, settings: model.paySettings) {
                    model.celebration = nil
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: model.celebration?.id)
    }

    private var isCurrentMonth: Bool {
        let t = DayKey(Date())
        return t.year == month.year && t.month == month.month
    }

    private func previousMonthSummary() -> MonthSummary {
        let prev = month.adding(days: -1)
        return PayCalculator.monthSummary(year: prev.year, month: prev.month,
                                          records: model.workRecords, settings: model.paySettings)
    }
}

// MARK: - 월 이동

private struct MonthSwitcher: View {
    @Binding var month: DayKey

    var body: some View {
        HStack {
            Button { shift(-1) } label: { Image(systemName: "chevron.left").font(.title3.bold()) }
            Spacer()
            Text("\(String(month.year))년 \(month.month)월").font(.title2.bold())
            Spacer()
            Button { shift(1) } label: { Image(systemName: "chevron.right").font(.title3.bold()) }
        }
        .padding(.horizontal, 8)
    }

    private func shift(_ delta: Int) {
        var y = month.year, m = month.month + delta
        if m == 0 { m = 12; y -= 1 }
        if m == 13 { m = 1; y += 1 }
        month = DayKey(year: y, month: m, day: 1)
    }
}

// MARK: - 이번 달 수입

private struct MonthTotalCard: View {
    let summary: MonthSummary
    let previous: MonthSummary
    let goal: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("이번 달 번 돈 (세전)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
            Text("\(IncentiveOffer.won(summary.gross))원")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .contentTransition(.numericText())

            HStack(spacing: 18) {
                Stat(label: "근무", value: "\(summary.workDays)일")
                Stat(label: "시간", value: String(format: "%.1f시간", summary.totalHours))
                Stat(label: "예상 실수령", value: PayCalculator.shortWon(summary.net) + "원")
            }

            if previous.gross > 0 {
                let diff = summary.gross - previous.gross
                Text("지난달 대비 \(diff >= 0 ? "▲" : "▼") \(IncentiveOffer.won(abs(diff)))원")
                    .font(.footnote.bold())
                    .foregroundStyle(.white.opacity(0.9))
            }

            if goal > 0 {
                let ratio = min(1, Double(summary.gross) / Double(goal))
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: ratio).tint(.white)
                    Text("목표 \(IncentiveOffer.won(goal))원 중 \(Int(ratio * 100))%"
                         + (summary.gross < goal ? " · \(IncentiveOffer.won(goal - summary.gross))원 남음" : " 달성! 🎉"))
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(LinearGradient(colors: [Color(red: 0.08, green: 0.40, blue: 0.96),
                                            Color(red: 0.04, green: 0.25, blue: 0.75)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 24))
    }

    private struct Stat: View {
        let label: String
        let value: String
        var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundStyle(.white.opacity(0.75))
                Text(value).font(.headline).foregroundStyle(.white)
            }
        }
    }
}

// MARK: - 이번 주 주휴 진행

private struct ThisWeekCard: View {
    let week: WeekSummary
    let settings: PaySettings

    var body: some View {
        let target = settings.holidayMinDays
        WorkCard(title: "이번 주 (\(week.start.shortLabel)~\(week.end.shortLabel))") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    ForEach(0..<max(target, week.workDays), id: \.self) { i in
                        Circle()
                            .fill(i < week.workDays ? Color.blue : Color(.tertiarySystemFill))
                            .frame(width: 26, height: 26)
                            .overlay {
                                if i < week.workDays {
                                    Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                                }
                            }
                    }
                    Spacer()
                    Text("\(week.workDays)/\(target)일").font(.headline)
                }

                if week.qualifiesCompany {
                    Label("주휴수당 +\(IncentiveOffer.won(week.companyHolidayPay))원 달성!", systemImage: "party.popper.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                } else {
                    let expected = Int((40.0 / 40 * 8 * week.averageWage).rounded())
                    Text("\(week.daysToCompanyRule)일 더 일하면 주휴수당 약 +\(IncentiveOffer.won(expected))원")
                        .font(.subheadline.bold())
                        .foregroundStyle(.blue)
                    if settings.holidayRule == .companyDays && week.qualifiesLegal {
                        Label("법 기준(주 15시간 이상)으로는 이미 약 \(IncentiveOffer.won(week.legalHolidayPay))원 대상일 수 있어요",
                              systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - 달력

private struct CalendarCard: View {
    let month: DayKey
    let records: [WorkRecord]
    var holidayPremium: Bool = true
    let onTap: (DayKey) -> Void

    private let weekdays = ["일", "월", "화", "수", "목", "금", "토"]

    /// 달력 칸을 주(行) 단위로: 앞뒤 빈칸은 nil
    private var rows: [[DayKey?]] {
        let first = DayKey(year: month.year, month: month.month, day: 1)
        let leading = first.weekday() - 1
        let count = Calendar.current.range(of: .day, in: .month, for: first.date())?.count ?? 30
        var cells: [DayKey?] = Array(repeating: nil, count: leading)
        cells += (1...count).map { DayKey(year: month.year, month: month.month, day: $0) }
        while cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }

    var body: some View {
        let today = DayKey(Date())
        let byDay = Dictionary(grouping: records.filter { $0.day.year == month.year && $0.day.month == month.month },
                               by: \.day)

        WorkCard(title: "달력 · 날짜를 눌러 근무 입력") {
            VStack(spacing: 6) {
                // 요일 머리글
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { i in
                        Text(weekdays[i])
                            .font(.caption.bold())
                            .foregroundStyle(Self.weekdayColor(i + 1, holiday: false))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.bottom, 2)
                Divider()

                // 날짜
                ForEach(Array(rows.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { col in
                            if let day = week[col] {
                                DayCell(day: day,
                                        records: byDay[day] ?? [],
                                        isToday: day == today,
                                        holidayPremium: holidayPremium,
                                        onTap: onTap)
                            } else {
                                Color.clear.frame(maxWidth: .infinity, minHeight: 56)
                            }
                        }
                    }
                }

                // 범례
                HStack(spacing: 14) {
                    Legend(color: .blue, text: "근무")
                    Legend(color: .red, text: "일요일·공휴일")
                    Legend(color: Color(red: 0.15, green: 0.4, blue: 0.95), text: "토요일", textOnly: true)
                    if holidayPremium {
                        HStack(spacing: 4) {
                            PremiumBadge()
                            Text("1.5배").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
    }

    /// 1=일(빨강), 7=토(파랑), 공휴일(빨강)
    static func weekdayColor(_ weekday: Int, holiday: Bool) -> Color {
        if holiday || weekday == 1 { return .red }
        if weekday == 7 { return Color(red: 0.15, green: 0.4, blue: 0.95) }
        return .primary
    }

    private struct DayCell: View {
        let day: DayKey
        let records: [WorkRecord]
        let isToday: Bool
        var holidayPremium: Bool = true
        let onTap: (DayKey) -> Void

        var body: some View {
            let holiday = Holidays.name(of: day)
            let worked = !records.isEmpty
            let total = records.map { PayCalculator.dayPay($0, holidayPremium: holidayPremium).total }.reduce(0, +)

            Button { onTap(day) } label: {
                VStack(spacing: 1) {
                    Text("\(day.day)")
                        .font(.subheadline.weight(isToday ? .heavy : .semibold))
                        .foregroundStyle(worked ? Color.white
                                         : CalendarCard.weekdayColor(day.weekday(), holiday: holiday != nil))
                    if worked {
                        Text(PayCalculator.shortWon(total))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    } else if let holiday {
                        Text(holiday)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.red)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(worked ? Color.blue : (holiday != nil ? Color.red.opacity(0.07) : Color.clear),
                            in: RoundedRectangle(cornerRadius: 10))
                .overlay {
                    if isToday {
                        RoundedRectangle(cornerRadius: 10).stroke(worked ? Color.orange : Color.blue, lineWidth: 2)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if holiday != nil && holidayPremium {
                        PremiumBadge().offset(x: 3, y: -4)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private struct Legend: View {
        let color: Color
        let text: String
        var textOnly = false
        var body: some View {
            HStack(spacing: 4) {
                if !textOnly { RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 10, height: 10) }
                Text(text).font(.caption2).foregroundStyle(textOnly ? color : .secondary)
            }
        }
    }
}



// MARK: - 공휴일 1.5배 배지

struct PremiumBadge: View {
    var body: some View {
        Text("×1.5")
            .font(.system(size: 8, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 3).padding(.vertical, 1)
            .background(LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom),
                        in: Capsule())
    }
}

// MARK: - 다가오는 1.5배 날

private struct UpcomingHolidayCard: View {
    let settings: PaySettings
    let records: [WorkRecord]
    let onTap: (DayKey) -> Void

    var body: some View {
        let today = DayKey(Date())
        let upcoming: [(day: DayKey, name: String)] = (0...45).compactMap { offset in
            let d = today.adding(days: offset)
            return Holidays.name(of: d).map { (d, $0) }
        }
        let extra = Int((8 * Double(settings.defaultHourlyWage) * PayRates.holidayPremium).rounded())

        if !upcoming.isEmpty {
            WorkCard(title: "다가오는 1.5배 날 (공휴일)") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(upcoming.prefix(4), id: \.day) { item in
                        let offset = Calendar.current.dateComponents([.day], from: today.date(), to: item.day.date()).day ?? 0
                        let booked = records.contains { $0.day == item.day }
                        Button { onTap(item.day) } label: {
                            HStack(spacing: 12) {
                                Text(offset == 0 ? "오늘" : "D-\(offset)")
                                    .font(.subheadline.weight(.heavy))
                                    .foregroundStyle(.white)
                                    .frame(width: 58, height: 34)
                                    .background(offset <= 3 ? Color.red : Color.orange, in: RoundedRectangle(cornerRadius: 10))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(item.day.month)/\(item.day.day) \(item.name)").font(.subheadline.bold())
                                    Text(booked ? "근무 등록됨 ✅" : "8시간 근무 시 약 +\(IncentiveOffer.won(extra))원 더")
                                        .font(.caption)
                                        .foregroundStyle(booked ? Color.green : Color.secondary)
                                }
                                Spacer()
                                PremiumBadge().scaleEffect(1.6)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    Label("공휴일은 1.5배라 지원자가 몰려요. 근무 신청은 며칠 전에 미리 해 두세요!",
                          systemImage: "exclamationmark.bubble.fill")
                        .font(.footnote.bold())
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

// MARK: - 1년 월별 수입 그래프

private struct YearChartCard: View {
    let year: Int
    let records: [WorkRecord]
    let settings: PaySettings
    @Binding var month: DayKey

    @State private var grown = false
    @State private var selected: String?

    private struct Point: Identifiable {
        let month: Int
        let gross: Int
        let days: Int
        var id: Int { month }
        var label: String { "\(month)월" }
    }

    var body: some View {
        let points = (1...12).map { m -> Point in
            let s = PayCalculator.monthSummary(year: year, month: m, records: records, settings: settings)
            return Point(month: m, gross: s.gross, days: s.workDays)
        }
        let total = points.map(\.gross).reduce(0, +)
        let worked = points.filter { $0.gross > 0 }
        let best = worked.max { $0.gross < $1.gross }
        let average = worked.isEmpty ? 0 : total / worked.count
        let totalDays = points.map(\.days).reduce(0, +)

        WorkCard(title: "\(String(year))년 월별 수입") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 0) {
                    stat("올해 합계", PayCalculator.shortWon(total) + "원")
                    stat("최고의 달", best.map { "\($0.month)월" } ?? "-")
                    stat("월평균", PayCalculator.shortWon(average) + "원")
                    stat("총 근무", "\(totalDays)일")
                }

                if total == 0 {
                    Text("근무를 기록하면 달마다 막대가 올라가요 📈")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    Chart(points) { p in
                        BarMark(x: .value("월", p.label),
                                y: .value("수입", grown ? p.gross : 0))
                            .cornerRadius(6)
                            .foregroundStyle(barStyle(p, best: best))
                            .annotation(position: .top, spacing: 2) {
                                if p.id == best?.id && grown {
                                    Text("👑 " + PayCalculator.shortWon(p.gross))
                                        .font(.caption2.bold())
                                        .foregroundStyle(Color.orange)
                                }
                            }
                    }
                    .chartXSelection(value: $selected)
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let v = value.as(Int.self) { Text(PayCalculator.shortWon(v)) }
                            }
                        }
                    }
                    .frame(height: 210)
                    .onChange(of: selected) { _, newValue in
                        if let newValue, let m = Int(newValue.replacingOccurrences(of: "월", with: "")) {
                            withAnimation { month = DayKey(year: year, month: m, day: 1) }
                        }
                    }

                    Text("막대를 누르면 그 달로 이동해요 · 금색 막대가 가장 많이 번 달")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            grown = false
            withAnimation(.spring(response: 0.9, dampingFraction: 0.75).delay(0.15)) { grown = true }
        }
        .onChange(of: year) { _, _ in
            grown = false
            withAnimation(.spring(response: 0.9, dampingFraction: 0.75)) { grown = true }
        }
    }

    private func barStyle(_ p: Point, best: Point?) -> AnyShapeStyle {
        if p.id == best?.id && p.gross > 0 {
            return AnyShapeStyle(LinearGradient(colors: [Color(red: 1, green: 0.85, blue: 0.35), .orange],
                                                startPoint: .top, endPoint: .bottom))
        }
        if p.month == month.month { return AnyShapeStyle(Color.blue) }
        return AnyShapeStyle(Color.blue.opacity(0.4))
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.bold()).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 4대보험 · 보너스 진행

private struct MilestonesCard: View {
    let summary: MonthSummary
    let settings: PaySettings

    var body: some View {
        WorkCard(title: "이번 달 체크포인트") {
            VStack(alignment: .leading, spacing: 12) {
                // 4대보험
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "cross.case.fill")
                        .foregroundStyle(summary.insuranceLikely ? .orange : .blue)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        if summary.insuranceLikely {
                            Text("월 \(settings.insuranceMinDays)일 이상 근무 → 국민연금·건강보험 가입 대상일 수 있어요")
                                .font(.subheadline.bold())
                            Text("공제가 생기지만, 연금 가입기간과 직장 건강보험 혜택이 쌓입니다 (추정)")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text("\(summary.daysToInsurance)일 더 근무하면 국민연금·건강보험 가입 대상 (월 \(settings.insuranceMinDays)일)")
                                .font(.subheadline.bold())
                            Text("그 전까지는 고용보험(0.9%)만 공제되는 것으로 계산합니다 (추정)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                // 근무일수 보너스
                ForEach(summary.bonuses) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: item.achieved ? "star.fill" : "star")
                            .foregroundStyle(.yellow)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.achieved
                                 ? "\(item.rule.name) 달성! +\(IncentiveOffer.won(item.rule.amount))원"
                                 : "\(item.rule.name)까지 \(item.rule.minDays - summary.workDays)일 남음 (+\(IncentiveOffer.won(item.rule.amount))원)")
                                .font(.subheadline.bold())
                            ProgressView(value: min(1, Double(summary.workDays) / Double(max(1, item.rule.minDays))))
                        }
                    }
                }
                if summary.bonuses.isEmpty {
                    Text("⚙️ 설정에서 '월 15일 근무 시 +금액' 같은 보너스 규칙을 추가할 수 있어요")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - 주별 내역

private struct WeeksCard: View {
    let weeks: [WeekSummary]
    let settings: PaySettings

    var body: some View {
        WorkCard(title: "주별 주휴수당 (일~토)") {
            VStack(spacing: 10) {
                ForEach(weeks) { w in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(w.start.shortLabel)~\(w.end.shortLabel)").font(.subheadline.bold())
                            Text("\(w.workDays)일 · \(String(format: "%.0f", w.regularHours))시간")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if w.appliedHolidayPay > 0 {
                            Text("+\(IncentiveOffer.won(w.appliedHolidayPay))원").font(.headline).foregroundStyle(.green)
                        } else if settings.holidayRule == .companyDays && w.legalHolidayPay > 0 {
                            Text("법 기준 \(PayCalculator.shortWon(w.legalHolidayPay))")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text("-").foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 상세 내역

private struct BreakdownCard: View {
    let summary: MonthSummary
    let applyDeductions: Bool

    var body: some View {
        WorkCard(title: "이번 달 상세 (세전 → 실수령)") {
            VStack(spacing: 8) {
                Row("기본급", summary.base)
                Row("연장수당", summary.overtime)
                Row("야간수당", summary.night)
                Row("인센티브", summary.incentive)
                Row("휴일수당 (공휴일 1.5배)", summary.holidayWork)
                Row("주휴수당", summary.holidayPay)
                Row("근무일수 보너스", summary.bonusTotal)
                Divider()
                Row("세전 합계", summary.gross, bold: true)
                if applyDeductions {
                    Row("고용보험 (0.9%)", -summary.deductions.employment)
                    if summary.insuranceLikely {
                        Row("국민연금 (4.75%)", -summary.deductions.pension)
                        Row("건강보험 (3.595%)", -summary.deductions.health)
                        Row("장기요양", -summary.deductions.longTermCare)
                    }
                    Row("소득세 (일용)", -summary.deductions.incomeTax)
                    Row("지방소득세", -summary.deductions.localTax)
                    Divider()
                    Row("예상 실수령", summary.net, bold: true)
                }
            }
        }
    }

    private struct Row: View {
        let label: String
        let value: Int
        var bold = false
        init(_ label: String, _ value: Int, bold: Bool = false) {
            self.label = label; self.value = value; self.bold = bold
        }
        var body: some View {
            HStack {
                Text(label).font(bold ? .headline : .subheadline)
                Spacer()
                Text("\(value < 0 ? "−" : "")\(IncentiveOffer.won(abs(value)))원")
                    .font(bold ? .headline : .subheadline)
                    .foregroundStyle(value < 0 ? Color.red : (bold ? Color.primary : Color.secondary))
            }
        }
    }
}

/// 공통 카드
struct WorkCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }
}
