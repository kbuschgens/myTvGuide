import SwiftUI

private struct SlotKey: LayoutValueKey {
    static let defaultValue = (x: CGFloat(0), width: CGFloat(0))
}

extension View {
    func timelineSlot(x: CGFloat, width: CGFloat) -> some View {
        layoutValue(key: SlotKey.self, value: (x, width))
    }
}

/// Plaatst subviews op absolute x-positie/breedte binnen één rij.
struct TimelineRowLayout: Layout {
    let totalWidth: CGFloat
    let height: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: totalWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            let slot = subview[SlotKey.self]
            subview.place(at: CGPoint(x: bounds.minX + slot.x, y: bounds.minY),
                          anchor: .topLeading,
                          proposal: ProposedViewSize(width: slot.width, height: height))
        }
    }
}
