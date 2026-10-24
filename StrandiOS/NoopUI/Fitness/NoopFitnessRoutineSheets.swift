#if os(iOS)
import SwiftUI
import StrandTraining

// The routine editor's small sheets (rest timer, rep range, last time) and the routine page's schedule
// summary. Each sheet is sized to its content, never a full-height page with a few controls in the middle.

/// The two button weights every Fitness action uses: volt for the one thing the screen is for, glass for
/// the rest. Same height and corner as the routine page's Schedule / Start pair.
struct NoopFitnessActionButton: View {
    enum Weight { case primary, secondary }
    let title: String
    var weight: Weight = .primary
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).font(NoopHTMLFont.sans(15, weight: .semibold))
                .foregroundStyle(weight == .primary ? NoopHTMLColor.voltInk : NoopHTMLColor.ink)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(weight == .primary ? NoopHTMLColor.volt : Color.white.opacity(0.07),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(NoopHTMLPressStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
    }
}

/// Sheet chrome shared by the small sheets: a title, an optional subtitle, content, then actions.
private struct NoopFitnessCompactSheet<Content: View, Actions: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var content: Content
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(NoopHTMLFont.sheetTitle).foregroundStyle(NoopHTMLColor.ink)
                if let subtitle {
                    Text(subtitle).font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.copy)
                }
            }
            content
            Spacer(minLength: 0)
            actions
        }
        .padding(.horizontal, 20).padding(.top, 30).padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A big value with − and + either side, the way a value is set with one thumb.
private struct NoopFitnessStepper: View {
    let label: String
    let value: String
    let decrement: () -> Void
    let increment: () -> Void
    var canDecrement = true
    var canIncrement = true

    var body: some View {
        VStack(spacing: 8) {
            Text(label.uppercased()).font(NoopHTMLFont.sans(10.5, weight: .semibold)).tracking(1.2)
                .foregroundStyle(NoopHTMLColor.copy)
            HStack(spacing: 0) {
                step("minus", enabled: canDecrement, action: decrement).accessibilityLabel("Less")
                Text(value).font(NoopHTMLFont.outfit(34)).monospacedDigit().foregroundStyle(NoopHTMLColor.ink)
                    .contentTransition(.numericText()).frame(maxWidth: .infinity)
                    .lineLimit(1).minimumScaleFactor(0.6)
                step("plus", enabled: canIncrement, action: increment).accessibilityLabel("More")
            }
            .padding(6)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(label), \(value)")
    }

    private func step(_ glyph: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: glyph).font(.system(size: 17, weight: .semibold))
                .foregroundStyle(enabled ? NoopHTMLColor.ink : NoopHTMLColor.muted)
                .frame(width: 52, height: 52)
                .background(Color.white.opacity(enabled ? 0.08 : 0.03), in: Circle())
        }
        .buttonStyle(NoopHTMLPressStyle())
        .disabled(!enabled)
    }
}

/// A row of tappable presets; the selected one is filled.
private struct NoopFitnessPresetRow<Value: Hashable>: View {
    let options: [(label: String, value: Value)]
    let selected: Value?
    let pick: (Value) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.value) { option in
                let on = option.value == selected
                Button { pick(option.value) } label: {
                    Text(option.label).font(NoopHTMLFont.sans(13, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(on ? NoopHTMLColor.voltInk : NoopHTMLColor.inkSoft)
                        .frame(maxWidth: .infinity).frame(height: 38)
                        .background(on ? NoopHTMLColor.volt : Color.white.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(NoopHTMLPressStyle())
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}

/// "1:30", "45s", "Off" — how a rest reads everywhere in the editor.
enum NoopRestFormat {
    static func clock(_ seconds: Int) -> String {
        guard seconds > 0 else { return "Off" }
        guard seconds >= 60 else { return "\(seconds)s" }
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}

/// Rest between sets for one exercise. Every change applies to all its sets at once.
struct NoopFitnessRestSheet: View {
    let exercise: String
    @Binding var seconds: Int
    let done: () -> Void

    private static let presets = [60, 90, 120, 180]
    private static let more = [0, 30, 45, 150, 240, 300]

    var body: some View {
        NoopFitnessCompactSheet(title: "Rest timer", subtitle: exercise) {
            NoopFitnessStepper(label: "Between sets", value: NoopRestFormat.clock(seconds),
                               decrement: { set(seconds - 15) }, increment: { set(seconds + 15) },
                               canDecrement: seconds > 0, canIncrement: seconds < 900)
            NoopFitnessPresetRow(options: Self.presets.map { (NoopRestFormat.clock($0), $0) },
                                 selected: seconds, pick: set)
            NoopFitnessPresetRow(options: Self.more.map { (NoopRestFormat.clock($0), $0) },
                                 selected: seconds, pick: set)
        } actions: {
            NoopFitnessActionButton(title: "Done", action: done)
        }
        .sensoryFeedback(.selection, trigger: seconds)
    }

    private func set(_ value: Int) {
        withAnimation(NoopMotion.swap) { seconds = min(900, max(0, value)) }
    }
}

/// Target reps as a range: the low end is the goal, the top is when to add weight.
struct NoopFitnessRepRangeSheet: View {
    let exercise: String
    @Binding var low: Int
    @Binding var high: Int
    let apply: () -> Void

    private static let presets: [(label: String, value: ClosedRange<Int>)] = [
        ("3–5", 3...5), ("6–8", 6...8), ("8–12", 8...12), ("12–15", 12...15), ("15–20", 15...20)
    ]

    var body: some View {
        NoopFitnessCompactSheet(title: "Target rep range", subtitle: exercise) {
            HStack(spacing: 12) {
                NoopFitnessStepper(label: "From", value: "\(low)",
                                   decrement: { change { low -= 1 } }, increment: { change { low += 1; high = max(high, low) } },
                                   canDecrement: low > 1, canIncrement: low < 100)
                NoopFitnessStepper(label: "To", value: "\(high)",
                                   decrement: { change { high -= 1; low = min(low, high) } }, increment: { change { high += 1 } },
                                   canDecrement: high > 1, canIncrement: high < 100)
            }
            NoopFitnessPresetRow(options: Self.presets.map { ($0.label, $0.value) }, selected: low...high) { range in
                change { low = range.lowerBound; high = range.upperBound }
            }
            Text("Hit the top of the range on every set, then add weight next time.")
                .font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.copy)
                .fixedSize(horizontal: false, vertical: true)
        } actions: {
            NoopFitnessActionButton(title: "Apply to all sets", action: apply)
        }
        .sensoryFeedback(.selection, trigger: low * 1000 + high)
    }

    private func change(_ body: () -> Void) {
        withAnimation(NoopMotion.swap) { body() }
    }
}

/// The sets from the last session that logged this exercise, ready to copy into the routine.
struct NoopFitnessLastTimeSheet: View {
    let exercise: String
    let date: Date
    let sets: [RoutineSetPlan]
    let units: UnitSystem
    let use: () -> Void

    var body: some View {
        NoopFitnessCompactSheet(title: "Last time",
                                subtitle: "\(exercise) · \(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))") {
            VStack(spacing: 0) {
                HStack {
                    Text("SET").frame(width: 36, alignment: .leading)
                    Text(LiftFormat.weightUnit(units).uppercased()).frame(maxWidth: .infinity)
                    Text("REPS").frame(maxWidth: .infinity)
                    Text("REST").frame(maxWidth: .infinity)
                }
                .font(NoopHTMLFont.sans(10.5, weight: .semibold)).tracking(1).foregroundStyle(NoopHTMLColor.copy)
                .padding(.bottom, 8)
                ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                    HStack {
                        Text("\(index + 1)").foregroundStyle(NoopHTMLColor.copy).frame(width: 36, alignment: .leading)
                        Text(set.targetWeightKg.map { LiftFormat.trim(LiftFormat.display(fromKilograms: $0, system: units)) } ?? "BW")
                            .frame(maxWidth: .infinity)
                        Text(set.repsMin.map(String.init) ?? "—").frame(maxWidth: .infinity)
                        Text(set.restSeconds.map(NoopRestFormat.clock) ?? "—").foregroundStyle(NoopHTMLColor.copy)
                            .frame(maxWidth: .infinity)
                    }
                    .font(NoopHTMLFont.sans(15, weight: .medium)).monospacedDigit().foregroundStyle(NoopHTMLColor.ink)
                    .frame(height: 40)
                    if index < sets.count - 1 { Divider().overlay(NoopHTMLColor.border) }
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        } actions: {
            NoopFitnessActionButton(title: "Use these sets", action: use)
        }
    }
}

/// A routine's upcoming sessions, read as a plan ("Mon, Wed, Fri at 6:00 PM · until 30 Dec") with the
/// next few dates under it, never every date of a 26-week repeat in a list.
struct NoopFitnessScheduleSummary: View {
    let upcoming: [NoopFitnessSettings.Plan]
    let remove: (NoopFitnessSettings.Plan) -> Void
    let stopRepeating: () -> Void
    let edit: () -> Void
    @State private var expanded = false

    private var cal: Calendar { Calendar.current }

    /// "Mon, Wed, Fri" when the dates fall on a weekly pattern, nil for a one-off.
    private var weekdays: String? {
        guard upcoming.count > 1 else { return nil }
        let days = Set(upcoming.map { cal.component(.weekday, from: $0.date) })
        let monFirst = days.sorted { ($0 + 5) % 7 < ($1 + 5) % 7 }
        return monFirst.map { cal.shortWeekdaySymbols[$0 - 1] }.joined(separator: ", ")
    }

    private var time: String? {
        let timed = upcoming.filter { $0.includesTime != false }
        guard let first = timed.first else { return nil }
        let hm = cal.dateComponents([.hour, .minute], from: first.date)
        guard timed.allSatisfy({ cal.dateComponents([.hour, .minute], from: $0.date) == hm }) else { return nil }
        return first.date.formatted(date: .omitted, time: .shortened)
    }

    var body: some View {
        NoopFitnessPanel(label: "Scheduled") {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: upcoming.count > 1 ? "repeat" : "calendar")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(NoopHTMLColor.volt)
                    .frame(width: 36, height: 36)
                    .background(NoopHTMLColor.volt.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(headline).font(NoopHTMLFont.sans(15, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                    Text(detail).font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.copy)
                }
                Spacer(minLength: 0)
                Menu {
                    Button { edit() } label: { Label("Change schedule", systemImage: "calendar.badge.clock") }
                    Button(role: .destructive) { stopRepeating() } label: {
                        Label(upcoming.count > 1 ? "Remove all upcoming" : "Remove", systemImage: "calendar.badge.minus")
                    }
                } label: {
                    Image(systemName: "ellipsis").foregroundStyle(NoopHTMLColor.inkSoft).frame(width: 36, height: 36)
                }
                .accessibilityLabel("Schedule actions")
            }

            VStack(spacing: 0) {
                ForEach(Array(shown.enumerated()), id: \.element.id) { index, plan in
                    row(plan, next: index == 0)
                    if index < shown.count - 1 { Divider().overlay(NoopHTMLColor.border).padding(.leading, 56) }
                }
            }
            .padding(.top, 4)

            if upcoming.count > 3 {
                Button {
                    withAnimation(NoopMotion.swap) { expanded.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Text(expanded ? "Show less" : "All \(upcoming.count) sessions")
                        Image(systemName: "chevron.down").rotationEffect(.degrees(expanded ? 180 : 0))
                    }
                    .font(NoopHTMLFont.sans(13, weight: .semibold)).foregroundStyle(NoopHTMLColor.inkSoft)
                    .frame(maxWidth: .infinity).frame(height: 40)
                }
                .buttonStyle(NoopHTMLPressStyle())
            }
        }
        .padding(.top, 12)
    }

    private var shown: [NoopFitnessSettings.Plan] { expanded ? upcoming : Array(upcoming.prefix(3)) }

    private var headline: String {
        guard let weekdays else {
            return upcoming.first.map { $0.date.formatted(.dateTime.weekday(.wide).day().month(.wide)) } ?? ""
        }
        return time.map { "\(weekdays) at \($0)" } ?? weekdays
    }

    private var detail: String {
        let n = upcoming.count
        guard n > 1, let last = upcoming.last else {
            return time.map { "Once at \($0)" } ?? "Once"
        }
        return "\(n) sessions · until \(last.date.formatted(.dateTime.day().month(.abbreviated)))"
    }

    private func row(_ plan: NoopFitnessSettings.Plan, next: Bool) -> some View {
        HStack(spacing: 14) {
            VStack(spacing: 0) {
                Text(plan.date.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .font(NoopHTMLFont.sans(9.5, weight: .bold)).tracking(0.8)
                    .foregroundStyle(next ? NoopHTMLColor.volt : NoopHTMLColor.copy)
                Text(plan.date.formatted(.dateTime.day()))
                    .font(NoopHTMLFont.sans(17, weight: .semibold)).monospacedDigit().foregroundStyle(NoopHTMLColor.ink)
            }
            .frame(width: 42, height: 44)
            .background(Color.white.opacity(next ? 0.08 : 0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.date.formatted(.dateTime.weekday(.wide)))
                    .font(NoopHTMLFont.sans(14.5, weight: .medium)).foregroundStyle(NoopHTMLColor.ink)
                Text(relative(plan))
                    .font(NoopHTMLFont.sans(12)).foregroundStyle(next ? NoopHTMLColor.volt : NoopHTMLColor.copy)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .contextMenu {
            Button(role: .destructive) { remove(plan) } label: { Label("Skip this one", systemImage: "calendar.badge.minus") }
        }
        .modifier(NoopSwipeToDelete { remove(plan) })
        .accessibilityAction(named: "Skip this one") { remove(plan) }
    }

    private func relative(_ plan: NoopFitnessSettings.Plan) -> String {
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: plan.date)).day ?? 0
        let when = days == 0 ? "Today" : days == 1 ? "Tomorrow" : "In \(days) days"
        guard plan.includesTime != false else { return when }
        return "\(when) · \(plan.date.formatted(date: .omitted, time: .shortened))"
    }
}
#endif
