import SwiftUI
import SwiftData
import UserNotifications
import ServiceManagement
import UniformTypeIdentifiers
import AppKit

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject var stopwatch: StopwatchModel
    
    @Query private var allProjects: [Project]
    @Query private var allSessions: [Session]
    @Query private var allReminders: [Reminder]
    @Query private var allCategories: [Category]
    
    let onBack: () -> Void
    
    @AppStorage("menuBarDisplayMode") private var menuBarDisplayMode = "iconAndTimer"
    @AppStorage("backgroundStyle") private var backgroundStyle = "glass"
    @AppStorage("backupFrequency") private var backupFrequency = "never"
    @AppStorage("backupDirectoryPath") private var backupDirectoryPath = ""
    @AppStorage("lastBackupDate") private var lastBackupDate: Double = 0
    @AppStorage("appLanguage") private var appLanguage = "system"

    @State private var showDeleteConfirm = false
    @State private var deleteConfirmText = ""
    @State private var notificationStatus: String = String(localized: "Checking…")
    @State private var launchAtLoginEnabled: Bool = {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Başlık satırı
            HStack {
                Button {
                    onBack()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
                
                Text("Settings")
                    .font(.headline)
                
                Spacer()
                
                // Simetri sağlamak için boş bir alan
                Spacer().frame(width: 50)
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 1. Sistem Bildirimleri
                    VStack(alignment: .leading, spacing: 8) {
                        Label("macOS Notifications", systemImage: "bell.badge.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.accentColor)

                        Text("System permissions must be enabled so you can receive local notifications when a reminder is due.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            Text("Permission status: \(notificationStatus)")
                                .font(.caption2)
                                .fontWeight(.bold)
                            Spacer()
                            Button("Request / Refresh") {
                                requestNotificationPermission()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(12)
                    .background(CategorySurface.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(CategorySurface.border, lineWidth: 1)
                    }
                    
                    // 2. Genel Tercihler
                    VStack(alignment: .leading, spacing: 10) {
                        Label("General Preferences", systemImage: "sliders.horizontal.3")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.accentColor)

                        // Language preference
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Language")
                                .font(.caption)
                                .fontWeight(.medium)

                            Picker("", selection: $appLanguage) {
                                Text("System").tag("system")
                                Text("English").tag("en")
                                Text("Türkçe").tag("tr")
                            }
                            .pickerStyle(.segmented)
                            .controlSize(.small)
                            .onChange(of: appLanguage) { _, newValue in
                                applyLanguage(newValue)
                            }

                            Text("Restart the app to fully apply a language change.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Divider().padding(.vertical, 2)

                        // Menu bar preference
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Menu Bar Display")
                                .font(.caption)
                                .fontWeight(.medium)

                            Picker("", selection: $menuBarDisplayMode) {
                                Text("Icon and Timer").tag("iconAndTimer")
                                Text("Timer Only").tag("timerOnly")
                                Text("Icon Only").tag("iconOnly")
                            }
                            .pickerStyle(.segmented)
                            .controlSize(.small)

                            Text("Sets what is shown in the menu bar while the timer is running.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Divider().padding(.vertical, 2)

                        // Background style preference
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Window Appearance")
                                .font(.caption)
                                .fontWeight(.medium)

                            Picker("", selection: $backgroundStyle) {
                                Text("Glass").tag("glass")
                                Text("Matte").tag("matte")
                            }
                            .pickerStyle(.segmented)
                            .controlSize(.small)

                            Text("Determines the background style of the app window.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Divider().padding(.vertical, 2)

                        // Launch at login
                        Toggle(isOn: Binding(
                            get: { launchAtLoginEnabled },
                            set: { newValue in
                                launchAtLoginEnabled = newValue
                                toggleLaunchAtLogin(enabled: newValue)
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Launch at System Startup")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text("Flowbar starts automatically when you turn on your computer.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                    .padding(12)
                    .background(CategorySurface.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(CategorySurface.border, lineWidth: 1)
                    }
                    
                    // 3. Otomatik Yedekleme Ayarları
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Automatic Backup", systemImage: "archivebox.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.accentColor)

                        // Frequency
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Backup Frequency")
                                .font(.caption)
                                .fontWeight(.medium)

                            Picker("", selection: $backupFrequency) {
                                Text("Off").tag("never")
                                Text("Weekly").tag("weekly")
                                Text("Monthly").tag("monthly")
                            }
                            .pickerStyle(.segmented)
                            .controlSize(.small)
                        }

                        Divider().padding(.vertical, 2)

                        // Folder
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Backup Folder")
                                .font(.caption)
                                .fontWeight(.medium)

                            HStack {
                                Text(backupDirectoryPath.isEmpty ? String(localized: "No folder selected") : backupDirectoryPath)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                Spacer()

                                Button(backupDirectoryPath.isEmpty ? "Choose Folder..." : "Change...") {
                                    selectBackupDirectory()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }

                        if !backupDirectoryPath.isEmpty && backupFrequency != "never" {
                            Divider().padding(.vertical, 2)

                            HStack {
                                Text("Last Backup:")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(formattedLastBackupDate())
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .padding(12)
                    .background(CategorySurface.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(CategorySurface.border, lineWidth: 1)
                    }
                    
                    // 4. Veri İstatistikleri ve Yönetimi
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Data & Storage", systemImage: "database.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.accentColor)

                        // Stats grid
                        VStack(spacing: 6) {
                            statRow(label: String(localized: "Total Projects"), value: "\(allProjects.count)")
                            statRow(label: String(localized: "Total Sessions"), value: "\(allSessions.count)")
                            statRow(label: String(localized: "Total Categories"), value: "\(allCategories.count)")
                            statRow(label: String(localized: "Reminders (Pending/Completed)"), value: "\(allReminders.filter { !$0.isCompleted }.count) / \(allReminders.filter { $0.isCompleted }.count)")
                        }
                        .padding(.vertical, 4)

                        // Export buttons
                        HStack(spacing: 8) {
                            Text("Export Data:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Button {
                                exportSessionsToCSV()
                            } label: {
                                Label("CSV (Excel)", systemImage: "tablecells.fill")
                                    .font(.caption2)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(allSessions.isEmpty)
                            
                            Button {
                                exportSessionsToJSON()
                            } label: {
                                Label("JSON", systemImage: "curlybraces")
                                    .font(.caption2)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(allSessions.isEmpty)
                        }
                        .padding(.vertical, 2)
                        
                        Divider()
                        
                        if showDeleteConfirm {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("WARNING: All saved sessions, projects and reminders will be permanently deleted. This action cannot be undone!")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                                    .fontWeight(.semibold)
                                    .fixedSize(horizontal: false, vertical: true)

                                HStack(spacing: 8) {
                                    TextField(String(localized: "Type '\(resetKeyword)' to confirm"), text: $deleteConfirmText)
                                        .textFieldStyle(.roundedBorder)
                                        .controlSize(.small)

                                    Button("Cancel") {
                                        withAnimation(.snappy(duration: 0.16)) {
                                            showDeleteConfirm = false
                                            deleteConfirmText = ""
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)

                                    Button("Reset", role: .destructive) {
                                        resetDatabase()
                                        withAnimation(.snappy(duration: 0.16)) {
                                            showDeleteConfirm = false
                                            deleteConfirmText = ""
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                    .disabled(deleteConfirmText != resetKeyword)
                                }
                            }
                            .padding(8)
                            .background(Color.red.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
                            }
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.98)),
                                removal: .opacity
                            ))
                        } else {
                            HStack {
                                Button("Clear Completed Reminders") {
                                    clearCompletedReminders()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(allReminders.filter { $0.isCompleted }.isEmpty)

                                Spacer()

                                Button("Reset All Data", role: .destructive) {
                                    withAnimation(.snappy(duration: 0.16)) {
                                        showDeleteConfirm = true
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                    .padding(12)
                    .background(CategorySurface.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(CategorySurface.border, lineWidth: 1)
                    }
                    
                    // 4. Hakkında ve Görünüm
                    VStack(alignment: .leading, spacing: 6) {
                        Label("About", systemImage: "info.circle.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.accentColor)

                        Text("Flowbar v1.1")
                            .font(.caption)
                            .fontWeight(.bold)
                        Text("An advanced weekly time planner and reminder menu bar tool. Automatically follows the macOS system appearance (Light/Dark mode).")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(CategorySurface.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(CategorySurface.border, lineWidth: 1)
                    }
                    
                    // 5. Geliştirici & Topluluk
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Developer & Community", systemImage: "person.2.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.accentColor)

                        Text("Flowbar is an open source project. Visit our GitHub page to contribute or report issues you run into.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 8) {
                            Link(destination: URL(string: "https://github.com/hasanyazarr/flowbar")!) {
                                Label("GitHub Project", systemImage: "arrow.up.forward.app.fill")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            Link(destination: URL(string: "https://github.com/hasanyazarr/flowbar/issues")!) {
                                Label("Report Issue", systemImage: "ladybug.fill")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            Spacer()
                            
                            Button {
                                restartApp()
                            } label: {
                                Label("Restart", systemImage: "arrow.clockwise")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button(role: .destructive) {
                                quitApp()
                            } label: {
                                Label("Quit", systemImage: "power")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(12)
                    .background(CategorySurface.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(CategorySurface.border, lineWidth: 1)
                    }
                }
            }
        }
        .onAppear {
            checkNotificationStatus()
        }
    }
    
    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .monospacedDigit()
        }
    }
    
    // Bildirim izin durumunu kontrol eder
    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized:
                    self.notificationStatus = String(localized: "Granted ✓")
                case .denied:
                    self.notificationStatus = String(localized: "Denied ✗")
                case .notDetermined:
                    self.notificationStatus = String(localized: "Not determined ?")
                case .provisional:
                    self.notificationStatus = String(localized: "Provisional")
                case .ephemeral:
                    self.notificationStatus = String(localized: "Ephemeral")
                @unknown default:
                    self.notificationStatus = String(localized: "Unknown")
                }
            }
        }
    }
    
    // Bildirim izni ister veya reddedildiyse sistem ayarlarına yönlendirir
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .denied {
                    // İzin reddedildiyse kullanıcıyı Sistem Ayarları -> Bildirimler sayfasına yönlendir
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                        NSWorkspace.shared.open(url)
                    }
                } else {
                    // İzin belirlenmediyse sistem pop-up'ını tetikle
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
                        self.checkNotificationStatus()
                    }
                }
            }
        }
    }
    
    // Tamamlanan hatırlatıcıları siler
    private func clearCompletedReminders() {
        withAnimation(.snappy(duration: 0.14)) {
            let completed = allReminders.filter { $0.isCompleted }
            for reminder in completed {
                context.delete(reminder)
            }
        }
    }
    
    // Tüm veritabanını sıfırlar
    private func resetDatabase() {
        withAnimation(.snappy(duration: 0.16)) {
            stopwatch.stop()
            
            // Tüm modelleri sil
            for session in allSessions { context.delete(session) }
            for project in allProjects { context.delete(project) }
            for category in allCategories { context.delete(category) }
            for reminder in allReminders { context.delete(reminder) }
            
            showDeleteConfirm = false
        }
    }
    
    // Başlangıçta otomatik çalıştırmayı açar/kapatır
    private func toggleLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            let appService = SMAppService.mainApp
            if enabled {
                do {
                    try appService.register()
                } catch {
                    print("Failed to register launch at login: \(error.localizedDescription)")
                    launchAtLoginEnabled = false
                }
            } else {
                do {
                    try appService.unregister()
                } catch {
                    print("Failed to unregister launch at login: \(error.localizedDescription)")
                    launchAtLoginEnabled = true
                }
            }
        }
    }
    
    // Oturumları CSV olarak dışa aktarır
    private func exportSessionsToCSV() {
        let sortedSessions = allSessions.sorted { $0.startedAt > $1.startedAt }
        
        var csvString = "Date,Project,Category,Note,Start,End,Measured Duration (Seconds),Logged Duration (Seconds),Logged Duration (Hours)\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        
        for session in sortedSessions {
            let dateStr = dateFormatter.string(from: session.startedAt)
            let projectStr = escapeCSVField(session.project?.name ?? "Uncategorized")
            let categoryStr = escapeCSVField(session.project?.category?.name ?? "None")
            let noteStr = escapeCSVField(session.note)
            let startStr = timeFormatter.string(from: session.startedAt)
            let endStr = timeFormatter.string(from: session.endedAt)
            let measuredSec = session.measuredSeconds
            let loggedSec = session.loggedSeconds
            let loggedHours = Double(loggedSec) / 3600.0
            let hoursStr = String(format: "%.2f", loggedHours)
            
            csvString += "\(dateStr),\(projectStr),\(categoryStr),\(noteStr),\(startStr),\(endStr),\(measuredSec),\(loggedSec),\(hoursStr)\n"
        }
        
        saveStringToFile(content: csvString, defaultFileName: "flowbar_sessions_export.csv")
    }
    
    // Oturumları JSON olarak dışa aktarır
    private func exportSessionsToJSON() {
        struct SessionJSON: Codable {
            let id: String
            let project: String?
            let category: String?
            let note: String
            let startedAt: String
            let endedAt: String
            let measuredSeconds: Int
            let loggedSeconds: Int
        }
        
        let isoFormatter = ISO8601DateFormatter()
        let sortedSessions = allSessions.sorted { $0.startedAt > $1.startedAt }
        
        let jsonSessions = sortedSessions.map { session in
            SessionJSON(
                id: session.id.uuidString,
                project: session.project?.name,
                category: session.project?.category?.name,
                note: session.note,
                startedAt: isoFormatter.string(from: session.startedAt),
                endedAt: isoFormatter.string(from: session.endedAt),
                measuredSeconds: session.measuredSeconds,
                loggedSeconds: session.loggedSeconds
            )
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(jsonSessions)
            if let jsonString = String(data: data, encoding: .utf8) {
                saveStringToFile(content: jsonString, defaultFileName: "flowbar_sessions_export.json")
            }
        } catch {
            print("JSON export encoding failed: \(error)")
        }
    }
    
    // CSV alanlarındaki özel karakterleri kaçış karakterleri ile sarmalar
    private func escapeCSVField(_ field: String) -> String {
        var escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\n") || escaped.contains("\"") {
            escaped = "\"\(escaped)\""
        }
        return escaped
    }
    
    // Veriyi NSSavePanel kullanarak dosyaya yazar
    private func saveStringToFile(content: String, defaultFileName: String) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = defaultFileName.hasSuffix(".csv") ? [UTType.commaSeparatedText] : [UTType.json]
        savePanel.nameFieldStringValue = defaultFileName
        savePanel.title = String(localized: "Save Data")
        savePanel.message = String(localized: "Choose where you want to save your Flowbar data.")
        
        // Modal diyalog açılmadan önce uygulamayı ön plana alarak odaklanmayı (focus) garanti ediyoruz
        NSApp.activate(ignoringOtherApps: true)
        
        let response = savePanel.runModal()
        if response == .OK, let url = savePanel.url {
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("File write error: \(error.localizedDescription)")
            }
        }
    }
    
    // Uygulamayı güvenli ve kesintisiz şekilde yeniden başlatır
    private func restartApp() {
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        
        let bundleURL = Bundle.main.bundleURL
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: config) { _, _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }

    // Uygulamadan tamamen çıkar (çalışan sayaç varsa önce durdurur)
    private func quitApp() {
        stopwatch.stop()
        NSApp.terminate(nil)
    }
    
    // Kullanıcıya yedekleme klasörü seçtirir ve yer işaretini kaydeder
    private func selectBackupDirectory() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        openPanel.canCreateDirectories = true // Kullanıcı dilerse yeni yedekleme alt klasörü oluşturabilsin
        openPanel.title = String(localized: "Choose Backup Folder")
        openPanel.message = String(localized: "Choose the folder where automatic backups will be saved.")
        
        // Modal diyalog açılmadan önce uygulamayı ön plana alarak odaklanmayı (focus) garanti ediyoruz
        NSApp.activate(ignoringOtherApps: true)
        
        let response = openPanel.runModal()
        if response == .OK, let url = openPanel.url {
            AutoBackupManager.shared.saveBookmark(url: url)
        }
    }
    
    // Son yedekleme tarihini biçimlendirip döndürür
    private func formattedLastBackupDate() -> String {
        guard lastBackupDate > 0 else { return String(localized: "No backup yet") }
        let date = Date(timeIntervalSince1970: lastBackupDate)
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("d MMMM yyyy, HH:mm")
        return formatter.string(from: date)
    }

    // The keyword the user must type to confirm a full data reset.
    private var resetKeyword: String { String(localized: "RESET") }

    // Applies the in-app language override. Persists AppleLanguages so the choice
    // survives relaunch; a restart is required for the UI to fully re-render.
    private func applyLanguage(_ language: String) {
        switch language {
        case "en":
            UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
        case "tr":
            UserDefaults.standard.set(["tr"], forKey: "AppleLanguages")
        default:
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
    }
}
