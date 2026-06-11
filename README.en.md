# Wise Calendar

[한국어](README.md) | English

A personal iOS calendar + planner app. Large date display for intuitive scheduling, with three planner modes: diary, to-do, and personal event.

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
│   ├── EventEditorView.swift       Mode-specific event input UI (time, location, repeat)
│   ├── SettingsView.swift          Settings (integration · theme · notifications)
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
| `CalendarView` | Date hero (double-tap/long-press = add event), header, 2-month mini calendar, overdue in red, event edit/delete, rainbow colors |
| `CalendarLogic` | 42-cell grid, `dateKey(yyyy-MM-dd)`, SUN-first alignment |
| `CalendarTheme` | `accent/month/year/todayTint/navBackground/sunday/saturday`; `.default` preset |
| `CalendarEventItem` | Display value type — `displayTitle("HH:mm title")`, `isOverdue`, `isTodo` |
| `EventStoreManager` | `EKEventStore` wrapper, `[String:[CalendarEventItem]]` cache, `addEvent` / `updateEvent` / `deleteEvent` / `fetchEvent` |
| `AppSettings` | UserDefaults: `plannerMode`, `notificationsEnabled`, `onboardingCompleted`, `enabledCalendarIDs` |
| `PlannerMode` | `diary` · `todo` · `personalEvent` |
| `PlannerLogic` | `dayOfYear`, `fixedTitle("[#ddd] …")`, `encodeTodos`, `decodeTodos` |
| `EventTemplate` | `medication/appointment/fixed` categories, `defaultStartHour`, `defaultDurationMinutes` |
| `TemplateStore` | UserDefaults JSON persistence, 7 seed templates, `update()` |
| `EventEditSheet` | Edit sheet for registered events — title, time, location, notes, calls `updateEvent` |
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
| `OnboardingView` | App launch (Release: once / DEBUG: always) | Guide → mode select → Google → notifications |
| `CalendarView` | Default after onboarding | Date hero + header + mini calendar, overdue in red |
| `EventEditorView` | `+` button tap | Mode-specific event input (time, location, repeat) |
| `SettingsView` | `⚙` button tap | Calendar integration · planner mode · notifications |

---

## Feature Examples

### Event storage and time handling by planner mode

| Mode | Time Handling | EKEvent.notes format |
|------|---------------|----------------------|
| `diary` | Editor open time = startDate, save time = endDate | Free text |
| `todo` | due-date DatePicker → startDate = endDate = deadline | `"- [ ] Item\n- [x] Done"` |
| `personalEvent/medication` | Morning(7h)/Lunch(12h)/Evening(18h) preset or custom. Yearly repeat toggle. Photo/camera attachment. | nil |
| `personalEvent/appointment` | Start + end DatePicker + location → EKEvent.location | nil |
| `personalEvent/fixed` | Start + end time + yearly EKRecurrenceRule | nil |

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
3. DEBUG build: onboarding shown every launch — tap "Allow Notifications" on step 4

---

## Next Steps (PRD Backlog)

- [ ] Widget (iOS WidgetKit) — today's events at a glance
- [ ] iCloud sync — multi-device planner data
- [ ] Custom themes — user-defined `CalendarTheme` color palette UI
- [ ] App Store release — Fastlane → TestFlight → review submission
