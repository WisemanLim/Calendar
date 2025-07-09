import SwiftUI
import EventKit

struct CalendarView: View {
    @State private var currentDate = Date()
    @State private var selectedDate = Date()
    @StateObject private var eventStore = EventStoreManager.shared
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    private let days = ["일", "월", "화", "수", "목", "금", "토"]
    
    private var currentMonthDays: [DayInfo] {
        generateDaysInMonth(for: currentDate)
    }
    
    private func yearString(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: date)
    }
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: currentDate)
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
                // Current month and year header
                HStack {
                    Text(monthString)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.black)
                    Spacer()
                    HStack(spacing: 15) {
                        Button(action: {
                            if let newDate = Calendar.current.date(byAdding: .year, value: -1, to: currentDate) {
                                currentDate = newDate
                            }
                        }) {
                            Text("<")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.blue)
                                .frame(width: 30, height: 30)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(15)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Text(yearString(date: currentDate))
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.gray)
                            .frame(minWidth: 80)
                        
                        Button(action: {
                            if let newDate = Calendar.current.date(byAdding: .year, value: 1, to: currentDate) {
                                currentDate = newDate
                            }
                        }) {
                            Text(">")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.blue)
                                .frame(width: 30, height: 30)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(15)
                        }
                        .buttonStyle(PlainButtonStyle())
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
                        .frame(height: geometry.size.height * 0.7)
                    
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
                                .foregroundColor(Color.gray.opacity(0.15))
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                .offset(y: 10)

                            Text(weekdayString(date: selectedDate).uppercased())
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(Color.gray.opacity(0.15))
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
                    }
                    .onChange(of: selectedDate) { _, newValue in
                        loadEvents(for: newValue)
                    }
                    .onChange(of: currentDate) { _, _ in
                        loadEvents(for: selectedDate)
                    }
                    
                    // Content layer
                    VStack(spacing: 8) {
                        Spacer()
                            .frame(height: 30)
                        
                        // Main content area
                        VStack(spacing: 15) {
                            // Memo list
                            let memos = memosForSelectedDate()
                            if !memos.isEmpty {
                                MemoListView(memos: Array(memos.prefix(2)))
                                Text("SCHEDULE")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.gray.opacity(0.8))
                                    .padding(.bottom, 5)
                                ForEach(memos, id: \.self) { memo in
                                    HStack(alignment: .top, spacing: 10) {
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 6, height: 6)
                                            .padding(.top, 6)
                                        Text(memo)
                                            .font(.system(size: 16))
                                            .foregroundColor(.black)
                                            .lineLimit(2)
                                        Spacer()
                                        HStack(alignment: .top, spacing: 10) {
                                            Circle()
                                                .fill(Color.blue)
                                                .frame(width: 6, height: 6)
                                                .padding(.top, 6)
                                            Text(memo)
                                                .font(.system(size: 16))
                                                .foregroundColor(.black)
                                                .lineLimit(2)
                                            Spacer()
                                        }
                                    }
                                }
                                .padding(.horizontal, 25)
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
                    .frame(height: geometry.size.height * 0.7 - 40)
                    .padding(.bottom, 40)
                }
                .frame(height: geometry.size.height * 0.7)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 10)
                
                // Four month calendar grid with navigation
                HStack(spacing: 0) {
                    // Previous month button
                    Button(action: { changeMonth(-1) }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.blue)
                            .frame(width: 24, height: 24)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.trailing, 5)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Calendar grid
                    VStack(spacing: 5) {
                        // First row - current and next month
                        HStack(spacing: 5) {
                            MonthView(date: currentDate, selectedDate: $selectedDate, eventStore: eventStore, isCurrentMonth: true)
                            MonthView(date: Calendar.current.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate, selectedDate: $selectedDate, eventStore: eventStore, isCurrentMonth: false)
                        }
                        HStack(spacing: 5) {
                            MonthView(date: Calendar.current.date(byAdding: .month, value: 2, to: currentDate) ?? currentDate, selectedDate: $selectedDate, eventStore: eventStore, isCurrentMonth: false)
                            MonthView(date: Calendar.current.date(byAdding: .month, value: 3, to: currentDate) ?? currentDate, selectedDate: $selectedDate, eventStore: eventStore, isCurrentMonth: false)
                        }
                    }
                    
                    // Next month button
                    Button(action: { changeMonth(1) }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.blue)
                            .frame(width: 24, height: 24)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.leading, 5)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
    }
    
    private func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(date1, inSameDayAs: date2)
    }
    
    private func generateDaysInMonth(for date: Date) -> [DayInfo] {
        var days = [DayInfo]()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let firstDayOfMonth = calendar.date(from: components) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let range = calendar.range(of: .day, in: .month, for: date) ?? 1..<1
        let numDays = range.count
        let prevMonth = calendar.date(byAdding: .month, value: -1, to: date)!
        let prevMonthRange = calendar.range(of: .day, in: .month, for: prevMonth) ?? 1..<1
        let prevMonthDays = prevMonthRange.count

        for i in (firstWeekday - 2)..<0 {
            let day = prevMonthDays + i + 1
            if let prevDate = calendar.date(byAdding: .day, value: -i-1, to: firstDayOfMonth) {
                days.append(DayInfo(day: day, date: prevDate, isCurrentMonth: false))
            }
        }

        let today = calendar.startOfDay(for: Date())
        let selected = calendar.startOfDay(for: selectedDate)
        for day in 1...numDays {
            let dateComponents = DateComponents(year: components.year, month: components.month, day: day)
            if let currentDate = calendar.date(from: dateComponents) {
                var info = DayInfo(day: day, date: currentDate, isCurrentMonth: true)
                info.isToday = calendar.isDate(currentDate, inSameDayAs: today)
                info.isSelected = calendar.isDate(currentDate, inSameDayAs: selected)
                info.hasEvent = !(eventStore.events[eventStore.dateKey(from: currentDate)]?.isEmpty ?? true)
                days.append(info)
            }
        }

        let totalDays = 42
        let remaining = totalDays - days.count
        if remaining > 0, let lastDate = days.last?.date {
            for _ in 1...remaining {
                if let nextDate = calendar.date(byAdding: .day, value: 1, to: lastDate) {
                    days.append(DayInfo(day: calendar.component(.day, from: nextDate), date: nextDate, isCurrentMonth: false))
                }
            }
        }
        return days
    }
    

    
    private func loadEvents(for date: Date) {
        Task {
            // This will trigger a fetch if the events aren't cached
            _ = eventStore.fetchEvents(for: date)
        }
    }
    
    private func memosForSelectedDate() -> [String] {
        eventStore.events[eventStore.dateKey(from: selectedDate)] ?? []
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
}

struct DayInfo: Identifiable {
    let id = UUID()
    let day: Int
    let date: Date
    let isCurrentMonth: Bool
    var isToday: Bool = false
    var isSelected: Bool = false
    var hasEvent: Bool = false
    
    init(day: Int, date: Date, isCurrentMonth: Bool) {
        self.day = day
        self.date = date
        self.isCurrentMonth = isCurrentMonth
    }
}



struct MonthView: View {
    let date: Date
    @Binding var selectedDate: Date
    @ObservedObject var eventStore: EventStoreManager
    let isCurrentMonth: Bool
    
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
        var days = [DayInfo]()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let firstDayOfMonth = calendar.date(from: components) else { return [] }
        
        // Get the weekday of the first day of the month (1 = Sunday, 2 = Monday, etc.)
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        
        // Get the number of days in the month
        let range = calendar.range(of: .day, in: .month, for: date) ?? 1..<1
        let numDays = range.count
        
        // Add padding for days from previous month
        let prevMonth = calendar.date(byAdding: .month, value: -1, to: date)!
        let prevMonthRange = calendar.range(of: .day, in: .month, for: prevMonth) ?? 1..<1
        let prevMonthDays = prevMonthRange.count
        
        // Add previous month's days
        let previousDaysCount = (firstWeekday - 1 + 6) % 7  // Calculate how many days from previous month to show
        if previousDaysCount > 0 {
            for i in 0..<previousDaysCount {
                if let prevDate = calendar.date(byAdding: .day, value: -previousDaysCount + i, to: firstDayOfMonth) {
                    let day = calendar.component(.day, from: prevDate)
                    var info = DayInfo(day: day, date: prevDate, isCurrentMonth: false)
                    info.hasEvent = !(eventStore.events[eventStore.dateKey(from: prevDate)]?.isEmpty ?? true)
                    days.append(info)
                }
            }
        }
        
        // Add days of the current month
        let today = calendar.startOfDay(for: Date())
        let selected = calendar.startOfDay(for: selectedDate)
        
        for day in 1...numDays {
            let dateComponents = DateComponents(year: components.year, month: components.month, day: day)
            if let currentDate = calendar.date(from: dateComponents) {
                var info = DayInfo(day: day, date: currentDate, isCurrentMonth: true)
                info.isToday = calendar.isDate(currentDate, inSameDayAs: today)
                info.isSelected = calendar.isDate(currentDate, inSameDayAs: selected)
                info.hasEvent = !(eventStore.events[eventStore.dateKey(from: currentDate)]?.isEmpty ?? true)
                days.append(info)
            }
        }
        
        // Add next month's days to fill the grid (6 weeks)
        let totalDays = 42 // 6 weeks * 7 days
        let remaining = totalDays - days.count
        if remaining > 0, let lastDate = days.last?.date {
            for i in 0..<remaining {
                if let nextDate = calendar.date(byAdding: .day, value: i + 1, to: lastDate) {
                    var info = DayInfo(day: calendar.component(.day, from: nextDate), date: nextDate, isCurrentMonth: false)
                    info.hasEvent = !(eventStore.events[eventStore.dateKey(from: nextDate)]?.isEmpty ?? true)
                    days.append(info)
                }
            }
        }
        
        return days
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
                        .foregroundColor(day == "SUN" ? .red : (day == "SAT" ? .blue : .gray))
                }
            }
            
            // Date grid
            let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)
            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(currentMonthDays) { dayInfo in
                    DayView(
                        dayInfo: dayInfo,
                        isSelected: isSameDay(dayInfo.date, selectedDate)
                    )
                    .onTapGesture {
                        selectedDate = dayInfo.date
                    }
                }
            }
        }
        .padding(4)
        .background(Color.white)
        .cornerRadius(4)
        .shadow(radius: 1)
    }
    
    private func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(date1, inSameDayAs: date2)
    }
}

struct DayView: View {
    let dayInfo: DayInfo
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 24, height: 24)
            }
            
            Text("\(dayInfo.day)")
                .font(.system(size: 12, weight: dayInfo.isToday ? .bold : .regular))
                .foregroundColor(
                    isSelected ? .white :
                    dayInfo.isToday ? .blue :
                    dayInfo.isCurrentMonth ? .black : .gray
                )
                .frame(width: 24, height: 24)
            
            if dayInfo.hasEvent {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 4, height: 4)
                    .offset(y: 6)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 30)
    }
}

struct MemoListView: View {
    var memos: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if memos.isEmpty {
                Text("No events scheduled")
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 5)
            } else {
                ForEach(memos.prefix(2), id: \.self) { memo in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 5, height: 5)
                            .padding(.top, 6)
                        Text(memo)
                            .font(.system(size: 14))
                            .foregroundColor(.black)
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

struct CalendarView_Previews: PreviewProvider {
    static var previews: some View {
        let eventStore = EventStoreManager.shared
        return CalendarView()
            .environment(\.locale, .init(identifier: "en_US"))
            .environmentObject(eventStore)
    }
}
