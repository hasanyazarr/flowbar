import Foundation
import Combine

@MainActor
final class StopwatchModel: ObservableObject {
    @Published private(set) var elapsedSeconds: Int = 0
    /// Sayaç bir oturum için aktif mi (çalışıyor veya duraklatılmış). Reset ile sıfırlanır.
    @Published private(set) var isActive: Bool = false
    /// Aktif oturum geçici olarak duraklatıldı mı.
    @Published private(set) var isPaused: Bool = false
    private var timer: Timer?
    private(set) var startedAt: Date?

    /// Sayaç şu an saniye sayıyor mu (aktif ve duraklatılmamış).
    var isRunning: Bool { timer != nil }

    /// Yeni bir oturum başlatır: süreyi sıfırlar ve saymaya başlar.
    func start() {
        guard timer == nil else { return }
        startedAt = .now
        elapsedSeconds = 0
        isActive = true
        isPaused = false
        startTicking()
    }

    /// Çalışan oturumu duraklatır; geçen süre korunur.
    func pause() {
        guard isActive, !isPaused else { return }
        timer?.invalidate()
        timer = nil
        isPaused = true
    }

    /// Duraklatılmış oturumu kaldığı yerden sürdürür.
    func resume() {
        guard isActive, isPaused else { return }
        isPaused = false
        startTicking()
    }

    /// Oturumu durdurur (kaydetme öncesi). Süre korunur, sayma durur.
    func stop() {
        timer?.invalidate()
        timer = nil
        isPaused = false
    }

    /// Sayacı tamamen sıfırlar.
    func reset() {
        stop()
        elapsedSeconds = 0
        startedAt = nil
        isActive = false
    }

    private func startTicking() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.elapsedSeconds += 1 }
        }
    }
}
