import SwiftUI

/// 급여 계산 설정: 기본값 · 주휴 기준 · 공제 · 목표 · 근무일수 보너스
struct PaySettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var newRuleName = "15일 근무 보너스"
    @State private var newRuleDays = 15
    @State private var newRuleAmount = 0
    @State private var newCenter = ""
    @State private var newGroupName = ""

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("기본 시급")
                        TextField("10320", value: $model.paySettings.defaultHourlyWage, format: .number)
                            .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                        Text("원")
                    }
                    DatePicker("기본 출근", selection: minuteBinding($model.paySettings.defaultStartMinute),
                               displayedComponents: .hourAndMinute)
                    DatePicker("기본 퇴근", selection: minuteBinding($model.paySettings.defaultEndMinute),
                               displayedComponents: .hourAndMinute)
                    Stepper("기본 휴게 \(model.paySettings.defaultBreakMinutes)분",
                            value: $model.paySettings.defaultBreakMinutes, in: 0...180, step: 10)
                    HStack {
                        Text("기본 센터")
                        TextField("예: 인천14", text: $model.paySettings.defaultCenter)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("새 근무 기본값")
                } footer: {
                    Text("2026년 최저임금은 시간당 10,320원입니다.")
                }

                Section {
                    ForEach(model.paySettings.centerPresets, id: \.self) { c in
                        Label(c, systemImage: "building.2")
                    }
                    .onDelete { model.paySettings.centerPresets.remove(atOffsets: $0) }
                    HStack {
                        TextField("예: 인천14", text: $newCenter)
                        Button("추가") {
                            let c = newCenter.trimmingCharacters(in: .whitespaces)
                            if !c.isEmpty && !model.paySettings.centerPresets.contains(c) {
                                model.paySettings.centerPresets.append(c)
                            }
                            newCenter = ""
                        }
                        .disabled(newCenter.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("자주 가는 센터")
                } footer: {
                    Text("근무 입력에서 버튼으로 바로 선택됩니다. 홈 탭의 '내 센터'도 함께 표시돼요. 왼쪽으로 밀면 삭제.")
                }

                ForEach(model.paySettings.shiftGroups) { group in
                    ShiftGroupSection(group: group)
                }

                Section {
                    HStack {
                        TextField("새 근무조 이름 (예: 새벽조)", text: $newGroupName)
                        Button("추가") {
                            let n = newGroupName.trimmingCharacters(in: .whitespaces)
                            if !n.isEmpty && !model.paySettings.shiftGroups.contains(where: { $0.name == n }) {
                                model.paySettings.shiftGroups.append(ShiftGroup(name: n))
                            }
                            newGroupName = ""
                        }
                        .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    Button("근무조·시간대 기본값으로 되돌리기") {
                        model.paySettings.shiftGroups = ShiftGroup.defaults
                        model.paySettings.shiftTimes = ShiftPreset.defaults
                    }
                    .font(.footnote)
                } header: {
                    Text("근무조 추가")
                } footer: {
                    Text("근무 입력에서 근무조를 고르면 그 근무조의 시간대 버튼이 나옵니다. 휴게시간 기본값은 근로기준법 기준 추정치(4시간 이상 30분, 8시간 이상 1시간)이니 실제와 다르면 고치세요.")
                }

                Section {
                    Picker("주휴 기준", selection: $model.paySettings.holidayRule) {
                        ForEach(HolidayPayRule.allCases) { Text($0.label).tag($0) }
                    }
                    Stepper("주 \(model.paySettings.holidayMinDays)일 근무 시 (축하 기준)",
                            value: $model.paySettings.holidayMinDays, in: 1...7)
                } header: {
                    Text("주휴수당 (일~토 기준)")
                } footer: {
                    Text("근로기준법상 주휴수당은 주 15시간 이상 근무가 기준입니다. 일부 사업장은 '주 5일 근무 시 지급'으로 안내하기도 합니다. 실제로 받는 기준에 맞춰 선택하세요. 금액 = (주 근무시간 ÷ 40, 최대 1) × 8 × 시급")
                }

                Section {
                    Toggle("공휴일 근무 1.5배 적용", isOn: $model.paySettings.applyHolidayPremium)
                } header: {
                    Text("휴일근로 수당")
                } footer: {
                    Text("공휴일·대체공휴일·근로자의 날 근무는 8시간까지 1.5배, 8시간 초과분은 2배로 계산합니다 (5인 이상 사업장, 근로기준법 제56조). 자정을 넘기는 근무는 공휴일 날짜에 걸친 시간만 계산합니다.")
                }

                Section {
                    Toggle("공제 추정해서 실수령 표시", isOn: $model.paySettings.applyDeductions)
                    Stepper("4대보험 기준: 월 \(model.paySettings.insuranceMinDays)일",
                            value: $model.paySettings.insuranceMinDays, in: 1...31)
                    Stepper("또는 월 \(Int(model.paySettings.insuranceMinHours))시간",
                            value: $model.paySettings.insuranceMinHours, in: 10...200, step: 10)
                } header: {
                    Text("공제 (추정)")
                } footer: {
                    Text("일용직은 고용보험 0.9%가 기본 공제됩니다. 월 8일(또는 60시간) 이상이면 국민연금 4.75%·건강보험 3.595%·장기요양(건강보험료의 13.14%)이 추가될 수 있습니다. 소득세는 (일급 − 15만원) × 2.7%, 1,000원 미만이면 0원입니다. 정확한 가입 여부는 4대사회보험 정보연계센터에서 확인하세요.")
                }

                Section {
                    Button {
                        let wage = Double(model.paySettings.defaultHourlyWage)
                        let start = DayKey(Date()).weekStart()
                        let amount = Int((8 * wage).rounded())
                        let preview = WeekSummary(start: start, end: start.adding(days: 6),
                                                  workDays: model.paySettings.holidayMinDays, regularHours: 40,
                                                  averageWage: wage, qualifiesCompany: true, qualifiesLegal: true,
                                                  companyHolidayPay: amount, legalHolidayPay: amount,
                                                  appliedHolidayPay: amount, daysToCompanyRule: 0)
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { model.celebration = preview }
                    } label: {
                        Label("주휴수당 축하 화면 미리보기", systemImage: "party.popper")
                    }
                } footer: {
                    Text("한 주(일~토)에 \(model.paySettings.holidayMinDays)번째 근무를 저장하는 순간 이 화면이 자동으로 나옵니다.")
                }

                Section("이번 달 목표") {
                    HStack {
                        Text("목표 금액")
                        TextField("0", value: $model.paySettings.monthlyGoal, format: .number)
                            .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                        Text("원")
                    }
                }

                Section {
                    ForEach(model.paySettings.bonusRules) { rule in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(rule.name).font(.subheadline.bold())
                                Text("월 \(rule.minDays)일 이상 근무 시").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("+\(IncentiveOffer.won(rule.amount))원")
                        }
                    }
                    .onDelete { model.paySettings.bonusRules.remove(atOffsets: $0) }

                    VStack(alignment: .leading, spacing: 8) {
                        TextField("이름", text: $newRuleName)
                        Stepper("월 \(newRuleDays)일 이상", value: $newRuleDays, in: 1...31)
                        HStack {
                            Text("금액")
                            TextField("0", value: $newRuleAmount, format: .number)
                                .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                            Text("원")
                        }
                        Button("규칙 추가") {
                            model.paySettings.bonusRules.append(
                                MonthlyBonusRule(name: newRuleName.isEmpty ? "근무일수 보너스" : newRuleName,
                                                 minDays: newRuleDays, amount: newRuleAmount))
                            newRuleAmount = 0
                        }
                        .disabled(newRuleAmount <= 0)
                    }
                } header: {
                    Text("근무일수 보너스")
                } footer: {
                    Text("예: '월 15일 이상 근무 시 +금액'처럼 센터 공지에 나온 조건을 직접 넣으세요. 센터마다 다르고 바뀔 수 있어 기본값은 비워 두었습니다. 왼쪽으로 밀면 삭제됩니다.")
                }
            }
            .navigationTitle("급여 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
        }
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

/// 근무조 하나의 시간대 목록 (추가·수정·삭제)
private struct ShiftGroupSection: View {
    @Environment(AppModel.self) private var model
    let group: ShiftGroup

    var body: some View {
        @Bindable var model = model
        let indices = model.paySettings.shiftTimes.indices.filter { model.paySettings.shiftTimes[$0].group == group.name }

        Section {
            ForEach(indices, id: \.self) { i in
                HStack {
                    DatePicker("", selection: minuteBinding($model.paySettings.shiftTimes[i].startMinute),
                               displayedComponents: .hourAndMinute).labelsHidden()
                    Text("~")
                    DatePicker("", selection: minuteBinding($model.paySettings.shiftTimes[i].endMinute),
                               displayedComponents: .hourAndMinute).labelsHidden()
                    Spacer()
                    Menu {
                        ForEach([0, 30, 60, 90], id: \.self) { m in
                            Button("휴게 \(m)분") { model.paySettings.shiftTimes[i].breakMinutes = m }
                        }
                    } label: {
                        Text("휴게 \(model.paySettings.shiftTimes[i].breakMinutes)분").font(.caption)
                    }
                }
            }
            .onDelete { offsets in
                let ids = offsets.map { model.paySettings.shiftTimes[indices[$0]].id }
                model.paySettings.shiftTimes.removeAll { ids.contains($0.id) }
            }
            Button {
                let last = indices.last.map { model.paySettings.shiftTimes[$0] }
                model.paySettings.shiftTimes.append(ShiftPreset(group: group.name,
                                                                start: last?.startMinute ?? 9 * 60,
                                                                end: last?.endMinute ?? 18 * 60))
            } label: {
                Label("시간대 추가", systemImage: "plus.circle")
            }
        } header: {
            HStack {
                Text(group.label)
                Spacer()
                if !ShiftGroup.defaults.contains(group) {
                    Button("근무조 삭제", role: .destructive) {
                        model.paySettings.shiftGroups.removeAll { $0 == group }
                        model.paySettings.shiftTimes.removeAll { $0.group == group.name }
                    }
                    .font(.caption)
                }
            }
        }
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
