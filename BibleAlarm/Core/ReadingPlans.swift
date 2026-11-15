import Foundation

/// A Premium reading plan: one chapter a day, with one key verse from it for the morning challenge.
struct ReadingPlan: Identifiable, Sendable {
    let id: String
    let days: [VerseRef]

    func day(at index: Int) -> VerseRef? {
        guard !days.isEmpty else { return nil }
        return days[((index % days.count) + days.count) % days.count]
    }

    static let all: [ReadingPlan] = [proverbs, psalms, john]

    static func plan(id: String) -> ReadingPlan? {
        all.first { $0.id == id }
    }

    private static func refs(_ list: String) -> [VerseRef] {
        list.split(separator: ",").compactMap { VerseRef($0.trimmingCharacters(in: .whitespaces)) }
    }

    /// Proverbs in 31 days.
    static let proverbs = ReadingPlan(id: "proverbs31", days: refs("""
        PRO 1:7, PRO 2:6, PRO 3:5, PRO 4:23, PRO 5:21, PRO 6:6, PRO 7:2, PRO 8:11, PRO 9:10, PRO 10:12, \
        PRO 11:25, PRO 12:25, PRO 13:20, PRO 14:26, PRO 15:1, PRO 16:3, PRO 17:17, PRO 18:10, PRO 19:21, \
        PRO 20:7, PRO 21:21, PRO 22:1, PRO 23:18, PRO 24:16, PRO 25:11, PRO 26:20, PRO 27:17, PRO 28:13, \
        PRO 29:25, PRO 30:5, PRO 31:30
        """))

    /// Thirty well-loved Psalms in 30 days.
    static let psalms = ReadingPlan(id: "psalms30", days: refs("""
        PSA 1:2, PSA 8:1, PSA 16:8, PSA 19:14, PSA 23:1, PSA 24:1, PSA 27:1, PSA 32:8, PSA 34:8, PSA 37:4, \
        PSA 40:1, PSA 42:1, PSA 46:1, PSA 51:10, PSA 62:1, PSA 63:1, PSA 67:1, PSA 84:10, PSA 90:12, PSA 91:1, \
        PSA 95:6, PSA 100:4, PSA 103:1, PSA 116:1, PSA 121:1, PSA 127:1, PSA 130:5, PSA 139:14, PSA 145:18, \
        PSA 150:6
        """))

    /// The Gospel of John in 21 days.
    static let john = ReadingPlan(id: "john21", days: refs("""
        JHN 1:14, JHN 2:11, JHN 3:16, JHN 4:14, JHN 5:24, JHN 6:35, JHN 7:38, JHN 8:12, JHN 9:25, JHN 10:10, \
        JHN 11:25, JHN 12:46, JHN 13:34, JHN 14:6, JHN 15:5, JHN 16:33, JHN 17:17, JHN 18:11, JHN 19:30, \
        JHN 20:29, JHN 21:22
        """))
}
