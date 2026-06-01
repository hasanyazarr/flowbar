import SwiftUI
import SwiftData

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("backgroundStyle") private var backgroundStyle = "glass"
    @Query(sort: \Session.endedAt, order: .reverse) private var allSessions: [Session]

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
        .background(
            Group {
                if backgroundStyle == "matte" {
                    Color(nsColor: .windowBackgroundColor)
                }
            }
        )
        .onAppear {
            AutoBackupManager.shared.checkAndRunBackup(sessions: allSessions)
        }
    }
}
