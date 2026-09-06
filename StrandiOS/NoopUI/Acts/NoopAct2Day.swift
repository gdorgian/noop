import Foundation
import SwiftUI

struct NoopAct2Screens: View {
    @ObservedObject var navigation: NoopNavigation
    @EnvironmentObject private var updateStore: UpdateStore
    @ObservedObject private var planStore = CoachPlanStore.shared

    @AppStorage("noop.schedule.kind") private var scheduleKind = "mostly-nights"
    @SceneStorage("noop.act2.day-rail-open") private var dayRailOpen = false
    @SceneStorage("noop.act2.heart-point") private var selectedHeartPoint = 23
    @SceneStorage("noop.act2.stress-level") private var selectedStress = 0
    @SceneStorage("noop.act3.rest-day") private var restDay = false
    @State private var todayPulseAnchor = Date()
    @State private var heartPulseAnchor = Date()
    var body: some View {
        switch navigation.route {
        case .today:
            todayScreen
        case .inbox:
            inboxScreen
        case .charge:
            chargeScreen
        case .day:
            dayScreen
        case .vitals:
            vitalsScreen
        case .stress:
            stressScreen
        case .heart:
            heartScreen
        default:
            todayScreen
        }
    }

    // MARK: - Today

    private var sessionCardTitle: String {
        if let finished = navigation.finishedSessionToday { return finished.workout.act3.name }
        return restDay ? "Rest" : navigation.selectedWorkout.act3.name
    }

    private var sessionCardLine: String {
        // Change 3. After a session the card reads what was done and what it cost, in the same
        // currency the rest of the day screen speaks.
        if let finished = navigation.finishedSessionToday,
           let chargeCost = finished.chargeCost,
           let sleepNeedMinutes = finished.sleepNeedMinutes {
            return "\(finished.minutes) min · \(chargeCost) of today’s charge, and \(sleepNeedMinutes) minutes on tonight’s need."
        }
        if let finished = navigation.finishedSessionToday {
            return "\(finished.minutes) min · saved from this session’s measured record."
        }
        return restDay
            ? "Nothing today. Tomorrow is the earliest this pays off."
            : navigation.selectedWorkout.act3.note
    }

    private var sessionCardRoute: NoopRoute {
        navigation.finishedSessionToday == nil ? .session : .detail
    }

    private var todayInitialScrollID: String? {
        #if DEBUG
        CommandLine.arguments.contains("--noop-scroll-session-card") ? "noop-today-session" : nil
        #else
        nil
        #endif
    }

    private var todayScreen: some View {
        NoopScreen(topInset: 58, initialScrollID: todayInitialScrollID) {
            VStack(spacing: 0) {
                todayHeader

                if dayRailOpen {
                    dayRail
                        .frame(width: UIScreen.main.bounds.width)
                        .padding(.top, 12)
                        .padding(.bottom, 2)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if isHistorical {
                    Button {
                        navigation.selectedTodayDay = 0
                        dayRailOpen = false
                    } label: {
                        HStack(spacing: 10) {
                            Act2Glyph(.clock, size: 17, color: NoopHTMLColor.night)
                            Text("Looking back at \(dayContext.date). Nothing here is live.")
                                .font(NoopHTMLFont.sans(12.5))
                                .foregroundStyle(Color(hex: 0xC9D0EE))
                                .multilineTextAlignment(.leading)
                                .lineSpacing(2)
                            Spacer(minLength: 4)
                            Text("Today")
                                .font(NoopHTMLFont.sans(12, weight: .semibold))
                                .foregroundStyle(NoopHTMLColor.night)
                        }
                        .padding(.horizontal, 15)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(NoopHTMLColor.night.opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(NoopHTMLColor.night.opacity(0.24), lineWidth: 0.5))
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                    .padding(.top, 12)
                }

                Button { navigation.push(.charge) } label: {
                    Act2BreathingOrb(
                        wakeCharge: dayContext.wakeCharge,
                        charge: dayContext.charge,
                        recordedBPM: dayContext.recordedPulse,
                        isHistorical: false
                    )
                }
                .buttonStyle(NoopHTMLPressStyle())

                VStack(spacing: 10) {
                    Button { navigation.push(.charge) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text(dayContext.chargeLabel)
                                    .font(NoopHTMLFont.outfit(19))
                                    .tracking(-0.38)
                                Act2CSSChevron(size: 7, color: NoopHTMLColor.muted)
                            }
                            Text(dayContext.chargeLine)
                                .font(NoopHTMLFont.sans(13.5))
                                .foregroundStyle(NoopHTMLColor.copy)
                                // CSS 13.5px / 1.55 = 20.925pt per line. Instrument Sans'
                                // native 13.5pt line is 16.47pt; center the remaining leading.
                                .lineSpacing(4.455)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(height: 41.85, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 2)
                        .padding(.bottom, 8)
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 12) {
                        Act2Glyph(.moon, size: 19, color: NoopHTMLColor.night)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isNightWorker ? "Last sleep · 7h 12m, 7m over your need" : "Last night · 7h 12m, 7m over your need")
                                .font(NoopHTMLFont.sans(13))
                                .foregroundStyle(NoopHTMLColor.inkSoft)
                            Text(isNightWorker ? "Deep came early, before the heat. Nothing to fix." : "Deep came early. Nothing to fix.")
                                .font(NoopHTMLFont.sans(11.5))
                                .foregroundStyle(Color(hex: 0x7F8A85))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(NoopHTMLColor.night.opacity(0.09), in: RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(NoopHTMLColor.night.opacity(0.2), lineWidth: 0.5))

                    Button { navigation.push(.coach) } label: {
                        HStack(spacing: 13) {
                            Act2SveaOrb()
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Svea has read your morning")
                                    .font(NoopHTMLFont.sans(14.5, weight: .semibold))
                                Text("Written at 07:12 from five measured signals — with one proposal you can turn down")
                                    .font(NoopHTMLFont.sans(12))
                                    .foregroundStyle(Color(hex: 0xB7C3C9))
                                    // CSS 12px / 1.5 = two 18pt line boxes.
                                    .lineSpacing(3.36)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(height: 36, alignment: .leading)
                            }
                            Spacer(minLength: 4)
                            Act2CSSChevron(size: 8, color: Color(hex: 0xA9B4E0))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            NoopCSSLinearGradient(
                                colors: [NoopHTMLColor.night.opacity(0.16), NoopHTMLColor.night.opacity(0.03)]
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        }
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(NoopHTMLColor.night.opacity(0.3), lineWidth: 0.5))
                    }
                    .buttonStyle(NoopHTMLPressStyle())

                    Button { navigation.push(.day) } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .firstTextBaseline) {
                                NoopSectionLabel("The day so far")
                                Spacer()
                                Text(dayContext.span)
                                    .font(NoopHTMLFont.sans(11))
                                    .foregroundStyle(NoopHTMLColor.faint)
                                    .monospacedDigit()
                            }
                            Act2FixedHeartChart(values: Self.heartValues, kind: .mini)
                                .frame(height: 54)
                            Text(dayContext.dayRead)
                                .font(NoopHTMLFont.sans(12.5))
                                .foregroundStyle(NoopHTMLColor.copy)
                                // CSS 12.5px / 1.5 = 18.75pt line boxes.
                                .lineSpacing(3.5)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.vertical, 1.75)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 13)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))
                    }
                    .buttonStyle(NoopHTMLPressStyle())

                    // Change 1, door one. `today` already answers "can I train"; this is the door to
                    // acting on it. Always present — an empty slot where a card was yesterday reads
                    // as a bug — so a rest day changes the copy rather than removing the card.
                    Button { navigation.reset(to: sessionCardRoute) } label: {
                        HStack(spacing: 13) {
                            VStack(alignment: .leading, spacing: 4) {
                                NoopSectionLabel("Today's session", color: Color(hex: 0xC8934B))
                                // Three states, one card. Title and line crossfade; the card, its
                                // tint, its eyebrow and its chevron never move, and it is never absent.
                                Text(sessionCardTitle)
                                    .font(NoopHTMLFont.sans(14.5, weight: .semibold))
                                    .foregroundStyle(NoopHTMLColor.ink)
                                Text(sessionCardLine)
                                    .font(NoopHTMLFont.sans(12))
                                    .foregroundStyle(NoopHTMLColor.copy)
                                    .lineSpacing(3.36)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                            }
                            .id(sessionCardTitle + sessionCardLine)
                            .transition(.opacity)
                            .animation(NoopMotion.swap, value: sessionCardTitle + sessionCardLine)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Act2CSSChevron(size: 8, color: NoopHTMLColor.faint)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 15)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(NoopHTMLColor.border, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                    .id("noop-today-session")

                    Act2TodayHeartRow(
                        anchor: todayPulseAnchor,
                        wakeCharge: dayContext.wakeCharge,
                        charge: dayContext.charge,
                        recordedBPM: dayContext.recordedPulse,
                        isHistorical: false
                    ) { navigation.push(.heart) }

                    act2DestinationRow(
                        title: "Vitals",
                        detail: "Five signals, each against your own zone",
                        glyph: .lungs,
                        tint: Color(hex: 0xF2B45C),
                        value: "one to watch",
                        valueColor: Color(hex: 0xF3C888)
                    ) { navigation.push(.vitals) }

                    act2DestinationRow(
                        title: "Stress",
                        detail: "Four steps, not a traffic light",
                        glyph: .spark,
                        tint: selectedStress >= 2 ? Color(hex: 0xF2B45C) : NoopHTMLColor.blue,
                        value: Self.stressLevels[selectedStress].name.lowercased(),
                        valueColor: selectedStress >= 2 ? Color(hex: 0xF3C888) : NoopHTMLColor.blueLight
                    ) { navigation.push(.stress) }

                    if navigation.dayLogSaved {
                        VStack(alignment: .leading, spacing: 9) {
                            NoopSectionLabel("Logged today")
                            NoopFlowLayout(spacing: 6) {
                                ForEach(navigation.dayLogChips, id: \.self) { chip in
                                    Text(chip)
                                        .font(NoopHTMLFont.sans(11.5, weight: .semibold))
                                        .foregroundStyle(NoopHTMLColor.blueLight)
                                        .padding(.horizontal, 11)
                                        .padding(.vertical, 6)
                                        .background(NoopHTMLColor.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(NoopHTMLColor.blue.opacity(0.22), lineWidth: 0.5))
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(NoopHTMLColor.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(NoopHTMLColor.blue.opacity(0.18), lineWidth: 0.5))
                        .animation(.easeInOut(duration: 0.18), value: navigation.dayLogChips)
                    }
                }
                .padding(.top, 4)
            }
        }
        .onAppear { todayPulseAnchor = Date() }
    }

    private var todayHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dayContext.eyebrow)
                    .font(NoopHTMLFont.sans(13.5))
                    .foregroundStyle(NoopHTMLColor.copy)
                Text(isHistorical ? dayContext.header : "Take four breaths first")
                    .font(NoopHTMLFont.outfit(23))
                    .tracking(-0.46)
                    // CSS: Outfit 23px / 1.15. The final header also carries the Updates
                    // bell, so flexbox gives the copy the remaining width and wraps it there.
                    .lineSpacing(-2.53)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(height: 52.9, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 9) {
                NoopBatteryChip(percent: 52) { navigation.push(.strap) }
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { dayRailOpen.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Act2Glyph(.calendar, size: 15, color: dayRailOpen || isHistorical ? NoopHTMLColor.blueLight : Color(hex: 0x8B958F))
                        Text(selectedTodayOffset == 0 ? "Today" : selectedTodayOffset == 1 ? "Yesterday" : dayContext.shortLabel)
                            .font(NoopHTMLFont.sans(12, weight: .semibold))
                            .foregroundStyle(dayRailOpen || isHistorical ? NoopHTMLColor.blueLight : NoopHTMLColor.inkSoft)
                    }
                    .padding(.horizontal, 11)
                    .frame(height: 30)
                    .background(dayRailOpen || isHistorical ? NoopHTMLColor.blue.opacity(0.14) : Color.white.opacity(0.06), in: Capsule())
                    .overlay(Capsule().stroke(dayRailOpen || isHistorical ? NoopHTMLColor.blue.opacity(0.34) : Color.white.opacity(0.1), lineWidth: 0.5))
                }
                .buttonStyle(.plain)

                Button { navigation.push(.inbox) } label: {
                    ZStack(alignment: .topTrailing) {
                        NoopCanonicalGlyph(name: .bell, size: 15, color: NoopHTMLColor.inkSoft)
                            .frame(width: 32, height: 32)
                            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 11))
                            .overlay(
                                RoundedRectangle(cornerRadius: 11)
                                    .stroke(Color.white.opacity(0.09), lineWidth: 0.5)
                            )

                        if inboxUnreadCount > 0 {
                            Text("\(min(inboxUnreadCount, 99))")
                                .font(NoopHTMLFont.sans(9.5, weight: .bold))
                                .foregroundStyle(Color(hex: 0x03212F))
                                .monospacedDigit()
                                .padding(.horizontal, 4)
                                .frame(minWidth: 16, minHeight: 16)
                                .background(NoopHTMLColor.blue, in: Capsule())
                                .overlay(Capsule().stroke(NoopHTMLColor.canvas, lineWidth: 1.5))
                                .offset(x: 4, y: -4)
                        }
                    }
                    .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    inboxUnreadCount > 0
                        ? "Updates, \(inboxUnreadCount) unread"
                        : "Updates"
                )
            }
            .padding(.top, 4)
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.bottom, 4)
    }

    private func act2DestinationRow(
        title: String,
        detail: String,
        glyph: Act2GlyphKind,
        tint: Color,
        value: String,
        valueColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Act2Glyph(glyph, size: 21, color: tint)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(NoopHTMLFont.sans(14.5, weight: .semibold))
                    Text(detail)
                        .font(NoopHTMLFont.sans(12))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .lineSpacing(2)
                }
                Spacer(minLength: 5)
                Text(value)
                    .font(NoopHTMLFont.sans(11.5, weight: .semibold))
                    .foregroundStyle(valueColor)
                    .fixedSize(horizontal: true, vertical: false)
                Act2CSSChevron(size: 8, color: NoopHTMLColor.faint)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(NoopHTMLColor.border, lineWidth: 0.5))
        }
        .buttonStyle(NoopHTMLPressStyle())
    }

    private var dayRail: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(Array(Self.days.enumerated()), id: \.offset) { index, day in
                    let offset = Self.days.count - 1 - index
                    let selected = offset == selectedTodayOffset
                    Button {
                        navigation.selectedTodayDay = offset
                        dayRailOpen = false
                    } label: {
                        VStack(spacing: 3) {
                            Text(day.weekday.uppercased())
                                .font(NoopHTMLFont.sans(9.5, weight: .semibold))
                                .tracking(0.6)
                                .foregroundStyle(selected ? NoopHTMLColor.blueLight : Color(hex: 0x7F8A85))
                            Text("\(day.number)")
                                .font(NoopHTMLFont.outfit(17))
                                .foregroundStyle(selected ? NoopHTMLColor.ink : NoopHTMLColor.inkSoft)
                                .frame(height: 17)
                        }
                        .padding(.top, 9)
                        .padding(.bottom, 10)
                        .frame(width: 46)
                        .background(selected ? NoopHTMLColor.blue.opacity(0.18) : Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 15))
                        .overlay(RoundedRectangle(cornerRadius: 15).stroke(selected ? NoopHTMLColor.blue.opacity(0.42) : NoopHTMLColor.border, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Updates

    private var inboxScreen: some View {
        NoopScreen(topInset: 58) {
            VStack(spacing: 0) {
                Act2BackBar(label: "Today", action: { back(to: .today) })
                    .padding(.bottom, 16)

                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Updates")
                            .font(NoopHTMLFont.outfit(25))
                            .tracking(-0.625)
                        Text(inboxSubtitle)
                            .font(NoopHTMLFont.sans(13.5))
                            .foregroundStyle(NoopHTMLColor.copy)
                            .lineSpacing(5.13)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    // The browser's two-line intro occupies four more vertical pixels than
                    // SwiftUI's identically sized text. Preserve the HTML's following anchor.
                    .padding(.bottom, 4)

                    if inboxGroups.isEmpty {
                        VStack(spacing: 9) {
                            Text("Nothing waiting")
                                .font(NoopHTMLFont.sans(14, weight: .semibold))
                                .foregroundStyle(NoopHTMLColor.inkSoft)
                            Text("Proposals, notices and anything you put away land here. Nothing is repeated, and a run of the same finding counts once.")
                                .font(NoopHTMLFont.sans(12))
                                .foregroundStyle(Color(hex: 0x7F8A85))
                                .lineSpacing(4.56)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 26)
                        .frame(maxWidth: .infinity)
                        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))
                    }

                    ForEach(inboxGroups) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                NoopSectionLabel(group.title)
                                Spacer()
                                Text(group.note)
                                    .font(NoopHTMLFont.sans(11))
                                    .foregroundStyle(NoopHTMLColor.faint)
                            }
                            .padding(.horizontal, 2)
                            .padding(.top, 6)

                            VStack(spacing: 0) {
                                ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                                    if index > 0 {
                                        Divider().overlay(NoopHTMLColor.border)
                                    }
                                    inboxRow(item)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
                            .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))
                        }
                    }

                    Text("A proposal waits here until you answer it, and answering it here is the same as answering it on the card. Nothing in this list is a notification — the bell only fills, it never buzzes.")
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .lineSpacing(4.39)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 2)
                        .padding(.top, 2)
                        .padding(.bottom, 20)
                }
            }
        }
        .onAppear {
            if !NoopContentPolicy.allowsPrototypeContent {
                updateStore.pruneExpired()
            }
        }
    }

    private func inboxRow(_ item: Act2InboxItem) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Circle()
                .fill(item.showsUnreadDot ? NoopHTMLColor.blue : Color.clear)
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(item.title)
                        .font(NoopHTMLFont.sans(13.5, weight: item.titleIsBold ? .semibold : .regular))
                        .foregroundStyle(NoopHTMLColor.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(item.when)
                        .font(NoopHTMLFont.sans(10.5))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .monospacedDigit()
                        .fixedSize(horizontal: true, vertical: false)
                }

                Text(item.subtitle)
                    .font(NoopHTMLFont.sans(12))
                    .foregroundStyle(NoopHTMLColor.copy)
                    .lineSpacing(3.96)
                    .fixedSize(horizontal: false, vertical: true)

                inboxActions(for: item)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // CSS line boxes match, but SwiftUI collapses the rows' normal leading around their
        // controls. These asymmetric half-point paddings reproduce the measured HTML row
        // bounds without changing wrapping or the 14px visual inset at either edge.
        .padding(.top, 15)
        .padding(.bottom, item.usesActionSpacing ? 17.5 : 16.5)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func inboxActions(for item: Act2InboxItem) -> some View {
        if let decision = item.decision {
            Text(inboxResolution(for: item, decision: decision))
                .font(NoopHTMLFont.sans(11.5))
                .foregroundStyle(decision == .accept ? Color(hex: 0x8FE3B4) : Color(hex: 0x7F8A85))
                .lineSpacing(3.26)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        } else {
            switch item.action {
            case .proposal:
                HStack(spacing: 7) {
                    inboxActionButton("Accept", tint: NoopHTMLColor.blue, ink: NoopHTMLColor.blueLight) {
                        decideInbox(item, as: .accept)
                    }
                    inboxActionButton("Change", tint: NoopHTMLColor.night, ink: Color(hex: 0xC9D0EE)) {
                        decideInbox(item, as: .change)
                    }
                    inboxActionButton("Decline", tint: Color.white, ink: NoopHTMLColor.inkSoft) {
                        decideInbox(item, as: .decline)
                    }
                }
                .padding(.top, 6)
            case .restore:
                HStack {
                    inboxActionButton("Put it back", tint: NoopHTMLColor.blue, ink: NoopHTMLColor.blueLight) {
                        restoreInboxItem(item)
                    }
                    Spacer()
                }
                .padding(.top, 6)
            case .none:
                EmptyView()
            }
        }
    }

    private func inboxActionButton(
        _ label: String,
        tint: Color,
        ink: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(NoopHTMLFont.sans(11.5, weight: .semibold))
                .foregroundStyle(ink)
                .padding(.horizontal, 12)
                .frame(height: 29)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(tint.opacity(0.34), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private var inboxUnreadCount: Int {
        if NoopContentPolicy.allowsPrototypeContent {
            return demoInboxPendingCount + (navigation.inboxRestored ? 0 : 1)
        }
        return updateStore.unreadCount
    }

    private var inboxSubtitle: String {
        if NoopContentPolicy.allowsPrototypeContent {
            return "\(demoInboxPendingCount) to answer, and \(navigation.inboxRestored ? "two" : "three") things to know. A proposal stays here until you say yes or no to it."
        }
        guard !updateStore.items.isEmpty else {
            return "Everything is answered. This is where proposals, notices and anything you put away collect."
        }
        let pending = liveInboxItems.filter { item in
            if case .proposal = item.action { return item.decision == nil }
            return false
        }.count
        let known = max(0, liveInboxItems.count - pending)
        return "\(pending) to answer, and \(countWord(known)) things to know. A proposal stays here until you say yes or no to it."
    }

    private var inboxGroups: [Act2InboxGroup] {
        NoopContentPolicy.allowsPrototypeContent ? demoInboxGroups : liveInboxGroups
    }

    private var demoInboxPendingCount: Int {
        ["anchor", "thursday"].filter { inboxDecision(for: $0) == nil }.count
    }

    private var demoInboxGroups: [Act2InboxGroup] {
        let proposals = [
            Act2InboxItem(
                id: "anchor",
                title: "Move your anchor to 22:40",
                subtitle: "Twenty minutes earlier for the next four nights. It costs you the end of one episode and buys back about 25 minutes of the debt.",
                when: "Svea · 07:12",
                action: .proposal(planProposalID: nil),
                decision: inboxDecision(for: "anchor"),
                acceptedCopy: "Accepted. Tonight’s anchor reads 22:40, and the bedtime nudge moves with it.",
                sourceItemID: nil,
                showsUnreadDot: inboxDecision(for: "anchor") == nil,
                titleIsBold: true
            ),
            Act2InboxItem(
                id: "thursday",
                title: "Make Thursday easy instead of hard",
                subtitle: "Two hard days back to back is what put you here last month. Zone 2 for forty minutes keeps the week’s load and drops the cost.",
                when: "Svea · 07:12",
                action: .proposal(planProposalID: nil),
                decision: inboxDecision(for: "thursday"),
                acceptedCopy: "Accepted. Thursday now reads Easy 40 min in the effort.",
                sourceItemID: nil,
                showsUnreadDot: inboxDecision(for: "thursday") == nil,
                titleIsBold: true
            )
        ]

        let worthKnowing = [
            Act2InboxItem(
                id: "resting-line",
                title: "Six days under your resting line",
                subtitle: "Your pulse has sat two beats under your own baseline all week. Usually fitness, sometimes the start of a cold — it is neither yet.",
                when: "Today · 06:40"
            ),
            Act2InboxItem(
                id: "pace-old",
                title: "Your pace is a month old",
                subtitle: "You swept on 12 August at 5.5 a minute. Your resting pulse has moved three beats since, which is enough to move the pace.",
                when: "Yesterday"
            )
        ]

        let putAway: [Act2InboxItem]
        if navigation.inboxRestored {
            putAway = [
                Act2InboxItem(
                    id: "restored",
                    title: "Back on Today",
                    subtitle: "Something is off is on the home screen again, priced in the ledger where it was.",
                    when: "Just now"
                ),
                Act2InboxItem(
                    id: "backup",
                    title: "Backup ran at 03:10",
                    subtitle: "41 nights, 2.1 MB, to the folder you chose. The next one is due Sunday.",
                    when: "Today · 03:10"
                )
            ]
        } else {
            putAway = [
                Act2InboxItem(
                    id: "put-away",
                    title: "You swiped away Something is off",
                    subtitle: "It is still in the charge ledger, priced at 12. Putting it back only restores the card on Today.",
                    when: "Today · 07:20",
                    action: .restore
                ),
                Act2InboxItem(
                    id: "backup",
                    title: "Backup ran at 03:10",
                    subtitle: "41 nights, 2.1 MB, to the folder you chose. The next one is due Sunday.",
                    when: "Today · 03:10"
                )
            ]
        }

        return [
            Act2InboxGroup(id: "decision", title: "Needs a decision", note: demoInboxPendingCount == 0 ? "all answered" : "\(demoInboxPendingCount) waiting", items: proposals),
            Act2InboxGroup(id: "knowing", title: "Worth knowing", note: "nothing to answer", items: worthKnowing),
            Act2InboxGroup(id: "away", title: "Put away", note: "kept for seven days", items: putAway)
        ]
    }

    private var liveInboxItems: [Act2InboxItem] {
        updateStore.sortedItems.map { item in
            let key = item.id.uuidString
            let decision = inboxDecision(for: key) ?? storedDecision(for: item.planProposalId)
            let action: Act2InboxAction
            if item.category == .actionable, decision == nil {
                action = .proposal(planProposalID: item.planProposalId)
            } else if item.category == .statusReminder, item.kind == .dismissedCard {
                action = .restore
            } else {
                action = .none
            }
            return Act2InboxItem(
                id: key,
                title: item.title,
                subtitle: item.message,
                when: inboxWhen(item.date),
                action: action,
                decision: decision,
                acceptedCopy: "Accepted.",
                sourceItemID: item.id,
                showsUnreadDot: !item.read,
                titleIsBold: item.category == .actionable
            )
        }
    }

    private var liveInboxGroups: [Act2InboxGroup] {
        let needs = liveInboxItems.filter { item in
            guard let sourceID = item.sourceItemID,
                  let source = updateStore.items.first(where: { $0.id == sourceID }) else { return false }
            return source.category == .actionable
        }
        let knowing = liveInboxItems.filter { item in
            guard let sourceID = item.sourceItemID,
                  let source = updateStore.items.first(where: { $0.id == sourceID }) else { return false }
            return source.category == .informative
        }
        let away = liveInboxItems.filter { item in
            guard let sourceID = item.sourceItemID,
                  let source = updateStore.items.first(where: { $0.id == sourceID }) else { return false }
            return source.category == .statusReminder
        }
        let pending = needs.filter { $0.decision == nil }.count
        return [
            needs.isEmpty ? nil : Act2InboxGroup(id: "decision", title: "Needs a decision", note: pending == 0 ? "all answered" : "\(pending) waiting", items: needs),
            knowing.isEmpty ? nil : Act2InboxGroup(id: "knowing", title: "Worth knowing", note: "nothing to answer", items: knowing),
            away.isEmpty ? nil : Act2InboxGroup(id: "away", title: "Put away", note: "kept for seven days", items: away)
        ].compactMap { $0 }
    }

    private func decideInbox(_ item: Act2InboxItem, as decision: Act2InboxDecision) {
        navigation.inboxDecisionValues[item.id] = decision.rawValue
        if case let .proposal(planProposalID) = item.action, let planProposalID {
            switch decision {
            case .accept:
                planStore.accept(planProposalID)
            case .decline:
                planStore.decline(planProposalID)
            case .change:
                break
            }
        }
        if let sourceID = item.sourceItemID {
            updateStore.markRead(sourceID)
        }
    }

    private func restoreInboxItem(_ item: Act2InboxItem) {
        guard let sourceID = item.sourceItemID,
              let source = updateStore.items.first(where: { $0.id == sourceID }) else {
            navigation.inboxRestored = true
            return
        }
        if let payload = source.restorePayload {
            UserDefaults.standard.set(false, forKey: TodayCardDismissal.flagKey(payload))
        }
        updateStore.requestRestore(source)
    }

    private func inboxResolution(for item: Act2InboxItem, decision: Act2InboxDecision) -> String {
        switch decision {
        case .accept:
            return item.acceptedCopy
        case .change:
            return "Opened for editing — nothing changes until you save it."
        case .decline:
            return "Declined. Svea will not raise it again this week."
        }
    }

    private func inboxDecision(for id: String) -> Act2InboxDecision? {
        navigation.inboxDecisionValues[id].flatMap(Act2InboxDecision.init(rawValue:))
    }

    private func storedDecision(for proposalID: UUID?) -> Act2InboxDecision? {
        guard let proposalID,
              let proposal = planStore.proposals.first(where: { $0.id == proposalID }) else { return nil }
        switch proposal.status {
        case .proposed:
            return nil
        case .accepted, .completed:
            return .accept
        case .declined, .skipped:
            return .decline
        case .modifiedByUser, .paused, .rescheduled:
            return .change
        }
    }

    private func inboxWhen(_ date: Date) -> String {
        let calendar = Calendar.autoupdatingCurrent
        if calendar.isDateInToday(date) {
            return "Today · \(Self.inboxTimeFormatter.string(from: date))"
        }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return Self.inboxDateFormatter.string(from: date)
    }

    private func countWord(_ count: Int) -> String {
        let words = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
        return count < words.count ? words[count] : "\(count)"
    }

    // MARK: - Charge

    private var chargeScreen: some View {
        NoopScreen(topInset: 58) {
            VStack(spacing: 0) {
                Act2BackBar(label: "Today", action: { back(to: .today) })
                    .padding(.bottom, 16)

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 13) {
                        HStack(alignment: .bottom, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                NoopSectionLabel("Charge left", color: Color(hex: 0x8B958F))
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text("\(dayContext.charge)")
                                        .font(NoopHTMLFont.outfit200(52))
                                        .tracking(-1.56)
                                        .foregroundStyle(chargeColor)
                                        .monospacedDigit()
                                        .frame(height: 52)
                                    Text("of \(dayContext.wakeCharge)")
                                        .font(NoopHTMLFont.sans(13))
                                        .foregroundStyle(Color(hex: 0x7F8A85))
                                        .monospacedDigit()
                                }
                            }
                            Spacer()
                            Act2ChargeStateChip(text: dayContext.chargeLabel, color: chargeColor)
                        }
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.06))
                                Capsule()
                                    .fill(NoopHTMLColor.blueLight.opacity(0.16))
                                    .frame(width: proxy.size.width * min(1, CGFloat(dayContext.wakeCharge) / 100))
                                Capsule()
                                    .fill(chargeColor)
                                    .frame(width: proxy.size.width * min(1, CGFloat(dayContext.charge) / 100))
                                    .animation(.easeInOut(duration: 0.5), value: dayContext.charge)
                            }
                        }
                        .frame(height: 12)
                        Text(dayContext.chargeLine)
                            .font(NoopHTMLFont.sans(13))
                            .foregroundStyle(NoopHTMLColor.copy)
                            .lineSpacing(3)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        NoopSectionLabel("Where it went")
                            .padding(.horizontal, 4)
                        VStack(spacing: 0) {
                            ForEach(Array(dayContext.spend.enumerated()), id: \.offset) { index, row in
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(row.title).font(NoopHTMLFont.sans(13.5))
                                        Text(row.detail)
                                            .font(NoopHTMLFont.sans(11.5))
                                            .foregroundStyle(Color(hex: 0x7F8A85))
                                            .lineSpacing(2)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer(minLength: 6)
                                    Text("−\(row.cost)")
                                        .font(NoopHTMLFont.outfit(17))
                                        .tracking(-0.34)
                                        .foregroundStyle(chargeColor)
                                        .monospacedDigit()
                                }
                                .padding(.vertical, 11)
                                if index < dayContext.spend.count - 1 { Divider().overlay(NoopHTMLColor.border) }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))
                    }

                    HStack(spacing: 13) {
                        Act2Glyph(.moon, size: 19, color: NoopHTMLColor.night)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Tonight puts it back").font(NoopHTMLFont.sans(13.5, weight: .semibold))
                            Text("7h 05m in bed gets you back to about \(min(100, dayContext.charge + 26)) by morning. Sleep is the only thing that does it.")
                                .font(NoopHTMLFont.sans(12))
                                .foregroundStyle(Color(hex: 0xC9D0EE))
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(NoopHTMLColor.night.opacity(0.09), in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.night.opacity(0.24), lineWidth: 0.5))

                    Text("Charge is spent, not scored. It starts where your night left it and everything you do takes a piece — so a low evening is not a failure, it is the day showing up in the number.")
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 2)
                }
            }
        }
    }

    // MARK: - Heart

    private var heartScreen: some View {
        NoopScreen(topInset: 58) {
            VStack(spacing: 0) {
                Act2BackBar(label: "Heart", action: { back(to: .today) })
                    .padding(.bottom, 14)

                VStack(spacing: 16) {
                    Act2HeartHero(
                        anchor: heartPulseAnchor,
                        wakeCharge: dayContext.wakeCharge,
                        charge: dayContext.charge,
                        recordedBPM: dayContext.recordedPulse,
                        isHistorical: false,
                        span: dayContext.span
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            NoopSectionLabel("Today · \(dayContext.span)")
                            Spacer()
                            Text("52 low · 68 avg · 96 high")
                                .font(NoopHTMLFont.sans(11))
                                .foregroundStyle(NoopHTMLColor.faint)
                                .monospacedDigit()
                        }
                        Act2FixedHeartChart(values: Self.heartValues, kind: .heart)
                            .frame(height: 84)
                        Text("Dashes are your own resting line, 58 bpm")
                            .font(NoopHTMLFont.sans(11))
                            .foregroundStyle(NoopHTMLColor.faint)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))

                    VStack(alignment: .leading, spacing: 13) {
                        NoopSectionLabel("Where the day was spent")
                        Act2WeightedZoneBar(zones: Self.heartZones)
                        VStack(spacing: 9) {
                            ForEach(Self.heartZones, id: \.name) { zone in
                                HStack(spacing: 11) {
                                    RoundedRectangle(cornerRadius: 3).fill(zone.color).frame(width: 10, height: 10)
                                    Text(zone.name)
                                        .font(NoopHTMLFont.sans(13))
                                        .foregroundStyle(NoopHTMLColor.inkSoft)
                                    Spacer()
                                    Text(zone.range)
                                        .font(NoopHTMLFont.sans(11.5))
                                        .foregroundStyle(NoopHTMLColor.faint)
                                    Text(zone.time)
                                        .font(NoopHTMLFont.sans(12.5))
                                        .frame(width: 62, alignment: .trailing)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))

                    VStack(spacing: 0) {
                        metricRow("Resting heart rate", note: "two beats under your baseline", value: "58")
                        Divider().overlay(NoopHTMLColor.border)
                        metricRow("Variability", note: "near the top of your zone", value: "56 ms")
                        Divider().overlay(NoopHTMLColor.border)
                        metricRow("Recovery after the walk", note: "down 24 beats in the first minute", value: "−24")
                        Divider().overlay(NoopHTMLColor.border)
                        metricRow("Highest today", note: "at 08:26, on the hill", value: "96", warm: true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))

                    Text("Wrist optical readings lag a sharp change by a few seconds and lose accuracy in cold hands. Beat-to-beat is the honest one — it is what everything else here is built from.")
                        .font(NoopHTMLFont.sans(12))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 2)
                }
            }
        }
        .onAppear { heartPulseAnchor = Date() }
    }

    private func metricRow(_ title: String, note: String, value: String, warm: Bool = false) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(NoopHTMLFont.sans(13.5))
                Text(note).font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.faint)
            }
            Spacer()
            Text(value)
                .font(NoopHTMLFont.outfit(18))
                .foregroundStyle(warm ? Color(hex: 0xF2B45C) : NoopHTMLColor.blue)
        }
        .frame(minHeight: 58)
    }

    // MARK: - The day so far

    private var dayScreen: some View {
        let point = min(max(selectedHeartPoint, 0), Self.heartValues.count - 1)
        let nearest = nearestMark(to: point)
        return NoopScreen(topInset: 58) {
            VStack(spacing: 0) {
                Act2BackBar(label: "The day so far", action: { back(to: .today) })
                    .padding(.bottom, 18)

                VStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 9) {
                            Text("\(Int(Self.heartValues[point]))")
                                .font(NoopHTMLFont.outfit200(52))
                                .tracking(-2.08)
                                .monospacedDigit()
                                .frame(height: 52)
                            Text("bpm at \(point == Self.heartValues.count - 1 ? dayContext.endTime : nearest.time)")
                                .font(NoopHTMLFont.sans(13))
                                .foregroundStyle(NoopHTMLColor.copy)
                        }
                        Text(point == Self.heartValues.count - 1
                             ? dayContext.dayRead
                             : "Closest to \(nearest.label.lowercased()) at \(nearest.time). \(Self.heartValues[point] > 84 ? "The one real climb of the day." : "Inside your ordinary range for this hour.")")
                            .font(NoopHTMLFont.sans(13.5))
                            .foregroundStyle(NoopHTMLColor.copy)
                            .lineSpacing(3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 10) {
                        NoopSectionLabel("Drag along the day")
                        Act2ScrubbableDayChart(values: Self.heartValues, selected: $selectedHeartPoint)
                            .frame(height: 150)
                        HStack {
                            Text(dayContext.axis[0]); Spacer()
                            Text(dayContext.axis[1]); Spacer()
                            Text(dayContext.axis[2]); Spacer()
                            Text(dayContext.axis[3])
                        }
                        .font(NoopHTMLFont.sans(10.5))
                        .foregroundStyle(NoopHTMLColor.faint)
                        Text("Dashes are your own resting line, 58 bpm")
                            .font(NoopHTMLFont.sans(11))
                            .foregroundStyle(NoopHTMLColor.faint)
                            .padding(.top, 2)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))

                    VStack(alignment: .leading, spacing: 0) {
                        NoopSectionLabel("What happened")
                            .padding(.top, 13)
                            .padding(.bottom, 4)
                        ForEach(Array(dayContext.marks.enumerated()), id: \.offset) { index, mark in
                            let selected = abs(mark.index - point) <= 1
                            Button { selectedHeartPoint = mark.index } label: {
                                HStack(spacing: 11) {
                                    ZStack {
                                        if selected {
                                            Circle()
                                                .fill(NoopHTMLColor.blue.opacity(0.16))
                                                .frame(width: 16, height: 16)
                                        }
                                        Circle()
                                            .fill(selected ? NoopHTMLColor.blue : Color.white.opacity(0.22))
                                            .frame(width: 8, height: 8)
                                    }
                                    .frame(width: 8, height: 8)
                                    Text(mark.time)
                                        .font(NoopHTMLFont.sans(12.5))
                                        .frame(width: 46, alignment: .leading)
                                        .foregroundStyle(NoopHTMLColor.copy)
                                    Text(mark.label)
                                        .font(NoopHTMLFont.sans(13.5))
                                        .foregroundStyle(NoopHTMLColor.ink)
                                    Spacer()
                                    Text("\(mark.pulse) bpm")
                                        .font(NoopHTMLFont.sans(12.5))
                                        .foregroundStyle(Color(hex: 0x7F8A85))
                                        .monospacedDigit()
                                }
                                .frame(minHeight: 50)
                                .opacity(selected ? 1 : 0.78)
                                .animation(.easeInOut(duration: 0.18), value: selected)
                            }
                            .buttonStyle(.plain)
                            if index < dayContext.marks.count - 1 { Divider().overlay(NoopHTMLColor.border) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))

                    Text("No score on this screen on purpose. It is the shape of your day, and the only question it answers is “is that normal for me”.")
                        .font(NoopHTMLFont.sans(12))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 2)
                }
            }
        }
    }

    // MARK: - Vitals

    private var vitalsScreen: some View {
        NoopScreen(topInset: 58) {
            VStack(spacing: 0) {
                Act2BackBar(label: "Vitals", action: { back(to: .today) })
                    .padding(.bottom, 16)

                VStack(spacing: 14) {
                    HStack(spacing: 11) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: 0xF2B45C).opacity(0.16))
                                .frame(width: 17, height: 17)
                            Circle()
                                .fill(Color(hex: 0xF2B45C))
                                .frame(width: 9, height: 9)
                        }
                        .frame(width: 9, height: 9)
                        Text("Four in your normal zone, one outside it")
                            .font(NoopHTMLFont.sans(13.5))
                            .foregroundStyle(NoopHTMLColor.inkSoft)
                        Spacer()
                    }

                    VStack(spacing: 9) {
                        ForEach(Self.vitals, id: \.name) { vital in
                            Act2VitalCard(vital: vital)
                        }
                    }

                    HStack(spacing: 14) {
                        Text("31")
                            .font(NoopHTMLFont.outfit(30, weight: .light))
                            .tracking(-0.9)
                            .foregroundStyle(NoopHTMLColor.blue)
                            .monospacedDigit()
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Fitness age").font(NoopHTMLFont.sans(13.5, weight: .semibold))
                            Text("Four years under your own. An estimate from resting heart rate and recovery — treat it as a direction, not a fact.")
                                .font(NoopHTMLFont.sans(12))
                                .foregroundStyle(NoopHTMLColor.copy)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(NoopHTMLColor.border, lineWidth: 0.5))

                    Text("The shaded stretch is your own normal zone, the pale line inside it is your baseline. If the dot sits in the shade, there is nothing to read.")
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 2)
                }
            }
        }
    }

    // MARK: - Stress

    private var stressScreen: some View {
        let level = Self.stressLevels[selectedStress]
        return NoopScreen(topInset: 58) {
            VStack(spacing: 0) {
                Act2BackBar(label: "Stress", action: { back(to: .today) })
                    .padding(.bottom, 18)

                VStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(level.name)
                            .font(NoopHTMLFont.outfit200(44))
                            .tracking(-1.54)
                            .foregroundStyle(level.color)
                            .frame(height: 44)
                            .animation(.easeInOut(duration: 0.18), value: selectedStress)
                        Text(level.read)
                            .font(NoopHTMLFont.sans(13.5))
                            .foregroundStyle(NoopHTMLColor.copy)
                            .lineSpacing(3)
                            .animation(.easeInOut(duration: 0.18), value: selectedStress)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 6) {
                        ForEach(Array(Self.stressLevels.enumerated()), id: \.offset) { index, item in
                            let selected = selectedStress == index
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) { selectedStress = index }
                            } label: {
                                VStack(spacing: 7) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(item.color)
                                        .frame(width: 10, height: 10)
                                        .opacity(selected ? 1 : 0.5)
                                    Text(item.name)
                                        .font(NoopHTMLFont.sans(10.5, weight: selected ? .semibold : .medium))
                                        .foregroundStyle(selected ? NoopHTMLColor.ink : Color(hex: 0x7F8A85))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.78)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 11)
                                .frame(maxWidth: .infinity)
                                .background(selected ? Color.white.opacity(0.07) : Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 15))
                                .overlay(RoundedRectangle(cornerRadius: 15).stroke(selected ? Color.white.opacity(0.16) : Color.white.opacity(0.05), lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            NoopSectionLabel("Across the day · at or above this step")
                            Spacer()
                            Text(dayContext.span)
                                .font(NoopHTMLFont.sans(11))
                                .foregroundStyle(NoopHTMLColor.faint)
                        }
                        HStack(alignment: .bottom, spacing: 3) {
                            ForEach(Array(Self.stressValues.enumerated()), id: \.offset) { _, value in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Self.stressLevels[value].color)
                                    .opacity(value >= selectedStress ? 0.95 : 0.3)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: CGFloat(22 + value * 18))
                                    .animation(.easeInOut(duration: 0.2), value: selectedStress)
                            }
                        }
                        .frame(height: 76, alignment: .bottom)
                        HStack {
                            Text(dayContext.axis[0]); Spacer()
                            Text(dayContext.axis[1]); Spacer()
                            Text(dayContext.axis[2]); Spacer()
                            Text(dayContext.axis[3])
                        }
                        .font(NoopHTMLFont.sans(10.5))
                        .foregroundStyle(NoopHTMLColor.faint)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))

                    Button { navigation.reset(to: .today) } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            NoopSectionLabel("The one control you have", color: selectedStress >= 2 ? Color(hex: 0xF2B45C) : NoopHTMLColor.blue)
                            Text("Breathe with the orb")
                                .font(NoopHTMLFont.outfit(22, weight: .light))
                                .tracking(-0.44)
                                .frame(height: 25.3)
                            Text("Your home screen is already pacing it — four in, four held, four out, four held. Watch the pulse inside the orb come down as you go.")
                                .font(NoopHTMLFont.sans(12.5))
                                .foregroundStyle(Color(hex: 0xB7C3C9))
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 18)
                        .padding(.bottom, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            let accent = selectedStress >= 2 ? Color(hex: 0xF2B45C) : NoopHTMLColor.blue
                            NoopCSSLinearGradient(
                                colors: [
                                    accent.opacity(selectedStress >= 2 ? 0.16 : 0.17),
                                    accent.opacity(0.03)
                                ]
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 22))
                        }
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke((selectedStress >= 2 ? Color(hex: 0xF2B45C) : NoopHTMLColor.blue).opacity(selectedStress >= 2 ? 0.34 : 0.3), lineWidth: 0.5))
                        .animation(.easeInOut(duration: 0.22), value: selectedStress)
                    }
                    .buttonStyle(NoopHTMLPressStyle())

                    Text("Four steps and a cool ramp, deliberately not a traffic light. Stress is information about the last hour, not a verdict on you.")
                        .font(NoopHTMLFont.sans(12))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 2)
                }
            }
        }
    }

    // MARK: - Shared context

    private var selectedTodayOffset: Int {
        min(max(navigation.selectedTodayDay, 0), Self.days.count - 1)
    }

    private var isHistorical: Bool { selectedTodayOffset > 0 }

    private var dayContext: Act2DayContext {
        let selected = Self.days[Self.days.count - 1 - selectedTodayOffset]
        let canonical = Self.days[Self.days.count - 1]
        let eyebrow = isHistorical ? selected.date : (isNightWorker ? "Evening, Gabriel" : "Hi, Gabriel")
        let header = isHistorical ? selected.header : "Take four breaths first"

        guard isNightWorker else {
            return Act2DayContext(
                weekday: selected.weekday,
                number: selected.number,
                date: selected.date,
                shortLabel: selected.shortLabel,
                eyebrow: eyebrow,
                header: header,
                span: canonical.span,
                axis: canonical.axis,
                endTime: canonical.endTime,
                dayRead: canonical.dayRead,
                recordedPulse: canonical.recordedPulse,
                wakeCharge: canonical.wakeCharge,
                charge: canonical.charge,
                chargeLabel: canonical.chargeLabel,
                chargeLine: canonical.chargeLine,
                spend: canonical.spend,
                marks: canonical.marks
            )
        }
        return Act2DayContext(
            weekday: selected.weekday,
            number: selected.number,
            date: selected.date,
            shortLabel: selected.shortLabel,
            eyebrow: eyebrow,
            header: header,
            span: "15:22 → 22:40",
            axis: ["15:22", "17:30", "20:00", "22:40"],
            endTime: "22:40",
            dayRead: "Quiet since the walk before your shift. You are eight beats above your resting line, which is normal for this point of a night.",
            recordedPulse: canonical.recordedPulse,
            wakeCharge: canonical.wakeCharge,
            charge: canonical.charge,
            chargeLabel: canonical.chargeLabel,
            // The HTML selects this sentence from the same charge thresholds in either
            // schedule. Night-shift wording is used only by the >= 70 stateCoach branch.
            chargeLine: canonical.chargeLine,
            spend: canonical.spend,
            marks: Self.nightShiftMarks
        )
    }

    private var isNightWorker: Bool { NoopScheduleInference.isNightWorker(kind: scheduleKind) }

    private var chargeColor: Color {
        Act2ChargePalette.color(forCharge: dayContext.charge)
    }

    private func nearestMark(to point: Int) -> Act2Mark {
        dayContext.marks.min(by: { abs($0.index - point) < abs($1.index - point) }) ?? dayContext.marks[0]
    }

    private func back(to fallback: NoopRoute) {
        navigation.canGoBack ? navigation.back() : navigation.reset(to: fallback)
    }
}

// MARK: - Act 2 graphic components

private enum Act2InboxDecision: String {
    case accept, change, decline
}

private enum Act2InboxAction {
    case none
    case proposal(planProposalID: UUID?)
    case restore
}

private struct Act2InboxItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let when: String
    var action: Act2InboxAction = .none
    var decision: Act2InboxDecision? = nil
    var acceptedCopy: String = "Accepted."
    var sourceItemID: UUID? = nil
    var showsUnreadDot = false
    var titleIsBold = false

    var usesActionSpacing: Bool {
        switch action {
        case .none: false
        case .proposal, .restore: true
        }
    }
}

private struct Act2InboxGroup: Identifiable {
    let id: String
    let title: String
    let note: String
    let items: [Act2InboxItem]
}

private enum Act2GlyphKind { case calendar, clock, moon, heart, lungs, spark }

private struct Act2Glyph: View {
    let kind: Act2GlyphKind
    let size: CGFloat
    let color: Color

    init(_ kind: Act2GlyphKind, size: CGFloat, color: Color) {
        self.kind = kind
        self.size = size
        self.color = color
    }

    var body: some View {
        Canvas { context, canvas in
            let scale = min(canvas.width, canvas.height) / 24
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * scale, y: y * scale) }
            var path = Path()
            switch kind {
            case .calendar:
                path.addRect(CGRect(x: 5 * scale, y: 7.5 * scale, width: 14 * scale, height: 12.5 * scale))
                path.move(to: point(5, 11)); path.addLine(to: point(19, 11))
                path.move(to: point(8.6, 4.5)); path.addLine(to: point(8.6, 8.5))
                path.move(to: point(15.4, 4.5)); path.addLine(to: point(15.4, 8.5))
            case .clock:
                path.addEllipse(in: CGRect(x: 4.4 * scale, y: 4.4 * scale, width: 15.2 * scale, height: 15.2 * scale))
                path.move(to: point(12, 7.6)); path.addLine(to: point(12, 12.5)); path.addLine(to: point(15, 14.5))
            case .moon:
                // Exact SVG arcs from the HTML mask:
                // M20 14.5 A8.5 8.5 0 0 1 9.5 4 a8.5 8.5 0 1 0 10.5 10.5z
                path.move(to: point(20, 14.5))
                path.addArc(
                    center: point(17.67617498, 6.32382502),
                    radius: 8.5 * scale,
                    startAngle: .degrees(74.13383814),
                    endAngle: .degrees(195.86616186),
                    clockwise: false
                )
                path.addArc(
                    center: point(11.82382502, 12.17617498),
                    radius: 8.5 * scale,
                    startAngle: .degrees(254.13383814),
                    endAngle: .degrees(15.86616186),
                    clockwise: true
                )
                path.closeSubpath()
            case .heart:
                path.move(to: point(12, 20))
                path.addCurve(to: point(5, 10.6), control1: point(8, 17.5), control2: point(5, 14.2))
                path.addCurve(to: point(12, 8), control1: point(5, 6.1), control2: point(10, 5.1))
                path.addCurve(to: point(19, 10.6), control1: point(14, 5.1), control2: point(19, 6.1))
                path.addCurve(to: point(12, 20), control1: point(19, 14.2), control2: point(16, 17.5))
            case .lungs:
                path.move(to: point(12, 4)); path.addLine(to: point(12, 12))
                path.move(to: point(8.6, 20))
                path.addCurve(to: point(5, 16.6), control1: point(6.6, 20), control2: point(5, 18.6))
                path.addCurve(to: point(7.5, 9.9), control1: point(5, 13.9), control2: point(5.9, 11.5))
                path.addCurve(to: point(9.6, 10.8), control1: point(8.3, 9), control2: point(9.6, 9.6))
                path.addLine(to: point(9.6, 17.7))
                path.addCurve(to: point(8.6, 20), control1: point(9.6, 19), control2: point(9.1, 20))
                path.move(to: point(15.4, 20))
                path.addCurve(to: point(19, 16.6), control1: point(17.4, 20), control2: point(19, 18.6))
                path.addCurve(to: point(16.5, 9.9), control1: point(19, 13.9), control2: point(18.1, 11.5))
                path.addCurve(to: point(14.4, 10.8), control1: point(15.7, 9), control2: point(14.4, 9.6))
                path.addLine(to: point(14.4, 17.7))
                path.addCurve(to: point(15.4, 20), control1: point(14.4, 19), control2: point(14.9, 20))
            case .spark:
                path.move(to: point(12, 3.5)); path.addLine(to: point(13.6, 9)); path.addLine(to: point(19, 10.6))
                path.addLine(to: point(13.6, 12)); path.addLine(to: point(12, 17.5)); path.addLine(to: point(10.4, 12))
                path.addLine(to: point(5, 10.6)); path.addLine(to: point(10.4, 9)); path.closeSubpath()
            }
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.7 * scale, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}

private struct Act2CSSChevron: View {
    enum Direction { case left, right }
    var direction: Direction = .right
    let size: CGFloat
    let color: Color

    var body: some View {
        Canvas { context, canvas in
            var path = Path()
            if direction == .right {
                path.move(to: CGPoint(x: 1, y: 0.8))
                path.addLine(to: CGPoint(x: canvas.width - 1, y: canvas.height / 2))
                path.addLine(to: CGPoint(x: 1, y: canvas.height - 0.8))
            } else {
                path.move(to: CGPoint(x: canvas.width - 1, y: 0.8))
                path.addLine(to: CGPoint(x: 1, y: canvas.height / 2))
                path.addLine(to: CGPoint(x: canvas.width - 1, y: canvas.height - 0.8))
            }
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.6, lineCap: .square, lineJoin: .miter))
        }
        .frame(width: size, height: size)
    }
}

private struct Act2BackBar: View {
    let label: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: action) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.06))
                    Circle().stroke(Color.white.opacity(0.09), lineWidth: 0.5)
                    Act2CSSBackCorner(color: NoopHTMLColor.inkSoft)
                        .offset(x: -1)
                }
                // CSS width/height are 34px content-box plus a 0.5px border.
                .frame(width: 35, height: 35)
            }
            .buttonStyle(.plain)
            Text(label)
                .font(NoopHTMLFont.sans(13.5))
                .foregroundStyle(NoopHTMLColor.copy)
            Spacer()
        }
        .padding(.horizontal, -2)
        .padding(.top, -2)
    }
}

/// Exact CSS back glyph: a 9 x 9 content box with 1.6px left/bottom borders,
/// rotated 45 degrees. Its transformed visual bounds are intentionally larger
/// than its layout box, just as in the HTML.
private struct Act2CSSBackCorner: View {
    let color: Color

    var body: some View {
        Canvas { context, _ in
            var path = Path()
            path.move(to: CGPoint(x: 0.8, y: 0))
            path.addLine(to: CGPoint(x: 0.8, y: 9.8))
            path.addLine(to: CGPoint(x: 10.6, y: 9.8))
            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: 1.6, lineCap: .butt, lineJoin: .miter)
            )
        }
        .frame(width: 10.6, height: 10.6)
        .rotationEffect(.degrees(45))
    }
}

private struct Act2ChargeStateChip: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(NoopHTMLFont.sans(11.5, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.3), lineWidth: 0.5))
    }
}

private struct Act2VitalDeltaChip: View {
    let text: String
    let outside: Bool
    var body: some View {
        Text(text)
            .font(NoopHTMLFont.sans(11, weight: .semibold))
            .foregroundStyle(outside ? Color(hex: 0xF3C888) : NoopHTMLColor.blueLight)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background((outside ? Color(hex: 0xF2B45C) : NoopHTMLColor.blue).opacity(0.13), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct Act2HeartbeatSample {
    let scale: CGFloat
    let glow: Double

    init(elapsed: TimeInterval, reduceMotion: Bool) {
        guard !reduceMotion else { scale = 1; glow = 0.45; return }
        let p = elapsed.truncatingRemainder(dividingBy: 1.05) / 1.05
        let keys = [0.0, 0.09, 0.18, 0.27, 0.42, 1.0]
        let scales = [1.0, 1.05, 1.01, 1.035, 1.0, 1.0]
        let glows = [0.45, 0.8, 0.55, 0.72, 0.45, 0.45]
        let upper = max(1, keys.firstIndex(where: { $0 >= p }) ?? keys.count - 1)
        let amount = Act2MotionMath.cssEase((p - keys[upper - 1]) / max(0.0001, keys[upper] - keys[upper - 1]))
        scale = CGFloat(scales[upper - 1] + (scales[upper] - scales[upper - 1]) * amount)
        glow = glows[upper - 1] + (glows[upper] - glows[upper - 1]) * amount
    }
}

private enum Act2MotionMath {
    static func cssEase(_ progress: Double) -> Double {
        let x = min(1, max(0, progress))
        var lo = 0.0, hi = 1.0, t = x
        for _ in 0..<12 {
            t = (lo + hi) / 2
            if cubic(t, 0.42, 0.58) < x { lo = t } else { hi = t }
        }
        return cubic(t, 0, 1)
    }

    private static func cubic(_ t: Double, _ a: Double, _ b: Double) -> Double {
        let u = 1 - t
        return 3 * u * u * t * a + 3 * u * t * t * b + t * t * t
    }
}

private enum Act2ChargePalette {
    static func color(forCharge charge: Int) -> Color {
        let heat = min(1, max(0, (58 - Double(charge)) / 40))
        if heat < 0.03 { return NoopHTMLColor.blue }
        let rgb = components(forHeat: heat)
        return Color(.sRGB, red: rgb.0 / 255, green: rgb.1 / 255, blue: rgb.2 / 255, opacity: 1)
    }

    static func components(forHeat heat: Double) -> (Double, Double, Double) {
        let ramp = [
            (47.0, 178.0, 240.0),
            (224.0, 138.0, 155.0),
            (242.0, 180.0, 92.0),
            (240.0, 116.0, 44.0)
        ]
        let stops = [0.0, 0.5, 0.78, 1.0]
        for index in 1..<ramp.count where heat <= stops[index] || index == ramp.count - 1 {
            let amount = min(1, max(0, (heat - stops[index - 1]) / (stops[index] - stops[index - 1])))
            return (
                (ramp[index - 1].0 + (ramp[index].0 - ramp[index - 1].0) * amount).rounded(),
                (ramp[index - 1].1 + (ramp[index].1 - ramp[index - 1].1) * amount).rounded(),
                (ramp[index - 1].2 + (ramp[index].2 - ramp[index - 1].2) * amount).rounded()
            )
        }
        return ramp[0]
    }
}

private struct Act2TodayHeartRow: View {
    let anchor: Date
    let wakeCharge: Int
    let charge: Int
    let recordedBPM: Int
    let isHistorical: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 30.0)) { timeline in
                let elapsed = max(0, timeline.date.timeIntervalSince(anchor))
                let orb = Act2OrbFrame(elapsed: elapsed, wakeCharge: wakeCharge, charge: charge, recordedBPM: recordedBPM, isHistorical: isHistorical)
                let beat = Act2HeartbeatSample(elapsed: elapsed, reduceMotion: reduceMotion)
                HStack(spacing: 13) {
                    ZStack {
                        Circle()
                            .fill(RadialGradient(colors: [NoopHTMLColor.blue.opacity(0.34), .clear], center: .center, startRadius: 0, endRadius: 17))
                            .frame(width: 34, height: 34)
                            .opacity(beat.glow)
                        Act2Glyph(.heart, size: 21, color: NoopHTMLColor.blue)
                    }
                    .frame(width: 34, height: 34)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Heart").font(NoopHTMLFont.sans(14.5, weight: .semibold))
                        Text("Live now · \(orb.bpm < 66 ? "settling with the exhale" : orb.bpm > 72 ? "lifting with the inhale" : "resting")")
                            .font(NoopHTMLFont.sans(12))
                            .foregroundStyle(NoopHTMLColor.copy)
                    }
                    Spacer(minLength: 3)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(orb.bpm)")
                            .font(NoopHTMLFont.outfit(26, weight: .light))
                            .tracking(-0.65)
                            .monospacedDigit()
                            .scaleEffect(beat.scale)
                        Text("bpm")
                            .font(NoopHTMLFont.sans(10.5))
                            .foregroundStyle(NoopHTMLColor.muted)
                    }
                    Act2CSSChevron(size: 8, color: NoopHTMLColor.faint)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(NoopHTMLColor.border, lineWidth: 0.5))
            }
        }
        .buttonStyle(NoopHTMLPressStyle())
    }
}

private struct Act2HeartHero: View {
    let anchor: Date
    let wakeCharge: Int
    let charge: Int
    let recordedBPM: Int
    let isHistorical: Bool
    let span: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 30.0)) { timeline in
            let elapsed = max(0, timeline.date.timeIntervalSince(anchor))
            let orb = Act2OrbFrame(elapsed: elapsed, wakeCharge: wakeCharge, charge: charge, recordedBPM: recordedBPM, isHistorical: isHistorical)
            let beat = Act2HeartbeatSample(elapsed: elapsed, reduceMotion: reduceMotion)
            HStack(alignment: .bottom, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text("\(orb.bpm)")
                            .font(NoopHTMLFont.outfit200(64))
                            .tracking(-2.88)
                            .monospacedDigit()
                            .frame(height: 64)
                            .scaleEffect(beat.scale)
                            .background {
                                Ellipse()
                                    .fill(RadialGradient(colors: [NoopHTMLColor.blue.opacity(0.28), .clear], center: .center, startRadius: 0, endRadius: 60))
                                    .frame(width: 120, height: 90)
                                    .opacity(beat.glow)
                                    .offset(x: -14, y: -7)
                            }
                        Text("bpm, live")
                            .font(NoopHTMLFont.sans(13))
                            .foregroundStyle(NoopHTMLColor.copy)
                    }
                    Text(orb.bpm < 62 ? "Resting · under your own resting line" : "Easy · sitting just above resting")
                        .font(NoopHTMLFont.sans(13))
                        .foregroundStyle(Color(hex: 0x7F8A85))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    NoopSectionLabel("Beat to beat")
                    Text("42 ms")
                        .font(NoopHTMLFont.outfit(19))
                        .monospacedDigit()
                }
            }
        }
    }
}

private enum Act2ChartKind { case mini, heart, scrub(Int) }

private struct Act2FixedHeartChart: View {
    let values: [Double]
    let kind: Act2ChartKind

    var body: some View {
        Canvas { context, size in
            guard values.count > 1 else { return }
            let referenceHeight: CGFloat = {
                switch kind { case .mini: 54; case .heart: 84; case .scrub: 150 }
            }()
            func point(_ index: Int, _ value: Double) -> CGPoint {
                let x = CGFloat(index) / CGFloat(values.count - 1) * size.width
                let yRef: CGFloat
                switch kind {
                case .mini: yRef = 54 - CGFloat((value - 50) / 54) * 44
                case .heart: yRef = 84 - CGFloat((value - 50) / 54) * 70
                case .scrub: yRef = 140 - CGFloat((value - 50) / 54) * 118
                }
                return CGPoint(x: x, y: yRef / referenceHeight * size.height)
            }
            let points = values.enumerated().map { point($0.offset, $0.element) }
            var area = Path(); area.move(to: CGPoint(x: 0, y: size.height))
            points.forEach { area.addLine(to: $0) }
            area.addLine(to: CGPoint(x: size.width, y: size.height)); area.closeSubpath()
            context.fill(area, with: .color(NoopHTMLColor.blue.opacity(kind.isMini ? 0.13 : 0.12)))

            if !kind.isMini {
                let baseline = (kind.isHeart ? 62.0 / 84.0 : 112.0 / 150.0) * size.height
                var dash = Path(); dash.move(to: CGPoint(x: 0, y: baseline)); dash.addLine(to: CGPoint(x: size.width, y: baseline))
                context.stroke(dash, with: .color(Color.white.opacity(0.06)), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
            }

            var line = Path(); line.move(to: points[0]); points.dropFirst().forEach { line.addLine(to: $0) }
            context.stroke(line, with: .color(NoopHTMLColor.blue), style: StrokeStyle(lineWidth: kind.lineWidth, lineCap: .round, lineJoin: .round))

            if case let .scrub(selected) = kind {
                let index = min(max(selected, 0), points.count - 1)
                let p = points[index]
                var cursor = Path(); cursor.move(to: CGPoint(x: p.x, y: 0)); cursor.addLine(to: CGPoint(x: p.x, y: size.height))
                context.stroke(cursor, with: .color(Color.white.opacity(0.26)), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                let dot = Path(ellipseIn: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10))
                context.fill(dot, with: .color(NoopHTMLColor.blue))
                context.stroke(dot, with: .color(NoopHTMLColor.card), style: StrokeStyle(lineWidth: 3))
            }
        }
    }
}

private extension Act2ChartKind {
    var isMini: Bool { if case .mini = self { return true }; return false }
    var isHeart: Bool { if case .heart = self { return true }; return false }
    var lineWidth: CGFloat { switch self { case .mini: 2; case .heart: 2.2; case .scrub: 2.4 } }
}

private struct Act2ScrubbableDayChart: View {
    let values: [Double]
    @Binding var selected: Int

    var body: some View {
        GeometryReader { proxy in
            Act2FixedHeartChart(values: values, kind: .scrub(selected))
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let fraction = min(1, max(0, gesture.location.x / max(1, proxy.size.width)))
                            selected = Int((fraction * CGFloat(max(0, values.count - 1))).rounded())
                        }
                )
        }
    }
}

private struct Act2WeightedZoneBar: View {
    let zones: [Act2HeartZone]
    var body: some View {
        GeometryReader { proxy in
            let total = CGFloat(max(1, zones.reduce(0) { $0 + $1.weight }))
            HStack(spacing: 3) {
                ForEach(zones, id: \.name) { zone in
                    Rectangle()
                        .fill(zone.color)
                        .frame(width: max(0, (proxy.size.width - CGFloat(zones.count - 1) * 3) * CGFloat(zone.weight) / total))
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: 12)
    }
}

// Source of truth: current `Noop Act 2 - The Day.dc.html` boxOrb/boxGlow/boxRing/drift
// keyframes, markup 101–117, and runtime formulas 742–853, cross-checked by noop-gauge.js.
// Keep this as a formula port; visual approximations drift out of phase with the gauge.
private struct Act2BreathingOrb: View {
    let wakeCharge: Int
    let charge: Int
    let recordedBPM: Int
    let isHistorical: Bool

    @State private var arrival = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let frame = Act2OrbFrame(
                elapsed: max(0, timeline.date.timeIntervalSince(arrival)),
                wakeCharge: wakeCharge,
                charge: charge,
                recordedBPM: recordedBPM,
                isHistorical: isHistorical
            )
            orb(frame)
        }
        .onAppear { arrival = Date() }
    }

    private func orb(_ frame: Act2OrbFrame) -> some View {
        ZStack {
            Act2ChargeTicks(frame: frame)
                .frame(width: 306, height: 306)

            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: NoopHTMLColor.blue.opacity(0.4), location: 0),
                            .init(color: NoopHTMLColor.blue.opacity(0), location: 0.68),
                            .init(color: .clear, location: 1)
                        ],
                        center: .center,
                        startRadius: 0,
                        // CSS `radial-gradient(circle, ...)` defaults to farthest-corner.
                        endRadius: 189.50
                    )
                )
                .frame(width: 268, height: 268)
                .blur(radius: 6)
                .scaleEffect(frame.glowScale)
                .opacity(frame.glowOpacity)

            Circle()
                .stroke(NoopHTMLColor.blueLight.opacity(0.5), lineWidth: 1)
                .frame(width: 224, height: 224)
                .scaleEffect(frame.ringScale)
                .opacity(frame.ringOpacity)

            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(hex: 0x9FE2FB), location: 0),
                            .init(color: Color(hex: 0x2FB2F0), location: 0.55),
                            .init(color: Color(hex: 0x0A5F92), location: 1)
                        ],
                        center: UnitPoint(x: 0.38, y: 0.32),
                        startRadius: 0,
                        endRadius: 161.95
                    )
                )
                .frame(width: 176, height: 176)
                .shadow(color: Color(hex: 0x0B6FA8).opacity(0.55), radius: 26, y: 18)
                .overlay {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, Color(hex: 0x042A42).opacity(0.5)],
                                startPoint: UnitPoint(x: 0.5, y: 0.42),
                                endPoint: .bottom
                            )
                        )
                        .blendMode(.multiply)
                }
                .scaleEffect(frame.orbScale)

            if frame.heat >= 0.03 {
                Circle()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: frame.warm.opacity(0.42 * frame.heat + 0.1), location: 0),
                                .init(color: frame.warm.opacity(0), location: 0.68),
                                .init(color: .clear, location: 1)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 189.50
                        )
                    )
                    .frame(width: 268, height: 268)
                    .blur(radius: 6)
                    .scaleEffect(frame.glowScale)
                    .opacity(frame.glowOpacity)

                Circle()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: frame.warm.opacity(0.98), location: 0),
                                .init(color: frame.warm.opacity(0.86), location: 0.55),
                                .init(color: frame.warmDeep.opacity(0.98), location: 1)
                            ],
                            center: UnitPoint(x: 0.38, y: 0.32),
                            startRadius: 0,
                            endRadius: 161.95
                        )
                    )
                    .frame(width: 176, height: 176)
                    .shadow(color: frame.warm.opacity(0.42), radius: 26, y: 18)
                    .scaleEffect(frame.orbScale)
                    .opacity(min(1, frame.heat * 1.15))
            }

            Circle()
                .fill(
                    AngularGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: Color.white.opacity(0.32), location: 0.29),
                            .init(color: .clear, location: 0.58),
                            .init(color: .clear, location: 1)
                        ],
                        center: .center,
                        startAngle: .degrees(200),
                        endAngle: .degrees(560)
                    )
                )
                .frame(width: 176, height: 176)
                .rotationEffect(.degrees(frame.sheenAngle))
                .blendMode(.overlay)

            VStack(spacing: 6) {
                Text("\(frame.bpm)")
                    .font(NoopHTMLFont.outfit(52, weight: .thin))
                    .tracking(-1.56)
                    .foregroundStyle(Color(hex: 0xF6FDFF))
                    .monospacedDigit()
                    .shadow(color: Color(hex: 0x041E30).opacity(0.55), radius: 8, y: 2)
                    .frame(height: 52)
                Text(frame.label.uppercased())
                    .font(NoopHTMLFont.sans(12.5, weight: .semibold))
                    .tracking(1.375)
                    .foregroundStyle(Color(hex: 0xF6FDFF).opacity(0.86))
                    .shadow(color: Color(hex: 0x041E30).opacity(0.5), radius: 4, y: 1)
            }
        }
        .frame(height: 318)
    }
}

private struct Act2ChargeTicks: View {
    let frame: Act2OrbFrame

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let count = 41
            let span = 250.0
            let start = -125.0

            for index in 0..<count {
                let angle = start + Double(index) / Double(count - 1) * span
                let radians = angle * .pi / 180
                let outward = CGVector(dx: sin(radians), dy: -cos(radians))
                let length: CGFloat = index.isMultiple(of: 5) ? 15 : 9
                let tickCenter = CGPoint(
                    x: center.x + outward.dx * 142,
                    y: center.y + outward.dy * 142
                )
                var tick = Path()
                tick.move(to: CGPoint(
                    x: tickCenter.x - outward.dx * length / 2,
                    y: tickCenter.y - outward.dy * length / 2
                ))
                tick.addLine(to: CGPoint(
                    x: tickCenter.x + outward.dx * length / 2,
                    y: tickCenter.y + outward.dy * length / 2
                ))

                let on = index <= frame.activeTick
                let ghost = !on && index <= frame.wakeTick
                let color: Color
                if on {
                    let opacity = 0.32 + 0.68 * Double(index) / Double(max(1, frame.activeTick))
                    color = frame.tickColor.opacity(opacity)
                } else if ghost {
                    color = Color(hex: 0x9FE2FB).opacity(0.38)
                } else {
                    color = Color.white.opacity(0.13)
                }
                context.stroke(
                    tick,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
            }

            let markerRadians = (-125 + frame.fraction * 250) * .pi / 180
            let outward = CGVector(dx: sin(markerRadians), dy: -cos(markerRadians))
            let tangent = CGVector(dx: cos(markerRadians), dy: sin(markerRadians))
            let markerCenter = CGPoint(
                x: center.x + outward.dx * 131,
                y: center.y + outward.dy * 131
            )
            var marker = Path()
            marker.move(to: CGPoint(
                x: markerCenter.x + outward.dx * 4.5,
                y: markerCenter.y + outward.dy * 4.5
            ))
            marker.addLine(to: CGPoint(
                x: markerCenter.x - outward.dx * 4.5 + tangent.dx * 6,
                y: markerCenter.y - outward.dy * 4.5 + tangent.dy * 6
            ))
            marker.addLine(to: CGPoint(
                x: markerCenter.x - outward.dx * 4.5 - tangent.dx * 6,
                y: markerCenter.y - outward.dy * 4.5 - tangent.dy * 6
            ))
            marker.closeSubpath()
            context.addFilter(.shadow(color: .black.opacity(0.5), radius: 6))
            context.fill(marker, with: .color(NoopHTMLColor.ink))
        }
    }
}

private struct Act2OrbFrame {
    let elapsed: TimeInterval
    let wakeCharge: Int
    let charge: Int
    let recordedBPM: Int
    let isHistorical: Bool

    let bpm: Int
    let label: String
    let orbScale: CGFloat
    let glowScale: CGFloat
    let glowOpacity: Double
    let ringScale: CGFloat
    let ringOpacity: Double
    let sheenAngle: Double
    let shownCharge: Int
    let fraction: Double
    let activeTick: Int
    let wakeTick: Int
    let heat: Double
    let warm: Color
    let warmDeep: Color
    let tickColor: Color

    init(elapsed: TimeInterval, wakeCharge: Int, charge: Int, recordedBPM: Int, isHistorical: Bool) {
        self.elapsed = elapsed
        self.wakeCharge = wakeCharge
        self.charge = charge
        self.recordedBPM = recordedBPM
        self.isHistorical = isHistorical

        let cycle = elapsed.truncatingRemainder(dividingBy: 16)
        let phaseIndex = min(3, max(0, Int(cycle / 4)))
        label = ["In", "Hold", "Out", "Hold"][phaseIndex]
        let settle = min(7.0, floor(elapsed / 16) * 1.5)
        let swing = [3.0, 1.0, -3.0, -1.0][phaseIndex]
        bpm = Int((70 - settle + swing).rounded())

        let breath: Double
        if cycle < 4 {
            breath = Self.cssEaseInOut(cycle / 4)
        } else if cycle < 8 {
            breath = 1
        } else if cycle < 12 {
            breath = 1 - Self.cssEaseInOut((cycle - 8) / 4)
        } else {
            breath = 0
        }
        orbScale = 0.82 + (1.16 - 0.82) * breath
        glowScale = 0.86 + (1.24 - 0.86) * breath
        glowOpacity = 0.32 + (0.8 - 0.32) * breath
        ringScale = 0.8 + (1.32 - 0.8) * breath
        ringOpacity = 0.55 + (0.12 - 0.55) * breath
        sheenAngle = elapsed.truncatingRemainder(dividingBy: 24) / 24 * 360

        let drain = min(1, max(0, elapsed / 1.15))
        let drainEase = 1 - pow(1 - drain, 3)
        shownCharge = Int((Double(wakeCharge) + Double(charge - wakeCharge) * drainEase).rounded())
        fraction = min(1, max(0.04, Double(shownCharge) / 100))
        activeTick = Int((fraction * 40).rounded())
        wakeTick = Int((min(1, max(0.04, Double(wakeCharge) / 100)) * 40).rounded())
        heat = min(1, max(0, (58 - Double(shownCharge)) / 40))

        let components = Act2ChargePalette.components(forHeat: heat)
        warm = Color(
            .sRGB,
            red: components.0 / 255,
            green: components.1 / 255,
            blue: components.2 / 255,
            opacity: 1
        )
        warmDeep = Color(
            .sRGB,
            red: components.0 * 0.5 / 255,
            green: components.1 * 0.42 / 255,
            blue: components.2 * 0.34 / 255,
            opacity: 1
        )
        tickColor = heat < 0.03 ? NoopHTMLColor.blue : warm
    }

    /// CSS `ease-in-out` is cubic-bezier(.42, 0, .58, 1), which requires solving X before reading Y.
    private static func cssEaseInOut(_ progress: Double) -> Double {
        let x = min(1, max(0, progress))
        var lower = 0.0
        var upper = 1.0
        var parameter = x
        for _ in 0..<14 {
            parameter = (lower + upper) / 2
            let estimate = cubic(parameter, 0.42, 0.58)
            if estimate < x { lower = parameter } else { upper = parameter }
        }
        return cubic(parameter, 0, 1)
    }

    private static func cubic(_ value: Double, _ first: Double, _ second: Double) -> Double {
        let inverse = 1 - value
        return 3 * inverse * inverse * value * first
            + 3 * inverse * value * value * second
            + value * value * value
    }
}

private struct Act2SveaOrb: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: NoopHTMLColor.night.opacity(0.45), location: 0),
                            .init(color: .clear, location: 0.66),
                            .init(color: .clear, location: 1)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 31.11
                    )
                )
                .frame(width: 44, height: 44)
                .blur(radius: 4)
            Act2SveaBlob()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(hex: 0xDDE3F6), location: 0),
                            .init(color: NoopHTMLColor.night, location: 0.58),
                            .init(color: Color(hex: 0x4A56A8), location: 1)
                        ],
                        center: UnitPoint(x: 0.44, y: 0.38),
                        startRadius: 0,
                        endRadius: 23.39
                    )
                )
                .frame(width: 28, height: 28)
                .shadow(color: NoopHTMLColor.night.opacity(0.5), radius: 6)
        }
        .frame(width: 32, height: 32)
    }
}

/// CSS `border-radius:58% 42% 46% 54% / 49% 55% 45% 51%`.
private struct Act2SveaBlob: Shape {
    func path(in rect: CGRect) -> Path {
        let kappa: CGFloat = 0.5522847498
        let tl = CGSize(width: rect.width * 0.58, height: rect.height * 0.49)
        let tr = CGSize(width: rect.width * 0.42, height: rect.height * 0.55)
        let br = CGSize(width: rect.width * 0.46, height: rect.height * 0.45)
        let bl = CGSize(width: rect.width * 0.54, height: rect.height * 0.51)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + tl.width, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr.width, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + tr.height),
            control1: CGPoint(x: rect.maxX - tr.width * (1 - kappa), y: rect.minY),
            control2: CGPoint(x: rect.maxX, y: rect.minY + tr.height * (1 - kappa))
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br.height))
        path.addCurve(
            to: CGPoint(x: rect.maxX - br.width, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.maxY - br.height * (1 - kappa)),
            control2: CGPoint(x: rect.maxX - br.width * (1 - kappa), y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + bl.width, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - bl.height),
            control1: CGPoint(x: rect.minX + bl.width * (1 - kappa), y: rect.maxY),
            control2: CGPoint(x: rect.minX, y: rect.maxY - bl.height * (1 - kappa))
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl.height))
        path.addCurve(
            to: CGPoint(x: rect.minX + tl.width, y: rect.minY),
            control1: CGPoint(x: rect.minX, y: rect.minY + tl.height * (1 - kappa)),
            control2: CGPoint(x: rect.minX + tl.width * (1 - kappa), y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

private struct Act2VitalCard: View {
    let vital: Act2Vital

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(vital.name).font(NoopHTMLFont.sans(13.5, weight: .semibold))
                Spacer()
                Text(vital.window).font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.faint)
            }
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(vital.value)
                        .font(NoopHTMLFont.outfit(25, weight: .light))
                        .tracking(-0.7)
                        .foregroundStyle(vital.outside ? Color(hex: 0xF3C888) : NoopHTMLColor.ink)
                        .monospacedDigit()
                        .frame(height: 25)
                    Text(vital.unit).font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.muted)
                }
                Spacer()
                Act2VitalDeltaChip(text: vital.delta, outside: vital.outside)
            }
            VStack(spacing: 6) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.06)).frame(height: 4)
                        Capsule().fill(NoopHTMLColor.blue.opacity(0.3))
                            .frame(width: proxy.size.width * vital.bandWidth, height: 4)
                            .offset(x: proxy.size.width * vital.bandStart)
                        Rectangle().fill(NoopHTMLColor.ink.opacity(0.55)).frame(width: 2, height: 16)
                            .offset(x: proxy.size.width * vital.baseline - 1)
                        ZStack {
                            Circle()
                                .fill((vital.outside ? Color(hex: 0xF2B45C) : NoopHTMLColor.blue).opacity(0.16))
                                .frame(width: 22, height: 22)
                            Circle()
                                .fill(vital.outside ? Color(hex: 0xF2B45C) : NoopHTMLColor.blue)
                                .frame(width: 14, height: 14)
                                .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
                        }
                            .offset(x: proxy.size.width * vital.position - 11)
                    }
                    .frame(height: 22)
                }
                .frame(height: 22)

                GeometryReader { proxy in
                    ZStack(alignment: .topLeading) {
                        Text(vital.lowLabel)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(vital.baselineLabel)
                            .foregroundStyle(NoopHTMLColor.ink.opacity(0.5))
                            .fixedSize()
                            .position(x: proxy.size.width * vital.baseline, y: 6.5)
                        Text(vital.highLabel)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .font(NoopHTMLFont.sans(10))
                    .foregroundStyle(NoopHTMLColor.faint)
                    .monospacedDigit()
                }
                .frame(height: 13)
            }

            Text(vital.plain)
                .font(NoopHTMLFont.sans(12))
                .foregroundStyle(Color(hex: 0x7F8A85))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.top, 15)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(vital.outside ? Color(hex: 0xF2B45C).opacity(0.05) : NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(vital.outside ? Color(hex: 0xF2B45C).opacity(0.26) : NoopHTMLColor.border, lineWidth: 0.5))
    }
}

// MARK: - Act 2 models

private struct Act2Spend {
    let title: String
    let detail: String
    let cost: Int
}

private struct Act2Mark {
    let time: String
    let label: String
    let pulse: Int
    let index: Int
}

private struct Act2DayContext {
    let weekday: String
    let number: Int
    let date: String
    let shortLabel: String
    let eyebrow: String
    let header: String
    let span: String
    let axis: [String]
    let endTime: String
    let dayRead: String
    let recordedPulse: Int
    let wakeCharge: Int
    let charge: Int
    let chargeLabel: String
    let chargeLine: String
    let spend: [Act2Spend]
    let marks: [Act2Mark]
}

private struct Act2HeartZone {
    let name: String
    let range: String
    let time: String
    let weight: Int
    let color: Color
}

private struct Act2StressLevel {
    let name: String
    let color: Color
    let read: String
}

private struct Act2Vital {
    let name: String
    let value: String
    let unit: String
    let window: String
    let delta: String
    let plain: String
    let lowLabel: String
    let baselineLabel: String
    let highLabel: String
    let bandStart: CGFloat
    let bandWidth: CGFloat
    let baseline: CGFloat
    let position: CGFloat
    var outside = false
}

private extension NoopAct2Screens {
    static let inboxTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static let inboxDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    static let heartValues: [Double] = [58, 60, 62, 74, 88, 96, 92, 78, 72, 70, 74, 80, 76, 72, 70, 68, 72, 78, 74, 70, 68, 66, 70, 72]
    static let stressValues = [0, 0, 1, 1, 2, 2, 1, 1, 0, 1, 1, 2, 3, 2, 1, 1, 0, 1, 2, 1, 1, 1]

    static let stressLevels = [
        Act2StressLevel(name: "Settled", color: Color(hex: 0x4FB8E8), read: "Nothing is asking anything of you. Your rhythm has been steady for the last two hours."),
        Act2StressLevel(name: "Engaged", color: NoopHTMLColor.night, read: "Working, not straining. This is where most of a good day sits — no action needed."),
        Act2StressLevel(name: "Pushed", color: Color(hex: 0xF2B45C), read: "An hour of real load. Worth a wind-down before it becomes the evening you take home."),
        Act2StressLevel(name: "Overloaded", color: NoopHTMLColor.amber, read: "Your body has been braced for a while. Four rounds of breathing is the cheapest thing you can do about it.")
    ]

    static let heartZones = [
        Act2HeartZone(name: "Resting", range: "under 62", time: "9h 12m", weight: 52, color: Color(hex: 0x3E6C86)),
        Act2HeartZone(name: "Easy", range: "62–96", time: "3h 04m", weight: 26, color: Color(hex: 0x4FB8E8)),
        Act2HeartZone(name: "Steady", range: "96–128", time: "38m", weight: 12, color: NoopHTMLColor.blue),
        Act2HeartZone(name: "Hard", range: "128–152", time: "6m", weight: 7, color: Color(hex: 0xF2B45C)),
        Act2HeartZone(name: "All out", range: "152+", time: "—", weight: 3, color: NoopHTMLColor.amber)
    ]

    static let vitals = [
        Act2Vital(name: "Resting heart rate", value: "58", unit: "bpm", window: "overnight average", delta: "−2 bpm vs baseline", plain: "Two beats slower than your baseline — a good sign, nothing to read into.", lowLabel: "54", baselineLabel: "your normal 60", highLabel: "64", bandStart: 8.0 / 28.0, bandWidth: 10.0 / 28.0, baseline: 0.50, position: 12.0 / 28.0),
        Act2Vital(name: "Heart rhythm", value: "56", unit: "ms", window: "overnight variability", delta: "+8 ms vs baseline", plain: "Near the top of your zone. The clearest sign you have recovered.", lowLabel: "42", baselineLabel: "your normal 48", highLabel: "60", bandStart: 14.0 / 48.0, bandWidth: 18.0 / 48.0, baseline: 20.0 / 48.0, position: 28.0 / 48.0),
        Act2Vital(name: "Breathing rate", value: "16.1", unit: "/min", window: "overnight average", delta: "+1.8 /min vs baseline", plain: "Almost two breaths a minute above your normal, and outside your zone for the first time in three weeks. Usually altitude, a warm room, a drink, or something your body is fighting off. Worth watching for a night, not worth worrying about tonight.", lowLabel: "13.4", baselineLabel: "your normal 14.3", highLabel: "15.2", bandStart: 2.4 / 7.0, bandWidth: 1.8 / 7.0, baseline: 3.3 / 7.0, position: 5.1 / 7.0, outside: true),
        Act2Vital(name: "Blood oxygen", value: "97", unit: "%", window: "overnight low", delta: "at your baseline", plain: "Normal. Wrist readings are approximate, so only sustained changes get flagged.", lowLabel: "96", baselineLabel: "your normal 97", highLabel: "99", bandStart: 3.5 / 8.0, bandWidth: 3.5 / 8.0, baseline: 5.0 / 8.0, position: 5.0 / 8.0),
        Act2Vital(name: "Skin temperature", value: "−0.2", unit: "°C", window: "deviation from your normal", delta: "−0.2 °C vs baseline", plain: "Slightly cool, which is what a proper sleep looks like.", lowLabel: "−0.4", baselineLabel: "your normal 0.0", highLabel: "0.4", bandStart: 0.8 / 2.4, bandWidth: 0.8 / 2.4, baseline: 0.50, position: 1.0 / 2.4)
    ]

    static let commonSpend = [
        Act2Spend(title: "Just being awake", detail: "baseline burn across 8h 56m", cost: 10),
        Act2Spend(title: "The intervals", detail: "6 × 3 min hard at 07:40", cost: 14),
        Act2Spend(title: "Two hard meetings", detail: "38 stressed minutes before lunch", cost: 7),
        Act2Spend(title: "On your feet", detail: "11.4k steps, 3k over your normal", cost: 5)
    ]

    static func marks(_ day: Int) -> [Act2Mark] {
        [
            Act2Mark(time: "06:41", label: "Woke", pulse: 58, index: 0),
            Act2Mark(time: "07:20", label: "Coffee", pulse: 62, index: 2),
            Act2Mark(time: "08:10", label: "Walk, 32 min", pulse: 96, index: 5),
            Act2Mark(time: "09:30", label: day == 22 ? "Standup" : "Morning", pulse: 78, index: 7),
            Act2Mark(time: "12:05", label: "Lunch", pulse: 80, index: 11),
            Act2Mark(time: "14:20", label: day == 22 ? "Now" : "Final reading", pulse: 72, index: 23)
        ]
    }

    static let nightShiftMarks = [
        Act2Mark(time: "15:22", label: "Woke", pulse: 58, index: 0),
        Act2Mark(time: "16:10", label: "Coffee", pulse: 62, index: 2),
        Act2Mark(time: "17:00", label: "Walk, 32 min", pulse: 96, index: 5),
        Act2Mark(time: "18:00", label: "Shift started", pulse: 78, index: 7),
        Act2Mark(time: "20:30", label: "Ward round", pulse: 80, index: 11),
        Act2Mark(time: "22:40", label: "Now", pulse: 72, index: 23)
    ]

    static let days: [Act2DayContext] = [
        Act2DayContext(weekday: "Sun", number: 16, date: "Sunday 16 August", shortLabel: "Sun 16", eyebrow: "Sunday 16 August", header: "Two sessions, then nothing", span: "06:38 → 22:10", axis: ["06:38", "11:30", "17:00", "22:10"], endTime: "22:10", dayRead: "The second session was the whole cost. After it, the day came back down normally.", recordedPulse: 68, wakeCharge: 86, charge: 34, chargeLabel: "Running low", chargeLine: "You woke with 86 and finished with 34. Two sessions spent most of the room you had.", spend: commonSpend, marks: marks(16)),
        Act2DayContext(weekday: "Mon", number: 17, date: "Monday 17 August", shortLabel: "Mon 17", eyebrow: "Monday 17 August", header: "The intervals cost you", span: "06:50 → 21:42", axis: ["06:50", "11:00", "16:00", "21:42"], endTime: "21:42", dayRead: "The intervals are the one clear climb. Everything after them stayed a little higher than usual.", recordedPulse: 74, wakeCharge: 80, charge: 31, chargeLabel: "Running low", chargeLine: "You woke with 80 and finished with 31. The intervals were the largest single cost.", spend: commonSpend, marks: marks(17)),
        Act2DayContext(weekday: "Tue", number: 18, date: "Tuesday 18 August", shortLabel: "Tue 18", eyebrow: "Tuesday 18 August", header: "Short night, easy day", span: "05:18 → 20:50", axis: ["05:18", "10:00", "15:00", "20:50"], endTime: "20:50", dayRead: "You started with less after the short night, then kept the day easy enough not to spend it twice.", recordedPulse: 66, wakeCharge: 62, charge: 38, chargeLabel: "Running low", chargeLine: "You woke with 62 and finished with 38. The short night, not the day, set the limit.", spend: Array(commonSpend.prefix(2)), marks: marks(18)),
        Act2DayContext(weekday: "Wed", number: 19, date: "Wednesday 19 August", shortLabel: "Wed 19", eyebrow: "Wednesday 19 August", header: "Back to your own normal", span: "05:42 → 21:10", axis: ["05:42", "10:30", "15:30", "21:10"], endTime: "21:10", dayRead: "A normal curve from wake to evening, with no hour sitting outside your own range.", recordedPulse: 64, wakeCharge: 78, charge: 49, chargeLabel: "Running low", chargeLine: "You woke with 78 and finished with 49. An ordinary day used an ordinary amount.", spend: Array(commonSpend.prefix(3)), marks: marks(19)),
        Act2DayContext(weekday: "Thu", number: 20, date: "Thursday 20 August", shortLabel: "Thu 20", eyebrow: "Thursday 20 August", header: "A quiet day, mostly", span: "06:20 → 21:30", axis: ["06:20", "10:30", "16:00", "21:30"], endTime: "21:30", dayRead: "Quiet except for the walk and one pushed hour after lunch. Both came down cleanly.", recordedPulse: 65, wakeCharge: 84, charge: 53, chargeLabel: "Enough for the evening", chargeLine: "You woke with 84 and finished with 53. Most of the day stayed cheap.", spend: Array(commonSpend.prefix(3)), marks: marks(20)),
        Act2DayContext(weekday: "Fri", number: 21, date: "Friday 21 August", shortLabel: "Fri 21", eyebrow: "Friday 21 August", header: "You went to bed on time", span: "06:40 → 22:05", axis: ["06:40", "11:00", "16:30", "22:05"], endTime: "22:05", dayRead: "The day held steady and the evening came down early enough to leave sleep alone.", recordedPulse: 63, wakeCharge: 88, charge: 57, chargeLabel: "Enough for the evening", chargeLine: "You woke with 88 and finished with 57. Nothing borrowed from the next morning.", spend: Array(commonSpend.prefix(3)), marks: marks(21)),
        Act2DayContext(weekday: "Sat", number: 22, date: "Saturday 22 August", shortLabel: "Sat 22", eyebrow: "Hi, Gabriel", header: "Take four breaths first", span: "06:41 → 14:20", axis: ["06:41", "09:00", "11:30", "14:20"], endTime: "14:20", dayRead: "Quiet since the walk. You are sitting eight beats above your resting line, which is normal for the early afternoon.", recordedPulse: 72, wakeCharge: 92, charge: 56, chargeLabel: "Enough for the evening", chargeLine: "You woke with 92 and you have 56 left. Normal for this hour. Enough for the evening you had planned.", spend: commonSpend, marks: marks(22))
    ]
}
