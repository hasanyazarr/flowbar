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
        return "\(h)s \(m)dk"
    }

    /// Süreyi aşağı doğru en yakın 15 dakikalık dilime yuvarlar (ölçülenden fazla loglamaz).
    static func flooredToQuarter(fromSeconds seconds: Int) -> (hours: Int, minutes: Int) {
        let totalMinutes = seconds / 60
        let flooredMinutes = (totalMinutes / 15) * 15
        return (flooredMinutes / 60, flooredMinutes % 60)
    }
}
