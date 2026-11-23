import SwiftUI
import AppKit

@main
struct HobbyAtlasApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup("HobbyAtlas") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 980, minHeight: 640)
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Project…") { NotificationCenter.default.post(name: .newProject, object: nil) }
                    .keyboardShortcut("n")
            }
        }

        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        if let dir = Snapshot.glassOutputDir {
            Task { @MainActor in Snapshot.runGlass(to: dir) }
            return
        }
        #endif
        if let dir = ProcessInfo.processInfo.environment["HOBBYATLAS_SNAPSHOT"] {
            Task { @MainActor in Snapshot.run(to: dir) }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

extension Notification.Name {
    static let newProject = Notification.Name("HobbyAtlas.newProject")
}

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @AppStorage(GlassTheme.key) private var glassTheme = false

    var body: some View {
        TabView {
            Form {
                Section("Currency") {
                    Picker("Currency", selection: $store.library.currency) {
                        ForEach(["USD", "EUR", "GBP", "CAD", "AUD", "SAR", "AED", "INR", "PKR", "JPY"], id: \.self) { Text($0) }
                    }
                }
                Section {
                    Toggle("Liquid Glass theme", isOn: $glassTheme).disabled(!GlassTheme.isSupported)
                } header: {
                    Text("Appearance")
                } footer: {
                    Text(GlassTheme.isSupported ? "Liquid Glass cards, board columns and badges over a soft tinted backdrop."
                                                : "Requires macOS 26 or later.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Storage") {
                    LabeledContent("Projects", value: "\(store.projects.count)")
                    LabeledContent("Photos", value: "\(store.projects.reduce(0) { $0 + $1.photos.count })")
                    Button("Show Data Folder in Finder") { NSWorkspace.shared.activateFileViewerSelecting([store.baseURL]) }
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("General", systemImage: "gearshape") }

            VStack(spacing: 10) {
                Image(systemName: "map.fill").font(.system(size: 36))
                    .foregroundStyle(LinearGradient(colors: [.teal, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                Text("HobbyAtlas").font(.title2.bold())
                Text("Free and open source under the MIT License.\nEvery feature is included — no accounts, no paywalls.")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 460, height: 420)
    }
}
