아래는 App Store Connect에서 내 앱 정보를 '인센콜'로 바꾸고 1.0 버전 정보를 채우는 작업이야. appstoreconnect.apple.com의 '키워드알람'(번들 ID com.gijeong.keywordalarm) 앱에서 순서대로 진행해 줘. 각 섹션마다 입력 후 '저장'을 누르고, 화면을 캡처해서 보여줘. 
⚠️ 다음은 절대 누르지 마: '심사에 추가', '심사를 위해 제출', '앱 삭제', 가격을 유료로 바꾸기, 계약·세금·은행 정보 변경. 이 단계가 나오면 멈추고 나에게 물어봐.

[1] 앱 정보 (일반 정보 > 앱 정보)
- 이름: 인센콜
- 부제: 인센티브 문자 알람·근무·급여 기록
- 카테고리: 기본 '유틸리티', 보조 '생산성'
- 연령 등급: '설정' 눌러 모든 항목 '없음' / '아니요' → 4+
- 개인정보 처리방침 URL: https://<깃허브아이디>.github.io/keyword-alarm-ios/privacy.html
  (이 주소가 아직 없으면 비워 두고 나에게 알려줘)
→ 저장

[2] 가격 및 사용 가능 여부
- 가격: 무료 (₩0)
- 사용 가능 국가: 대한민국 포함 (나머지는 기본값 그대로)
→ 저장

[3] 앱이 수집하는 개인정보 (App Privacy)
- '시작하기' → "이 앱에서 데이터를 수집합니까?" → '아니요, 데이터를 수집하지 않습니다' → 저장 → '게시'

[4] iOS 앱 1.0 제출 준비 중 (버전 정보, 한국어)
- 홍보 문구:
야간 근무 후 자는 동안 놓친 인센티브 문자, 이제 그만! 등록한 문구가 담긴 문자가 오면 무음 모드에서도 크게 울리고, 근무·주휴수당·월 수입까지 한 번에 관리하세요.
- 키워드:
인센티브,특별지급,문자알람,근무기록,주휴수당,급여계산,일당,일용직,물류센터,야간근무,알바,공휴일수당,무음알람
- 지원 URL: https://<깃허브아이디>.github.io/keyword-alarm-ios/
- 저작권: 2026 최기정
- 설명 (아래 <<< >>> 사이 전체):
<<<
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
>>>
- 앱 심사 정보 > 로그인 필요: 체크 해제
- 앱 심사 정보 > 연락처: 이름 최기정, 내 전화번호, 내 이메일
- 앱 심사 정보 > 메모 (아래 <<< >>> 사이 전체):
<<<
This app does not read SMS directly. It provides an App Intent ("문자 확인 후 알람" / Check message and alarm) that the user connects to a Shortcuts personal automation (Message trigger, "Run Immediately"). The received message text is checked on-device for user-defined keywords and an alarm is scheduled with AlarmKit.

How to review without SMS:
1. Home tab > "알람 권한 허용" (Allow alarms) > "테스트 알람 (5초 뒤)" (Test alarm in 5 sec). Lock the device: the alarm rings even in silent mode. Tap "자세히" (Details) for the detail screen.
2. Keywords tab (키워드) > "문구 테스트": paste any text containing "인센티브" to see the match result and alarm title preview.
3. Work tab (근무): tap a date to add a work record; pay is calculated locally. Gear icon > "주휴수당 축하 화면 미리보기" shows the celebration animation.
4. Weather on the Home tab uses WeatherKit with a user-selected region (no GPS, no location permission). Apple Weather attribution is shown in the card.

No login, no server, no analytics, no data collection. All data stays on device.
>>>
- 버전 출시: '이 버전을 수동으로 출시'
→ 저장

[5] 끝나면 각 섹션에 빠진 필수 항목(빨간 표시)이 있는지 확인해서 목록으로 알려줘. 스크린샷과 빌드 선택은 내가 직접 할게.
