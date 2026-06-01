import Foundation
import Combine

@MainActor
final class StopwatchModel: ObservableObject {
    @Published private(set) var elapsedSeconds: Int = 0
    private var timer: Timer?
    private(set) var startedAt: Date?

    var isRunning: Bool { timer != nil }

    func start() {
        guard timer == nil else { return }
        startedAt = .now
        elapsedSeconds = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.elapsedSeconds += 1 }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func reset() {
        stop()
        elapsedSeconds = 0
        startedAt = nil
    }
}
