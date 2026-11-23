import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Photo progress timeline: drop or import photos, caption them, set a cover, and compare before/after.
struct PhotosView: View {
    @EnvironmentObject var store: AppStore
    @Binding var project: Project
    @State private var importing = false
    @State private var dropping = false
    @State private var selected: UUID?
    @State private var compareMode = false
    @State private var compareIDs: [UUID] = []
    @State private var showCompare = false

    private var sorted: [ProgressPhoto] { project.photos.sorted { $0.takenAt > $1.takenAt } }

    private var groups: [(String, [ProgressPhoto])] {
        let byMonth = Dictionary(grouping: sorted) { $0.takenAt.formatted(.dateTime.year().month(.wide)) }
        return byMonth.sorted { ($0.value.first?.takenAt ?? .distantPast) > ($1.value.first?.takenAt ?? .distantPast) }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if project.photos.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        ForEach(groups, id: \.0) { month, photos in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(month).font(.headline)
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180, maximum: 260), spacing: 12)], spacing: 12) {
                                    ForEach(photos) { photo in tile(photo) }
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .overlay {
            if dropping {
                RoundedRectangle(cornerRadius: 16).strokeBorder(project.hobby.color, style: StrokeStyle(lineWidth: 3, dash: [8]))
                    .background(project.hobby.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(Label("Drop photos to add them", systemImage: "photo.badge.plus").font(.title3))
                    .padding(12)
            }
        }
        .onDrop(of: [.fileURL, .image], isTargeted: $dropping, perform: handleDrop)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { add(store.importPhotos(urls)) }
        }
        .sheet(item: Binding(get: { selected.map(PhotoRef.init) }, set: { selected = $0?.id })) { ref in
            if let i = project.photos.firstIndex(where: { $0.id == ref.id }) {
                PhotoDetail(photo: $project.photos[i],
                            url: store.url(for: project.photos[i]),
                            isCover: project.coverPhoto?.id == ref.id,
                            setCover: { project.coverPhotoID = ref.id },
                            onDelete: { delete(ref.id) })
            }
        }
        .sheet(isPresented: $showCompare) {
            if compareIDs.count == 2,
               let a = project.photos.first(where: { $0.id == compareIDs[0] }),
               let b = project.photos.first(where: { $0.id == compareIDs[1] }) {
                let (before, after) = a.takenAt <= b.takenAt ? (a, b) : (b, a)
                CompareView(before: before, after: after, beforeURL: store.url(for: before), afterURL: store.url(for: after))
            }
        }
    }

    struct PhotoRef: Identifiable { let id: UUID }

    private var toolbar: some View {
        HStack {
            Text("\(project.photos.count) photo\(project.photos.count == 1 ? "" : "s")").foregroundStyle(.secondary)
            if let first = sorted.last, let last = sorted.first, project.photos.count > 1 {
                let days = Calendar.current.dateComponents([.day], from: first.takenAt, to: last.takenAt).day ?? 0
                Text("· \(days) days of progress").foregroundStyle(.secondary)
            }
            Spacer()
            if compareMode {
                Text(compareIDs.count < 2 ? "Pick \(2 - compareIDs.count) photo\(compareIDs.count == 1 ? "" : "s")" : "Ready")
                    .foregroundStyle(.secondary)
                Button("Compare") { showCompare = true }.disabled(compareIDs.count != 2).buttonStyle(.borderedProminent)
                Button("Cancel") { compareMode = false; compareIDs = [] }
            } else {
                Button { compareMode = true } label: { Label("Before / After", systemImage: "rectangle.split.2x1") }
                    .disabled(project.photos.count < 2)
                Button { importing = true } label: { Label("Add Photos", systemImage: "plus") }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
    }

    private func tile(_ photo: ProgressPhoto) -> some View {
        let picked = compareIDs.contains(photo.id)
        return VStack(alignment: .leading, spacing: 6) {
            Color.clear
                .frame(height: 150).frame(maxWidth: .infinity)
                .overlay { PhotoImage(url: store.url(for: photo), maxPixel: 600) }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(alignment: .topTrailing) {
                    if compareMode {
                        Image(systemName: picked ? "checkmark.circle.fill" : "circle")
                            .font(.title2).foregroundStyle(picked ? project.hobby.color : .white)
                            .shadow(radius: 2).padding(8)
                    } else if project.coverPhoto?.id == photo.id {
                        Image(systemName: "star.fill").foregroundStyle(.yellow).shadow(radius: 2).padding(8)
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(picked ? project.hobby.color : .clear, lineWidth: 3))
            Text(photo.caption.isEmpty ? "No caption" : photo.caption)
                .font(.callout).lineLimit(1).foregroundStyle(photo.caption.isEmpty ? .tertiary : .primary)
            Text(photo.takenAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if compareMode {
                if picked { compareIDs.removeAll { $0 == photo.id } }
                else { compareIDs = Array((compareIDs + [photo.id]).suffix(2)) }
            } else {
                selected = photo.id
            }
        }
        .contextMenu {
            Button("Set as Cover") { project.coverPhotoID = photo.id }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([store.url(for: photo)]) }
            Divider()
            Button("Delete Photo", role: .destructive) { delete(photo.id) }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Document your progress", systemImage: "camera.on.rectangle")
        } description: {
            Text("Drop photos here or add them from Finder. Capture dates are read from the photo so your timeline stays in order.")
        } actions: {
            Button("Add Photos") { importing = true }.buttonStyle(.borderedProminent)
        }
    }

    private func add(_ photos: [ProgressPhoto]) {
        guard !photos.isEmpty else { return }
        withAnimation { project.photos.append(contentsOf: photos) }
    }

    private func delete(_ id: UUID) {
        guard let p = project.photos.first(where: { $0.id == id }) else { return }
        store.deletePhotoFile(p)
        project.photos.removeAll { $0.id == id }
        if project.coverPhotoID == id { project.coverPhotoID = nil }
        if selected == id { selected = nil }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                handled = true
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    Task { @MainActor in add(store.importPhotos([url])) }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                handled = true
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    guard let data else { return }
                    Task { @MainActor in if let p = store.importImageData(data) { add([p]) } }
                }
            }
        }
        return handled
    }
}

struct PhotoDetail: View {
    @Binding var photo: ProgressPhoto
    let url: URL
    let isCover: Bool
    let setCover: () -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 14) {
            PhotoImage(url: url, maxPixel: 2400, contentMode: .fit)
                .frame(maxWidth: 820, maxHeight: 560)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            TextField("Caption — what changed?", text: $photo.caption).textFieldStyle(.roundedBorder).font(.title3)
            HStack {
                DatePicker("Taken", selection: $photo.takenAt)
                Spacer()
                Button(isCover ? "Cover Photo" : "Set as Cover", systemImage: isCover ? "star.fill" : "star", action: setCover)
                    .disabled(isCover)
                Button("Delete", role: .destructive) { onDelete(); dismiss() }
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(minWidth: 640)
    }
}

/// Drag the handle to wipe between the earlier and later photo.
struct CompareView: View {
    let before: ProgressPhoto
    let after: ProgressPhoto
    let beforeURL: URL
    let afterURL: URL
    @State private var split: CGFloat = 0.5
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 14) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Color.clear.frame(width: geo.size.width, height: geo.size.height)
                        .overlay { PhotoImage(url: afterURL, maxPixel: 1400) }.clipped()
                    Color.clear.frame(width: geo.size.width, height: geo.size.height)
                        .overlay { PhotoImage(url: beforeURL, maxPixel: 1400) }.clipped()
                        .mask(alignment: .leading) { Rectangle().frame(width: geo.size.width * split) }
                    Rectangle().fill(.white).frame(width: 3).shadow(radius: 3)
                        .offset(x: geo.size.width * split - 1.5)
                    Circle().fill(.white).frame(width: 34, height: 34).shadow(radius: 3)
                        .overlay(Image(systemName: "arrow.left.and.right").foregroundStyle(.black))
                        .offset(x: geo.size.width * split - 17)
                    VStack {
                        HStack {
                            badge("Before · " + before.takenAt.formatted(date: .abbreviated, time: .omitted))
                            Spacer()
                            badge("After · " + after.takenAt.formatted(date: .abbreviated, time: .omitted))
                        }
                        Spacer()
                    }
                    .padding(10)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                    split = min(max(v.location.x / geo.size.width, 0), 1)
                })
            }
            .frame(width: 820, height: 540)
            HStack {
                let days = Calendar.current.dateComponents([.day], from: before.takenAt, to: after.takenAt).day ?? 0
                Text("\(days) days apart").foregroundStyle(.secondary)
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
    }

    private func badge(_ text: String) -> some View {
        Text(text).font(.caption.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .glassOr(Capsule(), fill: .ultraThinMaterial)
    }
}
