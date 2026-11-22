import AppKit

// Renders HobbyAtlas's icon: a teal-to-indigo squircle with a folded map and a location pin.
let out = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let inset = s * 0.098
    let r = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let bg = NSBezierPath(roundedRect: r, xRadius: r.width * 0.225, yRadius: r.width * 0.225)

    NSGraphicsContext.saveGraphicsState()
    let sh = NSShadow()
    sh.shadowBlurRadius = s * 0.025
    sh.shadowOffset = NSSize(width: 0, height: -s * 0.012)
    sh.shadowColor = NSColor.black.withAlphaComponent(0.35)
    sh.set()
    NSColor.black.setFill(); bg.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(colors: [
        NSColor(red: 0.20, green: 0.74, blue: 0.70, alpha: 1),
        NSColor(red: 0.25, green: 0.50, blue: 0.86, alpha: 1),
        NSColor(red: 0.38, green: 0.32, blue: 0.84, alpha: 1),
    ])!.draw(in: bg, angle: -65)

    let u = r.width / 100

    // Folded map: three panels
    let panelW = 20 * u, panelH = 46 * u, baseX = r.minX + 20 * u, baseY = r.minY + 20 * u
    let shades: [CGFloat] = [1.0, 0.86, 1.0]
    for i in 0..<3 {
        let x = baseX + CGFloat(i) * panelW
        let lift: CGFloat = i == 1 ? 3 * u : 0
        let p = NSBezierPath()
        p.move(to: NSPoint(x: x, y: baseY + (i == 1 ? lift : 0)))
        p.line(to: NSPoint(x: x + panelW, y: baseY + (i == 1 ? 0 : lift)))
        p.line(to: NSPoint(x: x + panelW, y: baseY + panelH + (i == 1 ? 0 : lift)))
        p.line(to: NSPoint(x: x, y: baseY + panelH + (i == 1 ? lift : 0)))
        p.close()
        NSColor(white: shades[i], alpha: 0.95).setFill(); p.fill()
    }
    // Dashed trail across the map
    let trail = NSBezierPath()
    trail.move(to: NSPoint(x: baseX + 6 * u, y: baseY + 10 * u))
    trail.curve(to: NSPoint(x: baseX + 44 * u, y: baseY + 30 * u),
                controlPoint1: NSPoint(x: baseX + 20 * u, y: baseY + 4 * u),
                controlPoint2: NSPoint(x: baseX + 28 * u, y: baseY + 34 * u))
    trail.lineWidth = 2.6 * u
    trail.setLineDash([4 * u, 3 * u], count: 2, phase: 0)
    trail.lineCapStyle = .round
    NSColor(red: 0.25, green: 0.50, blue: 0.86, alpha: 0.8).setStroke(); trail.stroke()

    // Pin
    let cx = baseX + 44 * u, cy = baseY + 42 * u
    let pin = NSBezierPath()
    pin.move(to: NSPoint(x: cx, y: cy - 14 * u))
    pin.curve(to: NSPoint(x: cx - 10 * u, y: cy + 4 * u), controlPoint1: NSPoint(x: cx - 4 * u, y: cy - 6 * u), controlPoint2: NSPoint(x: cx - 10 * u, y: cy - 3 * u))
    pin.appendArc(withCenter: NSPoint(x: cx, y: cy + 4 * u), radius: 10 * u, startAngle: 180, endAngle: 0, clockwise: true)
    pin.curve(to: NSPoint(x: cx, y: cy - 14 * u), controlPoint1: NSPoint(x: cx + 10 * u, y: cy - 3 * u), controlPoint2: NSPoint(x: cx + 4 * u, y: cy - 6 * u))
    pin.close()
    NSGraphicsContext.saveGraphicsState()
    let psh = NSShadow(); psh.shadowBlurRadius = 3 * u; psh.shadowOffset = NSSize(width: 0, height: -1.5 * u)
    psh.shadowColor = NSColor.black.withAlphaComponent(0.3); psh.set()
    NSColor(red: 0.98, green: 0.45, blue: 0.35, alpha: 1).setFill(); pin.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSColor.white.setFill()
    NSBezierPath(ovalIn: NSRect(x: cx - 4 * u, y: cy, width: 8 * u, height: 8 * u)).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for (name, px) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128),
                   ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)] {
    try! render(px).write(to: URL(fileURLWithPath: "\(out)/icon_\(name).png"))
}
