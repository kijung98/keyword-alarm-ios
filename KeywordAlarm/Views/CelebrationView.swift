import SwiftUI

/// 주 N일 달성 축하 화면: 색종이가 터지고 주휴수당 금액이 크게 나온다.
struct CelebrationView: View {
    let week: WeekSummary
    let settings: PaySettings
    let onClose: () -> Void

    @State private var appeared = false
    @State private var start = Date()

    var body: some View {
        let amount = week.companyHolidayPay > 0 ? week.companyHolidayPay : week.legalHolidayPay

        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            ConfettiView(start: start)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 14) {
                Text("🎉").font(.system(size: 72))
                    .scaleEffect(appeared ? 1 : 0.2)
                Text("이번 주 \(week.workDays)일 달성!")
                    .font(.title.bold())
                Text("주휴수당")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("+\(IncentiveOffer.won(amount))원")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(.blue)
                    .scaleEffect(appeared ? 1 : 0.6)
                Text("\(week.start.shortLabel)~\(week.end.shortLabel) · \(String(format: "%.0f", week.regularHours))시간")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("수고 많으셨어요! 💪")
                    .font(.headline)
                    .padding(.top, 4)
                Button("확인", action: onClose)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 6)
            }
            .padding(28)
            .frame(maxWidth: 340)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
            .scaleEffect(appeared ? 1 : 0.85)
            .opacity(appeared ? 1 : 0)
        }
        .onTapGesture(perform: onClose)
        .sensoryFeedback(.success, trigger: appeared)
        .onAppear {
            start = Date()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appeared = true }
        }
        .task {
            try? await Task.sleep(for: .seconds(6))
            onClose()
        }
    }
}

/// 색종이 효과 (Canvas로 그림)
private struct ConfettiView: View {
    let start: Date

    private struct Piece {
        let x: Double        // 0~1 시작 가로 위치
        let vx: Double       // 가로 속도
        let vy: Double       // 처음 위로 튀는 속도
        let size: Double
        let spin: Double
        let color: Color
        let delay: Double
    }

    @State private var pieces: [Piece] = ConfettiView.makePieces()

    private static func makePieces() -> [Piece] {
        let colors: [Color] = [.blue, .yellow, .pink, .green, .orange, .purple, .mint, .red]
        return (0..<140).map { i in
            Piece(x: Double.random(in: 0.1...0.9),
                  vx: Double.random(in: -0.35...0.35),
                  vy: Double.random(in: 0.9...1.6),
                  size: Double.random(in: 6...12),
                  spin: Double.random(in: -8...8),
                  color: colors[i % colors.count],
                  delay: Double.random(in: 0...0.4))
        }
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(start)
                for p in pieces {
                    let tt = t - p.delay
                    guard tt > 0 else { continue }
                    // 아래 가운데에서 위로 터졌다가 떨어짐
                    let gravity = 1.3
                    let x = (p.x + p.vx * tt) * size.width
                    let y = size.height * (0.75 - p.vy * tt + 0.5 * gravity * tt * tt)
                    guard y < size.height + 20 else { continue }
                    var piece = context
                    piece.translateBy(x: x, y: y)
                    piece.rotate(by: .radians(p.spin * tt))
                    piece.fill(Path(CGRect(x: -p.size / 2, y: -p.size / 4, width: p.size, height: p.size / 2)),
                               with: .color(p.color))
                }
            }
        }
    }
}

#Preview {
    CelebrationView(week: WeekSummary(start: DayKey(year: 2026, month: 10, day: 4),
                                      end: DayKey(year: 2026, month: 10, day: 10),
                                      workDays: 5, regularHours: 40, averageWage: 10_320,
                                      qualifiesCompany: true, qualifiesLegal: true,
                                      companyHolidayPay: 82_560, legalHolidayPay: 82_560,
                                      appliedHolidayPay: 82_560, daysToCompanyRule: 0),
                    settings: PaySettings()) {}
}
