import SwiftUI
import SwiftData

struct SessionCompletionLayout {
    static let durationValueWidth: CGFloat = 90
    static let stepperWidth: CGFloat = 42
    static let noteMinHeight: CGFloat = 70
}

struct SessionSaveDraft {
    var note: String
    var hours: Int
    var minutes: Int

    var loggedSeconds: Int {
        Duration.seconds(hours: hours, minutes: minutes)
    }

    var canSave: Bool {
        loggedSeconds >= 60
    }

    func makeSession(measuredSeconds: Int, startedAt: Date, endedAt: Date, project: Project) -> Session {
        Session(note: note, measuredSeconds: measuredSeconds,
                loggedSeconds: loggedSeconds, startedAt: startedAt,
                endedAt: endedAt, project: project)
    }
}

struct SaveView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var stopwatch: StopwatchModel
    @Environment(\.modelContext) private var context
    @Query private var projects: [Project]

    @State private var hours = 0
    @State private var minutes = 0
    @State private var sessionNote = ""
    @State private var didInit = false

    private var project: Project? {
        projects.first { $0.id == appState.activeProjectID }
    }
    private var measured: Int { stopwatch.elapsedSeconds }
    private var draft: SessionSaveDraft {
        SessionSaveDraft(note: sessionNote, hours: hours, minutes: minutes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(project?.name ?? "—").font(.headline)
            TextField("Oturum notu", text: $sessionNote, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2...4)
                .frame(minHeight: SessionCompletionLayout.noteMinHeight, alignment: .topLeading)
            Text("Ölçülen: \(Duration.short(seconds: measured))")
                .font(.caption).foregroundStyle(.secondary)

            HStack(spacing: 18) {
                HStack(spacing: 6) {
                    Text("\(hours) saat")
                        .monospacedDigit()
                        .frame(width: SessionCompletionLayout.durationValueWidth, alignment: .leading)
                    Stepper(value: $hours, in: 0...23) { EmptyView() }
                        .labelsHidden()
                        .frame(width: SessionCompletionLayout.stepperWidth)
                }

                HStack(spacing: 6) {
                    Text("\(minutes) dk")
                        .monospacedDigit()
                        .frame(width: SessionCompletionLayout.durationValueWidth, alignment: .leading)
                    Stepper {
                        EmptyView()
                    } onIncrement: {
                        if minutes >= 45 {
                            if hours < 23 { hours += 1; minutes = 0 }
                        } else {
                            minutes += 15
                        }
                    } onDecrement: {
                        if minutes == 0 {
                            if hours > 0 { hours -= 1; minutes = 45 }
                        } else {
                            minutes -= 15
                        }
                    }
                    .labelsHidden()
                    .frame(width: SessionCompletionLayout.stepperWidth)
                }
            }

            HStack {
                Button("İptal") { finish() }
                Spacer()
                Button("Kaydet") { save() }
                    .disabled(!draft.canSave)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .onAppear {
            guard !didInit else { return }
            let (h, m) = Duration.flooredToQuarter(fromSeconds: measured)
            hours = h; minutes = m; sessionNote = appState.activeNote; didInit = true
        }
    }

    private func save() {
        guard let project else { finish(); return }
        let start = stopwatch.startedAt ?? .now
        let s = draft.makeSession(measuredSeconds: measured, startedAt: start, endedAt: .now, project: project)
        context.insert(s)
        finish()
    }

    private func finish() {
        stopwatch.reset()
        appState.activeProjectID = nil
        appState.activeNote = ""
        appState.screen = .home
    }
}
