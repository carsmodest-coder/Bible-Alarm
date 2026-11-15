import Foundation
import Observation

/// Reads the bundled files. Kept off the main actor so a 4 MB Bible can be decoded in the background.
enum BibleLoader {
    static func loadBible(versionID: String) -> BibleData? {
        guard let url = Bundle.main.url(forResource: versionID, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(BibleData.self, from: data)
    }

    static func loadVerseSets() -> VerseSetsFile {
        guard let url = Bundle.main.url(forResource: "verse_sets", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(VerseSetsFile.self, from: data) else {
            return VerseSetsFile(sets: [])
        }
        return file
    }
}

/// Gives the app Bible text. Only one translation is kept in memory at a time.
@MainActor
@Observable
final class BibleStore {
    private var loaded: BibleData?
    @ObservationIgnored private(set) lazy var verseSets: VerseSetsFile = BibleLoader.loadVerseSets()

    func bible(versionID: String) async -> BibleData? {
        if let loaded, loaded.id == versionID { return loaded }
        let data = await Task.detached(priority: .userInitiated) {
            BibleLoader.loadBible(versionID: versionID)
        }.value
        if let data { loaded = data }
        return data
    }

    func verse(_ ref: VerseRef, versionID: String) async -> Verse? {
        guard let text = await bible(versionID: versionID)?.text(for: ref) else { return nil }
        return Verse(ref: ref, versionID: versionID, text: text)
    }

    func chapter(bookID: String, chapter: Int, versionID: String) async -> [String] {
        await bible(versionID: versionID)?.chapter(bookID: bookID, chapter: chapter) ?? []
    }

    /// Text of other curated verses in the same translation, used as the source of wrong choices.
    func distractorTexts(versionID: String, excluding ref: VerseRef, count: Int = 40) async -> [String] {
        guard let bible = await bible(versionID: versionID) else { return [] }
        let refs = verseSets.refs(inSet: nil).filter { $0 != ref }.shuffled().prefix(count)
        return refs.compactMap { bible.text(for: $0) }
    }
}
