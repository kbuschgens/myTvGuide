#!/usr/bin/env swift
// Genereert de tvOS brand assets (app-icoon in 2 lagen + top shelf) door de SwiftUI-tegel te renderen.
// Gebruik: swift scripts/make_icons.swift tvos/TvGids/Assets.xcassets
import AppKit
import SwiftUI

enum TVGuideStyle {
    static let background = Color(red: 16 / 255, green: 29 / 255, blue: 53 / 255)
    static let accent = Color(red: 120 / 255, green: 174 / 255, blue: 255 / 255)
    static let secondaryText = Color(red: 169 / 255, green: 188 / 255, blue: 216 / 255)
}

/// SF Symbol als gekleurde bitmap: `Image(systemName:)` wordt door ImageRenderer buiten een venster niet getekend.
func whiteSymbol(_ name: String, pointSize: CGFloat, weight: NSFont.Weight) -> NSImage {
    let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
    guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config)
    else { fatalError("symbool \(name) niet gevonden") }
    let scale: CGFloat = 8
    let size = symbol.size
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let rect = NSRect(origin: .zero, size: size)
    symbol.draw(in: rect)
    NSColor.white.setFill()
    rect.fill(using: .sourceIn)
    NSGraphicsContext.restoreGraphicsState()
    let image = NSImage(size: size)
    image.addRepresentation(rep)
    return image
}

/// Ontwerpmaat van de tegel: 400×240 punten (kleine app-tegel op 1x).
struct TVGuideAppTile: View {
    static let symbol = whiteSymbol("list.and.film", pointSize: 100, weight: .medium)

    var showsBackground = true
    var showsContent = true

    var body: some View {
        VStack(spacing: 22) {
            Image(nsImage: Self.symbol)
                .renderingMode(.original)
            Text("tv-gids")
                .font(.system(size: 54, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .opacity(showsContent ? 1 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(showsBackground ? TVGuideStyle.background : .clear)
    }
}

let args = CommandLine.arguments
guard args.count == 2 else { print("gebruik: make_icons.swift <Assets.xcassets>"); exit(1) }
let fm = FileManager.default
let root = URL(fileURLWithPath: args[1]).appendingPathComponent("App Icon & Top Shelf Image.brandassets")
try? fm.removeItem(at: root)

@MainActor
func render(width: Int, height: Int, background: Bool, content: Bool) -> Data {
    // Ontwerp is 400×240; schaal op naar de doelhoogte en laat de tegel in het midden staan.
    let s = Double(height) / 240
    let view = TVGuideAppTile(showsBackground: background, showsContent: content)
        .frame(width: Double(width) / s, height: 240)
        .environment(\.colorScheme, .dark)
    let renderer = ImageRenderer(content: view)
    renderer.scale = s
    renderer.isOpaque = background
    guard let cg = renderer.cgImage else { fatalError("renderen mislukt") }
    return NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])!
}

func write(_ data: Data, _ path: String) throws {
    let url = root.appendingPathComponent(path)
    try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url)
}
func json(_ obj: Any) -> Data { try! JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]) }
let info: [String: Any] = ["author": "xcode", "version": 1]
typealias Size = (scale: String, w: Int, h: Int)

@MainActor
func imageset(_ dir: String, name: String, sizes: [Size], background: Bool, content: Bool) throws {
    var images: [[String: String]] = []
    for s in sizes {
        let file = s.scale == "1x" ? "\(name).png" : "\(name)@\(s.scale).png"
        try write(render(width: s.w, height: s.h, background: background, content: content), "\(dir)/\(file)")
        images.append(["idiom": "tv", "filename": file, "scale": s.scale])
    }
    try write(json(["images": images, "info": info]), "\(dir)/Contents.json")
}

@MainActor
func imagestack(_ dir: String, sizes: [Size]) throws {
    try write(json(["layers": [["filename": "Front.imagestacklayer"], ["filename": "Back.imagestacklayer"]], "info": info]),
              "\(dir)/Contents.json")
    // Voor: alleen symbool + tekst (transparant) voor het parallax-effect; achter: effen achtergrond.
    for (layer, background, content) in [("Front", false, true), ("Back", true, false)] {
        let base = "\(dir)/\(layer).imagestacklayer"
        try write(json(["info": info]), "\(base)/Contents.json")
        try imageset("\(base)/Content.imageset", name: layer.lowercased(), sizes: sizes, background: background, content: content)
    }
}

MainActor.assumeIsolated {
    do {
        try imagestack("App Icon - Large.imagestack", sizes: [("1x", 1280, 768), ("2x", 2560, 1536)])
        try imagestack("App Icon - Small.imagestack", sizes: [("1x", 400, 240), ("2x", 800, 480)])
        try imageset("Top Shelf Image.imageset", name: "topshelf", sizes: [("1x", 1920, 720), ("2x", 3840, 1440)], background: true, content: true)
        try imageset("Top Shelf Image Wide.imageset", name: "topshelf-wide", sizes: [("1x", 2320, 720), ("2x", 4640, 1440)], background: true, content: true)
        try write(json([
            "assets": [
                ["filename": "App Icon - Large.imagestack", "idiom": "tv", "role": "primary-app-icon", "size": "1280x768"],
                ["filename": "App Icon - Small.imagestack", "idiom": "tv", "role": "primary-app-icon", "size": "400x240"],
                ["filename": "Top Shelf Image Wide.imageset", "idiom": "tv", "role": "top-shelf-image-wide", "size": "2320x720"],
                ["filename": "Top Shelf Image.imageset", "idiom": "tv", "role": "top-shelf-image", "size": "1920x720"],
            ],
            "info": info]), "Contents.json")
        try write(json(["info": info]), "../Contents.json")
        print("brand assets geschreven in \(root.path)")
    } catch { print("fout:", error); exit(1) }
}
