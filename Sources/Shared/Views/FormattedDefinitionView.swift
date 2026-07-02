import SwiftUI

/// Renders a parsed Webster definition with each sense on its own line: bold
/// sense numbers, indented lettered sub-senses, and a divider between homograph
/// blocks (different parts of speech).
struct FormattedDefinitionView: View {
    let definition: String

    private var parsed: ParsedDefinition { ParsedDefinition.parse(definition) }

    #if os(watchOS)
    private let bodyFont: Font = .system(.footnote, design: .serif)
    #else
    private let bodyFont: Font = .system(.body, design: .serif)
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(parsed.blocks.enumerated()), id: \.element.id) { index, block in
                if index > 0 {
                    Divider()
                }
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(block.senses) { sense in
                        senseView(sense, showNumber: block.isMultiSense)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func senseView(_ sense: ParsedDefinition.Sense, showNumber: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if showNumber, let label = sense.label {
                    Text(label)
                        .font(bodyFont.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 20, alignment: .leading)
                }
                if !sense.text.isEmpty {
                    Text(sense.text)
                        .font(bodyFont)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            ForEach(sense.subsenses) { sub in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(sub.label)
                        .font(bodyFont.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(sub.text)
                        .font(bodyFont)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, showNumber ? 24 : 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .selectableText()
    }
}
