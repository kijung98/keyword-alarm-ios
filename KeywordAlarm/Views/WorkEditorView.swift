import SwiftUI

/// 하루 근무 입력·수정
struct WorkEditorView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var record: WorkRecord
    let isNew: Bool

    init(record: WorkRecord, isNew: Bool) {
        _record = State(initialValue: record)
        self.isNew = isNew
    }

    var body: some View {
        let pay = PayCalculator.dayPay(record)
        let importOptions = makeImportOptions()

        NavigationStack {
            Form {
                // 미리보기
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("이날 예상 수입 (세전)").font(.caption).foregroundStyle(.secondary)
                        Text("\(IncentiveOffer.won(pay.total))원")
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundStyle(.blue)
                            .contentTransition(.numericText())
                        Text(previewLine(pay)).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("날짜") {
                    DatePicker("근무일", selection: dayBinding, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                }

                if !importOptions.isEmpty {
                    Section {
                        ForEach(importOptions) { option in
                            Button { apply(option) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(option.title).font(.subheadline.bold())
                                        Text(option.subtitle).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("+\(IncentiveOffer.won(option.bonus))원").font(.headline).foregroundStyle(.blue)
                                }
                            }
                        }
                    } header: {
                        Text("받은 인센티브 문자에서 불러오기")
                    } footer: {
                        Text("누르면 센터·근무조·시간·인센티브가 자동으로 채워집니다.")
                    }
                }

                Section("근무") {
                    HStack {
                        Text("센터")
                        TextField("예: 인천14", text: $record.center)
                            .multilineTextAlignment(.trailing)
                    }
                    if !model.settings.preferredCenters.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(model.settings.preferredCenters, id: \.self) { c in
                                    Button(c) { record.center = c }
                                        .buttonStyle(.bordered)
                                        .tint(record.center == c ? .blue : .gray)
                                }
                            }
                        }
                    }
                    HStack {
                        Text("근무조")
                        TextField("예: 오후조", text: $record.shift)
                            .multilineTextAlignment(.trailing)
                    }
                    DatePicker("출근", selection: minuteBinding($record.startMinute), displayedComponents: .hourAndMinute)
                    DatePicker("퇴근", selection: minuteBinding($record.endMinute), displayedComponents: .hourAndMinute)
                    Stepper("휴게 \(record.breakMinutes)분", value: $record.breakMinutes, in: 0...180, step: 10)
                    LabeledContent("실근무", value: String(format: "%.1f시간", pay.workedHours))
                }

                Section {
                    HStack {
                        Text("시급")
                        TextField("10320", value: $record.hourlyWage, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                        Text("원")
                    }
                    Toggle("일급을 직접 입력", isOn: overrideEnabled)
                    if record.dailyPayOverride != nil {
                        HStack {
                            Text("일급")
                            TextField("125280", value: overrideValue, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                            Text("원")
                        }
                    }
                    Stepper("추가 연장 \(String(format: "%.1f", record.overtimeHours))시간",
                            value: $record.overtimeHours, in: 0...8, step: 0.5)
                    if record.dailyPayOverride == nil {
                        Toggle("야간 가산 (22~06시 50%)", isOn: $record.applyNightPremium)
                    }
                    HStack {
                        Text("인센티브")
                        TextField("0", value: $record.incentive, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                        Text("원")
                    }
                } header: {
                    Text("급여")
                } footer: {
                    Text("8시간을 넘는 근무는 자동으로 연장(1.5배) 처리됩니다. '추가 연장'에는 그 외 연장만 넣으세요. 문자에 나온 일급(예: 125,280원)을 그대로 쓰려면 '일급을 직접 입력'을 켜세요.")
                }

                Section("메모") {
                    TextField("예: 허브 공정, 셔틀 6시 출발", text: $record.memo, axis: .vertical)
                }

                if !isNew {
                    Section {
                        Button("이 근무 기록 삭제", role: .destructive) {
                            model.deleteWork(record)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "근무 입력" : "근무 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        model.saveWork(record)
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }

    // MARK: - 미리보기 문구

    private func previewLine(_ p: DayPay) -> String {
        var parts = ["기본 \(PayCalculator.shortWon(p.base))"]
        if p.overtime > 0 { parts.append("연장 \(PayCalculator.shortWon(p.overtime))") }
        if p.night > 0 { parts.append("야간 \(PayCalculator.shortWon(p.night))") }
        if p.incentive > 0 { parts.append("인센티브 \(PayCalculator.shortWon(p.incentive))") }
        return parts.joined(separator: " + ")
    }

    // MARK: - 인센티브 불러오기

    private struct ImportOption: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let center: String
        let shift: String
        let start: Int?
        let end: Int?
        let bonus: Int
    }

    private func makeImportOptions() -> [ImportOption] {
        var result: [ImportOption] = []
        for offer in model.offers(on: record.day) {
            let mine = model.settings.preferredCodes(in: offer.centerCodes)
            let center = mine.first ?? offer.centerCodes.first ?? ""
            for s in offer.schedules where s.year == record.day.year && s.month == record.day.month && s.day == record.day.day {
                let shift = s.shiftName ?? ""
                let matching = offer.payLines.filter { line in
                    (line.center == nil || line.center == center) && sameShift(line.shift, shift)
                }
                let bonus = matching.map(\.bonus).max() ?? offer.bonusMax ?? 0
                result.append(ImportOption(title: [center, s.shiftText].filter { !$0.isEmpty }.joined(separator: " · "),
                                           subtitle: offer.processLabel.map { "공정 \($0)" } ?? "인센티브 문자",
                                           center: center, shift: shift,
                                           start: minutes(s.startTime), end: minutes(s.endTime), bonus: bonus))
            }
        }
        return result
    }

    private func apply(_ o: ImportOption) {
        record.center = o.center
        record.shift = o.shift
        if let s = o.start { record.startMinute = s }
        if let e = o.end { record.endMinute = e }
        record.incentive = o.bonus
    }

    private func sameShift(_ a: String, _ b: String) -> Bool {
        let n: (String) -> String = { $0.replacingOccurrences(of: "조", with: "").replacingOccurrences(of: " ", with: "") }
        return n(a) == n(b)
    }

    private func minutes(_ hm: String?) -> Int? {
        guard let hm else { return nil }
        let parts = hm.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return (parts[0] % 24) * 60 + parts[1]
    }

    // MARK: - 바인딩

    private var dayBinding: Binding<Date> {
        Binding(get: { record.day.date() }, set: { record.day = DayKey($0) })
    }

    private var overrideEnabled: Binding<Bool> {
        Binding(get: { record.dailyPayOverride != nil },
                set: { record.dailyPayOverride = $0 ? (record.dailyPayOverride ?? 0) : nil })
    }

    private var overrideValue: Binding<Int> {
        Binding(get: { record.dailyPayOverride ?? 0 }, set: { record.dailyPayOverride = $0 })
    }

    private func minuteBinding(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding<Date>(
            get: {
                Calendar.current.date(bySettingHour: minutes.wrappedValue / 60, minute: minutes.wrappedValue % 60,
                                      second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                minutes.wrappedValue = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            }
        )
    }
}
