import AppKit
import SwiftUI

/// `HOBBYATLAS_SNAPSHOT=<dir> HobbyAtlas` renders the main screens with demo data into PNGs, then quits.
/// Uses a throwaway library so real data is never touched. Handy for store screenshots and checks.
@MainActor
enum Snapshot {
    static var windows: [NSWindow] = []

    static func run(to dir: String) {
        let out = URL(fileURLWithPath: dir)
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        NSApp.windows.forEach { $0.orderOut(nil) }

        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("HobbyAtlasSnapshot-\(UUID().uuidString)")
        let store = AppStore(baseURL: tmp)
        let projectID = seed(store)
        let binding = store.binding(for: projectID)!

        let shots: [(String, AnyView, CGSize)] = [
            ("1-dashboard", AnyView(ContentView()), CGSize(width: 1280, height: 800)),
            ("2-board", AnyView(NavigationStack { ProjectDetailView(project: binding, tab: .board) }), CGSize(width: 1280, height: 760)),
            ("3-materials", AnyView(NavigationStack { ProjectDetailView(project: binding, tab: .materials) }), CGSize(width: 1280, height: 640)),
            ("4-photos", AnyView(NavigationStack { ProjectDetailView(project: binding, tab: .photos) }), CGSize(width: 1280, height: 720)),
            ("5-new-project", AnyView(NewProjectSheet(defaultHobby: .woodworking) { _ in }), CGSize(width: 520, height: 600)),
        ]

        for (i, shot) in shots.enumerated() {
            let view = shot.1.environmentObject(store)
                .background(Color(nsColor: .windowBackgroundColor))
                .environment(\.colorScheme, .dark)
            let host = NSHostingView(rootView: view)
            host.appearance = NSAppearance(named: .darkAqua)
            let w = NSWindow(contentRect: NSRect(origin: CGPoint(x: -4000 - i * 1400, y: 0), size: shot.2),
                             styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
            w.contentView = host
            w.isReleasedWhenClosed = false
            w.orderFront(nil)
            windows.append(w)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            for (w, shot) in zip(windows, shots) {
                guard let v = w.contentView, let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds) else { continue }
                v.cacheDisplay(in: v.bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?.write(to: out.appendingPathComponent(shot.0 + ".png"))
            }
            try? FileManager.default.removeItem(at: tmp)
            print("Snapshots written to \(out.path)")
            NSApp.terminate(nil)
        }
    }

    private static func seed(_ store: AppStore) -> UUID {
        let cal = Calendar.current
        func daysAgo(_ d: Int) -> Date { cal.date(byAdding: .day, value: -d, to: Date())! }

        var table = HobbyTemplate.all.first { $0.id == "wood-furniture" }!.makeProject(named: "Walnut Side Table", target: daysAgo(-21))
        table.summary = "Mid-century side table with tapered legs and a floating top."
        table.status = .active
        table.createdAt = daysAgo(30)
        // Move some cards along the board.
        let design = table.columns[0].cards
        table.columns[0].cards = []
        table.columns[4].cards = design
        let milling = table.columns[1].cards
        table.columns[1].cards = []
        table.columns[4].cards += milling
        table.columns[2].cards[0].label = .orange
        table.columns[2].cards[0].checklist = [ChecklistItem(text: "Mortises", done: true), ChecklistItem(text: "Tenons", done: true),
                                               ChecklistItem(text: "Test fit", done: false)]
        table.columns[2].cards[0].due = daysAgo(-3)
        table.columns[2].cards[1].notes = "Check for racking"
        table.columns[3].cards[0].label = .blue
        table.materials[0].status = .have
        table.materials[1].status = .have
        table.materials[2].status = .ordered
        table.materials.append(Material(name: "Brass tabletop fasteners", quantity: 8, unit: "pcs", unitCost: 0.75,
                                        status: .need, supplier: "https://www.example.com"))
        let palette: [(NSColor, String, Int)] = [
            (NSColor(red: 0.55, green: 0.40, blue: 0.28, alpha: 1), "Rough lumber", 28),
            (NSColor(red: 0.62, green: 0.46, blue: 0.30, alpha: 1), "Milled & squared", 22),
            (NSColor(red: 0.48, green: 0.34, blue: 0.24, alpha: 1), "Leg tapers cut", 15),
            (NSColor(red: 0.40, green: 0.28, blue: 0.20, alpha: 1), "Dry fit", 6),
            (NSColor(red: 0.35, green: 0.24, blue: 0.17, alpha: 1), "First coat of oil", 1),
        ]
        for (color, caption, ago) in palette {
            if var p = store.importImageData(demoImage(color, caption).tiffRepresentation!) {
                p.caption = caption
                p.takenAt = daysAgo(ago)
                table.photos.append(p)
            }
        }

        var garden = HobbyTemplate.all.first { $0.id == "garden-raised-bed" }!.makeProject(named: "Spring Raised Beds", target: nil)
        garden.status = .active
        garden.createdAt = daysAgo(10)
        garden.columns[3].cards = [BoardCard(title: "Radishes"), BoardCard(title: "Lettuce")]
        var model = HobbyTemplate.all.first { $0.id == "model-scale-kit" }!.makeProject(named: "Spitfire Mk IX 1:48", target: nil)
        model.status = .planning
        model.createdAt = daysAgo(5)
        var synth = HobbyTemplate.all.first { $0.id == "electronics-arduino" }!.makeProject(named: "Plant Moisture Monitor", target: nil)
        synth.status = .done
        synth.createdAt = daysAgo(60)
        synth.columns[3].cards = synth.columns.dropLast().flatMap(\.cards)
        for i in 0..<3 { synth.columns[i].cards = [] }
        var coins = HobbyTemplate.all.first { $0.id == "collection-catalog" }!.makeProject(named: "World Coins", target: nil)
        coins.status = .paused
        coins.createdAt = daysAgo(90)
        coins.columns[0].cards = [BoardCard(title: "1967 Canadian centennial set"), BoardCard(title: "Japanese 5 yen")]
        coins.columns[2].cards = [BoardCard(title: "UK 50p Kew Gardens")]

        store.library.projects = [table, garden, model, synth, coins]
        return table.id
    }

    private static func demoImage(_ color: NSColor, _ text: String) -> NSImage {
        let size = NSSize(width: 1200, height: 800)
        return NSImage(size: size, flipped: false) { r in
            NSGradient(colors: [color.blended(withFraction: 0.35, of: .white)!, color])!.draw(in: r, angle: -60)
            for i in 0..<14 { // wood grain
                let y = CGFloat(i) * 60 + 20
                let p = NSBezierPath()
                p.move(to: NSPoint(x: 0, y: y))
                p.curve(to: NSPoint(x: 1200, y: y + 30), controlPoint1: NSPoint(x: 400, y: y + 50), controlPoint2: NSPoint(x: 800, y: y - 30))
                color.withAlphaComponent(0.35).setStroke(); p.lineWidth = 6; p.stroke()
            }
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 64, weight: .bold),
                                                        .foregroundColor: NSColor.white.withAlphaComponent(0.9)]
            (text as NSString).draw(at: NSPoint(x: 60, y: 60), withAttributes: attrs)
            return true
        }
    }
}
