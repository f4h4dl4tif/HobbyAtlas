import AppKit
import SwiftUI
import ImageIO
import UniformTypeIdentifiers

/// Local-first storage: one JSON file plus a Photos folder in Application Support.
/// No account and no server, which keeps a one-time price sustainable.
@MainActor
final class AppStore: ObservableObject {
    @Published var library = Library() { didSet { scheduleSave() } }

    let baseURL: URL
    var photosURL: URL { baseURL.appendingPathComponent("Photos", isDirectory: true) }
    private var libraryURL: URL { baseURL.appendingPathComponent("library.json") }
    private var saveWork: DispatchWorkItem?

    init(baseURL: URL? = nil) {
        let fm = FileManager.default
        self.baseURL = baseURL ?? fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HobbyAtlas", isDirectory: true)
        try? fm.createDirectory(at: photosURL, withIntermediateDirectories: true)
        load()
    }

    var projects: [Project] { library.projects }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: libraryURL) else { return }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        if let lib = try? dec.decode(Library.self, from: data) {
            library = lib
        } else {
            // Keep a copy of a file we couldn't read rather than overwriting it.
            let backup = baseURL.appendingPathComponent("library-unreadable-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.copyItem(at: libraryURL, to: backup)
        }
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func saveNow() {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(library) else { return }
        try? data.write(to: libraryURL, options: .atomic)
    }

    // MARK: Projects

    func binding(for id: UUID) -> Binding<Project>? {
        guard library.projects.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { [weak self] in self?.library.projects.first(where: { $0.id == id }) ?? Project(name: "", hobby: .personal) },
            set: { [weak self] new in
                guard let self, let i = self.library.projects.firstIndex(where: { $0.id == id }) else { return }
                self.library.projects[i] = new
            })
    }

    @discardableResult
    func addProject(_ p: Project) -> UUID {
        library.projects.insert(p, at: 0)
        return p.id
    }

    func deleteProject(_ id: UUID) {
        guard let p = library.projects.first(where: { $0.id == id }) else { return }
        for photo in p.photos { try? FileManager.default.removeItem(at: url(for: photo)) }
        library.projects.removeAll { $0.id == id }
    }

    func duplicateProject(_ id: UUID) {
        guard var p = library.projects.first(where: { $0.id == id }) else { return }
        p.id = UUID()
        p.name += " Copy"
        p.createdAt = Date()
        p.photos = []
        p.coverPhotoID = nil
        p.columns = p.columns.map { col in
            var c = col; c.id = UUID(); c.cards = c.cards.map { var x = $0; x.id = UUID(); return x }; return c
        }
        p.materials = p.materials.map { var m = $0; m.id = UUID(); return m }
        addProject(p)
    }

    // MARK: Photos

    func url(for photo: ProgressPhoto) -> URL { photosURL.appendingPathComponent(photo.fileName) }

    /// Copies image files into the library and returns the new photo records.
    func importPhotos(_ urls: [URL]) -> [ProgressPhoto] {
        urls.compactMap { src in
            let access = src.startAccessingSecurityScopedResource()
            defer { if access { src.stopAccessingSecurityScopedResource() } }
            guard let type = UTType(filenameExtension: src.pathExtension), type.conforms(to: .image) else { return nil }
            let ext = src.pathExtension.isEmpty ? "jpg" : src.pathExtension.lowercased()
            let name = "\(UUID().uuidString).\(ext)"
            let dest = photosURL.appendingPathComponent(name)
            do { try FileManager.default.copyItem(at: src, to: dest) } catch { return nil }
            return ProgressPhoto(fileName: name, takenAt: Self.captureDate(of: src) ?? Date())
        }
    }

    func importImageData(_ data: Data) -> ProgressPhoto? {
        guard let img = NSImage(data: data), let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let jpg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) else { return nil }
        let name = "\(UUID().uuidString).jpg"
        do { try jpg.write(to: photosURL.appendingPathComponent(name)) } catch { return nil }
        return ProgressPhoto(fileName: name)
    }

    func deletePhotoFile(_ photo: ProgressPhoto) {
        try? FileManager.default.removeItem(at: url(for: photo))
        ImageCache.shared.evict(url(for: photo))
    }

    private static func captureDate(of url: URL) -> Date? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any],
              let str = exif[kCGImagePropertyExifDateTimeOriginal] as? String else {
            return (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate
        }
        let f = DateFormatter()
        f.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return f.date(from: str)
    }
}

// MARK: - Image cache

final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, NSImage>()

    func thumbnail(_ url: URL, maxPixel: Int = 600) -> NSImage? {
        let key = "\(url.path)#\(maxPixel)" as NSString
        if let img = cache.object(forKey: key) { return img }
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        let img = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        cache.setObject(img, forKey: key)
        return img
    }

    func evict(_ url: URL) {
        for px in [300, 600, 1400, 2400] { cache.removeObject(forKey: "\(url.path)#\(px)" as NSString) }
    }
}

struct PhotoImage: View {
    let url: URL
    var maxPixel = 600
    var contentMode: ContentMode = .fill

    var body: some View {
        if let img = ImageCache.shared.thumbnail(url, maxPixel: maxPixel) {
            Image(nsImage: img).resizable().aspectRatio(contentMode: contentMode)
        } else {
            ZStack {
                Rectangle().fill(.quaternary)
                Image(systemName: "photo").foregroundStyle(.secondary)
            }
        }
    }
}
