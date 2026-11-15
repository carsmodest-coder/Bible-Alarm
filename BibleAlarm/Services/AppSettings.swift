import Foundation
import Observation

/// The user's choices, saved in UserDefaults.
@MainActor
@Observable
final class AppSettings {
    private let defaults = UserDefaults.standard

    var hasOnboarded: Bool { didSet { defaults.set(hasOnboarded, forKey: "hasOnboarded") } }
    var bibleVersionID: String { didSet { defaults.set(bibleVersionID, forKey: "bibleVersionID") } }
    var difficulty: Difficulty { didSet { defaults.set(difficulty.rawValue, forKey: "difficulty") } }
    var challengeMode: ChallengeMode { didSet { defaults.set(challengeMode.rawValue, forKey: "challengeMode") } }
    var defaultBackupInterval: Int { didSet { defaults.set(defaultBackupInterval, forKey: "defaultBackupInterval") } }
    /// "all", "set:<id>" or "plan:<id>". Anything other than "all" is Premium.
    var verseSource: String { didSet { defaults.set(verseSource, forKey: "verseSource") } }
    /// Test builds only: unlocks Premium without a purchase.
    var testUnlock: Bool { didSet { defaults.set(testUnlock, forKey: "testUnlock") } }

    // Today's verse stays the same all day once it has been chosen.
    var dailyVerseDay: String { didSet { defaults.set(dailyVerseDay, forKey: "dailyVerseDay") } }
    var dailyVerseRef: String { didSet { defaults.set(dailyVerseRef, forKey: "dailyVerseRef") } }
    var dailyVerseSource: String { didSet { defaults.set(dailyVerseSource, forKey: "dailyVerseSource") } }

    init() {
        let defaults = UserDefaults.standard
        hasOnboarded = defaults.bool(forKey: "hasOnboarded")
        bibleVersionID = defaults.string(forKey: "bibleVersionID")
            ?? BibleVersion.suggested(forLanguageCode: Locale.current.language.languageCode?.identifier).id
        difficulty = Difficulty(rawValue: defaults.string(forKey: "difficulty") ?? "") ?? .normal
        challengeMode = ChallengeMode(rawValue: defaults.string(forKey: "challengeMode") ?? "") ?? .tap
        let interval = defaults.integer(forKey: "defaultBackupInterval")
        defaultBackupInterval = BackupPolicy.normalizedInterval(interval)
        verseSource = defaults.string(forKey: "verseSource") ?? "all"
        testUnlock = defaults.bool(forKey: "testUnlock")
        dailyVerseDay = defaults.string(forKey: "dailyVerseDay") ?? ""
        dailyVerseRef = defaults.string(forKey: "dailyVerseRef") ?? ""
        dailyVerseSource = defaults.string(forKey: "dailyVerseSource") ?? ""
    }

    var bibleVersion: BibleVersion { BibleVersion.version(id: bibleVersionID) }

    func planProgress(_ planID: String) -> Int {
        defaults.integer(forKey: "planProgress." + planID)
    }

    func setPlanProgress(_ day: Int, for planID: String) {
        defaults.set(day, forKey: "planProgress." + planID)
    }
}
