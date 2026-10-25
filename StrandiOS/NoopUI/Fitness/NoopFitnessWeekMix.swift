#if os(iOS)
import SwiftUI

/// This week's training at a glance: one column a day, weights in green beneath cardio and sports in blue,
/// so the two read as one week rather than two competing ones. The total and how it compares with last
/// week sit above; the split in time sits below.
struct NoopFitnessWeekMixCard: View {
    let week: [NoopFitnessSnapshot.WeekDay]
    /// Every session in the history, for last week's total.
    let history: [NoopFitnessSession]
    let now: Date

    @State private var grown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func minutes(_ sessions: [NoopFitnessSession], _ kind: NoopFitnessSession.Kind) -> Double {
        sessions.filter { $0.kind == kind }.reduce(0) { $0 + $1.durationS } / 60
    }

    private var strength: Double { week.reduce(0) { $0 + minutes($1.sessions, .strength) } }
    private var cardio: Double { week.reduce(0) { $0 + minutes($1.sessions, .cardio) } }
    private var sessionCount: Int { week.reduce(0) { $0 + $1.sessions.count } }

    /// Last week's whole total, or nil before there is any history from before this week.
    private var lastWeek: Double? {
        guard let monday = week.first?.date,
              let start = Calendar.current.date(byAdding: .day, value: -7, to: monday),
              history.contains(where: { $0.start < monday }) else { return nil }
        return history.filter { $0.start >= start && $0.start < monday }.reduce(0) { $0 + $1.durationS } / 60
    }

    var body: some View {
        let total = strength + cardio
        let peak = max(30, week.map { minutes($0.sessions, .strength) + minutes($0.sessions, .cardio) }.max() ?? 0)
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(total > 0 ? Self.duration(total) : "Nothing yet")
                        .font(NoopHTMLFont.outfit(NoopType.title2, weight: .light)).foregroundStyle(NoopHTMLColor.ink)
                        .monospacedDigit().contentTransition(.numericText())
                    Text(total > 0 ? "\(sessionCount) \(sessionCount == 1 ? "session" : "sessions") this week" : "The week fills in as you train")
                        .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                }
                Spacer()
                if let last = lastWeek, last > 0 {
                    // Last week's total stays quiet until this week passes it; then it is a small win.
                    let ahead = total > last
                    HStack(spacing: 4) {
                        if ahead { Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .bold)) }
                        Text(ahead ? "Past last week's \(Self.duration(last))" : "Last week \(Self.duration(last))")
                            .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold)).monospacedDigit()
                    }
                    .foregroundStyle(ahead ? NoopHTMLColor.green : NoopHTMLColor.copy)
                    .padding(.horizontal, 10).frame(height: 28)
                    .background((ahead ? NoopHTMLColor.green : Color.white).opacity(0.08), in: Capsule())
                }
            }

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(week.enumerated()), id: \.element.id) { i, day in
                    column(day, peak: peak, index: i)
                }
            }
            .frame(height: 112)

            HStack(spacing: 16) {
                legend(NoopHTMLColor.volt, "Weights", strength)
                legend(NoopHTMLColor.blueLight, "Cardio and sports", cardio)
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
        .onAppear {
            guard !grown else { return }
            if reduceMotion { grown = true } else { withAnimation(.spring(response: 0.7, dampingFraction: 0.82).delay(0.1)) { grown = true } }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("This week, \(Self.duration(total)): weights \(Self.duration(strength)), cardio and sports \(Self.duration(cardio)).")
        .padding(.bottom, 22)
    }

    private func column(_ day: NoopFitnessSnapshot.WeekDay, peak: Double, index: Int) -> some View {
        let s = minutes(day.sessions, .strength), c = minutes(day.sessions, .cardio)
        let today = Calendar.current.isDateInToday(day.date)
        let future = day.date > now && !today
        let height: CGFloat = 86
        return VStack(spacing: 7) {
            ZStack(alignment: .bottom) {
                Capsule().fill(Color.white.opacity(future ? 0.025 : 0.05)).frame(width: 14, height: height)
                if s + c > 0 {
                    VStack(spacing: 2) {
                        if c > 0 {
                            Capsule().fill(NoopHTMLColor.blueLight.gradient)
                                .frame(width: 14, height: max(6, height * CGFloat(c / peak)))
                        }
                        if s > 0 {
                            Capsule().fill(NoopHTMLColor.volt.gradient)
                                .frame(width: 14, height: max(6, height * CGFloat(s / peak)))
                        }
                    }
                    .scaleEffect(x: 1, y: grown ? 1 : 0.02, anchor: .bottom)
                    .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.04), value: grown)
                }
            }
            .frame(height: height, alignment: .bottom)
            Text(day.date.formatted(.dateTime.weekday(.narrow)))
                .font(NoopHTMLFont.sans(NoopType.eyebrow, weight: today ? .bold : .medium))
                .foregroundStyle(today ? NoopHTMLColor.ink : NoopHTMLColor.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private func legend(_ color: Color, _ title: String, _ minutes: Double) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(title).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
            Text(minutes > 0 ? Self.duration(minutes) : "—").font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
                .foregroundStyle(NoopHTMLColor.ink).monospacedDigit()
        }
    }

    static func duration(_ minutes: Double) -> String {
        let m = Int(minutes)   // whole minutes, as every other duration in Fitness
        return m >= 60 ? "\(m / 60)h \(String(format: "%02d", m % 60))m" : "\(m)m"
    }
}
#endif
