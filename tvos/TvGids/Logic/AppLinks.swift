import Foundation

struct AppInfo: Decodable, Sendable, Equatable {
    let name: String
    let scheme: String
    let appStoreId: Int

    var launchURL: URL? { URL(string: scheme) }
    var storeURL: URL? { URL(string: "https://apps.apple.com/be/app/id\(appStoreId)") }
}

/// Zender → doel-app, uit pipeline/channels.json (gebundeld).
struct AppLinks: Sendable {
    private struct File: Decodable {
        struct Entry: Decodable { let id: String; let openUrl: String?; let probeUrls: [String]? }
        let apps: [String: AppInfo]
        let channels: [Entry]
    }
    let apps: [String: AppInfo]
    /// Zenders met een eigen link (`openUrl`) die voorrang heeft op het app-scheme.
    let channelURLs: [String: URL]
    /// Kandidaat-links voor zenders waarvan de werkende deep link nog niet bevestigd is (testmodus).
    let probeURLs: [String: [URL]]

    init(apps: [String: AppInfo], channelURLs: [String: URL] = [:], probeURLs: [String: [URL]] = [:]) {
        self.apps = apps
        self.channelURLs = channelURLs
        self.probeURLs = probeURLs
    }

    init(bundle: Bundle = .main) {
        guard let url = bundle.url(forResource: "channels", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data)
        else { self.init(apps: [:]); return }
        let urls = file.channels.compactMap { entry in
            entry.openUrl.flatMap(URL.init(string:)).map { (entry.id, $0) }
        }
        let probes = file.channels.compactMap { entry in
            entry.probeUrls.map { (entry.id, $0.compactMap(URL.init(string:))) }
        }
        self.init(apps: file.apps, channelURLs: Dictionary(urls, uniquingKeysWith: { first, _ in first }),
                  probeURLs: Dictionary(probes, uniquingKeysWith: { first, _ in first }))
    }

    func app(for channel: Channel) -> AppInfo? { apps[channel.app] }
    func overrideURL(for channel: Channel) -> URL? { channelURLs[channel.id] }
}
