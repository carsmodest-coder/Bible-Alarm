import Foundation

/// A single verse location, for example John 3:16.
struct VerseRef: Hashable, Codable, Sendable {
    let bookID: String
    let chapter: Int
    let verse: Int

    init(bookID: String, chapter: Int, verse: Int) {
        self.bookID = bookID
        self.chapter = chapter
        self.verse = verse
    }

    /// Parses the compact form used in the bundled data, for example "JHN 3:16".
    init?(_ string: String) {
        let parts = string.split(separator: " ")
        guard parts.count == 2 else { return nil }
        let numbers = parts[1].split(separator: ":")
        guard numbers.count == 2, let chapter = Int(numbers[0]), let verse = Int(numbers[1]) else { return nil }
        self.init(bookID: String(parts[0]), chapter: chapter, verse: verse)
    }

    var key: String { "\(bookID) \(chapter):\(verse)" }
}

/// One bundled Bible translation.
struct BibleVersion: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let shortName: String
    let isChinese: Bool
    let credit: String

    static let kjv = BibleVersion(
        id: "kjv", name: "King James Version", shortName: "KJV", isChinese: false,
        credit: "King James Version (1769). Public domain.")
    static let web = BibleVersion(
        id: "web", name: "World English Bible", shortName: "WEB", isChinese: false,
        credit: "World English Bible. Public domain.")
    static let cuv = BibleVersion(
        id: "cuv", name: "和合本", shortName: "和合本", isChinese: true,
        credit: "Chinese Union Version 和合本 (1919), Traditional Chinese. Public domain.")

    static let all: [BibleVersion] = [.kjv, .web, .cuv]

    static func version(id: String) -> BibleVersion {
        all.first { $0.id == id } ?? .kjv
    }

    /// Chinese-language devices start with 和合本, everything else with the KJV.
    static func suggested(forLanguageCode code: String?) -> BibleVersion {
        code == "zh" ? .cuv : .kjv
    }
}

/// The decoded contents of one bundled Bible file.
struct BibleData: Decodable, Sendable {
    struct Book: Decodable, Sendable {
        let id: String
        let chapters: [[String]]
    }

    let id: String
    let books: [Book]

    func chapter(bookID: String, chapter: Int) -> [String]? {
        guard let book = books.first(where: { $0.id == bookID }),
              chapter >= 1, chapter <= book.chapters.count else { return nil }
        return book.chapters[chapter - 1]
    }

    func text(for ref: VerseRef) -> String? {
        guard let verses = chapter(bookID: ref.bookID, chapter: ref.chapter),
              ref.verse >= 1, ref.verse <= verses.count else { return nil }
        let text = verses[ref.verse - 1]
        return text.isEmpty ? nil : text
    }
}

/// A verse together with its text in one version.
struct Verse: Hashable, Sendable {
    let ref: VerseRef
    let versionID: String
    let text: String

    var version: BibleVersion { BibleVersion.version(id: versionID) }
    var isChinese: Bool { version.isChinese }
    var referenceText: String { BookNames.reference(ref, chinese: isChinese) }
}

/// The curated verse lists in verse_sets.json.
struct VerseSetsFile: Decodable, Sendable {
    struct VerseSet: Decodable, Sendable {
        let id: String
        let refs: [String]
    }

    let sets: [VerseSet]

    func refs(inSet id: String?) -> [VerseRef] {
        var seen = Set<VerseRef>()
        var result: [VerseRef] = []
        for set in sets where id == nil || set.id == id {
            for ref in set.refs.compactMap({ VerseRef($0) }) where seen.insert(ref).inserted {
                result.append(ref)
            }
        }
        return result
    }
}
