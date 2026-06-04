import SwiftUI
import SwiftData

private enum HomeTab: String, CaseIterable {
    case session
    case projects
    case history
    case analytics
    case remind

    var title: String {
        switch self {
        case .session: return String(localized: "Session")
        case .projects: return String(localized: "Projects")
        case .history: return String(localized: "History")
        case .analytics: return String(localized: "Analytics")
        case .remind: return String(localized: "Remind")
        }
    }

    var icon: String {
        switch self {
        case .session: return "timer"
        case .projects: return "folder"
        case .history: return "clock.arrow.circlepath"
        case .analytics: return "chart.bar.xaxis"
        case .remind: return "bell"
        }
    }

    var layoutKind: PopoverTabKind {
        switch self {
        case .session:
            return .session
        case .projects:
            return .projects
        case .history:
            return .history
        case .analytics:
            return .analytics
        case .remind:
            return .remind
        }
    }
}

/// Aktif oturum ekranının görünüm seçenekleri. Ayarlardan seçilir
/// (@AppStorage "timerLayout"). Sayaç boyutu ve popover yüksekliği presete bağlı.
enum TimerLayout: String, CaseIterable, Identifiable {
    case card      // Mevcut: proje + kategori + not + sayaç + iki buton
    case focus     // Sade: devasa sayaç, minimum bilgi
    case compact   // Yoğun: küçük sayaç, sıkı yerleşim

    var id: String { rawValue }

    static func from(_ raw: String) -> TimerLayout {
        TimerLayout(rawValue: raw) ?? .card
    }

    var title: String {
        switch self {
        case .card: return String(localized: "Card")
        case .focus: return String(localized: "Focus")
        case .compact: return String(localized: "Compact")
        }
    }

    /// Canlı sayacın punto boyutu.
    var timerFontSize: CGFloat {
        switch self {
        case .card: return 34
        case .focus: return 56
        case .compact: return 24
        }
    }

    /// Aktif oturumdayken popover yüksekliği.
    var popoverHeight: CGFloat {
        switch self {
        case .card: return 260
        case .focus: return 240
        case .compact: return 200
        }
    }
}

/// Custom segmented tab bar. Icons sit in a pill; the selected tab is marked by a
/// filled accent capsule that slides between tabs (matchedGeometryEffect). Hovering
/// a tab smoothly expands it to reveal the tab's full name beside the icon.
private struct HomeTabBar: View {
    @Binding var selection: HomeTab
    @State private var hovered: HomeTab?
    @Namespace private var capsuleNamespace

    var body: some View {
        HStack(spacing: 2) {
            ForEach(HomeTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(2)
        .background(Color.secondary.opacity(0.14))
        .clipShape(Capsule())
        .animation(.snappy(duration: 0.22), value: selection)
        .animation(.snappy(duration: 0.22), value: hovered)
    }

    private func tabButton(_ tab: HomeTab) -> some View {
        let isSelected = selection == tab
        let isHovered = hovered == tab
        // Show the label when hovered, or for the selected tab while nothing is hovered.
        let showsLabel = isHovered || (isSelected && hovered == nil)

        return Button {
            selection = tab
        } label: {
            HStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12, weight: .semibold))

                if showsLabel {
                    Text(tab.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .fixedSize()
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .leading)),
                            removal: .opacity
                        ))
                }
            }
            .foregroundStyle(isSelected ? Color.white : .secondary)
            .padding(.horizontal, showsLabel ? 10 : 8)
            .padding(.vertical, 5)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.accentColor)
                        .matchedGeometryEffect(id: "selectedCapsule", in: capsuleNamespace)
                } else if isHovered {
                    Capsule()
                        .fill(Color.secondary.opacity(0.18))
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hovered = hovering ? tab : (hovered == tab ? nil : hovered)
        }
        .help(tab.title)
    }
}

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var stopwatch: StopwatchModel
    @Environment(\.modelContext) private var context
    @Query(sort: \Project.createdAt) private var allProjects: [Project]
    @Query(sort: \Session.endedAt) private var allSessions: [Session]
    @Query(sort: \Category.name) private var categories: [Category]

    @State private var selectedTab: HomeTab = .session
    @State private var showManualEntry = false
    @State private var editingSessionID: UUID?
    @State private var manualProjectID: UUID?
    @State private var manualNote = ""
    @State private var manualHours = 0
    @State private var manualMinutes = 0
    @State private var manualDay = Date.now
    @State private var newProjectName = ""
    @State private var selectedProjectID: UUID?
    @State private var expandedProjectID: UUID?
    @State private var note = ""
    @State private var nameError: String?
    @State private var search = ""
    @State private var managementSearch = ""
    @State private var filterCategoryID: UUID?
    @State private var showFilters = false
    @State private var showCategories = false
    @State private var newCategoryName = ""
    @State private var newCategoryColorHex = CategoryPalette.defaultHex
    @State private var editingCategoryID: UUID?
    @State private var categoryError: String?
    @State private var showSettings = false
    @AppStorage("timerLayout") private var timerLayoutRaw = TimerLayout.card.rawValue
    @AppStorage("projectsViewMode") private var projectsViewMode = "list"

    private var timerLayout: TimerLayout { TimerLayout.from(timerLayoutRaw) }

    private var activeProjects: [Project] {
        ProjectFiltering.active(allProjects)
    }

    private var pickerProjects: [Project] {
        let base = ProjectFiltering.filtered(activeProjects, query: search)
        return search.trimmingCharacters(in: .whitespaces).isEmpty
            ? ProjectFiltering.recencySorted(base)
            : base
    }

    private var managementProjects: [Project] {
        let byCategory = ProjectFiltering.filtered(activeProjects, categoryID: filterCategoryID)
        return ProjectFiltering.filtered(byCategory, query: managementSearch)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var historySessions: [Session] {
        SessionHistory.latest(allSessions)
    }

    private var selectedProject: Project? {
        guard let selectedProjectID else { return nil }
        return activeProjects.first { $0.id == selectedProjectID }
    }

    private var selectedProjectRecentSessions: [Session] {
        SessionHistory.recent(for: selectedProjectID, from: allSessions, limit: 3)
    }

    private var editingCategory: Category? {
        guard let editingCategoryID else { return nil }
        return categories.first { $0.id == editingCategoryID }
    }

    private var projectPickerRowCount: Int {
        guard !activeProjects.isEmpty else { return 1 }
        return min(max(pickerProjects.count, 1), 4)
    }

    private var projectPickerHeight: CGFloat {
        CGFloat(projectPickerRowCount) * PopoverLayout.sessionProjectRowHeight
    }

    private var popoverSize: CGSize {
        if showSettings {
            return CGSize(width: 480, height: 400)
        }
        switch selectedTab {
        case .session:
            if stopwatch.isActive {
                return CGSize(width: 480, height: timerLayout.popoverHeight)
            } else {
                return PopoverLayout.sessionSize(
                    projectRowCount: projectPickerRowCount,
                    recentSessionCount: selectedProjectRecentSessions.count
                )
            }
        case .projects:
            return PopoverLayout.size(for: .projects)
        case .history:
            return PopoverLayout.historySize(showsManualEntryForm: showManualEntry)
        case .analytics:
            return PopoverLayout.size(for: .analytics)
        case .remind:
            return PopoverLayout.size(for: .remind)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showSettings {
                SettingsView {
                    withAnimation(.snappy(duration: 0.18)) {
                        showSettings = false
                    }
                }
                .environmentObject(stopwatch)
            } else {
                HStack(spacing: 8) {
                    Text("Flowbar")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.leading, 2)
                    
                    Spacer()

                    HomeTabBar(selection: $selectedTab)

                    Button {
                        withAnimation(.snappy(duration: 0.18)) {
                            showSettings = true
                        }
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.body)
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .hoverHighlight()
                }
                .frame(maxWidth: .infinity)

                switch selectedTab {
                case .session:
                    sessionTab
                case .projects:
                    projectsTab
                case .history:
                    historyTab
                case .analytics:
                    AnalyticsView()
                case .remind:
                    RemindView()
                }
            }
        }
        .frame(width: popoverSize.width, height: popoverSize.height, alignment: .topLeading)
        .animation(.snappy(duration: 0.18), value: selectedTab)
        .animation(.snappy(duration: 0.18), value: showSettings)
        .hidesScrollIndicators()
        .onDisappear {
            // Menübar pop'u kapanınca sekmeyi sıfırla; bir sonraki açılış hep
            // Session sekmesinden başlasın (kullanıcı History/Analytics'te
            // bırakıp kapatsa bile "takılı" kalmasın).
            selectedTab = .session
            showSettings = false
        }
    }

    private var sessionTab: some View {
        Group {
            if stopwatch.isActive {
                activeSessionCard
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Start a new session").font(.headline)
                        Spacer()
                        if let selectedProject {
                            Text(selectedProject.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    SearchField(text: $search, placeholder: String(localized: "Search projects…"))

                    if activeProjects.isEmpty {
                        Text("No projects yet, add one")
                            .foregroundStyle(.secondary).font(.callout)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(pickerProjects) { p in
                                    Button {
                                        selectedProjectID = p.id
                                    } label: {
                                        ProjectPickerRow(project: p, isSelected: selectedProjectID == p.id)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(height: projectPickerHeight)
                    }

                    RecentSessionNotesView(sessions: selectedProjectRecentSessions)

                    SessionNoteEditor(text: $note)
                        .frame(height: PopoverLayout.sessionNoteMinHeight, alignment: .topLeading)

                    Button {
                        startSession()
                    } label: {
                        Text("Start")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(selectedProjectID == nil)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
    }

    private var activeProjectName: String {
        allProjects.first { $0.id == appState.activeProjectID }?.name ?? "—"
    }

    private var activeProjectCategory: Category? {
        allProjects.first { $0.id == appState.activeProjectID }?.category
    }

    @ViewBuilder
    private var activeSessionCard: some View {
        Group {
            switch timerLayout {
            case .card: cardLayout
            case .focus: focusLayout
            case .compact: compactLayout
            }
        }
        .padding(14)
        .background(Color.accentColor.opacity(0.06))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.accentColor.opacity(0.25), lineWidth: 1.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Active session layouts

    /// Mevcut tasarım: başlık + kategori + (varsa) odak notu + sayaç + iki buton.
    private var cardLayout: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    activeSessionLabel
                    Text(activeProjectName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
                Spacer()

                if let category = activeProjectCategory {
                    CategoryChip(name: category.name, hex: category.colorHex)
                }
            }

            if !appState.activeNote.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Focus")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(appState.activeNote)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(8)
                .background(Color.secondary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            timerReadout
            sessionControls
        }
    }

    /// Sade odak modu: devasa sayaç, ortalı proje adı, kategori/not gizli.
    private var focusLayout: some View {
        VStack(spacing: 14) {
            VStack(spacing: 2) {
                activeSessionLabel
                Text(activeProjectName)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }

            timerReadout
            sessionControls
        }
        .frame(maxWidth: .infinity)
    }

    /// Yoğun mod: tek satır başlık + küçük sayaç + butonlar; minimum yükseklik.
    private var compactLayout: some View {
        VStack(spacing: 10) {
            HStack {
                Text(activeProjectName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                timerReadout
            }
            sessionControls
        }
    }

    private var activeSessionLabel: some View {
        Text("ACTIVE SESSION")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundStyle(Color.accentColor)
    }

    /// Canlı sayaç. Duraklıyken solar ve sağına kırmızı duraklatma ikonu eklenir
    /// (alta taşmaması için sayacın yanında, dikey ortada). Punto presete bağlı.
    private var timerReadout: some View {
        Text(Duration.stopwatch(seconds: stopwatch.elapsedSeconds))
            .font(.system(size: timerLayout.timerFontSize, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.accentColor)
            .shadow(color: Color.accentColor.opacity(stopwatch.isPaused ? 0 : 0.2), radius: 6, x: 0, y: 3)
            .opacity(stopwatch.isPaused ? 0.45 : 1)
            .overlay(alignment: .trailing) {
                if stopwatch.isPaused {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: timerLayout.timerFontSize * 0.34))
                        .foregroundStyle(.red)
                        .help(String(localized: "Paused"))
                        .offset(x: timerLayout.timerFontSize * 0.55)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.vertical, timerLayout == .compact ? 0 : 4)
            .animation(.snappy(duration: 0.16), value: stopwatch.isPaused)
    }

    private var sessionControls: some View {
        HStack(spacing: 10) {
            Button {
                togglePause()
            } label: {
                Label(
                    stopwatch.isPaused ? String(localized: "Resume") : String(localized: "Pause"),
                    systemImage: stopwatch.isPaused ? "play.fill" : "pause.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(timerLayout == .compact ? .regular : .large)

            Button(role: .destructive) {
                stopActiveSession()
            } label: {
                Label("Stop and Save", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(timerLayout == .compact ? .regular : .large)
        }
    }

    private var projectsTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Projects").font(.headline)

            if PopoverLayout.showsInlineProjectCreation(for: selectedTab.layoutKind) {
                addProjectRow(buttonTitle: String(localized: "Add"))
            }

            HStack(spacing: 8) {
                SearchField(text: $managementSearch, placeholder: String(localized: "Search projects…"))

                if !categories.isEmpty {
                    Button {
                        withAnimation(.snappy(duration: 0.16)) {
                            showFilters.toggle()
                        }
                    } label: {
                        Image(systemName: showFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .font(.title3)
                            .foregroundStyle(showFilters || filterCategoryID != nil ? Color.accentColor : .secondary)
                            .frame(width: 28, height: 28)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .hoverHighlight()
                    .help("Show/Hide Category Filters")
                }

                Button {
                    withAnimation(.snappy(duration: 0.16)) {
                        projectsViewMode = projectsViewMode == "grid" ? "list" : "grid"
                    }
                } label: {
                    Image(systemName: projectsViewMode == "grid" ? "square.grid.2x2.fill" : "list.bullet")
                        .font(.title3)
                        .foregroundStyle(projectsViewMode == "grid" ? Color.accentColor : .secondary)
                        .frame(width: 28, height: 28)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .hoverHighlight()
                .help("Toggle list / grid view")
            }

            if showFilters && !categories.isEmpty {
                categoryFilterBar
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98)),
                        removal: .opacity
                    ))
            }

            projectsContent
                .frame(maxHeight: .infinity)

            Divider()

            categoryManager
        }
    }

    private var categoryFilterBar: some View {
        FlowLayout(spacing: 6) {
            FilterChip(
                title: String(localized: "All"),
                hex: nil,
                isSelected: filterCategoryID == nil
            ) {
                filterCategoryID = nil
            }

            ForEach(categories) { category in
                FilterChip(
                    title: category.name,
                    hex: category.colorHex,
                    isSelected: filterCategoryID == category.id
                ) {
                    filterCategoryID = filterCategoryID == category.id ? nil : category.id
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 2)
    }

    private var historyTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Past sessions").font(.headline)
                Spacer()
                Button {
                    // Form açılırken tarihi bugüne sabitle; menubar uygulaması
                    // arka planda günlerce açık kalabildiği için @State'in ilk
                    // başlatıldığı günde takılı kalmasını önler.
                    if !showManualEntry {
                        manualDay = .now
                    }
                    withAnimation(.snappy(duration: 0.16)) {
                        showManualEntry.toggle()
                    }
                } label: {
                    Label("Add manually", systemImage: showManualEntry ? "xmark" : "plus")
                        .font(.callout)
                }
                .buttonStyle(.bordered)
                .help(showManualEntry ? String(localized: "Close form") : String(localized: "Add a session manually"))
            }

            if showManualEntry {
                manualEntryForm
            }

            if historySessions.isEmpty {
                Text("No sessions saved yet")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(historySessions, id: \.id) { session in
                                if editingSessionID == session.id {
                                    SessionEditForm(
                                        session: session,
                                        projects: activeProjects,
                                        onCancel: {
                                            withAnimation(.snappy(duration: 0.16)) {
                                                editingSessionID = nil
                                            }
                                        },
                                        onSave: {
                                            withAnimation(.snappy(duration: 0.16)) {
                                                editingSessionID = nil
                                            }
                                        }
                                    )
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .scale(scale: 0.96)),
                                        removal: .opacity
                                    ))
                                } else {
                                    SessionHistoryRow(
                                        session: session,
                                        onEdit: { startEditingSession(session, scroll: proxy) },
                                        onDelete: { deleteSession(session) }
                                    )
                                    .transition(.opacity)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var manualDraft: ManualSessionEntry {
        ManualSessionEntry(note: manualNote, hours: manualHours, minutes: manualMinutes, day: manualDay)
    }

    private var manualEntryForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            ProjectSelectList(projects: activeProjects, selection: $manualProjectID)

            SessionNoteEditor(text: $manualNote, placeholder: String(localized: "Note (optional)"))
                .frame(height: 72)

            HStack(spacing: 16) {
                ManualDurationStepper(hours: $manualHours, minutes: $manualMinutes)
                Spacer()
                DatePicker("", selection: $manualDay, in: ...Date.now, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.field)
            }

            Button {
                saveManualSession()
            } label: {
                Text("Save")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(manualProjectID == nil || !manualDraft.canSave)
        }
        .padding(12)
        .background(CategorySurface.panel)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var projectsContent: some View {
        let isSearching = !managementSearch.trimmingCharacters(in: .whitespaces).isEmpty
        if projectsViewMode == "grid" && !isSearching {
            CategoryGridView(
                folders: CategoryStats.folders(projects: managementProjects),
                onProjectDelete: { project in deleteProject(project) }
            )
        } else {
            projectManagementList
        }
    }

    private var projectManagementList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if managementProjects.isEmpty {
                        Text("No matching projects")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(managementProjects) { project in
                            ProjectExpandableCard(
                                project: project,
                                isExpanded: expandedProjectID == project.id,
                                onToggle: { toggleExpanded(project, scroll: proxy) },
                                onDelete: { deleteProject(project) }
                            )
                            .id(project.id)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func toggleExpanded(_ project: Project, scroll proxy: ScrollViewProxy) {
        let willExpand = expandedProjectID != project.id
        withAnimation(.snappy(duration: 0.16)) {
            expandedProjectID = willExpand ? project.id : nil
        }
        // Aşağı açılan kart görünüm dışına taşabilir; açılınca alt kenarını görünür yap.
        guard willExpand else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.snappy(duration: 0.2)) {
                proxy.scrollTo(project.id, anchor: .bottom)
            }
        }
    }

    private var categoryManager: some View {
        VStack(alignment: .leading, spacing: showCategories ? 8 : 0) {
            // Tıklanabilir başlık: bölümü filtre barı gibi aç/kapa yapar.
            CategoryDisclosureHeader(isOpen: showCategories) {
                withAnimation(.snappy(duration: 0.16)) {
                    showCategories.toggle()
                    // Kapatılırken gizli bir düzenleme state'i kalmasın.
                    if !showCategories { editingCategoryID = nil }
                }
            }

            if showCategories {
                Group {
                    if categories.isEmpty {
                        Text("No categories yet")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    } else {
                        FlowLayout(spacing: 6) {
                            ForEach(categories) { category in
                                Button {
                                    withAnimation(.snappy(duration: 0.16)) {
                                        editingCategoryID = editingCategoryID == category.id ? nil : category.id
                                    }
                                } label: {
                                    CategoryChip(name: category.name, hex: category.colorHex)
                                        .overlay {
                                            if editingCategoryID == category.id {
                                                Capsule()
                                                    .stroke(Color.accentColor, lineWidth: 2)
                                            }
                                        }
                                        .hoverHighlight()
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 2)
                    }

                    if let editingCategory {
                        CategoryEditPanel(category: editingCategory) {
                            deleteCategory(editingCategory)
                        }
                    } else {
                        CategoryCreationPanel(
                            name: $newCategoryName,
                            colorHex: $newCategoryColorHex,
                            error: categoryError
                        ) {
                            addCategory()
                        }
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.98)),
                    removal: .opacity
                ))
            }
        }
        .padding(12)
        .background(CategorySurface.panel)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func addProjectRow(buttonTitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                TextField("New project", text: $newProjectName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addProject)
                Button(buttonTitle, action: addProject)
                    .disabled(newProjectName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if let nameError { Text(nameError).foregroundStyle(.red).font(.caption) }
        }
    }

    private func addProject() {
        let trimmed = newProjectName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if allProjects.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            nameError = String(localized: "A project with this name already exists")
            return
        }
        let project = Project(name: trimmed)
        context.insert(project)
        selectedProjectID = project.id
        expandedProjectID = project.id
        newProjectName = ""
        nameError = nil
    }

    private func addCategory() {
        let trimmed = newCategoryName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if categories.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            categoryError = String(localized: "This category already exists")
            return
        }
        context.insert(Category(name: trimmed, colorHex: newCategoryColorHex))
        newCategoryName = ""
        categoryError = nil
    }

    private func deleteCategory(_ category: Category) {
        if editingCategoryID == category.id {
            editingCategoryID = nil
        }
        CategoryManagement.delete(category, in: context)
    }

    private func deleteProject(_ project: Project) {
        let id = project.id
        // Silinen projeye dair seçim/genişleme durumlarını temizle.
        if expandedProjectID == id { expandedProjectID = nil }
        if selectedProjectID == id { selectedProjectID = nil }
        if manualProjectID == id { manualProjectID = nil }
        // .cascade ilişkisi sayesinde oturumlar da silinir.
        context.delete(project)
    }

    private func deleteSession(_ session: Session) {
        if editingSessionID == session.id { editingSessionID = nil }
        context.delete(session)
    }

    private func startEditingSession(_ session: Session, scroll proxy: ScrollViewProxy) {
        withAnimation(.snappy(duration: 0.16)) {
            editingSessionID = session.id
        }
        // Aşağı açılan düzenleme formu görünüm dışına taşabilir; alt kenarını görünür yap.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.snappy(duration: 0.2)) {
                proxy.scrollTo(session.id, anchor: .bottom)
            }
        }
    }

    private func startSession() {
        guard let id = selectedProjectID else { return }
        appState.activeProjectID = id
        appState.activeNote = note
        stopwatch.start()
    }

    private func togglePause() {
        if stopwatch.isPaused {
            stopwatch.resume()
        } else {
            stopwatch.pause()
        }
    }

    private func stopActiveSession() {
        stopwatch.stop()
        appState.screen = .save
    }

    private func saveManualSession() {
        guard let project = activeProjects.first(where: { $0.id == manualProjectID }),
              manualDraft.canSave else { return }
        context.insert(manualDraft.makeSession(project: project))
        // Girişten sonra formu temizle ve kapat.
        manualNote = ""
        manualHours = 0
        manualMinutes = 0
        manualDay = .now
        manualProjectID = nil
        withAnimation(.snappy(duration: 0.16)) {
            showManualEntry = false
        }
    }
}

/// Elle giriş için saat/dakika seçici. SaveView'daki 15-dk mantığının aynısı:
/// dakika 0/15/30/45 adımlarla, saat taşmasıyla.
private struct ManualDurationStepper: View {
    @Binding var hours: Int
    @Binding var minutes: Int

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 6) {
                Text("\(hours) hr")
                    .monospacedDigit()
                    .frame(width: 56, alignment: .leading)
                Stepper(value: $hours, in: 0...23) { EmptyView() }
                    .labelsHidden()
            }

            HStack(spacing: 6) {
                Text("\(minutes) min")
                    .monospacedDigit()
                    .frame(width: 48, alignment: .leading)
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
            }
        }
    }
}

struct ProjectExpandableCard: View {
    @Bindable var project: Project
    let isExpanded: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void
    @Query(sort: \Category.name) private var categories: [Category]
    @State private var showDeleteConfirm = false

    private var statusColor: Color {
        switch project.status {
        case .inProgress: return .green
        case .continuous: return .blue
        case .paused: return .orange
        case .done: return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 14 : 0) {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(isExpanded ? Color.accentColor : .secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 14)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name)
                            .font(.callout)
                            .fontWeight(.semibold)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            if let category = project.category {
                                CategoryChip(name: category.name, hex: category.colorHex)
                            } else {
                                Text("Uncategorized")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(statusColor)
                                    .frame(width: 6, height: 6)
                                Text(project.status.label)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Spacer(minLength: 10)

                    HStack(spacing: 5) {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(Duration.short(seconds: project.totalLoggedSeconds))
                            .foregroundStyle(.secondary)
                            .font(.caption)
                            .monospacedDigit()
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                    .opacity(0.6)

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PROJECT NAME")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)

                        TextField("Project name", text: $project.name)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CATEGORY")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary)

                            Picker("", selection: $project.category) {
                                Text("None").tag(Category?.none)
                                ForEach(categories) { category in
                                    Text(category.name).tag(Category?.some(category))
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("STATUS")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary)
                            
                            Picker("", selection: Binding(
                                get: { project.status },
                                set: { project.status = $0 }
                            )) {
                                ForEach(ProjectStatus.allCases, id: \.self) { status in
                                    Text(status.label).tag(status)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    if showDeleteConfirm {
                        deleteConfirmBar
                    } else {
                        HStack {
                            Spacer()
                            Button(role: .destructive) {
                                withAnimation(.snappy(duration: 0.14)) { showDeleteConfirm = true }
                            } label: {
                                Label("Delete project", systemImage: "trash")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("Delete the project and all its sessions")
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            showDeleteConfirm 
                ? Color.red.opacity(0.08) 
                : (isExpanded ? Color.accentColor.opacity(0.06) : Color.secondary.opacity(0.03))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    showDeleteConfirm
                        ? Color.red.opacity(0.2)
                        : (isExpanded ? Color.accentColor.opacity(0.25) : Color.clear),
                    lineWidth: 1
                )
        }
    }

    private var deleteConfirmBar: some View {
        HStack {
            Text(project.sessions.isEmpty
                 ? String(localized: "This project will be permanently deleted.")
                 : String(localized: "This project and \(project.sessions.count) sessions will be permanently deleted."))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Cancel") {
                withAnimation(.snappy(duration: 0.14)) { showDeleteConfirm = false }
            }
            .controlSize(.small)
            Button("Delete", role: .destructive, action: onDelete)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}

/// Bir geçmiş oturumu yerinde düzenleme formu (proje/not/süre/tarih).
struct SessionEditForm: View {
    let session: Session
    let projects: [Project]
    let onCancel: () -> Void
    let onSave: () -> Void

    @State private var edit: SessionEdit

    init(session: Session, projects: [Project], onCancel: @escaping () -> Void, onSave: @escaping () -> Void) {
        self.session = session
        self.projects = projects
        self.onCancel = onCancel
        self.onSave = onSave
        _edit = State(initialValue: SessionEdit(session: session))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ProjectSelectList(projects: projects, selection: $edit.projectID)

            SessionNoteEditor(text: $edit.note, placeholder: String(localized: "Note (optional)"))
                .frame(height: 72)

            HStack(spacing: 16) {
                ManualDurationStepper(hours: $edit.hours, minutes: $edit.minutes)
                Spacer()
                DatePicker("", selection: $edit.day, in: ...Date.now, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.field)
            }

            HStack {
                Button("Cancel", action: onCancel)
                Spacer()
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(edit.projectID == nil || !edit.canSave)
            }
        }
        .padding(12)
        .background(CategorySurface.panel)
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func save() {
        let project = projects.first { $0.id == edit.projectID }
        edit.apply(to: session, project: project)
        onSave()
    }
}

struct SessionHistoryRow: View {
    let session: Session
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false
    @State private var showDeleteConfirm = false

    private var showActions: Bool { isHovering || showDeleteConfirm }

    private var dateText: String {
        session.endedAt.formatted(
            .dateTime.day().month(.abbreviated).year().locale(Locale.current)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(session.project?.name ?? String(localized: "No project"))
                            .font(.callout)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        if let category = session.project?.category {
                            CategoryChip(name: category.name, hex: category.colorHex)
                        }
                    }
                    Text(session.note.isEmpty ? String(localized: "No note") : session.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 10)

                ZStack(alignment: .topTrailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(Duration.short(seconds: session.loggedSeconds))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Text(dateText)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .opacity(showActions ? 0 : 1)
                    .allowsHitTesting(!showActions)

                    if showActions {
                        HStack(spacing: 6) {
                            Button {
                                onEdit()
                            } label: {
                                Image(systemName: "pencil")
                                    .frame(width: 22, height: 22)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help("Edit")

                            Button(role: .destructive) {
                                withAnimation(.snappy(duration: 0.14)) { showDeleteConfirm.toggle() }
                            } label: {
                                Image(systemName: "trash")
                                    .frame(width: 22, height: 22)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help("Delete")
                        }
                    }
                }
                .frame(minWidth: 72, alignment: .trailing)
            }

            if showDeleteConfirm {
                HStack {
                    Text("Delete this session?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Cancel") {
                        withAnimation(.snappy(duration: 0.14)) { showDeleteConfirm = false }
                    }
                    Button("Delete", role: .destructive, action: onDelete)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background((showDeleteConfirm ? Color.red.opacity(0.12) : Color.secondary.opacity(isHovering ? 0.14 : 0.08)))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onHover { hovering in
            withAnimation(.snappy(duration: 0.12)) { isHovering = hovering }
        }
    }
}

struct SessionNoteEditor: View {
    @Binding var text: String
    var placeholder: String = PopoverLayout.sessionNotePlaceholder

    // Placeholder ve metin aynı NSTextView içerik kutusunu paylaşır:
    // her ikisi de aynı inset'i kullanınca imleç ile placeholder birebir hizalanır.
    private static let contentInset = NSSize(width: 8, height: 8)

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, Self.contentInset.width)
                    .padding(.vertical, Self.contentInset.height)
                    .allowsHitTesting(false)
            }

            MultilineTextView(text: $text, contentInset: Self.contentInset)
        }
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// Overlay scroller kullanan, içerik inset'i tam kontrol edilebilen NSTextView sarmalayıcısı.
/// Legacy (her zaman görünen) scroll çubuğu yerine, yalnızca scroll sırasında beliren ince
/// overlay scroller kullanır.
struct MultilineTextView: NSViewRepresentable {
    @Binding var text: String
    let contentInset: NSSize

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.font = .preferredFont(forTextStyle: .callout)
        textView.textContainerInset = contentInset
        textView.drawsBackground = false
        textView.allowsUndo = true
        textView.textContainer?.lineFragmentPadding = 0

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        scrollView.verticalScrollElasticity = .allowed
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private let parent: MultilineTextView

        init(_ parent: MultilineTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

extension View {
    /// SwiftUI ScrollView'un alttaki NSScrollView'undaki scroller'ları gizler.
    /// macOS'ta `.scrollIndicators(.hidden)` güvenilir çalışmadığı için gerekli.
    func hidesScrollIndicators() -> some View {
        background(ScrollerHider())
    }
}

/// SwiftUI ScrollView'un alttaki NSScrollView'unu bulup scroller'larını kalıcı olarak gizler.
/// `background()` içine yerleşir, kardeş NSScrollView'ı superview ağacında tarayarak bulur ve
/// scroller'ları her layout geçişinde tekrar gizler (SwiftUI aksi halde geri açabiliyor).
private struct ScrollerHider: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        ProbeView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? ProbeView)?.hideEnclosingScrollers()
    }

    final class ProbeView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            hideEnclosingScrollers()
        }

        override func layout() {
            super.layout()
            hideEnclosingScrollers()
        }

        func hideEnclosingScrollers() {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                // Birkaç ata seviyesine çık, her birinin alt ağacındaki tüm NSScrollView'ları gizle.
                var root: NSView? = self
                for _ in 0..<6 { root = root?.superview }
                guard let root else { return }
                Self.allScrollViews(in: root).forEach(Self.hide)
            }
        }

        private static func hide(_ scrollView: NSScrollView) {
            scrollView.scrollerStyle = .overlay
            scrollView.autohidesScrollers = true
            scrollView.hasVerticalScroller = false
            scrollView.hasHorizontalScroller = false
            scrollView.verticalScroller?.alphaValue = 0
            scrollView.horizontalScroller?.alphaValue = 0
        }

        private static func allScrollViews(in view: NSView) -> [NSScrollView] {
            var result: [NSScrollView] = []
            if let scrollView = view as? NSScrollView { result.append(scrollView) }
            for subview in view.subviews {
                result.append(contentsOf: allScrollViews(in: subview))
            }
            return result
        }
    }
}

/// Minimalist yüzey paleti: paneller çizgi yerine çok hafif bir zeminle
/// gruplanır. `border` neredeyse görünmezdir (çift-çizgi hissini önler);
/// gruplama kontrastı `panel`'in hafif dolgusundan gelir.
enum CategorySurface {
    static let panel = Color.secondary.opacity(0.05)
    static let inset = Color.secondary.opacity(0.03)
}

private struct CategoryCreationPanel: View {
    @Binding var name: String
    @Binding var colorHex: String
    let error: String?
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                TextField("New category", text: $name)
                    .textFieldStyle(.roundedBorder)

                Button("Add") { onAdd() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            CategorySwatchPicker(selection: $colorHex)

            if let error {
                Text(error).foregroundStyle(.red).font(.caption)
            }
        }
        .padding(10)
        .background(CategorySurface.inset)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct CategoryEditPanel: View {
    @Bindable var category: Category
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                TextField("Category name", text: $category.name)
                    .textFieldStyle(.roundedBorder)

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 18)
                }
                .buttonStyle(.bordered)
                .help("Delete category")
            }

            CategorySwatchPicker(selection: $category.colorHex)
        }
        .padding(10)
        .background(CategorySurface.inset)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct CategorySwatchPicker: View {
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 7) {
            ForEach(CategoryPalette.colors, id: \.self) { hex in
                Button {
                    selection = hex
                } label: {
                    Circle()
                        .fill(Color(hex: hex) ?? .gray)
                        .frame(width: 18, height: 18)
                        .overlay {
                            Circle()
                                .stroke(Color.white.opacity(0.85), lineWidth: 1)
                        }
                        .overlay {
                            Circle()
                                .stroke(selection == hex ? Color.accentColor : Color.clear, lineWidth: 3)
                        }
                        .padding(3)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(hex)
            }
        }
    }
}

private struct RecentSessionNotesView: View {
    let sessions: [Session]

    var body: some View {
        if !sessions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(PopoverLayout.recentSessionNotesTitle)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 5) {
                    ForEach(sessions) { session in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(session.note.isEmpty ? String(localized: "No note") : session.note)
                                .font(.caption)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 10)
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(Duration.short(seconds: session.loggedSeconds))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                Text(relativeDateText(for: session.endedAt))
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            .padding(10)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func relativeDateText(for date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return String(localized: "Today")
        } else if calendar.isDateInYesterday(date) {
            return String(localized: "Yesterday")
        }

        let startOfDate = calendar.startOfDay(for: date)
        let startOfNow = calendar.startOfDay(for: now)
        let components = calendar.dateComponents([.day], from: startOfDate, to: startOfNow)

        if let days = components.day, days < 7 {
            return String(localized: "\(days) days ago")
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale.current
            formatter.setLocalizedDateFormatFromTemplate("d MMM")
            return formatter.string(from: date)
        }
    }
}

/// İkonlu, kapsül biçimli arama alanı. Metin girilince temizleme (×) butonu belirir.
private struct SearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.callout)
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.callout)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear")
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// Proje seçim listelerindeki tek satır: solda kategori renginde dikey şerit,
/// ardından seçim dairesi + proje adı + toplam süre. Kategorisi olmayan
/// projelerde şerit şeffaf kalır (renk gösterilmez). Hem "Start a new session"
/// listesi hem de form'lardaki `ProjectSelectList` bunu kullanır.
private struct ProjectPickerRow: View {
    let project: Project
    let isSelected: Bool

    private var stripeColor: Color {
        guard let hex = project.category?.colorHex,
              let color = Color(hex: hex) else { return .clear }
        return color
    }

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(stripeColor)
                .frame(width: 3)
                .frame(maxHeight: .infinity)

            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            Text(project.name)
            Spacer()
            Text(Duration.short(seconds: project.totalLoggedSeconds))
                .foregroundStyle(.secondary).font(.caption)
        }
        .frame(height: PopoverLayout.sessionProjectRowHeight)
    }
}

/// Arama çubuğu + aynı yükseklikte liste satırları olan proje seçici.
/// Form'lardaki yerel `Picker` dropdown'ı yerine kullanılır; uzun proje
/// listesinde aramayı kolaylaştırır.
private struct ProjectSelectList: View {
    let projects: [Project]
    @Binding var selection: UUID?

    @State private var query = ""

    /// Boş query'de en son kullanılana göre; arama varsa eşleşenler.
    private var visibleProjects: [Project] {
        let base = ProjectFiltering.filtered(projects, query: query)
        return query.trimmingCharacters(in: .whitespaces).isEmpty
            ? ProjectFiltering.recencySorted(base)
            : base
    }

    private var rowCount: Int {
        min(max(visibleProjects.count, 1), 4)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SearchField(text: $query, placeholder: String(localized: "Search projects…"))

            if projects.isEmpty {
                Text("No projects yet, add one")
                    .foregroundStyle(.secondary).font(.callout)
            } else if visibleProjects.isEmpty {
                Text("No matches")
                    .foregroundStyle(.secondary).font(.callout)
                    .frame(height: PopoverLayout.sessionProjectRowHeight)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(visibleProjects) { p in
                            Button {
                                selection = p.id
                            } label: {
                                ProjectPickerRow(project: p, isSelected: selection == p.id)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(height: CGFloat(rowCount) * PopoverLayout.sessionProjectRowHeight)
            }
        }
    }
}

/// "Kategoriler" bölümünü aç/kapa eden başlık satırı. Geniş bir satır olduğu için
/// scale yerine hover'da renk değiştirir (scale taşmaya yol açıyordu).
private struct CategoryDisclosureHeader: View {
    let isOpen: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text("Categories").font(.headline)
                Spacer()
                Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(isHovering ? Color.accentColor : .primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.12), value: isHovering)
        .onHover { isHovering = $0 }
    }
}

private struct CategoryChip: View {
    let name: String
    let hex: String

    var body: some View {
        Text(name)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 2.5)
            .background((Color(hex: hex) ?? .gray).opacity(0.68))
            .clipShape(Capsule())
    }
}

/// Projeler sekmesindeki kategori filtre çipi. Seçiliyken dolu, değilken hafif;
/// imleç üzerine gelince belirginleşir (tıklanabilir olduğu anlaşılsın diye).
private struct FilterChip: View {
    let title: String
    let hex: String?
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    private var tint: Color { (hex.flatMap { Color(hex: $0) }) ?? .gray }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 3.5)
                .background(background)
                .overlay {
                    Capsule().stroke(.white.opacity(isSelected ? 0.9 : 0), lineWidth: 1.5)
                }
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.06 : 1)
        .animation(.snappy(duration: 0.12), value: isHovering)
        .onHover { isHovering = $0 }
    }

    private var background: some View {
        // Kategori çipleriyle aynı parlaklık (0.68); seçim, beyaz kenarlıkla belli olur.
        tint.opacity(0.68)
    }
}

/// İmleç üzerine gelince hafif büyüyüp parlayan, tıklanabilirliği vurgulayan sarmalayıcı.
private struct HoverHighlight: ViewModifier {
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .brightness(isHovering ? 0.08 : 0)
            .scaleEffect(isHovering ? 1.06 : 1)
            .animation(.snappy(duration: 0.12), value: isHovering)
            .onHover { isHovering = $0 }
    }
}

extension View {
    func hoverHighlight() -> some View { modifier(HoverHighlight()) }
}

/// SwiftUI FlowLayout wrapping layout. Lays out subviews horizontally and wraps
/// to the next line dynamically when the horizontal boundary is exceeded.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        var height: CGFloat = 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        height = currentY + lineHeight
        return CGSize(width: width, height: max(height, 0))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(size)
            )
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
