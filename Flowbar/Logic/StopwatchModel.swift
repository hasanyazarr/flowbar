import Foundation
import Combine

/// Pure, testable elapsed-time core. Derives elapsed seconds from wall-clock
/// timestamps rather than counting timer ticks, so it stays accurate across
/// sleep/wake and timer drift. Pausing freezes the elapsed value: any real time
/// that passes while paused (including the Mac sleeping) is excluded.
struct ElapsedClock {
    let startedAt: Date
    /// Total seconds spent paused across all prior pause/resume cycles.
    private(set) var accumulatedPausedSeconds: TimeInterval = 0
    /// When the current pause began, or nil if running.
    private(set) var pausedSince: Date?

    var isPaused: Bool { pausedSince != nil }

    init(startedAt: Date) {
        self.startedAt = startedAt
    }

    /// Begins a pause at `now`. No-op if already paused.
    mutating func pause(now: Date) {
        guard pausedSince == nil else { return }
        pausedSince = now
    }

    /// Ends the current pause at `now`, folding its duration into the paused
    /// total. No-op if not paused.
    mutating func resume(now: Date) {
        guard let pausedSince else { return }
        accumulatedPausedSeconds += now.timeIntervalSince(pausedSince)
        self.pausedSince = nil
    }

    /// Elapsed seconds as of `now`, excluding all paused time. While paused this
    /// stays fixed at the value reached when the pause began.
    func elapsedSeconds(now: Date) -> Int {
        let reference = pausedSince ?? now
        let elapsed = reference.timeIntervalSince(startedAt) - accumulatedPausedSeconds
        return max(0, Int(elapsed))
    }
}

@MainActor
final class StopwatchModel: ObservableObject {
    /// Wall-clock derived elapsed seconds. The timer only triggers a recompute;
    /// it never increments this directly, so the value stays correct across
    /// sleep/wake and timer drift.
    @Published private(set) var elapsedSeconds: Int = 0
    /// Sayaç bir oturum için aktif mi (çalışıyor veya duraklatılmış). Reset ile sıfırlanır.
    @Published private(set) var isActive: Bool = false
    /// Aktif oturum geçici olarak duraklatıldı mı.
    @Published private(set) var isPaused: Bool = false
    private var timer: Timer?
    private var clock: ElapsedClock?

    /// Aktif oturumun başlangıç tarihi (kaydetme için); oturum yoksa nil.
    var startedAt: Date? { clock?.startedAt }

    /// Sayaç şu an saniye sayıyor mu (aktif ve duraklatılmamış).
    var isRunning: Bool { timer != nil }

    /// Yeni bir oturum başlatır: süreyi sıfırlar ve saymaya başlar.
    func start() {
        guard timer == nil else { return }
        clock = ElapsedClock(startedAt: .now)
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
        clock?.pause(now: .now)
        isPaused = true
        tick()
    }

    /// Duraklatılmış oturumu kaldığı yerden sürdürür.
    func resume() {
        guard isActive, isPaused else { return }
        clock?.resume(now: .now)
        isPaused = false
        startTicking()
    }

    /// Oturumu durdurur (kaydetme öncesi). Süre korunur, sayma durur.
    func stop() {
        timer?.invalidate()
        timer = nil
        // Freeze the elapsed value so reads after stop stay stable, without
        // flipping the public isPaused flag (which means "user paused").
        if clock?.isPaused == false {
            clock?.pause(now: .now)
        }
        isPaused = false
        tick()
    }

    /// Sayacı tamamen sıfırlar.
    func reset() {
        timer?.invalidate()
        timer = nil
        clock = nil
        elapsedSeconds = 0
        isActive = false
        isPaused = false
    }

    private func startTicking() {
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    /// Recomputes `elapsedSeconds` from the wall clock.
    private func tick() {
        guard let clock else { return }
        elapsedSeconds = clock.elapsedSeconds(now: .now)
    }
}
