# 인센콜 앱스토어 제출 가이드 (v1.0)

## A. App Store Connect 입력값 (복사해서 붙여넣기)

| 항목 | 입력값 |
|---|---|
| 이름 (30자) | 인센콜 |
| 부제 (30자) | 인센티브 문자 알람·근무·급여 기록 |
| 카테고리 | 1차: 유틸리티 / 2차: 생산성 |
| 가격 | 무료 (유료는 사업자등록번호 필요 — 아래 D 참고) |
| 연령 등급 | 4+ (설문 모두 '없음') |
| 저작권 | 2026 최기정 |
| 개인정보처리방침 URL | https://<깃허브아이디>.github.io/keyword-alarm-ios/privacy.html |
| 지원 URL | https://<깃허브아이디>.github.io/keyword-alarm-ios/ |
| 번들 ID | com.gijeong.keywordalarm (그대로 — 사용자에게는 안 보임) |

### 홍보 문구 (170자)
```
야간 근무 후 자는 동안 놓친 인센티브 문자, 이제 그만! 등록한 문구가 담긴 문자가 오면 무음 모드에서도 크게 울리고, 근무·주휴수당·월 수입까지 한 번에 관리하세요.
```

### 키워드 (100자, 쉼표 구분·띄어쓰기 없이)
```
인센티브,특별지급,문자알람,근무기록,주휴수당,급여계산,일당,일용직,물류센터,야간근무,알바,공휴일수당,무음알람
```

### 설명
```
자는 동안 인센티브 문자를 놓치지 마세요.

인센콜은 미리 등록한 문구(예: 인센티브, 특별지급)가 담긴 문자가 오면 무음·집중 모드에서도 시계 알람처럼 크게 울려 주는 앱입니다. 야간 근무 후 낮에 자는 분을 위해 만들었습니다.

■ 인센티브 문자 알람
• 등록한 문구가 담긴 문자가 오면 무음 모드에서도 크게 울림
• 금액·날짜(오늘/내일)·센터·근무조·공정을 자동으로 읽어 알람 한 줄에 표시
• '자세히'를 누르면 큰 글씨 상세 화면과 근무조별 금액표
• 내 센터 등록, 감시 시간대·요일 설정, 같은 문자 중복 알람 방지
• 홈 화면 레이더로 감시 중/대기 중을 한눈에

■ 근무 기록과 급여 계산
• 달력에 근무를 기록하면 그날 수입이 바로 계산
• 근무조(주간·오후·심야·단축)와 시간대를 버튼으로 선택
• 연장 1.5배, 야간 가산, 공휴일 근무 1.5배 자동 계산
• 주휴수당 진행 표시, 주 5일 달성 시 축하 애니메이션
• 이번 달 번 돈, 근무일수, 예상 실수령, 1년 월별 그래프
• 다가오는 공휴일(1.5배 날) D-day 안내

■ 3일 날씨
• 오늘·내일·모레 날씨와 우산 알림, 출근길 비 예보

■ 개인정보 걱정 없음
• 회원가입·서버 없음, 기록은 모두 아이폰 안에만 저장
• 문자 원문은 저장하지 않음

※ 아이폰 기본 '단축어' 앱의 메시지 자동화와 함께 동작합니다. 앱 안 '설정 안내' 탭에서 단계별로 안내합니다.
※ 문자 메시지만 지원합니다 (카카오톡 등 다른 앱 알림은 iOS 정책상 지원하지 않습니다).
※ 급여·공제 금액은 입력값 기준 추정치이며, 실제 지급액은 급여명세서를 기준으로 하세요.
※ iOS 26 이상에서 사용할 수 있습니다.
```

### 앱 심사 정보 → 메모 (심사관용, 영어)
```
This app does not read SMS directly. It provides an App Intent ("문자 확인 후 알람" / Check message and alarm) that the user connects to a Shortcuts personal automation (Message trigger, "Run Immediately"). The received message text is checked on-device for user-defined keywords and an alarm is scheduled with AlarmKit.

How to review without SMS:
1. Home tab > "알람 권한 허용" (Allow alarms) > "테스트 알람 (5초 뒤)" (Test alarm in 5 sec). Lock the device: the alarm rings even in silent mode. Tap "자세히" (Details) for the detail screen.
2. Keywords tab (키워드) > "문구 테스트": paste any text containing "인센티브" to see the match result and alarm title preview.
3. Work tab (근무): tap a date to add a work record; pay is calculated locally. Gear icon > "주휴수당 축하 화면 미리보기" shows the celebration animation.
4. Weather on the Home tab uses WeatherKit with a user-selected region (no GPS, no location permission). Apple Weather attribution is shown in the card.

No login, no server, no analytics, no data collection. All data stays on device.
```

### 앱 개인정보 보호 (App Privacy)
- "데이터를 수집합니까?" → **아니요, 이 앱에서 데이터를 수집하지 않습니다**

---

## B. 업로드 순서

1. **개인정보처리방침 페이지 게시** — `docs/` 폴더를 GitHub Pages로 공개 (이메일 자리 먼저 수정)
2. **App Store Connect 정보 입력** — 위 A (또는 aside 브라우저에 `ASIDE_PROMPT.md` 붙여넣기)
3. **Xcode 업로드**
   - 위쪽 기기 선택 → **Any iOS Device (arm64)**
   - **Product → Archive** → Organizer → **Distribute App → App Store Connect → Distribute**
   - 같은 버전을 다시 올릴 때는 `project.yml`의 `CURRENT_PROJECT_VERSION`을 2, 3…으로 올린 뒤 `xcodegen generate`
4. **TestFlight** — 10~30분 뒤 빌드 표시 → 내부 테스터(본인) 설치 → 실제 문자 테스트
5. **스크린샷** — 6.9형(아이폰 Pro Max) 시뮬레이터에서 ⌘S, 추천 5장: 홈(레이더·날씨) / 알람 상세 / 근무 달력 / 월간 그래프 / 축하 화면
6. **버전 1.0 → 빌드 선택 → 심사에 추가 → 제출**

## C. 심사 대비 체크 (처리 완료)

| 항목 | 상태 |
|---|---|
| 개인정보 매니페스트 | ✅ PrivacyInfo.xcprivacy |
| 암호화 수출 규정 | ✅ ITSAppUsesNonExemptEncryption = NO |
| 앱 아이콘 1024px (K1) | ✅ |
| 타사 상표(쿠팡) 화면·메타데이터 노출 | ✅ 없음 (메타데이터에도 쓰지 말 것) |
| 권한 설명 | ✅ AlarmKit 사용 설명 |
| WeatherKit 출처 표시 | ✅ 날씨 카드 하단 Apple Weather 로고·링크 |
| 문자 없이 심사하는 방법 | ✅ 심사 메모 |

## D. 유료(₩9,900 등) 판매 시 필요한 것

| 항목 | 내용 |
|---|---|
| 유료 앱 계약 (Paid Apps Agreement) | App Store Connect → 비즈니스 → 계약 |
| **사업자등록번호(BRN)** | 한국 개인 개발자는 필수 (영문 사업자등록증명 함께) |
| 은행 계좌 · 세금 정보 | 같은 화면에서 입력 |
| 한국 법 준수 정보 | 이메일·전화 인증 + BRN (전자상거래법상 상품 페이지에 표시) |

→ 무료로 먼저 출시하고, 사업자등록 후 업데이트에서 유료/인앱결제로 전환 가능.
