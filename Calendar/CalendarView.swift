import SwiftUI
import EventKit

struct CalendarView: View {
    var theme: CalendarTheme = .default
    @ObservedObject var settings: AppSettings
    @ObservedObject var templateStore: TemplateStore

    @State private var currentDate = Date()
    @State private var selectedDate = Date()
    @StateObject private var eventStore = EventStoreManager.shared
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var showSettings = false
    @State private var showEditor = false
    @State private var editingEvent: CalendarEventItem?

    /// 선택일(스케줄 일자)이 오늘이 아니면 Today 버튼 노출.
    private var showsTodayButton: Bool {
        !Calendar.current.isDateInToday(selectedDate)
    }

    private func yearString(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: date)
    }

    private var monthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: currentDate)
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Top utility strip: settings + add
                HStack {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(theme.accent)
                    }
                    .buttonStyle(PlainButtonStyle())
                    Spacer()
                    Button { showEditor = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(theme.accent)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // Current month and year header
                HStack(spacing: 10) {
                    // Month group: < June >
                    HStack(spacing: 4) {
                        navButton(systemName: "chevron.left", tint: theme.month) { changeMonth(-1) }
                        Text(monthString)
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(theme.month)
                        navButton(systemName: "chevron.right", tint: theme.month) { changeMonth(1) }
                    }

                    // Today button — only when selected date is not today
                    if showsTodayButton {
                        Button(action: goToToday) {
                            Text("Today")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(theme.todayTint)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(theme.navBackground)
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    Spacer()

                    // Year group: < 2026 >  (nav buttons share year text color)
                    HStack(spacing: 6) {
                        navButton(systemName: "chevron.left", tint: theme.year) { changeYear(-1) }
                        Text(yearString(date: currentDate))
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(theme.year)
                        navButton(systemName: "chevron.right", tint: theme.year) { changeYear(1) }
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                
                // Selected date section with layered design
                ZStack {
                    // White background container with thin border
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .shadow(radius: 1)
                        .padding(.horizontal, 10)
                        .frame(height: geometry.size.height * 0.56)
                    
                    // Large background date with weekday and swipe gesture
                    ZStack {
                        // Previous date (offscreen left)
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
                        
                        // Current date
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
                        DragGesture()
                            .onChanged { value in
                                self.dragOffset = value.translation.width
                                self.isDragging = true
                            }
                            .onEnded { value in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    // If drag distance is more than 1/4 of screen width, switch dates
                                    if abs(value.translation.width) > geometry.size.width / 4 {
                                        if value.translation.width > 0 {
                                            // Swipe right - go to previous day
                                            if let newDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) {
                                                selectedDate = newDate
                                            }
                                        } else {
                                            // Swipe left - go to next day
                                            if let newDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) {
                                                selectedDate = newDate
                                            }
                                        }
                                    }
                                    self.dragOffset = 0
                                    self.isDragging = false
                                }
                            }
                    )
                    .onAppear {
                        loadEvents(for: selectedDate)
                        prefetchVisibleMonths()
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
                    .simultaneousGesture(
                        TapGesture(count: 2).onEnded { showEditor = true }
                    )
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.6).onEnded { _ in showEditor = true }
                    )
                    
                    // Content layer
                    VStack(spacing: 8) {
                        Spacer()
                            .frame(height: 30)
                        
                        // Main content area
                        VStack(spacing: 15) {
                            // Memo list
                            let memos = memosForSelectedDate()
                            if !memos.isEmpty {
                                Text("SCHEDULE")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.gray.opacity(0.8))
                                    .padding(.bottom, 5)
                                ForEach(memos) { memo in
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
                                    .padding(.horizontal, 25)
                                    .contentShape(Rectangle())
                                    .contextMenu {
                                        Button { editingEvent = memo } label: {
                                            Label("편집", systemImage: "pencil")
                                        }
                                        Button(role: .destructive) {
                                            eventStore.deleteEvent(id: memo.id, on: selectedDate)
                                        } label: {
                                            Label("삭제", systemImage: "trash")
                                        }
                                    }
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("No events scheduled")
                                        .font(.system(size: 16))
                                        .foregroundColor(.gray.opacity(0.7))
                                        .padding(.top, 20)
                                }
                                .padding(.horizontal, 25)
                            }
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 20)
                    }
                    .frame(height: geometry.size.height * 0.56 - 40)
                    .padding(.bottom, 40)
                }
                .frame(height: geometry.size.height * 0.56)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 10)
                HStack(spacing: 0) {
                    MonthView(date: currentDate, selectedDate: $selectedDate, eventStore: eventStore, isCurrentMonth: true, theme: theme)
                    Divider().frame(width: 1).padding(.vertical, 6)
                    MonthView(date: Calendar.current.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate, selectedDate: $selectedDate, eventStore: eventStore, isCurrentMonth: false, theme: theme)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
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
                EventEditorView(mode: settings.plannerMode, date: selectedDate,
                                eventStore: eventStore, templateStore: templateStore,
                                notificationsEnabled: settings.notificationsEnabled, theme: theme)
            }
            .fullScreenCover(isPresented: editorFullScreenBinding) {
                EventEditorView(mode: .diary, date: selectedDate,
                                eventStore: eventStore, templateStore: templateStore,
                                notificationsEnabled: settings.notificationsEnabled, theme: theme)
            }
            .sheet(item: $editingEvent) { event in
                EventEditSheet(item: event, date: selectedDate, eventStore: eventStore)
            }
        }
    }

    /// 다이어리 = 전체화면, 그 외 = 시트.
    private var editorFullScreenBinding: Binding<Bool> {
        Binding(
            get: { showEditor && settings.plannerMode == .diary },
            set: { if !$0 { showEditor = false } }
        )
    }
    private var editorSheetBinding: Binding<Bool> {
        Binding(
            get: { showEditor && settings.plannerMode != .diary },
            set: { if !$0 { showEditor = false } }
        )
    }

    private func loadEvents(for date: Date) {
        _ = eventStore.fetchEvents(for: date)
    }

    /// 현재 표시 중인 두 달(currentDate + 다음달)을 일괄 프리패치.
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
    
    private func dayString(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private func weekdayString(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: date)
    }
    
    private func changeMonth(_ value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: currentDate) {
            currentDate = newDate
            // Auto-select first day of the month when changing months
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

    /// 공통 이동 버튼 (월/연 < > 에서 재사용). 색은 호출부 테마에서 주입.
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

/// 이벤트 갯수 → 무지개 7단계 색상 (0=기본, 1=노, 2=주, 3=초, 4=남, 5=보, 6+=빨)
func eventCountColor(_ count: Int) -> Color {
    switch count {
    case 0: return .black
    case 1: return Color(red: 0.95, green: 0.85, blue: 0.0)   // 노란색
    case 2: return Color(red: 1.0,  green: 0.55, blue: 0.0)   // 주황색
    case 3: return Color(red: 0.15, green: 0.72, blue: 0.25)  // 초록색
    case 4: return Color(red: 0.08, green: 0.15, blue: 0.65)  // 남색
    case 5: return Color(red: 0.55, green: 0.1,  blue: 0.8)   // 보라색
    default: return Color(red: 0.85, green: 0.1, blue: 0.1)   // 빨간색 (6+)
    }
}



struct MonthView: View {
    let date: Date
    @Binding var selectedDate: Date
    @ObservedObject var eventStore: EventStoreManager
    let isCurrentMonth: Bool
    var theme: CalendarTheme = .default

    private let days = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M월"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: date)
    }
    
    private var currentMonthDays: [DayInfo] {
        generateDaysInMonth(for: date)
    }
    
    private func generateDaysInMonth(for date: Date) -> [DayInfo] {
        CalendarLogic.monthGrid(
            for: date,
            selectedDate: selectedDate,
            today: Date(),
            eventCount: { d in
                eventStore.events[eventStore.dateKey(from: d)]?.count ?? 0
            }
        )
    }
    
    var body: some View {
        VStack(spacing: 2) {
            // Month header
            Text(monthYearString)
                .font(.system(size: 10, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 2)
            
            // Weekday header
            HStack(spacing: 1) {
                ForEach(days, id: \.self) { day in
                    Text(day)
                        .frame(maxWidth: .infinity)
                        .font(.system(size: 8))
                        .foregroundColor(day == "SUN" ? theme.sunday : (day == "SAT" ? theme.saturday : .gray))
                }
            }
            
            // Date grid
            let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)
            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(currentMonthDays) { dayInfo in
                    DayView(
                        dayInfo: dayInfo,
                        isSelected: isSameDay(dayInfo.date, selectedDate),
                        theme: theme
                    )
                    .onTapGesture {
                        selectedDate = dayInfo.date
                    }
                }
            }
        }
        .padding(4)
    }
    
    private func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(date1, inSameDayAs: date2)
    }
}

struct DayView: View {
    let dayInfo: DayInfo
    let isSelected: Bool
    var theme: CalendarTheme = .default

    var body: some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(theme.accent)
                    .frame(width: 24, height: 24)
            }

            Text("\(dayInfo.day)")
                .font(.system(size: 12, weight: dayInfo.isToday ? .bold : .regular))
                .foregroundColor(
                    isSelected ? .white :
                    !dayInfo.isCurrentMonth ? .gray :
                    dayInfo.eventCount > 0 ? eventCountColor(dayInfo.eventCount) :
                    dayInfo.isToday ? theme.accent : .black
                )
                .frame(width: 24, height: 24)

            if dayInfo.hasEvent {
                Circle()
                    .fill(dayInfo.eventCount > 0 ? eventCountColor(dayInfo.eventCount) : theme.accent)
                    .frame(width: 4, height: 4)
                    .offset(y: 6)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 30)
    }
}

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
    @State private var location: String

    init(item: CalendarEventItem, date: Date, eventStore: EventStoreManager) {
        self.item = item
        self.date = date
        self.eventStore = eventStore
        let ek = eventStore.fetchEvent(id: item.id)
        _title    = State(initialValue: item.title)
        _notes    = State(initialValue: ek?.notes ?? "")
        _startTime = State(initialValue: ek?.startDate ?? item.startDate)
        _endTime   = State(initialValue: ek?.endDate   ?? item.startDate.addingTimeInterval(3600))
        _location  = State(initialValue: ek?.location  ?? "")
    }

    var body: some View {
        NavigationStack {
            List {
                Section("제목") {
                    TextField("제목", text: $title)
                }
                Section("시간") {
                    DatePicker("시작", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("종료", selection: $endTime,   displayedComponents: [.date, .hourAndMinute])
                }
                Section("장소") {
                    TextField("장소 (선택)", text: $location)
                }
                Section("메모") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
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
                            id: item.id,
                            title: title,
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

struct CalendarView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarView(settings: AppSettings(defaults: UserDefaults(suiteName: "preview")!),
                     templateStore: TemplateStore(defaults: UserDefaults(suiteName: "preview")!))
            .environment(\.locale, .init(identifier: "en_US"))
    }
}
