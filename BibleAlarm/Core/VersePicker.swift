import Foundation

/// Chooses the next morning verse, avoiding verses read recently.
enum VersePicker {
    /// Verses completed within this many days are not shown again.
    static let noRepeatDays = 60

    static func pick<G: RandomNumberGenerator>(
        pool: [VerseRef], recent: Set<VerseRef>, using generator: inout G
    ) -> VerseRef? {
        let fresh = pool.filter { !recent.contains($0) }
        return (fresh.isEmpty ? pool : fresh).randomElement(using: &generator)
    }

    /// A stable key for a calendar day, for example "2026-11-15".
    static func dayKey(for date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04ld-%02ld-%02ld", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
