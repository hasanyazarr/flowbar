import XCTest
@testable import Flowbar

final class DurationTests: XCTestCase {
    func test_secondsToHoursMinutes() {
        let r = Duration.hoursMinutes(fromSeconds: 5000) // 1h 23m 20s
        XCTAssertEqual(r.hours, 1)
        XCTAssertEqual(r.minutes, 23)
    }

    func test_hoursMinutesToSeconds() {
        XCTAssertEqual(Duration.seconds(hours: 1, minutes: 23), 4980)
    }

    func test_stopwatchFormat() {
        XCTAssertEqual(Duration.stopwatch(seconds: 5000), "01:23:20")
        XCTAssertEqual(Duration.stopwatch(seconds: 0), "00:00:00")
    }

    func test_shortFormat() {
        XCTAssertEqual(Duration.short(seconds: 4980), "1h 23m")
        XCTAssertEqual(Duration.short(seconds: 600), "0h 10m")
    }

    func test_flooredToQuarter_roundsDownTo15() {
        // 1h 23m -> 1h 15m
        let a = Duration.flooredToQuarter(fromSeconds: Duration.seconds(hours: 1, minutes: 23))
        XCTAssertEqual(a.hours, 1)
        XCTAssertEqual(a.minutes, 15)

        // 1h 52m -> 1h 45m
        let b = Duration.flooredToQuarter(fromSeconds: Duration.seconds(hours: 1, minutes: 52))
        XCTAssertEqual(b.hours, 1)
        XCTAssertEqual(b.minutes, 45)

        // 0h 14m -> 0h 0m
        let c = Duration.flooredToQuarter(fromSeconds: Duration.seconds(hours: 0, minutes: 14))
        XCTAssertEqual(c.hours, 0)
        XCTAssertEqual(c.minutes, 0)
    }

    func test_flooredToQuarter_exactMultipleUnchanged() {
        let r = Duration.flooredToQuarter(fromSeconds: Duration.seconds(hours: 2, minutes: 45))
        XCTAssertEqual(r.hours, 2)
        XCTAssertEqual(r.minutes, 45)
    }

    func test_flooredToQuarter_zero() {
        let r = Duration.flooredToQuarter(fromSeconds: 0)
        XCTAssertEqual(r.hours, 0)
        XCTAssertEqual(r.minutes, 0)
    }
}
