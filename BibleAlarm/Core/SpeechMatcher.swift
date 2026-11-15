import Foundation

/// Scores how much of a verse was read aloud (Premium strict mode).
enum SpeechMatcher {
    /// The share of the verse that must be heard to pass.
    static let passingScore = 0.8

    /// Returns 0...1: the share of the verse's words (characters for Chinese) found in what was heard.
    static func score(spoken: String, verse: String, isChinese: Bool) -> Double {
        let expected = units(verse, isChinese: isChinese)
        guard !expected.isEmpty else { return 0 }
        var heard: [String: Int] = [:]
        for unit in units(spoken, isChinese: isChinese) {
            heard[unit, default: 0] += 1
        }
        var matched = 0
        for unit in expected {
            if let remaining = heard[unit], remaining > 0 {
                heard[unit] = remaining - 1
                matched += 1
            }
        }
        return Double(matched) / Double(expected.count)
    }

    static func units(_ text: String, isChinese: Bool) -> [String] {
        if isChinese {
            return text.filter { $0.isLetter || $0.isNumber }.map { String($0) }
        }
        return VerseTokenizer.englishSegments(text)
            .filter { $0.isWord }
            .map { WordLists.normalize($0.text).replacingOccurrences(of: "'", with: "") }
    }
}
