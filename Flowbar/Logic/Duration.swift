import Foundation

enum Duration {
    static func hoursMinutes(fromSeconds seconds: Int) -> (hours: Int, minutes: Int) {
        (seconds / 3600, (seconds % 3600) / 60)
    }

    static func seconds(hours: Int, minutes: Int) -> Int {
        hours * 3600 + minutes * 60
    }

    static func stopwatch(seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    static func short(seconds: Int) -> String {
        let (h, m) = hoursMinutes(fromSeconds: seconds)
        return String(localized: "\(h)h \(m)m", comment: "Compact duration, e.g. '3h 15m'")
    }

    /// Rounds the duration down to the nearest 15-minute slot (never logs more than measured).
    static func flooredToQuarter(fromSeconds seconds: Int) -> (hours: Int, minutes: Int) {
        let totalMinutes = seconds / 60
        let flooredMinutes = (totalMinutes / 15) * 15
        return (flooredMinutes / 60, flooredMinutes % 60)
    }
}
