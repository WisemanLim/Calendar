# Wise Calendar

한국어 | [English](README.en.md)

개인용 iOS 캘린더 + 플래너 앱. 큰 날짜 화면으로 일정을 직관적으로 입력하고, 다이어리·업무 이벤트·개인 이벤트 3가지 플래너 모드를 지원한다.

- **Profile**: ios-swiftui
- **Domain**: ict-saas (consumer, 서버리스)
- **PRD**: [.docs/PRD.md](.docs/PRD.md)

---

## 아키텍처 / 디렉터리

```
Wise-Calendar/
├── Calendar/
│   ├── AppDelegate.swift           앱 진입점
│   ├── SceneDelegate.swift         RootView 로드
│   ├── RootView.swift              온보딩 분기 → CalendarView
│   │
│   ├── CalendarView.swift          메인 화면 (큰 날짜 + 헤더 + 하단 달력)
│   ├── CalendarLogic.swift         날짜 그리드 순수 함수 (SUN-first 42칸)
│   ├── CalendarTheme.swift         색 테마 구조체
│   │
│   ├── EventStoreManager.swift     EventKit 읽기/쓰기 + CalendarEventItem + 캐시
│   ├── AppSettings.swift           UserDefaults 설정 영속
│   ├── PlannerMode.swift           diary / todo / personalEvent
│   ├── PlannerLogic.swift          순수 함수 (dayOfYear, fixedTitle, encodeTodos)
│   ├── EventTemplate.swift         EventTemplate Codable + TemplateStore
│   ├── NotificationManager.swift   UNUserNotificationCenter (9am 알림)
│   │
│   ├── WeatherService.swift        날씨 서비스 (WeatherKit 주 / Open-Meteo 폴백)
│   │
│   ├── EventEditorView.swift       모드별 이벤트 입력 UI (시간·장소·반복 설정)
│   ├── SettingsView.swift          설정 화면 (연동 · 테마 · 알림)
│   └── OnboardingView.swift        4단계 온보딩 TabView
│
├── Calendar/Assets.xcassets/
│   └── AppIcon.appiconset/         앱 아이콘 (Aug 31, 1024×1024)
│
├── CalendarTests/
│   ├── CalendarLogicTests.swift    9개 단위 테스트
│   └── PlannerLogicTests.swift     15개 단위 테스트
│
├── test/
│   ├── dev-env/                    dev-env 시험 기록
│   └── impl/{1..4}/               구현 차수별 시험 시나리오 + 결과
│
└── .docs/PRD.md                    One-Page PRD
```

### 주요 컴포넌트

| 파일 | 역할 |
|------|------|
| `RootView` | 온보딩 분기 (`shouldShowOnboarding` → `.fullScreenCover`) |
| `CalendarView` | 큰 날짜 히어로(더블탭·롱프레스=이벤트 추가), 헤더(음력+날씨 아이콘+온도 같은 라인), 주간 스트립(좌우 스와이프로 전주·다음주 이동), 하단 2개월 미니 달력, overdue 적색, **이벤트 탭=편집 즉시 진입**, 편집 시트 닫힘 시 캐시 무효화·재로드, 무지개 색상. **비밀 약속**: `[비밀]` prefix 이벤트 `.opacity(0.25)` 흐린 표시. **롱프레스(0.6s)**: `addButtonLongPressed` 플래그로 팝업 즉시 닫힘 방지. **풀-투-리프레시**: 일정 목록 영역 아래로 드래그(60pt↑) → 날씨·일정 동기화 (`simultaneousGesture` 수직 판별) |
| `CalendarLogic` | 그리드 42칸 생성, `dateKey(yyyy-MM-dd)`, SUN-first 정렬 |
| `CalendarTheme` | `accent/month/year/todayTint/navBackground/sunday/saturday`; `.default` 제공 |
| `CalendarEventItem` | 이벤트 표시용 값 타입 — `displayTitle("HH:mm 제목")`, `isOverdue`, `isTodo` |
| `EventStoreManager` | `EKEventStore` 래퍼, `[String:[CalendarEventItem]]` 캐시, `addEvent` / `updateEvent` / `deleteEvent` / `fetchEvent`. `cachedEventCounts` UserDefaults 캐시(`wc.eventCountCache`) — 앱 시작 즉시 이벤트 갯수 이모지 표시 |
| `AppSettings` | UserDefaults: `plannerMode`, `notificationsEnabled`, `onboardingCompleted`, `enabledCalendarIDs`, `lastSeenVersion`, `appColorScheme` |
| `AppColorScheme` | `system`/`dark`/`light` 롤링 전환 enum — `icon`(SF Symbol), `colorScheme: ColorScheme?`, `next` 프로퍼티 |
| `WeatherService` | WeatherKit(Apple) 우선 → Open-Meteo 폴백. `dailyWeather[yyyy-MM-dd]` + `dailyTemperature[yyyy-MM-dd]: [String: Int]` Published. `WeatherCondition: String, Codable, Equatable` — UserDefaults 캐시(`wc.dailyWeather`, `wc.dailyTemperature`) 선표시 후 변경 시만 갱신. **일별 강제 갱신**: `wc.lastFetchDate` 저장 → 앱 실행 시 오늘 날짜와 다르면 `hasFetched` 리셋 → 무조건 재조회 |
| `eventDayEmoji()` | 이벤트 갯수 → 얼굴 이모지: 0~1=😀, 2~3=😊, 4+=🤯 |
| `PlannerMode` | `diary`(일기) · `todo`(업무 이벤트) · `personalEvent`(개인 이벤트) |
| `PlannerLogic` | `dayOfYear`, `fixedTitle("[#ddd] …")`, `encodeTodos`, `decodeTodos` |
| `EventTemplate` | `workEvent`(업무 이벤트 전용)·`medication`·`appointment`·`fixed` 카테고리. `isTodo: Bool` 플래그(체크리스트 스타일). `defaultStartHour`, `defaultDurationMinutes` |
| `TemplateStore` | UserDefaults JSON 영속, 키 `templates.v3`, seed 15건, `update()` |
| `EventEditSheet` | 등록 이벤트 수정 시트 — 제목·시간·장소·메모 편집, `updateEvent` 호출. **시작 시간 변경 시 종료 시간 자동 조정** (`originalDuration` 유지). 메모 `TextEditor` 자동 확장 |
| `EventCopySheet` | 이벤트 복사 시트 — DatePicker(목표 날짜) + 제목·시간·메모 미리보기, `addEvent` 호출 |
| `eventCountColor()` | 이벤트 갯수 → 무지개 7단계: 0=기본, 1=노, 2=주, 3=초, 4=남, 5=보, 6+=빨 |
| `MedicationPreset` | 아침(7h)/점심(12h)/저녁(18h)/직접 — 복용 시간 프리셋 |
| `EventImageStore` | 복용 이벤트 사진 영속 — Documents JPEG + UserDefaults eventID 매핑 |
| `CameraPicker` | `UIImagePickerController` 카메라 래퍼 (`UIViewControllerRepresentable`) |
| `PlannerLogic.substituteTitlePatterns` | 타이틀 날짜 패턴 치환 (`yyyy-mm-dd`, `d###` 등 6종) |
| `NotificationManager` | `UNUserNotificationCenter`, 9am 로컬 알림 예약 |

---

## 사전 요구사항

| 도구 | 최소 버전 |
|------|-----------|
| macOS | 15 Sequoia+ |
| Xcode | 16+ |
| iOS SDK | 17+ |
| 시뮬레이터 | iPhone 17 (또는 실기기) |

외부 의존성(CocoaPods/SPM 패키지) 없음.

---

## 환경 설정

서버리스 앱 — `.env` 파일·API 키 없음.

**Info.plist 권한** (기 설정됨):
- `NSCalendarsUsageDescription` — EventKit 캘린더 읽기/쓰기
- `NSRemindersUsageDescription` — 미리 알림 접근
- `NSLocationWhenInUseUsageDescription` — 날씨 정보용 현재 위치
- `NSCameraUsageDescription` — 복용 이벤트 사진 첨부
- `NSPhotoLibraryUsageDescription` — 앨범 사진 첨부

**Google 캘린더 연동** (OAuth 불필요):
1. iPhone → 설정 → 캘린더 → 계정 → 계정 추가 → Google 로그인
2. 앱이 EventKit을 통해 자동으로 해당 캘린더 표시

**알림**: 런타임에 `UNUserNotificationCenter.requestAuthorization()` 호출.

---

## 날씨 연동 (WeatherKit)

WeatherKit(Apple)을 기본으로 사용하고, 실패 시 Open-Meteo(무료·API 키 없음)로 자동 폴백.

### WeatherKit 활성화 (Apple Developer Portal 필수)

1. [developer.apple.com](https://developer.apple.com) → Certificates, Identifiers & Profiles
2. Identifiers → `com.wiseman.calendar` 선택
3. **WeatherKit** 체크박스 활성화 → Save
4. Xcode에서 재빌드 (entitlements 파일 `Calendar/Calendar.entitlements` 이미 포함됨)

> WeatherKit이 비활성화 상태이면 앱이 자동으로 Open-Meteo로 폴백하므로 날씨 아이콘 및 온도는 정상 표시됨. Open-Meteo 요청 파라미터: `weather_code,temperature_2m_max`.

### WeatherKit API 사용

```swift
// WeatherService.swift
let forecast = try await WeatherKit.WeatherService.shared
    .weather(for: location, including: .daily)

for day in forecast.forecast {
    let condition = WeatherCondition.from(wkCondition: day.condition)
    // condition.sfSymbol → SF Symbol 이름 (예: "sun.max.fill")
    // condition.tintColor → SwiftUI Color
    let tempC = Int(day.highTemperature.converted(to: .celsius).value.rounded())
    // → dailyTemperature[yyyy-MM-dd] 에 저장, 헤더에 온도 표시
}
```

### WeatherCondition 매핑

| WeatherKit | 내부 enum | SF Symbol |
|-----------|-----------|-----------|
| `.clear`, `.mostlyClear` | `.clear` | `sun.max.fill` |
| `.partlyCloudy`, `.sunShowers` | `.partlyCloudy` | `cloud.sun.fill` |
| `.cloudy`, `.mostlyCloudy` | `.overcast` | `cloud.fill` |
| `.foggy`, `.haze` | `.fog` | `cloud.fog.fill` |
| `.drizzle` | `.drizzle` | `cloud.drizzle.fill` |
| `.rain`, `.freezingRain` | `.rain` | `cloud.rain.fill` |
| `.heavyRain` | `.heavyRain` | `cloud.heavyrain.fill` |
| `.snow`, `.heavySnow`, `.blizzard` | `.snow` | `snowflake` |
| `.thunderstorms`, `.strongStorms` | `.thunderstorm` | `cloud.bolt.rain.fill` |

---

## 실행 방법

### A. Xcode GUI

```
1. Calendar.xcodeproj 열기
2. Scheme: "Calendar" 확인
3. 시뮬레이터: "iPhone 17" 선택 (또는 연결된 실기기)
4. ▶ Run (⌘R)
```

### B. xcodebuild 커맨드라인

```bash
# 빌드
xcodebuild build \
  -project Calendar.xcodeproj \
  -scheme Calendar \
  -destination 'platform=iOS Simulator,name=iPhone 17'

# 빌드 + 테스트
xcrun simctl shutdown all    # 시뮬레이터 플레이크 방지
xcodebuild test \
  -project Calendar.xcodeproj \
  -scheme Calendar \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

---

## 화면 구조

| 화면 | 진입 방법 | 설명 |
|------|-----------|------|
| `OnboardingView` | 앱 시작 (Release: 최초 설치·재설치·버전 업데이트 / DEBUG: 매회) | 소개+모드선택 → 일기+할일 → 개인이벤트 → 연동+알림 4단계 |
| `CalendarView` | 온보딩 완료 후 기본 화면 | 큰 날짜 히어로 + 헤더(음력+날씨 아이콘+온도 같은 라인) + 일정 목록(아래로 드래그=날씨·일정 새로고침) + 하단 미니 달력, overdue 적색 |
| `EventEditorView` | `+` 버튼 탭 | 모드별 이벤트 입력 (시간·장소·반복) |
| `SettingsView` | `⚙` 버튼 탭 | 캘린더 연동 · 플래너 모드 · 알림 · 화면 테마(system/dark/light 롤링) |

---

## 주요 기능 예시

### 플래너 모드별 이벤트 저장 및 시간 처리

| 모드 | 시간 처리 | EKEvent.notes 형식 |
|------|-----------|-------------------|
| `diary` | 에디터 오픈 시각=startDate, 저장 시각=endDate | 자유 텍스트 |
| `todo/할 일` (`isTodo=true`) | due-date DatePicker → startDate=endDate=기한 | `"- [ ] 항목"` |
| `todo/회의·세미나·회식` (`isTodo=false`) | 시작·종료 DatePicker + 장소 → EKEvent.location | nil |
| `personalEvent/medication` | 아침(7h)/점심(12h)/저녁(18h)/임시긴급 프리셋 또는 직접. 반복 토글(yearly). 사진/카메라 첨부. | nil |
| `personalEvent/appointment` | 시작·종료 DatePicker + 장소. **비밀 약속**: `[비밀]` prefix → opacity 0.25 표시 | nil |
| `personalEvent/fixed` | 시작·종료 + yearly EKRecurrenceRule | nil |

### overdue 적색 표시

```swift
// CalendarEventItem.isOverdue 조건
let isOverdue = isTodo && event.startDate < now && notes.contains("- [ ]")
// → CalendarView에서 해당 항목 텍스트·점 빨간색
```

### [#ddd] 연간 고정 이벤트

```swift
let title = PlannerLogic.fixedTitle(dayOfYear: 162, title: "알레르기 약 복용(-/-)")
// → "[#162] 알레르기 약 복용(-/-)"
```

### 복용 프리셋 기본값 저장

```swift
// "기본 시간으로 저장" 탭 시
templateStore.update(template.with(defaultStartHour: 7))
// → UserDefaults에 영속, 다음 선택 시 07:00 자동 적용
```

### 약속 장소 저장

```swift
eventStore.addEvent(title: "연인과 약속", notes: nil,
    startDate: start, endDate: end,
    location: "강남역 스타벅스")
// → EKEvent.location → iOS 캘린더 앱에서 지도 링크 표시
```

### 타이틀 날짜 패턴 치환 (개인이벤트)

```swift
// 2026-03-08에 저장 시
PlannerLogic.substituteTitlePatterns("[정기작업] (d###) yyyy-mm-dd", date: date)
// → "[정기작업] (067) 2026-03-08"

// 날짜 패턴 없는 복용/약속 이벤트 → 자동 yearly RRULE 생성
PlannerLogic.hasTitleDatePattern("아침 약 복용") // false → auto RRULE
```

지원 패턴: `yyyy-mm-dd` · `yyyy/mm/dd` · `yy-mm-dd` · `yyyy.mm.dd` · `dd-mm-yyyy` · `d###`

### 복용 이벤트 사진 첨부

```swift
// EventEditorView에서 앨범 또는 카메라로 사진 선택
// 저장 성공 후 자동으로 EventImageStore에 연결
EventImageStore.shared.loadImage(for: eventId) // → UIImage?
```

### 일정 목록 음력+날씨 표시

```swift
// CalendarView 헤더 — 음력과 날씨를 같은 라인에 표시
// weatherService.dailyWeather["2026-06-23"] → WeatherCondition.clear
// weatherService.dailyTemperature["2026-06-23"] → 28  (°C)
// → Image(systemName: "sun.max.fill") + Text("28°")
```

### 알림 예약

```swift
NotificationManager.shared.scheduleEventReminder(title: "회의", on: date)
// UNCalendarNotificationTrigger: 지정일 09:00
```

---

## 앱 아이콘

`Calendar/Assets.xcassets/AppIcon.appiconset/AppIcon.png` (1024×1024)

- 빨간 헤더 + "Aug" 흰색 볼드
- 상단 스프링 바인딩 링 9개
- 큰 "31" (2026년 8월 31일)
- 우하단 페이지 접힘 효과

---

## 테스트

```bash
xcrun simctl shutdown all
xcodebuild test \
  -project Calendar.xcodeproj \
  -scheme Calendar \
  -destination 'platform=iOS Simulator,name=iPhone 17'
# → Executed 29 tests, with 0 failures
```

| 테스트 클래스 | 수 | 내용 |
|-------------|----|------|
| `CalendarLogicTests` | 9 | dateKey 포맷, 42칸 그리드, SUN-first 정렬, 이벤트 주입 |
| `PlannerLogicTests` | 20 | dayOfYear 5종, fixedTitle 4종, encodeTodos 4종, EventTemplate 2종, 타이틀 패턴 5종 |

시험 기록: [impl/1](test/impl/1/result.md) · [impl/2](test/impl/2/result.md) · [impl/3](test/impl/3/result.md) · [impl/4](test/impl/4/result.md)

---

## 트러블슈팅

### 시뮬레이터 "Busy / FBSOpenApplicationServiceErrorDomain Code=1"

```bash
xcrun simctl shutdown all
```

### "No such module 'Calendar'" (XCTest 타깃)

Xcode → CalendarTests 타깃 → Build Settings → `TEST_HOST` = `$(BUILT_PRODUCTS_DIR)/Calendar.app/Calendar`

### Google 캘린더가 앱에 표시되지 않음

1. 기기 설정 → 캘린더 → 계정에 Google 계정 추가
2. 앱 설정(⚙) → "캘린더 연동" 체크
3. 기기 설정 → 개인 정보 보호 → 캘린더 → Wise Calendar 허용

### 알림이 오지 않음

1. 기기 설정 → 알림 → Wise Calendar → 허용
2. 앱 설정(⚙) → 알림 토글 ON
3. DEBUG: 온보딩 매회 표시 → 4단계에서 "알림 허용" 탭

---

## 다음 단계 (PRD 잔여)

- [ ] 위젯 (iOS WidgetKit) — 오늘 일정 미리보기
- [ ] iCloud 동기화 — 멀티 디바이스 플래너 데이터
- [ ] 사용자 정의 테마 — `CalendarTheme` 커스텀 팔레트 UI
- [ ] App Store 배포 — Fastlane → TestFlight → 심사
