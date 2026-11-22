import SwiftUI

enum SidebarItem: Hashable {
    case all, active, hobby(HobbyKind)

    var title: String {
        switch self {
        case .all: "All Projects"
        case .active: "In Progress"
        case .hobby(let h): h.title
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var store: AppStore
    @State private var selection: SidebarItem? = .all
    @State private var path: [UUID] = []
    @State private var showNew = false
    var initialPath: [UUID] = []

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Library") {
                    row(.all, symbol: "square.grid.2x2", color: .accentColor, count: store.projects.count)
                    row(.active, symbol: "flame.fill", color: .orange,
                        count: store.projects.filter { $0.status == .active }.count)
                }
                Section("Hobbies") {
                    ForEach(HobbyKind.allCases) { h in
                        row(.hobby(h), symbol: h.symbol, color: h.color,
                            count: store.projects.filter { $0.hobby == h }.count)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } detail: {
            NavigationStack(path: $path) {
                ProjectGridView(filter: selection ?? .all, onNew: requestNew)
                    .navigationDestination(for: UUID.self) { id in
                        if let binding = store.binding(for: id) {
                            ProjectDetailView(project: binding)
                        } else {
                            ContentUnavailableView("Project not found", systemImage: "questionmark.folder")
                        }
                    }
            }
        }
        .onAppear { if path.isEmpty { path = initialPath } }
        .onChange(of: selection) { path = [] }
        .onReceive(NotificationCenter.default.publisher(for: .newProject)) { _ in requestNew() }
        .sheet(isPresented: $showNew) {
            NewProjectSheet(defaultHobby: {
                if case .hobby(let h) = selection { return h } else { return .gardening }
            }()) { id in path = [id] }
        }
    }

    private func requestNew() {
        showNew = true
    }

    private func row(_ item: SidebarItem, symbol: String, color: Color, count: Int) -> some View {
        Label {
            HStack {
                Text(item.title)
                Spacer()
                if count > 0 { Text("\(count)").foregroundStyle(.secondary).font(.callout.monospacedDigit()) }
            }
        } icon: {
            Image(systemName: symbol).foregroundStyle(color)
        }
        .tag(item)
    }
}

// MARK: - Project grid

struct ProjectGridView: View {
    @EnvironmentObject var store: AppStore
    let filter: SidebarItem
    let onNew: () -> Void
    @State private var search = ""
    @State private var sort: Sort = .recent
    @State private var pendingDelete: Project?

    enum Sort: String, CaseIterable { case recent = "Recently Created", name = "Name", progress = "Progress" }

    private var projects: [Project] {
        var list = store.projects
        switch filter {
        case .all: break
        case .active: list = list.filter { $0.status == .active }
        case .hobby(let h): list = list.filter { $0.hobby == h }
        }
        if !search.isEmpty {
            list = list.filter { $0.name.localizedCaseInsensitiveContains(search) || $0.summary.localizedCaseInsensitiveContains(search) }
        }
        switch sort {
        case .recent: list.sort { $0.createdAt > $1.createdAt }
        case .name: list.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .progress: list.sort { $0.progress > $1.progress }
        }
        return list
    }

    var body: some View {
        Group {
            if projects.isEmpty {
                emptyState
            } else {
                ScrollView {
                    if filter == .all && search.isEmpty { StatsStrip(projects: store.projects, currency: store.library.currency) }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 250, maximum: 340), spacing: 18)], spacing: 18) {
                        ForEach(projects) { p in
                            NavigationLink(value: p.id) { ProjectCardView(project: p) }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Menu("Status") {
                                        ForEach(ProjectStatus.allCases) { s in
                                            Button(s.title) { store.binding(for: p.id)?.wrappedValue.status = s }
                                        }
                                    }
                                    Button("Duplicate") { store.duplicateProject(p.id) }
                                    Divider()
                                    Button("Delete…", role: .destructive) { pendingDelete = p }
                                }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle(filter.title)
        .searchable(text: $search, placement: .toolbar, prompt: "Search projects")
        .toolbar {
            ToolbarItem {
                Picker("Sort", selection: $sort) {
                    ForEach(Sort.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.menu)
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: onNew) { Label("New Project", systemImage: "plus") }
            }
        }
        .confirmationDialog("Delete “\(pendingDelete?.name ?? "")”?", isPresented: Binding(
            get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
            Button("Delete Project and Photos", role: .destructive) {
                if let p = pendingDelete { store.deleteProject(p.id) }
            }
        } message: {
            Text("This removes its board, materials and progress photos. It can't be undone.")
        }
    }

    @ViewBuilder private var emptyState: some View {
        if !search.isEmpty {
            ContentUnavailableView.search(text: search)
        } else {
            ContentUnavailableView {
                Label(filter == .all ? "Start your first project" : "No \(filter.title) projects yet",
                      systemImage: { if case .hobby(let h) = filter { return h.symbol } else { return "map" } }())
            } description: {
                Text("Plan it on a board, track materials and costs, and document progress with photos.")
            } actions: {
                Button("New Project", action: onNew).buttonStyle(.borderedProminent)
            }
        }
    }
}

struct StatsStrip: View {
    let projects: [Project]
    let currency: String

    var body: some View {
        HStack(spacing: 14) {
            stat("Active", "\(projects.filter { $0.status == .active }.count)", "flame.fill", .orange)
            stat("Finished", "\(projects.filter { $0.status == .done }.count)", "checkmark.seal.fill", .green)
            stat("Photos", "\(projects.reduce(0) { $0 + $1.photos.count })", "photo.stack.fill", .blue)
            stat("Still to buy", projects.reduce(0) { $0 + $1.materialsToBuy }.money(currency), "cart.fill", .pink)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private func stat(_ title: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
                .frame(width: 36, height: 36).background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.title3.weight(.semibold).monospacedDigit())
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct ProjectCardView: View {
    @EnvironmentObject var store: AppStore
    let project: Project
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                if let cover = project.coverPhoto {
                    Color.clear.overlay { PhotoImage(url: store.url(for: cover)) }.clipped()
                } else {
                    LinearGradient(colors: [project.hobby.color.opacity(0.85), project.hobby.color.opacity(0.45)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: project.hobby.symbol)
                        .font(.system(size: 46, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                HStack(spacing: 4) {
                    Image(systemName: project.hobby.symbol)
                    Text(project.hobby.title)
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(10)
            }
            .frame(height: 140)
            .clipped()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(project.name).font(.headline).lineLimit(1)
                    Spacer()
                    StatusPill(status: project.status)
                }
                if !project.summary.isEmpty {
                    Text(project.summary).font(.callout).foregroundStyle(.secondary).lineLimit(2)
                }
                ProgressView(value: project.progress).tint(project.hobby.color)
                HStack(spacing: 12) {
                    Label("\(project.columns.last?.cards.count ?? 0)/\(project.allCards.count)", systemImage: "checklist")
                    Label("\(project.materials.count)", systemImage: "shippingbox")
                    Label("\(project.photos.count)", systemImage: "photo")
                    Spacer()
                    if let d = project.targetDate {
                        Label(d.formatted(.dateTime.month(.abbreviated).day()), systemImage: "calendar")
                    }
                }
                .font(.caption).foregroundStyle(.secondary).labelStyle(.titleAndIcon)
            }
            .padding(12)
        }
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.separator.opacity(hovering ? 1 : 0.5)))
        .shadow(color: .black.opacity(hovering ? 0.15 : 0.05), radius: hovering ? 10 : 4, y: 2)
        .scaleEffect(hovering ? 1.01 : 1)
        .animation(.easeOut(duration: 0.15), value: hovering)
        .onHover { hovering = $0 }
    }
}

struct StatusPill: View {
    let status: ProjectStatus
    var body: some View {
        Text(status.title)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(status.color.opacity(0.18), in: Capsule())
            .foregroundStyle(status.color)
    }
}

// MARK: - New project

struct NewProjectSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State var hobby: HobbyKind
    @State private var name = ""
    @State private var templateID: String
    @State private var hasTarget = false
    @State private var target = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    let onCreate: (UUID) -> Void

    init(defaultHobby: HobbyKind, onCreate: @escaping (UUID) -> Void) {
        _hobby = State(initialValue: defaultHobby)
        _templateID = State(initialValue: HobbyTemplate.templates(for: defaultHobby)[0].id)
        self.onCreate = onCreate
    }

    private var templates: [HobbyTemplate] { HobbyTemplate.templates(for: hobby) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("New Project").font(.title2.bold())

            TextField("Project name", text: $name, prompt: Text("e.g. Spitfire Mk IX 1:48"))
                .textFieldStyle(.roundedBorder).font(.title3)

            VStack(alignment: .leading, spacing: 8) {
                Text("Hobby").font(.headline)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(HobbyKind.allCases) { h in
                        Button { hobby = h; templateID = HobbyTemplate.templates(for: h)[0].id } label: {
                            HStack {
                                Image(systemName: h.symbol).foregroundStyle(hobby == h ? .white : h.color)
                                Text(h.title)
                                Spacer(minLength: 0)
                            }
                            .padding(10)
                            .background(hobby == h ? h.color : Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(hobby == h ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Start from").font(.headline)
                ForEach(templates) { t in
                    Button { templateID = t.id } label: {
                        HStack(alignment: .top) {
                            Image(systemName: templateID == t.id ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(templateID == t.id ? hobby.color : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t.name).fontWeight(.medium)
                                Text(t.summary.isEmpty ? "To Do · In Progress · Done" : t.summary + "  ·  " + t.columns.map(\.0).joined(separator: " → "))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Toggle("Target date", isOn: $hasTarget)
                if hasTarget { DatePicker("", selection: $target, displayedComponents: .date).labelsHidden() }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Create Project") { create() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 520)
    }

    private func create() {
        let t = templates.first { $0.id == templateID } ?? HobbyTemplate.blank(hobby)
        var p = t.makeProject(named: name.trimmingCharacters(in: .whitespaces), target: hasTarget ? target : nil)
        p.status = .active
        let id = store.addProject(p)
        dismiss()
        onCreate(id)
    }
}
