import Foundation

/// A verse with one or more words hidden, plus the choices offered for each hidden word.
struct BlankChallenge: Equatable, Sendable {
    struct Blank: Equatable, Sendable, Identifiable {
        /// Position of this blank in reading order, starting at 0.
        let id: Int
        /// Index into `segments` of the hidden word.
        let segmentIndex: Int
        let answer: String
        /// The answer plus the wrong choices, already shuffled.
        let choices: [String]
    }

    let segments: [TextSegment]
    let blanks: [Blank]

    func blank(atSegment index: Int) -> Blank? {
        blanks.first { $0.segmentIndex == index }
    }
}

/// Picks the words to hide in a verse and builds the multiple-choice answers (brief section 5).
struct BlankGenerator: Sendable {
    var isChinese: Bool
    /// Total buttons shown for each blank, including the right answer.
    var choiceCount: Int = 4

    /// - Parameters:
    ///   - text: the verse.
    ///   - blankCount: how many words to hide (Easy 1, Normal 2, Memorize more).
    ///   - distractorTexts: other verses in the same version; wrong choices are taken from their words.
    func makeChallenge<G: RandomNumberGenerator>(
        text: String, blankCount: Int, distractorTexts: [String], using generator: inout G
    ) -> BlankChallenge {
        let segments = VerseTokenizer.segments(text, isChinese: isChinese)
        let chosen = chooseBlankSegments(in: segments, count: max(1, blankCount))

        let verseWords = Set(segments.filter { $0.isWord }.map { WordLists.normalize($0.text) })
        var pool: [String] = []
        var seen = Set<String>()
        for other in distractorTexts {
            for word in VerseTokenizer.words(other, isChinese: isChinese) where isContentWord(word) {
                let key = WordLists.normalize(word)
                if !verseWords.contains(key), seen.insert(key).inserted {
                    pool.append(word)
                }
            }
        }
        pool.shuffle(using: &generator)

        var blanks: [BlankChallenge.Blank] = []
        for (order, segmentIndex) in chosen.sorted().enumerated() {
            let answer = segments[segmentIndex].text
            let wrong = distractors(for: answer, from: pool, count: max(1, choiceCount - 1))
            var choices = wrong + [answer]
            choices.shuffle(using: &generator)
            blanks.append(BlankChallenge.Blank(id: order, segmentIndex: segmentIndex, answer: answer, choices: choices))
        }
        return BlankChallenge(segments: segments, blanks: blanks)
    }

    /// True when the typed or tapped text is the hidden word (ignoring capital letters and spaces).
    static func matches(_ attempt: String, answer: String) -> Bool {
        let cleaned = attempt.trimmingCharacters(in: .whitespacesAndNewlines)
        return !cleaned.isEmpty && WordLists.normalize(cleaned) == WordLists.normalize(answer)
    }

    // MARK: - Choosing words

    func isContentWord(_ word: String) -> Bool {
        if WordLists.isStopword(word, isChinese: isChinese) { return false }
        if !word.contains(where: { $0.isLetter }) { return false }
        return isChinese ? true : word.count >= 3
    }

    /// Keywords first (most important first), then the longest remaining content words.
    func chooseBlankSegments(in segments: [TextSegment], count: Int) -> [Int] {
        var candidates = segments.indices.filter { segments[$0].isWord && isContentWord(segments[$0].text) }
        if candidates.isEmpty {
            candidates = segments.indices.filter { segments[$0].isWord }
        }
        let ranked = candidates.sorted { left, right in
            let leftRank = WordLists.keywordRank(segments[left].text, isChinese: isChinese)
            let rightRank = WordLists.keywordRank(segments[right].text, isChinese: isChinese)
            switch (leftRank, rightRank) {
            case let (l?, r?) where l != r: return l < r
            case (_?, nil): return true
            case (nil, _?): return false
            default:
                let leftLength = segments[left].text.count
                let rightLength = segments[right].text.count
                return leftLength != rightLength ? leftLength > rightLength : left < right
            }
        }
        var chosen: [Int] = []
        var usedWords = Set<String>()
        for index in ranked where chosen.count < count {
            if usedWords.insert(WordLists.normalize(segments[index].text)).inserted {
                chosen.append(index)
            }
        }
        return chosen
    }

    // MARK: - Wrong choices

    /// Words of similar length to the answer, written with the same capital-letter style.
    func distractors(for answer: String, from pool: [String], count: Int) -> [String] {
        let answerKey = WordLists.normalize(answer)
        let ordered = pool.enumerated().sorted { left, right in
            let leftGap = abs(left.element.count - answer.count)
            let rightGap = abs(right.element.count - answer.count)
            return leftGap != rightGap ? leftGap < rightGap : left.offset < right.offset
        }
        var result: [String] = []
        var used: Set<String> = [answerKey]
        for (_, word) in ordered where result.count < count {
            let styled = matchCase(of: answer, word)
            if used.insert(WordLists.normalize(styled)).inserted {
                result.append(styled)
            }
        }
        return result
    }

    private func matchCase(of answer: String, _ word: String) -> String {
        guard !isChinese, let first = answer.first else { return word }
        if answer.count > 1, answer == answer.uppercased() { return word.uppercased() }
        if first.isUppercase { return word.prefix(1).uppercased() + word.dropFirst().lowercased() }
        return word.lowercased()
    }
}
