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
    
    @State private var showDeleteConfirm = false
    @State private var deleteConfirmText = ""
    @State private var notificationStatus: String = "Kontrol ediliyor…"
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
                        Text("Geri")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
                
                Text("Ayarlar")
                    .font(.headline)
                
                Spacer()
                
                // Simetri sağlamak için boş bir alan
                Spacer().frame(width: 50)
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 1. Sistem Bildirimleri
                    VStack(alignment: .leading, spacing: 8) {
                        Label("macOS Bildirimleri", systemImage: "bell.badge.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.accentColor)
                        
                        Text("Hatırlatıcı zamanı geldiğinde yerel bildirim alabilmeniz için sistem izinlerinin açık olması gerekir.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            Text("İzin Durumu: \(notificationStatus)")
                                .font(.caption2)
                                .fontWeight(.bold)
                            Spacer()
                            Button("İzin İste / Yenile") {
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
                        Label("Genel Tercihler", systemImage: "sliders.horizontal.3")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.accentColor)
                        
                        // Menü Bar Tercihi
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Menü Bar Gösterimi")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            Picker("", selection: $menuBarDisplayMode) {
                                Text("Simge ve Süre").tag("iconAndTimer")
                                Text("Yalnızca Süre").tag("timerOnly")
                                Text("Yalnızca Simge").tag("iconOnly")
                            }
                            .pickerStyle(.segmented)
                            .controlSize(.small)
                            
                            Text("Sayaç çalışırken menü barında ne görüntüleneceğini ayarlar.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        
                        Divider().padding(.vertical, 2)
                        
                        // Arka Plan Stili Tercihi
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pencere Görünümü")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            Picker("", selection: $backgroundStyle) {
                                Text("Cam (Glass)").tag("glass")
                                Text("Mat (Matte)").tag("matte")
                            }
                            .pickerStyle(.segmented)
                            .controlSize(.small)
                            
                            Text("Uygulama penceresinin arka plan stilini belirler.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        
                        Divider().padding(.vertical, 2)
                        
                        // Başlangıçta Otomatik Çalıştır
                        Toggle(isOn: Binding(
                            get: { launchAtLoginEnabled },
                            set: { newValue in
                                launchAtLoginEnabled = newValue
                                toggleLaunchAtLogin(enabled: newValue)
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sistem Açılışında Otomatik Başlat")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text("Bilgisayarınızı açtığınızda Flowbar kendiliğinden çalışır.")
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
                        Label("Otomatik Yedekleme", systemImage: "archivebox.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.accentColor)
                        
                        // Sıklık Seçimi
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Yedekleme Sıklığı")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            Picker("", selection: $backupFrequency) {
                                Text("Kapalı").tag("never")
                                Text("Haftalık").tag("weekly")
                                Text("Aylık").tag("monthly")
                            }
                            .pickerStyle(.segmented)
                            .controlSize(.small)
                        }
                        
                        Divider().padding(.vertical, 2)
                        
                        // Klasör Seçimi
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Yedekleme Klasörü")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            HStack {
                                Text(backupDirectoryPath.isEmpty ? "Klasör Seçilmedi" : backupDirectoryPath)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                
                                Spacer()
                                
                                Button(backupDirectoryPath.isEmpty ? "Klasör Seç..." : "Değiştir...") {
                                    selectBackupDirectory()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        
                        if !backupDirectoryPath.isEmpty && backupFrequency != "never" {
                            Divider().padding(.vertical, 2)
                            
                            HStack {
                                Text("Son Yedekleme:")
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
                        Label("Veri ve Depolama", systemImage: "database.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.accentColor)
                        
                        // İstatistikler Grid
                        VStack(spacing: 6) {
                            statRow(label: "Toplam Proje", value: "\(allProjects.count)")
                            statRow(label: "Toplam Oturum", value: "\(allSessions.count)")
                            statRow(label: "Toplam Kategori", value: "\(allCategories.count)")
                            statRow(label: "Hatırlatıcılar (Bekleyen/Tamamlanan)", value: "\(allReminders.filter { !$0.isCompleted }.count) / \(allReminders.filter { $0.isCompleted }.count)")
                        }
                        .padding(.vertical, 4)
                        
                        // Veri Aktarma Butonları
                        HStack(spacing: 8) {
                            Text("Verileri Aktar:")
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
                                Text("DİKKAT: Tüm kayıtlı oturumlar, projeler ve hatırlatıcılar kalıcı olarak silinecektir. Bu işlem geri alınamaz!")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                                    .fontWeight(.semibold)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                HStack(spacing: 8) {
                                    TextField("Onaylamak için 'SIFIRLA' yazın", text: $deleteConfirmText)
                                        .textFieldStyle(.roundedBorder)
                                        .controlSize(.small)
                                    
                                    Button("Vazgeç") {
                                        withAnimation(.snappy(duration: 0.16)) {
                                            showDeleteConfirm = false
                                            deleteConfirmText = ""
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    
                                    Button("Sıfırla", role: .destructive) {
                                        resetDatabase()
                                        withAnimation(.snappy(duration: 0.16)) {
                                            showDeleteConfirm = false
                                            deleteConfirmText = ""
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                    .disabled(deleteConfirmText != "SIFIRLA")
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
                                Button("Tamamlanan Hatırlatıcıları Temizle") {
                                    clearCompletedReminders()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(allReminders.filter { $0.isCompleted }.isEmpty)
                                
                                Spacer()
                                
                                Button("Tüm Verileri Sıfırla", role: .destructive) {
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
                        Label("Uygulama Hakkında", systemImage: "info.circle.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.accentColor)
                        
                        Text("Flowbar v1.1")
                            .font(.caption)
                            .fontWeight(.bold)
                        Text("Gelişmiş haftalık zaman planlayıcı ve hatırlatıcı menü bar aracı. macOS sistem görünümünü (Açık/Karanlık mod) otomatik takip eder.")
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
                        Label("Geliştirici & Topluluk", systemImage: "person.2.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.accentColor)
                        
                        Text("Flowbar açık kaynaklı bir projedir. Katkıda bulunmak veya karşılaştığınız sorunları bildirmek için GitHub sayfamızı ziyaret edin.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 8) {
                            Link(destination: URL(string: "https://github.com/hasanyazarr/flowbar")!) {
                                Label("GitHub Projesi", systemImage: "arrow.up.forward.app.fill")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            Link(destination: URL(string: "https://github.com/hasanyazarr/flowbar/issues")!) {
                                Label("Sorun Bildir", systemImage: "ladybug.fill")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            Spacer()
                            
                            Button {
                                restartApp()
                            } label: {
                                Label("Yeniden Başlat", systemImage: "arrow.clockwise")
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
                    self.notificationStatus = "İzin Verildi ✓"
                case .denied:
                    self.notificationStatus = "İzin Reddedildi ✗"
                case .notDetermined:
                    self.notificationStatus = "Belirlenmedi ?"
                case .provisional:
                    self.notificationStatus = "Geçici İzin"
                case .ephemeral:
                    self.notificationStatus = "Anlık İzin"
                @unknown default:
                    self.notificationStatus = "Bilinmiyor"
                }
            }
        }
    }
    
    // Bildirim izni ister
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            checkNotificationStatus()
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
                    print("Otomatik başlatma kaydedilemedi: \(error.localizedDescription)")
                    launchAtLoginEnabled = false
                }
            } else {
                do {
                    try appService.unregister()
                } catch {
                    print("Otomatik başlatma kaydı silinemedi: \(error.localizedDescription)")
                    launchAtLoginEnabled = true
                }
            }
        }
    }
    
    // Oturumları CSV olarak dışa aktarır
    private func exportSessionsToCSV() {
        let sortedSessions = allSessions.sorted { $0.startedAt > $1.startedAt }
        
        var csvString = "Tarih,Proje,Kategori,Not,Baslangic,Bitis,Olculen Sure (Saniye),Kaydedilen Sure (Saniye),Kaydedilen Sure (Saat)\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        
        for session in sortedSessions {
            let dateStr = dateFormatter.string(from: session.startedAt)
            let projectStr = escapeCSVField(session.project?.name ?? "Kategorisiz")
            let categoryStr = escapeCSVField(session.project?.category?.name ?? "Yok")
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
        savePanel.title = "Verileri Kaydet"
        savePanel.message = "Flowbar verilerini kaydetmek istediğiniz konumu seçin."
        
        // Modal diyalog açılmadan önce uygulamayı ön plana alarak odaklanmayı (focus) garanti ediyoruz
        NSApp.activate(ignoringOtherApps: true)
        
        let response = savePanel.runModal()
        if response == .OK, let url = savePanel.url {
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("Dosya yazma hatası: \(error.localizedDescription)")
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
    
    // Kullanıcıya yedekleme klasörü seçtirir ve yer işaretini kaydeder
    private func selectBackupDirectory() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        openPanel.canCreateDirectories = true // Kullanıcı dilerse yeni yedekleme alt klasörü oluşturabilsin
        openPanel.title = "Yedekleme Klasörünü Seçin"
        openPanel.message = "Otomatik yedeklerin kaydedileceği klasörü seçin."
        
        // Modal diyalog açılmadan önce uygulamayı ön plana alarak odaklanmayı (focus) garanti ediyoruz
        NSApp.activate(ignoringOtherApps: true)
        
        let response = openPanel.runModal()
        if response == .OK, let url = openPanel.url {
            AutoBackupManager.shared.saveBookmark(url: url)
        }
    }
    
    // Son yedekleme tarihini biçimlendirip döndürür
    private func formattedLastBackupDate() -> String {
        guard lastBackupDate > 0 else { return "Henüz yedek alınmadı" }
        let date = Date(timeIntervalSince1970: lastBackupDate)
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy, HH:mm"
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: date)
    }
}
