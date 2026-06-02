import SwiftUI
import SwiftData

struct RemindView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Project.createdAt) private var activeProjects: [Project]
    @Query(sort: \Reminder.createdAt, order: .reverse) private var allReminders: [Reminder]

    // Form durumları
    @State private var selectedProjectID: UUID?
    @State private var reminderContent: String = ""
    @State private var hasRemindTime: Bool = false
    @State private var remindTime: Date = Date().addingTimeInterval(900) // 15 dk sonrası varsayılan
    @State private var contentError: String?

    // Tamamlananları göster/gizle
    @State private var showCompleted: Bool = false

    // Inline düzenleme durumları
    @State private var editingReminderID: UUID?
    @State private var editContent: String = ""
    @State private var editProjectID: UUID?
    @State private var editHasRemindTime: Bool = false
    @State private var editRemindTime: Date = .now

    private var activeReminders: [Reminder] {
        allReminders.filter { !$0.isCompleted }
    }

    private var completedReminders: [Reminder] {
        allReminders.filter { $0.isCompleted }
    }

    private var selectedProject: Project? {
        guard let selectedProjectID else { return nil }
        return activeProjects.first { $0.id == selectedProjectID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Reminders").font(.headline)

            // Hatırlatıcı Ekleme Formu
            VStack(alignment: .leading, spacing: 10) {
                // Proje Seç
                Picker("Project", selection: $selectedProjectID) {
                    Text("No project (General)").tag(UUID?.none)
                    ForEach(activeProjects) { project in
                        Text(project.name).tag(UUID?.some(project.id))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)

                // Hatırlatma Alanı (Geniş Metin Editörü)
                SessionNoteEditor(text: $reminderContent, placeholder: String(localized: "Something to remember…"))
                    .frame(height: 72)

                // Opsiyonel Tarih/Saat Seçici
                HStack {
                    Toggle("Set alarm/notification", isOn: $hasRemindTime)
                        .toggleStyle(.checkbox)
                        .font(.callout)

                    Spacer()

                    if hasRemindTime {
                        DatePicker("", selection: $remindTime, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
                .animation(.snappy(duration: 0.16), value: hasRemindTime)

                if hasRemindTime {
                    quickTimeShortcuts(binding: $remindTime)
                        .transition(.opacity)
                }

                if let contentError {
                    Text(contentError)
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                Button(action: addReminder) {
                    Label("Add reminder", systemImage: "bell.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(reminderContent.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(12)
            .background(CategorySurface.panel)
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(CategorySurface.border, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Hatırlatıcı Listesi
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if activeReminders.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No pending reminders")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                    } else {
                        ForEach(activeReminders) { reminder in
                            reminderRow(for: reminder)
                        }
                    }

                    // Tamamlananlar Başlığı ve Listesi
                    if !completedReminders.isEmpty {
                        Divider().padding(.vertical, 4)

                        Button {
                            withAnimation(.snappy(duration: 0.14)) {
                                showCompleted.toggle()
                            }
                        } label: {
                            HStack {
                                Text("Completed (\(completedReminders.count))")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Image(systemName: showCompleted ? "chevron.down" : "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .hoverHighlight()

                        if showCompleted {
                            ForEach(completedReminders) { reminder in
                                reminderRow(for: reminder)
                                    .opacity(0.6)
                            }
                            .transition(.opacity)
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
        }
        .onAppear {
            ReminderNotificationManager.requestPermission()
        }
    }

    // Tek bir hatırlatıcı satırı (düzenleme modundaysa edit görünümü)
    @ViewBuilder
    private func reminderRow(for reminder: Reminder) -> some View {
        if editingReminderID == reminder.id {
            editRow(for: reminder)
        } else {
            displayRow(for: reminder)
        }
    }

    // Okuma görünümü
    private func displayRow(for reminder: Reminder) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Checkbox
            Button {
                toggleCompleted(reminder)
            } label: {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(reminder.isCompleted ? .secondary : Color.accentColor)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.content)
                    .font(.body)
                    .strikethrough(reminder.isCompleted)
                    .foregroundStyle(reminder.isCompleted ? .secondary : .primary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if let project = reminder.project {
                        let chipColor = (project.category?.colorHex).flatMap { Color(hex: $0) } ?? .accentColor
                        Text(project.name)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2.5)
                            .background(chipColor.opacity(0.68))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }

                    if let remindAt = reminder.remindAt {
                        Label(formatDate(remindAt), systemImage: "clock")
                            .font(.caption2)
                            .foregroundStyle(remindAt < Date() && !reminder.isCompleted ? .red : .secondary)
                    }
                }
            }

            Spacer()

            // Düzenleme Butonu (tamamlanmamışlarda)
            if !reminder.isCompleted {
                Button {
                    beginEditing(reminder)
                } label: {
                    Image(systemName: "pencil")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .hoverHighlight()
                .help(String(localized: "Edit reminder"))
            }

            // Silme Butonu
            Button {
                deleteReminder(reminder)
            } label: {
                Image(systemName: "trash")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .hoverHighlight()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // Inline düzenleme görünümü
    private func editRow(for reminder: Reminder) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Project", selection: $editProjectID) {
                Text("No project (General)").tag(UUID?.none)
                ForEach(activeProjects) { project in
                    Text(project.name).tag(UUID?.some(project.id))
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)

            SessionNoteEditor(text: $editContent, placeholder: String(localized: "Something to remember…"))
                .frame(height: 60)

            HStack {
                Toggle("Set alarm/notification", isOn: $editHasRemindTime)
                    .toggleStyle(.checkbox)
                    .font(.callout)

                Spacer()

                if editHasRemindTime {
                    DatePicker("", selection: $editRemindTime, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }
            }
            .animation(.snappy(duration: 0.16), value: editHasRemindTime)

            if editHasRemindTime {
                quickTimeShortcuts(binding: $editRemindTime)
            }

            HStack {
                Button("Cancel") { cancelEditing() }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                Spacer()

                Button {
                    saveEditing(reminder)
                } label: {
                    Label("Save", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(editContent.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(12)
        .background(CategorySurface.panel)
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor.opacity(0.4), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // Hızlı tarih/saat kısayolları: verilen binding'i ayarlar.
    private func quickTimeShortcuts(binding: Binding<Date>) -> some View {
        HStack(spacing: 6) {
            ForEach(QuickTime.allCases) { option in
                Button(option.label) {
                    binding.wrappedValue = option.date()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    // Önceden tanımlı hızlı saat seçenekleri.
    private enum QuickTime: String, CaseIterable, Identifiable {
        case inOneHour
        case thisEvening
        case tomorrowMorning

        var id: String { rawValue }

        var label: LocalizedStringKey {
            switch self {
            case .inOneHour: return "In 1 hour"
            case .thisEvening: return "This evening"
            case .tomorrowMorning: return "Tomorrow morning"
            }
        }

        func date(now: Date = .now, calendar: Calendar = .current) -> Date {
            switch self {
            case .inOneHour:
                return now.addingTimeInterval(3600)
            case .thisEvening:
                // Bugün 18:00; geçmişse 1 saat sonrasına düş.
                let evening = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: now) ?? now
                return evening > now ? evening : now.addingTimeInterval(3600)
            case .tomorrowMorning:
                // Yarın 09:00.
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
                return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
            }
        }
    }

    // Düzenlemeyi başlatır: mevcut değerleri edit alanlarına yükler.
    private func beginEditing(_ reminder: Reminder) {
        editingReminderID = reminder.id
        editContent = reminder.content
        editProjectID = reminder.project?.id
        editHasRemindTime = reminder.remindAt != nil
        editRemindTime = reminder.remindAt ?? Date().addingTimeInterval(900)
    }

    private func cancelEditing() {
        editingReminderID = nil
    }

    // Düzenlemeyi kaydeder; bildirim varsa yeniden zamanlar.
    private func saveEditing(_ reminder: Reminder) {
        let trimmed = editContent.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        reminder.content = trimmed
        reminder.project = activeProjects.first { $0.id == editProjectID }
        reminder.remindAt = editHasRemindTime ? editRemindTime : nil

        // Bildirimi güncel duruma göre yeniden kur.
        ReminderNotificationManager.cancelNotification(for: reminder)
        if editHasRemindTime && !reminder.isCompleted {
            ReminderNotificationManager.scheduleNotification(for: reminder)
        }

        editingReminderID = nil
    }

    // Hatırlatıcıyı kaydeder
    private func addReminder() {
        let trimmed = reminderContent.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let rTime = hasRemindTime ? remindTime : nil
        let reminder = Reminder(content: trimmed, remindAt: rTime, project: selectedProject)

        context.insert(reminder)

        if hasRemindTime {
            ReminderNotificationManager.scheduleNotification(for: reminder)
        }

        // Temizle
        reminderContent = ""
        hasRemindTime = false
        contentError = nil
    }

    // Durum değiştirme
    private func toggleCompleted(_ reminder: Reminder) {
        withAnimation(.snappy(duration: 0.16)) {
            reminder.isCompleted.toggle()
            if reminder.isCompleted {
                ReminderNotificationManager.cancelNotification(for: reminder)
            } else if reminder.remindAt != nil {
                ReminderNotificationManager.scheduleNotification(for: reminder)
            }
        }
    }

    // Silme
    private func deleteReminder(_ reminder: Reminder) {
        withAnimation(.snappy(duration: 0.14)) {
            ReminderNotificationManager.cancelNotification(for: reminder)
            context.delete(reminder)
        }
    }

    // Tarih formatı
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        if Calendar.current.isDateInToday(date) {
            let time = date.formatted(date: .omitted, time: .shortened)
            return String(localized: "Today \(time)")
        } else if Calendar.current.isDateInTomorrow(date) {
            let time = date.formatted(date: .omitted, time: .shortened)
            return String(localized: "Tomorrow \(time)")
        } else {
            formatter.setLocalizedDateFormatFromTemplate("d MMM HH:mm")
            return formatter.string(from: date)
        }
    }
}
