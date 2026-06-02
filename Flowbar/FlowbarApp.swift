import SwiftUI
import SwiftData

@main
struct WeeklyMenubarApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var stopwatch = StopwatchModel()
    
    @AppStorage("menuBarDisplayMode") private var menuBarDisplayMode = "iconAndTimer"

    let container = PersistenceController.makeContainer()

    var body: some Scene {
        MenuBarExtra {
            RootView()
                .environmentObject(appState)
                .environmentObject(stopwatch)
                .modelContainer(container)
        } label: {
            if stopwatch.isActive {
                let symbol = stopwatch.isPaused ? "⏸" : "⏱"
                switch menuBarDisplayMode {
                case "timerOnly":
                    Text(Duration.stopwatch(seconds: stopwatch.elapsedSeconds))
                case "iconOnly":
                    Image(systemName: stopwatch.isPaused ? "pause.circle" : "timer")
                default:
                    Text("\(symbol) \(Duration.stopwatch(seconds: stopwatch.elapsedSeconds))")
                }
            } else {
                Image(systemName: "timer")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
