import SwiftUI

/// 홈 화면 상태 표시용 레이더.
/// - 감시 중: 파란 빛줄기가 빙글빙글 돌며 탐지
/// - 대기 중(감시 시간 밖): 천천히, 흐리게 돌아감
/// - 꺼짐: 멈춘 회색 레이더
/// 오늘 울린 인센티브 알람은 금색 점(블립)으로 표시된다.
struct RadarView: View {
    enum Mode { case active, standby, off }

    var mode: Mode
    var blips: Int = 0
    var size: CGFloat = 84

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    private var tint: Color {
        switch mode {
        case .active: Color(red: 0.12, green: 0.55, blue: 1.0)
        case .standby: Color(red: 0.45, green: 0.6, blue: 0.85)
        case .off: Color.gray
        }
    }

    /// 한 바퀴 도는 시간(초)
    private var period: Double { mode == .active ? 2.6 : 6.0 }

    var body: some View {
        TimelineView(.animation(paused: mode == .off || reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSince(start)
            let angle = mode == .off ? -45.0 : (t / period).truncatingRemainder(dividingBy: 1) * 360

            ZStack {
                // 바탕 (어두운 화면)
                Circle()
                    .fill(RadialGradient(colors: [Color(red: 0.05, green: 0.16, blue: 0.32),
                                                  Color(red: 0.02, green: 0.06, blue: 0.14)],
                                         center: .center, startRadius: 0, endRadius: size / 2))

                // 동심원 + 십자선
                ForEach(1..<4) { i in
                    Circle()
                        .stroke(tint.opacity(0.35), lineWidth: 1)
                        .frame(width: size * CGFloat(i) / 3, height: size * CGFloat(i) / 3)
                }
                Path { p in
                    p.move(to: CGPoint(x: size / 2, y: 0)); p.addLine(to: CGPoint(x: size / 2, y: size))
                    p.move(to: CGPoint(x: 0, y: size / 2)); p.addLine(to: CGPoint(x: size, y: size / 2))
                }
                .stroke(tint.opacity(0.25), lineWidth: 1)

                // 회전하는 빛줄기 (꼬리가 흐려지는 부채꼴)
                if mode != .off {
                    Circle()
                        .fill(AngularGradient(gradient: Gradient(stops: [
                            .init(color: tint.opacity(0), location: 0),
                            .init(color: tint.opacity(0), location: 0.72),
                            .init(color: tint.opacity(mode == .active ? 0.55 : 0.25), location: 0.99),
                            .init(color: tint.opacity(0), location: 1)
                        ]), center: .center))
                        .rotationEffect(.degrees(angle))
                    // 선두 선
                    Rectangle()
                        .fill(tint.opacity(mode == .active ? 0.95 : 0.5))
                        .frame(width: 1.5, height: size / 2)
                        .offset(y: -size / 4)
                        .rotationEffect(.degrees(angle + 90))   // 막대는 위(북쪽) 기준, 그라데이션은 동쪽 기준
                }

                // 블립: 빛줄기가 지나가면 반짝였다가 서서히 흐려짐
                ForEach(0..<min(blips, 5), id: \.self) { i in
                    let pos = Self.blipPositions[i]
                    let blipAngle = pos.angle
                    let since = ((angle + 90 - blipAngle).truncatingRemainder(dividingBy: 360) + 360)
                        .truncatingRemainder(dividingBy: 360)
                    let glow = mode == .active ? max(0.35, 1 - since / 300) : 0.6
                    Circle()
                        .fill(Color(red: 1, green: 0.8, blue: 0.2))
                        .frame(width: 7, height: 7)
                        .shadow(color: .yellow.opacity(glow), radius: 4)
                        .opacity(glow)
                        .offset(x: cos(blipAngle * .pi / 180 - .pi / 2) * size * pos.radius,
                                y: sin(blipAngle * .pi / 180 - .pi / 2) * size * pos.radius)
                }

                // 가운데 점 (내 위치)
                Circle()
                    .fill(tint)
                    .frame(width: 6, height: 6)
                    .shadow(color: tint, radius: mode == .active ? 4 : 0)

                // 테두리
                Circle().stroke(tint.opacity(0.8), lineWidth: 2)
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        }
        .shadow(color: tint.opacity(mode == .active ? 0.45 : 0), radius: 10)
        .accessibilityLabel(mode == .active ? "감시 중" : (mode == .standby ? "대기 중" : "꺼짐"))
    }

    /// 블립 위치 (고정값이라 화면이 다시 그려져도 점이 튀지 않음)
    private static let blipPositions: [(angle: Double, radius: CGFloat)] = [
        (60, 0.28), (150, 0.36), (230, 0.22), (310, 0.33), (20, 0.18)
    ]
}

#Preview {
    HStack(spacing: 20) {
        RadarView(mode: .active, blips: 2)
        RadarView(mode: .standby)
        RadarView(mode: .off)
    }
    .padding()
}
