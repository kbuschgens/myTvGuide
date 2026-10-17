import SwiftUI
import UIKit

struct GuideScreen: View {
    @State private var store = GuideStore()
    @State private var focus: FocusTarget?
    @State private var missingApp: AppInfo?
    @State private var probing: Channel?
    @State private var probeResult: String?
    @State private var found = PrivateLauncher.Report()
    @State private var anchor = TimeGrid.floorToSlot(.now)
    @State private var gridID = UUID()
    @State private var isReady = false
    @State private var backgroundedAt: Date?

    @Environment(\.scenePhase) private var scenePhase
    private let palette = Palette.load()
    private let links = AppLinks()
    /// Na zo lang op de achtergrond start de gids opnieuw bij het live-programma.
    private static let reanchorAfter: TimeInterval = 10 * 60

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                if let guide = store.guide {
                    // Het raster wordt direct opgebouwd (zodat scroll en focus kunnen landen) maar blijft
                    // afgedekt door een spinner tot de initiële focus en het detailvenster klaar zijn.
                    ZStack {
                        VStack(spacing: 0) {
                            TimelineView(.periodic(from: .now, by: 15)) { context in
                                EPGGrid(guide: guide, logoURL: store.logoURL(for:), palette: palette, anchor: anchor,
                                        now: context.date, viewportWidth: geo.size.width, focus: $focus, onSelect: open)
                            }
                            .id(gridID)
                            DetailPane(channel: selection?.channel, program: selection?.program)
                        }
                        if !isReady {
                            // Dekkende laag i.p.v. opacity 0: verborgen views kunnen geen focus krijgen.
                            Rectangle().fill(.background).ignoresSafeArea()
                            ProgressView().scaleEffect(1.6)
                        }
                    }
                    .onChange(of: selection != nil) { _, hasSelection in if hasSelection { isReady = true } }
                    .task(id: gridID) {
                        // Vangnet: toon de gids ook als er geen programma gefocust kan worden.
                        try? await Task.sleep(for: .seconds(2))
                        isReady = true
                    }
                } else if let message = store.errorMessage {
                    Text(message).font(.title3).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .task { await store.refresh() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                // Afdekken zodra de app weggaat: bij terugkeer zie je dan nooit een verouderd raster.
                backgroundedAt = .now
                isReady = false
            case .active:
                Task { await store.refresh() }
                guard let since = backgroundedAt else { return }
                backgroundedAt = nil
                if Date.now.timeIntervalSince(since) > Self.reanchorAfter {
                    // Lang weggeweest: raster opnieuw verankeren op nu; scroll en focus terug naar live.
                    anchor = TimeGrid.floorToSlot(.now)
                    focus = nil
                    gridID = UUID()
                } else {
                    isReady = true // Kort weggeweest: raster, scroll en focus blijven zoals ze waren.
                }
            default:
                break
            }
        }
        .confirmationDialog("Test VRT MAX-link", isPresented: Binding(get: { probing != nil }, set: { if !$0 { probing = nil } }),
                            titleVisibility: .visible) {
            Button("Zoek VRT op dit toestel") {
                found = PrivateLauncher.search("vrt")
                probeResult = found.lines.joined(separator: "\n")
            }
            ForEach(found.schemes, id: \.self) { scheme in
                if let url = URL(string: "\(scheme)://") {
                    Button("Gevonden: \(scheme)://") { probe(url) }
                }
            }
            ForEach(found.bundleIDs.isEmpty ? ["be.vrt.vrtnu", "be.vrt.vrtmax"] : found.bundleIDs, id: \.self) { id in
                Button("Open app \(id)") {
                    probeResult = "openApplicationWithBundleID \(id): \(PrivateLauncher.open(bundleID: id))"
                }
            }
            ForEach(probing.flatMap { links.probeURLs[$0.id] } ?? [], id: \.absoluteString) { url in
                Button(url.absoluteString) { probe(url) }
            }
            Button("Annuleer", role: .cancel) {}
        } message: {
            Text("Begin met \"Zoek VRT op dit toestel\", kies daarna een link of app en kijk of VRT MAX opent.")
        }
        .alert("Resultaat", isPresented: Binding(get: { probeResult != nil }, set: { if !$0 { probeResult = nil } })) {
            Button("OK") {}
        } message: {
            Text(probeResult ?? "")
        }
        .alert(item: $missingApp) { app in
            Alert(title: Text("\(app.name) niet gevonden"),
                  message: Text("Installeer \(app.name) om dit programma te bekijken."),
                  primaryButton: .default(Text("Open App Store")) {
                      if let url = app.storeURL { UIApplication.shared.open(url) }
                  },
                  secondaryButton: .cancel(Text("Annuleer")))
        }
    }

    private var selection: (channel: Channel, program: Program)? {
        guard let focus, let channel = store.guide?.channels.first(where: { $0.id == focus.channelID }),
              let program = channel.programs.first(where: { $0.start == focus.start }) else { return nil }
        return (channel, program)
    }

    private func probe(_ url: URL) {
        let canOpen = UIApplication.shared.canOpenURL(url)
        UIApplication.shared.open(url) { success in
            Task { @MainActor in
                probeResult = "\(url.absoluteString)\ncanOpenURL: \(canOpen)\nopen: \(success)"
            }
        }
    }

    private func open(_ channel: Channel, _ program: Program) {
        if links.probeURLs[channel.id] != nil {
            probing = channel
            return
        }
        if let url = links.overrideURL(for: channel) {
            UIApplication.shared.open(url) { success in
                if !success, let app = links.app(for: channel) { Task { @MainActor in missingApp = app } }
            }
            return
        }
        guard let app = links.app(for: channel), let url = app.launchURL else { return }
        UIApplication.shared.open(url, options: [:]) { success in
            if !success { Task { @MainActor in missingApp = app } }
        }
    }
}

extension AppInfo: Identifiable { var id: String { scheme } }
