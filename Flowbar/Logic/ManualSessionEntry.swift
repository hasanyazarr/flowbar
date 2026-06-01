import Foundation

/// Geçmişe dönük (stopwatch çalışmadan) elle girilen oturum.
/// Süre + seçilen gün alır; oturumu seçilen günün sonuna yerleştirir,
/// böylece geçmiş listesinde (endedAt'e göre sıralı) doğru güne düşer.
struct ManualSessionEntry {
    var note: String
    var hours: Int
    var minutes: Int
    /// Oturumun yapıldığı gün. Saat bilgisi yok sayılır; sadece takvim günü kullanılır.
    var day: Date

    var loggedSeconds: Int {
        Duration.seconds(hours: hours, minutes: minutes)
    }

    var canSave: Bool {
        loggedSeconds >= 60
    }

    /// Elle girilen oturumu üretir.
    /// - measuredSeconds = 0 (hiç ölçülmedi → elle giriş işareti)
    /// - endedAt = seçilen günün son anı, startedAt = endedAt − süre
    func makeSession(project: Project, calendar: Calendar = .current) -> Session {
        let endOfDay = Self.endOfDay(for: day, calendar: calendar)
        let started = endOfDay.addingTimeInterval(-Double(loggedSeconds))
        return Session(
            note: note,
            measuredSeconds: 0,
            loggedSeconds: loggedSeconds,
            startedAt: started,
            endedAt: endOfDay,
            project: project
        )
    }

    static func endOfDay(for day: Date, calendar: Calendar) -> Date {
        let startOfDay = calendar.startOfDay(for: day)
        // Günün son anı: ertesi günün başından 1 saniye geri.
        let startOfNextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        return startOfNextDay.addingTimeInterval(-1)
    }
}

/// Var olan bir oturumu düzenlemek için form modeli.
/// Mevcut değerleri okur, değişiklikleri oturuma geri uygular.
struct SessionEdit {
    var note: String
    var hours: Int
    var minutes: Int
    var projectID: UUID?
    /// Oturumun bittiği gün (tarih seçici için). Saati korunur.
    var day: Date

    private let originalEndedAt: Date

    init(session: Session) {
        self.note = session.note
        let (h, m) = Duration.hoursMinutes(fromSeconds: session.loggedSeconds)
        self.hours = h
        self.minutes = m
        self.projectID = session.project?.id
        self.day = session.endedAt
        self.originalEndedAt = session.endedAt
    }

    var loggedSeconds: Int {
        Duration.seconds(hours: hours, minutes: minutes)
    }

    var canSave: Bool {
        loggedSeconds >= 60
    }

    /// Düzenlemeyi oturuma yazar. measuredSeconds korunur (canlı oturumlarda gerçek ölçüm).
    /// endedAt: seçilen günün takvim günü + orijinal saat; startedAt = endedAt − yeni süre.
    func apply(to session: Session, project: Project?, calendar: Calendar = .current) {
        session.note = note
        session.loggedSeconds = loggedSeconds
        session.project = project

        let endedAt = Self.combine(day: day, timeFrom: originalEndedAt, calendar: calendar)
        session.endedAt = endedAt
        session.startedAt = endedAt.addingTimeInterval(-Double(loggedSeconds))
    }

    /// `day`'in takvim gününü `timeFrom`'un saat/dakika/saniyesiyle birleştirir.
    private static func combine(day: Date, timeFrom: Date, calendar: Calendar) -> Date {
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: day)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: timeFrom)
        var merged = DateComponents()
        merged.year = dayComponents.year
        merged.month = dayComponents.month
        merged.day = dayComponents.day
        merged.hour = timeComponents.hour
        merged.minute = timeComponents.minute
        merged.second = timeComponents.second
        return calendar.date(from: merged) ?? day
    }
}
