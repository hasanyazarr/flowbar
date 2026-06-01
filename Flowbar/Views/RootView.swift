import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            switch appState.screen {
            case .home:
                HomeView()
            case .timer:
                TimerView()
            case .save:
                SaveView()
            }
        }
        .padding(12)
    }
}
