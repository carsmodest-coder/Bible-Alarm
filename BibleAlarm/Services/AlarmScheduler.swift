import ActivityKit
import AlarmKit
import AppIntents
import Foundation
import SwiftUI

/// AlarmKit requires a metadata type; this app has no extra data to attach.
struct VerseAlarmMetadata: AlarmMetadata {}

/// Thin wrapper around AlarmKit. Has no state of its own, so the alarm buttons (App Intents)
/// can use it when the app was launched in the background.
enum AlarmScheduler {
    static let tint = Color(red: 0.96, green: 0.69, blue: 0.29)

    /// Schedules (or replaces) the main alarm for an entry.
    static func scheduleMain(snapshot: AlarmSnapshot, title: String, hour: Int, minute: Int, repeatMask: Int) async throws {
        try? AlarmManager.shared.cancel(id: snapshot.entryID)
        let days = Weekdays.days(in: repeatMask).compactMap { localeWeekday($0) }
        let relative = Alarm.Schedule.Relative(
            time: Alarm.Schedule.Relative.Time(hour: hour, minute: minute),
            repeats: days.isEmpty ? .never : .weekly(days))
        let configuration = AlarmManager.AlarmConfiguration<VerseAlarmMetadata>.alarm(
            schedule: .relative(relative),
            attributes: attributes(title: title),
            stopIntent: AlarmStoppedIntent(alarmID: snapshot.entryID, entryID: snapshot.entryID),
            secondaryIntent: OpenVerseIntent(alarmID: snapshot.entryID, entryID: snapshot.entryID),
            sound: sound(named: snapshot.soundName))
        _ = try await AlarmManager.shared.schedule(id: snapshot.entryID, configuration: configuration)
    }

    /// Schedules a one-time follow-up alarm.
    static func scheduleBackup(id: UUID, entryID: UUID?, title: String, fireDate: Date, soundName: String?) async throws {
        let configuration = AlarmManager.AlarmConfiguration<VerseAlarmMetadata>.alarm(
            schedule: .fixed(fireDate),
            attributes: attributes(title: title),
            stopIntent: AlarmStoppedIntent(alarmID: id, entryID: entryID),
            secondaryIntent: OpenVerseIntent(alarmID: id, entryID: entryID),
            sound: sound(named: soundName))
        _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
    }

    static func cancel(id: UUID) {
        try? AlarmManager.shared.cancel(id: id)
    }

    static func stop(id: UUID) {
        try? AlarmManager.shared.stop(id: id)
    }

    /// Identifiers of every alarm currently registered with the system, or nil if that could not be read.
    static func scheduledIDs() -> Set<UUID>? {
        guard let alarms = try? AlarmManager.shared.alarms else { return nil }
        return Set(alarms.map { $0.id })
    }

    private static func attributes(title: String) -> AlarmAttributes<VerseAlarmMetadata> {
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(String.LocalizationValue(title)),
            stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.circle"),
            secondaryButton: AlarmButton(text: "Read verse", textColor: .white, systemImageName: "book.fill"),
            secondaryButtonBehavior: .custom)
        return AlarmAttributes(
            presentation: AlarmPresentation(alert: alert),
            metadata: VerseAlarmMetadata(),
            tintColor: tint)
    }

    private static func sound(named name: String?) -> AlertConfiguration.AlertSound {
        if let name, !name.isEmpty { return .named(name) }
        return .default
    }

    private static func localeWeekday(_ day: Int) -> Locale.Weekday? {
        switch day {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return nil
        }
    }
}

/// Keeps follow-up alarms ringing until today's verse is finished.
enum BackupChain {
    /// Called whenever an alarm is silenced without the verse being finished
    /// (Stop was tapped, or the app was opened from the alarm).
    static func alarmWasSilenced(entryID: UUID?) async {
        let now = Date()
        let calendar = Calendar.current
        let snapshot = entryID.flatMap { ChallengeStore.snapshot(for: $0) }

        var challenge: PendingChallenge
        if let existing = ChallengeStore.pending, calendar.isDate(existing.startedAt, inSameDayAs: now) {
            challenge = existing
        } else {
            challenge = PendingChallenge(
                entryID: entryID, startedAt: now, backupsFired: 0, backupAlarmID: nil,
                intervalMinutes: snapshot?.intervalMinutes ?? BackupPolicy.defaultInterval,
                soundName: snapshot?.soundName,
                difficulty: snapshot?.difficulty ?? Difficulty.normal.rawValue)
        }

        if let lastCompleted = ChallengeStore.lastCompletedAt, calendar.isDate(lastCompleted, inSameDayAs: now) {
            // Today's verse is already done: nothing to chase.
            ChallengeStore.pending = nil
            return
        }

        if let previous = challenge.backupAlarmID {
            AlarmScheduler.cancel(id: previous)
            challenge.backupAlarmID = nil
        }

        if BackupPolicy.shouldScheduleBackup(
            lastCompletedAt: ChallengeStore.lastCompletedAt, backupsFired: challenge.backupsFired,
            now: now, calendar: calendar) {
            let backupID = UUID()
            let fireDate = BackupPolicy.nextBackupDate(now: now, intervalMinutes: challenge.intervalMinutes)
            let title = String(localized: "Read today's verse to stop the alarm")
            do {
                try await AlarmScheduler.scheduleBackup(
                    id: backupID, entryID: challenge.entryID, title: title,
                    fireDate: fireDate, soundName: challenge.soundName)
                challenge.backupAlarmID = backupID
                challenge.backupsFired += 1
            } catch {
                challenge.backupAlarmID = nil
            }
        }
        ChallengeStore.pending = challenge
    }

    /// Called when the verse is finished: stop chasing.
    static func verseCompleted() {
        if let backupID = ChallengeStore.pending?.backupAlarmID {
            AlarmScheduler.cancel(id: backupID)
        }
        ChallengeStore.pending = nil
        ChallengeStore.lastCompletedAt = Date()
    }
}

/// Runs when Stop is tapped on a ringing alarm.
struct AlarmStoppedIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop alarm"
    static let isDiscoverable: Bool = false

    @Parameter(title: "Alarm ID")
    var alarmID: String

    @Parameter(title: "Entry ID")
    var entryID: String

    init() {
        self.alarmID = ""
        self.entryID = ""
    }

    init(alarmID: UUID, entryID: UUID?) {
        self.alarmID = alarmID.uuidString
        self.entryID = entryID?.uuidString ?? ""
    }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID) {
            AlarmScheduler.stop(id: id)
        }
        await BackupChain.alarmWasSilenced(entryID: UUID(uuidString: entryID))
        return .result()
    }
}

/// Runs when "Read verse" is tapped on a ringing alarm: silences it and opens the app on the verse.
struct OpenVerseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Read verse"
    static let isDiscoverable: Bool = false
    static let supportedModes: IntentModes = .foreground

    @Parameter(title: "Alarm ID")
    var alarmID: String

    @Parameter(title: "Entry ID")
    var entryID: String

    init() {
        self.alarmID = ""
        self.entryID = ""
    }

    init(alarmID: UUID, entryID: UUID?) {
        self.alarmID = alarmID.uuidString
        self.entryID = entryID?.uuidString ?? ""
    }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID) {
            AlarmScheduler.stop(id: id)
        }
        // A follow-up alarm is still scheduled in case the app is closed again without finishing.
        await BackupChain.alarmWasSilenced(entryID: UUID(uuidString: entryID))
        return .result()
    }
}
