import SwiftUI

struct ProgramBlock: View {
    let program: Program
    let pair: ColorPair
    let now: Date

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(program.title)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
            Text(BrusselsTime.range(program.start, program.end))
                .font(.caption2)
                .lineLimit(1)
                .opacity(0.85)
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(isFocused ? 0.6 : 0), radius: 14, y: 6)
        .overlay { if isFocused { focusRing } }
        .scaleEffect(isFocused ? 1.04 : 1)
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }

    /// Dubbele rand (wit + donker erbinnen): zichtbaar op zowel de lichte blokken als de donkere achtergrond.
    private var focusRing: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).strokeBorder(.white, lineWidth: 7)
            RoundedRectangle(cornerRadius: 4).strokeBorder(Color(hex: "#1B1B1F"), lineWidth: 3).padding(7)
        }
    }

    /// Verleden = basiskleur, toekomst = lichtere kleur; een lopend programma wordt op de Nu-lijn gesplitst.
    private var background: LinearGradient {
        let past = Color(hex: pair.past), future = Color(hex: pair.future)
        if let f = TimeGrid.splitFraction(start: program.start, end: program.end, now: now) {
            return LinearGradient(stops: [.init(color: past, location: 0), .init(color: past, location: f),
                                          .init(color: future, location: f), .init(color: future, location: 1)],
                                  startPoint: .leading, endPoint: .trailing)
        }
        let color = program.end <= now ? past : future
        return LinearGradient(colors: [color, color], startPoint: .leading, endPoint: .trailing)
    }
}

struct BlockButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label }
}
