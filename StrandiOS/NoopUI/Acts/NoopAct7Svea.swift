import SwiftUI

struct NoopAct7Screens: View {
    @ObservedObject var navigation: NoopNavigation
    @EnvironmentObject private var coach: AICoachEngine

    var body: some View {
        switch navigation.route {
        case .coach:
            if navigation.coachVoice == .off {
                NoopSveaOff(navigation: navigation)
            } else if coach.isConfigured || NoopSveaFixture.forcesCoachRoute {
                NoopSveaCoach(navigation: navigation)
            } else {
                NoopSveaGate(navigation: navigation)
            }
        case .gate: NoopSveaGate(navigation: navigation)
        case .setup: NoopSveaSetup(navigation: navigation)
        case .consent: NoopSveaConsent(navigation: navigation)
        case .memory: NoopSveaMemory(navigation: navigation)
        default: NoopSveaCoach(navigation: navigation)
        }
    }
}

private enum NoopSveaFixture {
    static var enabled: Bool { NoopContentPolicy.allowsPrototypeContent }

    static var forcesCoachRoute: Bool {
        #if DEBUG
        let arguments = CommandLine.arguments
        guard enabled,
              let flag = arguments.firstIndex(of: "--noop-route"),
              arguments.indices.contains(flag + 1) else { return false }
        return arguments[flag + 1] == NoopRoute.coach.rawValue
        #else
        return false
        #endif
    }
}

// MARK: - Coach

private struct NoopSveaCoach: View {
    @ObservedObject var navigation: NoopNavigation
    @EnvironmentObject private var coach: AICoachEngine
    @ObservedObject private var memoryStore = CoachMemory.shared
    @AppStorage("noop.html.svea-grant-count") private var grantCount = 5
    // Onboarding step 2's answer. Svea's framing follows it: for a night worker "last night" is
    // the wrong name for the sleep she has just read.
    @AppStorage("noop.schedule.kind") private var scheduleKind = "mostly-nights"

    private var isNightWorker: Bool { NoopScheduleInference.isNightWorker(kind: scheduleKind) }
    @State private var proposal = "open"
    @State private var question = ""
    @State private var asked = ""
    @State private var answerKind = ""
    @State private var showUsedMemory = true
    @FocusState private var askFocused: Bool

    var body: some View {
        NoopSveaScrollScreen(bottomInset: 206) {
            VStack(spacing: 0) {
                coachHeader
                VStack(alignment: .leading, spacing: 10) {
                    briefCard
                    proposalCard

                    if !asked.isEmpty {
                        VStack(spacing: 10) {
                            HStack {
                                Spacer(minLength: 0)
                                Text(asked)
                                    .font(NoopHTMLFont.sans(13.5))
                                    .foregroundStyle(NoopHTMLColor.ink)
                                    .noopSveaLineBox(fontSize: 13.5, ratio: 1.5)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 11)
                                    .frame(maxWidth: (UIScreen.main.bounds.width - 40) * 0.8, alignment: .leading)
                                    .background(
                                        Color.white.opacity(0.08),
                                        in: UnevenRoundedRectangle(
                                            topLeadingRadius: 18,
                                            bottomLeadingRadius: 18,
                                            bottomTrailingRadius: 6,
                                            topTrailingRadius: 18
                                        )
                                    )
                                    .overlay(
                                        UnevenRoundedRectangle(
                                            topLeadingRadius: 18,
                                            bottomLeadingRadius: 18,
                                            bottomTrailingRadius: 6,
                                            topTrailingRadius: 18
                                        )
                                        .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
                                    )
                            }

                            if answerKind == "streaming" {
                                NoopSveaStreamingAnswer()
                            } else if answerKind == "declined" {
                                NoopSveaDeclinedAnswer(ask: askAlternative)
                            } else {
                                NoopSveaDataAnswer(showMemory: showUsedMemory, forgetMemory: forgetUsedMemory)
                            }
                        }
                        .transition(.opacity.combined(with: .offset(y: 9)))
                    }

                    Text("Everything periwinkle on this screen was generated. Everything in a bordered tile with a monospace figure was measured on your wrist. The app will never mix those two into one sentence.")
                        .font(NoopHTMLFont.sans(11))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .noopSveaLineBox(fontSize: 11, ratio: 1.6)
                        .padding(.horizontal, 2)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
        }
        // Keep the fixed composer out of the scroll view's layout calculation. Otherwise its
        // intrinsic TextField width expands the root ZStack by 28 pt and clips the first prompt.
        .overlay(alignment: .bottom) {
            composer
                .padding(.horizontal, 14)
                .padding(.bottom, 88)
        }
        .onChange(of: navigation.askFocusRequest) { _, _ in askFocused = true }
        .task {
            if navigation.askFocusRequest > 0 { askFocused = true }
            grantCount = SveaDataGrants.load().allowed.count
        }
    }

    private var coachHeader: some View {
        HStack(spacing: 11) {
            NoopSveaMiniOrb()
            VStack(alignment: .leading, spacing: 2) {
                Text("Svea")
                    .font(NoopHTMLFont.outfit(20, weight: .regular))
                    .tracking(-0.44)
                    .frame(height: 22, alignment: .top)
                Text("\(coach.provider.noopDisplayName) · your key · \(grantCount) of 7 grants")
                    .font(NoopHTMLFont.sans(11))
                    .foregroundStyle(Color(hex: 0x7F8A85))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("Memory") { navigation.push(.memory) }
                .font(NoopHTMLFont.sans(11.5, weight: .semibold))
                .foregroundStyle(NoopHTMLColor.inkSoft)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.10), lineWidth: 0.5))
                .buttonStyle(NoopHTMLPressStyle())
        }
        .padding(.horizontal, 18)
        .padding(.top, 54)
        .padding(.bottom, 4)
    }

    private var briefCard: some View {
        NoopSveaGradientCard(
            tint: NoopHTMLColor.night,
            startOpacity: 0.14,
            endOpacity: 0.03,
            angle: 160,
            borderOpacity: 0.30,
            radius: 26,
            horizontalPadding: 16,
            topPadding: 16,
            bottomPadding: 15
        ) {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 8) {
                    NoopSveaEyebrow("Today's brief · 07:12", size: 9.5, color: Color(hex: 0xC9D0EE))
                        .fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 0)
                    Text("WRITTEN")
                        .font(NoopHTMLFont.sans(9, weight: .semibold))
                        .tracking(1.08)
                        .foregroundStyle(Color(hex: 0xA9B4E0))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(NoopHTMLColor.night.opacity(0.45), lineWidth: 0.5))
                }

                ForEach(brief, id: \.self) { paragraph in
                    Text(paragraph)
                        .font(NoopHTMLFont.sans(14))
                        .foregroundStyle(Color(hex: 0xDCE3E0))
                        .noopSveaLineBox(fontSize: 14, ratio: 1.62)
                }

                VStack(alignment: .leading, spacing: 9) {
                    NoopSveaEyebrow("Grounded in — measured", size: 9.5, color: Color(hex: 0x8B958F))
                    NoopFlowLayout(spacing: 6) {
                        ForEach(Array(sources.enumerated()), id: \.offset) { _, source in
                            HStack(alignment: .firstTextBaseline, spacing: 7) {
                                Text(source.label)
                                    .font(NoopHTMLFont.sans(10.5))
                                    .foregroundStyle(Color(hex: 0x8B958F))
                                Text(source.value)
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(NoopHTMLColor.ink)
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .frame(minHeight: 28)
                            .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 9))
                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.10), lineWidth: 0.5))
                        }
                    }
                    Text(groundNote)
                        .font(NoopHTMLFont.sans(11))
                        .foregroundStyle(Color(hex: 0x7F8A85))
                        .noopSveaLineBox(fontSize: 11, ratio: 1.55)
                }
                .padding(.top, 11)
                .overlay(alignment: .top) {
                    Rectangle().fill(NoopHTMLColor.night.opacity(0.22)).frame(height: 0.5)
                }
            }
        }
    }

    private var proposalCard: some View {
        NoopSveaPlainCard(radius: 26, horizontalPadding: 16, topPadding: 16, bottomPadding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 9) {
                    NoopSveaEyebrow("A proposal", size: 9.5, color: Color(hex: 0xC9D0EE))
                        .fixedSize(horizontal: true, vertical: false)
                    Text("nothing is in your day until you say so")
                        .font(NoopHTMLFont.sans(11))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.88)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text("Forty easy minutes, this afternoon")
                        .font(NoopHTMLFont.outfit(21, weight: .regular))
                        .tracking(-0.504)
                        .frame(minHeight: 25.2, alignment: .top)
                    Text("Because sleep landed on your need and variability is where it usually sits before a good session — not because a plan says Thursday.")
                        .font(NoopHTMLFont.sans(12.5))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .noopSveaLineBox(fontSize: 12.5, ratio: 1.6)
                }

                if proposal == "open" {
                    GeometryReader { proxy in
                        let unit = max(0, proxy.size.width - 14) / 3.4
                        HStack(spacing: 7) {
                            Button("Put it in today") { proposal = "accepted" }
                                .buttonStyle(NoopSveaActionButtonStyle(primary: true))
                                .frame(width: unit * 1.4)
                            Button("Move") { proposal = "moved" }
                                .buttonStyle(NoopSveaActionButtonStyle())
                                .frame(width: unit)
                            Button("Skip") { proposal = "skipped" }
                                .buttonStyle(NoopSveaActionButtonStyle())
                                .frame(width: unit)
                        }
                    }
                    .frame(height: 44)
                } else {
                    HStack(spacing: 10) {
                        Text(proposalText)
                            .font(NoopHTMLFont.sans(12.5))
                            .foregroundStyle(Color(hex: 0xDCE3E0))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Button("Undo") { proposal = "open" }
                            .font(NoopHTMLFont.sans(11.5, weight: .semibold))
                            .foregroundStyle(Color(hex: 0xA9B4E0))
                            .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 12)
                    .background(NoopHTMLColor.night.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(NoopHTMLColor.night.opacity(0.26), lineWidth: 0.5))
                }
            }
        }
    }

    private var composer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                suggestion("Should I lift today?", kind: "answer")
                suggestion(briefLabel, kind: "declined")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                TextField("Ask about your own data…", text: $question)
                    .focused($askFocused)
                    .font(NoopHTMLFont.sans(13))
                    .foregroundStyle(NoopHTMLColor.ink)
                    .tint(NoopHTMLColor.night)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.send)
                    .onSubmit(sendQuestion)
                Button(action: sendQuestion) {
                    NoopSveaSendArrow()
                        .frame(width: 13, height: 13)
                        .frame(width: 34, height: 34)
                        .background(NoopHTMLColor.night, in: Circle())
                }
                .buttonStyle(NoopHTMLPressStyle())
                .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.leading, 16)
            .padding(.trailing, 9)
            .padding(.vertical, 9)
            .frame(height: 54)
            .background(Color(hex: 0x171C1A, alpha: 0.92), in: RoundedRectangle(cornerRadius: 22))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.10), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.45), radius: 13, y: 8)
        }
    }

    private var brief: [String] {
        switch navigation.coachVoice {
        case .plain:
            return [
                "You slept 7h 12m against a need of 7h 05m, and your variability has come up for the fourth night running. That is the pattern that has preceded your easier sessions all year.",
                "Nothing in the last three days argues for a hard effort, and nothing argues against a moderate one. If you want a session today, this is a good day for the kind you can hold a conversation through.",
                "One thing worth naming: bedtime drifted 40 minutes later across the week. It has not cost you yet, and it is the one lever you have before it does."
            ]
        case .quiet:
            return ["Slept on your need, variability up four nights. Good day for an easy session; bedtime has drifted 40 minutes later this week."]
        case .direct:
            return [
                "Sleep met your need. Variability up four nights — you are ready for a moderate session, not a hard one.",
                "Bedtime slipped 40 minutes this week. Fix that before it costs you a night."
            ]
        case .off: return []
        }
    }

    private struct Source {
        let label: String
        let value: String
        let grant: SveaDataGrant
    }

    private var allSources: [Source] {
        [
            .init(label: "Sleep", value: "7h 12m", grant: .sleep),
            .init(label: "HRV", value: "68 ms", grant: .vitals),
            .init(label: "Resting HR", value: "52 bpm", grant: .vitals),
            .init(label: "Journal", value: "3 entries", grant: .journal),
            .init(label: "Body age", value: "34 yr", grant: .ages)
        ]
    }

    private var sources: [Source] {
        let grants = SveaDataGrants.load()
        return allSources.filter { grants.allows($0.grant) }
    }

    private var groundNote: String {
        let grants = SveaDataGrants.load()
        let missing = allSources.filter { !grants.allows($0.grant) }.map { $0.label.lowercased() }
        if missing.isEmpty {
            return "Five signals, and nothing else. Everything you have not granted is absent from the prompt, not summarised into it."
        }
        return "\(sources.count) signals, and nothing else. Your grants keep \(missing.joined(separator: ", ")) out of the prompt — not summarised into it either."
    }

    private var proposalText: String {
        switch proposal {
        case "accepted": return "In today, 40 easy minutes — Svea will not raise it again"
        case "moved": return "Moved to tomorrow. Svea will check the morning first"
        default: return "Skipped. Nothing else changes because of it"
        }
    }

    /// The declined-brief chip, and the phrase `sendQuestion` recognises when it is typed.
    private var briefLabel: String {
        isNightWorker ? "Brief me on my last sleep" : "Brief me on last night"
    }

    private var briefPhrase: String { isNightWorker ? "last sleep" : "last night" }

    private func suggestion(_ label: String, kind: String) -> some View {
        let selected = asked == label
        return Button { beginAnswer(label, kind: kind) } label: {
            Text(label)
                .font(NoopHTMLFont.sans(12, weight: .semibold))
                .foregroundStyle(selected ? Color(hex: 0xDDE3F6) : NoopHTMLColor.inkSoft)
                .lineLimit(1)
                .padding(.horizontal, 13)
                .frame(height: 35)
                .background(
                    selected ? NoopHTMLColor.night.opacity(0.20) : Color(hex: 0x171C1A, alpha: 0.90),
                    in: RoundedRectangle(cornerRadius: 13)
                )
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 13))
                .overlay(
                    RoundedRectangle(cornerRadius: 13)
                        .stroke(selected ? NoopHTMLColor.night.opacity(0.50) : Color.white.opacity(0.10), lineWidth: 0.5)
                )
        }
        .buttonStyle(NoopHTMLPressStyle())
    }

    private func sendQuestion() {
        let clean = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        beginAnswer(clean, kind: clean.localizedCaseInsensitiveContains(briefPhrase) ? "declined" : "answer")
        question = ""
        askFocused = false
    }

    private func beginAnswer(_ prompt: String, kind: String) {
        withAnimation(.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.30)) {
            asked = prompt
            answerKind = "streaming"
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1_500))
            guard asked == prompt else { return }
            answerKind = kind
        }
    }

    private func askAlternative(_ prompt: String) {
        withAnimation(.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.30)) {
            asked = prompt
            answerKind = "answer"
        }
    }

    private func forgetUsedMemory() {
        if let fact = memoryStore.facts.first(where: {
            $0.text.localizedCaseInsensitiveContains("lift") &&
            $0.text.localizedCaseInsensitiveContains("Tuesday")
        }) {
            memoryStore.remove(fact.id)
        }
        withAnimation(.easeOut(duration: 0.18)) { showUsedMemory = false }
    }
}

private struct NoopSveaStreamingAnswer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NoopSveaTintCard(fillOpacity: 0.08, borderOpacity: 0.24, radius: 22, horizontalPadding: 16, topPadding: 15, bottomPadding: 15) {
            VStack(alignment: .leading, spacing: 9) {
                TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 0.05, paused: reduceMotion)) { timeline in
                    let phase = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1)
                    let caretOpacity = reduceMotion || phase <= 0.45 ? 1.0 : 0.12
                    (Text("Looking at four nights of variability against what you did after each one") +
                     Text("▌").foregroundColor(Color(hex: 0xA9B4E0, alpha: caretOpacity)))
                        .font(NoopHTMLFont.sans(13.5))
                        .foregroundStyle(Color(hex: 0xDCE3E0))
                        .noopSveaLineBox(fontSize: 13.5, ratio: 1.6)
                }
                NoopFlowLayout(spacing: 6) {
                    ForEach(["sleep · 14 nights", "HRV · 30 days", "journal · this week"], id: \.self) { item in
                        Text("reading \(item)")
                            .font(NoopHTMLFont.sans(10.5))
                            .foregroundStyle(Color(hex: 0x8B958F))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 7))
                    }
                }
            }
        }
    }
}

private struct NoopSveaDataAnswer: View {
    let showMemory: Bool
    let forgetMemory: () -> Void

    var body: some View {
        NoopSveaTintCard(fillOpacity: 0.08, borderOpacity: 0.24, radius: 22, horizontalPadding: 16, topPadding: 15, bottomPadding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Circle().fill(NoopHTMLColor.night).frame(width: 6, height: 6)
                    NoopSveaEyebrow("Svea · written", size: 9, tracking: 1.08, color: Color(hex: 0xA9B4E0))
                }
                Text("Yes, and it is the better of the two things you could do today. Your variability has been climbing for four nights and it is now the highest it has been in three weeks, which for you has always come before a session that felt easy.")
                    .font(NoopHTMLFont.sans(13.5))
                    .foregroundStyle(Color(hex: 0xDCE3E0))
                    .noopSveaLineBox(fontSize: 13.5, ratio: 1.62)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        NoopSveaEyebrow("Measured · your last 7 nights", size: 9.5, color: Color(hex: 0x8B958F))
                        Spacer(minLength: 0)
                        Text("HRV ms")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(NoopHTMLColor.blueLight)
                    }
                    NoopSveaHRVChart()
                    Text("Drawn from your own record. Svea chose the window; it did not choose the numbers.")
                        .font(NoopHTMLFont.sans(10.5))
                        .foregroundStyle(NoopHTMLColor.faint)
                }
                .padding(.horizontal, 13)
                .padding(.top, 13)
                .padding(.bottom, 11)
                .background(NoopHTMLColor.canvas.opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.10), lineWidth: 0.5))

                if showMemory {
                    Button(action: forgetMemory) {
                        HStack(alignment: .top, spacing: 9) {
                            NoopSveaGlyph(name: .memory, size: 17, color: Color(hex: 0xA9B4E0))
                            VStack(alignment: .leading, spacing: 3) {
                                (Text("Used a remembered fact: ") +
                                 Text("you lift Tuesdays and Thursdays").fontWeight(.semibold).foregroundColor(NoopHTMLColor.ink))
                                    .font(NoopHTMLFont.sans(11.5))
                                    .foregroundStyle(NoopHTMLColor.inkSoft)
                                    .noopSveaLineBox(fontSize: 11.5, ratio: 1.5)
                                Text("from your journal, three weeks ago · tap to forget it")
                                    .font(NoopHTMLFont.sans(10.5))
                                    .foregroundStyle(Color(hex: 0x7F8A85))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.16), style: StrokeStyle(lineWidth: 0.5, dash: [4, 3]))
                        )
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                }
            }
        }
    }
}

private struct NoopSveaDeclinedAnswer: View {
    let ask: (String) -> Void

    @AppStorage("noop.schedule.kind") private var scheduleKind = "mostly-nights"

    private var isNightWorker: Bool { NoopScheduleInference.isNightWorker(kind: scheduleKind) }

    private var alternatives: [String] {
        [
            isNightWorker
                ? "Read the sleep before instead — that one is complete"
                : "Read the night before instead — that one is complete",
            "Tell me what the missing stretch would have had to be",
            isNightWorker
                ? "Brief me on the week and leave that sleep out"
                : "Brief me on the week and leave last night out"
        ]
    }

    var body: some View {
        NoopSveaTintCard(fillOpacity: 0.06, borderOpacity: 0.22, radius: 22, horizontalPadding: 16, topPadding: 15, bottomPadding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    NoopSveaGlyph(name: .pause, size: 15, color: Color(hex: 0xA9B4E0))
                    NoopSveaEyebrow("Svea is not going to answer this one", size: 9, tracking: 1.08, color: Color(hex: 0xA9B4E0))
                }
                Text(isNightWorker
                     ? "I can see your last sleep, but I do not think it is one worth reading. The strap was off your wrist between 02:10 and 04:40, so about two and a half hours of it are missing rather than light."
                     : "I can see last night, but I do not think it is a night worth reading. The strap was off your wrist between 02:10 and 04:40, so about two and a half hours of it are missing rather than light.")
                    .font(NoopHTMLFont.sans(13.5))
                    .foregroundStyle(Color(hex: 0xDCE3E0))
                    .noopSveaLineBox(fontSize: 13.5, ratio: 1.62)
                Text("Briefing on it would mean guessing at the part that is gone, and you would not be able to tell which half I invented.")
                    .font(NoopHTMLFont.sans(13.5))
                    .foregroundStyle(Color(hex: 0xDCE3E0))
                    .noopSveaLineBox(fontSize: 13.5, ratio: 1.62)

                VStack(alignment: .leading, spacing: 8) {
                    NoopSveaEyebrow("What I can do instead", size: 11, tracking: 1.32, color: Color(hex: 0x8B958F))
                    ForEach(alternatives, id: \.self) { item in
                        Button { ask(item) } label: {
                            HStack(spacing: 9) {
                                Circle().fill(NoopHTMLColor.night).frame(width: 5, height: 5)
                                Text(item)
                                    .font(NoopHTMLFont.sans(12.5))
                                    .foregroundStyle(NoopHTMLColor.inkSoft)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                NoopSveaChevron(size: 7, color: NoopHTMLColor.faint)
                            }
                            .frame(minHeight: 30)
                        }
                        .buttonStyle(NoopHTMLPressStyle())
                    }
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.09), lineWidth: 0.5))

                Text("This is not an error and nothing failed. Declining is a thing Svea is allowed to do — and the reason it can be trusted the rest of the time.")
                    .font(NoopHTMLFont.sans(11))
                    .foregroundStyle(Color(hex: 0x7F8A85))
                    .noopSveaLineBox(fontSize: 11, ratio: 1.55)
            }
        }
    }
}

// MARK: - No-provider gate and Off

private struct NoopSveaGate: View {
    @ObservedObject var navigation: NoopNavigation
    private let facts: [(String, String, NoopSveaGlyphName)] = [
        ("The key is yours", "billed to your account, revocable by you, stored in the keychain and left out of backups.", .key),
        ("It reads what you grant, per purpose", "seven grants, three presets, and sensitive journal topics always decided separately.", .lock),
        ("It can decline", "on a night with missing data it will say so rather than write a plausible paragraph.", .pause)
    ]

    var body: some View {
        NoopSveaScrollScreen(bottomInset: 130) {
            VStack(spacing: 0) {
                VStack(spacing: 20) {
                    NoopSveaLargeOrb()
                    VStack(spacing: 11) {
                        Text("Svea runs on a key you own.")
                            .font(NoopHTMLFont.outfit(27, weight: .light))
                            .tracking(-0.81)
                            .multilineTextAlignment(.center)
                            .frame(minHeight: 32.4)
                        Text("Every other number in this app is computed on your phone. A coach cannot be — it needs a model, and models live on someone's server. So you bring the account, and you decide what it is allowed to see.")
                            .font(NoopHTMLFont.sans(13.5))
                            .foregroundStyle(NoopHTMLColor.copy)
                            .multilineTextAlignment(.center)
                            .noopSveaLineBox(fontSize: 13.5, ratio: 1.65)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 74)

                VStack(spacing: 10) {
                    NoopSveaPlainCard(radius: 24, horizontalPadding: 16, topPadding: 6, bottomPadding: 6) {
                        VStack(spacing: 0) {
                            ForEach(Array(facts.enumerated()), id: \.offset) { index, fact in
                                HStack(alignment: .center, spacing: 12) {
                                    NoopSveaGlyph(name: fact.2, size: 19, color: Color(hex: 0xA9B4E0))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(fact.0)
                                            .font(NoopHTMLFont.sans(13))
                                            .foregroundStyle(NoopHTMLColor.ink)
                                        Text(fact.1)
                                            .font(NoopHTMLFont.sans(11.5))
                                            .foregroundStyle(Color(hex: 0x7F8A85))
                                            .noopSveaLineBox(fontSize: 11.5, ratio: 1.5)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(minHeight: 62)
                                .padding(.vertical, 13)
                                if index < facts.count - 1 {
                                    Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                                }
                            }
                        }
                    }

                    Button("Add a provider") { navigation.push(.setup) }
                        .buttonStyle(NoopSveaPrimaryButtonStyle())
                    Button("See what it would be allowed to read") { navigation.push(.consent) }
                        .buttonStyle(NoopSveaSecondaryButtonStyle(height: 52, radius: 18, fontSize: 14))
                    Text("Without a provider the rest of the app is unchanged — sleep, effort, trends and your ages are all computed locally and none of them need this. Svea is the one thing you can leave switched off forever.")
                        .font(NoopHTMLFont.sans(11))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .noopSveaLineBox(fontSize: 11, ratio: 1.6)
                        .padding(.horizontal, 2)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
            }
        }
    }
}

private struct NoopSveaOff: View {
    @ObservedObject var navigation: NoopNavigation

    var body: some View {
        NoopSveaScrollScreen(bottomInset: 130) {
            VStack(spacing: 0) {
                VStack(spacing: 20) {
                    NoopSveaLargeOrb(dimmed: true)
                    VStack(spacing: 11) {
                        Text("Svea is off.")
                            .font(NoopHTMLFont.outfit(27, weight: .light))
                            .tracking(-0.81)
                        Text("No briefs, proposals, questions or generated coaching will contact a provider. Sleep, effort, trends, ages and the rest of Noop remain available.")
                            .font(NoopHTMLFont.sans(13.5))
                            .foregroundStyle(NoopHTMLColor.copy)
                            .multilineTextAlignment(.center)
                            .noopSveaLineBox(fontSize: 13.5, ratio: 1.65)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 74)

                VStack(spacing: 10) {
                    Button("Turn Svea on") { navigation.coachVoice = .plain }
                        .buttonStyle(NoopSveaPrimaryButtonStyle())
                    Button("Provider and permissions") { navigation.push(.setup) }
                        .buttonStyle(NoopSveaSecondaryButtonStyle(height: 52, radius: 18, fontSize: 14))
                    Text("Your provider, key, grants and memories stay on this iPhone so turning Svea back on restores the choices you made.")
                        .font(NoopHTMLFont.sans(11))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .multilineTextAlignment(.center)
                        .noopSveaLineBox(fontSize: 11, ratio: 1.6)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
            }
        }
    }
}

// MARK: - Provider and key

private struct NoopSveaSetup: View {
    @ObservedObject var navigation: NoopNavigation
    @EnvironmentObject private var coach: AICoachEngine
    @AppStorage("noop.html.svea-provider") private var provider = "Anthropic"
    @AppStorage("noop.html.svea-proactive") private var proactive = "Never"
    @AppStorage("noop.svea.backgroundProactiveEnabled") private var backgroundProactiveEnabled = false
    @AppStorage("noop.html.svea-preset") private var consentPreset = "Personal"
    @AppStorage("noop.html.svea-grant-count") private var consentGrantCount = 5
    @AppStorage("noop.html.svea-granted-purpose-ids") private var consentGrantIDs = ""
    @State private var keyEndingVisible = false
    @State private var keyDraft = ""
    @FocusState private var keyFocused: Bool

    private let providers = ["Anthropic", "OpenAI", "Gemini", "OpenRouter", "Custom"]
    private let proactiveOptions = [
        ("Never", "Svea only speaks when asked"),
        ("When something changed", "a morning brief, and nothing else unprompted"),
        ("Freely", "may also raise a session, a drift or a run of poor nights")
    ]

    var body: some View {
        NoopSveaScrollScreen(bottomInset: 130) {
            VStack(spacing: 0) {
                NoopSveaRouteHeader(label: "Svea") {
                    if navigation.canGoBack { navigation.back() } else { navigation.reset(to: .coach) }
                }

                VStack(alignment: .leading, spacing: 12) {
                    NoopSveaRouteTitle("Provider and key")
                    providerCard
                    modelCard
                    voiceCard
                    consentLink
                }
                .padding(.horizontal, 20)
                .padding(.top, 5)
            }
        }
        .task {
            provider = coach.provider.noopDisplayName
            let explicitlyEnabled = backgroundProactiveEnabled && proactive != "Never"
            if navigation.coachVoice == .off || !explicitlyEnabled {
                proactive = "Never"
                backgroundProactiveEnabled = false
                coach.proactiveLevel = .off
                SveaProactiveBackgroundTask.updateSchedule(enabled: false)
            } else {
                coach.proactiveLevel = proactive == "Freely" ? .normal : .important
            }
        }
    }

    private var providerCard: some View {
        NoopSveaPlainCard(radius: 24, horizontalPadding: 16, topPadding: 16, bottomPadding: 17) {
            VStack(alignment: .leading, spacing: 11) {
                NoopSveaEyebrow("Who answers")
                NoopFlowLayout(spacing: 7) {
                    ForEach(providers, id: \.self) { item in
                        NoopSveaChip(item, selected: provider == item) { selectProvider(item) }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("API key")
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(Color(hex: 0x8B958F))
                    HStack(spacing: 10) {
                        SecureField("", text: $keyDraft, prompt: Text(keyMask).foregroundColor(NoopHTMLColor.inkSoft))
                            .focused($keyFocused)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(NoopHTMLColor.inkSoft)
                            .tracking(0.52)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button(keyAction, action: handleKeyAction)
                            .font(NoopHTMLFont.sans(11.5, weight: .semibold))
                            .foregroundStyle(Color(hex: 0xA9B4E0))
                            .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 15))
                    .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.11), lineWidth: 0.5))

                    HStack(alignment: .top, spacing: 8) {
                        NoopSveaGlyph(name: .lock, size: 17, color: Color(hex: 0xA9B4E0))
                        Text("Held in the iPhone keychain, excluded from backups and never written to the export file. Noop only reveals the final four characters; replace the key to change it.")
                            .font(NoopHTMLFont.sans(11))
                            .foregroundStyle(Color(hex: 0x7F8A85))
                            .noopSveaLineBox(fontSize: 11, ratio: 1.55)
                    }
                }
                .padding(.top, 4)

                Button(connectionTestLabel) {
                    if !keyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { saveKeyDraft() }
                    Task { await coach.testConnection() }
                }
                .buttonStyle(NoopSveaTintButtonStyle())
                .disabled(coach.connectionTest == .testing)
            }
        }
    }

    private var modelCard: some View {
        NoopSveaPlainCard(radius: 24, horizontalPadding: 16, topPadding: 16, bottomPadding: 6) {
            VStack(alignment: .leading, spacing: 0) {
                NoopSveaEyebrow("A model per job")
                    .frame(height: 20, alignment: .topLeading)
                ForEach(Array(models.enumerated()), id: \.offset) { index, model in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(model.title)
                                .font(NoopHTMLFont.sans(13.5))
                                .foregroundStyle(NoopHTMLColor.ink)
                            Text(model.detail)
                                .font(NoopHTMLFont.sans(11.5))
                                .foregroundStyle(Color(hex: 0x7F8A85))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text(model.value)
                            .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color(hex: 0xA9B4E0))
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 118, alignment: .trailing)
                    }
                    .frame(minHeight: 62)
                    .padding(.vertical, 13)
                    if index < models.count - 1 {
                        Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                    }
                }
            }
        }
    }

    private var voiceCard: some View {
        NoopSveaPlainCard(radius: 24, horizontalPadding: 16, topPadding: 16, bottomPadding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                NoopSveaEyebrow("How it talks")
                VStack(alignment: .leading, spacing: 8) {
                    Text("Voice")
                        .font(NoopHTMLFont.sans(12.5))
                        .foregroundStyle(NoopHTMLColor.inkSoft)
                    HStack(spacing: 6) {
                        ForEach(NoopCoachVoice.allCases) { voice in
                            NoopSveaChip(voice.rawValue, selected: navigation.coachVoice == voice) {
                                selectVoice(voice)
                            }
                        }
                    }
                    Text(voiceNote)
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(Color(hex: 0x7F8A85))
                        .noopSveaLineBox(fontSize: 11.5, ratio: 1.55)
                }

                VStack(alignment: .leading, spacing: 9) {
                    Text("How often it speaks first")
                        .font(NoopHTMLFont.sans(12.5))
                        .foregroundStyle(NoopHTMLColor.inkSoft)
                    ForEach(Array(proactiveOptions.enumerated()), id: \.offset) { index, item in
                        Button { selectProactive(item.0) } label: {
                            HStack(spacing: 11) {
                                NoopSveaRadioMark(selected: proactive == item.0)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.0)
                                        .font(NoopHTMLFont.sans(13))
                                        .foregroundStyle(NoopHTMLColor.ink)
                                    Text(item.1)
                                        .font(NoopHTMLFont.sans(11.5))
                                        .foregroundStyle(Color(hex: 0x7F8A85))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(minHeight: 50)
                            .padding(.top, index > 0 ? 1 : 0)
                            .overlay(alignment: .top) {
                                if index > 0 { Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1) }
                            }
                        }
                        .buttonStyle(NoopHTMLPressStyle())
                    }
                    if proactive != "Never" {
                        Text("Enabled by you: Svea may contact \(provider) in the background only for these proactive briefs.")
                            .font(NoopHTMLFont.sans(11))
                            .foregroundStyle(Color(hex: 0xA9B4E0))
                            .noopSveaLineBox(fontSize: 11, ratio: 1.55)
                    }
                }
                .padding(.top, 2)
                .disabled(navigation.coachVoice == .off)
                .opacity(navigation.coachVoice == .off ? 0.48 : 1)
            }
        }
    }

    private var consentLink: some View {
        Button { navigation.push(.consent) } label: {
            NoopSveaGradientCard(
                tint: NoopHTMLColor.night,
                startOpacity: 0.16,
                endOpacity: 0.03,
                angle: 158,
                borderOpacity: 0.30,
                radius: 24,
                horizontalPadding: 16,
                topPadding: 16,
                bottomPadding: 16
            ) {
                HStack(spacing: 13) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("What Svea may read")
                            .font(NoopHTMLFont.sans(14))
                            .foregroundStyle(NoopHTMLColor.ink)
                        Text(consentSummary)
                            .font(NoopHTMLFont.sans(11.5))
                            .foregroundStyle(Color(hex: 0xB7C3C9))
                            .noopSveaLineBox(fontSize: 11.5, ratio: 1.5)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    NoopSveaChevron(size: 9, color: Color(hex: 0xA9B4E0))
                }
            }
        }
        .buttonStyle(NoopHTMLPressStyle())
    }

    private var keyMask: String {
        guard keyEndingVisible else { return "•••• •••• •••• ••••" }
        if let key = AIKeyStore.read(), !key.isEmpty {
            return "•••• •••• •••• \(key.suffix(4))"
        }
        if NoopSveaFixture.enabled { return "•••• •••• •••• de51" }
        return "•••• •••• •••• ••••"
    }

    private var keyAction: String {
        if !keyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Save" }
        if coach.hasKey || NoopSveaFixture.enabled { return keyEndingVisible ? "Hide" : "Reveal" }
        return "Enter"
    }

    private var connectionTestLabel: String {
        switch coach.connectionTest {
        case .untested: return "Test the connection"
        case .testing: return "Testing…"
        case .ok: return "Answered — ready"
        case .failed: return "Couldn’t connect — try again"
        }
    }

    private var consentSummary: String {
        let hasTender = consentGrantIDs.split(separator: ",").contains("tender")
        return "\(consentPreset) · \(consentGrantCount) of 7 purposes granted · \(hasTender ? "sensitive topics included" : "sensitive topics excluded")"
    }

    private func handleKeyAction() {
        if !keyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            saveKeyDraft()
        } else if coach.hasKey || NoopSveaFixture.enabled {
            keyEndingVisible.toggle()
        } else {
            keyFocused = true
        }
    }

    private func saveKeyDraft() {
        let clean = keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        coach.setKey(clean)
        keyDraft = ""
        keyEndingVisible = coach.hasKey
    }

    private func selectProvider(_ item: String) {
        guard let selected = AIProvider(noopDisplayName: item) else { return }
        provider = item
        coach.provider = selected
        keyDraft = ""
        keyEndingVisible = false
    }

    private func selectVoice(_ voice: NoopCoachVoice) {
        navigation.coachVoice = voice
        if voice == .off {
            proactive = "Never"
            backgroundProactiveEnabled = false
            coach.proactiveLevel = .off
            SveaProactiveBackgroundTask.updateSchedule(enabled: false)
        }
    }

    private func selectProactive(_ value: String) {
        proactive = value
        backgroundProactiveEnabled = value != "Never"
        coach.proactiveLevel = value == "Never" ? .off : value == "Freely" ? .normal : .important
        SveaProactiveBackgroundTask.updateSchedule(enabled: backgroundProactiveEnabled)
    }

    private struct ModelRow {
        let title: String
        let detail: String
        let value: String
    }

    private var models: [ModelRow] {
        let values: [String]
        switch provider {
        case "OpenAI": values = ["gpt-5", "gpt-5-mini", "gpt-5"]
        case "Gemini": values = ["gemini-pro", "gemini-flash", "gemini-pro"]
        case "OpenRouter": values = ["auto", "auto:cheap", "auto"]
        case "Custom": values = ["— set an id —", "— set an id —", "— set an id —"]
        default: values = ["claude-sonnet", "claude-haiku", "claude-sonnet"]
        }
        return [
            .init(title: "The daily brief", detail: "one call each morning, long context", value: values[0]),
            .init(title: "Conversation", detail: "fast, interrupted often", value: values[1]),
            .init(title: "Charts", detail: "picks a window and a series", value: values[2])
        ]
    }

    private var voiceNote: String {
        switch navigation.coachVoice {
        case .plain: return "Three short paragraphs, in sentences. The default, and the only one that explains itself."
        case .quiet: return "One line, no reasoning. For people who want the read and not the read-out."
        case .direct: return "Two lines, imperative. Says what to do and stops — it will not soften a call you may disagree with."
        case .off: return "No briefs and no generated coaching. The rest of Noop remains available."
        }
    }
}

// MARK: - Consent

private struct NoopSveaConsent: View {
    @ObservedObject var navigation: NoopNavigation
    @EnvironmentObject private var coach: AICoachEngine
    @AppStorage("noop.html.svea-preset") private var preset = "Personal"
    @AppStorage("noop.schedule.kind") private var scheduleKind = "mostly-nights"
    @AppStorage("noop.html.svea-grant-count") private var grantCount = 5
    @AppStorage("noop.html.svea-granted-purpose-ids") private var savedGrantIDs = ""
    @AppStorage("noop.html.svea-proactive") private var proactive = "Never"
    @AppStorage("noop.svea.backgroundProactiveEnabled") private var backgroundProactiveEnabled = false
    @State private var expert = false
    @State private var showDeepConfirmation = false
    @State private var confirmingDeepPreset = false
    @State private var grants: [String: Bool] = NoopSveaConsent.personal

    var body: some View {
        ZStack {
            NoopSveaScrollScreen(bottomInset: 130) {
                VStack(spacing: 0) {
                    NoopSveaRouteHeader(label: "Provider and key") {
                        if navigation.canGoBack { navigation.back() } else { navigation.reset(to: .setup) }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        NoopSveaRouteTitle("What leaves the phone")
                        flowCard
                        presetsSection
                        grantsCard
                        promptCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 5)
                }
            }

            if showDeepConfirmation {
                NoopBottomSheet(
                    title: confirmingDeepPreset ? "Allow Deep Insights?" : "Allow sensitive journal access?",
                    dismiss: { showDeepConfirmation = false }
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(confirmingDeepPreset
                             ? "This includes sensitive journal entries and lab results in context Svea may send to your provider. Nothing is included unless you confirm it here."
                             : "This permits mood, medication, cycle information and anything you marked private to enter Svea’s provider context. It remains excluded unless you confirm here.")
                            .font(NoopHTMLFont.sans(13))
                            .foregroundStyle(NoopHTMLColor.copy)
                            .noopSveaLineBox(fontSize: 13, ratio: 1.55)
                        Button("Allow sensitive access") {
                            if confirmingDeepPreset {
                                applyPreset("Deep insights")
                            } else {
                                grants["tender"] = true
                                preset = "Edited by hand"
                                persistGrants()
                            }
                            showDeepConfirmation = false
                        }
                        .buttonStyle(NoopHTMLButtonStyle(kind: .primary, fullWidth: true))
                        Button("Not now") { showDeepConfirmation = false }
                            .buttonStyle(NoopHTMLButtonStyle(kind: .quiet, fullWidth: true))
                    }
                }
            }
        }
        .task {
            let loaded = SveaDataGrants.load()
            for grant in allGrants {
                grants[grant.id] = SveaDataGrant(rawValue: grant.id).map { loaded.allows($0) } ?? false
            }
            grantCount = loaded.allowed.count
            savedGrantIDs = loaded.canonicalValue
        }
    }

    private var flowCard: some View {
        NoopSveaGradientCard(
            tint: NoopHTMLColor.blue,
            startOpacity: 0.10,
            endOpacity: 0.02,
            angle: 158,
            borderOpacity: 0.24,
            radius: 24,
            horizontalPadding: 16,
            topPadding: 16,
            bottomPadding: 16
        ) {
            VStack(alignment: .leading, spacing: 12) {
                NoopSveaFlowRow(
                    color: NoopHTMLColor.blue,
                    title: "Stays here, always",
                    detail: "your key, the raw sensor stream, the index Svea remembers, and every number the app computes."
                )
                NoopSveaFlowRow(
                    color: NoopHTMLColor.night,
                    title: proactive == "Never" ? "Goes out when you ask" : "Goes out when you ask or enable a brief",
                    detail: proactive == "Never"
                        ? "a short text summary of the grants below, plus your question. Nothing is sent in the background."
                        : "a short text summary of the grants below, plus your question. Your enabled proactive brief may contact the provider in the background."
                )
                NoopSveaFlowRow(
                    color: NoopHTMLColor.muted,
                    title: "Never goes out",
                    detail: "anything ungranted — and it is removed before the request is built, not filtered from the reply."
                )
            }
        }
    }

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            NoopSveaEyebrow("Pick a level")
                .padding(.horizontal, 2)
                .padding(.top, 4)
            HStack(spacing: 6) {
                NoopSveaChip("Essentials", selected: preset == "Essentials", selectedTint: NoopHTMLColor.blue) {
                    applyPreset("Essentials")
                }
                NoopSveaChip("Personal", selected: preset == "Personal", selectedTint: NoopHTMLColor.blue) {
                    applyPreset("Personal")
                }
                NoopSveaChip("Deep insights", selected: preset == "Deep insights", selectedTint: NoopHTMLColor.blue) {
                    confirmingDeepPreset = true
                    showDeepConfirmation = true
                }
            }
            Text(presetNote)
                .font(NoopHTMLFont.sans(11.5))
                .foregroundStyle(Color(hex: 0x7F8A85))
                .noopSveaLineBox(fontSize: 11.5, ratio: 1.55)
        }
    }

    private var grantsCard: some View {
        NoopSveaPlainCard(radius: 24, horizontalPadding: 16, topPadding: 16, bottomPadding: 6) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    NoopSveaEyebrow("Purpose by purpose")
                    Spacer(minLength: 0)
                    Button(expert ? "Fewer" : "Show all seven") { expert.toggle() }
                        .font(NoopHTMLFont.sans(11.5, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xA9B4E0))
                        .buttonStyle(.plain)
                }
                .padding(.bottom, 4)

                ForEach(Array(visibleGrants.enumerated()), id: \.offset) { index, grant in
                    HStack(alignment: .top, spacing: 13) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 7) {
                                Text(grant.title)
                                    .font(NoopHTMLFont.sans(13.5))
                                    .foregroundStyle(NoopHTMLColor.ink)
                                if grant.id == "tender" {
                                    Text("ITS OWN DECISION")
                                        .font(NoopHTMLFont.sans(9, weight: .semibold))
                                        .tracking(0.9)
                                        .foregroundStyle(Color(hex: 0xF3C888))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(hex: 0xF3C888, alpha: 0.40), lineWidth: 0.5))
                                }
                            }
                            Text(grant.detail)
                                .font(NoopHTMLFont.sans(11.5))
                                .foregroundStyle(Color(hex: 0x7F8A85))
                                .noopSveaLineBox(fontSize: 11.5, ratio: 1.5)
                            if grants[grant.id] != true {
                                Text("Off — \(grant.loss)")
                                    .font(NoopHTMLFont.sans(11.5))
                                    .foregroundStyle(Color(hex: 0xC9D0EE))
                                    .noopSveaLineBox(fontSize: 11.5, ratio: 1.5)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        NoopSveaToggle(
                            isOn: grants[grant.id] == true,
                            tint: grant.id == "tender" ? Color(hex: 0xF3C888, alpha: 0.90) : NoopHTMLColor.night
                        ) {
                            toggleGrant(grant.id)
                        }
                        .padding(.top, 2)
                    }
                    .padding(.vertical, 14)
                    .padding(.top, index > 0 ? 1 : 0)
                    .overlay(alignment: .top) {
                        if index > 0 { Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1) }
                    }
                }
            }
        }
    }

    private var promptCard: some View {
        NoopSveaPlainCard(radius: 24, horizontalPadding: 16, topPadding: 16, bottomPadding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                NoopSveaEyebrow("The prompt, as it would go out")
                VStack(alignment: .leading, spacing: 6) {
                    promptLine(NoopScheduleInference.isNightWorker(kind: scheduleKind)
                               ? "Last sleep: 7h 12m, need 7h 05m, deep 1h 34m."
                               : "Last night: 7h 12m, need 7h 05m, deep 1h 34m.", grant: "sleep")
                    promptLine("HRV 68 ms (4-night rise), resting pulse 52.", grant: "vitals")
                    promptLine("Journal: no alcohol, coffee before 11:00, late meal Friday.", grant: "journal")
                    promptLine("Private entries: mood 3, medication logged.", grant: "tender")
                    promptLine("Body age 34 ± 5, pace 0.8×.", grant: "ages")
                    Text("Question: should I lift today?")
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(NoopHTMLColor.inkSoft)
                        .noopSveaLineBox(fontSize: 11.5, ratio: 1.6)
                }
                .padding(13)
                .background(NoopHTMLColor.canvas.opacity(0.60), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.09), lineWidth: 0.5))
                Text("Struck-through lines are what your current grants remove. It is the whole payload — there is no second, quieter request.")
                    .font(NoopHTMLFont.sans(11))
                    .foregroundStyle(Color(hex: 0x7F8A85))
                    .noopSveaLineBox(fontSize: 11, ratio: 1.55)
            }
        }
    }

    private static let essentials = ["sleep": true, "effort": true, "vitals": false, "journal": false, "tender": false, "ages": false, "labs": false]
    private static let personal = ["sleep": true, "effort": true, "vitals": true, "journal": true, "tender": false, "ages": true, "labs": false]
    private static let deep = ["sleep": true, "effort": true, "vitals": true, "journal": true, "tender": true, "ages": true, "labs": true]

    private var allGrants: [NoopSveaGrant] {
        [
            .init(id: "sleep", title: "Sleep and recovery", detail: "stages, timing, your need, the last 60 nights", loss: "no brief, no bedtime advice, no read on a bad night"),
            .init(id: "effort", title: "Effort and workouts", detail: "sessions, strain, time in zones", loss: "it cannot propose or judge a session"),
            .init(id: "vitals", title: "Vitals and trends", detail: "HRV, resting pulse, respiration, skin temperature", loss: "no illness read, and no reason behind a proposal"),
            .init(id: "journal", title: "Journal — behaviour", detail: "alcohol, caffeine, late meals, screens, travel", loss: "it can see the effect and never the cause"),
            .init(id: "tender", title: "Journal — sensitive topics", detail: "mood, medication, cycle, anything you marked private", loss: "these entries are excluded from every request"),
            .init(id: "ages", title: "Body age and estimates", detail: "body age, fitness age, the five domains", loss: "it will not discuss your ages at all"),
            .init(id: "labs", title: "Lab results", detail: "anything you entered in the lab book", loss: "bloodwork stays on the phone, unread")
        ]
    }

    private var visibleGrants: [NoopSveaGrant] {
        expert ? allGrants : allGrants.filter { $0.id != "labs" }
    }

    private var presetNote: String {
        switch preset {
        case "Essentials": return "Sleep and effort only. Svea can read the night and the session, and knows nothing about your day, your labs or anything you wrote."
        case "Deep insights": return "Everything, including lab results and sensitive journal topics. The most useful and the most exposed; a grant you should make deliberately rather than by preset."
        case "Edited by hand": return "Edited by hand — this is no longer one of the three presets, which is fine and is the point of the list below."
        default: return "Adds vitals, your journal and the age estimates. Sensitive journal topics stay out — those are always a separate decision."
        }
    }

    private func applyPreset(_ value: String) {
        preset = value
        switch value {
        case "Essentials": grants = Self.essentials
        case "Deep insights": grants = Self.deep
        default: grants = Self.personal
        }
        persistGrants()
    }

    private func toggleGrant(_ id: String) {
        if id == "tender", grants[id] != true {
            confirmingDeepPreset = false
            showDeepConfirmation = true
            return
        }
        grants[id, default: false].toggle()
        preset = "Edited by hand"
        persistGrants()
    }

    private func persistGrants() {
        let typed = Set(grants.compactMap { key, enabled in
            enabled ? SveaDataGrant(rawValue: key) : nil
        })
        let policy = SveaDataGrants(allowed: typed)
        policy.save()
        grantCount = typed.count
        savedGrantIDs = policy.canonicalValue
        coach.dataConsent = !typed.isEmpty

        if typed.isEmpty {
            backgroundProactiveEnabled = false
            SveaProactiveBackgroundTask.updateSchedule(enabled: false)
        } else if proactive != "Never" {
            backgroundProactiveEnabled = true
            SveaProactiveBackgroundTask.updateSchedule(enabled: true)
        }
    }

    private func promptLine(_ text: String, grant: String) -> some View {
        Text(text)
            .font(.system(size: 11.5, design: .monospaced))
            .foregroundStyle(grants[grant] == true ? NoopHTMLColor.inkSoft : Color(hex: 0x4E5653))
            .strikethrough(grants[grant] != true)
            .noopSveaLineBox(fontSize: 11.5, ratio: 1.6)
    }
}

// MARK: - Memory

private struct NoopSveaMemory: View {
    @ObservedObject var navigation: NoopNavigation
    @ObservedObject private var memoryStore = CoachMemory.shared
    @State private var showDeleteAll = false
    @State private var rebuilt = false
    @State private var demoForgotten: Set<UUID> = []
    @State private var demoCleared = false

    var body: some View {
        ZStack {
            NoopSveaScrollScreen(bottomInset: 130) {
                VStack(spacing: 0) {
                    NoopSveaRouteHeader(label: "Svea") {
                        if navigation.canGoBack { navigation.back() } else { navigation.reset(to: .coach) }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            NoopSveaRouteTitle("What Svea remembers")
                            Text(introText)
                                .font(NoopHTMLFont.sans(13))
                                .foregroundStyle(NoopHTMLColor.copy)
                                .noopSveaLineBox(fontSize: 13, ratio: 1.6)
                        }

                        memoryListCard
                        indexCard
                        withdrawRow
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 5)
                }
            }

            if showDeleteAll {
                NoopBottomSheet(title: "Delete all memories?", dismiss: { showDeleteAll = false }) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("This deletes Svea’s local index immediately. Nothing was stored at the provider.")
                            .font(NoopHTMLFont.sans(13))
                            .foregroundStyle(NoopHTMLColor.copy)
                            .noopSveaLineBox(fontSize: 13, ratio: 1.55)
                        Button("Delete all") { deleteAll() }
                            .buttonStyle(NoopHTMLButtonStyle(kind: .destructive, fullWidth: true))
                        Button("Cancel") { showDeleteAll = false }
                            .buttonStyle(NoopHTMLButtonStyle(kind: .quiet, fullWidth: true))
                    }
                }
            }
        }
    }

    private var memoryListCard: some View {
        NoopSveaPlainCard(radius: 24, horizontalPadding: 16, topPadding: 6, bottomPadding: 6) {
            Group {
                if memories.isEmpty {
                    Text("Nothing remembered.")
                        .font(NoopHTMLFont.sans(13.5))
                        .foregroundStyle(Color(hex: 0x7F8A85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 18)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(memories.enumerated()), id: \.element.id) { index, item in
                            HStack(alignment: .center, spacing: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.text)
                                        .font(NoopHTMLFont.sans(13.5))
                                        .foregroundStyle(NoopHTMLColor.ink)
                                        .noopSveaLineBox(fontSize: 13.5, ratio: 1.45)
                                    Text(item.source)
                                        .font(NoopHTMLFont.sans(11))
                                        .foregroundStyle(Color(hex: 0x7F8A85))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Button("Forget") { forget(item) }
                                    .font(NoopHTMLFont.sans(11.5, weight: .semibold))
                                    .foregroundStyle(Color(hex: 0xA9B4E0))
                                    .buttonStyle(.plain)
                            }
                            .frame(minHeight: 62)
                            .padding(.vertical, 13)
                            .padding(.top, index > 0 ? 1 : 0)
                            .overlay(alignment: .top) {
                                if index > 0 { Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1) }
                            }
                        }
                    }
                }
            }
        }
    }

    private var indexCard: some View {
        NoopSveaPlainCard(radius: 24, horizontalPadding: 16, topPadding: 16, bottomPadding: 16) {
            VStack(alignment: .leading, spacing: 11) {
                NoopSveaEyebrow("The index")
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Text("\(indexCount)")
                        .font(NoopHTMLFont.outfit200(34))
                        .tracking(-1.36)
                        .monospacedDigit()
                    Text("facts · built on this phone · \(indexSize)")
                        .font(NoopHTMLFont.sans(12.5))
                        .foregroundStyle(NoopHTMLColor.copy)
                }
                .frame(height: 34, alignment: .top)
                .offset(y: -5)
                HStack(spacing: 7) {
                    Button(rebuilt ? "Rebuilt" : "Rebuild") {
                        Task {
                            await CoachSemanticMemory.shared.rebuild()
                            rebuilt = true
                        }
                    }
                    .buttonStyle(NoopSveaSecondaryButtonStyle(height: 44, radius: 15, fontSize: 12.5))
                    Button("Delete all") { showDeleteAll = true }
                        .buttonStyle(NoopSveaWarmButtonStyle())
                }
                Text("Deleting is immediate and local. It does not ask the provider to forget anything, because nothing was stored there — and the screen says so rather than implying a reach it does not have.")
                    .font(NoopHTMLFont.sans(11))
                    .foregroundStyle(Color(hex: 0x7F8A85))
                    .noopSveaLineBox(fontSize: 11, ratio: 1.55)
            }
        }
    }

    private var withdrawRow: some View {
        Button { navigation.push(.consent) } label: {
            HStack(spacing: 13) {
                NoopSveaGlyph(name: .lock, size: 17, color: Color(hex: 0xA9B4E0))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Withdraw a permission")
                        .font(NoopHTMLFont.sans(13.5))
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text("takes effect on the next question, not eventually")
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(Color(hex: 0x7F8A85))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                NoopSveaChevron(size: 8, color: NoopHTMLColor.faint)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        }
        .buttonStyle(NoopHTMLPressStyle())
    }

    private var usesDemoMemories: Bool {
        NoopSveaFixture.enabled && memoryStore.facts.isEmpty && !demoCleared
    }

    private var memories: [NoopSveaMemoryItem] {
        if usesDemoMemories {
            return Self.demoMemories.filter { !demoForgotten.contains($0.id) }
        }
        return memoryStore.facts.map { fact in
            let source: String
            switch fact.source {
            case .user: source = "you told Svea"
            case .coachTool: source = "saved by Svea after your conversation"
            case .conversationSummary: source = "from a conversation you had"
            case .legacy: source = "from your earlier local record"
            }
            return .init(
                id: fact.id,
                text: fact.text,
                source: "\(source) · \(fact.createdAt.formatted(date: .abbreviated, time: .omitted))",
                isDemo: false
            )
        }
    }

    private var introText: String {
        if usesDemoMemories {
            return "Eleven facts, each one traceable to the day you said it. Nothing here was inferred about you in the background — a memory only forms out of something you wrote or logged."
        }
        return "\(indexCount) \(indexCount == 1 ? "fact" : "facts"), each one traceable to the day it entered your record. Nothing here was inferred about you in the background — a memory only forms out of something you wrote or logged."
    }

    private var indexCount: Int {
        usesDemoMemories ? max(0, 11 - demoForgotten.count) : memories.count
    }

    private var indexSize: String {
        if usesDemoMemories { return "2.1 MB" }
        return memories.isEmpty ? "0 KB" : "local index"
    }

    private func forget(_ item: NoopSveaMemoryItem) {
        if item.isDemo {
            demoForgotten.insert(item.id)
        } else {
            memoryStore.remove(item.id)
        }
    }

    private func deleteAll() {
        memoryStore.clearAll()
        demoCleared = true
        demoForgotten = Set(Self.demoMemories.map(\.id))
        Task { await CoachSemanticMemory.shared.deleteIndex() }
        showDeleteAll = false
    }

    private static let demoMemories: [NoopSveaMemoryItem] = [
        .init(id: UUID(uuidString: "A7000000-0000-0000-0000-000000000001")!, text: "You lift Tuesdays and Thursdays, and would rather not move them.", source: "from your journal · 3 weeks ago", isDemo: true),
        .init(id: UUID(uuidString: "A7000000-0000-0000-0000-000000000002")!, text: "A 7h night is enough for you; 6h is not.", source: "observed across 60 nights · 2 months ago", isDemo: true),
        .init(id: UUID(uuidString: "A7000000-0000-0000-0000-000000000003")!, text: "You are training toward a half marathon in October.", source: "you told Svea · 5 weeks ago", isDemo: true),
        .init(id: UUID(uuidString: "A7000000-0000-0000-0000-000000000004")!, text: "Coffee after 14:00 costs you deep sleep.", source: "from your own journal correlation · 6 weeks ago", isDemo: true)
    ]
}

// MARK: - Exact Act 7 surfaces and controls

private struct NoopSveaScrollScreen<Content: View>: View {
    let bottomInset: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.width, UIScreen.main.bounds.width)
            ScrollView {
                content
                    .frame(width: width, alignment: .topLeading)
                    .padding(.bottom, bottomInset)
                    .id("noop-svea-top")
            }
            .scrollIndicators(.hidden)
            .frame(width: width)
            .background(Color.clear)
        }
        .frame(width: UIScreen.main.bounds.width)
        .background(Color.clear)
    }
}

private struct NoopSveaRouteHeader: View {
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
                .frame(width: 36, height: 36)
            }
            .buttonStyle(NoopHTMLPressStyle())
            Text(label)
                .font(NoopHTMLFont.sans(13.5))
                .foregroundStyle(NoopHTMLColor.copy)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 56)
        .padding(.bottom, 6)
    }
}

private struct NoopSveaRouteTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(NoopHTMLFont.outfit(25, weight: .light))
            .tracking(-0.75)
            .foregroundStyle(NoopHTMLColor.ink)
            .frame(minHeight: 30, alignment: .top)
    }
}

private struct NoopSveaPlainCard<Content: View>: View {
    let radius: CGFloat
    let horizontalPadding: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, horizontalPadding + 1)
            .padding(.top, topPadding + 1)
            .padding(.bottom, bottomPadding + 1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
    }
}

private struct NoopSveaGradientCard<Content: View>: View {
    let tint: Color
    let startOpacity: Double
    let endOpacity: Double
    let angle: Double
    let borderOpacity: Double
    let radius: CGFloat
    let horizontalPadding: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, horizontalPadding + 1)
            .padding(.top, topPadding + 1)
            .padding(.bottom, bottomPadding + 1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                NoopCSSLinearGradient(
                    colors: [tint.opacity(startOpacity), tint.opacity(endOpacity)],
                    degrees: angle
                )
                .clipShape(RoundedRectangle(cornerRadius: radius))
            }
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(tint.opacity(borderOpacity), lineWidth: 0.5))
    }
}

private struct NoopSveaTintCard<Content: View>: View {
    let fillOpacity: Double
    let borderOpacity: Double
    let radius: CGFloat
    let horizontalPadding: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, horizontalPadding + 1)
            .padding(.top, topPadding + 1)
            .padding(.bottom, bottomPadding + 1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NoopHTMLColor.night.opacity(fillOpacity), in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(NoopHTMLColor.night.opacity(borderOpacity), lineWidth: 0.5))
    }
}

private struct NoopSveaEyebrow: View {
    let text: String
    let size: CGFloat
    let tracking: CGFloat
    let color: Color

    init(_ text: String, size: CGFloat = 10, tracking: CGFloat? = nil, color: Color = NoopHTMLColor.muted) {
        self.text = text
        self.size = size
        self.tracking = tracking ?? size * 0.14
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(NoopHTMLFont.sans(size, weight: .semibold))
            .tracking(tracking)
            .foregroundStyle(color)
    }
}

private struct NoopSveaChip: View {
    let text: String
    let selected: Bool
    let selectedTint: Color
    let action: () -> Void

    init(_ text: String, selected: Bool, selectedTint: Color = NoopHTMLColor.night, action: @escaping () -> Void) {
        self.text = text
        self.selected = selected
        self.selectedTint = selectedTint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(NoopHTMLFont.sans(12, weight: .semibold))
                .foregroundStyle(selected ? Color(hex: 0x0C1024) : Color(hex: 0xA9B2AE))
                .padding(.horizontal, 13.5)
                .padding(.vertical, 8)
                .frame(minHeight: 33)
                .background(selected ? selectedTint : Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(selected ? .clear : Color.white.opacity(0.10), lineWidth: 0.5))
        }
        .buttonStyle(NoopHTMLPressStyle())
    }
}

private struct NoopSveaRadioMark: View {
    let selected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(selected ? NoopHTMLColor.night : .clear)
                .overlay(Circle().stroke(selected ? NoopHTMLColor.night : Color.white.opacity(0.22), lineWidth: 1.6))
            if selected {
                Circle().fill(Color(hex: 0xDDE3F6)).frame(width: 8, height: 8)
            }
        }
        .frame(width: 20.2, height: 20.2)
    }
}

private struct NoopSveaToggle: View {
    let isOn: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Capsule()
                .fill(isOn ? tint : Color.white.opacity(0.13))
                .frame(width: 44, height: 27)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(.white)
                        .frame(width: 21, height: 21)
                        .padding(3)
                }
        }
        .buttonStyle(NoopHTMLPressStyle())
        .animation(.easeOut(duration: 0.18), value: isOn)
    }
}

private struct NoopSveaFlowRow: View {
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Circle()
                .fill(color)
                .shadow(color: color, radius: 5)
                .frame(width: 9, height: 9)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(NoopHTMLFont.sans(12.5, weight: .semibold))
                    .foregroundStyle(NoopHTMLColor.ink)
                Text(detail)
                    .font(NoopHTMLFont.sans(11.5))
                    .foregroundStyle(Color(hex: 0xB7C3C9))
                    .noopSveaLineBox(fontSize: 11.5, ratio: 1.55)
                    .frame(height: 35.625, alignment: .top)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 53.625, alignment: .top)
    }
}

private struct NoopSveaHRVChart: View {
    private let values = [59, 61, 58, 63, 65, 66, 68]

    var body: some View {
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                let last = index == values.count - 1
                VStack(spacing: 5) {
                    Text("\(value)")
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(last ? NoopHTMLColor.blueLight : NoopHTMLColor.faint)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(last ? NoopHTMLColor.blueLight : Color.white.opacity(0.16))
                        .frame(height: CGFloat(round(Double(value - 52) / 20 * 44) + 6))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 66, alignment: .bottom)
    }
}

private struct NoopSveaMiniOrb: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let pulse = reduceMotion ? 0 : NoopA4Animation.pulse(
                seconds: timeline.date.timeIntervalSinceReferenceDate,
                duration: 6
            )
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: NoopHTMLColor.night.opacity(0.45), location: 0),
                                .init(color: .clear, location: 0.66)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 32.53
                        )
                    )
                    .frame(width: 46, height: 46)
                    .blur(radius: 5)
                    .opacity(0.60 + pulse * 0.40)
                    .scaleEffect(1 + pulse * 0.06)

                NoopA4BlobShape(radii: .init(
                    tlx: 0.58, tly: 0.49,
                    trx: 0.42, try_: 0.55,
                    brx: 0.46, bry: 0.45,
                    blx: 0.54, bly: 0.51
                ))
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(hex: 0xDDE3F6), location: 0),
                            .init(color: NoopHTMLColor.night, location: 0.58),
                            .init(color: Color(hex: 0x4A56A8), location: 1)
                        ],
                        center: UnitPoint(x: 0.44, y: 0.38),
                        startRadius: 0,
                        endRadius: 25.06
                    )
                )
                .frame(width: 30, height: 30)
                .shadow(color: NoopHTMLColor.night.opacity(0.55), radius: 7)
            }
        }
        .frame(width: 34, height: 34)
    }
}

private struct NoopSveaLargeOrb: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var dimmed = false

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let seconds = timeline.date.timeIntervalSinceReferenceDate
            let pulse = reduceMotion ? 0 : NoopA4Animation.pulse(seconds: seconds, duration: 8)
            let spin = reduceMotion ? 0 : seconds.truncatingRemainder(dividingBy: 64) / 64 * 360
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: NoopHTMLColor.night.opacity(0.32), location: 0),
                                .init(color: .clear, location: 0.62)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 134.35
                        )
                    )
                    .frame(width: 190, height: 190)
                    .blur(radius: 14)
                    .opacity((0.60 + pulse * 0.40) * (dimmed ? 0.45 : 1))
                    .scaleEffect(1 + pulse * 0.06)

                NoopA4BlobShape(radii: .init(
                    tlx: 0.60, tly: 0.50,
                    trx: 0.40, try_: 0.58,
                    brx: 0.46, bry: 0.42,
                    blx: 0.54, bly: 0.50
                ))
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(hex: 0x080B0A), location: 0),
                            .init(color: Color(hex: 0x080B0A), location: 0.34),
                            .init(color: NoopHTMLColor.night.opacity(0.16), location: 0.43),
                            .init(color: NoopHTMLColor.night.opacity(0.44), location: 0.58),
                            .init(color: Color(hex: 0xA9B4E0, alpha: 0.72), location: 0.74),
                            .init(color: NoopHTMLColor.night.opacity(0.16), location: 0.92),
                            .init(color: .clear, location: 1)
                        ],
                        center: .center,
                        startRadius: 0,
                            endRadius: 93.34
                    )
                )
                .frame(width: 132, height: 132)
                .blur(radius: 4)
                .opacity(dimmed ? 0.45 : 1)

                NoopSveaSpeckField()
                    .frame(width: 132, height: 132)
                    .rotationEffect(.degrees(spin))
                    .opacity(dimmed ? 0.42 : 1)
            }
        }
        .frame(width: 150, height: 150)
    }
}

private struct NoopSveaSpeck: Identifiable {
    let id: Int
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let opacity: Double
}

private struct NoopSveaSpeckField: View {
    private static func hash(_ value: Int) -> Double {
        let x = sin(Double(value) * 127.1 + 311.7) * 43_758.5453
        return x - floor(x)
    }

    private static let specks: [NoopSveaSpeck] = (0..<26).map { index in
        let angle = Double(index) * 2.39996 + hash(index) * 1.2
        let radius = 0.56 + hash(index + 40) * 0.46
        let size = 1.1 + hash(index + 12) * 2
        return .init(
            id: index,
            x: CGFloat(0.5 + cos(angle) * radius * 0.47),
            y: CGFloat(0.5 + sin(angle) * radius * 0.47),
            size: CGFloat(size),
            opacity: 0.20 + hash(index + 7) * 0.45
        )
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ForEach(Self.specks) { speck in
                    Circle()
                        .fill(Color(hex: 0xE2E7FA, alpha: speck.opacity))
                        .frame(width: speck.size, height: speck.size)
                        .shadow(color: NoopHTMLColor.night.opacity(0.85), radius: speck.size * 1.3)
                        .position(x: speck.x * proxy.size.width, y: speck.y * proxy.size.height)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private enum NoopSveaGlyphName {
    case key, lock, memory, pause
}

private struct NoopSveaGlyph: View {
    let name: NoopSveaGlyphName
    let size: CGFloat
    let color: Color

    var body: some View {
        Canvas { context, canvasSize in
            let scale = min(canvasSize.width, canvasSize.height) / 24
            let path = glyphPath.applying(CGAffineTransform(scaleX: scale, y: scale))
            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: 1.7 * scale, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var glyphPath: Path {
        var path = Path()
        switch name {
        case .lock:
            path.addRect(CGRect(x: 6.5, y: 10.5, width: 11, height: 9))
            path.move(to: CGPoint(x: 8.8, y: 10.5))
            path.addLine(to: CGPoint(x: 8.8, y: 8))
            addCircularArc(
                &path,
                from: CGPoint(x: 8.8, y: 8),
                to: CGPoint(x: 15.2, y: 8),
                radius: 3.2,
                largeArc: false,
                sweep: true
            )
            path.addLine(to: CGPoint(x: 15.2, y: 10.5))
        case .pause:
            path.addEllipse(in: CGRect(x: 4.4, y: 4.4, width: 15.2, height: 15.2))
            path.move(to: CGPoint(x: 10.2, y: 9.4)); path.addLine(to: CGPoint(x: 10.2, y: 14.6))
            path.move(to: CGPoint(x: 13.8, y: 9.4)); path.addLine(to: CGPoint(x: 13.8, y: 14.6))
        case .memory:
            path.move(to: CGPoint(x: 12, y: 4.5))
            path.addCurve(to: CGPoint(x: 7.8, y: 8.7), control1: CGPoint(x: 9.7, y: 4.5), control2: CGPoint(x: 7.8, y: 6.4))
            path.addCurve(to: CGPoint(x: 8.7, y: 11.2), control1: CGPoint(x: 7.8, y: 9.7), control2: CGPoint(x: 8.1, y: 10.5))
            path.addCurve(to: CGPoint(x: 7.3, y: 14.3), control1: CGPoint(x: 7.8, y: 12), control2: CGPoint(x: 7.3, y: 13.1))
            path.addCurve(to: CGPoint(x: 12, y: 18.5), control1: CGPoint(x: 7.3, y: 17.1), control2: CGPoint(x: 9.5, y: 18.8))
            path.addCurve(to: CGPoint(x: 16.7, y: 14.3), control1: CGPoint(x: 14.5, y: 18.8), control2: CGPoint(x: 16.7, y: 17.1))
            path.addCurve(to: CGPoint(x: 15.3, y: 11.2), control1: CGPoint(x: 16.7, y: 13.1), control2: CGPoint(x: 16.2, y: 12))
            path.addCurve(to: CGPoint(x: 16.2, y: 8.7), control1: CGPoint(x: 15.9, y: 10.5), control2: CGPoint(x: 16.2, y: 9.7))
            path.addCurve(to: CGPoint(x: 12, y: 4.5), control1: CGPoint(x: 16.2, y: 6.4), control2: CGPoint(x: 14.3, y: 4.5))
            path.move(to: CGPoint(x: 12, y: 4.5)); path.addLine(to: CGPoint(x: 12, y: 18.5))
        case .key:
            path.move(to: CGPoint(x: 14.5, y: 4.5))
            addCircularArc(
                &path,
                from: CGPoint(x: 14.5, y: 4.5),
                to: CGPoint(x: 10.2, y: 12.1),
                radius: 5,
                largeArc: true,
                sweep: false
            )
            path.addLine(to: CGPoint(x: 4.5, y: 17.9))
            path.addLine(to: CGPoint(x: 4.5, y: 19.9))
            path.addLine(to: CGPoint(x: 6.5, y: 19.9))
            path.addLine(to: CGPoint(x: 7.5, y: 18.9))
            path.addLine(to: CGPoint(x: 9.5, y: 18.9))
            path.addLine(to: CGPoint(x: 9.5, y: 16.9))
            path.addLine(to: CGPoint(x: 11.5, y: 16.9))
            path.addLine(to: CGPoint(x: 11.5, y: 14.9))
            path.addLine(to: CGPoint(x: 12.7, y: 13.7))
            path.move(to: CGPoint(x: 15.5, y: 8.2)); path.addLine(to: CGPoint(x: 15.5, y: 8.3))
        }
        return path
    }

    private func addCircularArc(
        _ path: inout Path,
        from start: CGPoint,
        to end: CGPoint,
        radius requestedRadius: CGFloat,
        largeArc: Bool,
        sweep: Bool
    ) {
        let halfDX = (start.x - end.x) / 2
        let halfDY = (start.y - end.y) / 2
        let chordFactor = sqrt(halfDX * halfDX + halfDY * halfDY) / requestedRadius
        let radius = requestedRadius * max(1, chordFactor)
        let numerator = max(0, radius * radius - halfDX * halfDX - halfDY * halfDY)
        let denominator = max(.leastNonzeroMagnitude, halfDX * halfDX + halfDY * halfDY)
        let sign: CGFloat = largeArc == sweep ? -1 : 1
        let coefficient = sign * sqrt(numerator / denominator)
        let center = CGPoint(
            x: (start.x + end.x) / 2 + coefficient * halfDY,
            y: (start.y + end.y) / 2 - coefficient * halfDX
        )

        let startAngle = atan2((start.y - center.y) / radius, (start.x - center.x) / radius)
        var delta = atan2(
            (start.x - center.x) * (end.y - center.y) - (start.y - center.y) * (end.x - center.x),
            (start.x - center.x) * (end.x - center.x) + (start.y - center.y) * (end.y - center.y)
        )
        if sweep, delta < 0 { delta += 2 * .pi }
        if !sweep, delta > 0 { delta -= 2 * .pi }

        let segmentCount = max(1, Int(ceil(abs(delta) / (.pi / 2))))
        let segmentDelta = delta / CGFloat(segmentCount)
        for index in 0..<segmentCount {
            let angle0 = startAngle + CGFloat(index) * segmentDelta
            let angle1 = angle0 + segmentDelta
            let alpha = 4 / 3 * tan(segmentDelta / 4)
            let point0 = CGPoint(x: center.x + radius * cos(angle0), y: center.y + radius * sin(angle0))
            let point1 = CGPoint(x: center.x + radius * cos(angle1), y: center.y + radius * sin(angle1))
            let control0 = CGPoint(x: point0.x - alpha * radius * sin(angle0), y: point0.y + alpha * radius * cos(angle0))
            let control1 = CGPoint(x: point1.x + alpha * radius * sin(angle1), y: point1.y - alpha * radius * cos(angle1))
            path.addCurve(to: point1, control1: control0, control2: control1)
        }
    }
}

private struct NoopSveaChevron: View {
    let size: CGFloat
    let color: Color

    var body: some View {
        Canvas { context, canvasSize in
            var path = Path()
            path.move(to: CGPoint(x: canvasSize.width * 0.16, y: 0))
            path.addLine(to: CGPoint(x: canvasSize.width, y: canvasSize.height * 0.5))
            path.addLine(to: CGPoint(x: canvasSize.width * 0.16, y: canvasSize.height))
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}

private struct NoopSveaSendArrow: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: size.width * 0.14, y: size.height * 0.66))
            path.addLine(to: CGPoint(x: size.width * 0.5, y: size.height * 0.30))
            path.addLine(to: CGPoint(x: size.width * 0.86, y: size.height * 0.66))
            context.stroke(path, with: .color(Color(hex: 0x0C1024)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
        }
    }
}

private struct NoopSveaGrant: Identifiable {
    let id: String
    let title: String
    let detail: String
    let loss: String
}

private struct NoopSveaMemoryItem: Identifiable {
    let id: UUID
    let text: String
    let source: String
    let isDemo: Bool
}

private struct NoopSveaActionButtonStyle: ButtonStyle {
    var primary = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(NoopHTMLFont.sans(12.5, weight: .semibold))
            .foregroundStyle(primary ? Color(hex: 0x0C1024) : NoopHTMLColor.inkSoft)
            .frame(maxWidth: .infinity)
            .frame(height: primary ? 42 : 44)
            .background(primary ? NoopHTMLColor.night : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(primary ? .clear : Color.white.opacity(0.10), lineWidth: 0.5))
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

private struct NoopSveaPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(NoopHTMLFont.sans(14, weight: .semibold))
            .foregroundStyle(Color(hex: 0x0C1024))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(NoopHTMLColor.night, in: RoundedRectangle(cornerRadius: 18))
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

private struct NoopSveaSecondaryButtonStyle: ButtonStyle {
    let height: CGFloat
    let radius: CGFloat
    let fontSize: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(NoopHTMLFont.sans(fontSize, weight: .semibold))
            .foregroundStyle(NoopHTMLColor.inkSoft)
            .frame(maxWidth: .infinity)
            .frame(height: height + 2)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Color.white.opacity(0.10), lineWidth: 0.5))
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

private struct NoopSveaWarmButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(NoopHTMLFont.sans(12.5, weight: .semibold))
            .foregroundStyle(Color(hex: 0xF3C888))
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(Color(hex: 0xF3C888, alpha: 0.10), in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color(hex: 0xF3C888, alpha: 0.30), lineWidth: 0.5))
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

private struct NoopSveaTintButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(NoopHTMLFont.sans(12.5, weight: .semibold))
            .foregroundStyle(Color(hex: 0xC9D0EE))
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(NoopHTMLColor.night.opacity(0.14), in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(NoopHTMLColor.night.opacity(0.34), lineWidth: 0.5))
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

private struct NoopSveaLineBoxModifier: ViewModifier {
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
    func noopSveaLineBox(fontSize: CGFloat, ratio: CGFloat) -> some View {
        modifier(NoopSveaLineBoxModifier(fontSize: fontSize, ratio: ratio))
    }
}

private extension AIProvider {
    var noopDisplayName: String {
        switch self {
        case .anthropic: return "Anthropic"
        case .openAI: return "OpenAI"
        case .gemini: return "Gemini"
        case .openRouter: return "OpenRouter"
        case .custom: return "Custom"
        }
    }

    init?(noopDisplayName: String) {
        switch noopDisplayName {
        case "Anthropic": self = .anthropic
        case "OpenAI": self = .openAI
        case "Gemini": self = .gemini
        case "OpenRouter": self = .openRouter
        case "Custom": self = .custom
        default: return nil
        }
    }
}
