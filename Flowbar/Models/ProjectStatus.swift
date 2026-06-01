import Foundation

enum ProjectStatus: String, Codable, CaseIterable {
    case inProgress
    case continuous
    case paused
    case done

    var label: String {
        switch self {
        case .inProgress: return "In progress"
        case .continuous: return "Continuous"
        case .paused: return "Paused"
        case .done: return "Done"
        }
    }

    var colorHex: String {
        switch self {
        case .inProgress: return "#98C379" // green
        case .continuous: return "#61AFEF" // blue
        case .paused: return "#E06C75"     // red
        case .done: return "#56B6C2"       // teal
        }
    }
}
