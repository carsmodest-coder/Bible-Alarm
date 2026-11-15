import Foundation

struct StreakSummary: Equatable, Sendable {
    let current: Int
    let best: Int
    let completedToday: Bool
}

/// Works out the reading streak from the dates verses were completed.
enum StreakCalculator {
    static func summarize(dates: [Date], now: Date, calendar: Calendar) -> StreakSummary {
        let days = Set(dates.map { calendar.startOfDay(for: $0) })
        guard !days.isEmpty else { return StreakSummary(current: 0, best: 0, completedToday: false) }

        let today = calendar.startOfDay(for: now)
        let completedToday = days.contains(today)

        // The streak is still alive if yesterday was completed and today has not been done yet.
        var current = 0
        var cursor = completedToday ? today : (calendar.date(byAdding: .day, value: -1, to: today) ?? today)
        while days.contains(cursor) {
            current += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        var best = 0
        for day in days {
            // Only count runs from their first day.
            if let dayBefore = calendar.date(byAdding: .day, value: -1, to: day), days.contains(dayBefore) { continue }
            var length = 0
            var runCursor = day
            while days.contains(runCursor) {
                length += 1
                guard let next = calendar.date(byAdding: .day, value: 1, to: runCursor) else { break }
                runCursor = next
            }
            best = max(best, length)
        }
        return StreakSummary(current: current, best: max(best, current), completedToday: completedToday)
    }
}
