import AlarmKit
import Foundation
import Observation

/// Keeps the user's alarm list in step with the alarms registered with iOS.
@MainActor
@Observable
final class AlarmService {
    enum Permission: Sendable {
        case unknown
        case allowed
        case denied
    }

    private(set) var permission: Permission = .unknown
    var errorMessage: String?

    func refreshPermission() {
        switch AlarmManager.shared.authorizationState {
        case .authorized: permission = .allowed
        case .denied: permission = .denied
        case .notDetermined: permission = .unknown
        @unknown default: permission = .unknown
        }
    }

    /// Shows the system permission prompt if it has not been answered yet.
    @discardableResult
    func requestPermission() async -> Bool {
        do {
            let state = try await AlarmManager.shared.requestAuthorization()
            permission = state == .authorized ? .allowed : .denied
        } catch {
            refreshPermission()
        }
        return permission == .allowed
    }

    /// Schedules the alarm if it is switched on, otherwise removes it from the system.
    func sync(_ entry: AlarmEntry, soundName: String?) async {
        let snapshot = AlarmSnapshot(
            entryID: entry.id, label: entry.label,
            intervalMinutes: BackupPolicy.normalizedInterval(entry.backupIntervalMinutes),
            soundName: soundName, difficulty: entry.difficultyRaw)
        guard entry.isEnabled else {
            AlarmScheduler.cancel(id: entry.id)
            ChallengeStore.removeSnapshot(entryID: entry.id)
            return
        }
        guard await requestPermission() else {
            entry.isEnabled = false
            errorMessage = String(localized: "Alarms are turned off for Bible Alarm. Allow them in the Settings app.")
            return
        }
        ChallengeStore.save(snapshot)
        let title = entry.label.isEmpty ? String(localized: "Time to read God's word") : entry.label
        let hour = entry.hour
        let minute = entry.minute
        let repeatMask = entry.repeatMask
        do {
            try await AlarmScheduler.scheduleMain(
                snapshot: snapshot, title: title, hour: hour, minute: minute, repeatMask: repeatMask)
        } catch AlarmManager.AlarmError.maximumLimitReached {
            entry.isEnabled = false
            errorMessage = String(localized: "iOS will not allow any more alarms. Delete one and try again.")
        } catch {
            entry.isEnabled = false
            errorMessage = String(localized: "The alarm could not be set. Please try again.")
        }
    }

    func remove(_ entry: AlarmEntry) {
        AlarmScheduler.cancel(id: entry.id)
        ChallengeStore.removeSnapshot(entryID: entry.id)
    }

    /// One-time alarms disappear from iOS after they ring; switch them off in the list too.
    /// Repeating alarms that iOS has lost (for example after restoring a backup) are returned for rescheduling.
    func reconcile(_ entries: [AlarmEntry]) -> [AlarmEntry] {
        refreshPermission()
        guard permission == .allowed, let scheduled = AlarmScheduler.scheduledIDs() else { return [] }
        var missingRepeating: [AlarmEntry] = []
        for entry in entries where entry.isEnabled && !scheduled.contains(entry.id) {
            if entry.repeatMask == 0 {
                entry.isEnabled = false
            } else {
                missingRepeating.append(entry)
            }
        }
        return missingRepeating
    }
}
