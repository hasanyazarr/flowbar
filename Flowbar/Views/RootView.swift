import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("backgroundStyle") private var backgroundStyle = "glass"

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
                    Color(hex: "#101010") ?? Color.black
                }
            }
        )
        .preferredColorScheme(backgroundStyle == "matte" ? .dark : nil)
    }
}
