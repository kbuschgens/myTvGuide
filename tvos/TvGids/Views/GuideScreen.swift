import SwiftUI
import UIKit

struct GuideScreen: View {
    @State private var store = GuideStore()
    @State private var focus: FocusTarget?
    @State private var missingApp: AppInfo?
    @State private var anchor = TimeGrid.floorToSlot(.now)
    @State private var gridID = UUID()

    @Environment(\.scenePhase) private var scenePhase
    private let palette = Palette.load()
    private let links = AppLinks()

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                if let guide = store.guide {
                    TimelineView(.periodic(from: .now, by: 15)) { context in
                        EPGGrid(guide: guide, logoURL: store.logoURL(for:), palette: palette, anchor: anchor,
                                now: context.date, viewportWidth: geo.size.width, focus: $focus, onSelect: open)
                    }
                    .id(gridID)
                    DetailPane(channel: selection?.channel, program: selection?.program)
                } else if let message = store.errorMessage {
                    Text(message).font(.title3).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .task { await store.refresh() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            // Bij ontwaken: raster opnieuw verankeren op de huidige tijd (scroll en focus terug naar live).
            anchor = TimeGrid.floorToSlot(.now)
            gridID = UUID()
            Task { await store.refresh() }
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

    private func open(_ channel: Channel, _ program: Program) {
        guard let app = links.app(for: channel), let url = app.launchURL else { return }
        UIApplication.shared.open(url, options: [:]) { success in
            if !success { Task { @MainActor in missingApp = app } }
        }
    }
}

extension AppInfo: Identifiable { var id: String { scheme } }
