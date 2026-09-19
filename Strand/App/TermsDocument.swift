import Foundation

/// The FULL terms text, read from the `TERMS.md` that ships inside the app.
///
/// WHY THIS EXISTS. `Terms` carries the first-run gate's plain-English summary — five points and
/// four attestations, compiled in and localized. The binding document is `TERMS.md`, and the gate
/// has always told the user so: "The full terms are in TERMS.md, shipped with Noop Aura." That
/// sentence was not true. The file sat in the repository and was never added to either app's
/// resources, so nothing could show it and nothing could check it. A person who wanted to read what
/// they had just accepted had nowhere in the app to do it.
///
/// So the file now ships, and this reads it. The parse is deliberately shallow: headings become
/// sections and everything else is handed back as markdown, because the agreement's wording is the
/// agreement and re-typing it into Swift would create a second copy to drift. A screen styles the
/// headings itself and renders each body.
///
/// FAIL OPEN, NEVER CRASH. An absent or unreadable resource yields nil, and the caller falls back
/// to `Terms.points`. A missing legal document must not take the app down — but it must also not
/// pass silently, which is what `TermsDocumentTests` is for.
enum TermsDocument {

    struct Section: Identifiable, Equatable {
        /// The number as the document writes it: 1 through 9. Nil for an unnumbered heading.
        let number: Int?
        /// The heading with its number stripped — "Not a medical device".
        let heading: String
        /// The section's own markdown, headings removed. May contain bullets, bold and blockquotes.
        let body: String

        var id: String { "\(number.map(String.init) ?? "x")-\(heading)" }
    }

    struct Document: Equatable {
        let title: String
        /// The version the DOCUMENT declares. Compared against `Terms.currentVersion`, which is what
        /// the gate actually stores and enforces; the two drifting is the bug this makes visible.
        let version: String?
        /// Everything above the first numbered section, including the not-legal-advice note.
        let preamble: String
        let sections: [Section]
        /// The closing note beneath the final rule.
        let closing: String
    }

    /// The document as shipped, or nil when the resource is missing.
    static let bundled: Document? = load()

    static func load(from bundle: Bundle = .main) -> Document? {
        guard let url = bundle.url(forResource: "TERMS", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return nil }
        return parse(text)
    }

    /// Split on `##` headings. Kept pure so it can be tested without a bundle.
    static func parse(_ markdown: String) -> Document {
        let lines = markdown.components(separatedBy: .newlines)

        var title = ""
        var version: String?
        var preambleLines: [String] = []
        var sections: [Section] = []
        var currentHeading: String?
        var currentNumber: Int?
        var currentBody: [String] = []

        func closeSection() {
            guard let heading = currentHeading else { return }
            sections.append(Section(number: currentNumber,
                                    heading: heading,
                                    body: trimmed(currentBody.joined(separator: "\n"))))
            currentHeading = nil
            currentNumber = nil
            currentBody = []
        }

        for line in lines {
            if line.hasPrefix("# ") && title.isEmpty && currentHeading == nil {
                title = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                continue
            }
            if line.hasPrefix("## ") {
                closeSection()
                let raw = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                (currentNumber, currentHeading) = splitLeadingNumber(raw)
                continue
            }
            if currentHeading == nil {
                if version == nil, let found = declaredVersion(in: line) { version = found; continue }
                preambleLines.append(line)
            } else {
                currentBody.append(line)
            }
        }
        closeSection()

        // The document ends with a rule and a closing note. It belongs to the document, not to its
        // last section, so lift it off rather than leaving it attached to severance.
        var closing = ""
        if let last = sections.last, let split = splitOffClosing(last.body) {
            sections[sections.count - 1] = Section(number: last.number, heading: last.heading, body: split.body)
            closing = split.closing
        }

        return Document(title: title,
                        version: version,
                        preamble: stripTrailingRule(trimmed(preambleLines.joined(separator: "\n"))),
                        sections: sections,
                        closing: closing)
    }

    // MARK: - Parsing helpers

    /// "**Version 2.0**" -> "2.0". Tolerates the emphasis being absent.
    private static func declaredVersion(in line: String) -> String? {
        let cleaned = line.replacingOccurrences(of: "*", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard cleaned.lowercased().hasPrefix("version ") else { return nil }
        let value = cleaned.dropFirst("version ".count).trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    /// "5. Not a medical device" -> (5, "Not a medical device").
    private static func splitLeadingNumber(_ heading: String) -> (Int?, String) {
        guard let dot = heading.firstIndex(of: "."),
              let number = Int(heading[heading.startIndex..<dot]) else { return (nil, heading) }
        let rest = heading[heading.index(after: dot)...].trimmingCharacters(in: .whitespaces)
        return (number, rest.isEmpty ? heading : rest)
    }

    private static func splitOffClosing(_ body: String) -> (body: String, closing: String)? {
        let lines = body.components(separatedBy: .newlines)
        guard let ruleIndex = lines.lastIndex(where: { isRule($0) }) else { return nil }
        let after = trimmed(lines[(ruleIndex + 1)...].joined(separator: "\n"))
        guard !after.isEmpty else { return nil }
        return (trimmed(lines[..<ruleIndex].joined(separator: "\n")), after)
    }

    private static func stripTrailingRule(_ text: String) -> String {
        var lines = text.components(separatedBy: .newlines)
        while let last = lines.last, isRule(last) || last.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.removeLast()
        }
        return trimmed(lines.joined(separator: "\n"))
    }

    private static func isRule(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        return t == "---" || t == "***" || t == "___"
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
