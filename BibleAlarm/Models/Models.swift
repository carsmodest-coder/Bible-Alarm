import Foundation
import SwiftData

/// One alarm the user created. Its `id` is also the identifier used with AlarmKit.
@Model
final class AlarmEntry {
    var id: UUID = UUID()
    var hour: Int = 7
    var minute: Int = 0
    var label: String = ""
    /// Repeat days as bits (see `Weekdays`). 0 means the alarm rings once.
    var repeatMask: Int = 0
    var isEnabled: Bool = true
    var soundID: String = SoundID.defaultID
    var difficultyRaw: String = Difficulty.normal.rawValue
    var backupIntervalMinutes: Int = BackupPolicy.defaultInterval
    var createdAt: Date = Date()

    init(hour: Int, minute: Int, label: String = "", repeatMask: Int = 0, soundID: String = SoundID.defaultID,
         difficulty: Difficulty = .normal, backupIntervalMinutes: Int = BackupPolicy.defaultInterval) {
        self.id = UUID()
        self.hour = hour
        self.minute = minute
        self.label = label
        self.repeatMask = repeatMask
        self.isEnabled = true
        self.soundID = soundID
        self.difficultyRaw = difficulty.rawValue
        self.backupIntervalMinutes = backupIntervalMinutes
        self.createdAt = Date()
    }

    var difficulty: Difficulty {
        get { Difficulty(rawValue: difficultyRaw) ?? .normal }
        set { difficultyRaw = newValue.rawValue }
    }
}

/// A sound the user imported or recorded. The audio file lives in the app's Library/Sounds folder.
@Model
final class CustomSound {
    var id: UUID = UUID()
    var displayName: String = ""
    var fileName: String = ""
    var durationSeconds: Double = 0
    var createdAt: Date = Date()

    init(id: UUID, displayName: String, fileName: String, durationSeconds: Double) {
        self.id = id
        self.displayName = displayName
        self.fileName = fileName
        self.durationSeconds = durationSeconds
        self.createdAt = Date()
    }
}

/// A verse the user completed.
@Model
final class VerseRecord {
    var id: UUID = UUID()
    var versionID: String = "kjv"
    var bookID: String = ""
    var chapter: Int = 1
    var verse: Int = 1
    var text: String = ""
    var completedAt: Date = Date()
    var isFavorite: Bool = false
    var reflection: String = ""

    init(verse: Verse, completedAt: Date = Date()) {
        self.id = UUID()
        self.versionID = verse.versionID
        self.bookID = verse.ref.bookID
        self.chapter = verse.ref.chapter
        self.verse = verse.ref.verse
        self.text = verse.text
        self.completedAt = completedAt
        self.isFavorite = false
        self.reflection = ""
    }

    var ref: VerseRef { VerseRef(bookID: bookID, chapter: chapter, verse: verse) }
    var asVerse: Verse { Verse(ref: ref, versionID: versionID, text: text) }
}
