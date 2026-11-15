import XCTest

struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

final class TokenizerTests: XCTestCase {
    func testEnglishSegmentsRebuildTheVerse() {
        let text = "For God so loved the world, that he gave his only begotten Son."
        let segments = VerseTokenizer.englishSegments(text)
        XCTAssertEqual(segments.map { $0.text }.joined(), text)
        XCTAssertEqual(segments.first, TextSegment(text: "For", isWord: true))
        XCTAssertTrue(segments.contains(TextSegment(text: ", ", isWord: false)))
    }

    func testEnglishKeepsApostrophesInsideWords() {
        let words = VerseTokenizer.words("Don\u{2019}t lean on the Lord's word.", isChinese: false)
        XCTAssertEqual(words, ["Don\u{2019}t", "lean", "on", "the", "Lord's", "word"])
    }

    func testChineseSegmentsRebuildTheVerse() {
        let text = "神愛世人，甚至將他的獨生子賜給他們，叫一切信他的，不至滅亡，反得永生。"
        let segments = VerseTokenizer.chineseSegments(text)
        XCTAssertEqual(segments.map { $0.text }.joined(), text)
        XCTAssertFalse(segments.contains { $0.isWord && $0.text.contains("，") })
        XCTAssertTrue(segments.contains { $0.isWord })
    }
}

final class BlankGeneratorTests: XCTestCase {
    let others = [
        "The LORD is my shepherd; I shall not want.",
        "Trust in the LORD with all thine heart; and lean not unto thine own understanding.",
        "I can do all things through Christ which strengtheneth me.",
        "Thy word is a lamp unto my feet, and a light unto my path.",
        "Rejoice in the Lord alway: and again I say, Rejoice.",
    ]

    func testKeywordIsHiddenFirst() {
        var generator = SeededGenerator(state: 1)
        let challenge = BlankGenerator(isChinese: false).makeChallenge(
            text: "For God so loved the world, that he gave his only begotten Son.",
            blankCount: 1, distractorTexts: others, using: &generator)
        XCTAssertEqual(challenge.blanks.count, 1)
        XCTAssertEqual(challenge.blanks[0].answer, "God")
    }

    func testLongestWordIsHiddenWhenThereIsNoKeyword() {
        var generator = SeededGenerator(state: 2)
        let challenge = BlankGenerator(isChinese: false).makeChallenge(
            text: "A soft answer turneth away wrath.", blankCount: 1, distractorTexts: others, using: &generator)
        XCTAssertEqual(challenge.blanks[0].answer, "turneth")
    }

    func testChoicesContainTheAnswerOnceAndNoWordsFromTheVerse() {
        var generator = SeededGenerator(state: 3)
        let text = "Be still, and know that I am God."
        let challenge = BlankGenerator(isChinese: false).makeChallenge(
            text: text, blankCount: 2, distractorTexts: others, using: &generator)
        XCTAssertEqual(challenge.blanks.count, 2)
        XCTAssertLessThan(challenge.blanks[0].segmentIndex, challenge.blanks[1].segmentIndex)
        let verseWords = Set(VerseTokenizer.words(text, isChinese: false).map { WordLists.normalize($0) })
        for blank in challenge.blanks {
            XCTAssertEqual(blank.choices.count, 4)
            XCTAssertEqual(blank.choices.filter { $0 == blank.answer }.count, 1)
            XCTAssertEqual(Set(blank.choices.map { WordLists.normalize($0) }).count, blank.choices.count)
            for choice in blank.choices where choice != blank.answer {
                XCTAssertFalse(verseWords.contains(WordLists.normalize(choice)))
            }
        }
    }

    func testStopwordsAreNeverHidden() {
        var generator = SeededGenerator(state: 4)
        let challenge = BlankGenerator(isChinese: false).makeChallenge(
            text: "And he said unto them, Follow me.", blankCount: 2, distractorTexts: others, using: &generator)
        for blank in challenge.blanks {
            XCTAssertFalse(WordLists.isStopword(blank.answer, isChinese: false))
        }
    }

    func testChineseBlankIsAWholeKeyword() {
        var generator = SeededGenerator(state: 5)
        let challenge = BlankGenerator(isChinese: true).makeChallenge(
            text: "我留下平安給你們；我將我的平安賜給你們。",
            blankCount: 1,
            distractorTexts: ["耶和華是我的牧者，我必不至缺乏。", "你要專心仰賴耶和華，不可倚靠自己的聰明，", "應當一無掛慮，只要凡事藉着禱告、祈求，和感謝，將你們所要的告訴神。"],
            using: &generator)
        XCTAssertEqual(challenge.blanks.count, 1)
        XCTAssertEqual(challenge.blanks[0].answer, "平安")
        XCTAssertGreaterThanOrEqual(challenge.blanks[0].choices.count, 2)
    }

    func testAnswerMatchingIgnoresCaseAndSpaces() {
        XCTAssertTrue(BlankGenerator.matches(" lord ", answer: "LORD"))
        XCTAssertFalse(BlankGenerator.matches("", answer: "LORD"))
        XCTAssertFalse(BlankGenerator.matches("love", answer: "LORD"))
    }

    func testCapitalStyleOfWrongChoicesMatchesTheAnswer() {
        let generator = BlankGenerator(isChinese: false)
        XCTAssertEqual(generator.distractors(for: "LORD", from: ["hope", "peace"], count: 2), ["HOPE", "PEACE"])
        XCTAssertEqual(generator.distractors(for: "God", from: ["hope"], count: 1), ["Hope"])
        XCTAssertEqual(generator.distractors(for: "peace", from: ["Grace"], count: 1), ["grace"])
    }
}

final class VersePickerTests: XCTestCase {
    func testRecentVersesAreAvoided() {
        let pool = ["JHN 3:16", "PSA 23:1", "PRO 3:5"].compactMap { VerseRef($0) }
        var generator = SeededGenerator(state: 9)
        for _ in 0..<20 {
            let pick = VersePicker.pick(pool: pool, recent: [pool[0], pool[1]], using: &generator)
            XCTAssertEqual(pick, pool[2])
        }
    }

    func testFallsBackToWholePoolWhenEverythingIsRecent() {
        let pool = ["JHN 3:16", "PSA 23:1"].compactMap { VerseRef($0) }
        var generator = SeededGenerator(state: 9)
        XCTAssertNotNil(VersePicker.pick(pool: pool, recent: Set(pool), using: &generator))
        XCTAssertNil(VersePicker.pick(pool: [], recent: [], using: &generator))
    }

    func testVerseRefParsing() {
        XCTAssertEqual(VerseRef("1CO 13:4"), VerseRef(bookID: "1CO", chapter: 13, verse: 4))
        XCTAssertNil(VerseRef("John 3"))
        XCTAssertEqual(BookNames.reference(VerseRef(bookID: "JHN", chapter: 3, verse: 16), chinese: false), "John 3:16")
        XCTAssertEqual(BookNames.reference(VerseRef(bookID: "JHN", chapter: 3, verse: 16), chinese: true), "約翰福音 3:16")
        XCTAssertEqual(BookNames.order.count, 66)
    }
}

final class StreakTests: XCTestCase {
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    func date(_ day: Int, hour: Int = 7) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    func testEmpty() {
        XCTAssertEqual(StreakCalculator.summarize(dates: [], now: date(10), calendar: calendar),
                       StreakSummary(current: 0, best: 0, completedToday: false))
    }

    func testConsecutiveDaysIncludingToday() {
        let summary = StreakCalculator.summarize(dates: [date(8), date(9), date(10), date(10, hour: 9)], now: date(10, hour: 12), calendar: calendar)
        XCTAssertEqual(summary, StreakSummary(current: 3, best: 3, completedToday: true))
    }

    func testStreakSurvivesUntilEndOfToday() {
        let summary = StreakCalculator.summarize(dates: [date(8), date(9)], now: date(10), calendar: calendar)
        XCTAssertEqual(summary, StreakSummary(current: 2, best: 2, completedToday: false))
    }

    func testMissedDayResetsCurrentButKeepsBest() {
        let summary = StreakCalculator.summarize(dates: [date(1), date(2), date(3), date(4), date(9)], now: date(11), calendar: calendar)
        XCTAssertEqual(summary, StreakSummary(current: 0, best: 4, completedToday: false))
    }
}

final class AlarmClockTests: XCTestCase {
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    // 15 November 2026 is a Sunday.
    func date(day: Int, hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    func testOneTimeAlarmLaterToday() {
        let next = AlarmClock.nextFireDate(hour: 7, minute: 30, repeatMask: 0, after: date(day: 15, hour: 6), calendar: calendar)
        XCTAssertEqual(next, date(day: 15, hour: 7, minute: 30))
    }

    func testOneTimeAlarmRollsToTomorrow() {
        let next = AlarmClock.nextFireDate(hour: 7, minute: 30, repeatMask: 0, after: date(day: 15, hour: 8), calendar: calendar)
        XCTAssertEqual(next, date(day: 16, hour: 7, minute: 30))
    }

    func testWeekdayAlarmSkipsTheWeekend() {
        // Saturday 14 November, after the alarm time: next weekday is Monday 16.
        let next = AlarmClock.nextFireDate(hour: 7, minute: 0, repeatMask: Weekdays.weekdays, after: date(day: 14, hour: 9), calendar: calendar)
        XCTAssertEqual(next, date(day: 16, hour: 7))
    }

    func testWeekdayMaskRoundTrip() {
        XCTAssertEqual(Weekdays.days(in: Weekdays.mask(for: [1, 7])), [1, 7])
        XCTAssertEqual(Weekdays.mask(for: [1, 7]), Weekdays.weekends)
        XCTAssertEqual(Weekdays.days(in: Weekdays.weekdays), [2, 3, 4, 5, 6])
    }

    func testBackupPolicy() {
        let now = date(day: 15, hour: 7)
        XCTAssertTrue(BackupPolicy.shouldScheduleBackup(lastCompletedAt: nil, backupsFired: 0, now: now, calendar: calendar))
        XCTAssertTrue(BackupPolicy.shouldScheduleBackup(lastCompletedAt: date(day: 14, hour: 7), backupsFired: 3, now: now, calendar: calendar))
        XCTAssertFalse(BackupPolicy.shouldScheduleBackup(lastCompletedAt: date(day: 15, hour: 6), backupsFired: 0, now: now, calendar: calendar))
        XCTAssertFalse(BackupPolicy.shouldScheduleBackup(lastCompletedAt: nil, backupsFired: BackupPolicy.maxBackups, now: now, calendar: calendar))
        XCTAssertEqual(BackupPolicy.nextBackupDate(now: now, intervalMinutes: 5), now.addingTimeInterval(300))
        XCTAssertEqual(BackupPolicy.nextBackupDate(now: now, intervalMinutes: 99), now.addingTimeInterval(180))
    }
}

final class SpeechMatcherTests: XCTestCase {
    func testPerfectReading() {
        let verse = "The LORD is my shepherd; I shall not want."
        XCTAssertEqual(SpeechMatcher.score(spoken: "the lord is my shepherd I shall not want", verse: verse, isChinese: false), 1.0, accuracy: 0.001)
    }

    func testPartialReadingFails() {
        let verse = "The LORD is my shepherd; I shall not want."
        let score = SpeechMatcher.score(spoken: "the lord is my", verse: verse, isChinese: false)
        XCTAssertLessThan(score, SpeechMatcher.passingScore)
    }

    func testRepeatedWordsAreNotCountedTwice() {
        let score = SpeechMatcher.score(spoken: "rejoice", verse: "Rejoice, rejoice, rejoice, rejoice.", isChinese: false)
        XCTAssertEqual(score, 0.25, accuracy: 0.001)
    }

    func testChineseIsScoredByCharacter() {
        let verse = "耶和華是我的牧者，我必不至缺乏。"
        XCTAssertEqual(SpeechMatcher.score(spoken: "耶和華是我的牧者我必不至缺乏", verse: verse, isChinese: true), 1.0, accuracy: 0.001)
        XCTAssertLessThan(SpeechMatcher.score(spoken: "耶和華", verse: verse, isChinese: true), 0.5)
    }
}
