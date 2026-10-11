# 키워드알람 앱스토어 제출 가이드

## A. App Store Connect 입력값 (복사해서 붙여넣기)

| 항목 | 입력값 |
|---|---|
| 플랫폼 | iOS |
| 이름 | 키워드알람 (이미 있으면 `키워드알람: 문자 알람·근무 기록`) |
| 기본 언어 | 한국어 |
| 번들 ID | com.gijeong.keywordalarm (Xcode에서 쓴 것과 동일하게) |
| SKU | keywordalarm-001 |
| 카테고리 | 1차: 유틸리티 / 2차: 생산성 |
| 가격 | 무료 |
| 연령 등급 | 4+ (설문 모두 '없음') |
| 개인정보처리방침 URL | https://<깃허브아이디>.github.io/keyword-alarm-ios/privacy.html |
| 지원 URL | https://<깃허브아이디>.github.io/keyword-alarm-ios/ |
| 저작권 | 2026 최기정 |

### 부제 (30자 이내)
```
중요한 문자, 자는 중에도 크게
```

### 홍보 문구 (170자 이내)
```
야간 근무 후 자는 동안 놓친 인센티브 문자, 이제 그만! 등록한 키워드가 담긴 문자가 오면 무음 모드에서도 시계 알람처럼 크게 울리고, 금액·날짜·센터를 한눈에 보여 줍니다.
```

### 키워드 (100자 이내, 쉼표로 구분, 띄어쓰기 없이)
```
문자알람,키워드알람,인센티브,특별지급,근무기록,주휴수당,급여계산,일용직,물류센터,야간근무,알바,출근,무음알람
```

### 설명
```
자는 동안 중요한 문자를 놓치지 마세요.

키워드알람은 미리 등록한 문구(예: 인센티브, 특별지급)가 담긴 문자가 오면 무음·집중 모드에서도 시계 알람처럼 크게 울려 주는 앱입니다. 야간 근무 후 낮에 자는 분, 특정 연락을 꼭 받아야 하는 분을 위해 만들었습니다.

■ 키워드 문자 알람
• 등록한 키워드가 담긴 문자가 오면 무음 모드에서도 크게 울림
• 감시 시간대·요일 설정, 같은 문자 중복 알람 방지
• 띄어쓰기가 달라도 인식 ("특별 지급" = "특별지급")

■ 알람 한 줄에 핵심 정보
• 문자에서 금액·날짜(오늘/내일)·센터·근무조·공정을 자동으로 읽어 알람 제목에 표시
• '자세히'를 누르면 큰 글씨 상세 화면과 근무조별 금액표
• 내 센터를 등록하면 내 센터 기준 최고 금액을 표시

■ 근무 기록과 급여 계산
• 달력에 근무를 기록하면 그날 수입이 바로 계산
• 연장(1.5배)·야간(22~06시 가산) 자동 계산, 일급 직접 입력도 가능
• 주휴수당 진행 상황 표시, 주 5일 달성 시 축하 애니메이션
• 이번 달 번 돈, 근무일수, 예상 실수령, 지난달 대비, 목표 달성률
• 월 근무일수 보너스 규칙 직접 추가

■ 개인정보 걱정 없음
• 회원가입·서버 없음, 모든 데이터는 아이폰 안에만 저장
• 문자 원문은 저장하지 않음

※ 아이폰 기본 '단축어' 앱의 메시지 자동화와 함께 동작합니다. 설정 방법은 앱 안 '설정 안내' 탭에서 단계별로 안내합니다.
※ 문자 메시지만 지원합니다 (카카오톡 등 다른 앱 알림은 iOS 정책상 지원하지 않습니다).
※ 급여·공제 금액은 입력값 기준 추정치이며, 실제 지급액은 급여명세서를 기준으로 하세요.
※ iOS 26 이상에서 사용할 수 있습니다.
```

### 앱 심사 정보 → 메모 (심사관용)
```
This app does not read SMS directly. It provides an App Intent ("문자 확인 후 알람" / Check message and alarm) that the user connects to a Shortcuts personal automation (Message trigger, "Run Immediately"). When the automation passes the received message text, the app checks it for user-defined keywords on-device and schedules an alarm with AlarmKit.

How to review without SMS:
1. Home tab > "알람 권한 허용" (Allow alarms) > "테스트 알람 (5초 뒤)" (Test alarm in 5 sec). Lock the device: the alarm rings even in silent mode. Tap "자세히" (Details) to see the detail screen.
2. Keywords tab > "문구 테스트" (Phrase test): paste any text containing "인센티브" to see the match result and alarm title preview.
3. Work tab (근무): tap a date to add a work record; pay is calculated locally. Adding 5 days in one week (Sun-Sat) shows a celebration animation.

No login, no server, no data collection. All data stays on device.
```

### 앱 개인정보 보호 (App Privacy)
- "데이터를 수집합니까?" → **아니요, 이 앱에서 데이터를 수집하지 않습니다**

---

## B. 제출 순서

1. **개인정보처리방침 페이지 게시** (GitHub Pages)
   - `docs/privacy.html`, `docs/index.html`의 `[문의 이메일을 입력하세요]`를 실제 이메일로 수정
   - GitHub 저장소 업로드 → Settings → Pages → Branch: `main`, 폴더: `/docs` → Save
   - 1~2분 뒤 `https://<아이디>.github.io/<저장소이름>/privacy.html` 접속 확인
2. **App Store Connect에 앱 만들기**: 나의 앱 → + → 신규 앱 → A의 값 입력
3. **Xcode에서 업로드**
   - 위쪽 기기 선택 → **Any iOS Device (arm64)**
   - 메뉴 **Product → Archive** (몇 분)
   - Organizer 창 → **Distribute App → App Store Connect → Distribute**
4. **TestFlight로 먼저 테스트** (권장)
   - 업로드 10~30분 뒤 TestFlight 탭에 빌드 표시
   - 내부 테스터(본인) 추가 → 아이폰 TestFlight 앱으로 설치 → 실제 문자로 최종 확인
   - 동료 배포: 외부 테스트 그룹 → 공개 링크 (첫 외부 테스트는 간단한 심사 있음)
5. **스크린샷**: Xcode 시뮬레이터 중 **가장 큰 Pro Max** 기종 → 앱 실행 → ⌘ + S
   - 추천 5장: 홈(감시 중) / 알람 상세(금액표) / 근무 달력 / 월간 요약 / 주 5일 축하 화면
6. **심사 제출**: 버전 1.0 페이지 → 빌드 선택 → 스크린샷·설명·심사 메모 입력 → 심사에 추가 → 제출

## C. 심사에서 자주 걸리는 것 (이미 처리함)

| 항목 | 상태 |
|---|---|
| 개인정보 매니페스트 (PrivacyInfo.xcprivacy) | ✅ 추가 (UserDefaults 사유 CA92.1) |
| 암호화 수출 규정 | ✅ ITSAppUsesNonExemptEncryption = NO |
| 앱 아이콘 1024px, 투명도 없음 | ✅ |
| 화면·메타데이터의 타사 상표 | ✅ 화면 문구와 테스트 예시에서 회사명·링크 제거 (메타데이터에도 쓰지 말 것) |
| 권한 설명 문구 | ✅ NSAlarmKitUsageDescription |
| 심사관이 문자 없이 테스트할 방법 | ✅ 심사 메모에 안내 |
