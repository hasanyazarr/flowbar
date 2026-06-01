import SwiftUI
import SwiftData

struct TimerView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var stopwatch: StopwatchModel
    @Query private var projects: [Project]

    private var projectName: String {
        projects.first { $0.id == appState.activeProjectID }?.name ?? "—"
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(projectName).font(.headline)
            if !appState.activeNote.isEmpty {
                Text(appState.activeNote)
                    .font(.callout).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Text(Duration.stopwatch(seconds: stopwatch.elapsedSeconds))
                .font(.system(size: 34, weight: .semibold, design: .monospaced))
            Button("Durdur") {
                stopwatch.stop()
                appState.screen = .save
            }
            .keyboardShortcut(.defaultAction)
        }
    }
}
