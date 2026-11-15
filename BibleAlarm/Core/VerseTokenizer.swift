import Foundation
import NaturalLanguage

/// A piece of a verse: either a word, or the punctuation and spaces between words.
struct TextSegment: Equatable, Sendable {
    let text: String
    let isWord: Bool
}

/// Splits a verse into words and the punctuation between them.
/// Joining every segment's text gives back the original verse exactly.
enum VerseTokenizer {
    static func segments(_ text: String, isChinese: Bool) -> [TextSegment] {
        isChinese ? chineseSegments(text) : englishSegments(text)
    }

    /// Words only, in reading order.
    static func words(_ text: String, isChinese: Bool) -> [String] {
        segments(text, isChinese: isChinese).filter { $0.isWord }.map { $0.text }
    }

    static func englishSegments(_ text: String) -> [TextSegment] {
        let characters = Array(text)
        var result: [TextSegment] = []
        var current = ""
        var currentIsWord = false

        for (index, character) in characters.enumerated() {
            var isWordCharacter = character.isLetter || character.isNumber
            // Keep apostrophes that sit inside a word, as in "don't" or "Lord's".
            if !isWordCharacter, character == "'" || character == "\u{2019}",
               index > 0, index + 1 < characters.count,
               characters[index - 1].isLetter, characters[index + 1].isLetter {
                isWordCharacter = true
            }
            if current.isEmpty {
                current = String(character)
                currentIsWord = isWordCharacter
            } else if isWordCharacter == currentIsWord {
                current.append(character)
            } else {
                result.append(TextSegment(text: current, isWord: currentIsWord))
                current = String(character)
                currentIsWord = isWordCharacter
            }
        }
        if !current.isEmpty {
            result.append(TextSegment(text: current, isWord: currentIsWord))
        }
        return result
    }

    /// Uses the system word splitter so a blank is always a whole Chinese word (平安), never half of one.
    static func chineseSegments(_ text: String) -> [TextSegment] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        tokenizer.setLanguage(.traditionalChinese)

        var result: [TextSegment] = []
        var cursor = text.startIndex
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            if cursor < range.lowerBound {
                result.append(TextSegment(text: String(text[cursor..<range.lowerBound]), isWord: false))
            }
            let token = String(text[range])
            let isWord = token.contains { $0.isLetter || $0.isNumber }
            result.append(TextSegment(text: token, isWord: isWord))
            cursor = range.upperBound
            return true
        }
        if cursor < text.endIndex {
            result.append(TextSegment(text: String(text[cursor..<text.endIndex]), isWord: false))
        }
        return result
    }
}
