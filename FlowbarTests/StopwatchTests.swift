import XCTest
@testable import Flowbar

/// Tests for the wall-clock based elapsed-time core. The clock derives elapsed
/// seconds from real timestamps (Date) rather than counting timer ticks, so it
/// stays accurate across sleep/wake and timer drift.
final class StopwatchTests: XCTestCase {
    // Fixed reference instant for deterministic tests.
    private let t0 = Date(timeIntervalSinceReferenceDate: 1_000_000)

    private func at(_ seconds: TimeInterval) -> Date {
        t0.addingTimeInterval(seconds)
    }

    func test_runningElapsedIsWallClockDifference() {
        let clock = ElapsedClock(startedAt: t0)
        XCTAssertEqual(clock.elapsedSeconds(now: at(42)), 42)
    }

    func test_freshClockHasZeroElapsed() {
        let clock = ElapsedClock(startedAt: t0)
        XCTAssertEqual(clock.elapsedSeconds(now: t0), 0)
    }

    func test_pauseFreezesElapsedRegardlessOfWallClock() {
        var clock = ElapsedClock(startedAt: t0)
        clock.pause(now: at(30))
        // Wall clock advances a lot (e.g. the Mac slept) but elapsed stays frozen.
        XCTAssertEqual(clock.elapsedSeconds(now: at(5000)), 30)
    }

    func test_resumeExcludesPausedInterval() {
        var clock = ElapsedClock(startedAt: t0)
        clock.pause(now: at(30))
        clock.resume(now: at(100)) // paused for 70s
        // At 130s wall time, 70s was paused, so 60s counted.
        XCTAssertEqual(clock.elapsedSeconds(now: at(130)), 60)
    }

    func test_multiplePauseResumeCyclesAccumulate() {
        var clock = ElapsedClock(startedAt: t0)
        clock.pause(now: at(10))   // ran 10s
        clock.resume(now: at(40))  // paused 30s
        clock.pause(now: at(60))   // ran 20s more (total ran 30s)
        clock.resume(now: at(200)) // paused 140s
        // Total paused = 30 + 140 = 170s. At 250s wall time -> 250 - 170 = 80s.
        XCTAssertEqual(clock.elapsedSeconds(now: at(250)), 80)
    }

    func test_elapsedWhilePausedReflectsRunTimeBeforePause() {
        var clock = ElapsedClock(startedAt: t0)
        clock.pause(now: at(45))
        XCTAssertTrue(clock.isPaused)
        XCTAssertEqual(clock.elapsedSeconds(now: at(45)), 45)
    }

    func test_doublePauseIsIgnored() {
        var clock = ElapsedClock(startedAt: t0)
        clock.pause(now: at(30))
        clock.pause(now: at(40)) // already paused; second pause must be a no-op
        clock.resume(now: at(100))
        XCTAssertEqual(clock.elapsedSeconds(now: at(130)), 60)
    }

    func test_resumeWhileRunningIsIgnored() {
        var clock = ElapsedClock(startedAt: t0)
        clock.resume(now: at(50)) // not paused; must be a no-op
        XCTAssertEqual(clock.elapsedSeconds(now: at(50)), 50)
    }
}
