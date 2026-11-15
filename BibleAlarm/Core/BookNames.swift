import Foundation

/// English and Traditional Chinese names for the 66 books, keyed by their standard three-letter code.
enum BookNames {
    static let order: [String] = table.map { $0.id }

    static func name(_ bookID: String, chinese: Bool) -> String {
        guard let entry = table.first(where: { $0.id == bookID }) else { return bookID }
        return chinese ? entry.chinese : entry.english
    }

    static func reference(_ ref: VerseRef, chinese: Bool) -> String {
        "\(name(ref.bookID, chinese: chinese)) \(ref.chapter):\(ref.verse)"
    }

    static func chapterTitle(bookID: String, chapter: Int, chinese: Bool) -> String {
        "\(name(bookID, chinese: chinese)) \(chapter)"
    }

    private struct Entry: Sendable {
        let id: String
        let english: String
        let chinese: String
    }

    private static let table: [Entry] = [
        Entry(id: "GEN", english: "Genesis", chinese: "創世記"),
        Entry(id: "EXO", english: "Exodus", chinese: "出埃及記"),
        Entry(id: "LEV", english: "Leviticus", chinese: "利未記"),
        Entry(id: "NUM", english: "Numbers", chinese: "民數記"),
        Entry(id: "DEU", english: "Deuteronomy", chinese: "申命記"),
        Entry(id: "JOS", english: "Joshua", chinese: "約書亞記"),
        Entry(id: "JDG", english: "Judges", chinese: "士師記"),
        Entry(id: "RUT", english: "Ruth", chinese: "路得記"),
        Entry(id: "1SA", english: "1 Samuel", chinese: "撒母耳記上"),
        Entry(id: "2SA", english: "2 Samuel", chinese: "撒母耳記下"),
        Entry(id: "1KI", english: "1 Kings", chinese: "列王紀上"),
        Entry(id: "2KI", english: "2 Kings", chinese: "列王紀下"),
        Entry(id: "1CH", english: "1 Chronicles", chinese: "歷代志上"),
        Entry(id: "2CH", english: "2 Chronicles", chinese: "歷代志下"),
        Entry(id: "EZR", english: "Ezra", chinese: "以斯拉記"),
        Entry(id: "NEH", english: "Nehemiah", chinese: "尼希米記"),
        Entry(id: "EST", english: "Esther", chinese: "以斯帖記"),
        Entry(id: "JOB", english: "Job", chinese: "約伯記"),
        Entry(id: "PSA", english: "Psalms", chinese: "詩篇"),
        Entry(id: "PRO", english: "Proverbs", chinese: "箴言"),
        Entry(id: "ECC", english: "Ecclesiastes", chinese: "傳道書"),
        Entry(id: "SNG", english: "Song of Solomon", chinese: "雅歌"),
        Entry(id: "ISA", english: "Isaiah", chinese: "以賽亞書"),
        Entry(id: "JER", english: "Jeremiah", chinese: "耶利米書"),
        Entry(id: "LAM", english: "Lamentations", chinese: "耶利米哀歌"),
        Entry(id: "EZK", english: "Ezekiel", chinese: "以西結書"),
        Entry(id: "DAN", english: "Daniel", chinese: "但以理書"),
        Entry(id: "HOS", english: "Hosea", chinese: "何西阿書"),
        Entry(id: "JOL", english: "Joel", chinese: "約珥書"),
        Entry(id: "AMO", english: "Amos", chinese: "阿摩司書"),
        Entry(id: "OBA", english: "Obadiah", chinese: "俄巴底亞書"),
        Entry(id: "JON", english: "Jonah", chinese: "約拿書"),
        Entry(id: "MIC", english: "Micah", chinese: "彌迦書"),
        Entry(id: "NAM", english: "Nahum", chinese: "那鴻書"),
        Entry(id: "HAB", english: "Habakkuk", chinese: "哈巴谷書"),
        Entry(id: "ZEP", english: "Zephaniah", chinese: "西番雅書"),
        Entry(id: "HAG", english: "Haggai", chinese: "哈該書"),
        Entry(id: "ZEC", english: "Zechariah", chinese: "撒迦利亞書"),
        Entry(id: "MAL", english: "Malachi", chinese: "瑪拉基書"),
        Entry(id: "MAT", english: "Matthew", chinese: "馬太福音"),
        Entry(id: "MRK", english: "Mark", chinese: "馬可福音"),
        Entry(id: "LUK", english: "Luke", chinese: "路加福音"),
        Entry(id: "JHN", english: "John", chinese: "約翰福音"),
        Entry(id: "ACT", english: "Acts", chinese: "使徒行傳"),
        Entry(id: "ROM", english: "Romans", chinese: "羅馬書"),
        Entry(id: "1CO", english: "1 Corinthians", chinese: "哥林多前書"),
        Entry(id: "2CO", english: "2 Corinthians", chinese: "哥林多後書"),
        Entry(id: "GAL", english: "Galatians", chinese: "加拉太書"),
        Entry(id: "EPH", english: "Ephesians", chinese: "以弗所書"),
        Entry(id: "PHP", english: "Philippians", chinese: "腓立比書"),
        Entry(id: "COL", english: "Colossians", chinese: "歌羅西書"),
        Entry(id: "1TH", english: "1 Thessalonians", chinese: "帖撒羅尼迦前書"),
        Entry(id: "2TH", english: "2 Thessalonians", chinese: "帖撒羅尼迦後書"),
        Entry(id: "1TI", english: "1 Timothy", chinese: "提摩太前書"),
        Entry(id: "2TI", english: "2 Timothy", chinese: "提摩太後書"),
        Entry(id: "TIT", english: "Titus", chinese: "提多書"),
        Entry(id: "PHM", english: "Philemon", chinese: "腓利門書"),
        Entry(id: "HEB", english: "Hebrews", chinese: "希伯來書"),
        Entry(id: "JAS", english: "James", chinese: "雅各書"),
        Entry(id: "1PE", english: "1 Peter", chinese: "彼得前書"),
        Entry(id: "2PE", english: "2 Peter", chinese: "彼得後書"),
        Entry(id: "1JN", english: "1 John", chinese: "約翰一書"),
        Entry(id: "2JN", english: "2 John", chinese: "約翰二書"),
        Entry(id: "3JN", english: "3 John", chinese: "約翰三書"),
        Entry(id: "JUD", english: "Jude", chinese: "猶大書"),
        Entry(id: "REV", english: "Revelation", chinese: "啟示錄"),
    ]
}
