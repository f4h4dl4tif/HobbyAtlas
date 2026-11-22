import SwiftUI

enum ProjectTab: String, CaseIterable, Identifiable {
    case board = "Board", materials = "Materials", photos = "Progress Photos", notes = "Notes"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .board: "rectangle.split.3x1"
        case .materials: "shippingbox"
        case .photos: "photo.on.rectangle.angled"
        case .notes: "note.text"
        }
    }
}

struct ProjectDetailView: View {
    @EnvironmentObject var store: AppStore
    @Binding var project: Project
    @State var tab: ProjectTab = .board
    @State private var showInfo = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Group {
                switch tab {
                case .board: BoardView(project: $project)
                case .materials: MaterialsView(project: $project)
                case .photos: PhotosView(project: $project)
                case .notes: NotesView(project: $project)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(project.name)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("View", selection: $tab) {
                    ForEach(ProjectTab.allCases) { t in Label(t.rawValue, systemImage: t.symbol).tag(t) }
                }
                .pickerStyle(.segmented)
                .labelStyle(.titleOnly)
                .frame(width: 420)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: project.hobby.symbol)
                .font(.title2).foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(project.hobby.color.gradient, in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 3) {
                TextField("Project name", text: $project.name)
                    .textFieldStyle(.plain).font(.title2.bold())
                TextField("Add a short description", text: $project.summary)
                    .textFieldStyle(.plain).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 10) {
                    Picker("Status", selection: $project.status) {
                        ForEach(ProjectStatus.allCases) { Text($0.title).tag($0) }
                    }
                    .labelsHidden().fixedSize()
                    Button { showInfo.toggle() } label: {
                        Label(project.targetDate.map { "Due " + $0.formatted(date: .abbreviated, time: .omitted) } ?? "Set target",
                              systemImage: "calendar")
                    }
                    .popover(isPresented: $showInfo) { targetPopover }
                }
                HStack(spacing: 8) {
                    ProgressView(value: project.progress).tint(project.hobby.color).frame(width: 140)
                    Text("\(Int(project.progress * 100))%").font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
    }

    private var targetPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Hobby", selection: $project.hobby) {
                ForEach(HobbyKind.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
            }
            Toggle("Target date", isOn: Binding(
                get: { project.targetDate != nil },
                set: { project.targetDate = $0 ? (project.targetDate ?? Date()) : nil }))
            if project.targetDate != nil {
                DatePicker("Due", selection: Binding(get: { project.targetDate ?? Date() }, set: { project.targetDate = $0 }),
                           displayedComponents: .date)
                    .datePickerStyle(.graphical)
            }
            Text("Started \(project.createdAt.formatted(date: .long, time: .omitted))")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .frame(width: 280)
    }
}

struct NotesView: View {
    @Binding var project: Project
    var body: some View {
        TextEditor(text: $project.notes)
            .font(.body)
            .scrollContentBackground(.hidden)
            .padding(16)
            .overlay(alignment: .topLeading) {
                if project.notes.isEmpty {
                    Text("Ideas, measurements, links, lessons learned…")
                        .foregroundStyle(.tertiary).padding(.horizontal, 21).padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
    }
}
