# PRD — Wise-Calendar (위클리 플래너 iOS 앱)

> One-Page PRD · 애자일 · 작성일 2026-06-11 · 도메인: ict-saas (소비자 iOS 앱)
> 모르는 값은 `가정:` 으로 표시. 검토 후 확정 필요.

## 1. Why — 목표 / 문제

기존 iOS 캘린더 이벤트를 **큰 날짜 + 스와이프 + 다개월 그리드**로 빠르게 보고,
**주간 계획(Weekly Plan)** 을 세우는 미니멀 위클리 플래너.
조회·계획 중심. 동작 완성도를 높여 가능하면 **App Store 출시**.

## 2. Who — 사용자

- 주 사용자: 개인 일정을 관리하는 **일반 iOS 사용자**.
- 가정: iOS 17+ 단일 디바이스(iPhone) 사용. 다국어 중 한국어 우선.

## 3. What — 핵심 기능 (현재 구현 + 확장)

**구현됨 (코드 기준)**
- 큰 날짜 히어로 + 요일, 좌우 스와이프로 전일/익일 이동.
- **히어로 영역 더블탭 또는 길게 누르기** → 이벤트 추가 에디터 열기 (+ 버튼과 동일).
- 상단 헤더: `< 월 >`(월 이동) + `[Today]`(선택일이 오늘 아닐 때만) + `< 연 >`(연 이동). §3.1 참조.
- 하단 미니 달력: 현재월 + 다음월 2개 (이전 4개월 그리드 → 2개월로 축소).
- 색상 테마(`CalendarTheme`) — 연도/연 이동 동일 색, 강조·월·주말색 분리, `.default` 주입.
- EventKit 연동: 캘린더 접근 요청, 일자별 이벤트 조회·캐시 (`HH:mm 제목`).
- 일자별 이벤트 점 표시, 선택일 SCHEDULE 리스트 (중복 없음).
- **이벤트 갯수 색상**: 하단 미니 달력 날짜 숫자 + 히어로 날짜 수자에 이벤트 갯수에 따른 무지개 7단계 색상 적용.
  `0=기본`, `1=노(yellow)`, `2=주(orange)`, `3=초(green)`, `4=남(navy)`, `5=보(purple)`, `6+=빨(red)`.
  파란색(`theme.accent`)은 선택된 날짜(미니 달력)를 의미하며 변경 없음.
  히어로 숫자는 동일 색상을 opacity 0.28 로 적용(워터마크 효과 유지).
- **이벤트 수정/삭제**: 등록된 이벤트 **탭** → 편집(`EventEditSheet`) 즉시 진입. 길게 누르기(컨텍스트 메뉴) → 복사·삭제.

**확장 (다음 범위 — 기능 확장 + 리팩터/표준화)**
- 이벤트 추가/편집/삭제 (EventKit 쓰기).
- **앱 설정 + 플래너 모드 + 템플릿 + 온보딩** (§3.2).
- 위클리 뷰 (스케치의 WEEKLY PLAN: 주차별 #1~#2 슬롯).
- 연간 뷰 / 빠른 연·월 점프(스케치의 다이얼 선택).
- 다크/브랜드 테마 적용(`CalendarTheme` 교체) — 기반 마련됨.
- 가정: 데이터는 기기 EventKit 만 사용, 별도 백엔드/계정 없음.

### 3.1 헤더/테마 UI 사양 (2026-06-11 반영, 첨부 이미지 기준)

1. **상단 유틸리티 바** (Row 1) — `⚙` (왼쪽) | `[Today]`(선택일 오늘 아닐 때) + `< 년 >` (중앙) | `＋` (오른쪽).
2. **월 헤더** (Row 2) — `<` | `MONTH YEAR` | `>` 전체 너비. 월 이름이 한 줄에 표시됨.
3. **주간 스트립** (Row 3) — 선택일이 포함된 주(일~토) 7셀. 각 셀: 요일 약어 + 날짜 숫자(원형 강조) + 날씨 아이콘.
   - 날씨 아이콘: SF Symbol (`sun.max.fill` 등) + `WeatherCondition.tintColor`.
   - 날씨 미조회 시 이모지 대체: 0~1개 이벤트 = 😀, 2~3개 = 😊, 4개 이상 = 🤯.
   - 날씨 데이터: WeatherKit(Apple) 우선 + Open-Meteo(무료·무키) 폴백 + CoreLocation, 실패 시 이모지 자동 대체.
   - `WeatherService.dailyTemperature: [String: Int]` — 날짜키별 일 최고기온(°C). WeatherKit: `day.highTemperature.converted(to: .celsius)`, Open-Meteo: `temperature_2m_max` 파라미터. 캐시키: `wc.dailyTemperature`.
   - **좌우 스와이프**: 좌 스와이프 → 다음 주(+7일), 우 스와이프 → 이전 주(-7일). 임계값 50pt, 러버밴드(0.25×) 피드백.
4. **Today 버튼** — Row 1 중앙. 선택일이 당일 아닐 때만 노출.
5. **연 이동** — `<`(이전년)·`>`(다음년). 버튼·숫자 색 = `CalendarTheme.year`.
6. **월 이동** — Row 2 좌우 chevron.
7. **하단 달력** — 현재월·다음월 2개를 좌우 배치. 선택/오늘/이벤트 점 = `theme.accent`. 좌우 스와이프로 월 이동(좌 → 다음달, 우 → 이전달). 임계값 50pt, 러버밴드(0.25×) 피드백.
8. **＋ 버튼 길게 누르기** — `confirmationDialog`로 현재 설정 외 다른 입력 방식 목록 노출,
   선택 시 `oneTimeModeOverride` 에 저장 → 해당 세션 1회만 적용 후 초기화.
9. **일정목록(SCHEDULE 영역) 상단 정보 바** — "SCHEDULE" 헤더 텍스트 없음. 대신 선택일 기준 단일 라인으로 표시:
   - **좌측**: 음력 날짜 (예: `음력 5월 28일`)
   - **우측**: 날씨 아이콘 + 일 최고기온 (예: `☀ 29°`) — `WeatherService.dailyTemperature[dateKey]` 사용.
   - 온도 미조회 시 아이콘만 표시.

### 3.2 설정 · 플래너 모드 · 템플릿 · 온보딩 (2026-06-11 추가 요구)

> 용어: "사용자 테마"(입력 방식) = **플래너 모드**(`PlannerMode`), 색 테마(`CalendarTheme`)와 별개.

**(A) 앱 설정** — 일반 캘린더 앱 준용. 헤더 톱니 버튼 → `SettingsView`.
- (1) **연동** — iOS 시스템 계정 기반. EventKit 이 시스템에 추가된 Google/iCloud 캘린더 소스를 노출하므로,
  표시할 캘린더 소스 선택 + "기기 설정 → 캘린더에 Google 계정 추가" 가이드 제공.
  *가정: 자체 Google OAuth 는 백엔드 필요 → 차후. 현 단계는 시스템 계정 경유.*
- (2) **사용자 테마(플래너 모드)** — diary / todo / personalEvent 중 택1. 이벤트 추가 UX 결정.
- (3) **알림** — 로컬 알림(UNUserNotificationCenter) on/off + 권한 요청/가이드.
- (4) **화면 테마(앱 색상 모드)** — 설정 내비게이션 바 "설정" 제목과 동행. 아이콘 탭마다 system(`desktopcomputer`) → dark(`moon.fill`) → light(`sun.max.fill`) 롤링 전환. `.contentTransition(.symbolEffect)` 애니메이션 적용. `.preferredColorScheme`으로 앱 전체 반영.
- 설정 영속화: `AppSettings`(UserDefaults). 필드: `plannerMode`, `notificationsEnabled`,
  `onboardingCompleted`, `enabledCalendarIDs`, `lastSeenVersion`, `appColorScheme`.

**(B) 플래너 모드별 이벤트 추가 UX**
- **diary(일기)** — 추가 시 전체화면 에디터(`TextEditor`)로 확대, 자유 본문 입력 → EKEvent.notes 저장.
  - **시간 자동 설정**: 에디터를 열 때의 현재 시각이 이벤트 `startDate`, 저장(확인) 버튼을 누른 시각이 `endDate` 로 자동 기록.
  - 경과 시간 표시: 에디터 우상단에 `mm:ss`(1시간 이상이면 `h:mm:ss`) 실시간 표시.
- **todo(일정관리)** — 체크리스트 입력(여러 항목), 각 항목 완료 토글. notes 에 `- [ ]`/`- [x]` 로 인코딩,
  목록에서 완료여부 수정 가능.
  - **Due Date 필수**: 이벤트 추가 시 목표 시간(기한, due-date)을 `DatePicker`로 반드시 설정. 기본값 = 선택일 23:59.
  - **기한 초과 적색 표시**: `isTodo && startDate < now && notes 에 "- [ ]" 존재` 인 항목은 캘린더 뷰에서 빨간색으로 표시 (`isOverdue` 플래그, `CalendarEventItem`).
- **personalEvent(개인 이벤트)** — 추가 시 **템플릿 선택** 후 프리필 입력. 카테고리별 시간 설정 방식 상이.
  - **복용(medication)**: 아침(7시)/점심(12시)/저녁(18시) 프리셋 버튼 + 직접 입력(`DatePicker`). 선택한 시간을 "기본 시간으로 저장" 시 해당 템플릿의 `defaultStartHour` 갱신.
    반복 토글(매년 Yearly) + 시작일·종료일 선택 지원. **사진/카메라** 첨부 가능 — `PhotosPicker`(앨범) 또는 `UIImagePickerController`(카메라), `EventImageStore`에 JPEG 저장.
  - **약속(appointment)**: 시작/종료 시각 `DatePicker` 각각 설정. **장소(location)** 텍스트 입력 (선택) → EKEvent.location 저장, iOS 지도 앱 연동. 반복 설정 없음.
  - **고정(fixed)**: 시작/종료 시각 `DatePicker` 설정(기본 종료=시작과 동일). 반복 토글 활성화 시 반복 시작일·종료일 선택, 매년(yearly) `EKRecurrenceRule` 적용.

**(B-2) 개인이벤트 타이틀 날짜 패턴 치환**

개인이벤트 저장 시 제목에 아래 패턴이 포함되면 저장일 기준 실제 날짜로 치환된다.

| 패턴 | 예시 (2026-03-08 기준) |
|------|------------------------|
| `yyyy-mm-dd` | `2026-03-08` |
| `yyyy/mm/dd` | `2026/03/08` |
| `yy-mm-dd` | `26-03-08` |
| `yyyy.mm.dd` | `2026.03.08` |
| `dd-mm-yyyy` | `08-03-2026` |
| `d###` | `067` (연중 일련일, 3자리) |

패턴 조합 가능: `[정기작업] (d###) yyyy-mm-dd` → `[정기작업] (067) 2026-03-08`

**자동 RRULE**: 제목에 날짜 패턴이 없으면 복용 카테고리는 자동으로 yearly `EKRecurrenceRule`을 생성한다. 복용 카테고리는 명시적 반복 토글로도 제어 가능. 약속(appointment) 카테고리는 반복 설정 미지원.

**(C) 템플릿(`EventTemplate`)** — UserDefaults(JSON) 영속.
- 카테고리: `medication`(복용: 아침/점심/저녁), `appointment`(약속: 연인/친구/회식 등), `fixed`(고정).
- **시간 기본값 저장**: `defaultStartHour`(0–23), `defaultDurationMinutes` 필드로 카테고리별 기본 시각 기억.
  - medication 기본값: 아침=7h, 점심=12h, 저녁=18h (duration=0).
  - appointment 기본값: 연인=19h/120m, 친구=14h/120m, 회식=18h/180m.
  - fixed 기본값: 9h/0m.
- **고정/반복 이벤트** — 연간 동일 패턴. 표기 `[#ddd] 제목(-/-)`, `#ddd` = 해당 연의 일련일(day-of-year, 1–365/366).
  예: `[#162] 알레르기 약 복용(-/-)` = 그 해 162번째 날. 매년 같은 day-of-year 에 재현.
- 기본 템플릿 시드 제공. 사용자 추가/편집 가능.

**(D) 온보딩/인트로(`OnboardingView`)**
- 노출 조건: 최초 설치·재설치(`!onboardingCompleted`) **또는 버전 업데이트**(`lastSeenVersion ≠ currentBundleVersion`) **또는 DEBUG 빌드에서는 매번**.
- 4단계:
  1. **소개 + 모드 선택** — 앱 소개 씬 카드(웹툰 스타일) + 주요 기능 목록 + 플래너 모드 선택 버튼 + 설정 변경 안내.
  2. **일기 + 일정관리** — 두 모드를 각각 씬 카드 + 기능 목록으로 나란히 설명.
  3. **개인이벤트** — 복용(📷 사진 강조) · 약속 · 고정 3가지 카드.
  4. **연동 + 알림** — Google/iCloud 연동 씬 카드 + 알림 씬 카드(허용 버튼 내장).
  완료 시 `onboardingCompleted=true`, `lastSeenVersion=currentBundleVersion`.

**(E) 이벤트 복사(`EventCopySheet`)**
- 컨텍스트 메뉴 "복사(내용포함)" / "복사(내용제외)": 기존 이벤트를 다른 날짜로 복제.
- `EventCopyConfig(id, item, includeNotes)` → `EventCopySheet`: 상단 DatePicker(목표 날짜) + 제목·시간·메모 미리보기 Form → 저장 시 `addEvent` 호출.

## 4. How — 접근

- 플랫폼: iOS (SwiftUI + EventKit + UserNotifications). 단일 앱, 서버 없음.
- 현재 UIKit `ViewController`/`Main.storyboard` 는 미사용 데드코드 → 정리 대상.
- 진입점: `SceneDelegate` → `UIHostingController(RootView())`.
  `RootView` = 온보딩 노출 분기(`AppSettings`) 후 `CalendarView`.
- 영속화: `AppSettings`·`EventTemplate` = UserDefaults(JSON). 일정 본문 = EKEvent.notes 인코딩.
- 순수 로직(모드 인코딩/디코딩, day-of-year, 템플릿 직렬화)은 `CalendarLogic`/신규 헬퍼로 추출 → 단위 테스트.
- 가정: 의존성 매니저 없음(SwiftPM/CocoaPods 미사용), Xcode 프로젝트 단독 빌드. Google 자체 OAuth 미포함.

## 5. Success — 성공 기준 / 검증

| 기준 | 측정 |
|------|------|
| 빌드 성공 | `xcodebuild` 경고/에러 없이 빌드 |
| 동작 완성도 | 핵심 화면(히어로·그리드·스와이프·이벤트 표시) 무크래시 동작 |
| EventKit 연동 | 접근 허용/거부 분기, 이벤트 조회·표시 정상 |
| 테스트 | 그리드(`CalendarLogic.monthGrid`)·`dateKey`·day-of-year·모드/템플릿 인코딩 단위 테스트 통과 |
| 설정/모드 | 설정 영속(UserDefaults), 플래너 모드별 추가 UX 분기, 모드 전환 반영 |
| 템플릿 | 기본 템플릿 시드, 고정 `[#ddd]` 패턴 직렬화·매년 재현, `defaultStartHour`/`defaultDurationMinutes` 저장 |
| 온보딩 | 최초 실행/DEBUG 매회 노출, 완료 후 미노출(릴리스) |
| diary 시간 | 에디터 오픈 시각=startDate, 저장 시각=endDate 자동 기록 |
| todo 기한 | due-date DatePicker 필수, 기한 초과 항목 캘린더 뷰에서 적색 표시 |
| medication 시간 | 아침/점심/저녁 프리셋 버튼 + 직접 입력, 기본값 템플릿 저장 |
| appointment 시간+장소 | 시작·종료 DatePicker + 장소 TextField → EKEvent.location |
| fixed 반복 | 시작·종료 시간 설정, 반복 토글 + 시작/종료일 선택, yearly EKRecurrenceRule |
| (확장 목표) 출시 | 가정: 메모리·접근성·App Store 심사 가이드 충족 |

## 6. 알려진 이슈 / 리스크 (코드 분석)

**해소됨 (impl/1·impl/2·impl/3)**
- ~~SCHEDULE 메모 중복 렌더~~ → nested HStack 제거.
- ~~단위 테스트 타깃 부재~~ → `CalendarTests` 신설, 24 케이스 통과.
- ~~월 그리드 SUN-first 정렬 어긋남~~ → `CalendarLogic.monthGrid` 교정.
- ~~좌측 하단 달력이 전월 표시~~ → `selectedDate` 변경 시 `currentDate` 월 동기화.
- ~~연 다를 때 Today 버튼 미표시~~ → `changeYear` 에서 `selectedDate` 도 갱신.
- ~~이벤트 시간 정보 없음~~ → `CalendarEventItem.displayTitle("HH:mm 제목")`, `addEvent` 시간 범위 파라미터화.
- ~~todo 기한·overdue 표시 없음~~ → `isOverdue` 플래그, 캘린더 뷰 적색 표시.
- ~~diary 시간 자동 기록 없음~~ → editorOpenTime=start, saveTime=end.
- ~~medication/appointment/fixed 시간 설정 없음~~ → 카테고리별 시간 UI + yearly 반복 설정.
- ~~SCHEDULE 이벤트 중복 표시~~ → `MemoListView` 제거, ForEach 단일 렌더링.
- ~~이벤트 수정·삭제 없음~~ → 컨텍스트 메뉴 + `EventEditSheet`, `deleteEvent`/`updateEvent`.
- ~~히어로 영역 제스처로 이벤트 추가 불가~~ → 더블탭·롱프레스 → `showEditor = true`.
- ~~날짜 색상 단일색~~ → `eventCountColor()` 무지개 7단계, 미니 달력 + 히어로 동시 적용.
- ~~미니 달력 색상 클릭 전 미표시~~ → `fetchEventsForMonth` 추가, 월 단위 단일 쿼리로 일별 캐시 선채움. `.onAppear`, `currentDate` 변경, `hasAccess` 변경 시 자동 프리패치.

- ~~등록 이벤트 수정·삭제 반영 안됨~~ → `fetchEvents` 비동기 Task → 동기 직접 할당 수정.
- ~~개인이벤트 타이틀 날짜 패턴 없음~~ → `PlannerLogic.substituteTitlePatterns/hasTitleDatePattern` 추가, 저장 시 자동 치환 + 날짜 패턴 없으면 auto RRULE.
- ~~복용 이벤트 반복 설정 없음~~ → 반복 토글 + 시작/종료일 추가.
- ~~복용 이벤트 사진 첨부 없음~~ → `PhotosPicker`(앨범) + `CameraPicker`(카메라) + `EventImageStore`.
- ~~월 이름 긴 경우(September 등) 여러 줄로 깨짐~~ → 헤더를 `MONTH YEAR` 단일 텍스트로 통합, `minimumScaleFactor` 적용.
- ~~상단 헤더 레이아웃 불명확~~ → Row1(유틸) / Row2(월헤더) / Row3(주간스트립) 3단 구조로 재설계.
- ~~주간 날씨/이벤트 현황 미표시~~ → `WeekStripView` + `WeatherService`(Open-Meteo) 추가. 날씨 미조회 시 이모지 대체.
- ~~＋ 버튼 길게 누르기 미지원~~ → `oneTimeModeOverride` + `confirmationDialog`로 1회성 입력 방식 변경 지원.
- ~~이벤트 복사 없음~~ → 컨텍스트 메뉴 "복사(내용포함/제외)" + `EventCopySheet` (DatePicker + 저장).
- ~~온보딩 4단계~~ → 7단계 (다이어리·할일·개인이벤트 상세, 웹툰 일러스트레이션, 복용 사진 강조).
- ~~버전 업데이트 시 온보딩 재노출 없음~~ → `lastSeenVersion` 추적, 업데이트·재설치 시 자동 재노출.
- ~~diary 제목 기본값 없음~~ → 에디터 열 때 `[yyyy.MM.dd]😀수고했어요.` 자동 채움 (이벤트 수 기반 이모지).
- ~~날씨 WeatherKit 미사용~~ → WeatherKit 우선 + Open-Meteo 폴백; entitlements 및 `NSLocationWhenInUseUsageDescription` 추가.
- ~~테마 전환 없음~~ → `AppColorScheme`(system/dark/light) 롤링 버튼, `SettingsView` 상단 내비게이션 바에 배치, `preferredColorScheme` 앱 전체 반영.

- ~~일정목록 날씨/음력 별도 라인~~ → 음력+날씨(아이콘+온도) 단일 라인으로 통합.
- ~~SCHEDULE 헤더 텍스트~~ → 제거.
- ~~날씨 온도 미표시~~ → `WeatherService.dailyTemperature` 추가; WeatherKit `day.highTemperature` / Open-Meteo `temperature_2m_max` 조회, 캐시키 `wc.dailyTemperature`.
- ~~약속 반복일정 UI 불필요~~ → appointment 카테고리 반복 섹션 제거.
- ~~편집 저장 후 즉시 화면 미갱신~~ → `sheet(item:onDismiss:)`로 캐시 무효화·재로드 추가.
- ~~이벤트 탭 시 편집 진입 없음~~ → 단순 탭으로 `EventEditSheet` 즉시 진입, 컨텍스트 메뉴는 복사·삭제만 유지.
- ~~메모 블럭 고정 높이~~ → `TextEditor` 최소 80pt, 내용 줄 수 기준 자동 확장 (`notesEditorHeight` computed).
- ~~날씨·이모지 매번 조회~~ → `WeatherCondition: String, Codable, Equatable` + UserDefaults 캐시 (`wc.dailyWeather`); 초기 로드 시 캐시 선표시 → 변경 시만 갱신·저장. 이벤트 갯수도 `cachedEventCounts`(`wc.eventCountCache`) 로 앱 시작 즉시 이모지 표시.

**잔여**
- `EventStoreManager` 가 `hasAccess` 변경을 구독하지 않음 → 권한 늦은 허용 시 화면 미갱신.
- 데드코드: `ViewController.swift`, `Main.storyboard` (pbxproj 동기화 그룹 예외 필요해 보류).

---
다음 단계: 검토·수정 후 `/wise-dev-standard:recommend` 로 스택·도메인 추천을 이어가세요.
