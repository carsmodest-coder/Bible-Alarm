import Foundation

/// What an alarm needs to know when it rings while the app is not open.
struct AlarmSnapshot: Codable, Sendable {
    var entryID: UUID
    var label: String
    var intervalMinutes: Int
    /// File name of the alarm sound, or nil for the system sound.
    var soundName: String?
    var difficulty: String
}

/// A morning verse that still has to be completed after an alarm rang.
struct PendingChallenge: Codable, Sendable {
    var entryID: UUID?
    var startedAt: Date
    var backupsFired: Int
    var backupAlarmID: UUID?
    var intervalMinutes: Int
    var soundName: String?
    var difficulty: String
}

/// Small pieces of state shared between the app and the alarm buttons (App Intents).
/// Stored in UserDefaults so it is available even when the app was launched in the background.
enum ChallengeStore {
    private static let pendingKey = "challenge.pending"
    private static let completedKey = "challenge.lastCompletedAt"
    private static let snapshotsKey = "challenge.snapshots"

    static var pending: PendingChallenge? {
        get { decode(PendingChallenge.self, forKey: pendingKey) }
        set { encode(newValue, forKey: pendingKey) }
    }

    static var lastCompletedAt: Date? {
        get { UserDefaults.standard.object(forKey: completedKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: completedKey) }
    }

    static func snapshot(for entryID: UUID) -> AlarmSnapshot? {
        snapshots()[entryID.uuidString]
    }

    static func save(_ snapshot: AlarmSnapshot) {
        var all = snapshots()
        all[snapshot.entryID.uuidString] = snapshot
        encode(all, forKey: snapshotsKey)
    }

    static func removeSnapshot(entryID: UUID) {
        var all = snapshots()
        all[entryID.uuidString] = nil
        encode(all, forKey: snapshotsKey)
    }

    private static func snapshots() -> [String: AlarmSnapshot] {
        decode([String: AlarmSnapshot].self, forKey: snapshotsKey) ?? [:]
    }

    private static func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func encode<T: Encodable>(_ value: T?, forKey key: String) {
        guard let value, let data = try? JSONEncoder().encode(value) else {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        UserDefaults.standard.set(data, forKey: key)
    }
}
