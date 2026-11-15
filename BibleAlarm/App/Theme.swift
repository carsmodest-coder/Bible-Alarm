import SwiftUI

/// Colours and shared styles. Dark and calm: the person looking at this is half asleep.
enum Theme {
    static let background = Color(red: 0.039, green: 0.055, blue: 0.149)
    static let card = Color(red: 0.105, green: 0.118, blue: 0.235)
    static let accent = Color(red: 0.96, green: 0.69, blue: 0.29)
    static let secondaryText = Color.white.opacity(0.65)
    static let faintText = Color.white.opacity(0.4)
}

/// The one main action on a screen.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.semibold))
            .foregroundStyle(Color.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Theme.accent.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 18))
    }
}

/// A quieter, outlined action.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.card.opacity(configuration.isPressed ? 0.6 : 1), in: RoundedRectangle(cornerRadius: 18))
    }
}

extension View {
    /// Dark page background for lists and forms.
    func screenBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
    }

    func cardRow() -> some View {
        self.listRowBackground(Theme.card)
    }
}

/// Small "Premium" badge shown next to locked features.
struct PremiumBadge: View {
    var body: some View {
        Text("Premium")
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color.black)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Theme.accent, in: Capsule())
    }
}

/// Moves a view left and right, used when an answer is wrong.
struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(animatableData * .pi * 4), y: 0))
    }
}

enum Formatters {
    static func time(hour: Int, minute: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    static func clock(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%ld:%02ld", total / 60, total % 60)
    }

    /// "Once", "Every day", "Weekdays", "Weekends" or a list such as "Mon Wed Fri".
    static func repeatSummary(mask: Int) -> String {
        switch mask {
        case 0: return String(localized: "Once")
        case Weekdays.everyDay: return String(localized: "Every day")
        case Weekdays.weekdays: return String(localized: "Weekdays")
        case Weekdays.weekends: return String(localized: "Weekends")
        default:
            let symbols = Calendar.current.shortWeekdaySymbols
            return Weekdays.days(in: mask).map { symbols[$0 - 1] }.joined(separator: " ")
        }
    }
}
