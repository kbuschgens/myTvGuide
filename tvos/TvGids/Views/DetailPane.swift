import SwiftUI

struct DetailPane: View {
    let channel: Channel?
    let program: Program?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let channel, let program {
                Text("\(channel.name) | \(BrusselsTime.range(program.start, program.end))")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(program.title)
                    .font(.title2.weight(.bold))
                    .lineLimit(1)
                Text(program.description ?? "")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 190, maxHeight: 190, alignment: .topLeading)
        .padding(.top, 20)
        .overlay(alignment: .top) {
            // Dunne, lichtere scheidingslijn over de volle breedte: maakt het detailvenster een aparte sectie.
            Rectangle()
                .fill(.white.opacity(0.3))
                .frame(height: 1)
                .ignoresSafeArea(edges: .horizontal)
        }
    }
}
