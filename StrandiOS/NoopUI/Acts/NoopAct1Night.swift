import Foundation
import SwiftUI

struct NoopAct1Screens: View {
    @ObservedObject var navigation: NoopNavigation

    @AppStorage("noop.schedule.kind") private var scheduleKind = "mostly-nights"
    @State private var showHypnogram = NoopContentPolicy.allowsPrototypeContent
        && CommandLine.arguments.contains("--noop-hypnogram")
    @State private var selectedStage: Int?
    @SceneStorage("noop.act1.selected-bedtime") private var selectedBedtime = 2
    @SceneStorage("noop.act1.smart-wake") private var smartWake = true
    @SceneStorage("noop.act1.wind-down") private var windDownBuzz = true
    @SceneStorage("noop.act1.bedtime-committed") private var bedtimeCommitted = false
    @State private var expandedCause = 1
    @State private var debtRange = "14 nights"
    @State private var debtPoint: Int?

    var body: some View {
        switch navigation.route {
        case .rest:
            restScreen
        case .tonight:
            tonightScreen
        case .why:
            whyScreen
        case .debt:
            debtScreen
        default:
            restScreen
        }
    }

    // MARK: - Rest

    private var restScreen: some View {
        NoopScreen(topInset: 58) {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedNightOffset == 0 ? (isNightWorker ? "Last sleep" : "Last night") : selectedNight.date)
                            .font(NoopHTMLFont.sans(13.5))
                            .foregroundStyle(NoopHTMLColor.copy)
                        Text("Rest")
                            .font(NoopHTMLFont.outfit(23, weight: .regular))
                            .tracking(-0.46)
                            .frame(height: 26.45, alignment: .top)
                    }
                    Spacer(minLength: 8)
                    NoopBatteryChip(percent: 52) { navigation.push(.strap) }
                        .padding(.top, 2)
                }
                .padding(.bottom, 20)

                VStack(spacing: 10) {
                    Button { navigation.push(.why) } label: {
                        VStack(spacing: 2) {
                            HStack(alignment: .firstTextBaseline) {
                                NoopSectionLabel("Against your need", color: Color(hex: 0x8B958F))
                                Spacer()
                                Text(selectedNight.window)
                                    .font(NoopHTMLFont.sans(10.5))
                                    .foregroundStyle(NoopHTMLColor.faint)
                                    .monospacedDigit()
                            }

                            Act1SleepRing(
                                hours: selectedNight.hours,
                                delta: selectedNight.delta,
                                progress: min(1, selectedNight.value / 7.083),
                                selectedStage: selectedStage
                            )

                            HStack(spacing: 10) {
                                Text(ringRead)
                                    .font(NoopHTMLFont.sans(12.5))
                                    .foregroundStyle(NoopHTMLColor.inkSoft)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 4)
                                NoopA4CSSChevron(direction: .right, color: NoopHTMLColor.nightLight)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(NoopHTMLColor.border, lineWidth: 0.5))
                            .padding(.top, 6)
                        }
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                    .padding(.top, -14)

                    sevenNightsCard
                    sleepShapeCard

                    Act1LinkRow(
                        title: selectedNightOffset == 0 ? (isNightWorker ? "Why that sleep" : "Why last night") : "Why \(selectedNight.shortDate)",
                        detail: selectedNight.reason,
                        glyph: .read
                    ) { navigation.push(.why) }

                    Act1LinkRow(
                        title: "Sleep debt",
                        detail: selectedNightOffset == 0
                            ? "1h 20m behind over a fortnight. Two ordinary nights clears it."
                            : "The running balance as it stood after this sleep.",
                        glyph: .scale
                    ) { navigation.push(.debt) }

                    if navigation.nightJournalSaved { savedJournalRow }

                    Button { navigation.push(.tonight) } label: {
                        VStack(alignment: .leading, spacing: 11) {
                            NoopSectionLabel(isNightWorker ? "Before you sleep" : "Tonight", color: NoopHTMLColor.blue)
                            Text("Lights out by \(activeBedtimes[selectedBedtime].time)")
                                .font(NoopHTMLFont.outfit(27, weight: .light))
                                .tracking(-0.675)
                                .frame(minHeight: 29.7, alignment: .top)
                            Text(selectedBedtime == 2
                                 ? "Clears twenty minutes of debt before your \(alarmTime) alarm."
                                 : "\(activeBedtimes[selectedBedtime].length) before your \(alarmTime) alarm.")
                                .font(NoopHTMLFont.sans(13))
                                .foregroundStyle(Color(hex: 0xB7C3C9))
                                .noopAct1LineBox(fontSize: 13, ratio: 1.5)
                            HStack(spacing: 7) {
                                Text("Decide it")
                                NoopA4CSSChevron(direction: .right, color: NoopHTMLColor.blueInk)
                            }
                            .font(NoopHTMLFont.sans(13, weight: .semibold))
                            .foregroundStyle(NoopHTMLColor.blueInk)
                            .padding(.horizontal, 14)
                            .frame(height: 38)
                            .background(NoopHTMLColor.blue, in: RoundedRectangle(cornerRadius: 14))
                            .padding(.top, 2)
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 19)
                        .padding(.bottom, 17)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            NoopCSSLinearGradient(
                                colors: [NoopHTMLColor.blue.opacity(0.17), NoopHTMLColor.blue.opacity(0.03)]
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                        }
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(NoopHTMLColor.blue.opacity(0.3), lineWidth: 0.5))
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                    .padding(.top, 4)
                }
            }
        }
    }

    private var sevenNightsCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                NoopSectionLabel(isNightWorker ? "Your last seven sleeps" : "Your last seven")
                Spacer()
                Text("dashes — your own need, 7h 05m")
                    .font(NoopHTMLFont.sans(10.5))
                    .foregroundStyle(NoopHTMLColor.faint)
            }

            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    Canvas { context, size in
                        var need = Path()
                        let y = size.height - (22 + 92 * 7.083 / 8.4)
                        need.move(to: CGPoint(x: 0, y: y))
                        need.addLine(to: CGPoint(x: size.width, y: y))
                        context.stroke(need, with: .color(NoopHTMLColor.night.opacity(0.55)), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    }
                    .allowsHitTesting(false)

                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(Array(Self.nights.enumerated()), id: \.offset) { index, night in
                            let selected = index == selectedNightIndex
                            Button {
                                withAnimation(.easeOut(duration: 0.18)) {
                                    navigation.selectedRestDay = Self.nights.count - 1 - index
                                    selectedStage = nil
                                }
                            } label: {
                                VStack(spacing: 6) {
                                    Text(selected ? String(format: "%.1fh", night.value) : "")
                                        .font(NoopHTMLFont.sans(11, weight: .semibold))
                                        .foregroundStyle(NoopHTMLColor.ink)
                                        .frame(height: 18)
                                        .padding(.horizontal, selected ? 7 : 0)
                                        .background(selected ? Color(hex: 0x6E7DB8).opacity(0.9) : .clear, in: Capsule())
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(
                                            selected
                                                ? LinearGradient(colors: [Color(hex: 0xA9B6E8), Color(hex: 0x6E7DB8)], startPoint: .top, endPoint: .bottom)
                                                : LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.08)], startPoint: .top, endPoint: .bottom)
                                        )
                                        .frame(height: 92 * night.value / 8.4)
                                        .shadow(color: selected ? Color(hex: 0x6E7DB8).opacity(0.35) : .clear, radius: 9, y: 5)
                                    Text(night.day)
                                        .font(NoopHTMLFont.sans(11.5, weight: selected ? .semibold : .medium))
                                        .foregroundStyle(selected ? NoopHTMLColor.ink : NoopHTMLColor.faint)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(width: proxy.size.width, height: 132, alignment: .bottom)
            }
            .frame(height: 132)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 13)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private var sleepShapeCard: some View {
        VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .firstTextBaseline) {
                    NoopSectionLabel("The shape of it")
                    Spacer()
                    Text(selectedNight.window)
                        .font(NoopHTMLFont.sans(11))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .monospacedDigit()
                }
                Text(selectedNight.verdict)
                    .font(NoopHTMLFont.sans(14))
                    .foregroundStyle(NoopHTMLColor.ink)
                    .noopAct1LineBox(fontSize: 14, ratio: 1.5)

                Button {
                    withAnimation(.easeOut(duration: 0.22)) { showHypnogram.toggle() }
                } label: {
                    VStack(spacing: 9) {
                        Act1StageStrip(selectedStage: selectedStage)
                        .frame(height: 10)
                        .clipShape(Capsule())

                        HStack(spacing: 8) {
                            Text("Deep 1h 34m · REM 1h 48m · Light 3h 42m")
                                .font(NoopHTMLFont.sans(11.5))
                                .foregroundStyle(NoopHTMLColor.muted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.86)
                                .allowsTightening(true)
                            Spacer()
                            Text(showHypnogram ? "Hide the night" : "See the whole night")
                                .font(NoopHTMLFont.sans(11.5, weight: .semibold))
                                .foregroundStyle(NoopHTMLColor.night)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                }
                .buttonStyle(.plain)

                if showHypnogram {
                    VStack(spacing: 12) {
                        Act1Hypnogram(selectedStage: selectedStage)
                            .frame(height: 84)
                        HStack {
                            Text(selectedNight.axis[0]); Spacer()
                            Text(selectedNight.axis[1]); Spacer()
                            Text(selectedNight.axis[2]); Spacer()
                            Text(selectedNight.axis[3])
                        }
                        .font(NoopHTMLFont.sans(10.5))
                        .foregroundStyle(NoopHTMLColor.faint)
                        stageRows
                        Text(selectedStage == nil
                             ? "Tap a stage to pick it out of the night"
                             : "Showing \(["awake", "light", "REM", "deep"][selectedStage!]) only — tap again to show all")
                            .font(NoopHTMLFont.sans(10.5))
                            .foregroundStyle(NoopHTMLColor.faint)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 4)
                    }
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
        }
        .padding(.horizontal, 17)
        .padding(.top, 17)
        .padding(.bottom, 15)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private var stageRows: some View {
        let rows = [
            ("Deep", "1h 34m", 0.61, 3, Color(hex: 0x5D6BC4)),
            ("REM", "1h 48m", 0.70, 2, Color(hex: 0x4FB8E8)),
            ("Light", "3h 42m", 0.88, 1, NoopHTMLColor.nightLight),
            ("Awake", "8m", 0.07, 0, Color.white.opacity(0.22))
        ]
        return VStack(spacing: 3) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                let selected = selectedStage == row.3
                let dimmed = selectedStage != nil && !selected
                Button {
                    withAnimation(.easeOut(duration: 0.18)) {
                        selectedStage = selected ? nil : row.3
                    }
                } label: {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 3).fill(row.4).frame(width: 10, height: 10)
                        Text(row.0).frame(width: 40, alignment: .leading)
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.06))
                                Capsule().fill(row.4).frame(width: proxy.size.width * row.2)
                            }
                        }
                        .frame(height: 6)
                        Text(row.1).frame(width: 54, alignment: .trailing).foregroundStyle(NoopHTMLColor.ink)
                    }
                    .font(NoopHTMLFont.sans(12, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? NoopHTMLColor.ink : NoopHTMLColor.copy)
                    .padding(.horizontal, 6)
                    .frame(height: 31)
                    .background(selected ? Color.white.opacity(0.06) : .clear, in: RoundedRectangle(cornerRadius: 10))
                    .opacity(dimmed ? 0.45 : 1)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var savedJournalRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(NoopHTMLColor.blueInk)
                .frame(width: 16, height: 16)
                .background(NoopHTMLColor.blue, in: Circle())
            Text("Logged \(isNightWorker ? "06:50" : "22:41") — good day, no drinks, 1 note")
                .font(NoopHTMLFont.sans(12.5))
                .foregroundStyle(NoopHTMLColor.inkSoft)
            Spacer()
            Button("Edit") { navigation.show(.nightJournal) }
                .font(NoopHTMLFont.sans(12, weight: .semibold))
                .foregroundStyle(NoopHTMLColor.blue)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 42)
        .background(NoopHTMLColor.blue.opacity(0.09), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(NoopHTMLColor.blue.opacity(0.22), lineWidth: 0.5))
    }

    // MARK: - Tonight

    private var tonightScreen: some View {
        NoopScreen(bottomInset: 124, topInset: 56) {
            VStack(spacing: 0) {
                Act1BackHeader(label: isNightWorker ? "Before you sleep" : "Tonight") { navigation.reset(to: .rest) }

                VStack(spacing: 9) {
                    Text("LIGHTS OUT BY")
                        .font(NoopHTMLFont.sans(12.5, weight: .semibold))
                        .tracking(1.25)
                        .foregroundStyle(NoopHTMLColor.muted)
                    Text(activeBedtimes[selectedBedtime].time)
                        .font(NoopHTMLFont.act1Outfit200(82))
                        .tracking(-3.69)
                        .monospacedDigit()
                        .frame(height: 77.08, alignment: .top)
                        .offset(y: -13)
                    Text("\(activeBedtimes[selectedBedtime].length) before your \(alarmTime) alarm")
                        .font(NoopHTMLFont.sans(14))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .monospacedDigit()
                }
                .padding(.top, 14)
                .padding(.bottom, 26)

                VStack(spacing: 10) {
                    HStack(spacing: 6) {
                        ForEach(Array(activeBedtimes.enumerated()), id: \.offset) { index, stop in
                            let selected = index == selectedBedtime
                            Button {
                                selectedBedtime = index
                                bedtimeCommitted = false
                            } label: {
                                VStack(spacing: 4) {
                                    Text(stop.time)
                                        .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                                        .foregroundStyle(selected ? NoopHTMLColor.ink : NoopHTMLColor.copy)
                                    Text(stop.length)
                                        .font(NoopHTMLFont.sans(10))
                                        .foregroundStyle(selected ? NoopHTMLColor.blue : NoopHTMLColor.faint)
                                }
                                .padding(.horizontal, 4)
                                .padding(.top, 11)
                                .padding(.bottom, 10)
                                .frame(maxWidth: .infinity)
                                .background(selected ? NoopHTMLColor.blue.opacity(0.16) : Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 15))
                                .overlay(RoundedRectangle(cornerRadius: 15).stroke(selected ? NoopHTMLColor.blue.opacity(0.55) : NoopHTMLColor.border, lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text(activeBedtimes[selectedBedtime].note)
                        .font(NoopHTMLFont.serif(16.5))
                        .foregroundStyle(NoopHTMLColor.inkSoft)
                        .noopAct1LineBox(fontSize: 16.5, ratio: 1.45)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 2)
                        .padding(.top, 2)
                        .padding(.bottom, 6)

                    VStack(spacing: 0) {
                        tonightReason("Sleep debt · 1h 20m", note: "Pulls tonight twenty minutes earlier than your usual", value: "−20m", blue: true)
                        Divider().overlay(NoopHTMLColor.border).frame(height: 0.5)
                        tonightReason("Yesterday · easy", note: "A walk and nothing else. Nothing extra to pay back.", value: "0")
                        Divider().overlay(NoopHTMLColor.border).frame(height: 0.5)
                        tonightReason("Your own need · 7h 05m", note: "Measured across your last ninety nights, not a population average", value: "90n")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))

                    VStack(spacing: 0) {
                        tonightToggle(
                            glyph: .alarm,
                            title: isNightWorker ? "Wake me between 15:10 and 15:40" : "Wake me between 06:10 and 06:40",
                            detail: "Whichever moment you're closest to light sleep",
                            isOn: smartWake
                        ) { smartWake.toggle() }
                        Divider().overlay(NoopHTMLColor.border).frame(height: 0.5)
                        tonightToggle(
                            glyph: .bell,
                            title: "Buzz me to wind down at \(windDownTime)",
                            detail: "One buzz on the wrist. No notification.",
                            isOn: windDownBuzz
                        ) { windDownBuzz.toggle() }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                    .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))

                    if bedtimeCommitted {
                        HStack(spacing: 12) {
                            Act1CheckDisc(size: 18)
                            Text("Set — lights out \(activeBedtimes[selectedBedtime].time)\(windDownBuzz ? ", buzz at \(windDownTime)" : ", no wind-down buzz")")
                                .font(NoopHTMLFont.sans(13.5))
                                .foregroundStyle(NoopHTMLColor.inkSoft)
                            Spacer()
                            Button("Change") { bedtimeCommitted = false }
                                .font(NoopHTMLFont.sans(12.5, weight: .semibold))
                                .foregroundStyle(NoopHTMLColor.blue)
                        }
                        .padding(.horizontal, 18)
                        .frame(height: 54)
                        .background(NoopHTMLColor.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(NoopHTMLColor.blue.opacity(0.28), lineWidth: 0.5))
                        .padding(.top, 4)
                    } else {
                        Button("Set tonight") { bedtimeCommitted = true }
                            .font(NoopHTMLFont.sans(15, weight: .semibold))
                            .foregroundStyle(NoopHTMLColor.blueInk)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(NoopHTMLColor.blue, in: RoundedRectangle(cornerRadius: 18))
                            .buttonStyle(NoopHTMLPressStyle())
                            .padding(.top, 4)
                    }

                    Text("\(rhythmLine) Nothing here is a target — miss it and the next read simply says you missed it.")
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .noopAct1LineBox(fontSize: 11.5, ratio: 1.6)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.top, 2)
                }
            }
        }
    }

    private func tonightReason(_ title: String, note: String, value: String, blue: Bool = false) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(NoopHTMLFont.sans(13.5, weight: .semibold))
                Text(note)
                    .font(NoopHTMLFont.sans(12))
                    .foregroundStyle(NoopHTMLColor.copy)
                    .noopAct1LineBox(fontSize: 12, ratio: 1.5)
            }
            Spacer(minLength: 6)
            Text(value)
                .font(NoopHTMLFont.outfit(17))
                .foregroundStyle(blue ? NoopHTMLColor.blue : NoopHTMLColor.faint)
        }
        .frame(minHeight: 68)
    }

    private func tonightToggle(glyph: NoopCanonicalGlyphName, title: String, detail: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 13) {
            NoopCanonicalGlyph(name: glyph, size: 21, color: NoopHTMLColor.night)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.88)
                    .allowsTightening(true)
                Text(detail).font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.muted)
            }
            Spacer(minLength: 4)
            Act1Toggle(isOn: isOn, action: action)
        }
        .frame(minHeight: 64)
    }

    // MARK: - Why

    private var whyScreen: some View {
        NoopScreen(topInset: 56) {
            VStack(spacing: 0) {
                Act1BackHeader(label: selectedNightOffset == 0 ? (isNightWorker ? "Why that sleep" : "Why last night") : "Why \(selectedNight.shortDate)") { back(to: .rest) }

                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 9) {
                        Circle()
                            .fill(RadialGradient(colors: [Color(hex: 0x9FE2FB), Color(hex: 0x2FB2F0), Color(hex: 0x0A5F92)], center: .topLeading, startRadius: 0, endRadius: 22))
                            .frame(width: 22, height: 22)
                            .shadow(color: NoopHTMLColor.blue.opacity(0.5), radius: 6)
                        Text("SVEA")
                            .font(NoopHTMLFont.sans(11, weight: .semibold))
                            .tracking(1.43)
                            .foregroundStyle(NoopHTMLColor.muted)
                    }

                    Text(selectedNight.whyHeadline)
                        .font(NoopHTMLFont.serif(29))
                        .foregroundStyle(NoopHTMLColor.ink)
                        .tracking(-0.29)
                        .noopAct1LineBox(fontSize: 29, ratio: 1.22)
                    Text(whyParagraphOneDisplay)
                        .font(NoopHTMLFont.sans(14.5))
                        .foregroundStyle(Color(hex: 0xB7C3C9))
                        .tracking(-0.25)
                        .noopAct1LineBox(fontSize: 14.5, ratio: 1.68)
                        .padding(.top, -4)
                        .padding(.bottom, -2)
                    whyParagraphTwoText
                        .foregroundStyle(Color(hex: 0xB7C3C9))
                        .tracking(-0.25)
                        .noopAct1LineBox(fontSize: 14.5, ratio: 1.68)
                }
                .padding(.top, 10)
                .padding(.horizontal, 2)

                VStack(alignment: .leading, spacing: 8) {
                    Text("WHAT THE NIGHT WAS MADE OF")
                        .font(NoopHTMLFont.sans(10, weight: .semibold))
                        .tracking(1.3)
                        .foregroundStyle(NoopHTMLColor.muted)
                        .padding(.leading, 2)
                    ForEach(Array(selectedNight.causes.enumerated()), id: \.offset) { index, cause in
                        causeCard(cause, index: index)
                    }
                }
                .padding(.top, 20)

                VStack(alignment: .leading, spacing: 14) {
                    Text("The strap can't measure your bedroom. Room temperature here is inferred from skin temperature — treat it as a good guess, not a reading.")
                        .noopAct1LineBox(fontSize: 11.5, ratio: 1.65)
                    Text(rhythmLine)
                        .noopAct1LineBox(fontSize: 11.5, ratio: 1.65)
                    Button { navigation.push(.tonight) } label: {
                        HStack(spacing: 9) {
                            Text("Take this into tonight")
                            NoopA4CSSChevron(direction: .right, color: NoopHTMLColor.blue)
                        }
                        .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                        .foregroundStyle(NoopHTMLColor.blue)
                        .padding(.horizontal, 17)
                        .padding(.vertical, 12)
                        .background(NoopHTMLColor.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(NoopHTMLColor.blue.opacity(0.3), lineWidth: 0.5))
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                }
                .font(NoopHTMLFont.sans(11.5))
                .foregroundStyle(NoopHTMLColor.faint)
                .padding(.top, 18)
                .padding(.horizontal, 2)
            }
        }
    }

    private func causeCard(_ cause: Act1Cause, index: Int) -> some View {
        let open = expandedCause == index
        return Button {
            withAnimation(.easeOut(duration: 0.2)) { expandedCause = open ? -1 : index }
        } label: {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(cause.good ? NoopHTMLColor.blue : Color(hex: 0xF2B45C))
                        .frame(width: 9, height: 9)
                        .background(
                            Circle()
                                .fill((cause.good ? NoopHTMLColor.blue : Color(hex: 0xF2B45C)).opacity(0.14))
                                .frame(width: 17, height: 17)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cause.title).font(NoopHTMLFont.sans(13.5, weight: .semibold))
                        Text(cause.meta).font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color(hex: 0x7F8A85))
                    }
                    Spacer(minLength: 4)
                    Text(cause.effect)
                        .font(NoopHTMLFont.sans(11.5, weight: .semibold))
                        .foregroundStyle(cause.good ? NoopHTMLColor.blueLight : Color(hex: 0xF3C888))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(
                            (cause.good ? NoopHTMLColor.blue : Color(hex: 0xF2B45C)).opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                }
                if open {
                    VStack(alignment: .leading, spacing: 11) {
                        Text(cause.detail)
                            .font(NoopHTMLFont.sans(13))
                            .foregroundStyle(Color(hex: 0xB7C3C9))
                            .noopAct1LineBox(fontSize: 13, ratio: 1.62)
                        if cause.hasTemperatureChart {
                            VStack(spacing: 6) {
                                Act1TemperatureChart()
                                    .frame(height: 46)
                                HStack {
                                    Text(selectedNight.axis[0]); Spacer()
                                    Text(selectedNight.axis[1]); Spacer()
                                    Text(selectedNight.warmestLabel); Spacer()
                                    Text(selectedNight.axis[3])
                                }
                                .font(NoopHTMLFont.sans(10.5))
                                .foregroundStyle(NoopHTMLColor.faint)
                            }
                        }
                    }
                    .padding(.top, 1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(open ? Color.white.opacity(0.055) : NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(open ? Color.white.opacity(0.13) : NoopHTMLColor.border, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Debt

    private var debtScreen: some View {
        let model = Self.debtModels[debtRange] ?? Self.debtModels["14 nights"]!
        let contextualPoint = max(0, model.values.count - 1 - selectedNightOffset)
        let point = min(debtPoint ?? contextualPoint, model.values.count - 1)
        return NoopScreen(topInset: 56) {
            VStack(spacing: 0) {
                Act1BackHeader(label: "Sleep debt") { back(to: .rest) }

                VStack(spacing: 16) {
                    HStack(spacing: 6) {
                        ForEach(["14 nights", "30 nights", "3 months"], id: \.self) { item in
                            let selected = item == debtRange
                            Button {
                                debtRange = item
                                debtPoint = nil
                            } label: {
                                Text(item)
                                    .font(NoopHTMLFont.sans(12.5, weight: selected ? .semibold : .medium))
                                    .foregroundStyle(selected ? Color(hex: 0x0D1120) : NoopHTMLColor.copy)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 38)
                                    .background(selected ? NoopHTMLColor.night : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 13))
                                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(selected ? .clear : Color.white.opacity(0.07), lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(Self.formatDebt(model.values[point]))
                                .font(NoopHTMLFont.act1Outfit200(52))
                                .tracking(-2.08)
                                .scaleEffect(x: 1.07, y: 1, anchor: .leading)
                                .frame(width: 163, height: 52, alignment: .topLeading)
                                .offset(x: 2, y: -3)
                            Text("behind")
                                .font(NoopHTMLFont.sans(13))
                                .foregroundStyle(NoopHTMLColor.copy)
                        }
                        Text("against your own need of 7h 05m a night")
                            .font(NoopHTMLFont.sans(13.5))
                            .foregroundStyle(NoopHTMLColor.copy)
                            .noopAct1LineBox(fontSize: 13.5, ratio: 1.55)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 10) {
                        NoopSectionLabel("Running balance · \(debtRange)")
                        Act1DebtChart(
                            values: model.values,
                            selectedIndex: point,
                            day: debtLabel(model.labels[point]),
                            value: "\(Self.formatDebt(model.values[point])) behind"
                        ) { debtPoint = $0 }
                        .frame(height: 118)
                        HStack {
                            Text(debtLabel(model.axis[0])); Spacer()
                            Text(debtLabel(model.axis[1])); Spacer()
                            Text(debtLabel(model.axis[2])); Spacer()
                            Text(debtLabel(model.axis[3]))
                        }
                        .font(NoopHTMLFont.sans(10.5))
                        .foregroundStyle(NoopHTMLColor.faint)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 13)
                    .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible())], spacing: 8) {
                        ForEach(Array(model.stats.enumerated()), id: \.offset) { _, stat in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(stat.0.uppercased())
                                    .font(NoopHTMLFont.sans(10.5, weight: .semibold))
                                    .tracking(1.05)
                                    .foregroundStyle(NoopHTMLColor.muted)
                                Text(stat.1)
                                    .font(NoopHTMLFont.outfit(19))
                                    .monospacedDigit()
                            }
                            .padding(.horizontal, 15)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(NoopHTMLColor.border, lineWidth: 0.5))
                        }
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        NoopSectionLabel("What moves it, for you")
                            .padding(.top, 13)
                            .padding(.bottom, 4)
                        ForEach(Array(Self.correlates.enumerated()), id: \.offset) { index, correlate in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(correlate.0).font(NoopHTMLFont.sans(13.5))
                                    Text(correlate.1).font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.faint)
                                }
                                Spacer()
                                Text(correlate.2)
                                    .font(NoopHTMLFont.outfit(17))
                                    .foregroundStyle(correlate.3 ? Color(hex: 0xF2B45C) : NoopHTMLColor.blue)
                            }
                            .frame(minHeight: 58)
                            if index < Self.correlates.count - 1 { Divider().overlay(NoopHTMLColor.border).frame(height: 0.5) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))

                    Text(model.read)
                        .font(NoopHTMLFont.sans(14))
                        .foregroundStyle(Color(hex: 0xB7C3C9))
                        .noopAct1LineBox(fontSize: 14, ratio: 1.65)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 2)
                }
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Context and helpers

    private var whyParagraphTwoText: Text {
        let phrase = "0.4°C warmer"
        guard let range = selectedNight.whyParagraphTwo.range(of: phrase) else {
            return Text(selectedNight.whyParagraphTwo)
                .font(NoopHTMLFont.sans(14.5))
        }
        let prefix = String(selectedNight.whyParagraphTwo[..<range.lowerBound])
        let suffix = String(selectedNight.whyParagraphTwo[range.upperBound...])
        return Text(prefix).font(NoopHTMLFont.sans(14.5))
            + Text(phrase).font(NoopHTMLFont.serif(16, italic: true))
            + Text(suffix).font(NoopHTMLFont.sans(14.5))
    }

    /// Chromium's `text-wrap: pretty` keeps this final phrase together. SwiftUI uses a
    /// greedy line breaker, so preserve the canonical break explicitly for the matching copy.
    private var whyParagraphOneDisplay: String {
        selectedNight.whyParagraphOne.replacingOccurrences(
            of: " instead of after two hours.",
            with: " instead of\nafter two hours."
        )
    }

    private var selectedNightOffset: Int {
        min(max(navigation.selectedRestDay, 0), Self.nights.count - 1)
    }

    private var selectedNightIndex: Int {
        Self.nights.count - 1 - selectedNightOffset
    }

    private var selectedNight: Act1Night {
        let base = Self.nights[selectedNightIndex]
        guard isNightWorker else { return base }
        let latest = selectedNightOffset == 0
        return Act1Night(
            day: base.day,
            date: base.date,
            shortDate: latest ? "that sleep" : base.shortDate,
            value: base.value,
            hours: base.hours,
            window: Self.nightWindows[selectedNightIndex],
            verdict: base.verdict,
            delta: base.delta,
            reason: latest
                ? "Asleep 22 minutes faster than usual — that's most of it. The room warmed up after 1pm."
                : base.reason,
            whyHeadline: latest ? "You slept well, for a day sleep." : base.whyHeadline,
            whyParagraphOne: latest
                ? "You were asleep by 08:10 — twenty-two minutes faster than you usually manage after a shift — and your deep sleep arrived in the first ninety minutes instead of after two hours."
                : base.whyParagraphOne,
            whyParagraphTwo: latest
                ? "One thing cost you: from about 1pm your skin ran 0.4°C warmer than a normal sleep and you surfaced twice, briefly. On past day sleeps that pattern has been the afternoon getting into the room, not you."
                : base.whyParagraphTwo,
            axis: ["08:10", "10:30", "13:00", "15:22"],
            warmestLabel: "13:00 — warmest",
            causes: Self.nightShiftCauses
        )
    }

    private var ringRead: String {
        let short = 7.083 - selectedNight.value
        if short > 0.12 {
            return isNightWorker
                ? "The ring stops short by \(Int((short * 60).rounded())) minutes — see why that sleep went that way"
                : "The ring stops short by \(Int((short * 60).rounded())) minutes — see why last night went that way"
        }
        return "A closed ring. See what the night was made of"
    }

    private var windDownTime: String {
        let parts = activeBedtimes[selectedBedtime].time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return "22:30" }
        let total = (parts[0] * 60 + parts[1] - 40 + 24 * 60) % (24 * 60)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private var activeBedtimes: [Act1Bedtime] { isNightWorker ? Self.nightShiftBedtimes : Self.bedtimes }
    private var alarmTime: String { isNightWorker ? "15:25" : "06:25" }
    private var isNightWorker: Bool { NoopScheduleInference.isNightWorker(kind: scheduleKind) }
    private var rhythmLine: String {
        isNightWorker
            ? "You work nights, so none of this is anchored to darkness — it follows your own pattern."
            : "Built from your own ninety-sleep pattern, not the clock."
    }

    private func debtLabel(_ label: String) -> String {
        isNightWorker && label == "Last night" ? "Last sleep" : label
    }

    private func back(to fallback: NoopRoute) {
        navigation.canGoBack ? navigation.back() : navigation.reset(to: fallback)
    }

    private static func formatDebt(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        return hours > 0 ? "\(hours)h \(String(format: "%02d", remainder))m" : "\(remainder)m"
    }
}

// MARK: - Act 1 graphic components

private struct Act1BackHeader: View {
    let label: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .overlay(Circle().stroke(Color.white.opacity(0.09), lineWidth: 0.5))
                    NoopA4CSSChevron(direction: .left, color: NoopHTMLColor.inkSoft)
                        .offset(x: -1)
                }
                .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            Text(label)
                .font(NoopHTMLFont.sans(13.5))
                .foregroundStyle(NoopHTMLColor.copy)
            Spacer(minLength: 0)
        }
        .frame(height: 34)
        .padding(.horizontal, -2)
        .padding(.bottom, 8)
    }
}

private struct Act1LinkRow: View {
    let title: String
    let detail: String
    let glyph: NoopCanonicalGlyphName
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                NoopCanonicalGlyph(name: glyph, size: 21, color: NoopHTMLColor.night)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(NoopHTMLFont.sans(14.5, weight: .semibold))
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text(detail)
                        .font(NoopHTMLFont.sans(12))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .noopAct1LineBox(fontSize: 12, ratio: 1.5)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                NoopA4CSSChevron(direction: .right, color: NoopHTMLColor.faint)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(NoopHTMLColor.border, lineWidth: 0.5))
        }
        .buttonStyle(NoopHTMLPressStyle())
    }
}

private struct Act1CheckDisc: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(NoopHTMLColor.blue)
            Canvas { context, canvas in
                var path = Path()
                path.move(to: CGPoint(x: canvas.width * 0.31, y: canvas.height * 0.52))
                path.addLine(to: CGPoint(x: canvas.width * 0.45, y: canvas.height * 0.67))
                path.addLine(to: CGPoint(x: canvas.width * 0.72, y: canvas.height * 0.36))
                context.stroke(path, with: .color(NoopHTMLColor.blueInk), style: StrokeStyle(lineWidth: 1.5, lineCap: .square, lineJoin: .miter))
            }
        }
        .frame(width: size, height: size)
    }
}

private struct Act1Toggle: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? NoopHTMLColor.blue : Color.white.opacity(0.09))
                    .overlay(Capsule().stroke(Color.white.opacity(isOn ? 0.14 : 0.16), lineWidth: 0.5))
                Circle()
                    .fill(NoopHTMLColor.ink)
                    .frame(width: 24, height: 24)
                    .padding(2)
                    .shadow(color: .black.opacity(0.45), radius: 1.5, y: 1)
            }
            .frame(width: 46, height: 28)
        }
        .buttonStyle(.plain)
        .animation(.timingCurve(0.34, 1.25, 0.64, 1, duration: 0.24), value: isOn)
    }
}

private struct Act1SleepRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let hours: String
    let delta: String
    let progress: Double
    let selectedStage: Int?

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let pulsePhase = time.truncatingRemainder(dividingBy: 9) / 9
            let pulse = (1 - cos(pulsePhase * 2 * .pi)) / 2
            let rotation = reduceMotion ? 0 : time.truncatingRemainder(dividingBy: 90) / 90 * 360

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: Color(hex: 0x5D6BC4).opacity(0.42), location: 0),
                                .init(color: .clear, location: 0.62)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 145
                        )
                    )
                    .frame(width: 290, height: 290)
                    .blur(radius: 18)
                    .opacity(reduceMotion ? 0.85 : 0.7 + pulse * 0.3)

                Circle()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: Color(hex: 0x4FB8E8).opacity(0.16), location: 0),
                                .init(color: .clear, location: 0.66)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 98
                        )
                    )
                    .frame(width: 196, height: 196)
                    .blur(radius: 10)

                Act1NightSpeckField()
                    .frame(width: 250, height: 250)
                    .rotationEffect(.degrees(rotation))

                Act1RingCanvas(progress: progress, selectedStage: selectedStage)
                    .frame(width: 232, height: 232)

                VStack(spacing: 0) {
                    Text(hours)
                        .font(NoopHTMLFont.act1Outfit200(46))
                        .tracking(-1.84)
                        .monospacedDigit()
                        .frame(height: 46, alignment: .top)
                        .offset(y: -8)
                        .shadow(color: .black.opacity(0.6), radius: 12, y: 2)
                    Text("ASLEEP")
                        .font(NoopHTMLFont.sans(10.5, weight: .semibold))
                        .tracking(2.1)
                        .foregroundStyle(Color(hex: 0x93A0A6))
                        .padding(.top, 8)
                    Text(delta)
                        .font(NoopHTMLFont.sans(11.5, weight: .semibold))
                        .foregroundStyle(delta.contains("over") || delta.contains("even") ? NoopHTMLColor.blueLight : NoopHTMLColor.inkSoft)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            delta.contains("over") || delta.contains("even") ? NoopHTMLColor.blue.opacity(0.13) : Color.white.opacity(0.07),
                            in: RoundedRectangle(cornerRadius: 9)
                        )
                }

                Text("the ring closes at your need · 7h 05m")
                    .font(NoopHTMLFont.sans(10.5))
                    .foregroundStyle(NoopHTMLColor.faint)
                    .position(x: 181, y: 241)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 250)
    }
}

private struct Act1RingCanvas: View {
    let progress: Double
    let selectedStage: Int?

    private let stages = [1, 1, 2, 3, 3, 3, 2, 2, 3, 3, 2, 1, 0, 1, 2, 3, 3, 2, 2, 1, 1, 2, 2, 3, 2, 1, 0, 1, 1, 2, 2, 1, 1, 0]

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 232, size.height / 232)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = 96 * scale
            let start = 138.0
            let fullSweep = 264.0
            let usedSweep = fullSweep * min(1, max(0, progress))

            func point(_ degrees: Double) -> CGPoint {
                let radians = degrees * .pi / 180
                return CGPoint(x: center.x + cos(radians) * radius, y: center.y + sin(radians) * radius)
            }
            func arc(from a0: Double, to a1: Double) -> Path {
                var path = Path()
                let steps = max(2, Int(ceil(abs(a1 - a0) / 2)))
                for index in 0...steps {
                    let angle = a0 + (a1 - a0) * Double(index) / Double(steps)
                    let p = point(angle)
                    if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
                }
                return path
            }
            func color(_ stage: Int) -> Color {
                let base = [Color.white.opacity(0.22), NoopHTMLColor.nightLight, Color(hex: 0x4FB8E8), Color(hex: 0x5D6BC4)][stage]
                return selectedStage == nil || selectedStage == stage ? base : Color.white.opacity(0.08)
            }
            func width(_ stage: Int) -> CGFloat { [5, 10, 14, 18][stage] * scale }

            context.stroke(
                arc(from: start, to: start + fullSweep),
                with: .color(Color.white.opacity(0.06)),
                style: StrokeStyle(lineWidth: 17 * scale, lineCap: .round, lineJoin: .round)
            )

            let segmentSweep = usedSweep / Double(stages.count)
            context.drawLayer { glow in
                glow.addFilter(.blur(radius: 9 * scale))
                for (index, stage) in stages.enumerated() {
                    let a0 = start + Double(index) * segmentSweep + 0.3
                    let a1 = start + Double(index + 1) * segmentSweep - 0.3
                    glow.stroke(arc(from: a0, to: a1), with: .color(color(stage)), style: StrokeStyle(lineWidth: width(stage), lineCap: .round, lineJoin: .round))
                }
            }
            for (index, stage) in stages.enumerated() {
                let a0 = start + Double(index) * segmentSweep + 0.3
                let a1 = start + Double(index + 1) * segmentSweep - 0.3
                context.stroke(arc(from: a0, to: a1), with: .color(color(stage)), style: StrokeStyle(lineWidth: width(stage), lineCap: .round, lineJoin: .round))
            }

            let wake = point(start + usedSweep)
            context.fill(Path(ellipseIn: CGRect(x: wake.x - 3.2 * scale, y: wake.y - 3.2 * scale, width: 6.4 * scale, height: 6.4 * scale)), with: .color(NoopHTMLColor.ink))
        }
    }
}

private struct Act1NightSpeck: Identifiable {
    let id: Int
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let opacity: Double
}

private struct Act1NightSpeckField: View {
    private static func hash(_ value: Int) -> Double {
        let raw = sin(Double(value) * 91.7 + 74.3) * 21_374.1234
        return raw - floor(raw)
    }

    private static let specks: [Act1NightSpeck] = (0..<42).map { index in
        let angle = Double(index) * 2.39996 + hash(index) * 1.3
        let radius = 0.78 + hash(index + 60) * 0.3
        let size = 1.1 + hash(index + 21) * 2.2
        return Act1NightSpeck(
            id: index,
            x: CGFloat((50 + cos(angle) * radius * 47) / 100 * 250),
            y: CGFloat((50 + sin(angle) * radius * 47) / 100 * 250),
            size: CGFloat(size),
            opacity: 0.16 + hash(index + 5) * 0.4
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Self.specks) { speck in
                Circle()
                    .fill(Color(hex: 0xD6DEFF).opacity(speck.opacity))
                    .frame(width: speck.size, height: speck.size)
                    .shadow(color: Color(hex: 0x7A8ADC).opacity(0.7), radius: speck.size * 1.3)
                    .position(x: speck.x, y: speck.y)
            }
        }
    }
}

private struct Act1StageStrip: View {
    let selectedStage: Int?

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = max(0, proxy.size.width - 6)
            HStack(spacing: 2) {
                segment(stage: 3, color: Color(hex: 0x5D6BC4), width: availableWidth * 0.22)
                segment(stage: 2, color: Color(hex: 0x4FB8E8), width: availableWidth * 0.25)
                segment(stage: 1, color: NoopHTMLColor.nightLight, width: availableWidth * 0.51)
                segment(stage: 0, color: Color.white.opacity(0.22), width: availableWidth * 0.02)
            }
        }
    }

    private func segment(stage: Int, color: Color, width: CGFloat) -> some View {
        Rectangle()
            .fill(selectedStage == nil || selectedStage == stage ? color : Color.white.opacity(0.09))
            .frame(width: width)
    }
}

private struct Act1Hypnogram: View {
    let selectedStage: Int?
    private let stages = [1, 1, 2, 3, 3, 3, 2, 2, 3, 3, 2, 1, 0, 1, 2, 3, 3, 2, 2, 1, 1, 2, 2, 3, 2, 1, 0, 1, 1, 2, 2, 1, 1, 0]

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(stages.enumerated()), id: \.offset) { _, stage in
                RoundedRectangle(cornerRadius: 3)
                    .fill(selectedStage == nil || selectedStage == stage ? color(stage) : Color.white.opacity(0.07))
                    .frame(minWidth: 3, maxWidth: .infinity)
                    .frame(height: [20, 40, 60, 82][stage])
                    .shadow(color: selectedStage == stage ? color(stage) : .clear, radius: 5)
            }
        }
    }

    private func color(_ stage: Int) -> Color {
        [Color.white.opacity(0.22), NoopHTMLColor.nightLight, Color(hex: 0x4FB8E8), Color(hex: 0x5D6BC4)][stage]
    }
}

private struct Act1TemperatureChart: View {
    private let values = [0.0, -1, -2, -1, 0, 1, 0, 2, 6, 10, 12, 9, 5, 2, 1]

    var body: some View {
        Canvas { context, size in
            let sx = size.width / 280
            let sy = size.height / 46
            var baseline = Path()
            baseline.move(to: CGPoint(x: 0, y: 30 * sy))
            baseline.addLine(to: CGPoint(x: size.width, y: 30 * sy))
            context.stroke(baseline, with: .color(Color.white.opacity(0.08)), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))

            var line = Path()
            for (index, value) in values.enumerated() {
                let point = CGPoint(x: CGFloat(index) / CGFloat(values.count - 1) * size.width, y: CGFloat(30 - value * 1.75) * sy)
                if index == 0 { line.move(to: point) } else { line.addLine(to: point) }
            }
            context.stroke(line, with: .color(Color(hex: 0xF2B45C)), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            let dot = CGPoint(x: 176 * sx, y: 9 * sy)
            let circle = Path(ellipseIn: CGRect(x: dot.x - 3.6, y: dot.y - 3.6, width: 7.2, height: 7.2))
            context.fill(circle, with: .color(Color(hex: 0xF2B45C)))
            context.stroke(circle, with: .color(NoopHTMLColor.card), lineWidth: 2.4)
        }
    }
}

private struct Act1DebtChart: View {
    let values: [Int]
    let selectedIndex: Int
    let day: String
    let value: String
    let onSelect: (Int) -> Void

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let maxValue = Double(values.max() ?? 1) * 1.18
            let points = values.enumerated().map { index, value in
                CGPoint(
                    x: CGFloat(index) / CGFloat(max(1, values.count - 1)) * size.width,
                    y: 118 - CGFloat(Double(value) / maxValue) * 104
                )
            }
            let selected = points[min(max(0, selectedIndex), points.count - 1)]
            let bubbleX = min(size.width * 0.84, max(size.width * 0.16, selected.x))
            let bubbleTop = max(0, selected.y - 48)

            ZStack(alignment: .topLeading) {
                Canvas { context, canvas in
                    var baseline = Path()
                    baseline.move(to: CGPoint(x: 0, y: 118))
                    baseline.addLine(to: CGPoint(x: canvas.width, y: 118))
                    context.stroke(baseline, with: .color(Color.white.opacity(0.1)), lineWidth: 1)

                    var area = Path()
                    area.move(to: CGPoint(x: 0, y: 118))
                    for point in points { area.addLine(to: point) }
                    area.addLine(to: CGPoint(x: canvas.width, y: 118))
                    area.closeSubpath()
                    context.fill(area, with: .color(NoopHTMLColor.night.opacity(0.14)))

                    var line = Path()
                    if let first = points.first {
                        line.move(to: first)
                        for point in points.dropFirst() { line.addLine(to: point) }
                        context.stroke(line, with: .color(NoopHTMLColor.night), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                    }

                    var marker = Path()
                    marker.move(to: CGPoint(x: selected.x, y: 0))
                    marker.addLine(to: CGPoint(x: selected.x, y: 118))
                    context.stroke(marker, with: .color(Color.white.opacity(0.24)), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    let circle = Path(ellipseIn: CGRect(x: selected.x - 5, y: selected.y - 5, width: 10, height: 10))
                    context.fill(circle, with: .color(NoopHTMLColor.night))
                    context.stroke(circle, with: .color(NoopHTMLColor.card), lineWidth: 3)
                }

                HStack(spacing: 0) {
                    ForEach(values.indices, id: \.self) { index in
                        Button { onSelect(index) } label: { Color.clear }
                            .buttonStyle(.plain)
                    }
                }

                VStack(spacing: 1) {
                    Text(day)
                        .font(NoopHTMLFont.sans(10.5))
                        .foregroundStyle(NoopHTMLColor.copy)
                    Text(value)
                        .font(NoopHTMLFont.sans(12.5, weight: .semibold))
                        .foregroundStyle(NoopHTMLColor.ink)
                        .monospacedDigit()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(hex: 0x1E242C).opacity(0.94), in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                .fixedSize()
                .position(x: bubbleX, y: bubbleTop + 21)
                .allowsHitTesting(false)
            }
        }
    }
}

private struct Act1LineBoxModifier: ViewModifier {
    let fontSize: CGFloat
    let ratio: CGFloat
    let nativeRatio: CGFloat

    func body(content: Content) -> some View {
        let native = fontSize * nativeRatio
        let target = fontSize * ratio
        let leading = max(0, target - native)
        content
            .lineSpacing(leading)
            .padding(.vertical, leading / 2)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private extension View {
    func noopAct1LineBox(fontSize: CGFloat, ratio: CGFloat, nativeRatio: CGFloat = 1.22) -> some View {
        modifier(Act1LineBoxModifier(fontSize: fontSize, ratio: ratio, nativeRatio: nativeRatio))
    }
}

// MARK: - Act 1 models

private struct Act1Cause {
    let title: String
    let meta: String
    let effect: String
    let good: Bool
    let detail: String
    var hasTemperatureChart = false
}

private struct Act1Night {
    let day: String
    let date: String
    let shortDate: String
    let value: Double
    let hours: String
    let window: String
    let verdict: String
    let delta: String
    let reason: String
    let whyHeadline: String
    let whyParagraphOne: String
    let whyParagraphTwo: String
    let axis: [String]
    let warmestLabel: String
    let causes: [Act1Cause]
}

private struct Act1Bedtime {
    let time: String
    let length: String
    let note: String
}

private struct Act1DebtModel {
    let values: [Int]
    let labels: [String]
    let axis: [String]
    let stats: [(String, String)]
    let read: String
}

private extension NoopAct1Screens {
    static let defaultCauses = [
        Act1Cause(
            title: "In bed at 23:14",
            meta: "26 minutes earlier than your usual",
            effect: "most of it",
            good: true,
            detail: "Across ninety nights, your bedtime explains more of your sleep than anything else you do — more than training, more than caffeine. Twenty-six minutes early bought you roughly forty minutes of sleep, because you also fell asleep faster."
        ),
        Act1Cause(
            title: "The room ran warm",
            meta: "Skin temp +0.4°C after 3am, two brief wakes",
            effect: "cost ~18m deep",
            good: false,
            detail: "Your skin held warmer than a normal night from about 3am, and both wakes sit inside that window. The pattern looks like the room rather than you — nothing else in the night moved.",
            hasTemperatureChart: true
        ),
        Act1Cause(
            title: "No alcohol",
            meta: "Nothing logged yesterday",
            effect: "nothing to account for",
            good: true,
            detail: "On nights you drink, you lose about fifty minutes and most of it comes out of deep sleep in the first half. None of that is in this night."
        ),
        Act1Cause(
            title: "Last coffee 11:40",
            meta: "Eleven hours before lights out",
            effect: "clear",
            good: true,
            detail: "Caffeine only shows up in your nights when it lands after 2pm. This was long clear of that."
        )
    ]

    static let nightShiftCauses = [
        Act1Cause(
            title: "Asleep by 08:10",
            meta: "22 minutes faster than your usual",
            effect: "most of it",
            good: true,
            detail: "Across ninety sleeps, how fast you get to bed after a shift explains more of your sleep than anything else you do. Twenty-two minutes bought you roughly forty minutes of sleep, because you also fell asleep quicker."
        ),
        Act1Cause(
            title: "The room warmed up",
            meta: "Skin temp +0.4°C after 13:00, two brief wakes",
            effect: "cost ~18m deep",
            good: false,
            detail: "Your skin held warmer from about 1pm, and both wakes sit inside that window. Blackout curtains fix the light; they do not fix the heat.",
            hasTemperatureChart: true
        ),
        Act1Cause(
            title: "No alcohol",
            meta: "Nothing logged after the shift",
            effect: "nothing to account for",
            good: true,
            detail: "On sleeps after a drink you lose about fifty minutes, and most of it comes out of deep sleep in the first half. None of that is in this one."
        ),
        Act1Cause(
            title: "Last coffee 04:40",
            meta: "Three and a half hours before bed",
            effect: "borderline",
            good: false,
            detail: "This one is close. Caffeine inside four hours of your bed time shows up in your sleeps as a shallower first block — worth pulling earlier in the shift."
        )
    ]

    static let nightWindows = ["09:52 – 15:22", "07:40 – 15:00", "09:52 – 15:22", "09:16 – 15:22", "08:22 – 15:22", "08:46 – 15:22", "08:10 – 15:22"]

    static let nights: [Act1Night] = [
        Act1Night(day: "S", date: "Sunday 16 August", shortDate: "Sunday", value: 5.5, hours: "5h 30m", window: "01:12 – 06:42", verdict: "Late night. Short, but you slept through it.", delta: "1h 35m short", reason: "A late bedtime did most of it. Once asleep, the night held together.", whyHeadline: "The night was short because it started late.", whyParagraphOne: "You got into bed at 01:12, well after your own usual window. That explains almost all of the missing hour and a half.", whyParagraphTwo: "Once asleep, you held the night together. There is no second problem hiding in the stages.", axis: ["01:12", "03:00", "05:00", "06:42"], warmestLabel: "04:10 — warmest", causes: defaultCauses),
        Act1Night(day: "M", date: "Monday 17 August", shortDate: "Monday", value: 7.3, hours: "7h 18m", window: "23:02 – 06:20", verdict: "The best night of the week — and the earliest bedtime.", delta: "13m over", reason: "Your earliest bedtime of the week gave you the fullest night.", whyHeadline: "The earliest bedtime made the best night.", whyParagraphOne: "You were in bed at 23:02 and asleep quickly. Deep sleep arrived in the first block, exactly where it usually does on your clearest nights.", whyParagraphTwo: "Nothing else asked for an explanation. This one was timing, not a trick.", axis: ["23:02", "01:20", "04:00", "06:20"], warmestLabel: "03:20 — warmest", causes: defaultCauses),
        Act1Night(day: "T", date: "Tuesday 18 August", shortDate: "Tuesday", value: 5.5, hours: "5h 30m", window: "23:48 – 05:18", verdict: "Woke twice after midnight and gave up early.", delta: "1h 35m short", reason: "Two wakes after midnight shortened the final block.", whyHeadline: "Two wakes broke the back half of the night.", whyParagraphOne: "The first half looked ordinary. After midnight you surfaced twice and the second wake became the end of the night.", whyParagraphTwo: "The room was warmer through that window. Treat that as a good guess, not a thermometer reading.", axis: ["23:48", "01:20", "03:20", "05:18"], warmestLabel: "03:20 — warmest", causes: defaultCauses),
        Act1Night(day: "W", date: "Wednesday 19 August", shortDate: "Wednesday", value: 6.1, hours: "6h 06m", window: "23:36 – 05:42", verdict: "Fine. A little short, nothing more to say.", delta: "59m short", reason: "A slightly late start and early wake. Nothing unusual inside it.", whyHeadline: "A little short, and otherwise ordinary.", whyParagraphOne: "You started later than your own middle and woke before the final light block had finished.", whyParagraphTwo: "The stages, temperature and pulse all stayed inside your normal shape. There is nothing else to solve.", axis: ["23:36", "01:30", "03:50", "05:42"], warmestLabel: "03:30 — warmest", causes: defaultCauses),
        Act1Night(day: "T", date: "Thursday 20 August", shortDate: "Thursday", value: 7.0, hours: "7h 00m", window: "23:20 – 06:20", verdict: "Solid and unbroken.", delta: "5m short — even", reason: "A steady night sitting almost exactly on your own need.", whyHeadline: "Nothing got in the way.", whyParagraphOne: "You went down close to your usual time and stayed asleep through the final block.", whyParagraphTwo: "Five minutes below your measured need is noise. This was an even night.", axis: ["23:20", "01:40", "04:00", "06:20"], warmestLabel: "03:20 — warmest", causes: defaultCauses),
        Act1Night(day: "F", date: "Friday 21 August", shortDate: "Friday", value: 6.6, hours: "6h 36m", window: "00:04 – 06:40", verdict: "Late to bed, then slept the whole way through.", delta: "29m short", reason: "The late start cost half an hour; the sleep itself stayed intact.", whyHeadline: "The night was good once it started.", whyParagraphOne: "You were twenty-nine minutes late against your own need, and the final number follows that almost exactly.", whyParagraphTwo: "No wake, temperature or pulse pattern added a second cost.", axis: ["00:04", "02:10", "04:30", "06:40"], warmestLabel: "03:40 — warmest", causes: defaultCauses),
        Act1Night(day: "S", date: "Saturday 22 August", shortDate: "last night", value: 7.2, hours: "7h 12m", window: "23:14 – 06:41", verdict: "Full night, and deep sleep came early.", delta: "7m over", reason: "You were in bed 26 minutes early — that's most of it. The room ran warm after 3am.", whyHeadline: "You slept well, and you nearly slept better.", whyParagraphOne: "Getting into bed at 23:14 did most of the work — that's 26 minutes earlier than your usual, and your deep sleep arrived in the first ninety minutes instead of after two hours.", whyParagraphTwo: "One thing cost you: after 3am your skin ran 0.4°C warmer than a normal night and you surfaced twice, briefly. On past nights that pattern has been the room, not you.", axis: ["23:14", "01:30", "04:00", "06:41"], warmestLabel: "03:20 — warmest", causes: defaultCauses)
    ]

    static let bedtimes = [
        Act1Bedtime(time: "22:30", length: "7h 55m", note: "An hour of debt gone by morning. Ambitious for a Saturday, but it works."),
        Act1Bedtime(time: "22:50", length: "7h 35m", note: "Clears half an hour of debt. A stretch, and worth it if the evening allows."),
        Act1Bedtime(time: "23:10", length: "7h 15m", note: "Clears twenty minutes of debt and still leaves you an evening. This is the one."),
        Act1Bedtime(time: "23:30", length: "6h 55m", note: "Holds you exactly level — nothing paid back, nothing added."),
        Act1Bedtime(time: "23:50", length: "6h 35m", note: "Adds half an hour to what you already owe. Fine once, not twice.")
    ]

    static let nightShiftBedtimes = [
        Act1Bedtime(time: "07:30", length: "7h 55m", note: "An hour of debt gone before the street wakes up. Ambitious straight off a shift, but it works."),
        Act1Bedtime(time: "07:50", length: "7h 35m", note: "Clears half an hour of debt. Worth it on the days you get home clean."),
        Act1Bedtime(time: "08:10", length: "7h 15m", note: "Clears twenty minutes of debt and still leaves you a wind-down. This is the one."),
        Act1Bedtime(time: "08:30", length: "6h 55m", note: "Holds you exactly level — nothing paid back, nothing added."),
        Act1Bedtime(time: "08:50", length: "6h 35m", note: "Adds half an hour to what you already owe. Fine once, not twice.")
    ]

    static let correlates: [(String, String, String, Bool)] = [
        ("Nights you drink", "9 nights logged", "−52 min", true),
        ("Screens in bed", "17 nights logged", "−21 min", true),
        ("After a hard session", "21 nights", "+14 min", false),
        ("Weekends", "8 nights", "+34 min", false)
    ]

    static let debtModels: [String: Act1DebtModel] = [
        "14 nights": Act1DebtModel(
            values: [35, 23, 68, 48, 54, 109, 91, 69, 81, 72, 107, 78, 83, 80],
            labels: ["3 Aug", "4 Aug", "5 Aug", "6 Aug", "7 Aug", "8 Aug", "9 Aug", "10 Aug", "11 Aug", "12 Aug", "13 Aug", "14 Aug", "15 Aug", "Last night"],
            axis: ["3 Aug", "7 Aug", "11 Aug", "Last night"],
            stats: [("Your need", "7h 05m"), ("Clear nights", "4 of 14"), ("Paid back", "51m"), ("Worst night", "1h 35m")],
            read: "You have been between one and two hours behind all fortnight, and never worse than that. Two ordinary nights clears it — there is no catching up to do."
        ),
        "30 nights": Act1DebtModel(
            values: [95, 120, 86, 64, 40, 72, 108, 131, 96, 70, 55, 88, 120, 74, 49, 66, 102, 84, 60, 95, 80],
            labels: ["18 Jul", "19 Jul", "21 Jul", "22 Jul", "23 Jul", "25 Jul", "26 Jul", "27 Jul", "29 Jul", "30 Jul", "31 Jul", "1 Aug", "2 Aug", "4 Aug", "5 Aug", "7 Aug", "8 Aug", "10 Aug", "12 Aug", "14 Aug", "Last night"],
            axis: ["18 Jul", "26 Jul", "4 Aug", "Last night"],
            stats: [("Your need", "7h 05m"), ("Clear nights", "11 of 30"), ("Paid back", "3h 12m"), ("Worst night", "2h 10m")],
            read: "The spike mid-month was one week of late nights, and you paid it back without doing anything special. This is a balance, not a wound."
        ),
        "3 months": Act1DebtModel(
            values: [180, 150, 120, 96, 140, 168, 120, 88, 60, 95, 130, 102, 74, 110, 140, 96, 70, 105, 88, 80],
            labels: ["19 May", "26 May", "2 Jun", "9 Jun", "13 Jun", "18 Jun", "23 Jun", "28 Jun", "3 Jul", "8 Jul", "13 Jul", "18 Jul", "22 Jul", "26 Jul", "30 Jul", "3 Aug", "6 Aug", "9 Aug", "13 Aug", "Last night"],
            axis: ["19 May", "18 Jun", "18 Jul", "Last night"],
            stats: [("Your need", "7h 02m"), ("Clear nights", "38 of 90"), ("Paid back", "9h 40m"), ("Worst night", "3h 05m")],
            read: "Three months ago you were routinely three hours behind. You are not any more, and that happened without a single early alarm."
        )
    ]
}
