#!/usr/bin/env swift
// Genereert de tvOS brand assets (app-icoon in 2 lagen + top shelf) uit image.png.
// Gebruik: swift scripts/make_icons.swift image.png tvos/TvGids/Assets.xcassets
import AppKit

let args = CommandLine.arguments
guard args.count == 3, let src = NSImage(contentsOfFile: args[1]),
      let cg = src.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    print("gebruik: make_icons.swift <image.png> <Assets.xcassets>"); exit(1)
}
let fm = FileManager.default
let root = URL(fileURLWithPath: args[2]).appendingPathComponent("App Icon & Top Shelf Image.brandassets")
try? fm.removeItem(at: root)

// Achtergrondkleur: pixel linksboven in het plaatje.
let rep = NSBitmapImageRep(cgImage: cg)
let bg = rep.colorAt(x: 4, y: 4)!.usingColorSpace(.sRGB)!

func png(_ w: Int, _ h: Int, opaque: Bool, draw: (CGContext) -> Void) -> Data {
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    if opaque { ctx.setFillColor(bg.cgColor); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h)) }
    ctx.interpolationQuality = .high
    draw(ctx)
    return NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
}

/// Plaatje gecentreerd, hoogte = canvas-hoogte (iets kleiner voor het icoon zodat de rand niet wegvalt).
func drawArtwork(_ ctx: CGContext, _ w: Int, _ h: Int, scale: Double) {
    let side = Double(h) * scale
    ctx.draw(cg, in: CGRect(x: (Double(w) - side) / 2, y: (Double(h) - side) / 2, width: side, height: side))
}

func write(_ data: Data, _ path: String) throws {
    let url = root.appendingPathComponent(path)
    try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url)
}
func json(_ obj: Any) -> Data { try! JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]) }
let info: [String: Any] = ["author": "xcode", "version": 1]

func imageset(_ dir: String, name: String, sizes: [(scale: String, w: Int, h: Int)], opaque: Bool,
              draw: @escaping (CGContext, Int, Int) -> Void) throws {
    var images: [[String: String]] = []
    for s in sizes {
        let file = s.scale == "1x" ? "\(name).png" : "\(name)@\(s.scale).png"
        try write(png(s.w, s.h, opaque: opaque) { draw($0, s.w, s.h) }, "\(dir)/\(file)")
        images.append(["idiom": "tv", "filename": file, "scale": s.scale])
    }
    try write(json(["images": images, "info": info]), "\(dir)/Contents.json")
}

func imagestack(_ dir: String, sizes: [(scale: String, w: Int, h: Int)]) throws {
    try write(json(["layers": [["filename": "Front.imagestacklayer"], ["filename": "Back.imagestacklayer"]],
                    "info": info]), "\(dir)/Contents.json")
    for (layer, opaque) in [("Front", false), ("Back", true)] {
        let base = "\(dir)/\(layer).imagestacklayer"
        try write(json(["info": info]), "\(base)/Contents.json")
        try imageset("\(base)/Content.imageset", name: layer.lowercased(), sizes: sizes, opaque: opaque) { ctx, w, h in
            if !opaque { drawArtwork(ctx, w, h, scale: 0.92) }
        }
    }
}

try imagestack("App Icon - Large.imagestack", sizes: [("1x", 1280, 768), ("2x", 2560, 1536)])
try imagestack("App Icon - Small.imagestack", sizes: [("1x", 400, 240), ("2x", 800, 480)])
try imageset("Top Shelf Image.imageset", name: "topshelf", sizes: [("1x", 1920, 720), ("2x", 3840, 1440)], opaque: true) { ctx, w, h in
    drawArtwork(ctx, w, h, scale: 0.95)
}
try imageset("Top Shelf Image Wide.imageset", name: "topshelf-wide", sizes: [("1x", 2320, 720), ("2x", 4640, 1440)], opaque: true) { ctx, w, h in
    drawArtwork(ctx, w, h, scale: 0.95)
}

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
