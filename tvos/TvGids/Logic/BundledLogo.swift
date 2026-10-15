import UIKit

/// Logo's uit de app-bundle (docs/logos), zodat ze ook zonder netwerk of hosting zichtbaar zijn.
/// Het bestand komt uit de gebundelde channels.json (`logoFile`), zodat een oude gecachte guide.json
/// geen verouderd logo kan tonen; het logo uit de gids is de terugval.
enum BundledLogo {
    private struct File: Decodable {
        struct Entry: Decodable { let id: String; let logoFile: String }
        let channels: [Entry]
    }

    static func logoFiles(bundle: Bundle = .main) -> [String: String] {
        guard let url = bundle.url(forResource: "channels", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data)
        else { return [:] }
        return Dictionary(file.channels.map { ($0.id, $0.logoFile) }, uniquingKeysWith: { first, _ in first })
    }

    static func image(for channel: Channel, files: [String: String], bundle: Bundle = .main) -> UIImage? {
        let name = files[channel.id] ?? (channel.logo as NSString).lastPathComponent
        guard let url = bundle.url(forResource: name, withExtension: nil, subdirectory: "logos") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}
