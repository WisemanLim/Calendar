import SwiftUI
import EventKit
import PhotosUI

enum MedicationPreset: String, CaseIterable {
    case morning = "아침"
    case lunch = "점심"
    case evening = "저녁"
    case custom = "직접"

    var hour: Int? {
        switch self {
        case .morning: return 7
        case .lunch: return 12
        case .evening: return 18
        case .custom: return nil
        }
    }
}

/// 플래너 모드별 이벤트 추가 화면.
struct EventEditorView: View {
    let mode: PlannerMode
    let date: Date
    @ObservedObject var eventStore: EventStoreManager
    @ObservedObject var templateStore: TemplateStore
    var notificationsEnabled: Bool
    var theme: CalendarTheme = .default

    @Environment(\.dismiss) private var dismiss

    // Common
    @State private var title = ""

    // Diary
    private let editorOpenTime = Date()
    @State private var diaryBody = ""
    @State private var elapsedSeconds = 0
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Todo
    @State private var todos: [TodoItem] = [TodoItem(text: "")]
    @State private var dueDate: Date

    // PersonalEvent
    @State private var selectedCategory: TemplateCategory = .medication
    @State private var selectedTemplate: EventTemplate?
    @State private var eventStartTime: Date
    @State private var eventEndTime: Date
    @State private var eventLocation = ""
    @State private var medicationPreset: MedicationPreset = .morning
    @State private var repeatEnabled = false
    @State private var repeatStartDate: Date
    @State private var repeatEndDate: Date

    // Photo (복용 이벤트 전용)
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var showCamera = false

    init(mode: PlannerMode, date: Date,
         eventStore: EventStoreManager, templateStore: TemplateStore,
         notificationsEnabled: Bool, theme: CalendarTheme = .default) {
        self.mode = mode
        self.date = date
        self.eventStore = eventStore
        self.templateStore = templateStore
        self.notificationsEnabled = notificationsEnabled
        self.theme = theme

        var c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        c.hour = 23; c.minute = 59
        _dueDate = State(initialValue: Calendar.current.date(from: c) ?? date)

        c.hour = 9; c.minute = 0
        let start = Calendar.current.date(from: c) ?? date
        _eventStartTime = State(initialValue: start)
        _eventEndTime = State(initialValue: start.addingTimeInterval(3600))

        _repeatStartDate = State(initialValue: date)
        _repeatEndDate = State(initialValue: Calendar.current.date(byAdding: .year, value: 1, to: date) ?? date)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("새 \(mode.title)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("저장", action: save).disabled(!canSave)
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .diary: diaryEditor
        case .todo: todoEditor
        case .personalEvent: templateEditor
        }
    }

    // MARK: diary — 시작=화면 열린 시각, 저장=저장 시각

    private var diaryEditor: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("제목", text: $title)
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                Text(elapsedString)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .monospacedDigit()
            }
            .padding()
            Divider()
            TextEditor(text: $diaryBody)
                .font(.system(size: 16))
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .topLeading) {
                    if diaryBody.isEmpty {
                        Text("오늘의 기록을 자유롭게 작성하세요…")
                            .foregroundColor(.gray.opacity(0.5))
                            .padding(16)
                            .allowsHitTesting(false)
                    }
                }
        }
        .onReceive(ticker) { _ in elapsedSeconds += 1 }
    }

    private var elapsedString: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    // MARK: todo — due-date 필수, 기한 초과 시 적색 표시

    private var todoEditor: some View {
        List {
            Section("제목") {
                TextField("할 일 목록 제목", text: $title)
            }
            Section("목표 시간 (Due Date)") {
                DatePicker("기한", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                if dueDate < Date() {
                    Label("기한이 지났습니다", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 13))
                }
            }
            Section("항목") {
                ForEach($todos) { $item in
                    HStack {
                        Button { item.done.toggle() } label: {
                            Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(item.done ? theme.accent : .gray)
                        }
                        .buttonStyle(PlainButtonStyle())
                        TextField("항목", text: $item.text)
                            .strikethrough(item.done)
                    }
                }
                .onDelete { todos.remove(atOffsets: $0) }
                Button { todos.append(TodoItem(text: "")) } label: {
                    Label("항목 추가", systemImage: "plus.circle")
                }
            }
        }
    }

    // MARK: personalEvent — 카테고리별 시간 설정

    private var templateEditor: some View {
        List {
            Section("분류") {
                Picker("분류", selection: $selectedCategory) {
                    ForEach(TemplateCategory.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedCategory) { _, _ in
                    selectedTemplate = nil; title = ""; repeatEnabled = false
                }
            }
            Section("템플릿") {
                ForEach(templateStore.templates(in: selectedCategory)) { t in
                    Button {
                        selectedTemplate = t
                        title = t.fixedDisplayTitle ?? t.titleFormat
                        applyTemplateTime(t)
                    } label: {
                        HStack {
                            Text(t.fixedDisplayTitle ?? t.titleFormat).foregroundColor(.primary)
                            Spacer()
                            if selectedTemplate?.id == t.id {
                                Image(systemName: "checkmark").foregroundColor(theme.accent)
                            }
                        }
                    }
                }
            }
            if let tmpl = selectedTemplate {
                Section("제목 (편집 가능)") { TextField("제목", text: $title) }
                timeSection(for: tmpl)
            }
        }
        .onChange(of: photoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    selectedImage = img
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker(image: $selectedImage)
        }
    }

    @ViewBuilder
    private func timeSection(for tmpl: EventTemplate) -> some View {
        switch tmpl.category {
        case .medication:
            Section("복용 시간") {
                HStack(spacing: 6) {
                    ForEach(MedicationPreset.allCases, id: \.self) { preset in
                        Button {
                            medicationPreset = preset
                            if let h = preset.hour { eventStartTime = dateAt(hour: h) }
                        } label: {
                            Text(preset.rawValue)
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(medicationPreset == preset ? theme.accent : Color.gray.opacity(0.15))
                                .foregroundColor(medicationPreset == preset ? .white : .primary)
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                DatePicker("시간", selection: $eventStartTime, displayedComponents: .hourAndMinute)
                    .onChange(of: eventStartTime) { _, _ in medicationPreset = .custom }
            }
            Section {
                Button("기본 시간으로 저장") {
                    var updated = tmpl
                    updated.defaultStartHour = Calendar.current.component(.hour, from: eventStartTime)
                    templateStore.update(updated)
                }
                .foregroundColor(theme.accent)
            }
            Section(header: Text("반복")) {
                Toggle("반복 설정", isOn: $repeatEnabled)
                if repeatEnabled {
                    DatePicker("반복 시작일", selection: $repeatStartDate, displayedComponents: .date)
                    DatePicker("반복 종료일", selection: $repeatEndDate,
                               in: repeatStartDate..., displayedComponents: .date)
                    Text("매년(Yearly) 반복")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
            }
            Section(header: Text("사진")) {
                if let img = selectedImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipped()
                        .cornerRadius(8)
                    Button("사진 제거", role: .destructive) {
                        selectedImage = nil; photoItem = nil
                    }
                }
                HStack(spacing: 16) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("앨범", systemImage: "photo.on.rectangle")
                    }
                    Divider().frame(height: 20)
                    Button { showCamera = true } label: {
                        Label("카메라", systemImage: "camera")
                    }
                }
            }

        case .appointment:
            Section("약속 시간") {
                DatePicker("시작", selection: $eventStartTime, displayedComponents: .hourAndMinute)
                DatePicker("종료", selection: $eventEndTime, displayedComponents: .hourAndMinute)
            }
            Section("장소") {
                TextField("장소 입력 (선택)", text: $eventLocation)
            }

        case .fixed:
            Section("시간") {
                DatePicker("시작", selection: $eventStartTime, displayedComponents: .hourAndMinute)
                DatePicker("종료", selection: $eventEndTime, displayedComponents: .hourAndMinute)
                    .onChange(of: eventStartTime) { _, newVal in
                        if eventEndTime < newVal { eventEndTime = newVal }
                    }
            }
            Section(header: Text("반복")) {
                Toggle("반복 설정", isOn: $repeatEnabled)
                if repeatEnabled {
                    DatePicker("반복 시작일", selection: $repeatStartDate, displayedComponents: .date)
                    DatePicker("반복 종료일", selection: $repeatEndDate,
                               in: repeatStartDate..., displayedComponents: .date)
                    Text("매년(Yearly) 반복")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
            }
        }
    }

    private func dateAt(hour: Int) -> Date {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        c.hour = hour; c.minute = 0
        return Calendar.current.date(from: c) ?? date
    }

    private func applyTemplateTime(_ t: EventTemplate) {
        let start = dateAt(hour: t.defaultStartHour)
        eventStartTime = start
        eventEndTime = t.defaultDurationMinutes > 0
            ? start.addingTimeInterval(TimeInterval(t.defaultDurationMinutes * 60))
            : start
        if t.category == .medication {
            switch t.defaultStartHour {
            case 7: medicationPreset = .morning
            case 12: medicationPreset = .lunch
            case 18: medicationPreset = .evening
            default: medicationPreset = .custom
            }
        }
    }

    // MARK: canSave / save

    private var canSave: Bool {
        switch mode {
        case .diary: return !title.isEmpty || !diaryBody.isEmpty
        case .todo: return todos.contains { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        case .personalEvent: return selectedTemplate != nil && !title.isEmpty
        }
    }

    private func save() {
        let resolvedTitle: String
        let notes: String?
        let startDate: Date
        let endDate: Date
        var location: String? = nil
        var recurrenceRules: [EKRecurrenceRule]? = nil

        switch mode {
        case .diary:
            resolvedTitle = title.isEmpty ? "일기" : title
            notes = diaryBody
            startDate = editorOpenTime
            endDate = Date()

        case .todo:
            resolvedTitle = title.isEmpty ? "할 일" : title
            let valid = todos.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
            notes = PlannerLogic.encodeTodos(valid)
            startDate = dueDate
            endDate = dueDate

        case .personalEvent:
            guard let tmpl = selectedTemplate else { return }
            resolvedTitle = PlannerLogic.substituteTitlePatterns(title, date: date)
            notes = nil
            let hasDatePattern = PlannerLogic.hasTitleDatePattern(title)
            switch tmpl.category {
            case .medication:
                startDate = eventStartTime
                endDate = eventStartTime
                if repeatEnabled {
                    recurrenceRules = [EKRecurrenceRule(
                        recurrenceWith: .yearly, interval: 1,
                        end: EKRecurrenceEnd(end: repeatEndDate)
                    )]
                } else if !hasDatePattern {
                    recurrenceRules = [EKRecurrenceRule(recurrenceWith: .yearly, interval: 1, end: nil)]
                }
            case .appointment:
                startDate = eventStartTime
                endDate = eventEndTime > eventStartTime ? eventEndTime : eventStartTime.addingTimeInterval(3600)
                let loc = eventLocation.trimmingCharacters(in: .whitespaces)
                location = loc.isEmpty ? nil : loc
                if !hasDatePattern {
                    recurrenceRules = [EKRecurrenceRule(recurrenceWith: .yearly, interval: 1, end: nil)]
                }
            case .fixed:
                startDate = eventStartTime
                endDate = eventEndTime >= eventStartTime ? eventEndTime : eventStartTime
                if repeatEnabled {
                    recurrenceRules = [EKRecurrenceRule(
                        recurrenceWith: .yearly, interval: 1,
                        end: EKRecurrenceEnd(end: repeatEndDate)
                    )]
                } else if !hasDatePattern {
                    recurrenceRules = [EKRecurrenceRule(recurrenceWith: .yearly, interval: 1, end: nil)]
                }
            }
        }

        if let eventId = eventStore.addEvent(
            title: resolvedTitle, notes: notes,
            startDate: startDate, endDate: endDate,
            isAllDay: false, location: location, recurrenceRules: recurrenceRules
        ) {
            if notificationsEnabled {
                NotificationManager.shared.scheduleEventReminder(title: resolvedTitle, on: startDate)
            }
            if let img = selectedImage {
                EventImageStore.shared.saveImage(img, for: eventId)
            }
        }
        dismiss()
    }
}

// MARK: - CameraPicker

/// UIImagePickerController 카메라 래퍼.
struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let vc = UIImagePickerController()
        vc.sourceType = .camera
        vc.allowsEditing = true
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
