# PRD — Wise-Calendar (위클리 플래너 iOS 앱)

> One-Page PRD · 애자일 · 작성일 2026-06-11 · 최종수정 2026-06-26 · 도메인: ict-saas (소비자 iOS 앱)
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
- **히어로 영역 더블탭** → 이벤트 추가 에디터 열기. **히어로 영역 롱프레스(0.6s)** → 입력 방식 선택 팝업 (`confirmationDialog`).
- 상단 헤더: `< 월 >`(월 이동) + `[Today]`(선택일이 오늘 아닐 때만) + `< 연 >`(연 이동). §3.1 참조.
- 하단 미니 달력: 현재월 + 다음월 2개.
- 색상 테마(`CalendarTheme`) — 연도/연 이동 동일 색, 강조·월·주말색 분리, `.default` 주입.
- EventKit 연동: 캘린더 접근 요청, 일자별 이벤트 조회·캐시 (`HH:mm 제목`).
- 일자별 이벤트 점 표시, 선택일 SCHEDULE 리스트 (중복 없음).
- **이벤트 갯수 색상**: 하단 미니 달력 날짜 숫자 + 히어로 날짜 숫자에 이벤트 갯수에 따른 무지개 7단계 색상 적용.
  `0=기본`, `1=노(yellow)`, `2=주(orange)`, `3=초(green)`, `4=남(navy)`, `5=보(purple)`, `6+=빨(red)`.
  히어로 숫자는 동일 색상을 opacity 0.28 로 적용(워터마크 효과 유지).
- **이벤트 수정/삭제**: 등록된 이벤트 **탭** → 편집(`EventEditSheet`) 즉시 진입. 롱프레스(컨텍스트 메뉴) → 복사·삭제.

**확장 (다음 범위 — 기능 확장 + 리팩터/표준화)**
- 위클리 뷰 (스케치의 WEEKLY PLAN: 주차별 #1~#2 슬롯).
- 연간 뷰 / 빠른 연·월 점프(스케치의 다이얼 선택).
- 다크/브랜드 테마 적용(`CalendarTheme` 교체) — 기반 마련됨.
- 가정: 데이터는 기기 EventKit 만 사용, 별도 백엔드/계정 없음.

### 3.1 헤더/테마 UI 사양 (2026-06-26 반영)

1. **상단 유틸리티 바** (Row 1) — `⚙` (왼쪽) | `[Today]`(선택일 오늘 아닐 때) + `< 년 >` (중앙) | `🔍` + `＋` (오른쪽).
2. **월 헤더** (Row 2) — `<` | `MONTH YEAR` | `>` 전체 너비.
3. **주간 스트립** (Row 3) — 선택일이 포함된 주(일~토) 7셀. 각 셀: 요일 약어 + 날짜 숫자(원형 강조) + 날씨 아이콘.
   - 날씨 아이콘: SF Symbol + `WeatherCondition.tintColor`.
   - 날씨 미조회 시 이모지 대체: 0~1개 이벤트 = 😀, 2~3개 = 😊, 4개 이상 = 🤯.
   - 날씨 데이터: WeatherKit(Apple) 우선 + Open-Meteo(무료·무키) 폴백 + CoreLocation.
   - **일별 강제 갱신**: 앱 실행 시 마지막 갱신일(`wc.lastFetchDate`) 비교 → 오늘 날짜와 다르면 `hasFetched` 리셋 → 항상 당일 최신 날씨 조회. 조회 성공 시 갱신일 저장.
   - **좌우 스와이프**: 좌 스와이프 → 다음 주(+7일), 우 스와이프 → 이전 주(-7일). 임계값 50pt, 러버밴드(0.25×) 피드백.
4. **Today 버튼** — Row 1 중앙. 선택일이 당일 아닐 때만 노출.
5. **연 이동** — `<`(이전년)·`>`(다음년). 버튼·숫자 색 = `CalendarTheme.year`.
6. **월 이동** — Row 2 좌우 chevron.
7. **하단 달력** — 현재월·다음월 2개를 좌우 배치. 좌우 스와이프로 월 이동.
8. **＋ 버튼 동작**:
   - **탭** → 현재 설정 플래너 모드로 에디터 열기.
   - **롱프레스(0.6s)** → `confirmationDialog`로 다른 입력 방식 목록 노출 (`oneTimeModeOverride`). `addButtonLongPressed` 플래그로 롱프레스 후 버튼 탭 이벤트 억제 → 팝업이 즉시 닫히지 않음.
9. **히어로 영역 동작**:
   - **더블탭** → 에디터 열기 (현재 모드).
   - **롱프레스(0.6s)** → 입력 방식 선택 팝업 (+ 버튼 롱프레스와 동일).
10. **일정목록(SCHEDULE 영역) 정보 바** — 선택일 기준 단일 라인: **좌측** 음력 날짜 · **우측** 날씨 아이콘 + 일 최고기온.
11. **비밀 약속 흐린 표시**: 제목이 `[비밀]`로 시작하는 이벤트는 일정 목록에서 `.opacity(0.25)` 처리.

### 3.2 설정 · 플래너 모드 · 템플릿 · 온보딩 (2026-06-26 업데이트)

> 용어: "사용자 테마"(입력 방식) = **플래너 모드**(`PlannerMode`), 색 테마(`CalendarTheme`)와 별개.

**(A) 앱 설정** — 일반 캘린더 앱 준용. 헤더 톱니 버튼 → `SettingsView`.
- (1) **연동** — iOS 시스템 계정 기반. EventKit이 시스템에 추가된 Google/iCloud 캘린더 소스를 노출.
- (2) **사용자 테마(플래너 모드)** — diary / todo(업무 이벤트) / personalEvent 중 택1.
- (3) **알림** — 로컬 알림(UNUserNotificationCenter) on/off + 권한 요청/가이드.
- (4) **화면 테마(앱 색상 모드)** — system·dark·light 롤링 전환.

**(B) 플래너 모드별 이벤트 추가 UX**

- **diary(일기)** — 추가 시 전체화면 에디터(`TextEditor`). 에디터 열 때 시각=`startDate`, 저장 시각=`endDate`. 경과 시간 `mm:ss` 실시간 표시.

- **todo(업무 이벤트)** — 템플릿 선택 기반 입력. 카테고리 피커 없이 `workEvent` 템플릿 직접 표시.
  - **할 일** (`isTodo=true`): 체크리스트 스타일. 단일 작업 제목 + Due Date `DatePicker`. notes 에 `"- [ ] 제목"` 인코딩.
    - **Due Date 필수**: 기본값 = 선택일 23:59.
    - **기한 초과 적색 표시**: `isTodo && startDate < now && notes 에 "- [ ]" 존재` → 캘린더 뷰 적색 표시 (`isOverdue` 플래그).
  - **회의·세미나/컨퍼런스·회식** (`isTodo=false`): 시작/종료 시간 `DatePicker` + 장소 텍스트 입력 → EKEvent.location.

- **personalEvent(개인 이벤트)** — 추가 시 카테고리 선택(복용·약속·고정/반복) → 템플릿 선택 → 프리필 입력.
  - **복용(medication)**: 아침/점심/저녁/임시긴급 4개 템플릿. 아침(7h)/점심(12h)/저녁(18h) 프리셋 버튼 + 직접 입력. 반복 토글(yearly). **사진/카메라** 첨부 — `PhotosPicker`(앨범) 또는 `UIImagePickerController`(카메라), `EventImageStore`에 JPEG 저장.
  - **약속(appointment)**: 시작/종료 시각 `DatePicker` + **장소** 텍스트 입력 → EKEvent.location. 템플릿: 연인과 약속·친구와 약속·동호회/이벤트·비밀 약속. **비밀 약속**: titleFormat=`"[비밀] 약속"` → 일정 목록에서 opacity 0.25 흐린 표시.
  - **고정/반복(fixed)**: 시작/종료 시각 + 반복 토글(yearly `EKRecurrenceRule`). 날짜 패턴 없으면 자동 yearly RRULE.

**(B-2) 개인이벤트 타이틀 날짜 패턴 치환**

| 패턴 | 예시 (2026-03-08 기준) |
|------|------------------------|
| `yyyy-mm-dd` | `2026-03-08` |
| `yyyy/mm/dd` | `2026/03/08` |
| `yy-mm-dd` | `26-03-08` |
| `yyyy.mm.dd` | `2026.03.08` |
| `dd-mm-yyyy` | `08-03-2026` |
| `d###` | `067` (연중 일련일, 3자리) |

패턴 조합 가능: `[정기작업] (d###) yyyy-mm-dd` → `[정기작업] (067) 2026-03-08`

**자동 RRULE**: 날짜 패턴 없는 고정/반복 항목은 저장 시 자동 yearly `EKRecurrenceRule` 생성. 명시적 반복 토글로도 제어 가능.

**(C) 템플릿(`EventTemplate`)** — UserDefaults(JSON) 영속. 키: `templates.v3`.

- **카테고리**: `workEvent`(업무 이벤트 모드 전용), `medication`(복용), `appointment`(약속), `fixed`(고정/반복).
- **isTodo 플래그**: `EventTemplate.isTodo: Bool` — 체크리스트 스타일 저장 여부. 기존 저장 데이터 하위호환 (`decodeIfPresent → false`).
- **시드 템플릿(v3)**:

| 카테고리 | 템플릿 | 기본 시각 |
|---------|--------|----------|
| workEvent | 할 일 (isTodo=true) | 09h / 60m |
| workEvent | 회의 | 10h / 60m |
| workEvent | 세미나/컨퍼런스 | 09h / 480m |
| workEvent | 회식 | 18h / 180m |
| medication | 아침 약 복용 | 07h / 0m |
| medication | 점심 약 복용 | 12h / 0m |
| medication | 저녁 약 복용 | 18h / 0m |
| medication | 임시/긴급 복용 | 09h / 0m |
| appointment | 연인과 약속 | 19h / 120m |
| appointment | 친구와 약속 | 14h / 120m |
| appointment | 동호회/이벤트 | 10h / 120m |
| appointment | 비밀 약속 (`[비밀] 약속`) | 19h / 120m |
| fixed | 알레르기 약 복용 (d###) | 09h / 0m |
| fixed | 약 복용 yyyy-mm-dd | 09h / 0m |
| fixed | [정기작업] (d###) yyyy-mm-dd | 09h / 0m |

**(D) 온보딩/인트로(`OnboardingView`)**
- 노출 조건: 최초 설치·재설치 또는 버전 업데이트 또는 DEBUG 빌드 매회.
- 4단계: 소개+모드선택 → 일기+업무이벤트 → 개인이벤트 → 연동+알림.
  완료 시 `onboardingCompleted=true`, `lastSeenVersion=currentBundleVersion`.

**(E) 이벤트 복사(`EventCopySheet`)**
- 컨텍스트 메뉴 "복사(내용포함)" / "복사(내용제외)": 기존 이벤트를 다른 날짜로 복제.
- `EventCopyConfig(id, item, includeNotes)` → `EventCopySheet`: DatePicker(목표 날짜) + 제목·시간·메모 Form → 저장 시 `addEvent`.

**(F) 이벤트 수정(`EventEditSheet`)**
- 제목·시간·장소·메모 편집. **시작 시간 변경 시 종료 시간 자동 조정**: 원본 duration(`originalDuration`) 유지. 사용자가 별도로 종료 시간을 변경하는 것도 허용.

## 4. How — 접근

- 플랫폼: iOS (SwiftUI + EventKit + UserNotifications + WeatherKit). 단일 앱, 서버 없음.
- 진입점: `SceneDelegate` → `UIHostingController(RootView())`.
  `RootView` = 온보딩 노출 분기(`AppSettings`) 후 `CalendarView`.
- 영속화: `AppSettings`·`EventTemplate` = UserDefaults(JSON). 일정 본문 = EKEvent.notes 인코딩.
- 순수 로직은 `CalendarLogic`/`PlannerLogic`으로 추출 → 단위 테스트.
- 가정: 의존성 매니저 없음, Xcode 프로젝트 단독 빌드.

## 5. Success — 성공 기준 / 검증

| 기준 | 측정 |
|------|------|
| 빌드 성공 | `xcodebuild` 경고/에러 없이 빌드 |
| 동작 완성도 | 핵심 화면 무크래시 동작 |
| EventKit 연동 | 접근 허용/거부 분기, 이벤트 조회·표시 정상 |
| 테스트 | 그리드·dateKey·day-of-year·모드/템플릿 인코딩 단위 테스트 통과 |
| 설정/모드 | 설정 영속, 플래너 모드별 추가 UX 분기 |
| 템플릿 v3 | workEvent/medication/appointment/fixed 시드, isTodo 체크리스트 동작 |
| 온보딩 | 최초 실행/DEBUG 매회 노출, 완료 후 미노출(릴리스) |
| diary 시간 | 에디터 오픈 시각=startDate, 저장 시각=endDate 자동 기록 |
| 업무이벤트 할 일 | Due Date 필수, 기한 초과 적색 표시, isTodo 인코딩 |
| 업무이벤트 회의/회식 | 시작/종료 시간 + 장소 저장 |
| medication 시간 | 프리셋 버튼 + 직접 입력, 사진 첨부 |
| appointment 시간+장소 | 시작·종료 DatePicker + 장소 → EKEvent.location |
| 비밀 약속 | [비밀] prefix → opacity 0.25 표시 |
| fixed 반복 | 시작·종료 + yearly EKRecurrenceRule |
| 수정 시간 자동조정 | EventEditSheet 시작 시간 변경 시 종료 시간 원본 간격 유지 |
| 날씨 일별 갱신 | 앱 실행 시 날짜 비교 → 새 날이면 무조건 재조회 |
| 롱프레스 팝업 | 0.6s, 팝업 뜬 후 즉시 닫힘 없음 |
| (확장 목표) 출시 | 메모리·접근성·App Store 심사 가이드 충족 |

## 6. 알려진 이슈 / 리스크 (코드 분석)

**해소됨**
- ~~SCHEDULE 메모 중복 렌더~~ → nested HStack 제거.
- ~~단위 테스트 타깃 부재~~ → `CalendarTests` 신설, 24 케이스 통과.
- ~~월 그리드 SUN-first 정렬 어긋남~~ → `CalendarLogic.monthGrid` 교정.
- ~~좌측 하단 달력이 전월 표시~~ → `selectedDate` 변경 시 `currentDate` 월 동기화.
- ~~연 다를 때 Today 버튼 미표시~~ → `changeYear` 에서 `selectedDate` 도 갱신.
- ~~이벤트 시간 정보 없음~~ → `CalendarEventItem.displayTitle("HH:mm 제목")`.
- ~~todo 기한·overdue 표시 없음~~ → `isOverdue` 플래그, 캘린더 뷰 적색 표시.
- ~~diary 시간 자동 기록 없음~~ → editorOpenTime=start, saveTime=end.
- ~~medication/appointment/fixed 시간 설정 없음~~ → 카테고리별 시간 UI.
- ~~이벤트 수정·삭제 없음~~ → `EventEditSheet`, `deleteEvent`/`updateEvent`.
- ~~날짜 색상 단일색~~ → `eventCountColor()` 무지개 7단계.
- ~~미니 달력 색상 클릭 전 미표시~~ → `fetchEventsForMonth` 월 단위 프리패치.
- ~~등록 이벤트 수정·삭제 반영 안됨~~ → 동기 직접 할당 수정.
- ~~개인이벤트 타이틀 날짜 패턴 없음~~ → `PlannerLogic.substituteTitlePatterns`.
- ~~복용 이벤트 사진 첨부 없음~~ → `PhotosPicker` + `CameraPicker` + `EventImageStore`.
- ~~주간 날씨/이벤트 현황 미표시~~ → `WeekStripView` + `WeatherService`.
- ~~＋ 버튼 길게 누르기 미지원~~ → `oneTimeModeOverride` + `confirmationDialog`.
- ~~이벤트 복사 없음~~ → `EventCopySheet`.
- ~~날씨 WeatherKit 미사용~~ → WeatherKit 우선 + Open-Meteo 폴백.
- ~~테마 전환 없음~~ → `AppColorScheme` 롤링 버튼.
- ~~날씨 온도 미표시~~ → `WeatherService.dailyTemperature`.
- ~~이벤트 탭 시 편집 진입 없음~~ → 단순 탭 → `EventEditSheet`.
- ~~날씨·이모지 매번 조회~~ → `WeatherCondition: Codable` + UserDefaults 캐시.
- ~~히어로 영역 롱프레스 미지원~~ → 0.6s 롱프레스 → 입력 방식 선택 팝업.
- ~~롱프레스 후 팝업 즉시 닫힘~~ → `addButtonLongPressed` 플래그로 버튼 탭 이벤트 억제.
- ~~날씨 캐시 날짜 갱신 미처리~~ → `wc.lastFetchDate` 저장 + 앱 실행 시 날짜 비교 → 새 날 무조건 재조회.
- ~~플래너 모드 템플릿 구조 미정리~~ → PlannerMode.todo → "업무 이벤트", workEvent 카테고리 추가, 템플릿 v3 재구성.
- ~~할 일 체크리스트 업무이벤트 에서 미지원~~ → `EventTemplate.isTodo` 플래그 + 체크리스트 due-date 에디터.
- ~~비밀 약속 표시 구분 없음~~ → `[비밀]` prefix → `.opacity(0.25)` 흐린 표시.
- ~~이벤트 수정 시 시작 시간 변경 후 종료 시간 미자동 조정~~ → `EventEditSheet.originalDuration` + onChange 자동 조정.

**잔여**
- `EventStoreManager` 가 `hasAccess` 변경을 구독하지 않음 → 권한 늦은 허용 시 화면 미갱신.
- 데드코드: `ViewController.swift`, `Main.storyboard` (pbxproj 동기화 그룹 예외 필요해 보류).

---
다음 단계: 검토·수정 후 `/wise-dev-standard:recommend` 로 스택·도메인 추천을 이어가세요.
