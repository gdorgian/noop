#if os(iOS)
import Foundation

/// The five things Noop has no opinion about, and the one thing it does ask.
///
/// One source, because two hand-typed copies of the product's own position drift — and the drift
/// was already here: the first-run panel denied four things, `you`'s trailing sentence denied three,
/// and no two lists agreed. These five are the union and the canonical set. `you/position` renders
/// them as rows; onboarding's step-1 panel renders the same titles inline.
enum NoopPositionCopy {
    struct Denial: Identifiable {
        let title: String
        let reason: String
        var id: String { title }
    }

    static let denials: [Denial] = [
        Denial(
            title: "No weight goal",
            reason: "Weight moves for reasons a strap cannot see. Noop reads what your body does, not what it weighs."
        ),
        Denial(
            title: "No calorie target",
            reason: "It estimates what you spent, because that changes a training decision. It will never set a number for you to eat against."
        ),
        Denial(
            title: "No step count",
            reason: "Ten thousand is a marketing figure from 1965. Your zones already say what the walk was worth."
        ),
        Denial(
            title: "No daily score",
            reason: "One number for a whole person is a horoscope. The day’s shape and the night’s read say more and hide less."
        ),
        Denial(
            title: "No comparison with other people",
            reason: "Nothing here is ranked against anyone else. Your only reference is your own last few weeks."
        )
    ]

    static let lead = "Five things this app has no opinion about. Each one is missing on purpose, and here is the purpose."

    static let asksTitle = "What it does ask"

    static let asks = "Six facts about your body, once, and one question about when you sleep. Everything else on your screens is measured or worked out."

    static let foot = "These are positions, not features waiting to be built. If one of them ever arrives, it will arrive with a reason on this screen."

    /// The first-run panel keeps its inline place and renders the same five titles, so the wizard
    /// and `you/position` cannot drift apart the way the four-, three- and five-item lists already had.
    static var inlineList: String { denials.map(\.title).joined(separator: " · ") }

    static let inlineClosing = "None of them would change a word of what it tells you."
}
#endif
