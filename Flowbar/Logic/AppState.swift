import Foundation
import Combine

enum Screen: Equatable {
    case home
    case timer
    case save
}

@MainActor
final class AppState: ObservableObject {
    @Published var screen: Screen = .home
    // Aktif oturumun bağlamı (timer/save ekranları için)
    @Published var activeProjectID: UUID?
    @Published var activeNote: String = ""
}
