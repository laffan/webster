import Foundation

/// Parses a raw Webster definition string into a structured form so the UI can
/// lay out each sense on its own line.
///
/// Webster entries pack a lot into one string:
///  - Homograph blocks (different parts of speech) separated by a blank line.
///  - Primary senses numbered `1.`, `2.`, `3.` …
///  - Lettered sub-senses `(a)`, `(b)`, `(c)` …
///
/// The parser walks the sense/sub-sense numbers *in sequence* so it doesn't
/// mistake citation numbers (e.g. "Gen. ix. 13.") or part-of-speech labels
/// (e.g. "(Naut.)") for structure.
struct ParsedDefinition {
    struct SubSense: Identifiable {
        let id = UUID()
        let label: String   // e.g. "(a)"
        let text: String
    }

    struct Sense: Identifiable {
        let id = UUID()
        let label: String?  // e.g. "1." — nil for an un-numbered single sense
        let text: String
        let subsenses: [SubSense]
    }

    struct Block: Identifiable {
        let id = UUID()
        let senses: [Sense]

        /// Show sense numbers only when a block actually has more than one.
        var isMultiSense: Bool {
            senses.filter { $0.label != nil }.count > 1
        }
    }

    let blocks: [Block]

    // MARK: - Parsing

    static func parse(_ definition: String) -> ParsedDefinition {
        let primaryTokens = (1...39).map { ("\($0).", Array("\($0).")) }
        let letterTokens = "abcdefghijklmnopqrstuvwxyz".map { ("(\($0))", Array("(\($0))")) }

        var blocks: [Block] = []
        for rawBlock in definition.components(separatedBy: "\n\n") {
            let blockStr = rawBlock.trimmingCharacters(in: .whitespacesAndNewlines)
            if blockStr.isEmpty { continue }

            let chars = Array(blockStr)
            let marks = sequentialMarkers(chars, tokens: primaryTokens)
            var senses: [Sense] = []

            if marks.isEmpty {
                senses.append(Sense(label: nil, text: collapse(blockStr), subsenses: []))
            } else {
                // Any text before the first "1." (uncommon) becomes a preamble.
                let preamble = collapse(String(chars[0..<marks[0].start]))
                if !preamble.isEmpty {
                    senses.append(Sense(label: nil, text: preamble, subsenses: []))
                }
                for (index, mark) in marks.enumerated() {
                    let end = index + 1 < marks.count ? marks[index + 1].start : chars.count
                    let content = Array(chars[mark.end..<end])
                    let (intro, subsenses) = parseSubsenses(content, tokens: letterTokens)
                    senses.append(Sense(label: mark.label, text: intro, subsenses: subsenses))
                }
            }
            blocks.append(Block(senses: senses))
        }
        return ParsedDefinition(blocks: blocks)
    }

    private static func parseSubsenses(
        _ content: [Character],
        tokens: [(String, [Character])]
    ) -> (intro: String, subsenses: [SubSense]) {
        let marks = sequentialMarkers(content, tokens: tokens)
        guard !marks.isEmpty else {
            return (collapse(String(content)), [])
        }
        let intro = collapse(String(content[0..<marks[0].start]))
        var subsenses: [SubSense] = []
        for (index, mark) in marks.enumerated() {
            let end = index + 1 < marks.count ? marks[index + 1].start : content.count
            let text = collapse(String(content[mark.end..<end]))
            subsenses.append(SubSense(label: mark.label, text: text))
        }
        return (intro, subsenses)
    }

    /// Finds each token from `tokens` in order, requiring the previous one to be
    /// found first. Returns the marker ranges that were located in sequence.
    private static func sequentialMarkers(
        _ chars: [Character],
        tokens: [(String, [Character])]
    ) -> [(label: String, start: Int, end: Int)] {
        var result: [(label: String, start: Int, end: Int)] = []
        var from = 0
        for (label, token) in tokens {
            guard let index = findMarker(chars, token: token, from: from) else { break }
            result.append((label, index, index + token.count))
            from = index + token.count
        }
        return result
    }

    private static func findMarker(_ chars: [Character], token: [Character], from: Int) -> Int? {
        let count = chars.count
        let width = token.count
        guard width > 0, width <= count else { return nil }

        var i = max(0, from)
        while i <= count - width {
            if Array(chars[i..<i + width]) == token {
                let prev = i > 0 ? chars[i - 1] : nil
                let beforeOK = prev == nil || prev!.isWhitespace
                    || prev == "(" || prev == "[" || prev == "-"
                let afterIndex = i + width
                let afterOK = afterIndex < count && chars[afterIndex].isWhitespace
                let prevNotDigit = prev == nil || !prev!.isNumber
                if beforeOK && afterOK && prevNotDigit {
                    return i
                }
            }
            i += 1
        }
        return nil
    }

    /// Collapses runs of whitespace (including stray newlines) to single spaces.
    private static func collapse(_ string: String) -> String {
        string
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
