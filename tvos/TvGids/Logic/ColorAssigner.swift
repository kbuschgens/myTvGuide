import Foundation

struct ColorPair: Sendable, Equatable {
    let name: String
    let past: String
    let future: String
}

/// Deterministische kleurtoewijzing; zelfde regels als shared/palette.json.
enum ColorAssigner {
    static func fnv1a32(_ text: String) -> UInt32 {
        var hash: UInt32 = 2_166_136_261
        for byte in text.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 16_777_619
        }
        return hash
    }

    /// Palet-indices voor een reeks opeenvolgende programmatitels (één zender).
    /// Een programma krijgt nooit dezelfde index als zijn voorganger.
    static func indices(for titles: [String], paletteCount: Int = 5) -> [Int] {
        var result: [Int] = []
        result.reserveCapacity(titles.count)
        var previous: Int?
        for title in titles {
            var index = Int(fnv1a32(title) % UInt32(paletteCount))
            if index == previous { index = (index + 1) % paletteCount }
            result.append(index)
            previous = index
        }
        return result
    }
}

enum Palette {
    private struct File: Decodable {
        struct Entry: Decodable { let name: String; let past: String; let future: String }
        let palette: [Entry]
    }

    static func load(from bundle: Bundle = .main) -> [ColorPair] {
        guard let url = bundle.url(forResource: "palette", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data)
        else { return fallback }
        return file.palette.map { ColorPair(name: $0.name, past: $0.past, future: $0.future) }
    }

    static let fallback: [ColorPair] = [
        .init(name: "Soft Blue", past: "#B9D9F3", future: "#D0E2EF"),
        .init(name: "Soft Lavender", past: "#B3B1E8", future: "#CFCEEC"),
        .init(name: "Soft Peach", past: "#F3D3C6", future: "#F0DED7"),
        .init(name: "Soft Coral", past: "#FAB9AC", future: "#F7D3CC"),
        .init(name: "Soft Sage", past: "#B4D7C8", future: "#CDE1D9"),
    ]
}
