import SwiftUI

enum HebrewNumerals {
    /// Hebrew letter-numbers with geresh / gershayim. 15 and 16 avoid the divine name.
    static func string(_ number: Int) -> String {
        guard number > 0, number < 1000 else { return String(number) }
        if number == 15 { return "ט״ו" }
        if number == 16 { return "ט״ז" }
        let ones = ["", "א", "ב", "ג", "ד", "ה", "ו", "ז", "ח", "ט"]
        let tens = ["", "י", "כ", "ל", "מ", "נ", "ס", "ע", "פ", "צ"]
        let hundreds = ["", "ק", "ר", "ש", "ת", "תק", "תר", "תש", "תת", "תתק"]
        var letters = hundreds[number / 100]
        let rest = number % 100
        if rest == 15 {
            letters += "טו"
        } else if rest == 16 {
            letters += "טז"
        } else {
            letters += tens[rest / 10]
            letters += ones[rest % 10]
        }
        if letters.count <= 1 {
            return letters + "׳"
        }
        var characters = Array(letters)
        characters.insert("״", at: characters.count - 1)
        return String(characters)
    }
}

enum HebrewText {
    static func containsHebrew(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x0590...0x05FF).contains($0.value) }
    }

    static func number(_ value: Int, language: AppLanguage) -> String {
        language == .he ? HebrewNumerals.string(value) : String(value)
    }

    static func citation(chapter: Int, verse: Int, language: AppLanguage) -> String {
        String(
            format: L10n.text("reading.place", language),
            number(chapter, language: language),
            number(verse, language: language)
        )
    }

    /// FTS5 query of Hebrew letters only. Nikud and cantillation are dropped, and each word is a prefix.
    static func ftsQuery(_ raw: String) -> String {
        let stripped = stripNikud(raw)
        var words: [String] = []
        var current = ""
        for scalar in stripped.unicodeScalars {
            if (0x05D0...0x05EA).contains(scalar.value) {
                current.unicodeScalars.append(scalar)
            } else if !current.isEmpty {
                words.append(current)
                current = ""
            }
        }
        if !current.isEmpty {
            words.append(current)
        }
        return words.map { "\"\($0)\"*" }.joined(separator: " ")
    }

    static func stripNikud(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            let value = scalar.value
            if (0x0591...0x05BD).contains(value) { continue }
            switch value {
            case 0x05BF, 0x05C1, 0x05C2, 0x05C4, 0x05C5, 0x05C7:
                continue
            default:
                scalars.append(scalar)
            }
        }
        return String(scalars)
    }

    static func plain(_ markup: String, stripNikud removePoints: Bool) -> String {
        let withoutTags = segments(in: markup).map(\.text).joined()
        let cleaned = removePoints ? stripNikud(withoutTags) : withoutTags
        return cleaned.replacingOccurrences(of: "[ \t]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func preview(_ comment: Comment, stripNikud removePoints: Bool) -> String {
        let source = comment.dibbur.isEmpty ? comment.body : comment.dibbur
        let text = plain(source, stripNikud: removePoints)
        if text.count <= 90 { return text }
        let end = text.index(text.startIndex, offsetBy: 90)
        return String(text[..<end]) + "…"
    }

    static func attributed(
        _ markup: String,
        showNikud: Bool,
        size: CGFloat,
        textColor: Color,
        emphasisColor: Color
    ) -> AttributedString {
        var result = AttributedString()
        for segment in segments(in: markup) {
            let visible = showNikud ? segment.text : stripNikud(segment.text)
            guard !visible.isEmpty else { continue }
            var part = AttributedString(visible)
            part.font = Theme.hebrewFont(size: size, emphasis: segment.emphasis)
            part.foregroundColor = segment.emphasis ? emphasisColor : textColor
            result += part
        }
        return result
    }

    private struct Segment {
        var text: String
        var emphasis: Bool
    }

    /// The vocalized edition marks the dibbur hamatchil, and other phrases, with `<b>`.
    private static func segments(in markup: String) -> [Segment] {
        var output: [Segment] = []
        var buffer = ""
        var emphasis = false
        var index = markup.startIndex
        while index < markup.endIndex {
            if markup[index] == "<" {
                let rest = markup[index...]
                if rest.hasPrefix("<b>") {
                    flush(&buffer, emphasis: emphasis, into: &output)
                    emphasis = true
                    index = markup.index(index, offsetBy: 3)
                    continue
                }
                if rest.hasPrefix("</b>") {
                    flush(&buffer, emphasis: emphasis, into: &output)
                    emphasis = false
                    index = markup.index(index, offsetBy: 4)
                    continue
                }
            }
            buffer.append(markup[index])
            index = markup.index(after: index)
        }
        flush(&buffer, emphasis: emphasis, into: &output)
        return output
    }

    private static func flush(_ buffer: inout String, emphasis: Bool, into output: inout [Segment]) {
        if !buffer.isEmpty {
            output.append(Segment(text: buffer, emphasis: emphasis))
            buffer = ""
        }
    }
}

extension View {
    /// Marks Hebrew content so VoiceOver reads it with a Hebrew voice, also when the
    /// interface is in English. SwiftUI takes a text's speech language from the locale
    /// in its environment and has no per-view accessibility language, so apply this to
    /// the Hebrew text alone, not to a row that also holds interface labels.
    func hebrewSpeech() -> some View {
        environment(\.locale, Locale(identifier: "he"))
    }
}
