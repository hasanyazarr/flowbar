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

    // Tek bir hatırlatıcı satırı
    private func reminderRow(for reminder: Reminder) -> some View {
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
                        Text(project.name)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.12))
                            .foregroundStyle(Color.accentColor)
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
