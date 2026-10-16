import SwiftUI
import UIKit

struct FocusTarget: Hashable {
    let channelID: String
    let start: Date
}

struct EPGGrid: View {
    let guide: Guide
    let logoURL: (Channel) -> URL?
    let palette: [ColorPair]
    let anchor: Date
    let now: Date
    let viewportWidth: CGFloat
    @Binding var focus: FocusTarget?
    let onSelect: (Channel, Program) -> Void

    @FocusState private var focused: FocusTarget?
    @State private var rowsPosition = ScrollPosition(x: 0)
    @State private var headerPosition = ScrollPosition(x: 0)
    @State private var didPlaceInitially = false

    private let logoFiles = BundledLogo.logoFiles()
    private let channelColumnWidth: CGFloat = 280
    private let rowHeight: CGFloat = 84
    private let rowSpacing: CGFloat = 10
    private let headerHeight: CGFloat = 50

    private var grid: TimeGrid {
        TimeGrid(anchor: anchor, viewportWidth: viewportWidth - channelColumnWidth)
    }

    var body: some View {
        let grid = grid
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Color.clear.frame(width: channelColumnWidth, height: headerHeight)
                ScrollView(.horizontal, showsIndicators: false) {
                    TimeHeader(grid: grid).frame(height: headerHeight)
                }
                .scrollDisabled(true)
                .scrollPosition($headerPosition)
            }
            ScrollView(.vertical, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    VStack(spacing: rowSpacing) {
                        ForEach(guide.channels) { ChannelCell(channel: $0, logo: logoURL($0), logoFiles: logoFiles, height: rowHeight) }
                    }
                    .frame(width: channelColumnWidth)
                    ScrollView(.horizontal, showsIndicators: false) {
                        rows(grid: grid)
                    }
                    .scrollPosition($rowsPosition)
                    .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.x } action: { _, x in
                        headerPosition.scrollTo(x: x)
                    }
                }
                .padding(.vertical, 20)
            }
        }
        .onChange(of: focused) { _, new in if let new { focus = new } }
        .onAppear { placeInitially(grid: grid) }
    }

    private func rows(grid: TimeGrid) -> some View {
        VStack(spacing: rowSpacing) {
            ForEach(guide.channels) { channel in
                let colors = ColorAssigner.indices(for: channel.programs.map(\.title), paletteCount: palette.count)
                TimelineRowLayout(totalWidth: grid.totalWidth, height: rowHeight) {
                    ForEach(Array(channel.programs.enumerated()), id: \.element.id) { i, program in
                        if let f = grid.frame(start: program.start, end: program.end) {
                            let target = FocusTarget(channelID: channel.id, start: program.start)
                            Button { onSelect(channel, program) } label: {
                                ProgramBlock(program: program, pair: palette[colors[i]], now: now)
                            }
                            .buttonStyle(BlockButtonStyle())
                            .focused($focused, equals: target)
                            .timelineSlot(x: f.x, width: max(f.width - 4, 1))
                            // Gefocust blok boven zijn buren, anders tekent de volgende het van links naar rechts over de rand.
                            .zIndex(focused == target ? 1 : 0)
                        }
                    }
                }
                // Idem tussen rijen: de rij met focus boven de rij eronder (schaal + schaduw lopen eroverheen).
                .zIndex(focused?.channelID == channel.id ? 1 : 0)
            }
        }
        .focusSection()
    }

    private func placeInitially(grid: TimeGrid) {
        guard !didPlaceInitially else { return }
        didPlaceInitially = true
        let x = grid.initialOffset(now: now)
        rowsPosition.scrollTo(x: x)
        headerPosition.scrollTo(x: x)
        // Initiële focus: huidig programma van de eerste zender.
        if let first = guide.channels.first,
           let live = first.programs.first(where: { $0.isLive(at: now) }) ?? first.programs.first(where: { $0.end > now }) {
            focused = FocusTarget(channelID: first.id, start: live.start)
        }
    }
}

private struct TimeHeader: View {
    let grid: TimeGrid

    var body: some View {
        HStack(spacing: 0) {
            ForEach(grid.slots, id: \.self) { slot in
                Text(BrusselsTime.format(slot))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 6)
                    .frame(width: grid.slotWidth, alignment: .leading)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(.white.opacity(0.25)).frame(width: 1)
                    }
            }
        }
        .frame(width: grid.totalWidth, alignment: .leading)
    }
}

private struct ChannelCell: View {
    let channel: Channel
    let logo: URL?
    let logoFiles: [String: String]
    let height: CGFloat

    var body: some View {
        HStack(spacing: 14) {
            ChannelLogo(bundled: BundledLogo.image(for: channel, files: logoFiles), remote: logo)
                .frame(width: 64, height: 48)
            Text(channel.name)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: height)
    }
}

private struct ChannelLogo: View {
    let bundled: UIImage?
    let remote: URL?

    var body: some View {
        if let bundled {
            Image(uiImage: bundled).resizable().scaledToFit()
        } else {
            AsyncImage(url: remote) { $0.resizable().scaledToFit() } placeholder: { Color.clear }
        }
    }
}
