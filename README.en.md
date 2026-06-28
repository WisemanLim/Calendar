# Wise Calendar

[한국어](README.md) | English

A personal iOS calendar + planner app. Large date display for intuitive scheduling, with three planner modes: diary, work event, and personal event. Includes weather integration (WeatherKit + Open-Meteo fallback), template-based event creation, secret appointment dimming, and a rolling system/dark/light theme toggle.

- **Profile**: ios-swiftui
- **Domain**: ict-saas (consumer, serverless)
- **PRD**: [.docs/PRD.md](.docs/PRD.md)

---

## Architecture / Directory

```
Wise-Calendar/
├── Calendar/
│   ├── AppDelegate.swift           App entry point
│   ├── SceneDelegate.swift         Loads RootView
│   ├── RootView.swift              Onboarding gate → CalendarView
│   │
│   ├── CalendarView.swift          Main screen (date hero + header + mini calendar)
│   ├── CalendarLogic.swift         Pure grid functions (SUN-first, 42 cells)
│   ├── CalendarTheme.swift         Color theme struct
│   │
│   ├── EventStoreManager.swift     EventKit read/write + CalendarEventItem + cache
│   ├── AppSettings.swift           UserDefaults-backed settings
│   ├── PlannerMode.swift           diary / todo / personalEvent
│   ├── PlannerLogic.swift          Pure functions (dayOfYear, fixedTitle, encodeTodos)
│   ├── EventTemplate.swift         EventTemplate Codable + TemplateStore
│   ├── NotificationManager.swift   UNUserNotificationCenter (9am reminders)
│   │
│   ├── WeatherService.swift        Weather (WeatherKit primary / Open-Meteo fallback)
│   │
│   ├── EventEditorView.swift       Mode-specific event input UI (time, location, repeat)
│   ├── SettingsView.swift          Settings (integration · theme · notifications · color scheme)
│   └── OnboardingView.swift        4-step onboarding TabView
│
├── Calendar/Assets.xcassets/
│   └── AppIcon.appiconset/         App icon (Aug 31, 1024×1024)
│
├── CalendarTests/
│   ├── CalendarLogicTests.swift    9 unit tests
│   └── PlannerLogicTests.swift     15 unit tests
│
├── test/
│   ├── dev-env/                    Dev-env test records
│   └── impl/{1..4}/               Per-iteration scenario + result
│
└── .docs/PRD.md                    One-Page PRD
```

### Key Components

| File | Responsibility |
|------|----------------|
| `RootView` | Onboarding gate (`shouldShowOnboarding` → `.fullScreenCover`) |
| `CalendarView` | Date hero (double-tap/long-press = add event), header, 2-month mini calendar, overdue in red, event edit/delete, rainbow colors. **Secret appointment**: events with `[비밀]` prefix shown at `.opacity(0.25)`. **Long-press(0.6s)**: `addButtonLongPressed` flag prevents popup from immediately closing. **Pull-to-refresh**: drag schedule list down 60pt+ → weather + events resync (`simultaneousGesture` vertical-direction detection) |
| `CalendarLogic` | 42-cell grid, `dateKey(yyyy-MM-dd)`, SUN-first alignment |
| `CalendarTheme` | `accent/month/year/todayTint/navBackground/sunday/saturday`; `.default` preset |
| `CalendarEventItem` | Display value type — `displayTitle("HH:mm title")`, `isOverdue`, `isTodo` |
| `EventStoreManager` | `EKEventStore` wrapper, `[String:[CalendarEventItem]]` cache, `addEvent` / `updateEvent` / `deleteEvent` / `fetchEvent` |
| `AppSettings` | UserDefaults: `plannerMode`, `notificationsEnabled`, `onboardingCompleted`, `enabledCalendarIDs`, `lastSeenVersion`, `appColorScheme` |
| `AppColorScheme` | Rolling color scheme enum — `system`/`dark`/`light`; `icon` (SF Symbol), `colorScheme: ColorScheme?`, `next` cycling property |
| `WeatherService` | WeatherKit (primary) → Open-Meteo fallback. `dailyWeather[yyyy-MM-dd]` + `dailyTemperature[yyyy-MM-dd]` Published. **Daily forced refresh**: `wc.lastFetchDate` stored — on app launch, if date differs from today, `hasFetched` resets and re-fetches unconditionally |
| `eventDayEmoji()` | Event count → face emoji: 0–1=😀, 2–3=😊, 4+=🤯 (WeekStrip fallback when no weather) |
| `PlannerMode` | `diary` · `todo` (업무 이벤트 / Work Event) · `personalEvent` |
| `PlannerLogic` | `dayOfYear`, `fixedTitle("[#ddd] …")`, `encodeTodos`, `decodeTodos` |
| `EventTemplate` | `workEvent`(todo mode only)·`medication`·`appointment`·`fixed` categories. `isTodo: Bool` flag for checklist-style save. `defaultStartHour`, `defaultDurationMinutes` |
| `TemplateStore` | UserDefaults JSON persistence, key `templates.v3`, 15 seed templates, `update()` |
| `EventEditSheet` | Edit sheet — title, time, location, notes, `updateEvent`. **Auto end-time adjustment**: changing start time shifts end time by original duration (`originalDuration`) |
| `EventCopySheet` | Copy-event sheet — DatePicker (target date) + title/time/notes preview form, calls `addEvent` |
| `eventCountColor()` | Event count → 7-level rainbow: 0=default, 1=yellow, 2=orange, 3=green, 4=navy, 5=purple, 6+=red |
| `MedicationPreset` | Morning(7h)/Lunch(12h)/Evening(18h)/Custom — medication time presets |
| `EventImageStore` | Photo persistence for medication events — Documents JPEG + UserDefaults eventID map |
| `CameraPicker` | `UIImagePickerController` camera wrapper (`UIViewControllerRepresentable`) |
| `PlannerLogic.substituteTitlePatterns` | Title date-pattern substitution (`yyyy-mm-dd`, `d###`, 6 patterns) |
| `NotificationManager` | `UNUserNotificationCenter`, 9am local notification scheduling |

---

## Prerequisites

| Tool | Minimum Version |
|------|-----------------|
| macOS | 15 Sequoia+ |
| Xcode | 16+ |
| iOS SDK | 17+ |
| Simulator | iPhone 17 (or physical device) |

No external dependencies (CocoaPods/SPM). Open the Xcode project and build immediately.

---

## Environment Setup

Serverless app — no `.env` files or API keys required.

**Info.plist permissions** (pre-configured):
- `NSCalendarsUsageDescription` — EventKit calendar read/write
- `NSRemindersUsageDescription` — Reminders access
- `NSLocationWhenInUseUsageDescription` — Current location for weather data
- `NSCameraUsageDescription` — Photo attachment for medication events
- `NSPhotoLibraryUsageDescription` — Album photo attachment

**WeatherKit** (Apple Developer Portal required):
1. [developer.apple.com](https://developer.apple.com) → Certificates, Identifiers & Profiles
2. Identifiers → `com.wiseman.calendar` → enable **WeatherKit** checkbox → Save
3. Rebuild in Xcode (`Calendar/Calendar.entitlements` already included)

> If WeatherKit is not activated, the app automatically falls back to Open-Meteo (no API key needed) — weather icons still display normally.

**Google Calendar integration** (no OAuth required):
1. iPhone → Settings → Calendar → Accounts → Add Account → Google
2. The app automatically surfaces those calendars via EventKit on next launch

**Notifications**: `UNUserNotificationCenter.requestAuthorization()` called at runtime.

---

## Running the App

### A. Xcode GUI

```
1. Open Calendar.xcodeproj
2. Confirm Scheme: "Calendar"
3. Select simulator: "iPhone 17" (or connected device)
4. ▶ Run (⌘R)
```

### B. xcodebuild CLI

```bash
# Build only
xcodebuild build \
  -project Calendar.xcodeproj \
  -scheme Calendar \
  -destination 'platform=iOS Simulator,name=iPhone 17'

# Build + test
xcrun simctl shutdown all    # prevent simulator flake
xcodebuild test \
  -project Calendar.xcodeproj \
  -scheme Calendar \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

---

## Screen Map

| Screen | Entry Point | Description |
|--------|-------------|-------------|
| `OnboardingView` | App launch (Release: first install / reinstall / version update; DEBUG: always) | 4 steps: intro+mode select → diary+todo → personal event → integration+notifications |
| `CalendarView` | Default after onboarding | Date hero + 3-row header (util bar / month nav / week strip with weather + left/right swipe ±7 days) + 2-month mini calendar, overdue in red; schedule list shows lunar date + weather icon (temperature) on same line; pull schedule list down to refresh weather + events |
| `EventEditorView` | `+` button tap | Mode-specific event input (time, location, repeat); diary pre-fills `[yyyy.MM.dd]😀수고했어요.` |
| `SettingsView` | `⚙` button tap | Calendar integration · planner mode · notifications · color scheme (system/dark/light rolling toggle) |

---

## Feature Examples

### Event storage and time handling by planner mode

| Mode | Time Handling | EKEvent.notes format |
|------|---------------|----------------------|
| `diary` | Editor open time = startDate, save time = endDate | Free text |
| `todo/할 일` (`isTodo=true`) | due-date DatePicker → startDate = endDate = deadline | `"- [ ] Item"` (checklist) |
| `todo/회의·세미나·회식` (`isTodo=false`) | Start + end DatePicker + location → EKEvent.location | nil |
| `personalEvent/medication` | Morning(7h)/Lunch(12h)/Evening(18h)/Emergency preset or custom. Repeat toggle + **Individual registration toggle (default ON)**: ON→per-date individual events, OFF→yearly RRULE. Photo/camera. | nil |
| `personalEvent/appointment` | Start + end DatePicker + location. **Secret**: `[비밀]` prefix → `.opacity(0.25)` display | nil |
| `personalEvent/fixed` | Start + end + repeat toggle + **Individual registration toggle (default ON)**: ON→per-date individual events (pattern substituted), OFF→yearly RRULE | nil |

### Overdue display (red)

```swift
// CalendarEventItem.isOverdue condition
let isOverdue = isTodo && event.startDate < now && notes.contains("- [ ]")
// → Text and dot displayed in red in CalendarView
```

### [#ddd] Annual fixed events

```swift
let title = PlannerLogic.fixedTitle(dayOfYear: 162, title: "Allergy medication(-/-)")
// → "[#162] Allergy medication(-/-)"
```

### Medication preset — save default time

```swift
// Tap "Save as default time"
templateStore.update(template.with(defaultStartHour: 7))
// → Persisted to UserDefaults; next selection auto-applies 07:00
```

### Appointment location

```swift
eventStore.addEvent(title: "Date", notes: nil,
    startDate: start, endDate: end,
    location: "Gangnam Station Starbucks")
// → EKEvent.location → iOS Calendar shows map link
```

### Notification scheduling

```swift
NotificationManager.shared.scheduleEventReminder(title: "Meeting", on: date)
// UNCalendarNotificationTrigger: 09:00 on the specified date
```

### Event copy (context menu)

Long-press any event in the schedule list to see "Copy (with notes)" / "Copy (without notes)".
`EventCopySheet` opens with a DatePicker to pick the target date; tapping Save calls `addEvent`.

### Diary default title

When opening the diary editor, the title is pre-filled based on the current event count for that day:

```
[2026.06.11]😀수고했어요.   (0–1 events)
[2026.06.11]😊수고했어요.   (2–3 events)
[2026.06.11]🤯수고했어요.   (4+ events)
```

### Color scheme toggle

Tap the icon in the Settings navigation bar to cycle: **system** (`desktopcomputer`) → **dark** (`moon.fill`) → **light** (`sun.max.fill`).
Persisted to UserDefaults via `AppSettings.appColorScheme`. Applied app-wide via `.preferredColorScheme()` in `RootView`.

### WeatherKit condition mapping

| WeatherKit | Internal enum | SF Symbol |
|-----------|---------------|-----------|
| `.clear`, `.mostlyClear` | `.clear` | `sun.max.fill` |
| `.partlyCloudy`, `.sunShowers` | `.partlyCloudy` | `cloud.sun.fill` |
| `.cloudy`, `.mostlyCloudy` | `.overcast` | `cloud.fill` |
| `.foggy`, `.haze` | `.fog` | `cloud.fog.fill` |
| `.drizzle` | `.drizzle` | `cloud.drizzle.fill` |
| `.rain`, `.freezingRain` | `.rain` | `cloud.rain.fill` |
| `.heavyRain` | `.heavyRain` | `cloud.heavyrain.fill` |
| `.snow`, `.heavySnow`, `.blizzard` | `.snow` | `snowflake` |
| `.thunderstorms`, `.strongStorms` | `.thunderstorm` | `cloud.bolt.rain.fill` |

`day.highTemperature` is used for daily temperature data. Open-Meteo fallback uses the `temperature_2m_max` parameter.

```swift
for day in forecast.forecast {
    let condition = WeatherCondition.from(wkCondition: day.condition)
    let tempCelsius = Int(day.highTemperature.converted(to: .celsius).value.rounded())
}
```

---

## App Icon

`Calendar/Assets.xcassets/AppIcon.appiconset/AppIcon.png` (1024×1024)

- Red header with white bold "Aug"
- 9 spiral binding rings at top
- Large "31" (August 31, 2026)
- Page fold effect at bottom-right corner

---

## Testing

```bash
xcrun simctl shutdown all
xcodebuild test \
  -project Calendar.xcodeproj \
  -scheme Calendar \
  -destination 'platform=iOS Simulator,name=iPhone 17'
# → Executed 29 tests, with 0 failures
```

| Test Class | Count | Coverage |
|------------|-------|----------|
| `CalendarLogicTests` | 9 | dateKey format, 42-cell grid, SUN-first alignment, event injection |
| `PlannerLogicTests` | 20 | dayOfYear ×5, fixedTitle ×4, encodeTodos ×4, EventTemplate ×2, title patterns ×5 |



Test records: [impl/1](test/impl/1/result.md) · [impl/2](test/impl/2/result.md) · [impl/3](test/impl/3/result.md) · [impl/4](test/impl/4/result.md)

---

## Troubleshooting

### Simulator "Busy / FBSOpenApplicationServiceErrorDomain Code=1"

```bash
xcrun simctl shutdown all
```

### "No such module 'Calendar'" in XCTest target

Xcode → CalendarTests target → Build Settings → `TEST_HOST` must be  
`$(BUILT_PRODUCTS_DIR)/Calendar.app/Calendar`

### Google Calendar not showing in the app

1. Confirm Google account added: Settings → Calendar → Accounts
2. In-app Settings (⚙) → "캘린더 연동" — check the calendar is toggled on
3. Confirm EventKit access: Settings → Privacy & Security → Calendars → Wise Calendar

### Notifications not arriving

1. Settings → Notifications → Wise Calendar → Allow
2. In-app Settings (⚙) → Notifications toggle ON
3. DEBUG build: onboarding shown every launch — tap "Allow Notifications" on step 7

---

## Next Steps (PRD Backlog)

- [ ] Widget (iOS WidgetKit) — today's events at a glance
- [ ] iCloud sync — multi-device planner data
- [ ] Custom themes — user-defined `CalendarTheme` color palette UI
- [ ] App Store release — Fastlane → TestFlight → review submission
