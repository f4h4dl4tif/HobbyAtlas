import SwiftUI

/// Optional Liquid Glass theme (macOS 26+), stored in UserDefaults under `glassTheme`. Off by default;
/// with it off every view keeps its original look.
enum GlassTheme {
    static let key = "glassTheme"
    static var isSupported: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }
}

/// Soft teal-to-indigo wash (the app icon's colours) behind grids and boards so glass has something to refract.
struct HobbyBackdrop: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let dark = scheme == .dark
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(colors: [Color.teal.opacity(dark ? 0.28 : 0.22), Color.indigo.opacity(dark ? 0.30 : 0.16)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            GeometryReader { g in
                Circle().fill(Color.orange.opacity(dark ? 0.12 : 0.14)).frame(width: g.size.width * 0.45).blur(radius: 110)
                    .position(x: g.size.width * 0.85, y: g.size.height * 0.85)
                Circle().fill(Color.teal.opacity(dark ? 0.22 : 0.20)).frame(width: g.size.width * 0.4).blur(radius: 100)
                    .position(x: g.size.width * 0.1, y: g.size.height * 0.1)
            }
        }
        .ignoresSafeArea()
    }
}

struct GlassBackdrop: ViewModifier {
    @AppStorage(GlassTheme.key) private var stored = false
    private var glass: Bool { stored && GlassTheme.isSupported }
    var enabled = true
    func body(content: Content) -> some View {
        if glass && enabled { content.background { HobbyBackdrop() } } else { content }
    }
}

/// Keeps dense content (tables, editors) on a solid readable surface when the backdrop is showing behind it.
struct SolidWhenGlass: ViewModifier {
    @AppStorage(GlassTheme.key) private var stored = false
    private var glass: Bool { stored && GlassTheme.isSupported }
    func body(content: Content) -> some View {
        if glass { content.background(Color(nsColor: .windowBackgroundColor)) } else { content }
    }
}

/// Glass in a shape when the theme is on; otherwise the original `.background(fill, in: shape)`.
struct GlassOrFill<S: Shape, F: ShapeStyle>: ViewModifier {
    @AppStorage(GlassTheme.key) private var stored = false
    private var glass: Bool { stored && GlassTheme.isSupported }
    let shape: S
    let fill: F
    var tint: Color? = nil

    func body(content: Content) -> some View {
        if glass, #available(macOS 26, *) {
            content.glassEffect(tint.map { Glass.regular.tint($0) } ?? .regular, in: shape)
        } else {
            content.background(fill, in: shape)
        }
    }
}

extension View {
    func glassBackdrop(enabled: Bool = true) -> some View { modifier(GlassBackdrop(enabled: enabled)) }
    func solidWhenGlass() -> some View { modifier(SolidWhenGlass()) }
    func glassOr<S: Shape, F: ShapeStyle>(_ shape: S, fill: F, tint: Color? = nil) -> some View {
        modifier(GlassOrFill(shape: shape, fill: fill, tint: tint))
    }
}

struct ProminentButton: ViewModifier {
    @AppStorage(GlassTheme.key) private var stored = false
    private var glass: Bool { stored && GlassTheme.isSupported }
    func body(content: Content) -> some View {
        if glass, #available(macOS 26, *) { content.buttonStyle(.glassProminent) } else { content.buttonStyle(.borderedProminent) }
    }
}
