import SwiftUI
import UIKit
import StrandImport
import WhoopStore

struct NoopAct8Screens: View {
    @ObservedObject var navigation: NoopNavigation

    var body: some View {
        switch navigation.route {
        case .goal:
            NoopGoalJourney(navigation: navigation)
        case .setGoal:
            NoopGoalSet(navigation: navigation)
        case .labs:
            NoopLabsHome(navigation: navigation)
        case .review:
            NoopLabReview(navigation: navigation)
        case .marker:
            NoopMarkerDetail(navigation: navigation)
        default:
            NoopGoalJourney(navigation: navigation)
        }
    }
}

// MARK: - Journey

private struct NoopGoalJourney: View {
    @ObservedObject var navigation: NoopNavigation
    @ObservedObject private var goalStore = CoachGoalStore.shared
    @AppStorage("noop.html.active-goal-kind") private var activeKind = NoopGoalKind.distance.rawValue
    @AppStorage("noop.html.active-goal-title") private var activeTitle = "Half marathon on 26 October, finishing comfortably."
    @State private var weekState = "open"

    var body: some View {
        NoopScreen(bottomInset: 118, topInset: 56) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 12) {
                    Button { navigation.reset(to: .you) } label: {
                        ZStack {
                            Circle().fill(Color.white.opacity(0.06)).overlay(Circle().stroke(NoopHTMLColor.borderStrong, lineWidth: 0.5))
                            NoopFixedChevron(direction: .left, color: NoopHTMLColor.inkSoft).offset(x: -1)
                        }.frame(width: 34, height: 34)
                    }.buttonStyle(.plain)
                    Text("You").font(NoopHTMLFont.sans(13.5)).foregroundStyle(NoopHTMLColor.copy)
                    Spacer()
                    Button("Change it") { navigation.push(.setGoal) }
                        .buttonStyle(NoopHTMLButtonStyle(kind: .secondary))
                        .frame(height: 30)
                }
                .padding(.horizontal, -2)

                HStack {
                    NoopSectionLabel("One goal at a time")
                    Spacer()
                    Text(deadlineLabel).font(NoopHTMLFont.sans(10.5)).foregroundStyle(NoopHTMLColor.faint)
                }.padding(.top, 8)

                NoopGoalRouteGraphic()

                VStack(alignment: .leading, spacing: 6) {
                    Text(displayedTitle)
                        .font(NoopHTMLFont.outfit(25, weight: .light)).tracking(-0.7).lineSpacing(2)
                    Text(goalSubtitle)
                        .font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.copy).lineSpacing(4)
                }
                .padding(.horizontal, 2)
                .padding(.top, 6)
                .padding(.bottom, 2)

                NoopAct8GradientCard(
                    tint: NoopHTMLColor.green,
                    degrees: 158,
                    startOpacity: 0.15,
                    endColor: Color.white.opacity(0.02),
                    borderOpacity: 0.34,
                    padding: EdgeInsets(top: 17, leading: 17, bottom: 16, trailing: 17)
                ) {
                    VStack(alignment: .leading, spacing: 11) {
                        HStack(spacing: 9) {
                            Circle().fill(NoopHTMLColor.green).shadow(color: NoopHTMLColor.green, radius: 5).frame(width: 8, height: 8)
                            NoopSectionLabel("The data says yes", color: Color(hex: 0x8FEFC0))
                        }
                        Text(feasibilityCopy)
                            .font(NoopHTMLFont.sans(13.5)).foregroundStyle(Color(hex: 0xDCE3E0)).lineSpacing(6.3)
                    }
                }
                .padding(.top, 14)

                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            NoopSectionLabel("Waypoints")
                            Spacer()
                            Text("only ticked when it happened").font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.faint)
                        }.padding(.bottom, 2)
                        ForEach(Array(waypoints.enumerated()), id: \.offset) { index, waypoint in
                            HStack(alignment: .top, spacing: 12) {
                                Group {
                                    if waypoint.done { Circle().fill(Color(hex: 0xF2B45C)).shadow(color: Color(hex: 0xF2B45C), radius: 6) }
                                    else { Circle().stroke(Color.white.opacity(0.24), style: StrokeStyle(lineWidth: 1.6, dash: [3, 3])) }
                                }.frame(width: 17, height: 17).padding(.top, 2)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(waypoint.title).font(NoopHTMLFont.sans(13.5)).foregroundStyle(waypoint.done ? NoopHTMLColor.ink : NoopHTMLColor.inkSoft)
                                    Text(waypoint.detail).font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy).lineSpacing(2)
                                }
                                Spacer()
                                NoopPill(text: waypoint.tag, color: waypoint.done ? Color(hex: 0xF6DCB4) : NoopHTMLColor.copy)
                            }.padding(.vertical, 14)
                            if index < waypoints.count - 1 { Divider().overlay(NoopHTMLColor.border) }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(NoopHTMLColor.border, lineWidth: 0.5))
                .padding(.top, 10)

                NoopAct8GradientCard(
                    tint: NoopHTMLColor.night,
                    degrees: 160,
                    startOpacity: 0.14,
                    endColor: NoopHTMLColor.night.opacity(0.03),
                    borderOpacity: 0.30,
                    padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
                ) {
                    VStack(alignment: .leading, spacing: 11) {
                        HStack {
                            NoopSectionLabel("This week, from Svea", color: Color(hex: 0xC9D0EE)); Spacer()
                            NoopPill(text: "written", color: Color(hex: 0xA9B4E0))
                        }
                        Text(weekProposal).font(NoopHTMLFont.sans(13.5)).foregroundStyle(Color(hex: 0xDCE3E0)).lineSpacing(4)
                        if weekState == "open" {
                            GeometryReader { proxy in
                                let unit = max(0, proxy.size.width - 7) / 2.4
                                HStack(spacing: 7) {
                                    Button("Take the week") { weekState = "taken" }
                                        .buttonStyle(NoopAct8WeekActionStyle(primary: true))
                                        .frame(width: unit * 1.4)
                                    Button("Not this week") { weekState = "skipped" }
                                        .buttonStyle(NoopAct8WeekActionStyle(primary: false))
                                        .frame(width: unit)
                                }
                            }
                            .frame(height: 42)
                        } else {
                            HStack {
                                Text(weekState == "taken" ? "This week is in. Svea will still check each morning" : "Left out. The route holds and the date does not move for one week")
                                    .font(NoopHTMLFont.sans(12.5))
                                Spacer()
                                Button("Undo") { weekState = "open" }.font(NoopHTMLFont.sans(11.5, weight: .semibold)).foregroundStyle(Color(hex: 0xA9B4E0))
                            }.padding(12).background(NoopHTMLColor.night.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
                .padding(.top, 10)

                NoopAct8BiomarkerLink(detail: biomarkersSummary) { navigation.push(.labs) }
                    .padding(.top, 10)
                Text("Progress is counted from sessions that were actually recorded on your wrist. Noop will not credit you for a week it did not see, and it will not invent a streak to keep you going.")
                    .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(3)
                    .padding(.horizontal, 2)
                    .padding(.top, 6)
            }
        }
    }

    private var activeStoredGoal: CoachGoal? {
        NoopContentPolicy.allowsPrototypeContent ? nil : goalStore.activeGoals.first
    }
    private var displayedTitle: String {
        NoopContentPolicy.allowsPrototypeContent
            ? "Half marathon on 26 October, finishing comfortably."
            : activeStoredGoal?.title ?? activeTitle
    }
    private var deadlineLabel: String {
        if NoopContentPolicy.allowsPrototypeContent { return "11 weeks to 26 October" }
        guard let deadline = activeStoredGoal?.targetDate else { return "11 weeks to 26 October" }
        let weeks = max(0, Calendar.current.dateComponents([.weekOfYear], from: Date(), to: deadline).weekOfYear ?? 0)
        return "\(weeks) weeks to \(deadline.formatted(.dateTime.day().month(.wide)))"
    }
    private var goalKind: NoopGoalKind {
        if NoopContentPolicy.allowsPrototypeContent { return .distance }
        if let stored = activeStoredGoal {
            switch stored.kind {
            case .sleep: return .sleep
            case .consistency: return .sleep
            case .weight: return .composition
            case .run: return NoopGoalKind(rawValue: activeKind) ?? .distance
            default: break
            }
        }
        return NoopGoalKind(rawValue: activeKind) ?? .distance
    }
    private var goalSubtitle: String {
        switch goalKind {
        case .distance: "Set 4 August. Two waypoints reached, both recorded on your wrist — 34 km a week at 6:04, and seventeen of the last thirty-one nights over your own need."
        case .pace: "Set from your recent sessions. Every waypoint is credited only when the target pace was recorded on your wrist."
        case .sleep: "Built from the bedtime window you chose and the nights the strap actually saw — missed nights are left blank, never guessed."
        case .composition: "Built from values you entered yourself. Noop dates every change and never treats the strap as a body-composition sensor."
        }
    }
    private var feasibilityCopy: String {
        switch goalKind {
        case .distance: "Twelve kilometres at 6:04 with heart rate under 150, on 34 km a week and eleven weeks left. The route asks for 55 km at peak, which is a 9% build — inside what your sleep has been absorbing."
        case .pace: "Your last four comparable efforts are moving in the right direction. The route keeps the hard work under the load your sleep has absorbed."
        case .sleep: "Your current timing already lands inside the chosen window on five nights a week. The route asks for consistency before it asks for a tighter window."
        case .composition: "The target sits inside the rate of change recorded over your last three entries. Wearable estimates are not used to make this call."
        }
    }
    private var weekProposal: String {
        goalKind == .distance
            ? "Four runs: two easy, one 14 km on Saturday, and Wednesday only if Tuesday night lands over your need. Nothing in this week is fixed — it moves with the mornings."
            : "Three small steps this week, each tied to the measurements that support this goal. Nothing is credited until it is recorded."
    }
    private var waypoints: [NoopGoalWaypoint] {
        switch goalKind {
        case .distance:
            [
                .init(title: "First 12 km run", detail: "done 3 August, at 6:04/km", tag: "reached", done: true),
                .init(title: "Four weeks inside your bedtime hour", detail: "done 17 August — the reason the rest is possible", tag: "reached", done: true),
                .init(title: "18 km at conversational pace", detail: "the next one. Two attempts allowed, no penalty for either", tag: "next", done: false),
                .init(title: "A week at 55 km without a poor night", detail: "the load ceiling this route is built around", tag: "ahead", done: false),
                .init(title: "Half marathon, 26 October", detail: "the goal. Nothing about the date is a promise", tag: "the day", done: false)
            ]
        case .pace:
            genericWaypoints(["Baseline effort recorded", "Three repeats inside target", "Target pace over half the distance", "Full-distance rehearsal", "Target effort"])
        case .sleep:
            genericWaypoints(["Five nights inside the window", "First full week", "Four steady weekends", "Eight-week run", "Regularity target"])
        case .composition:
            genericWaypoints(["Baseline entered", "First dated change", "Four-week trend", "Halfway value", "Target value"])
        }
    }
    private func genericWaypoints(_ labels: [String]) -> [NoopGoalWaypoint] {
        labels.enumerated().map { .init(title: $0.element, detail: $0.offset < 2 ? "recorded and dated" : "credited only when measured", tag: $0.offset < 2 ? "reached" : ($0.offset == 2 ? "next" : "ahead"), done: $0.offset < 2) }
    }
    private var biomarkersSummary: String {
        let outside = NoopLabMarker.all.filter(\.isOutside).count
        return "\(outside) of \(NoopLabMarker.all.count) outside the lab band · drawn 14 August"
    }
}

private struct NoopGoalRouteGraphic: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let spin = reduceMotion ? 0 : now.truncatingRemainder(dividingBy: 110) / 110 * 360
            let pulsePhase = now.truncatingRemainder(dividingBy: 9) / 9
            let pulse = reduceMotion ? 0.70 : 0.70 + 0.30 * ((1 - cos(pulsePhase * 2 * .pi)) / 2)

            ZStack {
                Ellipse()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: Color(hex: 0xF2B45C).opacity(0.22), location: 0),
                                .init(color: Color(hex: 0xF2B45C).opacity(0), location: 0.62)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 270)
                    .blur(radius: 18)
                    .opacity(pulse)

                routeSpecks
                    .rotationEffect(.degrees(spin))

                Canvas { context, size in
                    func point(_ t: Double) -> CGPoint {
                        CGPoint(
                            x: (22 + t * 296) / 330 * size.width,
                            y: (128 - sin(t * 2.1) * 58 - t * 26 + sin(t * 6.1) * 5) / 220 * size.height
                        )
                    }

                    func drawSegments(_ target: inout GraphicsContext) {
                        for index in 0..<36 {
                            let t0 = Double(index) / 36
                            let t1 = Double(index + 1) / 36
                            let done = t1 <= 0.46
                            let edge = !done && t0 <= 0.46
                            var segment = Path()
                            segment.move(to: point(t0))
                            segment.addLine(to: point(t1))
                            target.stroke(
                                segment,
                                with: .color(done ? Color(hex: 0xF2B45C) : edge ? Color(hex: 0xF2B45C).opacity(0.5) : Color.white.opacity(0.11)),
                                style: StrokeStyle(lineWidth: done ? 7 : 4, lineCap: .round)
                            )
                        }
                    }

                    context.drawLayer { glow in
                        glow.opacity = 0.85
                        glow.addFilter(.blur(radius: 8))
                        drawSegments(&glow)
                    }
                    drawSegments(&context)

                    for t in [0.06, 0.30, 0.52, 0.76, 0.97] {
                        let done = t <= 0.46
                        let center = point(t)
                        let radius: CGFloat = done ? 6 : 5
                        let dot = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                        context.fill(dot, with: .color(done ? Color(hex: 0xF2B45C) : NoopHTMLColor.canvas))
                        context.stroke(dot, with: .color(done ? Color(hex: 0xF6DCB4) : Color.white.opacity(0.3)), lineWidth: 1.8)
                    }
                }
                .frame(width: 330, height: 220)

                VStack {
                    Spacer()
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("46%")
                                .font(NoopHTMLFont.outfit200(50))
                                .tracking(-2.25)
                                .shadow(color: .black.opacity(0.75), radius: 12, y: 2)
                            Text("OF THE ROUTE, RECORDED")
                                .font(NoopHTMLFont.sans(10.5, weight: .semibold))
                                .tracking(1.68)
                                .foregroundStyle(Color(hex: 0x93A0A6))
                        }
                        Spacer()
                    }
                }
                .padding(.bottom, 6)

                VStack {
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("26 OCTOBER")
                                .font(NoopHTMLFont.sans(9.5, weight: .semibold))
                                .tracking(1.14)
                                .foregroundStyle(NoopHTMLColor.faint)
                            Text("the day itself")
                                .font(NoopHTMLFont.sans(11))
                                .foregroundStyle(NoopHTMLColor.copy)
                        }
                    }
                    Spacer()
                }
                .padding(.top, 6)
                .padding(.trailing, 2)
            }
            .frame(height: 252)
        }
    }

    private var routeSpecks: some View {
        Canvas { context, size in
            for index in 0..<30 {
                let angle = Double(index) * 2.39996 + hash(index) * 1.3
                let radius = 0.72 + hash(index + 40) * 0.34
                let diameter = 1 + hash(index + 9) * 2
                let center = CGPoint(
                    x: size.width * (0.5 + cos(angle) * radius * 0.47),
                    y: size.height * (0.5 + sin(angle) * radius * 0.47)
                )
                let rect = CGRect(
                    x: center.x - diameter / 2,
                    y: center.y - diameter / 2,
                    width: diameter,
                    height: diameter
                )
                context.drawLayer { dot in
                    dot.addFilter(.shadow(color: Color(hex: 0xF2B45C).opacity(0.7), radius: diameter * 2.6))
                    dot.fill(
                        Path(ellipseIn: rect),
                        with: .color(Color(hex: 0xFFE8C4).opacity(0.14 + hash(index + 3) * 0.38))
                    )
                }
            }
        }
        .frame(width: 250, height: 250)
    }

    private func hash(_ number: Int) -> Double {
        let value = sin(Double(number) * 127.1 + 311.7) * 43_758.5453
        return value - floor(value)
    }
}

private struct NoopAct8GradientCard<Content: View>: View {
    let tint: Color
    let degrees: Double
    let startOpacity: Double
    let endColor: Color
    let borderOpacity: Double
    let padding: EdgeInsets
    let content: Content

    init(
        tint: Color,
        degrees: Double,
        startOpacity: Double,
        endColor: Color,
        borderOpacity: Double,
        padding: EdgeInsets,
        @ViewBuilder content: () -> Content
    ) {
        self.tint = tint
        self.degrees = degrees
        self.startOpacity = startOpacity
        self.endColor = endColor
        self.borderOpacity = borderOpacity
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                NoopCSSLinearGradient(
                    colors: [tint.opacity(startOpacity), endColor],
                    degrees: degrees
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(tint.opacity(borderOpacity), lineWidth: 0.5)
            }
    }
}

private struct NoopAct8BiomarkerLink: View {
    let detail: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                NoopCanonicalGlyph(name: .drop, size: 20, color: NoopHTMLColor.warm)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Biomarkers")
                        .font(NoopHTMLFont.sans(13.5))
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text(detail)
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(Color(hex: 0x7F8A85))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                NoopFixedChevron(direction: .right, color: NoopHTMLColor.faint)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 66)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(NoopHTMLColor.border, lineWidth: 0.5)
            }
        }
        .buttonStyle(NoopHTMLPressStyle())
    }
}

// MARK: - Set goal

private struct NoopGoalSet: View {
    @ObservedObject var navigation: NoopNavigation
    @ObservedObject private var goalStore = CoachGoalStore.shared
    @AppStorage("noop.html.goal-week-index") private var weekIndex = 4
    @AppStorage("noop.html.goal-draft-title") private var draftTitle = "Half marathon on 26 October, finishing comfortably."
    @AppStorage("noop.html.active-goal-kind") private var activeKind = NoopGoalKind.distance.rawValue
    @AppStorage("noop.html.active-goal-title") private var activeTitle = "Half marathon on 26 October, finishing comfortably."
    @State private var showCommitConfirmation = false
    private let labels = ["6 weeks", "2 months", "10 weeks", "3 months", "15 weeks", "4 months", "20 weeks", "5 months", "6 months", "8 months", "10 months", "a year"]

    var body: some View {
        ZStack {
            NoopScreen(bottomInset: 118, topInset: 56) {
                VStack(alignment: .leading, spacing: 12) {
                    NoopBackHeader(label: "Journey") { navigation.reset(to: .goal) }
                        .padding(.horizontal, -2)
                        .padding(.bottom, -14)
                    Text("Set the goal").font(NoopHTMLFont.outfit(25, weight: .light)).tracking(-0.7)

                    NoopHTMLCard(radius: 24, padding: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            NoopSectionLabel("What are you aiming at")
                            NoopFlowLayout(spacing: 7) {
                                ForEach(NoopGoalKind.allCases) { kind in
                                    Button {
                                        navigation.selectedGoal = kind
                                        navigation.show(.goalEditor)
                                    } label: {
                                        Text(kind.rawValue).font(NoopHTMLFont.sans(12, weight: .semibold))
                                            .foregroundStyle(navigation.selectedGoal == kind ? Color(hex: 0x1E1405) : NoopHTMLColor.inkSoft)
                                            .padding(.horizontal, 13).frame(height: 36)
                                            .background(navigation.selectedGoal == kind ? Color(hex: 0xF2B45C) : Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 11))
                                            .overlay(RoundedRectangle(cornerRadius: 11).stroke(navigation.selectedGoal == kind ? .clear : Color.white.opacity(0.1), lineWidth: 0.5))
                                    }.buttonStyle(.plain)
                                }
                            }
                            HStack {
                                Text("By when").font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.inkSoft)
                                Spacer()
                                Text(labels[selectedWeekIndex]).font(.system(size: 12.5, weight: .semibold, design: .monospaced)).foregroundStyle(Color(hex: 0xF6DCB4))
                            }.padding(.top, 4)
                            HStack(alignment: .bottom, spacing: 5) {
                                ForEach(labels.indices, id: \.self) { index in
                                    Button { weekIndex = index } label: {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(index == selectedWeekIndex ? Color(hex: 0xF2B45C) : index < selectedWeekIndex ? Color(hex: 0xF2B45C).opacity(0.32) : Color.white.opacity(0.1))
                                            .frame(height: index == selectedWeekIndex ? 34 : 24)
                                    }.buttonStyle(.plain)
                                }
                            }
                            HStack { Text("6 weeks"); Spacer(); Text("a year") }.font(NoopHTMLFont.sans(10.5)).foregroundStyle(NoopHTMLColor.faint)
                        }
                    }

                    NoopAct8GradientCard(
                        tint: feasibility.color,
                        degrees: 158,
                        startOpacity: 0.15,
                        endColor: Color.white.opacity(0.02),
                        borderOpacity: 0.34,
                        padding: EdgeInsets(top: 17, leading: 17, bottom: 16, trailing: 17)
                    ) {
                        VStack(alignment: .leading, spacing: 11) {
                            HStack(spacing: 9) {
                                Circle().fill(feasibility.color).shadow(color: feasibility.color, radius: 5).frame(width: 8, height: 8)
                                NoopSectionLabel(feasibility.kicker, color: feasibility.light)
                            }
                            Text(feasibility.body).font(NoopHTMLFont.sans(13.5)).foregroundStyle(Color(hex: 0xDCE3E0)).lineSpacing(4)
                            if let fix = feasibility.fix {
                                VStack(alignment: .leading, spacing: 7) {
                                    NoopSectionLabel("What the data would accept")
                                    Text(fix).font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.inkSoft).lineSpacing(3)
                                }.padding(12).background(NoopHTMLColor.canvas.opacity(0.4), in: RoundedRectangle(cornerRadius: 16))
                            }
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(NoopGoalEvidence.all) { evidence in
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack { Text(evidence.name).font(NoopHTMLFont.sans(12.5)); Spacer(); Text(evidence.value).font(.system(size: 11.5, weight: .semibold, design: .monospaced)) }
                                        NoopProgressBar(
                                            progress: evidence.progress * feasibility.factor,
                                            color: evidenceColor(for: evidence),
                                            height: 6
                                        )
                                        Text(evidence.note).font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.copy)
                                    }
                                }
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 5)
                        }
                    }

                    NoopHTMLCard(radius: 24, padding: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            NoopSectionLabel("Safety check", color: Color(hex: 0xF3C888))
                            Text(feasibility.safety).font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.inkSoft).lineSpacing(3)
                            Text("Noop will not build a route that adds more than ten percent of weekly load a week, and it will hold a week back rather than meet a date. If that means the date moves, it says the date moves.")
                                .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.copy).lineSpacing(3)
                        }
                    }

                    Button(feasibility.commitLabel) {
                        if feasibility.kind == .realistic { commit() } else { showCommitConfirmation = true }
                    }.buttonStyle(NoopGoalCommitStyle(primary: feasibility.kind == .realistic))

                    Text("One goal at a time, on purpose. A second one would compete with the first for the same nights of sleep, and the app would have to pretend it did not.")
                        .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(3).padding(.horizontal, 2)
                }
            }
            if showCommitConfirmation {
                NoopBottomSheet(title: "Commit anyway?", dismiss: { showCommitConfirmation = false }) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("The data does not support this date as written. Noop will save the goal, but it will keep its safety limits and say when the date has to move.")
                            .font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.copy).lineSpacing(4)
                        Button("Commit anyway") { showCommitConfirmation = false; commit() }
                            .buttonStyle(NoopHTMLButtonStyle(kind: .primary, fullWidth: true))
                        Button("Keep editing") { showCommitConfirmation = false }
                            .buttonStyle(NoopHTMLButtonStyle(kind: .quiet, fullWidth: true))
                    }
                }
            }
        }
    }

    private var feasibility: NoopGoalFeasibility {
        if selectedWeekIndex <= 1 { return .unrealistic }
        if selectedWeekIndex <= 3 { return .ambitious }
        return .realistic
    }
    private var selectedWeekIndex: Int { max(0, min(labels.count - 1, weekIndex)) }
    private func evidenceColor(for evidence: NoopGoalEvidence) -> Color {
        let value = evidence.progress * feasibility.factor
        if value > 0.7 { return NoopHTMLColor.green }
        if value > 0.5 { return NoopHTMLColor.warm }
        return Color(hex: 0xE9A288)
    }
    private func commit() {
        activeKind = navigation.selectedGoal.rawValue
        activeTitle = draftTitle
        let defaults = UserDefaults.standard
        let deadlineWeeks = [6, 8, 10, 12, 15, 16, 20, 22, 26, 35, 43, 52][selectedWeekIndex]
        let deadline = Calendar.current.date(byAdding: .weekOfYear, value: deadlineWeeks, to: Date())
        let kind: CoachGoal.Kind
        let baseline: Double?
        let target: Double?
        switch navigation.selectedGoal {
        case .distance:
            kind = .run
            baseline = 12
            switch defaults.string(forKey: "noop.html.goal.distance") ?? "Half marathon" {
            case "5K": target = 5
            case "10K": target = 10
            case "Marathon": target = 42.195
            default: target = 21.0975
            }
        case .pace:
            kind = .run
            baseline = nil
            target = nil
        case .sleep:
            kind = .consistency
            baseline = nil
            target = Double(defaults.string(forKey: "noop.html.goal.sleep-nights") ?? "5")
        case .composition:
            kind = (defaults.string(forKey: "noop.html.goal.composition-metric") ?? "Weight") == "Weight" ? .weight : .custom
            baseline = nil
            target = Double(defaults.string(forKey: "noop.html.goal.target-value") ?? "")
        }
        for existing in goalStore.activeGoals {
            goalStore.setAside(existing.id, reason: "Replaced by the new one-goal route")
        }
        let draft = CoachGoal(
            kind: kind,
            title: draftTitle,
            baseline: baseline,
            target: target,
            targetDate: deadline,
            history: [.init(date: Date(), what: "Set in the Noop Journey")]
        )
        let acknowledgement: CoachGoal.RiskAcknowledgement? = feasibility.kind == .realistic ? nil : .init(
            verdict: feasibility.kicker,
            reason: "Confirmed with Commit anyway",
            date: Date()
        )
        goalStore.commit(draft, acknowledgedRisk: acknowledgement)
        navigation.reset(to: .goal)
    }
}

/// The canonical Set screen remains intact; selecting a kind opens this HTML-styled editor for
/// the details that the static proof did not render.
struct NoopGoalEditorSheet: View {
    @ObservedObject var navigation: NoopNavigation
    @State private var activity = "Run"
    @State private var distance = "Half marathon"
    @State private var eventDistance = "10K"
    @State private var finishTime = "00:52:00"
    @State private var sleepAnchor = "23:00–07:00"
    @State private var sleepDrift = "±45 min"
    @State private var nights = "5"
    @State private var compositionMetric = "Weight"
    @State private var targetValue = "72"

    var body: some View {
        NoopBottomSheet(title: navigation.selectedGoal.rawValue, dismiss: navigation.dismissOverlay, showsDone: true) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch navigation.selectedGoal {
                    case .distance:
                        fieldPicker("Activity", selection: $activity, values: ["Run", "Ride", "Swim", "Walk"])
                        fieldPicker("Target distance", selection: $distance, values: ["5K", "10K", "Half marathon", "Marathon", "Custom"])
                    case .pace:
                        fieldPicker("Activity", selection: $activity, values: ["Run", "Ride", "Swim", "Walk"])
                        fieldPicker("Event distance", selection: $eventDistance, values: ["5K", "10K", "Half marathon", "Marathon", "Custom"])
                        textField("Target finish time", text: $finishTime, keyboard: .numbersAndPunctuation)
                        Text("Finish time and target pace stay linked.").font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.copy)
                    case .sleep:
                        textField("Target sleep window", text: $sleepAnchor)
                        fieldPicker("Acceptable drift", selection: $sleepDrift, values: ["±30 min", "±45 min", "±60 min"])
                        fieldPicker("Nights each week", selection: $nights, values: ["4", "5", "6", "7"])
                    case .composition:
                        fieldPicker("Metric", selection: $compositionMetric, values: ["Weight", "Waist", "Body fat"])
                        textField("Target value", text: $targetValue, keyboard: .decimalPad)
                        Text(compositionMetric == "Weight" ? "kg" : compositionMetric == "Waist" ? "cm" : "%")
                            .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy)
                    }
                    Text("Prefilled from your current profile and record. Every value remains editable.")
                        .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(3)
                    Button("Save goal details") { save() }
                        .buttonStyle(NoopHTMLButtonStyle(kind: .primary, fullWidth: true))
                }
            }.frame(maxHeight: 470)
        }
        .task { load() }
    }

    private func fieldPicker(_ label: String, selection: Binding<String>, values: [String]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy)
            Picker(label, selection: selection) { ForEach(values, id: \.self) { Text($0).tag($0) } }
                .pickerStyle(.menu).tint(NoopHTMLColor.ink)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 48)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 15))
        }
    }
    private func textField(_ label: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy)
            TextField(label, text: text).keyboardType(keyboard).font(NoopHTMLFont.sans(13.5)).padding(.horizontal, 14).frame(height: 48)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.11), lineWidth: 0.5))
        }
    }
    private func load() {
        let defaults = UserDefaults.standard
        activity = defaults.string(forKey: "noop.html.goal.activity") ?? "Run"
        distance = defaults.string(forKey: "noop.html.goal.distance") ?? "Half marathon"
        eventDistance = defaults.string(forKey: "noop.html.goal.event-distance") ?? "10K"
        finishTime = defaults.string(forKey: "noop.html.goal.finish-time") ?? "00:52:00"
        sleepAnchor = defaults.string(forKey: "noop.html.goal.sleep-anchor") ?? "23:00–07:00"
        sleepDrift = defaults.string(forKey: "noop.html.goal.sleep-drift") ?? "±45 min"
        nights = defaults.string(forKey: "noop.html.goal.sleep-nights") ?? "5"
        compositionMetric = defaults.string(forKey: "noop.html.goal.composition-metric") ?? "Weight"
        targetValue = defaults.string(forKey: "noop.html.goal.target-value") ?? "72"
    }
    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(activity, forKey: "noop.html.goal.activity")
        defaults.set(distance, forKey: "noop.html.goal.distance")
        defaults.set(eventDistance, forKey: "noop.html.goal.event-distance")
        defaults.set(finishTime, forKey: "noop.html.goal.finish-time")
        defaults.set(sleepAnchor, forKey: "noop.html.goal.sleep-anchor")
        defaults.set(sleepDrift, forKey: "noop.html.goal.sleep-drift")
        defaults.set(nights, forKey: "noop.html.goal.sleep-nights")
        defaults.set(compositionMetric, forKey: "noop.html.goal.composition-metric")
        defaults.set(targetValue, forKey: "noop.html.goal.target-value")
        let title: String
        switch navigation.selectedGoal {
        case .distance: title = "\(distance) \(activity.lowercased()), finishing comfortably."
        case .pace: title = "\(eventDistance) \(activity.lowercased()) in \(finishTime)."
        case .sleep: title = "Sleep inside \(sleepAnchor), \(nights) nights each week."
        case .composition: title = "\(compositionMetric) at \(targetValue) \(compositionMetric == "Weight" ? "kg" : compositionMetric == "Waist" ? "cm" : "%")."
        }
        defaults.set(title, forKey: "noop.html.goal-draft-title")
        navigation.dismissOverlay()
    }
}

// MARK: - Biomarkers

private struct NoopLabsHome: View {
    @ObservedObject var navigation: NoopNavigation
    private var markers: [NoopLabMarker] { NoopLabMarker.all }
    private var inBandCount: Int { markers.filter { !$0.isOutside }.count }
    private var outOfBandLine: String {
        switch markers.count - inBandCount {
        case 0: "every marker inside the lab\u{2019}s band"
        case 1: "one marker outside the lab\u{2019}s band"
        case let count: "\(count) markers outside the lab\u{2019}s band"
        }
    }
    var body: some View {
        NoopScreen(bottomInset: 118, topInset: 56) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 12) {
                    Button { navigation.reset(to: .goal) } label: {
                        ZStack {
                            Circle().fill(Color.white.opacity(0.06))
                                .overlay(Circle().stroke(NoopHTMLColor.borderStrong, lineWidth: 0.5))
                            NoopFixedChevron(direction: .left, color: NoopHTMLColor.inkSoft).offset(x: -1)
                        }
                        .frame(width: 34, height: 34)
                    }.buttonStyle(.plain)
                    Text("You").font(NoopHTMLFont.sans(13.5)).foregroundStyle(NoopHTMLColor.copy)
                    Spacer()
                    Button("Enter results") { navigation.push(.review) }.buttonStyle(NoopGoalWarmButtonStyle())
                }
                .padding(.horizontal, -2)
                HStack { NoopSectionLabel("Biomarkers"); Spacer(); Text("drawn 14 August · Karolinska").font(NoopHTMLFont.sans(10.5)).foregroundStyle(NoopHTMLColor.faint) }.padding(.top, 8)
                NoopHelixHero(markers: markers.map { NoopHelixMarker(id: $0.id, outOfBand: $0.isOutside) })
                    .padding(.top, 6)

                // The helix has no centre to hold the count, so the reading sits under it: the
                // numeral on the left, the caption naming what a rung is on the right.
                HStack(alignment: .bottom, spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(inBandCount)")
                                .font(NoopHTMLFont.outfit200(38))
                                .tracking(-1.71)
                                .monospacedDigit()
                            Text("of \(markers.count) in band")
                                .font(NoopHTMLFont.sans(12))
                                .foregroundStyle(Color(hex: 0x7F8A85))
                                .fixedSize()
                        }
                        Text(outOfBandLine)
                            .font(NoopHTMLFont.sans(10.5))
                            .foregroundStyle(NoopHTMLColor.faint)
                            .fixedSize()
                    }
                    Spacer(minLength: 0)
                    Text("each rung is one marker")
                        .font(NoopHTMLFont.sans(10.5))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .multilineTextAlignment(.trailing)
                        .lineSpacing(3)
                }

                VStack(spacing: 0) {
                    ForEach(Array(markers.enumerated()), id: \.offset) { index, marker in
                        Button {
                            navigation.selectedMarker = marker.name
                            navigation.push(.marker)
                        } label: {
                            HStack(spacing: 12) {
                                Circle().fill(marker.color).shadow(color: marker.color, radius: 5).frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(marker.name).font(NoopHTMLFont.sans(13.5))
                                    Text("band \(marker.rangeText) · 14 Aug").font(NoopHTMLFont.sans(11)).foregroundStyle(Color(hex: 0x7F8A85))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                VStack(alignment: .trailing, spacing: 2) {
                                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        Text(marker.valueText).font(NoopHTMLFont.outfit(20, weight: .light))
                                        Text(marker.unit).font(NoopHTMLFont.sans(11)).foregroundStyle(Color(hex: 0x7F8A85))
                                    }
                                    Text(marker.bandTag)
                                        .font(NoopHTMLFont.sans(10.5, weight: .semibold))
                                        .foregroundStyle(marker.isOutside ? Color(hex: 0xF6DCB4) : NoopHTMLColor.copy)
                                }
                                NoopFixedChevron(direction: .right, color: NoopHTMLColor.faint)
                            }
                            .frame(minHeight: 62)
                            .padding(.vertical, 13)
                        }
                        .buttonStyle(.plain)
                        if index < markers.count - 1 { Divider().overlay(NoopHTMLColor.border) }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(NoopHTMLColor.border, lineWidth: 0.5))
                .padding(.top, 10)

                NoopHTMLCard(radius: 24, padding: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        NoopSectionLabel("Not measured here")
                        Text("Nothing on this screen came off the strap. These are numbers you or your clinic entered, kept beside the wearable data so they can be read together — and dated, because a ferritin from March is not a fact about today.")
                            .font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.copy).lineSpacing(4)
                    }
                }
                .padding(.top, 10)
                Text("Reference bands are the laboratory's, not a target. Out of range is a reason to ask someone, not a verdict — and Noop will not tell you what to do about a blood test.")
                    .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(3)
                    .padding(.horizontal, 2)
                    .padding(.top, 6)
            }
        }
    }
}

private struct NoopLabReview: View {
    @ObservedObject var navigation: NoopNavigation
    @EnvironmentObject private var repo: Repository
    @State private var candidates = NoopOCRCandidate.samples
    @State private var errorID: String?
    @State private var saving = false
    @State private var saveError: String?

    var body: some View {
        NoopScreen(bottomInset: 150, topInset: 56) {
            VStack(alignment: .leading, spacing: 12) {
                NoopBackHeader(label: "Biomarkers") { navigation.reset(to: .labs) }
                    .padding(.horizontal, -2)
                    .padding(.bottom, -14)
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        NoopSectionLabel("Nothing is stored yet", color: Color(hex: 0xF3C888)); Spacer()
                        NoopPill(text: "read, not measured", color: Color(hex: 0xF3C888))
                    }
                    Text("Four candidates were read off your photo. Confirm the ones that are right.")
                        .font(NoopHTMLFont.outfit(25, weight: .light)).tracking(-0.7).lineSpacing(2)
                    Text("Read on this phone, nothing uploaded. Check each number against your report, fix anything misread, and discard what you would rather not keep.")
                        .font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.copy).lineSpacing(4)
                }
                .padding(.top, -10)
                if let saveError {
                    Text(saveError)
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(NoopHTMLColor.red)
                        .lineSpacing(3)
                }

                VStack(spacing: 11) {
                    ForEach($candidates) { $candidate in
                        NoopOCRCandidateCard(candidate: $candidate, error: errorID == candidate.id ? "Enter a known marker, numeric value and compatible unit." : nil) {
                            if validate(candidate) { candidate.status = .corrected; candidate.editing = false; errorID = nil }
                            else { errorID = candidate.id }
                        }
                    }
                }

                NoopHTMLCard(radius: 24, padding: 16) {
                    VStack(alignment: .leading, spacing: 9) {
                        NoopSectionLabel("What happens to the file")
                        NoopLabFileFact("The photo and the text read from it are deleted when you leave this screen, whatever you decide.")
                        NoopLabFileFact("Discarded rows are not remembered — not as a value, and not as “you declined this”.")
                        NoopLabFileFact("Nothing was uploaded. The read happened on this phone, and it is the one part of the app that would rather be slow than remote.")
                    }
                }
            }
        }
        // Keep the fixed action bar out of the scroll view's layout calculation. As a ZStack
        // sibling its intrinsic width expands the root and the bar overhangs the screen —
        // the same trap Act 7's composer documents.
        .overlay(alignment: .bottom) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(confirmedCount == 0 ? "Nothing confirmed yet" : "\(confirmedCount) \(confirmedCount == 1 ? "result" : "results") will be stored")
                        .font(NoopHTMLFont.sans(12.5, weight: .semibold))
                    Text("\(pendingCount) still to check · \(discardedCount) discarded").font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.copy)
                }
                Spacer()
                Button(saving ? "Saving…" : "Save") { Task { await save() } }
                    .font(NoopHTMLFont.sans(13, weight: .semibold))
                    .foregroundStyle(confirmedCount > 0 ? Color(hex: 0x1E1405) : NoopHTMLColor.faint)
                    .padding(.horizontal, 20).frame(height: 40)
                    .background(confirmedCount > 0 ? Color(hex: 0xF2B45C) : Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 13))
                    .disabled(confirmedCount == 0 || saving)
            }
            .padding(.horizontal, 16).frame(height: 64)
            .background(Color(hex: 0x171C1A, alpha: 0.92), in: RoundedRectangle(cornerRadius: 22))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.45), radius: 13, y: 8)
            .padding(.horizontal, 14).padding(.bottom, 82)
        }
        .onDisappear(perform: scrubDraft)
    }

    private var confirmedCount: Int { candidates.filter { $0.status == .confirmed || $0.status == .corrected }.count }
    private var discardedCount: Int { candidates.filter { $0.status == .discarded }.count }
    private var pendingCount: Int { candidates.filter { $0.status == .pending }.count }
    private func validate(_ candidate: NoopOCRCandidate) -> Bool {
        let known = NoopLabMarker.definitions.first { $0.name.caseInsensitiveCompare(candidate.draftName.trimmingCharacters(in: .whitespaces)) == .orderedSame }
        let numeric = Double(candidate.draftValue.replacingOccurrences(of: ",", with: ".")) != nil
        return known?.unit == candidate.draftUnit.trimmingCharacters(in: .whitespaces) && numeric
    }
    @MainActor
    private func save() async {
        guard confirmedCount > 0, !saving else { return }
        saving = true
        saveError = nil
        let confirmed = candidates.filter { $0.status == .confirmed || $0.status == .corrected }
        guard let store = await repo.storeHandle() else {
            saving = false
            saveError = "Couldn’t open the local Lab Book. Nothing was saved."
            return
        }

        let day = "2026-08-14"
        let epoch = LabBookFormat.noonEpoch(day)
        let rows = confirmed.compactMap { candidate -> LabMarkerRow? in
            let enteredName = candidate.status == .corrected ? candidate.draftName.trimmingCharacters(in: .whitespaces) : candidate.name
            let name = NoopLabMarker.definitions.first { $0.name.caseInsensitiveCompare(enteredName) == .orderedSame }?.name ?? enteredName
            let rawValue = candidate.status == .corrected ? candidate.draftValue : candidate.value
            guard let value = Double(rawValue.replacingOccurrences(of: ",", with: ".")),
                  let storage = labStorage(for: name) else { return nil }
            return LabMarkerRow(
                id: "\(storage.key)-\(epoch)-\(UUID().uuidString.prefix(8))",
                deviceId: repo.deviceId,
                markerKey: storage.key,
                category: storage.category.rawValue,
                day: day,
                takenAt: epoch,
                value: value,
                valueText: nil,
                unit: candidate.status == .corrected ? candidate.draftUnit.trimmingCharacters(in: .whitespaces) : candidate.unit,
                source: LabReportTextImport.sourceId,
                note: nil,
                referenceText: nil
            )
        }
        guard rows.count == confirmed.count else {
            saving = false
            saveError = "One confirmed row could not be read as a known marker and numeric value. Nothing was saved."
            return
        }

        do {
            try await store.upsertLabMarkers(rows)
            let defaults = UserDefaults.standard
            for candidate in confirmed {
                let enteredName = candidate.status == .corrected ? candidate.draftName.trimmingCharacters(in: .whitespaces) : candidate.name
                let name = NoopLabMarker.definitions.first { $0.name.caseInsensitiveCompare(enteredName) == .orderedSame }?.name ?? enteredName
                let value = candidate.status == .corrected ? candidate.draftValue : candidate.value
                defaults.set(value.replacingOccurrences(of: ",", with: "."), forKey: "noop.html.marker.\(name).value")
            }
            defaults.set("14 August", forKey: "noop.html.last-lab-draw")
            await repo.refresh()
            scrubDraft()
            if navigation.route == .review { navigation.replace(with: .labs) }
        } catch {
            saveError = "Couldn’t save these readings to the local Lab Book. Nothing was changed."
        }
        saving = false
    }

    private func labStorage(for name: String) -> (key: String, category: LabMarkerCategory)? {
        switch name.lowercased() {
        case "ferritin": ("ferritin", .bloodPanel)
        case "vitamin d": ("vitamin_d", .bloodPanel)
        case "apob": ("custom_apob", .other)
        case "hs-crp": ("crp", .bloodPanel)
        case "hba1c": ("hba1c", .bloodPanel)
        case "tsh": ("tsh", .bloodPanel)
        case "alt": ("alt", .bloodPanel)
        default: nil
        }
    }

    private func scrubDraft() {
        candidates = NoopOCRCandidate.samples
        errorID = nil
        saveError = nil
    }
}

private struct NoopOCRCandidateCard: View {
    @Binding var candidate: NoopOCRCandidate
    let error: String?
    let saveCorrection: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2.5) {
                    Text(candidate.shownName).font(NoopHTMLFont.sans(13.5))
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(candidate.shownValue).font(NoopHTMLFont.outfit(30, weight: .light))
                        Text(candidate.shownUnit).font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color(hex: 0x7F8A85))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 5) {
                    Text(candidate.raw)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(hex: 0x17150F))
                        .lineLimit(1)
                        .frame(width: 156, height: 34)
                        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 9))
                    Text("AS READ")
                        .font(NoopHTMLFont.sans(9.5, weight: .semibold))
                        .tracking(0.95)
                        .foregroundStyle(NoopHTMLColor.faint)
                }
            }
            if candidate.editing {
                VStack(alignment: .leading, spacing: 9) {
                    TextField("Marker", text: $candidate.draftName)
                    HStack(spacing: 8) {
                        TextField("Value", text: $candidate.draftValue).keyboardType(.decimalPad)
                        TextField("Unit", text: $candidate.draftUnit).frame(width: 105)
                    }
                    if let error { Text(error).font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.red) }
                    HStack(spacing: 7) {
                        Button("Save correction", action: saveCorrection).buttonStyle(NoopOCRActionStyle(primary: true))
                        Button("Cancel") { candidate.editing = false }.buttonStyle(NoopOCRActionStyle())
                    }
                }
                .textFieldStyle(NoopOCRTextFieldStyle())
            } else if candidate.status == .pending {
                // Approved native correction: the proof varies these controls between rows.
                // Keep one 40pt height/radius system; only Confirm receives extra width/emphasis.
                GeometryReader { proxy in
                    let unit = max(0, proxy.size.width - 14) / 3.3
                    HStack(spacing: 7) {
                        Button("Confirm") { candidate.status = .confirmed }
                            .buttonStyle(NoopOCRActionStyle(primary: true))
                            .frame(width: unit * 1.3)
                        Button("Fix") {
                            candidate.draftName = candidate.name
                            candidate.draftValue = candidate.value
                            candidate.draftUnit = candidate.unit
                            candidate.editing = true
                        }
                        .buttonStyle(NoopOCRActionStyle())
                        .frame(width: unit)
                        Button("Discard") { candidate.status = .discarded }
                            .buttonStyle(NoopOCRActionStyle())
                            .frame(width: unit)
                    }
                }
                .frame(height: 40)
            } else {
                HStack {
                    Text(candidate.status.message).font(NoopHTMLFont.sans(12)).foregroundStyle(NoopHTMLColor.inkSoft)
                    Spacer()
                    Button("Undo") { candidate.status = .pending }
                        .font(NoopHTMLFont.sans(11.5, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xF6DCB4))
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 40)
                .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.09), lineWidth: 0.5))
            }
        }
        .padding(EdgeInsets(top: 15, leading: 16, bottom: 16, trailing: 16))
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(candidate.lowConfidence ? Color(hex: 0xF3C888).opacity(0.34) : Color.white.opacity(0.07), lineWidth: 0.5)
        }
    }
}

private struct NoopMarkerDetail: View {
    @ObservedObject var navigation: NoopNavigation
    private var marker: NoopLabMarker { NoopLabMarker.all.first { $0.name == navigation.selectedMarker } ?? NoopLabMarker.all[0] }
    var body: some View {
        NoopScreen(bottomInset: 118, topInset: 56) {
            VStack(alignment: .leading, spacing: 12) {
                NoopBackHeader(label: "Biomarkers") { navigation.reset(to: .labs) }
                    .padding(.horizontal, -2)
                    .padding(.bottom, -14)
                VStack(alignment: .leading, spacing: 0) {
                    Text(marker.name).font(NoopHTMLFont.outfit(25, weight: .regular)).tracking(-0.6)
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Text(marker.valueText).font(NoopHTMLFont.outfit200(54)).tracking(-2.4)
                        Text(marker.unit).font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.copy)
                        NoopPill(text: marker.detailBandTag, color: marker.color)
                    }
                    Text(marker.readCopy).font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.copy).lineSpacing(4)
                }

                NoopHTMLCard(radius: 24, padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { NoopSectionLabel("Four draws"); Spacer(); Text("shaded — the lab's band").font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.faint) }
                        NoopMarkerTrend(marker: marker)
                        HStack { Text("Jun 25"); Spacer(); Text("Nov 25"); Spacer(); Text("Mar 26"); Spacer(); Text("14 Aug") }
                            .font(NoopHTMLFont.sans(10.5)).foregroundStyle(NoopHTMLColor.faint)
                        Text(marker.bandNote)
                            .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.copy).lineSpacing(3)
                    }
                    .padding(.bottom, 5)
                }
                .padding(.top, 6)

                NoopHTMLCard(radius: 24, padding: 16) {
                    VStack(alignment: .leading, spacing: 11) {
                        NoopSectionLabel("What it sits next to")
                        NoopMarkerBeside("Haemoglobin, same draw", "141 g/L")
                        NoopMarkerBeside("Weekly distance that month", "34 km")
                        NoopMarkerBeside("Nights over your need, that month", "17 of 31")
                        Text("Shown together because they were drawn on the same day, not because Noop found a relationship. It has four points — that is not enough to claim one.")
                            .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.copy).lineSpacing(3)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    NoopSectionLabel("Worth a retest", color: Color(hex: 0xF3C888))
                    Text(marker.retestCopy)
                        .font(NoopHTMLFont.sans(12.5))
                        .foregroundStyle(Color(hex: 0xDCE3E0))
                        .lineSpacing(4)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(NoopHTMLColor.warm.opacity(0.08), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(NoopHTMLColor.warm.opacity(0.26), lineWidth: 0.5))
                Text("Entered by you, from a laboratory report. Noop stores and dates it, draws it against the band the lab gave, and stops there — it is not a diagnosis and not advice.")
                    .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(3)
                    .padding(.horizontal, 2)
                    .padding(.top, -10)
            }
        }
    }
}

// MARK: - Act 8 data and components

private struct NoopGoalWaypoint { let title: String; let detail: String; let tag: String; let done: Bool }
private struct NoopGoalEvidence: Identifiable {
    let id: String; let name: String; let value: String; let note: String; let progress: Double
    static let all: [NoopGoalEvidence] = [
        .init(id: "long", name: "Longest run this year", value: "12 km", note: "the route needs 18 km on the way", progress: 0.66),
        .init(id: "week", name: "Weekly distance now", value: "34 km", note: "the route peaks at 55 km", progress: 0.62),
        .init(id: "time", name: "Weeks available", value: "11", note: "a gentle build wants 14", progress: 0.78)
    ]
}
private enum NoopGoalFeasibilityKind { case realistic, ambitious, unrealistic }
private struct NoopGoalFeasibility {
    let kind: NoopGoalFeasibilityKind; let kicker: String; let body: String; let fix: String?; let safety: String; let commitLabel: String; let color: Color; let light: Color; let factor: Double
    static let realistic = NoopGoalFeasibility(kind: .realistic, kicker: "The data says yes", body: "Twelve kilometres at 6:04 with heart rate under 150, on 34 km a week and eleven weeks left. The route asks for 55 km at peak, which is a 9% build — inside what your sleep has been absorbing.", fix: nil, safety: "Two easy weeks are written into the route on purpose, and a poor run of sleep moves the next hard week rather than deleting it.", commitLabel: "Keep this route", color: NoopHTMLColor.green, light: Color(hex: 0x8FEFC0), factor: 1)
    static let ambitious = NoopGoalFeasibility(kind: .ambitious, kicker: "Possible, with one condition", body: "The distance is there but the build is steep. The selected date asks for more than your last two blocks absorbed without a poor night.", fix: "Move the date later, or hold the peak lower and take the day slower. The distance is not the risk; the ramp is.", safety: "The saved route keeps the weekly load ceiling even when the date asks for more.", commitLabel: "Commit anyway", color: Color(hex: 0xF2B45C), light: Color(hex: 0xF6DCB4), factor: 0.84)
    static let unrealistic = NoopGoalFeasibility(kind: .unrealistic, kicker: "The data says not by then", body: "Your longest run and the selected date would require a weekly build above every block your sleep has absorbed this year.", fix: "Choose a later date or a shorter event. Both make a route Noop can actually build.", safety: "Noop will not build above its safety ceiling. It will save the goal only after confirmation and say when the date has to move.", commitLabel: "Commit anyway", color: Color(hex: 0xE9A288), light: Color(hex: 0xF0BBA6), factor: 0.62)
}

private struct NoopLabMarker: Identifiable {
    let id: String; let name: String; let unit: String; let low: Double; let high: Double; let defaultValue: Double; let trend: [Double]; let trendText: String; let contextCopy: String
    var value: Double {
        if NoopContentPolicy.allowsPrototypeContent { return defaultValue }
        return Double(UserDefaults.standard.string(forKey: "noop.html.marker.\(name).value") ?? "") ?? defaultValue
    }
    var isOutside: Bool { value < low || value > high }
    var color: Color { isOutside ? Color(hex: 0xF2B45C) : NoopHTMLColor.green }
    var valueText: String { value.formatted(.number.precision(.fractionLength(0...2))) }
    var rangeText: String { "\(number(low))–\(number(high)) \(unit)" }
    var bandTag: String { value < low ? "below band" : value > high ? "above band" : "in band" }
    var detailBandTag: String { value < low ? "below the band" : value > high ? "above the band" : "in the band" }
    var series: [Double] {
        let slope: Double
        switch id {
        case "ferritin": slope = 1.5
        case "vitamin-d": slope = 1.42
        case "apob": slope = 1.14
        case "hs-crp": slope = 1.7
        case "hba1c": slope = 1.06
        case "tsh": slope = 1.12
        case "alt": slope = 0.84
        default: slope = 1.2
        }
        return [3, 2, 1, 0].map { back in
            guard back > 0 else { return value }
            let factor = 1 + (slope - 1) * (Double(back) / 3)
            return (value * factor * 100).rounded() / 100
        }
    }
    var trendDirection: String {
        guard let first = series.first, let last = series.last else { return "not yet a trend" }
        let threshold = max(0.01, abs(first) * 0.03)
        if last < first - threshold { return "lower across these four dated draws" }
        if last > first + threshold { return "higher across these four dated draws" }
        return "broadly stable across these four dated draws"
    }
    var readCopy: String {
        let note = htmlNote
        return "Four draws in fourteen months. \(note.prefix(1).uppercased())\(note.dropFirst())."
    }
    var htmlNote: String {
        switch id {
        case "ferritin": return isOutside ? "under the band, and the one worth asking about" : "inside, at the low end of a very wide band"
        case "vitamin-d": return isOutside ? "under the band, which for August is early" : "inside, in August — it falls by February"
        case "apob": return isOutside ? "over the band, and the first thing a clinician would look at" : "comfortably inside"
        case "hs-crp": return isOutside ? "over the band — worth repeating before reading anything into it" : "low, which is where you want it"
        case "hba1c": return isOutside ? "over the band" : "inside, and stable across four draws"
        case "tsh": return isOutside ? "over the band" : "inside"
        case "alt": return isOutside ? "over the band, in a hard training block" : "inside, and it moves with hard training weeks"
        default: return bandTag
        }
    }
    var chartMinimum: Double { (series + [low]).min()! * 0.86 }
    var chartMaximum: Double { (series + [low]).max()! * 1.14 }
    var bandNote: String {
        let topVisible = high <= chartMaximum
        let bottomVisible = low >= chartMinimum
        if topVisible && bottomVisible {
            return "The shaded area is the band the laboratory gave: \(number(low)) to \(number(high)) \(unit)."
        }
        if topVisible {
            return "The shaded area is the laboratory’s band. Its lower limit, \(number(low)) \(unit), sits below this scale."
        }
        return "The shaded area is the laboratory’s band from \(number(low)) \(unit) upward. Its upper limit, \(number(high)) \(unit), is far off this scale and is not drawn."
    }
    var retestCopy: String {
        if id == "ferritin" && isOutside {
            return "A single low ferritin inside a training block is common and not conclusive. The usual advice is a repeat draw in eight to twelve weeks — 9 November is the earliest that would tell you anything new."
        }
        if !isOutside {
            return "Nothing here asks for a retest before your next routine draw. Noop will keep this dated result beside the next one."
        }
        return "A single out-of-band result is not conclusive. Ask a clinician whether and when a repeat draw would be useful."
    }
    var dynamicContextCopy: String {
        let position = value < low ? "below" : value > high ? "above" : "inside"
        let markerFact: String
        switch id {
        case "vitamin-d": markerFact = "The draw is dated August; Noop does not assume a seasonal cause."
        case "hs-crp": markerFact = "Noop does not attach an inflammatory cause to a single value."
        case "hba1c": markerFact = "Noop records the dated series without turning it into a metabolic conclusion."
        case "tsh": markerFact = "Interpretation depends on clinical context Noop does not have."
        case "alt": markerFact = "Noop does not attribute the change to training or anything else."
        case "apob": markerFact = "Noop records the laboratory comparison and makes no treatment claim."
        default: markerFact = "Noop records the dated value and does not infer a cause."
        }
        return "\(name) is \(position) the laboratory’s band and is \(trendDirection). \(markerFact) One result is not a diagnosis; discuss it with a clinician if you want it interpreted."
    }
    private func number(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0...2))) }

    static let definitions: [NoopLabMarker] = [
        .init(id: "ferritin", name: "Ferritin", unit: "µg/L", low: 30, high: 400, defaultValue: 28, trend: [42, 38, 33, 28], trendText: "lower across these four dated draws", contextCopy: "This result is below the laboratory’s band. One result is not a diagnosis; discuss the dated value and its downward trend with a clinician if you want it interpreted."),
        .init(id: "vitamin-d", name: "Vitamin D", unit: "nmol/L", low: 50, high: 125, defaultValue: 44, trend: [63, 58, 51, 44], trendText: "lower across these four dated draws", contextCopy: "This result is below the laboratory’s band. Seasonal timing can matter, but Noop does not infer a cause; a clinician can interpret the value in context."),
        .init(id: "apob", name: "ApoB", unit: "g/L", low: 0.5, high: 1.0, defaultValue: 0.78, trend: [0.88, 0.84, 0.8, 0.78], trendText: "slightly lower than the previous draw", contextCopy: "This result is inside the laboratory’s band and slightly lower than the prior draw. Noop records that fact and makes no treatment claim."),
        .init(id: "hs-crp", name: "hs-CRP", unit: "mg/L", low: 0, high: 3, defaultValue: 0.6, trend: [1.1, 0.8, 0.7, 0.6], trendText: "lower across the four draws", contextCopy: "This result is inside the laboratory’s band. A single inflammatory marker is not a diagnosis, and Noop does not attach a cause to it."),
        .init(id: "hba1c", name: "HbA1c", unit: "mmol/mol", low: 20, high: 42, defaultValue: 33, trend: [34, 33, 33, 33], trendText: "stable across the four draws", contextCopy: "This result is inside the laboratory’s band and stable across these dated draws. Noop does not turn that into a clinical conclusion."),
        .init(id: "tsh", name: "TSH", unit: "mIU/L", low: 0.4, high: 4, defaultValue: 2.1, trend: [2.4, 2.2, 2.2, 2.1], trendText: "close to the preceding values", contextCopy: "This result is inside the laboratory’s band and close to the preceding values. Interpretation belongs with the clinical context Noop does not have."),
        .init(id: "alt", name: "ALT", unit: "U/L", low: 10, high: 50, defaultValue: 41, trend: [35, 38, 44, 41], trendText: "below the preceding draw", contextCopy: "This result is inside the laboratory’s band and below the preceding draw. Noop shows the dated series without attributing the change to training or anything else.")
    ]
    static var all: [NoopLabMarker] { definitions }
}

private enum NoopOCRStatus { case pending, confirmed, corrected, discarded
    var message: String { switch self { case .confirmed: "Will be stored, dated 14 August"; case .corrected: "Corrected by hand — stored as you entered it"; case .discarded: "Discarded. Not stored, and the file is not kept either"; case .pending: "" } }
}
private struct NoopOCRCandidate: Identifiable {
    // `confidence` and `lowConfidence` are not rendered on the interim path — nothing was read off a
    // photo, so there is no confidence to report. They return with Change 7 piece 1, together with
    // the source rect the per-row strip is cut from.
    let id: String; let name: String; let value: String; let unit: String; let raw: String; let confidence: String; let lowConfidence: Bool
    var status: NoopOCRStatus = .pending; var editing = false; var draftName = ""; var draftValue = ""; var draftUnit = ""
    var shownName: String { status == .corrected ? draftName : name }
    var shownValue: String { status == .corrected ? draftValue : value }
    var shownUnit: String { status == .corrected ? draftUnit : unit }
    static let samples = [
        NoopOCRCandidate(id: "ferritin", name: "Ferritin", value: "28", unit: "µg/L", raw: "Ferritin  28 µg/L", confidence: "clear read", lowConfidence: false),
        NoopOCRCandidate(id: "vitamin-d", name: "Vitamin D", value: "52", unit: "nmol/L", raw: "25-OH-D  52", confidence: "clear read", lowConfidence: false),
        NoopOCRCandidate(id: "apob", name: "ApoB", value: "0.78", unit: "g/L", raw: "ApoB  O.78 g/L", confidence: "low confidence — the O may be a zero", lowConfidence: true),
        NoopOCRCandidate(id: "hs-crp", name: "hs-CRP", value: "0.6", unit: "mg/L", raw: "hsCRP  <0,6", confidence: "low confidence — the page says “less than”", lowConfidence: true)
    ]
}

private struct NoopMarkerTrend: View {
    let marker: NoopLabMarker
    var body: some View {
        Canvas { context, size in
            let minValue = marker.chartMinimum
            let maxValue = marker.chartMaximum
            let span = max(0.001, maxValue - minValue)
            func y(_ value: Double) -> CGFloat { CGFloat((maxValue - value) / span) * size.height }
            let topVisible = marker.high <= maxValue
            let bottomVisible = marker.low >= minValue
            let bandTop = topVisible ? y(marker.high) : 0
            let bandBottom = bottomVisible ? y(marker.low) : size.height
            context.fill(
                Path(CGRect(x: 0, y: bandTop, width: size.width, height: max(2, bandBottom - bandTop))),
                with: .color(NoopHTMLColor.green.opacity(0.10))
            )
            if topVisible {
                var boundary = Path()
                boundary.move(to: CGPoint(x: 0, y: bandTop))
                boundary.addLine(to: CGPoint(x: size.width, y: bandTop))
                context.stroke(boundary, with: .color(NoopHTMLColor.green.opacity(0.32)), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
            }
            if bottomVisible {
                var boundary = Path()
                boundary.move(to: CGPoint(x: 0, y: bandBottom))
                boundary.addLine(to: CGPoint(x: size.width, y: bandBottom))
                context.stroke(boundary, with: .color(NoopHTMLColor.green.opacity(0.32)), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
            }

            var line = Path()
            var points: [CGPoint] = []
            for (index, value) in marker.series.enumerated() {
                let point = CGPoint(x: CGFloat(index) / CGFloat(marker.series.count - 1) * size.width, y: y(value))
                index == 0 ? line.move(to: point) : line.addLine(to: point)
                points.append(point)
            }
            context.stroke(line, with: .color(Color(hex: 0xF2B45C)), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

            for point in points {
                let dot = Path(ellipseIn: CGRect(x: point.x - 3.6, y: point.y - 3.6, width: 7.2, height: 7.2))
                context.fill(dot, with: .color(NoopHTMLColor.canvas))
                context.stroke(dot, with: .color(Color(hex: 0xF2B45C)), lineWidth: 2)
            }
        }.frame(height: 118)
    }
}

private struct NoopMarkerBeside: View {
    let label: String; let value: String
    init(_ label: String, _ value: String) { self.label = label; self.value = value }
    var body: some View { HStack(alignment: .firstTextBaseline) { Text(label).font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.inkSoft); Spacer(); Text(value).font(.system(size: 11.5, weight: .semibold, design: .monospaced)) } }
}
private struct NoopLabFileFact: View {
    let text: String; init(_ text: String) { self.text = text }
    var body: some View { HStack(alignment: .top, spacing: 10) { Circle().fill(Color(hex: 0xF2B45C)).frame(width: 5, height: 5).padding(.top, 6); Text(text).font(NoopHTMLFont.sans(12)).foregroundStyle(NoopHTMLColor.copy).lineSpacing(3) } }
}

private struct NoopOCRTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View { configuration.font(NoopHTMLFont.sans(13)).padding(.horizontal, 12).frame(height: 44).background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 13)).overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.white.opacity(0.11), lineWidth: 0.5)) }
}
private struct NoopOCRActionStyle: ButtonStyle {
    var primary = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(NoopHTMLFont.sans(12.5, weight: .semibold))
            .foregroundStyle(primary ? NoopHTMLColor.warmInk : NoopHTMLColor.inkSoft)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(primary ? NoopHTMLColor.warm : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 13))
            .overlay {
                RoundedRectangle(cornerRadius: 13)
                    .stroke(primary ? Color.clear : Color.white.opacity(0.10), lineWidth: 0.5)
            }
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}
private struct NoopGoalActionStyle: ButtonStyle {
    var primary = false
    func makeBody(configuration: Configuration) -> some View { configuration.label.font(NoopHTMLFont.sans(12.5, weight: .semibold)).foregroundStyle(primary ? Color(hex: 0x1E1405) : NoopHTMLColor.inkSoft).frame(maxWidth: .infinity).frame(height: 42).background(primary ? Color(hex: 0xF2B45C) : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(primary ? .clear : Color.white.opacity(0.1), lineWidth: 0.5)).opacity(configuration.isPressed ? 0.82 : 1) }
}
private struct NoopAct8WeekActionStyle: ButtonStyle {
    let primary: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(NoopHTMLFont.sans(12.5, weight: .semibold))
            .foregroundStyle(primary ? Color(hex: 0x0C1024) : NoopHTMLColor.inkSoft)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(primary ? NoopHTMLColor.night : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(primary ? Color.clear : Color.white.opacity(0.1), lineWidth: 0.5)
            }
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}
private struct NoopGoalCommitStyle: ButtonStyle {
    let primary: Bool
    func makeBody(configuration: Configuration) -> some View { configuration.label.font(NoopHTMLFont.sans(14, weight: .semibold)).foregroundStyle(primary ? Color(hex: 0x1E1405) : NoopHTMLColor.inkSoft).frame(maxWidth: .infinity).frame(height: 52).background(primary ? Color(hex: 0xF2B45C) : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(primary ? .clear : Color.white.opacity(0.14), lineWidth: 0.5)).opacity(configuration.isPressed ? 0.82 : 1) }
}
private struct NoopGoalWarmButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label.font(NoopHTMLFont.sans(11.5, weight: .semibold)).foregroundStyle(Color(hex: 0xF6DCB4)).padding(.horizontal, 12).frame(height: 30).background(Color(hex: 0xF2B45C).opacity(0.14), in: RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: 0xF2B45C).opacity(0.32), lineWidth: 0.5)).opacity(configuration.isPressed ? 0.82 : 1) }
}
