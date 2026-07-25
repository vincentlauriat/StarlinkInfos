#!/usr/bin/env swift
// Generates the StarlinkInfos app icon: a dish antenna sending a signal into a
// night sky, on a navy gradient background. Usage: ./Scripts/make-starlink-icon.swift
import AppKit

let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let root = scriptDir.deletingLastPathComponent()
let fm = FileManager.default
guard let assets = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        .first(where: { $0.pathExtension == "" && fm.fileExists(atPath: $0.appendingPathComponent("Assets.xcassets").path) })
        .map({ $0.appendingPathComponent("Assets.xcassets/AppIcon.appiconset") }) else {
    FileHandle.standardError.write(Data("could not locate AppIcon.appiconset\n".utf8))
    exit(1)
}

func render(_ size: Int, previewURL: URL? = nil) -> Data {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: s, height: s)

    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext

    // MARK: Background — night-sky navy gradient, rounded square.
    let rect = NSRect(x: 0, y: 0, width: s, height: s)
    let radius = s * 0.225
    let bgPath = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    bgPath.addClip()

    let sky = NSGradient(colors: [
        NSColor(calibratedRed: 0.06, green: 0.13, blue: 0.30, alpha: 1),  // horizon blue
        NSColor(calibratedRed: 0.015, green: 0.035, blue: 0.09, alpha: 1), // near-black zenith
    ])!
    sky.draw(in: bgPath, angle: 90)

    // Soft glow behind the dish, upper-right, like a rising light.
    if let glow = NSGradient(colors: [
        NSColor(calibratedRed: 0.18, green: 0.42, blue: 0.85, alpha: 0.35),
        NSColor(calibratedRed: 0.18, green: 0.42, blue: 0.85, alpha: 0.0),
    ]) {
        glow.draw(fromCenter: NSPoint(x: s * 0.70, y: s * 0.68), radius: 0,
                  toCenter: NSPoint(x: s * 0.70, y: s * 0.68), radius: s * 0.55,
                  options: [])
    }

    // MARK: Stars — small dots scattered in the upper field.
    let starPositions: [(CGFloat, CGFloat, CGFloat)] = [
        (0.16, 0.82, 0.014), (0.30, 0.90, 0.010), (0.10, 0.62, 0.009),
        (0.44, 0.86, 0.008), (0.22, 0.72, 0.007), (0.62, 0.90, 0.009),
        (0.82, 0.80, 0.011), (0.88, 0.60, 0.008),
    ]
    NSColor.white.withAlphaComponent(0.85).set()
    for (nx, ny, nr) in starPositions {
        let r = s * nr
        let p = NSBezierPath(ovalIn: NSRect(x: s * nx - r, y: s * ny - r, width: r * 2, height: r * 2))
        p.fill()
    }

    // MARK: Signal arcs — concentric quarter-arcs radiating from the dish
    // toward the upper right, evoking a beam reaching a satellite.
    let dishOrigin = NSPoint(x: s * 0.40, y: s * 0.34)
    cg.saveGState()
    for (i, radiusFrac) in [0.30, 0.42, 0.54].enumerated() {
        let arcRadius = s * CGFloat(radiusFrac)
        let alpha = 0.55 - CGFloat(i) * 0.15
        let path = NSBezierPath()
        path.appendArc(withCenter: dishOrigin, radius: arcRadius,
                        startAngle: 28, endAngle: 62)
        path.lineWidth = s * 0.026
        path.lineCapStyle = .round
        NSColor(calibratedRed: 0.55, green: 0.78, blue: 1.0, alpha: alpha).set()
        path.stroke()
    }
    cg.restoreGState()

    // MARK: Dish antenna — tilted ellipse (reflector face) + feed arm + stand.
    cg.saveGState()
    cg.translateBy(x: dishOrigin.x, y: dishOrigin.y)
    cg.rotate(by: -22 * .pi / 180)

    // Stand: a short thick vertical line anchored below the dish.
    let standPath = NSBezierPath()
    standPath.move(to: NSPoint(x: 0, y: -s * 0.02))
    standPath.line(to: NSPoint(x: 0, y: -s * 0.14))
    standPath.lineWidth = s * 0.028
    standPath.lineCapStyle = .round
    NSColor(calibratedRed: 0.72, green: 0.76, blue: 0.83, alpha: 1).set()
    standPath.stroke()

    // Reflector: a filled ellipse (the dish face), pale gradient for a
    // slightly glossy read at large sizes while staying a solid silhouette
    // at 16 px.
    let dishRect = NSRect(x: -s * 0.20, y: -s * 0.075, width: s * 0.40, height: s * 0.15)
    let dishPath = NSBezierPath(ovalIn: dishRect)
    if let dishGradient = NSGradient(colors: [
        NSColor(calibratedWhite: 1.0, alpha: 1.0),
        NSColor(calibratedRed: 0.80, green: 0.85, blue: 0.92, alpha: 1.0),
    ]) {
        dishGradient.draw(in: dishPath, angle: 90)
    }

    // Feed arm: thin line from the dish edge to a small feed-horn dot,
    // the classic satellite-dish silhouette cue.
    let feedStart = NSPoint(x: s * 0.20, y: 0)
    let feedEnd = NSPoint(x: s * 0.32, y: s * 0.10)
    let feedPath = NSBezierPath()
    feedPath.move(to: feedStart)
    feedPath.line(to: feedEnd)
    feedPath.lineWidth = s * 0.018
    feedPath.lineCapStyle = .round
    NSColor(calibratedWhite: 0.95, alpha: 1).set()
    feedPath.stroke()
    let feedDotR = s * 0.028
    NSColor(calibratedWhite: 1.0, alpha: 1).set()
    NSBezierPath(ovalIn: NSRect(x: feedEnd.x - feedDotR, y: feedEnd.y - feedDotR,
                                 width: feedDotR * 2, height: feedDotR * 2)).fill()
    cg.restoreGState()

    NSGraphicsContext.restoreGraphicsState()
    let data = rep.representation(using: .png, properties: [:])!
    if let previewURL {
        try? data.write(to: previewURL)
    }
    return data
}

if CommandLine.arguments.contains("--preview") {
    let previewURL = URL(fileURLWithPath: CommandLine.arguments.count >= 3 ? CommandLine.arguments[2] : "/tmp/starlink-icon-preview.png")
    _ = render(1024, previewURL: previewURL)
    print("wrote preview \(previewURL.path)")
    exit(0)
}

for size in [16, 32, 64, 128, 256, 512, 1024] {
    let url = assets.appendingPathComponent("icon_\(size).png")
    try! render(size).write(to: url)
    print("wrote \(url.lastPathComponent)")
}
print("✅ StarlinkInfos icon set generated")
