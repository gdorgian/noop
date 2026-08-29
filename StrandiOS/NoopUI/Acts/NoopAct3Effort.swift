import Foundation
import SwiftUI

struct NoopAct3Screens: View {
    @ObservedObject var navigation: NoopNavigation

    @AppStorage("noop.schedule.kind") private var scheduleKind = "mostly-nights"
    @SceneStorage("noop.act3.rest-day") private var restDay = false
    @State private var detailWorkout: NoopWorkout?

    var body: some View {
        switch navigation.route {
        case .session:
            sessionScreen
        case .pick:
            pickerScreen
        case .ready:
            readyScreen
        case .live:
            liveScreen
        case .intervals:
            intervalsScreen
        case .detail:
            detailScreen
        default:
            sessionScreen
        }
    }

    // MARK: - Today's session

    private var sessionScreen: some View {
        NoopScreen(topInset: 58) {
            VStack(spacing: 0) {
                Act3HomeHeader(
                    title: isNightWorker ? "This shift's session" : "Today's session",
                    eyebrow: isNightWorker ? "Wednesday, before your shift" : "Wednesday, 14:20"
                ) {
                    NoopBatteryChip(percent: 52) { navigation.push(.strap) }
                }

                VStack(spacing: 9) {
                    heroCard
                    whyCard
                    weeklyLoadCard

                    Button {
                        detailWorkout = .steadyRide
                        navigation.push(.detail)
                    } label: {
                        HStack(spacing: 13) {
                            NoopCanonicalGlyph(name: .bike, size: 21, color: NoopHTMLColor.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(isNightWorker ? "Before last shift" : "Yesterday") · Steady ride")
                                    .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                                Text("42 min · in zone 82% of the time")
                                    .font(NoopHTMLFont.sans(11.5))
                                    .foregroundStyle(Color(hex: 0x7F8A85))
                            }
                            Spacer()
                            NoopChevron()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 15)
                        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(NoopHTMLColor.border, lineWidth: 0.5))
                    }
                    .buttonStyle(NoopHTMLPressStyle())

                    VStack(alignment: .leading, spacing: 9) {
                        Text("Rather not today?")
                            .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                        Text("Skipping costs you nothing. There is no streak to break here — a rest day is a training decision, and Noop will fold it into tomorrow's number.")
                            .font(NoopHTMLFont.sans(12))
                            .foregroundStyle(NoopHTMLColor.copy)
                            .act3LineBox(fontSize: 12, ratio: 1.55)
                        Button {
                            restDay.toggle()
                        } label: {
                            Text(restDay ? "Today is a rest day" : "Mark today as rest")
                                .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                                .foregroundStyle(restDay ? Color(hex: 0xC9D0EE) : NoopHTMLColor.inkSoft)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(restDay ? NoopHTMLColor.night.opacity(0.22) : Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 15))
                                .overlay(RoundedRectangle(cornerRadius: 15).stroke(restDay ? NoopHTMLColor.night.opacity(0.45) : Color.white.opacity(0.12), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 15)
                    .padding(.bottom, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(NoopHTMLColor.night.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(NoopHTMLColor.night.opacity(0.18), lineWidth: 0.5))

                    Text("One session, one reason, two buttons. Noop will not offer you a plan for the week — it only knows what today can take.")
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .act3LineBox(fontSize: 11.5, ratio: 1.6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 2)
                }
                .padding(.top, 14)
            }
        }
    }

    private var heroCard: some View {
        let model = workoutModel
        let chosen = navigation.workoutChosenByUser
        let warm = chosen ? !model.isInsideToday : true
        return VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                NoopSectionLabel(chosen ? "Your choice" : "Dialled back for today", color: warm ? Color(hex: 0xF2B45C) : NoopHTMLColor.blue)
                Spacer()
                Text(chosen ? (model.isInsideToday ? "inside today" : "above today") : "was 6 × 1 min hard")
                    .font(NoopHTMLFont.sans(11))
                    .foregroundStyle(Color(hex: 0x7F8A85))
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(model.name)
                    .font(NoopHTMLFont.outfit(29, weight: .light))
                    .tracking(-0.85)
                Text(model.reason)
                    .font(NoopHTMLFont.sans(13.5))
                    .foregroundStyle(Color(hex: 0xB7C3C9))
                    .lineSpacing(3)
            }

            HStack(spacing: 14) {
                heroMetric("\(model.duration)", label: "minutes")
                Rectangle().fill(Color.white.opacity(0.12)).frame(width: 0.5, height: 30)
                heroMetric("\(model.low)–\(model.high)", label: "bpm to hold")
                Rectangle().fill(Color.white.opacity(0.12)).frame(width: 0.5, height: 30)
                heroMetric("\(model.load)", label: "load it adds")
            }
            .padding(.top, 12)
            .padding(.bottom, 2)

            VStack(spacing: 8) {
                Act3ActionButton("Get ready", height: 54, radius: 18, fontSize: 15, primary: true) { navigation.push(.ready) }
                Act3ActionButton("Choose something else", height: 46, radius: 16) { navigation.push(.pick) }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            NoopCSSLinearGradient(
                colors: warm
                    ? [Color(hex: 0xF2B45C).opacity(0.15), Color(hex: 0xF2B45C).opacity(0.03)]
                    : [NoopHTMLColor.blue.opacity(0.16), NoopHTMLColor.blue.opacity(0.03)],
                degrees: 158
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .overlay(RoundedRectangle(cornerRadius: 24).stroke((warm ? Color(hex: 0xF2B45C) : NoopHTMLColor.blue).opacity(0.3), lineWidth: 0.5))
    }

    private func heroMetric(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(NoopHTMLFont.outfit(21, weight: .light))
                .monospacedDigit()
            Text(label)
                .font(NoopHTMLFont.sans(10.5))
                .foregroundStyle(NoopHTMLColor.muted)
        }
    }

    private var whyCard: some View {
        let chosen = navigation.workoutChosenByUser
        let rows = chosen
            ? [
                Act3Why(label: "Slept 7h 12m, seven minutes over your need", note: "Deep came early. Nothing owed from last night.", verdict: "in zone", good: true),
                Act3Why(label: "Breathing rate 14.2 a minute", note: "Sitting on your baseline, where it has been for three weeks.", verdict: "in zone", good: true),
                Act3Why(label: "Two hard days back to back", note: "Sunday and Monday both went over 80. Tuesday was almost nothing, which is not the same as recovered.", verdict: "legs 2 days out", good: false)
            ]
            : [
                Act3Why(label: "Slept 7h 12m, seven minutes over your\nneed", note: "Deep came early. Nothing owed from\nlast night.", verdict: "in zone", good: true),
                Act3Why(label: "Breathing rate 16.1 a minute", note: "Almost two above your normal and outside\nyour zone for the first time in three weeks.\nUsually a warm room or something you are\nfighting off.", verdict: "out of zone", good: false),
                Act3Why(label: "Two hard days back to back", note: "Sunday and Monday both went over 80.\nTuesday was almost nothing, which is\nnot the same as recovered.", verdict: "legs 2 days out", good: false)
            ]
        return VStack(alignment: .leading, spacing: 13) {
            NoopSectionLabel(chosen ? "Why today can take it" : "Why this, and not the intervals")
            VStack(spacing: 11) {
                ForEach(rows, id: \.label) { row in
                    HStack(alignment: .top, spacing: 11) {
                        ZStack {
                            Circle()
                                .fill((row.good ? NoopHTMLColor.blue : Color(hex: 0xF2B45C)).opacity(0.14))
                                .frame(width: 17, height: 17)
                            Circle()
                                .fill(row.good ? NoopHTMLColor.blue : Color(hex: 0xF2B45C))
                                .frame(width: 9, height: 9)
                        }
                            .frame(width: 9, height: 9)
                            .padding(.top, 5)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.label)
                                .font(NoopHTMLFont.sans(13))
                                .fixedSize(horizontal: false, vertical: true)
                            Text(row.note)
                                .font(NoopHTMLFont.sans(11.5))
                                .foregroundStyle(Color(hex: 0x7F8A85))
                                .act3LineBox(fontSize: 11.5, ratio: 1.5)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(alignment: .topTrailing) {
                            Act3VerdictChip(text: row.verdict, good: row.good)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 15)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private var weeklyLoadCard: some View {
        let values = [42, 0, 74, 86, 88, 12, workoutModel.load]
        let days = ["Thu", "Fri", "Sat", "Sun", "Mon", "Tue", "Wed"]
        return NoopHTMLCard(radius: 20, padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    NoopSectionLabel("Load, last seven days")
                    Spacer()
                    Text("302 total")
                        .font(NoopHTMLFont.sans(11))
                        .foregroundStyle(NoopHTMLColor.faint)
                }
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(values.indices, id: \.self) { index in
                        let today = index == values.count - 1
                        RoundedRectangle(cornerRadius: 4)
                            .fill(today ? .clear : values[index] > 78 ? Color(hex: 0xF2B45C) : values[index] == 0 ? Color.white.opacity(0.07) : NoopHTMLColor.blue.opacity(0.5))
                            .overlay {
                                if today {
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(
                                            workoutModel.isInsideToday ? NoopHTMLColor.blue.opacity(0.7) : Color(hex: 0xF2B45C).opacity(0.75),
                                            style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                                        )
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: max(3, CGFloat(values[index]) / 100 * 62))
                    }
                }
                .frame(height: 62, alignment: .bottom)
                HStack(spacing: 6) {
                    ForEach(days.indices, id: \.self) { index in
                        Text(days[index])
                            .font(NoopHTMLFont.sans(9.5, weight: index == days.count - 1 ? .semibold : .regular))
                            .foregroundStyle(index == days.count - 1 ? (workoutModel.isInsideToday ? NoopHTMLColor.blueLight : Color(hex: 0xF3C888)) : NoopHTMLColor.faint)
                            .frame(maxWidth: .infinity)
                    }
                }
                Text("Sunday and Monday were both hard, and the dashed bar is what today would add. Keeping it under fifty is the whole idea.")
                    .font(NoopHTMLFont.sans(11.5))
                    .foregroundStyle(Color(hex: 0x7F8A85))
                    .lineSpacing(3)
            }
        }
    }

    // MARK: - Picker

    private var pickerScreen: some View {
        NoopScreen(topInset: 56) {
            VStack(spacing: 0) {
                Act3BackHeader(label: "Today's session") { back(to: .session) }
                    .padding(.horizontal, -2)

                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Choose something else")
                            .font(NoopHTMLFont.outfit(25))
                            .tracking(-0.625)
                        Text("Nothing here is locked. Each one says what it would cost you today, and you decide anyway.")
                            .font(NoopHTMLFont.sans(13))
                            .foregroundStyle(NoopHTMLColor.copy)
                            .act3LineBox(fontSize: 13, ratio: 1.55)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 9) {
                        ForEach(NoopWorkout.allCases) { workout in
                            workoutOption(workout)
                        }
                    }

                    Text("Amber is not a wall. It means the cost is higher than today's readiness — you will feel it tomorrow, and the app will say so tonight.")
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .act3LineBox(fontSize: 11.5, ratio: 1.6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 2)
                }
                .padding(.top, 8)
            }
        }
    }

    private func workoutOption(_ workout: NoopWorkout) -> some View {
        let model = workout.act3
        let selected = navigation.selectedWorkout == workout
        return Button {
            navigation.selectedWorkout = workout
            navigation.workoutChosenByUser = true
            navigation.reset(to: .session)
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 13) {
                    Act3WorkoutGlyph(workout: workout, size: 21, color: model.isInsideToday ? NoopHTMLColor.blue : Color(hex: 0xF2B45C))
                        .frame(width: 21)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.name).font(NoopHTMLFont.sans(14.5, weight: .semibold))
                        Text("\(model.duration) min · \(model.low)–\(model.high) bpm · load \(model.load)")
                            .font(NoopHTMLFont.sans(11.5))
                            .foregroundStyle(Color(hex: 0x7F8A85))
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)
                    Text(workout == .intervals ? "harder than today\nallows" : model.fit)
                        .font(NoopHTMLFont.sans(10.5, weight: .semibold))
                        .foregroundStyle(model.isInsideToday ? NoopHTMLColor.blueLight : Color(hex: 0xF3C888))
                        .lineLimit(workout == .intervals ? 2 : 1)
                        .fixedSize(horizontal: true, vertical: true)
                        .frame(width: fitChipOuterWidth(for: workout) - 18, alignment: .trailing)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background((model.isInsideToday ? NoopHTMLColor.blue : Color(hex: 0xF2B45C)).opacity(0.13), in: RoundedRectangle(cornerRadius: 8))
                        .multilineTextAlignment(.trailing)
                }
                Text(model.note)
                    .font(NoopHTMLFont.sans(11.5))
                    .foregroundStyle(Color(hex: 0x7F8A85))
                    .act3LineBox(fontSize: 11.5, ratio: 1.5)
            }
            .padding(.horizontal, 16)
            .padding(.top, 15)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? NoopHTMLColor.blue.opacity(0.09) : NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(selected ? NoopHTMLColor.blue.opacity(0.34) : NoopHTMLColor.border, lineWidth: 0.5))
        }
        .buttonStyle(NoopHTMLPressStyle())
    }

    private func fitChipOuterWidth(for workout: NoopWorkout) -> CGFloat {
        switch workout {
        case .steadyRide: 72
        case .intervals: 136
        case .longWalk: 99
        case .strength: 121
        case .easySwim: 110
        }
    }

    // MARK: - Ready

    private var readyScreen: some View {
        let canvasWidth = UIScreen.main.bounds.width
        let canvasHeight = UIScreen.main.bounds.height
        return VStack(spacing: 0) {
            HStack {
                Button { navigation.reset(to: .session) } label: {
                    ZStack {
                        Circle().fill(Color.white.opacity(0.06)).overlay(Circle().stroke(NoopHTMLColor.borderStrong, lineWidth: 0.5))
                        NoopFixedChevron(direction: .left, color: NoopHTMLColor.inkSoft)
                            .offset(x: -1)
                    }
                    .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                Spacer()
                NoopSectionLabel("Ready")
                Spacer()
                Color.clear.frame(width: 34, height: 34)
            }
            .frame(width: max(0, canvasWidth - 36))
            .padding(.top, 56)

            VStack(spacing: 26) {
                VStack(spacing: 9) {
                    Act3WorkoutGlyph(workout: navigation.selectedWorkout, size: 30, color: NoopHTMLColor.blue)
                    Text(workoutModel.name)
                        .font(NoopHTMLFont.outfit(31, weight: .light))
                        .tracking(-0.9)
                        .multilineTextAlignment(.center)
                    Text("\(workoutModel.duration) minutes · hold \(workoutModel.low)–\(workoutModel.high) bpm")
                        .font(NoopHTMLFont.sans(13.5))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .monospacedDigit()
                }

                VStack(spacing: 10) {
                    zoneLadder
                    Text("Your target is the lit stretch: \(workoutModel.primaryZone.lowercased()) is where this session lives, and the watch will tell you once if you leave it.")
                        .font(NoopHTMLFont.sans(12.5))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .lineSpacing(3)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }

                VStack(spacing: 11) {
                    readyCheck("bell", "One buzz if you drift out of the zone, and one when you come back. Nothing else will interrupt you.")
                    readyCheck("timer", "Auto-pause at the lights. Stopped time is not counted against you.")
                    readyCheck("checkmark", "No ring to close, no medal at the end. The session is done\nwhen the minutes are done.")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(NoopHTMLColor.border, lineWidth: 0.5))
                // The canonical HTML uses content-box sizing here: width:100% plus
                // 16pt padding on each side intentionally overflows its 24pt gutter.
                .frame(width: max(0, canvasWidth - 15))
                // Report the canonical 24pt content width to the parent while
                // allowing the content-box card itself to overflow that gutter.
                .frame(width: max(0, canvasWidth - 48))
            }
            .frame(maxHeight: .infinity)
            .frame(width: max(0, canvasWidth - 48))
            .padding(.top, 20)

            VStack(spacing: 8) {
                Act3ActionButton("Start", height: 60, radius: 20, fontSize: 16, primary: true) {
                    navigation.beginSession(at: Date())
                    navigation.push(navigation.liveRoute)
                }
                .shadow(color: NoopHTMLColor.blue.opacity(0.3), radius: 13, y: 8)
                Button("Not now") { navigation.reset(to: .session) }
                    .font(NoopHTMLFont.sans(13))
                    .foregroundStyle(Color(hex: 0x7F8A85))
                    .frame(height: 44)
            }
            .frame(width: max(0, canvasWidth - 48))
            .padding(.top, 18)
            .padding(.bottom, 26)
        }
        .frame(width: canvasWidth, height: canvasHeight)
        .background(NoopHTMLColor.canvas)
    }

    private var zoneLadder: some View {
        VStack(spacing: 10) {
            GeometryReader { proxy in
                let usable = max(0, proxy.size.width - 12)
                HStack(spacing: 3) {
                    ForEach(Self.zones, id: \.name) { zone in
                        let selected = zone.high > workoutModel.low && zone.low < workoutModel.high
                        Rectangle()
                            .fill(selected ? zone.color : Color.white.opacity(0.07))
                            .frame(width: usable * CGFloat(zone.high - zone.low) / 150)
                    }
                }
            }
            .frame(height: 12)
            .clipShape(Capsule())
            GeometryReader { proxy in
                let usable = max(0, proxy.size.width - 12)
                HStack(spacing: 3) {
                    ForEach(Self.zones, id: \.name) { zone in
                        let selected = zone.high > workoutModel.low && zone.low < workoutModel.high
                        Text(zone.name)
                            .font(NoopHTMLFont.sans(9.5, weight: selected ? .semibold : .regular))
                            .foregroundStyle(selected ? NoopHTMLColor.inkSoft : NoopHTMLColor.faint)
                            .frame(width: usable * CGFloat(zone.high - zone.low) / 150)
                    }
                }
            }
            .frame(height: 12)
        }
    }

    private func readyCheck(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            NoopCanonicalGlyph(
                name: symbol == "bell" ? .bell : symbol == "timer" ? .timer : .check,
                size: 17,
                color: NoopHTMLColor.blue
            )
                .frame(width: 18)
            Text(text)
                .font(NoopHTMLFont.sans(12.5))
                .foregroundStyle(Color(hex: 0xB7C3C9))
                .lineLimit(2)
                .minimumScaleFactor(text.contains("\n") ? 0.94 : 1)
                .allowsTightening(text.contains("\n"))
                .act3LineBox(fontSize: 12.5, ratio: 1.5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
        }
    }

    // MARK: - Live effort

    private var liveScreen: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let elapsed = liveElapsed(at: timeline.date)
            let bpm = liveBPM(elapsed: elapsed)
            Act3LiveScreen(
                model: workoutModel,
                elapsed: navigation.sessionElapsedDisplay(at: timeline.date),
                bpm: bpm,
                paused: navigation.sessionPaused,
                pauseAction: { togglePause(at: timeline.date) },
                endAction: { navigation.endSession(navigation.selectedWorkout) }
            )
        }
    }

    private var intervalsScreen: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let elapsed = liveElapsed(at: timeline.date)
            Act3IntervalsScreen(
                model: workoutModel,
                elapsed: elapsed,
                paused: navigation.sessionPaused,
                pauseAction: { togglePause(at: timeline.date) },
                endAction: { navigation.endSession(navigation.selectedWorkout) }
            )
        }
    }

    private func liveElapsed(at date: Date) -> Int {
        navigation.sessionElapsed(at: date)
    }

    private func liveBPM(elapsed: Int) -> Int {
        let middle = Double(workoutModel.low + workoutModel.high) / 2
        return Int((middle + 9 * sin(Double(elapsed) / 7) + 4 * sin(Double(elapsed) / 2.4)).rounded())
    }

    private func togglePause(at date: Date) {
        navigation.toggleSessionPause(at: date)
    }

    // MARK: - Detail

    private var detailScreen: some View {
        let detailModel = (detailWorkout ?? navigation.historyWorkout ?? navigation.finishedWorkout ?? navigation.selectedWorkout).act3
        let detail = detailModel.detail
        return NoopScreen(topInset: 56) {
            VStack(spacing: 0) {
                // Change 3. From the finished-session arrival the user did not come from `session`,
                // so sending them there is a lie; every other arrival keeps the Act 3 back map.
                Act3BackHeader(label: detailBackLabel) {
                    // A push (from `session` or `history`) pops; the finished-session arrival is a
                    // reset, so it falls back to `today` rather than lying about where it came from.
                    navigation.canGoBack ? navigation.back() : navigation.reset(to: .today)
                }
                    .padding(.horizontal, -2)

                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(detailModel.name)
                            .font(NoopHTMLFont.outfit(27, weight: .light))
                            .tracking(-0.756)
                        Text("\(isNightWorker ? "Before last shift" : "Yesterday"), 17:04 · \(detail.durationLabel.split(separator: ":").first ?? "42") min · \(detail.distance) km")
                            .font(NoopHTMLFont.sans(13))
                            .foregroundStyle(NoopHTMLColor.copy)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 9), GridItem(.flexible())], spacing: 9) {
                        detailTile(detail.durationLabel, unit: "min", label: "moving time")
                        detailTile("\(detail.average)", unit: "bpm", label: "average pulse")
                        detailTile("\(detail.highest)", unit: "bpm", label: detail.highestCaption, warm: true)
                        detailTile("\(detail.inZone)", unit: "%", label: "of it inside the zone")
                    }

                    VStack(alignment: .leading, spacing: 11) {
                        HStack(alignment: .firstTextBaseline) {
                            NoopSectionLabel("Pulse against the zone")
                            Spacer()
                            Text("\(detailModel.low)–\(detailModel.high) asked")
                                .font(NoopHTMLFont.sans(11))
                                .foregroundStyle(NoopHTMLColor.faint)
                                .monospacedDigit()
                        }
                        Act3PulseChart(values: detail.pulse, low: detailModel.low, high: detailModel.high)
                            .frame(height: 104)
                        HStack { Text("17:04"); Spacer(); Text("17:18"); Spacer(); Text("17:32"); Spacer(); Text("17:46") }
                            .font(NoopHTMLFont.sans(10.5))
                            .foregroundStyle(NoopHTMLColor.faint)
                        Text(detail.chartRead)
                            .font(NoopHTMLFont.sans(11.5))
                            .foregroundStyle(Color(hex: 0x7F8A85))
                            .act3LineBox(fontSize: 11.5, ratio: 1.55)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))

                    NoopHTMLCard(radius: 22, padding: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            NoopSectionLabel("Where the effort went")
                            Act3EffortBar(easy: detail.easyMinutes, target: detail.targetMinutes, hard: detail.hardMinutes)
                                .frame(height: 12)
                                .clipShape(Capsule())
                            VStack(spacing: 10.5) {
                                effortRow("Easy, under the zone", value: "\(detail.easyMinutes)m", color: Color(hex: 0x4FB8E8))
                                effortRow("\(detailModel.primaryZone), the zone itself", value: "\(detail.targetMinutes)m", color: NoopHTMLColor.blue)
                                effortRow("Hard, the two hills", value: "\(detail.hardMinutes)m", color: Color(hex: 0xF2B45C))
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            NoopCanonicalGlyph(name: .moon, size: 18, color: NoopHTMLColor.night)
                            Text("What it cost you").font(NoopHTMLFont.sans(13.5, weight: .semibold))
                        }
                        detailCost("Added to tonight's sleep need", value: "+\(detail.sleepCost) min")
                        detailCost("Recovered by", value: detail.recoveredBy)
                        detailCost("Load added to the week", value: "\(detailModel.load) → \(302 + detailModel.load)")
                        Text("Effort is not free and Noop will not pretend otherwise. Tonight's sleep need went up because of this ride, and tomorrow's session already knows.")
                            .font(NoopHTMLFont.sans(11.5))
                            .foregroundStyle(NoopHTMLColor.copy)
                            .act3LineBox(fontSize: 11.5, ratio: 1.6)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(NoopHTMLColor.night.opacity(0.08), in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.night.opacity(0.2), lineWidth: 0.5))

                    NoopHTMLCard(radius: 22, padding: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            NoopSectionLabel("Svea")
                            Text(detail.svea)
                                .font(NoopHTMLFont.sans(14))
                                .foregroundStyle(Color(hex: 0xDCE3E0))
                                .act3LineBox(fontSize: 14, ratio: 1.65)
                        }
                    }

                    Text("No score, no grade, no medal. A session is a thing you did and a cost you paid, and both are written down plainly.")
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .act3LineBox(fontSize: 11.5, ratio: 1.6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 2)
                }
                .padding(.top, 9)
            }
        }
    }

    private func detailTile(_ value: String, unit: String, label: String, warm: Bool = false) -> some View {
        NoopHTMLCard(radius: 18, padding: 14) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(value)
                        .font(NoopHTMLFont.outfit(27, weight: .light))
                        .tracking(-0.7)
                        .foregroundStyle(warm ? Color(hex: 0xF3C888) : NoopHTMLColor.ink)
                    Text(unit).font(NoopHTMLFont.sans(10.5)).foregroundStyle(NoopHTMLColor.muted)
                }
                .frame(height: 29)
                Text(label).font(NoopHTMLFont.sans(11)).foregroundStyle(Color(hex: 0x7F8A85))
            }
        }
    }

    private func effortRow(_ title: String, value: String, color: Color) -> some View {
        HStack(spacing: 11) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 9, height: 9)
            Text(title).font(NoopHTMLFont.sans(13))
            Spacer()
            Text(value).font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.copy)
        }
    }

    private func detailCost(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(NoopHTMLFont.sans(12.5))
                .foregroundStyle(Color(hex: 0xB7C3C9))
            Spacer()
            Text(value)
                .font(NoopHTMLFont.sans(13, weight: .semibold))
                .monospacedDigit()
        }
    }

    private var workoutModel: Act3WorkoutModel { navigation.selectedWorkout.act3 }

    private var detailBackLabel: String {
        if navigation.historyWorkout != nil { return "Everything you logged" }
        return navigation.canGoBack ? "Session" : "Today"
    }
    private var isNightWorker: Bool { NoopScheduleInference.isNightWorker(kind: scheduleKind) }

    private func showDetail(for workout: NoopWorkout) {
        navigation.historyWorkout = nil
        detailWorkout = workout
        navigation.push(.detail)
    }

    private func back(to fallback: NoopRoute) {
        navigation.canGoBack ? navigation.back() : navigation.reset(to: fallback)
    }
}

private struct Act3HomeHeader<Trailing: View>: View {
    let title: String
    let eyebrow: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow)
                    .font(NoopHTMLFont.sans(13.5))
                    .foregroundStyle(NoopHTMLColor.copy)
                    .frame(height: 16.5, alignment: .top)
                Text(title)
                    .font(NoopHTMLFont.outfit(23))
                    .tracking(-0.46)
                    .frame(height: 26.45, alignment: .top)
            }
            Spacer(minLength: 0)
            trailing
        }
        .frame(height: 46.95, alignment: .top)
        .padding(.bottom, 4)
    }
}

private struct Act3BackHeader: View {
    let label: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .overlay(Circle().stroke(Color.white.opacity(0.09), lineWidth: 0.5))
                    NoopFixedChevron(direction: .left, color: NoopHTMLColor.inkSoft)
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
        .padding(.bottom, 8)
    }
}

private struct Act3ActionButton: View {
    let title: String
    let height: CGFloat
    let radius: CGFloat
    let fontSize: CGFloat
    let primary: Bool
    let action: () -> Void

    init(
        _ title: String,
        height: CGFloat,
        radius: CGFloat,
        fontSize: CGFloat = 13.5,
        primary: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.height = height
        self.radius = radius
        self.fontSize = fontSize
        self.primary = primary
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(NoopHTMLFont.sans(fontSize, weight: primary ? .semibold : .regular))
                .foregroundStyle(primary ? NoopHTMLColor.blueInk : NoopHTMLColor.inkSoft)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(primary ? NoopHTMLColor.blue : Color.clear, in: RoundedRectangle(cornerRadius: radius))
                .overlay(
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(primary ? Color.clear : Color.white.opacity(0.14), lineWidth: 0.5)
                )
        }
        .buttonStyle(NoopHTMLPressStyle())
    }
}

private struct Act3VerdictChip: View {
    let text: String
    let good: Bool

    var body: some View {
        let ink = good ? NoopHTMLColor.blueLight : Color(hex: 0xF3C888)
        let fill = good ? NoopHTMLColor.blue : Color(hex: 0xF2B45C)
        Text(text)
            .font(NoopHTMLFont.sans(10.5, weight: .semibold))
            .foregroundStyle(ink)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(fill.opacity(0.13), in: RoundedRectangle(cornerRadius: 7))
            .fixedSize()
    }
}

private struct Act3WorkoutGlyph: View {
    let workout: NoopWorkout
    let size: CGFloat
    let color: Color

    private var glyph: NoopCanonicalGlyphName {
        switch workout {
        case .steadyRide: .bike
        case .intervals: .bolt
        case .longWalk: .walk
        case .strength: .weight
        case .easySwim: .wave
        }
    }

    var body: some View {
        NoopCanonicalGlyph(name: glyph, size: size, color: color)
    }
}

private struct Act3LineBoxModifier: ViewModifier {
    let fontSize: CGFloat
    let ratio: CGFloat

    func body(content: Content) -> some View {
        let native = fontSize * 1.22
        let target = fontSize * ratio
        let leading = max(0, target - native)
        content
            .lineSpacing(leading)
            .padding(.vertical, leading / 2)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private extension View {
    func act3LineBox(fontSize: CGFloat, ratio: CGFloat) -> some View {
        modifier(Act3LineBoxModifier(fontSize: fontSize, ratio: ratio))
    }
}

private struct Act3HeartbeatOrb: View {
    let bpm: Int
    let zone: String
    let outside: Bool
    let paused: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date()
    @State private var frozenPhase: Double?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: paused || reduceMotion)) { timeline in
            let phase = reduceMotion ? 0 : (frozenPhase ?? heartbeatPhase(at: timeline.date, duration: 0.52))
            let scale = reduceMotion ? 1 : heartbeatValue(
                phase,
                points: [(0, 1), (0.09, 1.05), (0.18, 1.01), (0.27, 1.035), (0.42, 1), (1, 1)]
            )
            let glow = reduceMotion ? 0.4 : heartbeatValue(
                phase,
                points: [(0, 0.4), (0.09, 0.78), (0.18, 0.5), (0.27, 0.68), (0.42, 0.4), (1, 0.4)]
            )

            ZStack {
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [(outside ? Color(hex: 0xF2B45C) : NoopHTMLColor.blue).opacity(0.3), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 115
                        )
                    )
                    .frame(width: 210, height: 150)
                    .opacity(glow)
                VStack(spacing: 8) {
                    Text("\(bpm)")
                        .font(NoopHTMLFont.outfit200(92))
                        .tracking(-4.6)
                        .foregroundStyle(paused ? Color(hex: 0x7F8A85) : outside ? Color(hex: 0xFBDCAA) : Color(hex: 0xF6FDFF))
                        .monospacedDigit()
                        .scaleEffect(scale)
                    Text(zone.uppercased())
                        .font(NoopHTMLFont.sans(12.5, weight: .semibold))
                        .tracking(1.75)
                        .foregroundStyle(paused ? Color(hex: 0x7F8A85) : Color(hex: 0xF6FDFF).opacity(0.86))
                }
            }
        }
        .onChange(of: paused) { _, isPaused in
            if isPaused {
                frozenPhase = heartbeatPhase(at: Date(), duration: 0.52)
            } else if let phase = frozenPhase {
                startedAt = Date().addingTimeInterval(-phase * 0.52)
                frozenPhase = nil
            }
        }
    }

    private func heartbeatPhase(at date: Date, duration: Double) -> Double {
        max(0, date.timeIntervalSince(startedAt)).truncatingRemainder(dividingBy: duration) / duration
    }
}

private struct Act3HeartbeatReadout: View {
    let color: Color
    let bpm: Int
    let zone: String
    let paused: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date()
    @State private var frozenPhase: Double?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: paused || reduceMotion)) { timeline in
            let phase = reduceMotion ? 0 : (frozenPhase ?? heartbeatPhase(at: timeline.date))
            let scale = reduceMotion ? 1 : heartbeatValue(
                phase,
                points: [(0, 1), (0.09, 1.05), (0.18, 1.01), (0.27, 1.035), (0.42, 1), (1, 1)]
            )
            let glow = reduceMotion ? 0.4 : heartbeatValue(
                phase,
                points: [(0, 0.4), (0.09, 0.78), (0.18, 0.5), (0.27, 0.68), (0.42, 0.4), (1, 0.4)]
            )

            HStack(spacing: 9) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                stops: [
                                    .init(color: color.opacity(0.34), location: 0),
                                    .init(color: color.opacity(0), location: 0.70)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 17
                            )
                        )
                        .frame(width: 34, height: 34)
                        .opacity(glow)
                    NoopCanonicalGlyph(name: .heart, size: 15, color: color)
                }
                .frame(width: 15, height: 15)

                Text("\(bpm)")
                    .font(NoopHTMLFont.outfit(22, weight: .light))
                    .tracking(-0.44)
                    .monospacedDigit()
                    .scaleEffect(scale)

                Text(zone)
                    .font(NoopHTMLFont.sans(11.5))
                    .foregroundStyle(NoopHTMLColor.copy)
            }
        }
        .onChange(of: paused) { _, isPaused in
            if isPaused {
                frozenPhase = heartbeatPhase(at: Date())
            } else if let phase = frozenPhase {
                startedAt = Date().addingTimeInterval(-phase * 0.44)
                frozenPhase = nil
            }
        }
    }

    private func heartbeatPhase(at date: Date) -> Double {
        max(0, date.timeIntervalSince(startedAt)).truncatingRemainder(dividingBy: 0.44) / 0.44
    }
}

private func heartbeatValue(_ phase: Double, points: [(Double, CGFloat)]) -> CGFloat {
    guard let first = points.first else { return 1 }
    if phase <= first.0 { return first.1 }
    for index in 1..<points.count {
        let previous = points[index - 1]
        let next = points[index]
        if phase <= next.0 {
            let span = max(0.0001, next.0 - previous.0)
            let amount = CGFloat((phase - previous.0) / span)
            return previous.1 + (next.1 - previous.1) * amount
        }
    }
    return points.last?.1 ?? first.1
}

private struct Act3CircleControl: View {
    let glyph: NoopCanonicalGlyphName
    let active: Bool
    let isStop: Bool
    let action: () -> Void

    var body: some View {
        let fill = isStop
            ? NoopHTMLColor.amber.opacity(0.14)
            : active ? NoopHTMLColor.blue : Color.white.opacity(0.08)
        let border = isStop
            ? NoopHTMLColor.amber.opacity(0.4)
            : active ? NoopHTMLColor.blue.opacity(0.6) : Color.white.opacity(0.16)
        let ink = isStop ? NoopHTMLColor.amber : active ? NoopHTMLColor.blueInk : NoopHTMLColor.ink

        Button(action: action) {
            NoopCanonicalGlyph(name: glyph, size: 20, color: ink)
                .frame(width: 62, height: 62)
                .background(fill, in: Circle())
                .overlay(Circle().stroke(border, lineWidth: 0.5))
        }
        .buttonStyle(NoopHTMLPressStyle())
    }
}

private struct Act3PulseChart: View {
    let values: [Double]
    let low: Int
    let high: Int

    var body: some View {
        Canvas { context, size in
            guard values.count > 1 else { return }
            let scale = min(size.width / 300, size.height / 104)
            let origin = CGPoint(x: (size.width - 300 * scale) / 2, y: (size.height - 104 * scale) / 2)
            func y(_ value: Double) -> CGFloat {
                origin.y + (104 - (value - 88) / 62 * 96) * scale
            }

            let top = y(Double(high))
            let bottom = y(Double(low))
            context.fill(
                Path(CGRect(x: origin.x, y: top, width: 300 * scale, height: bottom - top)),
                with: .color(NoopHTMLColor.blue.opacity(0.16))
            )

            var line = Path()
            for (index, value) in values.enumerated() {
                let point = CGPoint(
                    x: origin.x + CGFloat(index) / CGFloat(values.count - 1) * 300 * scale,
                    y: y(value)
                )
                if index == 0 { line.move(to: point) } else { line.addLine(to: point) }
            }
            context.stroke(
                line,
                with: .color(NoopHTMLColor.blue),
                style: StrokeStyle(lineWidth: 2.2 * scale, lineCap: .round, lineJoin: .round)
            )
        }
    }
}

private struct Act3EffortBar: View {
    let easy: Int
    let target: Int
    let hard: Int

    var body: some View {
        GeometryReader { proxy in
            let total = max(1, easy + target + hard)
            let usable = max(0, proxy.size.width - 6)
            HStack(spacing: 3) {
                Rectangle().fill(Color(hex: 0x4FB8E8)).frame(width: usable * CGFloat(easy) / CGFloat(total))
                Rectangle().fill(NoopHTMLColor.blue).frame(width: usable * CGFloat(target) / CGFloat(total))
                Rectangle().fill(Color(hex: 0xF2B45C)).frame(width: usable * CGFloat(hard) / CGFloat(total))
            }
        }
    }
}

// MARK: - Live faces

private struct Act3LiveScreen: View {
    let model: Act3WorkoutModel
    let elapsed: Int
    let bpm: Int
    let paused: Bool
    let pauseAction: () -> Void
    let endAction: () -> Void

    private var over: Bool { bpm > model.high }
    private var under: Bool { bpm < model.low }
    private var outside: Bool { over || under }

    var body: some View {
        let canvasWidth = UIScreen.main.bounds.width
        let canvasHeight = UIScreen.main.bounds.height
        return VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Self.format(elapsed)).font(NoopHTMLFont.outfit(20, weight: .light)).monospacedDigit()
                    NoopSectionLabel("Elapsed")
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(model.name).font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.inkSoft)
                    Text("hold \(model.low)–\(model.high)").font(NoopHTMLFont.sans(10.5)).foregroundStyle(Color(hex: 0x7F8A85))
                }
            }

            Act3HeartbeatOrb(bpm: bpm, zone: zoneName, outside: outside, paused: paused)
            .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 9) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08)).frame(height: 4)
                        Capsule().fill(NoopHTMLColor.blue.opacity(0.42))
                            .frame(width: proxy.size.width * (position(model.high) - position(model.low)), height: 4)
                            .offset(x: proxy.size.width * position(model.low))
                        ZStack {
                            Circle()
                                .fill((outside ? Color(hex: 0xF2B45C) : NoopHTMLColor.blue).opacity(0.18))
                                .frame(width: 22, height: 22)
                            Circle()
                                .fill(outside ? Color(hex: 0xF2B45C) : NoopHTMLColor.blue)
                                .frame(width: 14, height: 14)
                                .shadow(color: Color.black.opacity(0.45), radius: 3, y: 2)
                        }
                            .frame(width: 14, height: 14)
                            .offset(x: proxy.size.width * position(bpm) - 7)
                    }
                    .frame(height: 24)
                }
                .frame(height: 24)
                Text(cue)
                    .font(NoopHTMLFont.sans(13))
                    .foregroundStyle(paused ? NoopHTMLColor.copy : outside ? Color(hex: 0xF3C888) : Color(hex: 0xB7C3C9))
                    .act3LineBox(fontSize: 13, ratio: 1.5)
            }

            HStack {
                liveStat(String(format: "%.1f", Double(elapsed) / 60 * 0.35), label: "km")
                liveStat("\((model.low + model.high) / 2 - 2)", label: "avg pulse")
                liveStat(outside ? "88%" : "91%", label: "in zone")
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 4)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.08), lineWidth: 0.5))

            HStack(spacing: 20) {
                Act3CircleControl(glyph: paused ? .play : .pause, active: paused, isStop: false, action: pauseAction)
                Act3CircleControl(glyph: .stop, active: false, isStop: true, action: endAction)
            }
            Text(paused ? "Tap play, or just start moving" : "Auto-pauses when you stop")
                .font(NoopHTMLFont.sans(11))
                .foregroundStyle(NoopHTMLColor.faint)
        }
        .frame(width: max(0, canvasWidth - 44), height: max(0, canvasHeight - 80))
        .padding(.top, 54)
        .padding(.bottom, 26)
        .frame(width: canvasWidth, height: canvasHeight)
        .background(
            LinearGradient(
                stops: [
                    .init(color: (outside ? Color(hex: 0xF2B45C) : NoopHTMLColor.blue).opacity(0.16), location: 0),
                    .init(color: .clear, location: 0.46)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var zoneName: String {
        Act3Zone.zone(for: bpm).name
    }

    private var cue: String {
        if paused { return "Paused. It will pick up on its own when you start moving." }
        if over { return "\(bpm - model.high) beats over. Ease off and let it come back down." }
        if under { return "\(model.low - bpm) beats under. Lift it a little if that feels easy." }
        return "Right in the middle of the zone. Hold this."
    }

    private func position(_ pulse: Int) -> CGFloat {
        max(0, min(1, CGFloat(pulse - 90) / 90))
    }

    private func liveStat(_ value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(NoopHTMLFont.outfit(20, weight: .light)).monospacedDigit()
            NoopSectionLabel(label)
        }
        .frame(maxWidth: .infinity)
    }

    private static func format(_ seconds: Int) -> String {
        "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}

private struct Act3IntervalsScreen: View {
    let model: Act3WorkoutModel
    let elapsed: Int
    let paused: Bool
    let pauseAction: () -> Void
    let endAction: () -> Void

    private var cycleElapsed: Int { elapsed % 540 }
    private var round: Int { cycleElapsed / 90 + 1 }
    private var within: Int { cycleElapsed % 90 }
    private var isWork: Bool { within < 60 }
    private var remaining: Int { isWork ? 60 - within : 90 - within }
    private var bpm: Int {
        isWork ? min(174, Int((138 + Double(within) * 0.55).rounded())) : max(128, Int((170 - Double(within - 60) * 1.4).rounded()))
    }

    var body: some View {
        let canvasWidth = UIScreen.main.bounds.width
        let canvasHeight = UIScreen.main.bounds.height
        return VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Self.format(elapsed)).font(NoopHTMLFont.outfit(20, weight: .light)).monospacedDigit()
                    NoopSectionLabel("Elapsed")
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(model.name).font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.inkSoft)
                    Text("round \(round) of 6").font(NoopHTMLFont.sans(10.5)).foregroundStyle(Color(hex: 0x7F8A85))
                }
            }

            VStack(spacing: 14) {
                Text(isWork ? "WORK" : "EASY")
                    .font(NoopHTMLFont.sans(12.5, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(isWork ? Color(hex: 0xF7C39B) : Color(hex: 0x9FE2FB))
                Text(Self.format(remaining))
                    .font(NoopHTMLFont.outfit200(88))
                    .tracking(-4)
                    .foregroundStyle(paused ? Color(hex: 0x7F8A85) : Color(hex: 0xF6FDFF))
                    .monospacedDigit()
                Act3HeartbeatReadout(
                    color: isWork ? NoopHTMLColor.amber : Color(hex: 0x4FB8E8),
                    bpm: bpm,
                    zone: Act3Zone.zone(for: bpm).name,
                    paused: paused
                )
                .padding(.horizontal, 14)
                .frame(height: 40)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.09), lineWidth: 0.5))
                Text(isWork ? "Next: 30 seconds easy" : round >= 6 ? "Next: the last minute" : "Next: minute \(round + 1) of 6")
                    .font(NoopHTMLFont.sans(12.5))
                    .foregroundStyle(NoopHTMLColor.copy)
            }
            .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    ForEach(1...6, id: \.self) { item in
                        Capsule()
                            .fill(item < round ? NoopHTMLColor.amber.opacity(0.55) : item == round ? (isWork ? NoopHTMLColor.amber : Color(hex: 0x4FB8E8)) : Color.white.opacity(0.1))
                            .frame(maxWidth: .infinity)
                            .frame(height: item == round ? 9 : 6)
                    }
                }
                Text(cue)
                    .font(NoopHTMLFont.sans(13))
                    .foregroundStyle(paused ? NoopHTMLColor.copy : isWork ? Color(hex: 0xF7C39B) : Color(hex: 0xB7C3C9))
                    .act3LineBox(fontSize: 13, ratio: 1.5)
            }

            HStack(spacing: 20) {
                Act3CircleControl(glyph: paused ? .play : .pause, active: paused, isStop: false, action: pauseAction)
                Act3CircleControl(glyph: .stop, active: false, isStop: true, action: endAction)
            }
            Text(paused ? "Tap play, or just start moving" : "Auto-pauses when you stop")
                .font(NoopHTMLFont.sans(11))
                .foregroundStyle(NoopHTMLColor.faint)
        }
        .frame(width: max(0, canvasWidth - 44), height: max(0, canvasHeight - 80))
        .padding(.top, 54)
        .padding(.bottom, 26)
        .frame(width: canvasWidth, height: canvasHeight)
        .background(
            LinearGradient(
                stops: [
                    .init(color: (isWork ? NoopHTMLColor.amber : Color(hex: 0x4FB8E8)).opacity(isWork ? 0.17 : 0.15), location: 0),
                    .init(color: .clear, location: 0.46)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var cue: String {
        if paused { return "Paused. The step will resume where you left it." }
        if isWork { return bpm < model.low ? "Still climbing. Give it everything for the rest of the minute." : "That is the effort. Hold it to zero." }
        return "Let it fall. Anything under 140 before the next one is fine."
    }

    private static func format(_ seconds: Int) -> String {
        "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}

// MARK: - Act 3 models

private struct Act3Why {
    let label: String
    let note: String
    let verdict: String
    let good: Bool
}

private struct Act3Zone {
    let name: String
    let low: Int
    let high: Int
    let color: Color

    static func zone(for bpm: Int) -> Act3Zone {
        if bpm >= 152 { return Act3Zone(name: "All out", low: 152, high: 190, color: NoopHTMLColor.amber) }
        if bpm >= 128 { return Act3Zone(name: "Hard", low: 128, high: 152, color: Color(hex: 0xF2B45C)) }
        if bpm >= 96 { return Act3Zone(name: "Steady", low: 96, high: 128, color: NoopHTMLColor.blue) }
        if bpm >= 62 { return Act3Zone(name: "Easy", low: 62, high: 96, color: Color(hex: 0x4FB8E8)) }
        return Act3Zone(name: "Rest", low: 40, high: 62, color: Color(hex: 0x3E6C86))
    }
}

struct Act3WorkoutDetail {
    let durationLabel: String
    let distance: String
    let average: Int
    let highest: Int
    let inZone: Int
    let pulse: [Double]
    let chartRead: String
    let easyMinutes: Int
    let targetMinutes: Int
    let hardMinutes: Int
    let sleepCost: Int
    let recoveredBy: String
    let svea: String

    var highestCaption: String {
        highest == 141 ? "highest, on the second hill" : "highest"
    }
}

struct Act3WorkoutModel {
    let name: String
    let symbol: String
    let duration: Int
    let low: Int
    let high: Int
    let load: Int
    let fit: String
    let isInsideToday: Bool
    let reason: String
    let note: String
    let isIntervals: Bool
    let primaryZone: String
    let detail: Act3WorkoutDetail
}

extension NoopWorkout {
    var act3: Act3WorkoutModel {
        switch self {
        case .steadyRide:
            Act3WorkoutModel(
                name: "Steady ride", symbol: "bicycle", duration: 40, low: 112, high: 128, load: 48,
                fit: "as planned", isInsideToday: true,
                reason: "Forty minutes, easy the whole way. Hold your pulse between 112 and 128 and let the hills come to you.",
                note: "What today can take without borrowing from tomorrow.", isIntervals: false, primaryZone: "Steady",
                detail: Act3WorkoutDetail(durationLabel: "42:10", distance: "14.8", average: 126, highest: 141, inZone: 82, pulse: [94, 106, 116, 121, 124, 126, 122, 119, 124, 130, 136, 133, 127, 123, 120, 124, 127, 131, 138, 134, 126, 121, 114, 104], chartRead: "The shaded stretch is what the session asked for. You spent 34 of 42 minutes inside it, and the two climbs above were both hills.", easyMinutes: 6, targetMinutes: 31, hardMinutes: 5, sleepCost: 12, recoveredBy: "tomorrow, 11:00", svea: "You held the zone without needing to be told twice, and your pulse came down inside forty seconds every time you crested a hill. That recovery is the reason today looks the way it does.")
            )
        case .intervals:
            Act3WorkoutModel(
                name: "6 × 1 min hard", symbol: "bolt.fill", duration: 22, low: 152, high: 168, load: 86,
                fit: "harder than today allows", isInsideToday: false,
                reason: "Six one-minute efforts with thirty seconds easy between them. This is the session you had planned, and it is still here if you want it.",
                note: "Costs about two days of recovery from where you are this morning.", isIntervals: true, primaryZone: "All out",
                detail: Act3WorkoutDetail(durationLabel: "22:08", distance: "7.1", average: 148, highest: 174, inZone: 69, pulse: [104, 128, 145, 158, 166, 171, 142, 128, 146, 160, 168, 173, 139, 127, 147, 161, 169, 174, 141, 129, 148, 164, 170, 136], chartRead: "The shaded stretch is the hard minute. Each rise reached it late, and every easy thirty seconds brought your pulse back under 140.", easyMinutes: 10, targetMinutes: 8, hardMinutes: 4, sleepCost: 24, recoveredBy: "Friday, 09:00", svea: "You finished all six, but the final two took longer to come down. That is the exact cost the morning read warned about — real work, and two days to pay it back.")
            )
        case .longWalk:
            Act3WorkoutModel(
                name: "Long walk", symbol: "figure.walk", duration: 50, low: 92, high: 110, load: 18,
                fit: "well inside today", isInsideToday: true,
                reason: "Fifty easy minutes. Nothing to hold, nothing to hit — it counts as movement and costs you almost nothing.",
                note: "The honest choice on a day your breathing is up.", isIntervals: false, primaryZone: "Easy",
                detail: Act3WorkoutDetail(durationLabel: "50:22", distance: "4.4", average: 101, highest: 118, inZone: 88, pulse: [82, 88, 94, 98, 101, 104, 102, 99, 103, 107, 112, 109, 105, 103, 101, 104, 108, 114, 118, 111, 105, 100, 94, 88], chartRead: "Most of the walk sat inside the easy band. The two brief rises were hills and both came straight back down.", easyMinutes: 5, targetMinutes: 44, hardMinutes: 1, sleepCost: 4, recoveredBy: "tonight, 20:00", svea: "This did exactly what an easy choice should do: moved you, lifted your pulse gently, and left almost nothing for tomorrow to pay back.")
            )
        case .strength:
            Act3WorkoutModel(
                name: "Strength, lower body", symbol: "dumbbell", duration: 35, low: 104, high: 128, load: 62,
                fit: "legs are two days out", isInsideToday: false,
                reason: "Thirty-five minutes of lower body work. Your legs took a real load on Monday and have not finished the job.",
                note: "Better on Friday, when the ride has been paid off.", isIntervals: false, primaryZone: "Steady",
                detail: Act3WorkoutDetail(durationLabel: "35:34", distance: "—", average: 119, highest: 147, inZone: 74, pulse: [88, 96, 108, 126, 141, 112, 98, 110, 132, 145, 116, 101, 114, 136, 147, 120, 104, 116, 138, 143, 118, 108, 100, 92], chartRead: "The working sets rose above the band and the rests brought you back. Pulse is only part of a strength session, so the load also comes from the set pattern.", easyMinutes: 9, targetMinutes: 21, hardMinutes: 5, sleepCost: 17, recoveredBy: "Thursday, 18:00", svea: "Your pulse recovered between sets, but the final block slowed. That is your legs showing the two hard days still in them, exactly as the morning read expected.")
            )
        case .easySwim:
            Act3WorkoutModel(
                name: "Easy swim", symbol: "figure.pool.swim", duration: 30, low: 108, high: 126, load: 42,
                fit: "as good as the ride", isInsideToday: true,
                reason: "Thirty minutes, easy. Same effect as the ride with less through your legs.",
                note: "Swap freely — the recommendation does not mind which one you pick.", isIntervals: false, primaryZone: "Steady",
                detail: Act3WorkoutDetail(durationLabel: "30:18", distance: "1.2", average: 117, highest: 132, inZone: 85, pulse: [92, 101, 110, 115, 119, 122, 118, 114, 120, 125, 129, 126, 121, 117, 115, 119, 124, 130, 132, 127, 121, 116, 108, 99], chartRead: "The shaded stretch is what the swim asked for. Most lengths sat inside it; the four turns above were the faster final metres.", easyMinutes: 4, targetMinutes: 25, hardMinutes: 1, sleepCost: 10, recoveredBy: "tomorrow, 09:00", svea: "The swim gave you the same steady effect as the ride without asking the same thing of your legs. Your pulse settled inside a minute after every faster length.")
            )
        }
    }
}

private extension NoopAct3Screens {
    static let zones = [
        Act3Zone(name: "Rest", low: 40, high: 62, color: Color(hex: 0x3E6C86)),
        Act3Zone(name: "Easy", low: 62, high: 96, color: Color(hex: 0x4FB8E8)),
        Act3Zone(name: "Steady", low: 96, high: 128, color: NoopHTMLColor.blue),
        Act3Zone(name: "Hard", low: 128, high: 152, color: Color(hex: 0xF2B45C)),
        Act3Zone(name: "All out", low: 152, high: 190, color: NoopHTMLColor.amber)
    ]
}
