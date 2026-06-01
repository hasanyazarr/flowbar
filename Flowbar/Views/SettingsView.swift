import SwiftUI
import SwiftData
import UserNotifications
import ServiceManagement

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject var stopwatch: StopwatchModel
    
    @Query private var allProjects: [Project]
    @Query private var allSessions: [Session]
    @Query private var allReminders: [Reminder]
    @Query private var allCategories: [Category]
    
    let onBack: () -> Void
    
    @AppStorage("menuBarDisplayMode") private var menuBarDisplayMode = "iconAndTimer"
    
    @State private var showDeleteConfirm = false
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
                    
                    // 3. Veri İstatistikleri ve Yönetimi
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
                        
                        Divider()
                        
                        HStack {
                            Button("Tamamlanan Hatırlatıcıları Temizle") {
                                clearCompletedReminders()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(allReminders.filter { $0.isCompleted }.isEmpty)
                            
                            Spacer()
                            
                            if showDeleteConfirm {
                                HStack(spacing: 8) {
                                    Button("Vazgeç") {
                                        showDeleteConfirm = false
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    
                                    Button("Tümünü Sıfırla", role: .destructive) {
                                        resetDatabase()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                }
                            } else {
                                Button("Tüm Verileri Sıfırla", role: .destructive) {
                                    showDeleteConfirm = true
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
}
