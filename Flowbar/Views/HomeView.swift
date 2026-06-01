import SwiftUI
import SwiftData

private enum HomeTab: String, CaseIterable {
    case session = "Oturum"
    case projects = "Projeler"
    case history = "Geçmiş"
    case analytics = "Analiz"
    case remind = "Hatırlat"

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
    @State private var newCategoryName = ""
    @State private var newCategoryColorHex = CategoryPalette.defaultHex
    @State private var editingCategoryID: UUID?
    @State private var categoryError: String?
    @State private var showSettings = false

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
            if stopwatch.isRunning {
                return CGSize(width: 480, height: 260)
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
                        .padding(.leading, 2)
                    
                    Spacer()

                    Picker("", selection: $selectedTab) {
                        ForEach(HomeTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .fixedSize(horizontal: true, vertical: false)

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
    }

    private var sessionTab: some View {
        Group {
            if stopwatch.isRunning {
                activeSessionCard
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Yeni oturum başlat").font(.headline)
                        Spacer()
                        if let selectedProject {
                            Text(selectedProject.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    SearchField(text: $search, placeholder: "Proje ara…")

                    if activeProjects.isEmpty {
                        Text("Henüz proje yok, bir tane ekle")
                            .foregroundStyle(.secondary).font(.callout)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(pickerProjects) { p in
                                    Button {
                                        selectedProjectID = p.id
                                    } label: {
                                        HStack {
                                            Image(systemName: selectedProjectID == p.id ? "largecircle.fill.circle" : "circle")
                                                .foregroundStyle(selectedProjectID == p.id ? Color.accentColor : .secondary)
                                            Text(p.name)
                                            Spacer()
                                            Text(Duration.short(seconds: p.totalLoggedSeconds))
                                                .foregroundStyle(.secondary).font(.caption)
                                        }
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
                        Text("Başlat")
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

    private var activeSessionCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AKTİF OTURUM")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.accentColor)

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
                    Text("Odak Noktası")
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

            // Canlı Sayaç
            Text(Duration.stopwatch(seconds: stopwatch.elapsedSeconds))
                .font(.system(size: 34, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.accentColor)
                .shadow(color: Color.accentColor.opacity(0.2), radius: 6, x: 0, y: 3)
                .padding(.vertical, 4)

            Button(role: .destructive) {
                stopActiveSession()
            } label: {
                Label("Durdur ve Kaydet", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(14)
        .background(Color.accentColor.opacity(0.06))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.accentColor.opacity(0.25), lineWidth: 1.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var projectsTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Projeler").font(.headline)

            if PopoverLayout.showsInlineProjectCreation(for: selectedTab.layoutKind) {
                addProjectRow(buttonTitle: "Ekle")
            }

            HStack(spacing: 8) {
                SearchField(text: $managementSearch, placeholder: "Proje ara…")

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
                            .background(Color(nsColor: .textBackgroundColor).opacity(0.85))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(nsColor: .separatorColor).opacity(0.7), lineWidth: 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .hoverHighlight()
                    .help("Kategori Filtrelerini Göster/Gizle")
                }
            }

            if showFilters && !categories.isEmpty {
                categoryFilterBar
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98)),
                        removal: .opacity
                    ))
            }

            projectManagementList
                .frame(maxHeight: 360)

            Divider()

            categoryManager
        }
    }

    private var categoryFilterBar: some View {
        FlowLayout(spacing: 6) {
            FilterChip(
                title: "Tümü",
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
                Text("Geçmiş oturumlar").font(.headline)
                Spacer()
                Button {
                    withAnimation(.snappy(duration: 0.16)) {
                        showManualEntry.toggle()
                    }
                } label: {
                    Label("Manuel ekle", systemImage: showManualEntry ? "xmark" : "plus")
                        .font(.callout)
                }
                .buttonStyle(.bordered)
                .help(showManualEntry ? "Formu kapat" : "Geçmişe elle oturum ekle")
            }

            if showManualEntry {
                manualEntryForm
            }

            if historySessions.isEmpty {
                Text("Henüz kaydedilmiş oturum yok")
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
            Picker("Proje", selection: $manualProjectID) {
                Text("Proje seç").tag(UUID?.none)
                ForEach(activeProjects) { project in
                    Text(project.name).tag(UUID?.some(project.id))
                }
            }

            SessionNoteEditor(text: $manualNote, placeholder: "Not (opsiyonel)")
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
                Text("Kaydet")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(manualProjectID == nil || !manualDraft.canSave)
        }
        .padding(12)
        .background(CategorySurface.panel)
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(CategorySurface.border, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var projectManagementList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if managementProjects.isEmpty {
                        Text("Eşleşen proje yok")
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Kategoriler").font(.headline)

            if categories.isEmpty {
                Text("Henüz kategori yok")
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
        .padding(12)
        .background(CategorySurface.panel)
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(CategorySurface.border, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func addProjectRow(buttonTitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                TextField("Yeni proje", text: $newProjectName)
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
            nameError = "Bu isimde proje zaten var"
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
            categoryError = "Bu kategori zaten var"
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
                Text("\(hours) saat")
                    .monospacedDigit()
                    .frame(width: 56, alignment: .leading)
                Stepper(value: $hours, in: 0...23) { EmptyView() }
                    .labelsHidden()
            }

            HStack(spacing: 6) {
                Text("\(minutes) dk")
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

private struct ProjectExpandableCard: View {
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
                                Text("Kategorisiz")
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
                        Text("PROJE ADI")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                        
                        TextField("Proje adı", text: $project.name)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color(nsColor: .textBackgroundColor).opacity(0.4))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("KATEGORİ")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary)
                            
                            Picker("", selection: $project.category) {
                                Text("Yok").tag(Category?.none)
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
                            Text("DURUM")
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
                                Label("Projeyi sil", systemImage: "trash")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("Projeyi ve tüm oturumlarını sil")
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
                        : (isExpanded ? Color.accentColor.opacity(0.25) : Color(nsColor: .separatorColor).opacity(0.4)), 
                    lineWidth: 1
                )
        }
    }

    private var deleteConfirmBar: some View {
        HStack {
            Text(project.sessions.isEmpty
                 ? "Bu proje kalıcı olarak silinecek."
                 : "Bu proje ve \(project.sessions.count) oturum kalıcı olarak silinecek.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Vazgeç") {
                withAnimation(.snappy(duration: 0.14)) { showDeleteConfirm = false }
            }
            .controlSize(.small)
            Button("Sil", role: .destructive, action: onDelete)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}

/// Bir geçmiş oturumu yerinde düzenleme formu (proje/not/süre/tarih).
private struct SessionEditForm: View {
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
            Picker("Proje", selection: $edit.projectID) {
                Text("Proje seç").tag(UUID?.none)
                ForEach(projects) { project in
                    Text(project.name).tag(UUID?.some(project.id))
                }
            }

            SessionNoteEditor(text: $edit.note, placeholder: "Not (opsiyonel)")
                .frame(height: 72)

            HStack(spacing: 16) {
                ManualDurationStepper(hours: $edit.hours, minutes: $edit.minutes)
                Spacer()
                DatePicker("", selection: $edit.day, in: ...Date.now, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.field)
            }

            HStack {
                Button("Vazgeç", action: onCancel)
                Spacer()
                Button("Kaydet") { save() }
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

private struct SessionHistoryRow: View {
    let session: Session
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false
    @State private var showDeleteConfirm = false

    private var showActions: Bool { isHovering || showDeleteConfirm }

    private var dateText: String {
        session.endedAt.formatted(
            .dateTime.day().month(.abbreviated).year().locale(Locale(identifier: "tr_TR"))
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(session.project?.name ?? "Proje yok")
                            .font(.callout)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        if let category = session.project?.category {
                            CategoryChip(name: category.name, hex: category.colorHex)
                        }
                    }
                    Text(session.note.isEmpty ? "Not yok" : session.note)
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
                            .help("Düzenle")

                            Button(role: .destructive) {
                                withAnimation(.snappy(duration: 0.14)) { showDeleteConfirm.toggle() }
                            } label: {
                                Image(systemName: "trash")
                                    .frame(width: 22, height: 22)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help("Sil")
                        }
                    }
                }
                .frame(minWidth: 72, alignment: .trailing)
            }

            if showDeleteConfirm {
                HStack {
                    Text("Bu oturum silinsin mi?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Vazgeç") {
                        withAnimation(.snappy(duration: 0.14)) { showDeleteConfirm = false }
                    }
                    Button("Sil", role: .destructive, action: onDelete)
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
        .background(Color(nsColor: .textBackgroundColor).opacity(0.86))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.75), lineWidth: 1)
        }
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

enum CategorySurface {
    static let panel = Color(nsColor: .controlBackgroundColor).opacity(0.98)
    static let inset = Color(nsColor: .windowBackgroundColor).opacity(0.98)
    static let border = Color(nsColor: .separatorColor).opacity(0.7)
}

private struct CategoryCreationPanel: View {
    @Binding var name: String
    @Binding var colorHex: String
    let error: String?
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                TextField("Yeni kategori", text: $name)
                    .textFieldStyle(.roundedBorder)

                Button("Ekle") { onAdd() }
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
                TextField("Kategori adı", text: $category.name)
                    .textFieldStyle(.roundedBorder)

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 18)
                }
                .buttonStyle(.bordered)
                .help("Kategoriyi sil")
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
                            Text(session.note.isEmpty ? "Not yok" : session.note)
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
            return "Bugün"
        } else if calendar.isDateInYesterday(date) {
            return "Dün"
        }
        
        let startOfDate = calendar.startOfDay(for: date)
        let startOfNow = calendar.startOfDay(for: now)
        let components = calendar.dateComponents([.day], from: startOfDate, to: startOfNow)
        
        if let days = components.day, days < 7 {
            return "\(days) gün önce"
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "tr_TR")
            formatter.dateFormat = "d MMM"
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
                .help("Temizle")
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.85))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.7), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
