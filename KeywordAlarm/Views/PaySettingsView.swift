import SwiftUI

/// 급여 계산 설정: 기본값 · 주휴 기준 · 공제 · 목표 · 근무일수 보너스
struct PaySettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var newRuleName = "15일 근무 보너스"
    @State private var newRuleDays = 15
    @State private var newRuleAmount = 0

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
