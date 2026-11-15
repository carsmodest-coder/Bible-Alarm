import Foundation

/// Repeat days stored as bits: Sunday is bit 0, Monday bit 1 ... Saturday bit 6.
/// Day numbers match `Calendar` weekdays (1 = Sunday ... 7 = Saturday).
enum Weekdays {
    static func mask(for days: Set<Int>) -> Int {
        days.reduce(0) { $0 | (1 << ($1 - 1)) }
    }

    static func days(in mask: Int) -> [Int] {
        (1...7).filter { mask & (1 << ($0 - 1)) != 0 }
    }

    static func contains(_ mask: Int, day: Int) -> Bool {
        mask & (1 << (day - 1)) != 0
    }

    static let everyDay = 0b1111111
    static let weekdays = 0b0111110
    static let weekends = 0b1000001
}

enum AlarmClock {
    /// The next moment an alarm set for `hour:minute` rings. A mask of 0 means a one-time alarm.
    static func nextFireDate(hour: Int, minute: Int, repeatMask: Int, after now: Date, calendar: Calendar) -> Date? {
        for offset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now),
                  let candidate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  candidate > now else { continue }
            if repeatMask == 0 || Weekdays.contains(repeatMask, day: calendar.component(.weekday, from: candidate)) {
                return candidate
            }
        }
        return nil
    }
}

/// Rules for the follow-up alarms that keep ringing until the verse is finished.
enum BackupPolicy {
    static let maxBackups = 10
    static let allowedIntervals = [2, 3, 5]
    static let defaultInterval = 3

    static func normalizedInterval(_ minutes: Int) -> Int {
        allowedIntervals.contains(minutes) ? minutes : defaultInterval
    }

    /// A follow-up alarm is needed unless today's verse is already done or the limit was reached.
    static func shouldScheduleBackup(lastCompletedAt: Date?, backupsFired: Int, now: Date, calendar: Calendar) -> Bool {
        if backupsFired >= maxBackups { return false }
        if let lastCompletedAt, calendar.isDate(lastCompletedAt, inSameDayAs: now) { return false }
        return true
    }

    static func nextBackupDate(now: Date, intervalMinutes: Int) -> Date {
        now.addingTimeInterval(TimeInterval(normalizedInterval(intervalMinutes) * 60))
    }
}
