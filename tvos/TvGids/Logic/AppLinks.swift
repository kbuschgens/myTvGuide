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
    private struct File: Decodable { let apps: [String: AppInfo] }
    let apps: [String: AppInfo]

    init(apps: [String: AppInfo]) { self.apps = apps }

    init(bundle: Bundle = .main) {
        guard let url = bundle.url(forResource: "channels", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data)
        else { self.init(apps: [:]); return }
        self.init(apps: file.apps)
    }

    func app(for channel: Channel) -> AppInfo? { apps[channel.app] }
}
