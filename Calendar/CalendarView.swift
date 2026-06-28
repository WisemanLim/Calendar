import SwiftUI
import EventKit

struct CalendarView: View {
    var theme: CalendarTheme = .default
    @ObservedObject var settings: AppSettings
    @ObservedObject var templateStore: TemplateStore

    @State private var currentDate = Date()
    @State private var selectedDate = Date()
    @StateObject private var eventStore = EventStoreManager.shared
    @StateObject private var weatherService = WeatherService()
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var showSettings = false
    @State private var showEditor = false
    @State private var editingEvent: CalendarEventItem?
    @State private var copyConfig: EventCopyConfig? = nil
    @State private var oneTimeModeOverride: PlannerMode? = nil
    @State private var showModeOverridePicker = false
    @State private var showSearch = false
    @State private var addButtonLongPressed = false
    @State private var calendarSwipeOffset: CGFloat = 0
    @State private var pullRefreshOffset: CGFloat = 0
    @State private var isRefreshing = false

    private var showsTodayButton: Bool {
        !Calendar.current.isDateInToday(selectedDate)
    }

    private func yearString(date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy"
        return f.string(from: date)
    }

    private var monthYearString: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        f.locale = Locale(identifier: "en_US")
        return f.string(from: currentDate).uppercased()
    }

    private var activeMode: PlannerMode { oneTimeModeOverride ?? settings.plannerMode }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {

                // MARK: Row 1 — gear | Today? + < year > | +
                HStack(spacing: 8) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(theme.accent)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()

                    if showsTodayButton {
                        Button(action: goToToday) {
                            Text("Today")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(theme.todayTint)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(theme.navBackground)
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    HStack(spacing: 6) {
                        navButton(systemName: "chevron.left", tint: theme.year) { changeYear(-1) }
                        Text(yearString(date: currentDate))
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(theme.year)
                        navButton(systemName: "chevron.right", tint: theme.year) { changeYear(1) }
                    }

                    Spacer()

                    Button { showSearch = true } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(theme.accent)
                    }
                    .buttonStyle(PlainButtonStyle())

                    addButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // MARK: Row 2 — < MONTH YEAR >
                HStack {
                    navButton(systemName: "chevron.left", tint: theme.month) { changeMonth(-1) }
                    Spacer()
                    Text(monthYearString)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(theme.month)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Spacer()
                    navButton(systemName: "chevron.right", tint: theme.month) { changeMonth(1) }
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)

                // MARK: Row 3 — Week strip
                WeekStripView(
                    selectedDate: selectedDate,
                    theme: theme,
                    weatherService: weatherService,
                    eventStore: eventStore
                ) { date in
                    selectedDate = date
                }
                .padding(.top, 6)

                // MARK: Hero — large date + schedule list
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .shadow(radius: 1)
                        .padding(.horizontal, 10)
                        .frame(height: geometry.size.height * 0.48)

                    // Animated day background
                    ZStack {
                        if isDragging {
                            VStack(spacing: -10) {
                                Text(dayString(date: Calendar.current.date(byAdding: .day, value: dragOffset > 0 ? -1 : 1, to: selectedDate) ?? selectedDate))
                                    .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.9, weight: .bold))
                                    .minimumScaleFactor(0.5)
                                    .lineLimit(1)
                                    .foregroundColor(Color.gray.opacity(0.1))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                    .offset(y: 10)
                                Text(weekdayString(date: Calendar.current.date(byAdding: .day, value: dragOffset > 0 ? -1 : 1, to: selectedDate) ?? selectedDate).uppercased())
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundColor(Color.gray.opacity(0.1))
                                    .minimumScaleFactor(0.5)
                                    .lineLimit(1)
                                    .offset(y: -20)
                            }
                            .offset(x: dragOffset > 0 ? -geometry.size.width + dragOffset : geometry.size.width + dragOffset, y: 0)
                        }

                        VStack(spacing: -10) {
                            Text(dayString(date: selectedDate))
                                .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.9, weight: .bold))
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                                .foregroundColor(heroColor)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                .offset(y: 10)
                            Text(weekdayString(date: selectedDate).uppercased())
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(heroColor)
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                                .offset(y: -20)
                        }
                        .offset(x: dragOffset, y: -20)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .gesture(
                        DragGesture(minimumDistance: 30)
                            .onChanged { value in
                                guard abs(value.translation.width) > abs(value.translation.height) * 1.2 else { return }
                                dragOffset = value.translation.width
                                isDragging = true
                            }
                            .onEnded { value in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if abs(value.translation.width) > geometry.size.width / 4 {
                                        let delta = value.translation.width > 0 ? -1 : 1
                                        if let newDate = Calendar.current.date(byAdding: .day, value: delta, to: selectedDate) {
                                            selectedDate = newDate
                                        }
                                    }
                                    dragOffset = 0
                                    isDragging = false
                                }
                            }
                    )
                    .onAppear {
                        loadEvents(for: selectedDate)
                        prefetchVisibleMonths()
                        weatherService.requestLocationAndFetch()
                    }
                    .onChange(of: selectedDate) { _, newValue in
                        loadEvents(for: newValue)
                        if !Calendar.current.isDate(newValue, equalTo: currentDate, toGranularity: .month) {
                            currentDate = newValue
                        }
                    }
                    .onChange(of: currentDate) { _, _ in
                        loadEvents(for: selectedDate)
                        prefetchVisibleMonths()
                    }
                    .onChange(of: eventStore.hasAccess) { _, authorized in
                        if authorized { prefetchVisibleMonths() }
                    }
                    .simultaneousGesture(TapGesture(count: 2).onEnded { showEditor = true })
                    .simultaneousGesture(LongPressGesture(minimumDuration: 0.6).onEnded { _ in showModeOverridePicker = true })

                    // Schedule list overlay
                    VStack(spacing: 8) {
                        if isRefreshing || pullRefreshOffset > 20 {
                            HStack {
                                Spacer()
                                if isRefreshing {
                                    ProgressView()
                                        .tint(Color.gray.opacity(0.6))
                                } else {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.gray.opacity(0.5))
                                        .rotationEffect(.degrees(pullRefreshOffset > 60 ? 180 : 0))
                                        .animation(.spring(response: 0.3), value: pullRefreshOffset > 60)
                                }
                                Spacer()
                            }
                            .frame(height: 24)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        VStack(spacing: 15) {
                            // 음력 날짜 + 날씨 — 같은 라인
                            HStack(spacing: 6) {
                                Text(lunarDateString(for: selectedDate))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.gray.opacity(0.5))
                                Spacer()
                                let dateKey = eventStore.dateKey(from: selectedDate)
                                if let condition = weatherService.dailyWeather[dateKey] {
                                    Image(systemName: condition.sfSymbol)
                                        .foregroundColor(condition.tintColor)
                                        .font(.system(size: 14))
                                    if let temp = weatherService.dailyTemperature[dateKey] {
                                        Text("\(temp)°")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.gray.opacity(0.7))
                                    }
                                }
                            }
                            .padding(.horizontal, 25)
                            let memos = memosForSelectedDate()
                            if !memos.isEmpty {
                                ForEach(memos) { memo in
                                    let isSecret = memo.title.hasPrefix("[비밀]")
                                    SwipeDeleteWrapper(onDelete: { eventStore.deleteEvent(id: memo.id, on: selectedDate) }) {
                                        HStack(alignment: .top, spacing: 10) {
                                            Circle()
                                                .fill(memo.isOverdue ? Color.red : Color.blue)
                                                .frame(width: 6, height: 6)
                                                .padding(.top, 6)
                                            Text(memo.displayTitle)
                                                .font(.system(size: 16))
                                                .foregroundColor(memo.isOverdue ? .red : .black)
                                                .lineLimit(2)
                                            Spacer()
                                        }
                                        .opacity(isSecret ? 0.25 : 1.0)
                                        .padding(.horizontal, 25)
                                        .contentShape(Rectangle())
                                        .onTapGesture { editingEvent = memo }
                                        .contextMenu {
                                            Button { copyConfig = EventCopyConfig(item: memo, includeNotes: true) } label: {
                                                Label("복사 (내용포함)", systemImage: "doc.on.doc")
                                            }
                                            Button { copyConfig = EventCopyConfig(item: memo, includeNotes: false) } label: {
                                                Label("복사 (내용제외)", systemImage: "doc.on.doc.fill")
                                            }
                                            Button { copyConfig = EventCopyConfig(item: memo, includeNotes: true, isRepeat: true) } label: {
                                                Label("반복복사 (내용포함)", systemImage: "arrow.triangle.2.circlepath")
                                            }
                                            Button { copyConfig = EventCopyConfig(item: memo, includeNotes: false, isRepeat: true) } label: {
                                                Label("반복복사 (내용제외)", systemImage: "arrow.clockwise")
                                            }
                                        }
                                    }
                                }
                            }
                            // else { Text("No events scheduled") } // 주석 처리
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 25)
                    }
                    .frame(height: geometry.size.height * 0.48 - 40)
                    .padding(.bottom, 40)
                    .offset(y: max(0, pullRefreshOffset))
                }
                .frame(height: geometry.size.height * 0.48)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 15)
                        .onChanged { value in
                            guard abs(value.translation.height) > abs(value.translation.width) * 1.5,
                                  value.translation.height > 0 else { return }
                            withAnimation(.interactiveSpring()) {
                                pullRefreshOffset = value.translation.height * 0.35
                            }
                        }
                        .onEnded { value in
                            let isVertical = abs(value.translation.height) > abs(value.translation.width) * 1.5
                            let triggered = isVertical && value.translation.height > 60
                            withAnimation(.spring()) { pullRefreshOffset = 0 }
                            if triggered && !isRefreshing { refreshEvents() }
                        }
                )
                .frame(maxWidth: .infinity)
                .padding(.bottom, 10)

                // MARK: Mini calendars — current + next month
                HStack(spacing: 0) {
                    MonthView(date: currentDate, selectedDate: $selectedDate, eventStore: eventStore, isCurrentMonth: true, theme: theme)
                    Divider().frame(width: 1).padding(.vertical, 6)
                    MonthView(date: Calendar.current.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate, selectedDate: $selectedDate, eventStore: eventStore, isCurrentMonth: false, theme: theme)
                }
                .offset(x: calendarSwipeOffset)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { v in calendarSwipeOffset = v.translation.width * 0.25 }
                        .onEnded { v in
                            withAnimation(.easeOut(duration: 0.15)) { calendarSwipeOffset = 0 }
                            if v.translation.width < -50 { changeMonth(1) }
                            else if v.translation.width > 50 { changeMonth(-1) }
                        }
                )
                .padding(.horizontal, 8)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.15), radius: 14, x: 0, y: 5)
                .padding(.horizontal, 14)
                .padding(.bottom, 16)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(settings: settings, eventStore: eventStore)
            }
            .sheet(isPresented: editorSheetBinding) {
                EventEditorView(mode: activeMode, date: selectedDate,
                                eventStore: eventStore, templateStore: templateStore,
                                notificationsEnabled: settings.notificationsEnabled, theme: theme)
            }
            .fullScreenCover(isPresented: editorFullScreenBinding) {
                EventEditorView(mode: activeMode, date: selectedDate,
                                eventStore: eventStore, templateStore: templateStore,
                                notificationsEnabled: settings.notificationsEnabled, theme: theme)
            }
            .sheet(item: $editingEvent, onDismiss: {
                eventStore.invalidateCache(for: selectedDate)
                loadEvents(for: selectedDate)
            }) { event in
                EventEditSheet(item: event, date: selectedDate, eventStore: eventStore)
            }
            .sheet(item: $copyConfig) { config in
                EventCopySheet(config: config, eventStore: eventStore)
            }
            .sheet(isPresented: $showSearch) {
                EventSearchView(eventStore: eventStore) { date in
                    selectedDate = date
                    currentDate = date
                }
            }
            .confirmationDialog("입력 방식 선택", isPresented: $showModeOverridePicker, titleVisibility: .visible) {
                ForEach(PlannerMode.allCases.filter { $0 != settings.plannerMode }) { mode in
                    Button(mode.title) {
                        oneTimeModeOverride = mode
                        showEditor = true
                    }
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("이번 1회만 다른 입력 방식으로 이벤트를 추가합니다.")
            }
        }
    }

    // MARK: - Add button (tap = default mode, long press = one-time override)

    private var addButton: some View {
        Button {
            if !addButtonLongPressed { showEditor = true }
            addButtonLongPressed = false
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(theme.accent)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.6).onEnded { _ in
                addButtonLongPressed = true
                showModeOverridePicker = true
            }
        )
    }

    // MARK: - Sheet bindings

    private var editorFullScreenBinding: Binding<Bool> {
        Binding(
            get: { showEditor && activeMode == .diary },
            set: { if !$0 { showEditor = false; oneTimeModeOverride = nil } }
        )
    }

    private var editorSheetBinding: Binding<Bool> {
        Binding(
            get: { showEditor && activeMode != .diary },
            set: { if !$0 { showEditor = false; oneTimeModeOverride = nil } }
        )
    }

    // MARK: - Helpers

    private func loadEvents(for date: Date) {
        _ = eventStore.fetchEvents(for: date)
    }

    private func refreshEvents() {
        isRefreshing = true
        weatherService.requestLocationAndFetch()
        eventStore.invalidateCache(for: selectedDate)
        loadEvents(for: selectedDate)
        prefetchVisibleMonths()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.spring()) { isRefreshing = false }
        }
    }

    private func prefetchVisibleMonths() {
        let cal = Calendar.current
        func fetch(_ date: Date) {
            let comps = cal.dateComponents([.year, .month], from: date)
            if let y = comps.year, let m = comps.month {
                eventStore.fetchEventsForMonth(year: y, month: m)
            }
        }
        fetch(currentDate)
        if let next = cal.date(byAdding: .month, value: 1, to: currentDate) { fetch(next) }
    }

    private func memosForSelectedDate() -> [CalendarEventItem] {
        eventStore.events[eventStore.dateKey(from: selectedDate)] ?? []
    }

    private var heroColor: Color {
        let count = eventStore.events[eventStore.dateKey(from: selectedDate)]?.count ?? 0
        return count > 0 ? eventCountColor(count).opacity(0.28) : Color.gray.opacity(0.15)
    }

    private func lunarDateString(for date: Date) -> String {
        var cal = Calendar(identifier: .chinese)
        cal.locale = Locale(identifier: "ko_KR")
        let comps = cal.dateComponents([.month, .day], from: date)
        guard let month = comps.month, let day = comps.day else { return "" }
        let leap = comps.isLeapMonth == true ? "윤" : ""
        return "음력 \(leap)\(month)월 \(day)일"
    }

    private func dayString(date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }

    private func weekdayString(date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        f.locale = Locale(identifier: "en_US")
        return f.string(from: date)
    }

    private func changeMonth(_ value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: currentDate) {
            currentDate = newDate
            selectedDate = newDate
        }
    }

    private func changeYear(_ value: Int) {
        if let newDate = Calendar.current.date(byAdding: .year, value: value, to: currentDate) {
            currentDate = newDate
            selectedDate = newDate
        }
    }

    private func goToToday() {
        let today = Date()
        currentDate = today
        selectedDate = today
    }

    @ViewBuilder
    private func navButton(systemName: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(tint)
                .frame(width: 30, height: 30)
                .background(theme.navBackground)
                .cornerRadius(15)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - WeekStripView

struct WeekStripView: View {
    let selectedDate: Date
    let theme: CalendarTheme
    @ObservedObject var weatherService: WeatherService
    @ObservedObject var eventStore: EventStoreManager
    let onDateTap: (Date) -> Void

    private static let weekdayAbbrevs = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    private static let dateKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var weekDates: [Date] {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: selectedDate) // 1=Sun
        guard let startOfWeek = cal.date(byAdding: .day, value: -(weekday - 1), to: selectedDate) else { return [] }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: startOfWeek) }
    }

    @State private var swipeOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: 0) {
            ForEach(weekDates, id: \.self) { date in
                dayCell(for: date)
                    .onTapGesture { onDateTap(date) }
            }
        }
        .offset(x: swipeOffset)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground))
        .gesture(
            DragGesture(minimumDistance: 20)
                .onChanged { v in
                    swipeOffset = v.translation.width * 0.25
                }
                .onEnded { v in
                    let threshold: CGFloat = 50
                    withAnimation(.easeOut(duration: 0.15)) { swipeOffset = 0 }
                    let cal = Calendar.current
                    if v.translation.width < -threshold {
                        onDateTap(cal.date(byAdding: .day, value: 7, to: selectedDate) ?? selectedDate)
                    } else if v.translation.width > threshold {
                        onDateTap(cal.date(byAdding: .day, value: -7, to: selectedDate) ?? selectedDate)
                    }
                }
        )
    }

    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let cal = Calendar.current
        let isSelected = cal.isDate(date, inSameDayAs: selectedDate)
        let isToday = cal.isDateInToday(date)
        let weekdayIdx = cal.component(.weekday, from: date) - 1   // 0=Sun
        let dayNum = cal.component(.day, from: date)
        let dateKey = Self.dateKeyFormatter.string(from: date)
        let condition = weatherService.dailyWeather[dateKey]
        let dk = eventStore.dateKey(from: date)
        let eventCount = eventStore.events[dk]?.count ?? eventStore.cachedEventCounts[dk] ?? 0

        VStack(spacing: 4) {
            // Weekday abbreviation
            Text(Self.weekdayAbbrevs[weekdayIdx])
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(
                    weekdayIdx == 0 ? theme.sunday :
                    weekdayIdx == 6 ? theme.saturday : .gray
                )

            // Date circle
            ZStack {
                if isSelected {
                    Circle().fill(theme.accent).frame(width: 34, height: 34)
                } else if isToday {
                    Circle().stroke(theme.accent, lineWidth: 1.5).frame(width: 34, height: 34)
                }
                Text("\(dayNum)")
                    .font(.system(size: 17, weight: isToday ? .bold : .regular))
                    .foregroundColor(isSelected ? .white : isToday ? theme.accent : .primary)
            }
            .frame(width: 34, height: 34)

            // Weather icon (SF Symbol) or emoji fallback
            if let condition {
                Image(systemName: condition.sfSymbol)
                    .font(.system(size: 18))
                    .foregroundColor(condition.tintColor)
                    .frame(height: 23)
            } else {
                Text(eventDayEmoji(eventCount))
                    .font(.system(size: 18))
                    .frame(height: 23)
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

}

// MARK: - DayInfo

struct DayInfo: Identifiable {
    let id = UUID()
    let day: Int
    let date: Date
    let isCurrentMonth: Bool
    var isToday: Bool = false
    var isSelected: Bool = false
    var hasEvent: Bool = false
    var eventCount: Int = 0

    init(day: Int, date: Date, isCurrentMonth: Bool) {
        self.day = day
        self.date = date
        self.isCurrentMonth = isCurrentMonth
    }
}

/// 이벤트 갯수 → 얼굴 이모지 (0~1=😀, 2~3=😊, 4+=🤯)
func eventDayEmoji(_ count: Int) -> String {
    switch count {
    case 0, 1: return "😀"
    case 2, 3: return "😊"
    default:   return "🤯"
    }
}

/// 이벤트 갯수 → 무지개 7단계 색상 (0=기본, 1=노, 2=주, 3=초, 4=남, 5=보, 6+=빨)
func eventCountColor(_ count: Int) -> Color {
    switch count {
    case 0: return .black
    case 1: return Color(red: 0.95, green: 0.85, blue: 0.0)
    case 2: return Color(red: 1.0,  green: 0.55, blue: 0.0)
    case 3: return Color(red: 0.15, green: 0.72, blue: 0.25)
    case 4: return Color(red: 0.08, green: 0.15, blue: 0.65)
    case 5: return Color(red: 0.55, green: 0.1,  blue: 0.8)
    default: return Color(red: 0.85, green: 0.1, blue: 0.1)
    }
}

// MARK: - MonthView

struct MonthView: View {
    let date: Date
    @Binding var selectedDate: Date
    @ObservedObject var eventStore: EventStoreManager
    let isCurrentMonth: Bool
    var theme: CalendarTheme = .default

    private let days = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]

    private var monthYearString: String {
        let f = DateFormatter()
        f.dateFormat = "M월"
        f.locale = Locale(identifier: "en_US")
        return f.string(from: date)
    }

    private var currentMonthDays: [DayInfo] {
        CalendarLogic.monthGrid(
            for: date,
            selectedDate: selectedDate,
            today: Date(),
            eventCount: { d in
                let dk = eventStore.dateKey(from: d)
                return eventStore.events[dk]?.count ?? eventStore.cachedEventCounts[dk] ?? 0
            }
        )
    }

    var body: some View {
        VStack(spacing: 1) {
            Text(monthYearString)
                .font(.system(size: 9, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 1)

            HStack(spacing: 1) {
                ForEach(days, id: \.self) { day in
                    Text(day)
                        .frame(maxWidth: .infinity)
                        .font(.system(size: 7))
                        .foregroundColor(day == "SUN" ? theme.sunday : (day == "SAT" ? theme.saturday : .gray))
                }
            }

            let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(currentMonthDays) { dayInfo in
                    DayView(
                        dayInfo: dayInfo,
                        isSelected: isSameDay(dayInfo.date, selectedDate),
                        theme: theme
                    )
                    .onTapGesture { selectedDate = dayInfo.date }
                }
            }
        }
        .padding(.horizontal, 2)
    }

    private func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        Calendar.current.isDate(date1, inSameDayAs: date2)
    }
}

// MARK: - DayView

struct DayView: View {
    let dayInfo: DayInfo
    let isSelected: Bool
    var theme: CalendarTheme = .default

    var body: some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(theme.accent)
                    .frame(width: 20, height: 20)
            }
            Text("\(dayInfo.day)")
                .font(.system(size: 10, weight: dayInfo.isToday ? .bold : .regular))
                .foregroundColor(
                    isSelected ? .white :
                    !dayInfo.isCurrentMonth ? .gray :
                    dayInfo.eventCount > 0 ? eventCountColor(dayInfo.eventCount) :
                    dayInfo.isToday ? theme.accent : .black
                )
                .frame(width: 20, height: 20)

            if dayInfo.hasEvent {
                Circle()
                    .fill(dayInfo.eventCount > 0 ? eventCountColor(dayInfo.eventCount) : theme.accent)
                    .frame(width: 3, height: 3)
                    .offset(y: 5)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 22)
    }
}

// MARK: - MemoListView

struct MemoListView: View {
    var memos: [CalendarEventItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if memos.isEmpty {
                Text("No events scheduled")
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 5)
            } else {
                ForEach(memos.prefix(2)) { memo in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(memo.isOverdue ? Color.red : Color.blue)
                            .frame(width: 5, height: 5)
                            .padding(.top, 6)
                        Text(memo.displayTitle)
                            .font(.system(size: 14))
                            .foregroundColor(memo.isOverdue ? .red : .black)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
    }
}

// MARK: - EventEditSheet

struct EventEditSheet: View {
    let item: CalendarEventItem
    let date: Date
    @ObservedObject var eventStore: EventStoreManager
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var notes: String
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var originalDuration: TimeInterval
    @State private var location: String
    @State private var notesContentHeight: CGFloat = 80

    private var notesMaxHeight: CGFloat { UIScreen.main.bounds.height - 100 }

    private func calcNotesHeight(width: CGFloat) -> CGFloat {
        guard !notes.isEmpty else { return 80 }
        let font = UIFont.systemFont(ofSize: 16)
        let rect = (notes as NSString).boundingRect(
            with: CGSize(width: max(100, width - 16), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return max(80, ceil(rect.height) + 32)
    }

    init(item: CalendarEventItem, date: Date, eventStore: EventStoreManager) {
        self.item = item
        self.date = date
        self.eventStore = eventStore
        let ek = eventStore.fetchEvent(id: item.id)
        _title     = State(initialValue: item.title)
        _notes     = State(initialValue: ek?.notes ?? "")
        let start  = ek?.startDate ?? item.startDate
        let end    = ek?.endDate   ?? item.startDate.addingTimeInterval(3600)
        _startTime = State(initialValue: start)
        _endTime   = State(initialValue: end)
        _originalDuration = State(initialValue: end.timeIntervalSince(start))
        _location  = State(initialValue: ek?.location  ?? "")
    }

    var body: some View {
        NavigationStack {
            List {
                Section("제목") { TextField("제목", text: $title) }
                Section("시간") {
                    DatePicker("시작", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                        .onChange(of: startTime) { _, newStart in
                            endTime = newStart.addingTimeInterval(originalDuration)
                        }
                    DatePicker("종료", selection: $endTime,   displayedComponents: [.date, .hourAndMinute])
                }
                Section("장소") { TextField("장소 (선택)", text: $location) }
                Section("메모") {
                    TextEditor(text: $notes)
                        .scrollDisabled(notesContentHeight <= notesMaxHeight)
                        .frame(height: max(80, min(notesContentHeight, notesMaxHeight)))
                        .background(GeometryReader { geo in
                            Color.clear
                                .onAppear {
                                    notesContentHeight = calcNotesHeight(width: geo.size.width)
                                }
                                .onChange(of: notes) { _, _ in
                                    notesContentHeight = calcNotesHeight(width: geo.size.width)
                                }
                        })
                }
            }
            .navigationTitle("일정 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        let loc = location.trimmingCharacters(in: .whitespaces)
                        eventStore.updateEvent(
                            id: item.id, title: title,
                            notes: notes.isEmpty ? nil : notes,
                            startDate: startTime,
                            endDate: endTime < startTime ? startTime : endTime,
                            location: loc.isEmpty ? nil : loc,
                            on: date
                        )
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - EventCopyConfig

struct EventCopyConfig: Identifiable {
    let id = UUID()
    let item: CalendarEventItem
    let includeNotes: Bool
    var isRepeat: Bool = false
}

// MARK: - EventCopySheet

struct EventCopySheet: View {
    let config: EventCopyConfig
    @ObservedObject var eventStore: EventStoreManager
    @Environment(\.dismiss) private var dismiss

    @State private var targetDate: Date
    @State private var repeatEndDate: Date
    @State private var title: String
    @State private var notes: String
    @State private var startHour: Date
    @State private var endHour: Date

    init(config: EventCopyConfig, eventStore: EventStoreManager) {
        self.config = config
        self.eventStore = eventStore
        let ek = eventStore.fetchEvent(id: config.item.id)
        let today = Date()
        _targetDate    = State(initialValue: today)
        _repeatEndDate = State(initialValue: Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today)
        _title         = State(initialValue: config.item.title)
        _notes         = State(initialValue: config.includeNotes ? (ek?.notes ?? "") : "")
        _startHour     = State(initialValue: ek?.startDate ?? config.item.startDate)
        _endHour       = State(initialValue: ek?.endDate   ?? config.item.startDate.addingTimeInterval(3600))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DatePicker(config.isRepeat ? "시작일" : "복사 날짜", selection: $targetDate, displayedComponents: .date)
                    if config.isRepeat {
                        DatePicker("종료일", selection: $repeatEndDate, in: targetDate..., displayedComponents: .date)
                    }
                } header: {
                    Text(config.isRepeat ? "반복 날짜 범위" : "복사할 날짜 선택")
                }

                Section("제목") {
                    TextField("제목", text: $title)
                }

                Section("시간") {
                    DatePicker("시작", selection: $startHour, displayedComponents: .hourAndMinute)
                    DatePicker("종료", selection: $endHour,   displayedComponents: .hourAndMinute)
                }

                if config.includeNotes {
                    Section("내용") {
                        TextEditor(text: $notes).frame(minHeight: 80)
                    }
                }
            }
            .navigationTitle(config.isRepeat ? "반복 복사" : "이벤트 복사")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(config.isRepeat ? "반복복사" : "복사", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let cal = Calendar.current
        func combine(date: Date, time: Date) -> Date {
            let d = cal.dateComponents([.year, .month, .day], from: date)
            let t = cal.dateComponents([.hour, .minute], from: time)
            var merged = DateComponents()
            merged.year = d.year; merged.month = d.month; merged.day = d.day
            merged.hour = t.hour; merged.minute = t.minute
            return cal.date(from: merged) ?? date
        }
        if config.isRepeat {
            var cursor = targetDate
            while cursor <= repeatEndDate {
                let newStart = combine(date: cursor, time: startHour)
                let rawEnd   = combine(date: cursor, time: endHour)
                let newEnd   = rawEnd <= newStart ? newStart.addingTimeInterval(3600) : rawEnd
                _ = eventStore.addEvent(
                    title: title,
                    notes: config.includeNotes && !notes.isEmpty ? notes : nil,
                    startDate: newStart,
                    endDate: newEnd
                )
                guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
            }
        } else {
            let newStart = combine(date: targetDate, time: startHour)
            let rawEnd   = combine(date: targetDate, time: endHour)
            let newEnd   = rawEnd <= newStart ? newStart.addingTimeInterval(3600) : rawEnd
            _ = eventStore.addEvent(
                title: title,
                notes: config.includeNotes && !notes.isEmpty ? notes : nil,
                startDate: newStart,
                endDate: newEnd
            )
        }
        dismiss()
    }
}

// MARK: - EventSearchView

struct EventSearchView: View {
    @ObservedObject var eventStore: EventStoreManager
    let onSelect: (Date) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [CalendarEventItem] = []

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd (E) HH:mm"
        f.locale = Locale(identifier: "ko_KR")
        return f
    }()

    var body: some View {
        NavigationStack {
            List {
                ForEach(results) { item in
                    Button {
                        onSelect(item.startDate)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            Text(Self.dateFmt.string(from: item.startDate))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .overlay {
                if results.isEmpty && !query.isEmpty {
                    ContentUnavailableView("검색 결과 없음",
                                          systemImage: "magnifyingglass",
                                          description: Text("'\(query)'에 해당하는 이벤트가 없습니다."))
                }
            }
            .searchable(text: $query, prompt: "이벤트 검색")
            .onChange(of: query) { _, q in performSearch(q) }
            .navigationTitle("이벤트 검색")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
        }
    }

    private func performSearch(_ q: String) {
        let trimmed = q.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { results = []; return }
        let now = Date()
        let cal = Calendar.current
        let start = cal.date(byAdding: .year, value: -1, to: now) ?? now
        let end   = cal.date(byAdding: .year, value: 2,  to: now) ?? now
        results = eventStore.searchEvents(query: trimmed, from: start, to: end)
    }
}

// MARK: - Preview

struct CalendarView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarView(settings: AppSettings(defaults: UserDefaults(suiteName: "preview")!),
                     templateStore: TemplateStore(defaults: UserDefaults(suiteName: "preview")!))
            .environment(\.locale, .init(identifier: "en_US"))
    }
}

// MARK: - SwipeDeleteWrapper
private struct SwipeDeleteWrapper<Content: View>: View {
    let onDelete: () -> Void
    @ViewBuilder let content: Content

    @State private var offset: CGFloat = 0
    private let buttonWidth: CGFloat = 72

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(action: {
                withAnimation(.easeOut(duration: 0.2)) { offset = 0 }
                onDelete()
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.white)
                    .frame(width: buttonWidth)
                    .frame(maxHeight: .infinity)
            }
            .background(Color.red)
            .opacity(offset < -10 ? 1 : 0)

            content
                .offset(x: offset)
        }
        .clipped()
        .gesture(
            DragGesture(minimumDistance: 15, coordinateSpace: .local)
                .onChanged { v in
                    guard abs(v.translation.width) > abs(v.translation.height) * 1.2 else { return }
                    if v.translation.width < 0 {
                        offset = max(v.translation.width, -buttonWidth)
                    } else if offset < 0 {
                        offset = min(0, offset + v.translation.width)
                    }
                }
                .onEnded { v in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        offset = v.translation.width < -(buttonWidth / 2) ? -buttonWidth : 0
                    }
                }
        )
    }
}
