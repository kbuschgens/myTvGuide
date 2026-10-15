import Foundation
import Observation

@MainActor
@Observable
final class GuideStore {
    static let guideURL = URL(string: "https://sandermartensautomation.github.io/myTvGuide/guide.json")!

    private(set) var guide: Guide?
    private(set) var logoBase = GuideStore.guideURL.deletingLastPathComponent()
    private(set) var errorMessage: String?
    private(set) var isLoading = false

    private let cacheDirectory: URL
    private let session: URLSession
    private let url: URL

    init(url: URL = GuideStore.guideURL, session: URLSession = .shared,
         cacheDirectory: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]) {
        self.url = url
        self.session = session
        self.cacheDirectory = cacheDirectory
        logoBase = url.deletingLastPathComponent()
        guide = loadCached()
    }

    func logoURL(for channel: Channel) -> URL? {
        URL(string: channel.logo, relativeTo: logoBase)?.absoluteURL
    }

    /// Haalt de gids op bij start/wake; downloadt alleen als de server een nieuwere versie heeft.
    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        if guide != nil, let etag = UserDefaults.standard.string(forKey: Keys.etag) {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            if http.statusCode == 304 { errorMessage = nil; return }
            guard http.statusCode == 200 else { throw URLError(.badServerResponse) }
            let fresh = try Guide.decode(data)
            if fresh.generatedAt != guide?.generatedAt { guide = fresh }
            try? data.write(to: cacheFile, options: .atomic)
            UserDefaults.standard.set(http.value(forHTTPHeaderField: "ETag"), forKey: Keys.etag)
            errorMessage = nil
        } catch {
            // Offline of serverfout: oude cache blijft zichtbaar.
            errorMessage = guide == nil ? "Kan de gids niet laden. Probeer het later opnieuw." : nil
        }
    }

    private enum Keys { static let etag = "guide.etag" }
    private var cacheFile: URL { cacheDirectory.appendingPathComponent("guide.json") }

    private func loadCached() -> Guide? {
        guard let data = try? Data(contentsOf: cacheFile) else { return nil }
        return try? Guide.decode(data)
    }
}
