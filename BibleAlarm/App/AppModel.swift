import Foundation
import Observation
import SwiftData

/// One verse challenge being shown on screen.
struct ChallengeSession: Identifiable {
    enum Kind {
        case daily
        case memorize
    }

    let id = UUID()
    let verse: Verse
    let challenge: BlankChallenge
    let mode: ChallengeMode
    let kind: Kind
    let fromAlarm: Bool
}

/// The app's shared state: settings, services and the challenge currently on screen.
@MainActor
@Observable
final class AppModel {
    let container: ModelContainer
    let settings = AppSettings()
    let bible = BibleStore()
    let alarms = AlarmService()
    let store = StoreService()
    let player = SoundPreviewPlayer()

    /// The morning challenge, shown full screen when not nil.
    var session: ChallengeSession?
    private var isPreparingSession = false

    init(container: ModelContainer) {
        self.container = container
    }

    var context: ModelContext { container.mainContext }
    var isPremium: Bool { store.hasPremiumPurchase || settings.testUnlock }
    var completedToday: Bool {
        guard let last = ChallengeStore.lastCompletedAt else { return false }
        return Calendar.current.isDateInToday(last)
    }

    /// The answer style actually used: strict modes fall back to tapping without Premium.
    var effectiveMode: ChallengeMode { isPremium ? settings.challengeMode : .tap }
    var effectiveVerseSource: String { isPremium ? settings.verseSource : "all" }

    // MARK: - App lifecycle

    func appBecameActive() async {
        let entries = (try? context.fetch(FetchDescriptor<AlarmEntry>())) ?? []
        for entry in alarms.reconcile(entries) {
            await syncAlarm(entry)
        }
        try? context.save()
        if ChallengeStore.pending != nil {
            await startTodaysChallenge(fromAlarm: true)
        }
    }

    // MARK: - Alarms

    func syncAlarm(_ entry: AlarmEntry) async {
        let customSounds = (try? context.fetch(FetchDescriptor<CustomSound>())) ?? []
        let sound = SoundCatalog.resolve(entry.soundID, customSounds: customSounds)
        await alarms.sync(entry, soundName: sound.fileName)
        try? context.save()
    }

    func deleteAlarm(_ entry: AlarmEntry) {
        alarms.remove(entry)
        context.delete(entry)
        try? context.save()
    }

    // MARK: - Verses

    /// Chooses today's verse once and keeps returning it for the rest of the day.
    func todaysVerse() async -> Verse? {
        let versionID = settings.bibleVersionID
        let today = VersePicker.dayKey(for: Date(), calendar: .current)
        let source = effectiveVerseSource

        if settings.dailyVerseDay == today, settings.dailyVerseSource == source,
           let ref = VerseRef(settings.dailyVerseRef),
           let verse = await bible.verse(ref, versionID: versionID) {
            return verse
        }

        var chosen: VerseRef?
        if source.hasPrefix("plan:"), let plan = ReadingPlan.plan(id: String(source.dropFirst(5))) {
            chosen = plan.day(at: settings.planProgress(plan.id))
        } else {
            let setID = source.hasPrefix("set:") ? String(source.dropFirst(4)) : nil
            var pool = bible.verseSets.refs(inSet: setID)
            if pool.isEmpty { pool = bible.verseSets.refs(inSet: nil) }
            var generator = SystemRandomNumberGenerator()
            chosen = VersePicker.pick(pool: pool, recent: recentRefs(), using: &generator)
        }
        guard let chosen, let verse = await bible.verse(chosen, versionID: versionID) else { return nil }
        settings.dailyVerseDay = today
        settings.dailyVerseRef = chosen.key
        settings.dailyVerseSource = source
        return verse
    }

    private func recentRefs() -> Set<VerseRef> {
        let cutoff = Calendar.current.date(byAdding: .day, value: -VersePicker.noRepeatDays, to: Date()) ?? Date.distantPast
        let descriptor = FetchDescriptor<VerseRecord>(predicate: #Predicate { $0.completedAt >= cutoff })
        let records = (try? context.fetch(descriptor)) ?? []
        return Set(records.map { $0.ref })
    }

    func makeSession(verse: Verse, blankCount: Int, mode: ChallengeMode, kind: ChallengeSession.Kind, fromAlarm: Bool) async -> ChallengeSession {
        let others = await bible.distractorTexts(versionID: verse.versionID, excluding: verse.ref)
        var generator = SystemRandomNumberGenerator()
        let challenge = BlankGenerator(isChinese: verse.isChinese).makeChallenge(
            text: verse.text, blankCount: blankCount, distractorTexts: others, using: &generator)
        return ChallengeSession(verse: verse, challenge: challenge, mode: mode, kind: kind, fromAlarm: fromAlarm)
    }

    /// Opens the wake-up verse screen.
    func startTodaysChallenge(fromAlarm: Bool) async {
        guard session == nil, !isPreparingSession else { return }
        isPreparingSession = true
        defer { isPreparingSession = false }
        guard let verse = await todaysVerse() else { return }
        var difficulty = settings.difficulty
        if fromAlarm, let raw = ChallengeStore.pending?.difficulty, let alarmDifficulty = Difficulty(rawValue: raw) {
            difficulty = alarmDifficulty
        }
        session = await makeSession(
            verse: verse, blankCount: difficulty.blankCount, mode: effectiveMode, kind: .daily, fromAlarm: fromAlarm)
    }

    /// Records a finished morning verse and stops the follow-up alarms.
    @discardableResult
    func completeDaily(_ finished: ChallengeSession) -> VerseRecord {
        BackupChain.verseCompleted()

        // Reading today's verse a second time does not add a second entry or move a plan forward again.
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let todays = (try? context.fetch(FetchDescriptor<VerseRecord>(predicate: #Predicate { $0.completedAt >= startOfDay }))) ?? []
        if let existing = todays.first(where: { $0.ref == finished.verse.ref }) {
            return existing
        }

        let record = VerseRecord(verse: finished.verse)
        context.insert(record)
        try? context.save()

        let source = settings.dailyVerseSource
        if source.hasPrefix("plan:") {
            let planID = String(source.dropFirst(5))
            settings.setPlanProgress(settings.planProgress(planID) + 1, for: planID)
        }
        // Tomorrow, or the next time the source changes, a new verse is chosen.
        return record
    }
}
