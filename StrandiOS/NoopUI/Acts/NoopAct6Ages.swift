import SwiftUI

struct NoopAct6Screens: View {
    @ObservedObject var navigation: NoopNavigation
    @AppStorage("noop.html.selected-age-driver") private var selectedDriver = 0
    @AppStorage("noop.html.nights-recorded") private var nightsRecorded = 221
    // Onboarding step 2's answer. `ages` says "night" in two places that mean the time of day
    // rather than a count of sleeps, and both have to follow a rotating or permanent-nights answer.
    @AppStorage("noop.schedule.kind") private var scheduleKind = "mostly-nights"

    private var isNightWorker: Bool { NoopScheduleInference.isNightWorker(kind: scheduleKind) }

    var body: some View {
        switch navigation.route {
        case .ages:
            // Change 8.1. Under seven recorded nights `ages` shows this INSTEAD of itself — it is a
            // state, not a destination, and is never reachable again after the seventh night.
            if nightsRecorded < 7 { building } else { ages }
        case .building:
            building
        case .driver:
            driver
        case .method:
            method
        case .health:
            health
        default:
            ages
        }
    }

    // MARK: Your ages

    private var ages: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 12) {
                NoopAgeBackHeader(label: "Trends") { navigation.reset(to: .trends) }

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("6")
                            .font(NoopHTMLFont.outfit(23, weight: .light))
                            .foregroundStyle(Color(hex: 0x8FEFC0))
                        NoopAgeMicroLabel("years younger", alignment: .leading)
                    }
                    .frame(width: 88, alignment: .leading)

                    Spacer()
                    NoopAgeOrb()
                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("0.8×")
                            .font(NoopHTMLFont.outfit(23, weight: .light))
                        NoopAgeMicroLabel("pace of aging", alignment: .trailing)
                    }
                    .frame(width: 88, alignment: .trailing)
                }
                .padding(.vertical, 2)

                Text("Your body is running about 6 years behind your birthday, and it has been for two months.")
                    .font(NoopHTMLFont.outfit(26, weight: .light))
                    .tracking(-0.7)

                NoopHTMLCard(radius: 24, padding: 0) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            NoopSectionLabel("Body age")
                            Spacer()
                            Text("updated weekly")
                                .font(NoopHTMLFont.sans(11))
                                .foregroundStyle(NoopHTMLColor.faint)
                        }
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .firstTextBaseline, spacing: 9) {
                                Text("34")
                                    .font(NoopHTMLFont.outfit200(76))
                                    .tracking(-3.8)
                                    .frame(height: 68.4, alignment: .top)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("years")
                                        .font(NoopHTMLFont.sans(13))
                                        .foregroundStyle(NoopHTMLColor.copy)
                                    Text("6 years younger than your age")
                                        .font(NoopHTMLFont.sans(13.5, weight: .medium))
                                        .foregroundStyle(NoopHTMLColor.green)
                                }
                                .padding(.bottom, 5)
                            }
                            NoopAgeBand()
                            Text("The band is part of the number. Anywhere inside it is the same reading — and yours runs from 29 to 39.")
                                .font(NoopHTMLFont.sans(11.5))
                                .foregroundStyle(NoopHTMLColor.copy)
                                .lineSpacing(3)
                        }
                        .offset(y: -13)
                        .padding(.bottom, -6.5)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 20)
                }

                HStack {
                    NoopSectionLabel("What's moving it")
                    Spacer()
                    Text("signed, per factor")
                        .font(NoopHTMLFont.sans(11))
                        .foregroundStyle(NoopHTMLColor.faint)
                }
                .padding(.horizontal, 2)
                .padding(.top, 8)

                NoopHTMLCard(radius: 24, padding: 0) {
                    VStack(spacing: 11) {
                        HStack {
                            NoopSectionLabel("← takes years off", color: Color(hex: 0x8FEFC0))
                            Spacer()
                            NoopSectionLabel("adds years →", color: Color(hex: 0xF3C888))
                        }
                        VStack(spacing: 0) {
                            ForEach(Array(NoopAgeDriver.all.enumerated()), id: \.offset) { index, item in
                                Button {
                                    selectedDriver = index
                                    navigation.push(.driver)
                                } label: {
                                    NoopAgeDriverRow(item: item)
                                }
                                .buttonStyle(NoopHTMLPressStyle())
                                if index < NoopAgeDriver.all.count - 1 {
                                    Divider().overlay(NoopHTMLColor.border).frame(height: 0.5)
                                }
                            }
                        }
                        Text("Each factor is measured against the norm for someone your age. They do not add up to the number above — the model is not a sum.")
                            .font(NoopHTMLFont.sans(11.5))
                            .foregroundStyle(NoopHTMLColor.copy)
                            .lineSpacing(3)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 15)
                    .padding(.bottom, 16)
                }

                NoopHTMLCard(radius: 24, padding: 16) {
                    VStack(alignment: .leading, spacing: 13) {
                        HStack {
                            NoopSectionLabel("Body age over time")
                            Spacer()
                            NoopAgeChangeChip(text: "−3.1 yr since 14 Jun")
                        }
                        NoopBodyAgeHistoryChart(values: NoopAgeHistoryData.values)
                        HStack {
                            Text("14 Jun"); Spacer(); Text("5 Jul"); Spacer(); Text("26 Jul"); Spacer(); Text("16 Aug")
                        }
                        .font(NoopHTMLFont.sans(10.5))
                        .foregroundStyle(NoopHTMLColor.faint)
                        Text("Ten weeks. The shaded ribbon is the same ± 5 years, carried at every point — which is why a single week's wobble means nothing. Next update Saturday.")
                            .font(NoopHTMLFont.sans(11.5))
                            .foregroundStyle(NoopHTMLColor.copy)
                            .lineSpacing(3)
                    }
                }

                NoopHTMLCard(radius: 24, padding: 16) {
                    VStack(alignment: .leading, spacing: 13) {
                        NoopSectionLabel("A different question")
                        HStack(spacing: 9) {
                            NoopAgeLavenderMetric(title: "Fitness age", value: "31", unit: "± 5 yr")
                            NoopAgeLavenderMetric(title: "VO₂ max", value: "47.2", unit: "ml/kg/min")
                        }
                        (
                            Text("Fitness Age compares one thing — how much oxygen you can use — against norms for your sex and age. ")
                            + Text("It is not a biological age.").font(NoopHTMLFont.sans(11.5, weight: .semibold)).foregroundColor(NoopHTMLColor.inkSoft)
                            + Text(" It reads none of the sleep or variability signals above, so it can sit years away from Body Age without either being wrong.")
                        )
                            .font(NoopHTMLFont.sans(11.5))
                            .foregroundStyle(NoopHTMLColor.copy)
                            .lineSpacing(3)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    NoopSectionLabel("Health domains")
                    Text("14 of 28 instruments · moderate confidence")
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(NoopHTMLColor.copy)
                }
                .padding(.horizontal, 2)
                .padding(.top, 8)

                NoopHTMLCard(radius: 24, padding: 16) {
                    VStack(spacing: 15) {
                        HStack {
                            Text("0"); Spacer(); Text("50"); Spacer(); Text("100")
                        }
                        .font(NoopHTMLFont.sans(10))
                        .foregroundStyle(NoopHTMLColor.faint)
                        ForEach(NoopAgeDomain.all) { domain in
                            VStack(spacing: 7) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(domain.name).font(NoopHTMLFont.sans(13))
                                    Spacer()
                                    Text("\(domain.weight)% of score")
                                        .font(NoopHTMLFont.sans(11))
                                        .foregroundStyle(NoopHTMLColor.copy)
                                    Text("\(domain.score)")
                                        .font(NoopHTMLFont.outfit(19, weight: .light))
                                        .frame(width: 28, alignment: .trailing)
                                }
                                NoopProgressBar(
                                    progress: Double(domain.score) / 100,
                                    color: NoopHTMLColor.night,
                                    height: domain.height,
                                    trackOpacity: 0.09
                                )
                            }
                        }
                        Text("A domain is where you stand out of 100, from a second scorer that knows nothing about the drivers above. Nothing here is signed, and the thicker the bar, the more it counts.")
                            .font(NoopHTMLFont.sans(11.5))
                            .foregroundStyle(NoopHTMLColor.copy)
                            .lineSpacing(3)
                    }
                }

                NoopAgeGreenCard(horizontalPadding: 18, topPadding: 18, bottomPadding: 17) {
                    VStack(alignment: .leading, spacing: 9) {
                        NoopSectionLabel("The read", color: Color(hex: 0x8FEFC0))
                        Text("Fitness and sleep regularity are carrying this, and they are carrying it together — the regularity came first and the resting pulse followed. The one factor working against you is the simplest to fix: it is steps, not training.")
                            .font(NoopHTMLFont.sans(13.5))
                            .foregroundStyle(Color(hex: 0xD2E2D8))
                            .lineSpacing(4)
                    }
                }

                // Change 5. `ages/health` was built and specified but nothing routed to it.
                NoopAgeHealthHubRow { navigation.push(.health) }

                NoopAgeMethodRow { navigation.push(.method) }

                NoopAgeDisclaimer("Estimates from a wrist sensor, not a diagnosis. Body Age is a statistical comparison against population data — it is not a prediction about you, and no part of this screen is a medical device.")
            }
        }
    }

    // MARK: First week

    private var building: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 12) {
                NoopAgeBackHeader(label: "Trends") { navigation.reset(to: .trends) }
                NoopAgeLead("Body Age needs three more nights before it will say anything.")

                NoopHTMLCard(radius: 24, padding: 18) {
                    VStack(alignment: .leading, spacing: 13) {
                        HStack {
                            NoopSectionLabel("Body age")
                            Spacer()
                            Text("first estimate Sat 30 Aug")
                                .font(NoopHTMLFont.sans(11))
                                .foregroundStyle(NoopHTMLColor.faint)
                        }
                        HStack(alignment: .bottom, spacing: 10) {
                            Text("—")
                                .font(NoopHTMLFont.outfit200(70))
                                .tracking(-3.5)
                                .foregroundStyle(Color(hex: 0x3E4643))
                                .frame(height: 63, alignment: .top)
                            Text("± 5 yr\nnot yet available")
                                .font(NoopHTMLFont.sans(13))
                                .foregroundStyle(Color(hex: 0x8B958F))
                                .padding(.bottom, 8)
                        }
                        VStack(spacing: 7) {
                            HStack {
                                Text("2 of 4 requirements met")
                                    .foregroundStyle(NoopHTMLColor.copy)
                                Spacer()
                                Text("1 optional")
                                    .foregroundStyle(Color(hex: 0x7F8A85))
                            }
                            .font(NoopHTMLFont.sans(11.5))
                            HStack(spacing: 4) {
                                ForEach(0..<4, id: \.self) { i in
                                    Capsule().fill(i < 2 ? NoopHTMLColor.green : Color.white.opacity(0.13)).frame(height: 4)
                                }
                            }
                        }
                    }
                }

                NoopHTMLCard(radius: 24, padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(NoopAgeRequirement.all.enumerated()), id: \.offset) { index, item in
                            NoopAgeRequirementRow(item: item)
                            if index < NoopAgeRequirement.all.count - 1 { Divider().overlay(NoopHTMLColor.border) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }

                NoopHTMLCard(radius: 22, padding: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fitness Age").font(NoopHTMLFont.sans(13.5))
                            Text("needs one effort hard enough to read")
                                .font(NoopHTMLFont.sans(11.5))
                                .foregroundStyle(NoopHTMLColor.copy)
                        }
                        Spacer()
                        Text("—")
                            .font(NoopHTMLFont.outfit200(26))
                            .foregroundStyle(Color(hex: 0x3E4643))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 15)
                }

                Text("Noop will not estimate an age from a partial week. Four nights is enough to draw something plausible and not enough to draw something true, so this screen stays empty until it isn't.")
                    .font(NoopHTMLFont.sans(11.5))
                    .foregroundStyle(Color(hex: 0x8B958F))
                    .lineSpacing(3)
                    .padding(.horizontal, 2)
                    .padding(.top, 4)
                NoopAgeDisclaimer(
                    "Estimates from a wrist sensor, not a diagnosis. No part of this screen is a medical device.",
                    topPadding: 0
                )
            }
        }
    }

    // MARK: Driver

    private var driver: some View {
        let item = NoopAgeDriver.all[min(max(selectedDriver, 0), NoopAgeDriver.all.count - 1)]
        return NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 12) {
                NoopAgeBackHeader(label: "Your ages") { navigation.reset(to: .ages) }
                NoopAgeLead(item.lead)

                NoopHTMLCard(radius: 24, padding: 18) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            NoopSectionLabel(item.name)
                            Spacer()
                            Text(item.rank)
                                .font(NoopHTMLFont.sans(11))
                                .foregroundStyle(NoopHTMLColor.faint)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 9) {
                            Text(item.effect)
                                .font(NoopHTMLFont.outfit200(52))
                                .tracking(-2.2)
                                .foregroundStyle(item.color)
                                .frame(height: 52, alignment: .top)
                            Text(item.protective ? "off Body Age" : "onto Body Age")
                                .font(NoopHTMLFont.sans(13))
                                .foregroundStyle(NoopHTMLColor.copy)
                                .padding(.bottom, 4)
                        }
                        NoopDriverScale(item: item)
                    }
                }

                NoopHTMLCard(radius: 24, padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            NoopSectionLabel("Ten weeks")
                            Spacer()
                            Text(item.trendNote)
                                .font(NoopHTMLFont.sans(11))
                                .foregroundStyle(NoopHTMLColor.copy)
                        }
                        NoopAgeDriverTrendChart(item: item)
                    }
                }

                NoopHTMLCard(radius: 24, padding: 16) {
                    VStack(alignment: .leading, spacing: 9) {
                        NoopSectionLabel("What would move it")
                        Text(item.move)
                            .font(NoopHTMLFont.sans(13.5))
                            .foregroundStyle(NoopHTMLColor.inkSoft)
                            .lineSpacing(4)
                    }
                }
                NoopAgeDisclaimer(item.caveat)
            }
        }
    }

    // MARK: Method

    private var method: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 12) {
                NoopAgeBackHeader(label: "Your ages") { navigation.reset(to: .ages) }
                NoopAgeLead("It is a model, and you should know what it is made of.")

                NoopHTMLCard(radius: 24, padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(NoopAgeInput.all.enumerated()), id: \.offset) { index, input in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(input.name).font(NoopHTMLFont.sans(13.5))
                                    Text(input.cover)
                                        .font(NoopHTMLFont.sans(11.5))
                                        .foregroundStyle(NoopHTMLColor.copy)
                                }
                                Spacer()
                                NoopAgeStatePill(partial: input.partial)
                            }
                            .frame(minHeight: 58)
                            if index < NoopAgeInput.all.count - 1 { Divider().overlay(NoopHTMLColor.border) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }

                NoopHTMLCard(radius: 24, padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        NoopSectionLabel("Confidence")
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 14), spacing: 4) {
                            ForEach(0..<28, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(i < 14 ? NoopHTMLColor.green : Color.white.opacity(0.09))
                                    .frame(height: 16)
                            }
                        }
                        HStack {
                            Text("14 of 28 instruments · moderate confidence")
                                .font(NoopHTMLFont.sans(12.5))
                            Spacer()
                            Text("28 possible")
                                .font(NoopHTMLFont.sans(11))
                                .foregroundStyle(NoopHTMLColor.faint)
                        }
                        Text("Fourteen reading, fourteen dark. Entering recent blood work would light six of them; the rest need longer wear.")
                            .font(NoopHTMLFont.sans(11.5))
                            .foregroundStyle(NoopHTMLColor.copy)
                            .lineSpacing(3)
                    }
                }

                NoopHTMLCard(radius: 24, padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        NoopSectionLabel("Why ± 5 years")
                        Text("The model was fitted on a population, and on that population it lands within about five years of the truth. Your own five years are not noise to be averaged away — they are the honest width of the answer, which is why the band is drawn every time the number is.")
                            .font(NoopHTMLFont.sans(13.5))
                            .foregroundStyle(NoopHTMLColor.inkSoft)
                            .lineSpacing(4)
                    }
                }

                NoopHTMLCard(radius: 24, padding: 16) {
                    VStack(alignment: .leading, spacing: 11) {
                        NoopSectionLabel("What it is not")
                        ForEach(NoopAgeNot.all, id: \.self) { sentence in
                            HStack(alignment: .top, spacing: 10) {
                                Circle().fill(NoopHTMLColor.faint).frame(width: 5, height: 5).padding(.top, 7)
                                Text(sentence)
                                    .font(NoopHTMLFont.sans(13))
                                    .foregroundStyle(NoopHTMLColor.copy)
                                    .lineSpacing(3)
                            }
                        }
                    }
                }
                NoopAgeDisclaimer("Everything on this screen was computed on this phone. Nothing was sent anywhere to produce it.")
            }
        }
    }

    // MARK: Health hub

    private var health: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 12) {
                NoopAgeBackHeader(label: "Your ages") { navigation.reset(to: .ages) }
                NoopAgeLead(isNightWorker
                    ? "What was measured during your last sleep, and nothing estimated from it."
                    : "What was measured last night, and nothing estimated from it.")

                NoopHTMLCard(radius: 24, padding: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        NoopSectionLabel(isNightWorker ? "Vitals while you slept" : "Overnight vitals")
                        ForEach(Array(NoopHealthVital.all.enumerated()), id: \.offset) { index, vital in
                            HStack {
                                Text(vital.name).font(NoopHTMLFont.sans(13.5))
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        Text(vital.value).font(NoopHTMLFont.outfit(20, weight: .light))
                                        Text(vital.unit).font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.copy)
                                    }
                                    Text(vital.baseline).font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.faint)
                                }
                            }
                            .frame(minHeight: 62)
                            if index < NoopHealthVital.all.count - 1 { Divider().overlay(NoopHTMLColor.border) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 6)
                }

                NoopHTMLCard(radius: 24, padding: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        NoopSectionLabel("Body composition")
                        HStack {
                            Text("Weight").font(NoopHTMLFont.sans(13.5)); Spacer()
                            Text("74.2").font(NoopHTMLFont.outfit(20, weight: .light))
                            Text("kg").font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.copy)
                        }
                        .frame(minHeight: 56)
                        .padding(.top, 6)
                        Divider().overlay(NoopHTMLColor.border)
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Body fat").font(NoopHTMLFont.sans(13.5))
                                Text("never entered — the strap cannot measure it")
                                    .font(NoopHTMLFont.sans(11.5))
                                    .foregroundStyle(NoopHTMLColor.copy)
                            }
                            Spacer()
                            Text("—").font(NoopHTMLFont.outfit200(22)).foregroundStyle(Color(hex: 0x3E4643))
                        }
                        .frame(minHeight: 56)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 6)
                }

                Button { navigation.reset(to: .ages) } label: {
                    NoopAgeGreenCard {
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 5) {
                                NoopSectionLabel("Estimated", color: Color(hex: 0x8FEFC0))
                                Text("Your ages").font(NoopHTMLFont.sans(15))
                                Text("Body Age 34 · Fitness Age 31 · five domains — all of it lives in one place now")
                                    .font(NoopHTMLFont.sans(11.5))
                                    .foregroundStyle(Color(hex: 0xB4C9BE))
                                    .lineSpacing(2)
                            }
                            Spacer()
                            NoopChevron(color: Color(hex: 0x8FEFC0))
                        }
                    }
                }
                .buttonStyle(NoopHTMLPressStyle())

                NoopAgeHealthLinks(
                    biomarkers: { navigation.push(.labs) },
                    monitor: { navigation.push(.heart) }
                )
                NoopAgeDisclaimer("Measured values, as recorded. Where a value is absent it is shown absent — nothing on this screen is filled in with a plausible number.")
            }
        }
    }
}

// MARK: - Act 6 components

private struct NoopAgeBackHeader: View {
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
    }
}

private struct NoopAgeMicroLabel: View {
    let text: String
    let alignment: TextAlignment

    init(_ text: String, alignment: TextAlignment) {
        self.text = text
        self.alignment = alignment
    }

    var body: some View {
        Text(text.uppercased())
            .font(NoopHTMLFont.sans(9.5, weight: .semibold))
            .tracking(1.25)
            .foregroundStyle(Color(hex: 0x7F8A85))
            .lineSpacing(1.7)
            .multilineTextAlignment(alignment)
    }
}

private struct NoopAgeLead: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(NoopHTMLFont.outfit(26, weight: .light))
            .tracking(-0.7)
    }
}

private struct NoopAgeDisclaimer: View {
    let text: String
    let topPadding: CGFloat

    init(_ text: String, topPadding: CGFloat = 2) {
        self.text = text
        self.topPadding = topPadding
    }

    var body: some View {
        Text(text)
            .font(NoopHTMLFont.sans(11))
            .foregroundStyle(NoopHTMLColor.faint)
            .lineSpacing(3)
            .padding(.horizontal, 2)
            .padding(.top, topPadding)
    }
}

/// The green cards in the HTML use a directional wash, not a flat tint.
private struct NoopAgeGreenCard<Content: View>: View {
    let horizontalPadding: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    @ViewBuilder let content: Content

    init(
        horizontalPadding: CGFloat = 16,
        topPadding: CGFloat = 16,
        bottomPadding: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.horizontalPadding = horizontalPadding
        self.topPadding = topPadding
        self.bottomPadding = bottomPadding
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, horizontalPadding)
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                NoopCSSLinearGradient(
                    colors: [NoopHTMLColor.green.opacity(0.16), NoopHTMLColor.green.opacity(0.03)],
                    degrees: 158
                )
                .clipShape(RoundedRectangle(cornerRadius: 24))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(NoopHTMLColor.green.opacity(0.30), lineWidth: 0.5)
            )
    }
}

private struct NoopAgeChangeChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(NoopHTMLFont.sans(11, weight: .semibold))
            .foregroundStyle(Color(hex: 0x8FEFC0))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(NoopHTMLColor.green.opacity(0.13), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct NoopAgeOrb: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let seconds = timeline.date.timeIntervalSinceReferenceDate
            let morph = NoopA4Animation.morph(seconds: seconds, duration: 24, reversed: false)
            let spin = reduceMotion ? 0 : seconds.truncatingRemainder(dividingBy: 60) / 60 * 360

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: NoopHTMLColor.green.opacity(0.30), location: 0),
                                .init(color: .clear, location: 0.62)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 75
                        )
                    )
                    .frame(width: 150, height: 150)
                    .blur(radius: 10)

                NoopA4BlobShape(radii: morph.radii)
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: Color(hex: 0x080B0A), location: 0),
                                .init(color: Color(hex: 0x080B0A), location: 0.30),
                                .init(color: NoopHTMLColor.green.opacity(0.10), location: 0.39),
                                .init(color: NoopHTMLColor.green.opacity(0.34), location: 0.53),
                                .init(color: Color(hex: 0x30CE84, alpha: 0.80), location: 0.70),
                                .init(color: Color(hex: 0x9EF0CC, alpha: 0.42), location: 0.85),
                                .init(color: NoopHTMLColor.green.opacity(0.10), location: 0.95),
                                .init(color: .clear, location: 1)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 89.1
                        )
                    )
                    .frame(width: 126, height: 126)
                    .scaleEffect(morph.scale)
                    .rotationEffect(.degrees(morph.rotation))
                    .blur(radius: 3)

                NoopAgeMiniSpeckField()
                    .frame(width: 126, height: 126)
                    .rotationEffect(.degrees(spin))

                Text("34")
                    .font(NoopHTMLFont.outfit200(38))
                    .tracking(-1.52)
                    .monospacedDigit()
                    .shadow(color: .black.opacity(0.6), radius: 9, y: 2)
            }
        }
        .frame(width: 132, height: 132)
    }
}

private struct NoopAgeMiniSpeck: Identifiable {
    let id: Int
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let opacity: Double
}

private struct NoopAgeMiniSpeckField: View {
    private static func hash(_ value: Int) -> Double {
        let x = sin(Double(value) * 127.1 + 311.7) * 43_758.5453
        return x - floor(x)
    }

    private static let specks: [NoopAgeMiniSpeck] = (0..<30).map { index in
        let angle = Double(index) * 2.39996 + hash(index) * 1.1
        let radius = 0.58 + hash(index + 90) * 0.44
        let size = 1 + hash(index + 31) * 1.8
        return .init(
            id: index,
            x: CGFloat(0.5 + cos(angle) * radius * 0.47),
            y: CGFloat(0.5 + sin(angle) * radius * 0.47),
            size: CGFloat(size),
            opacity: 0.22 + hash(index + 11) * 0.45
        )
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ForEach(Self.specks) { speck in
                    Circle()
                        .fill(Color(hex: 0xD8FFEC, alpha: speck.opacity))
                        .frame(width: speck.size, height: speck.size)
                        .shadow(color: Color(hex: 0x68E6A4, alpha: 0.8), radius: speck.size * 1.3)
                        .position(x: speck.x * proxy.size.width, y: speck.y * proxy.size.height)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct NoopAgeBand: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bandVisible = false

    var body: some View {
        VStack(spacing: 9) {
            GeometryReader { geo in
                let bandLow = geo.size.width * 3 / 17
                let bandHigh = geo.size.width * 13 / 17
                let bodyAge = geo.size.width * 8 / 17
                let chronological = geo.size.width * 14 / 17
                ZStack(alignment: .topLeading) {
                    Capsule()
                        .fill(Color.white.opacity(0.13))
                        .frame(width: geo.size.width, height: 4)
                        .offset(y: 27)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [NoopHTMLColor.green.opacity(0.35), NoopHTMLColor.green.opacity(0.60)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: bandHigh - bandLow, height: 8)
                        .scaleEffect(x: reduceMotion || bandVisible ? 1 : 0.55, y: 1, anchor: .leading)
                        .opacity(reduceMotion || bandVisible ? 1 : 0)
                        .offset(x: bandLow, y: 25)
                    Rectangle().fill(Color(hex: 0x96F0C8, alpha: 0.75)).frame(width: 2, height: 16)
                        .offset(x: bandLow - 1, y: 21)
                    Rectangle().fill(Color(hex: 0x96F0C8, alpha: 0.75)).frame(width: 2, height: 16)
                        .offset(x: bandHigh - 1, y: 21)
                    Rectangle().fill(NoopHTMLColor.ink.opacity(0.45)).frame(width: 1, height: 24)
                        .offset(x: chronological - 0.5, y: 16)
                    Text("you are 40")
                        .font(NoopHTMLFont.sans(10))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .fixedSize()
                        .position(x: chronological, y: 6)
                    ZStack {
                        Circle().fill(NoopHTMLColor.card).frame(width: 20, height: 20)
                        Circle().fill(NoopHTMLColor.ink).frame(width: 14, height: 14)
                    }
                    .shadow(color: Color(hex: 0x96F0C8, alpha: 0.60), radius: 6)
                    .position(x: bodyAge, y: 29)
                }
            }
            .frame(height: 62)
            HStack {
                Text("29").foregroundStyle(NoopHTMLColor.muted)
                Spacer()
                Text("± 5 year band").foregroundStyle(Color(hex: 0x8B958F))
                Spacer()
                Text("39").foregroundStyle(NoopHTMLColor.muted)
            }
            .font(NoopHTMLFont.sans(11))
        }
        .onAppear {
            guard !reduceMotion else {
                bandVisible = true
                return
            }
            withAnimation(.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.62)) {
                bandVisible = true
            }
        }
        .onDisappear { bandVisible = false }
    }
}

private enum NoopAgeHistoryData {
    static let values: [Double] = {
        var result = (0..<10).map { index -> Double in
            let i = Double(index)
            let t = i / 9
            return 34 + 3.1 * (1 - t) + sin(i * 1.71) * 0.34 + sin(i * 0.63) * 0.22
        }
        result[9] = 34
        return result
    }()
}

private struct NoopBodyAgeHistoryChart: View {
    let values: [Double]

    var body: some View {
        Canvas { context, size in
            guard values.count > 1,
                  let smallest = values.min(),
                  let largest = values.max() else { return }

            let lowerBound = smallest - 6.4
            let upperBound = largest + 6.4
            let span = max(upperBound - lowerBound, 1)
            let scale = min(size.width / 300, size.height / 104)
            let origin = CGPoint(x: (size.width - 300 * scale) / 2, y: (size.height - 104 * scale) / 2)
            func point(_ index: Int, offset: Double = 0) -> CGPoint {
                let x = origin.x + 300 * scale * CGFloat(index) / CGFloat(values.count - 1)
                let y = origin.y + 104 * scale * CGFloat((upperBound - (values[index] + offset)) / span)
                return CGPoint(x: x, y: y)
            }

            var ribbon = Path()
            ribbon.move(to: point(0, offset: 5))
            for index in values.indices.dropFirst() { ribbon.addLine(to: point(index, offset: 5)) }
            for index in values.indices.reversed() { ribbon.addLine(to: point(index, offset: -5)) }
            ribbon.closeSubpath()
            context.fill(ribbon, with: .color(NoopHTMLColor.green.opacity(0.10)))

            var line = Path()
            line.move(to: point(0))
            for index in values.indices.dropFirst() { line.addLine(to: point(index)) }
            context.stroke(line, with: .color(NoopHTMLColor.green), style: StrokeStyle(lineWidth: 1.9 * scale, lineCap: .round, lineJoin: .round))

            let end = point(values.count - 1)
            let radius = 3.4 * scale
            let dot = Path(ellipseIn: CGRect(x: end.x - radius, y: end.y - radius, width: radius * 2, height: radius * 2))
            context.fill(dot, with: .color(NoopHTMLColor.canvas))
            context.stroke(dot, with: .color(NoopHTMLColor.green), lineWidth: 1.9 * scale)
        }
        .frame(height: 104)
        .accessibilityLabel("Body age over ten weeks with a five-year uncertainty ribbon")
    }
}

private struct NoopAgeLavenderMetric: View {
    let title: String
    let value: String
    let unit: String
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            NoopSectionLabel(title, color: Color(hex: 0xA9B4E0))
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(value).font(NoopHTMLFont.outfit200(34))
                Text(unit).font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.copy)
            }
        }
        .padding(.horizontal, 13)
        .padding(.top, 13)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NoopHTMLColor.night.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(NoopHTMLColor.night.opacity(0.22), lineWidth: 0.5))
    }
}

private struct NoopAgeDriver: Identifiable {
    let id: String
    let name: String
    let effect: String
    let protective: Bool
    let lead: String
    let rank: String
    let current: String
    let average: String
    let minimum: String
    let maximum: String
    let scale: String
    let trend: [Double]
    let trendNote: String
    let move: String
    let caveat: String
    var color: Color { protective ? Color(hex: 0x8FEFC0) : Color(hex: 0xF3C888) }

    static let all: [NoopAgeDriver] = [
        .init(id: "cardio", name: "Cardio fitness", effect: "−2.9 yr", protective: true, lead: "Your capacity is the single largest thing holding the number down.", rank: "1st largest of 5", current: "47.2 now", average: "45.1 six-month", minimum: "30", maximum: "55", scale: "ml/kg/min, estimated", trend: [45.1, 45.4, 45.8, 45.9, 46.2, 46.4, 46.6, 46.7, 47, 47.2], trendNote: "up from the six-month average", move: "One weekly effort above 85% of your maximum heart rate moves this more than anything else on the screen. Long steady work moves it too, just slower.", caveat: "Estimated from heart rate against pace, not from a lab test. The error on the estimate is about 3 ml/kg/min."),
        .init(id: "sleep", name: "Sleep regularity", effect: "−2.4 yr", protective: true, lead: "Your sleep timing is the steadiest it has been all year, and the model is paying you for it.", rank: "2nd largest of 5", current: "85% now", average: "78% six-month", minimum: "40%", maximum: "100%", scale: "consistency of sleep timing", trend: [78, 79, 77, 80, 81, 82, 83, 84, 84, 85], trendNote: "up from the six-month average", move: "Bed inside the same hour on the two nights you still drift — Friday and Saturday. Regularity counts for more here than duration does.", caveat: "Regularity is how consistent your timing is, not how long you slept. The two are scored separately."),
        .init(id: "rhr", name: "Resting heart rate", effect: "−1.6 yr", protective: true, lead: "Fifty-two beats at rest is well under the norm for forty.", rank: "3rd largest of 5", current: "52 now", average: "55 six-month", minimum: "42 bpm", maximum: "78 bpm", scale: "lower is better here", trend: [55, 55, 54.5, 54, 54, 53.5, 53, 53, 52.5, 52], trendNote: "down from the six-month average", move: "This one follows the others. It fell three beats while sleep regularity rose, and it will not move on its own.", caveat: "Taken from the lowest sustained stretch of the night, which makes it sensitive to a warm room or a late meal."),
        .init(id: "movement", name: "Daily movement", effect: "+0.9 yr", protective: false, lead: "Six and a half thousand steps a day is the one factor adding years.", rank: "4th largest of 5", current: "6.4k now", average: "6.9k six-month", minimum: "2k", maximum: "14k", scale: "thousand steps a day", trend: [6.9, 7.1, 6.8, 6.7, 6.9, 6.5, 6.6, 6.4, 6.5, 6.4], trendNote: "down from the six-month average", move: "The model reads total daily steps, not workouts. Two thousand more a day — roughly twenty minutes of walking — would take this factor to neutral.", caveat: "Steps come from the strap only. Anything you did without wearing it is not counted, and is not guessed at."),
        .init(id: "hrv", name: "Variability vs your age", effect: "+0.4 yr", protective: false, lead: "Sixty-eight milliseconds is normal, and just below the median for your age.", rank: "5th largest of 5", current: "68 ms now", average: "66 ms six-month", minimum: "30 ms", maximum: "110 ms", scale: "nocturnal HRV against the norm for 40", trend: [66, 65, 67, 66, 68, 67, 68, 69, 67, 68], trendNote: "up from the six-month average", move: "Your own journal points at two things: alcohol and late meals. Both show up in this line within a night.", caveat: "HRV is compared with a population norm for your age band. Individual variation is wide, so a small gap here means very little.")
    ]
}

private struct NoopAgeDriverRow: View {
    let item: NoopAgeDriver

    private var magnitude: Double {
        let normalized = item.effect.replacingOccurrences(of: "−", with: "-")
        return abs(Double(normalized.filter { "0123456789.-".contains($0) }) ?? 0)
    }

    var body: some View {
        HStack(spacing: 11) {
            Text(item.name)
                .font(NoopHTMLFont.sans(12.5))
                .foregroundStyle(NoopHTMLColor.inkSoft)
                .frame(width: 98, alignment: .leading)
            GeometryReader { geo in
                let center = geo.size.width / 2
                let width = geo.size.width * CGFloat((6 + magnitude / 2.9 * 42) / 100)
                ZStack(alignment: .topLeading) {
                    Rectangle().fill(Color.white.opacity(0.16))
                        .frame(width: 1, height: 20)
                        .offset(x: center - 0.5)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(item.color)
                        .frame(width: width, height: 10)
                        .offset(x: item.protective ? center - width : center, y: 5)
                }
            }
            .frame(height: 20)
            Text(item.effect)
                .font(NoopHTMLFont.outfit(14.5, weight: .regular))
                .foregroundStyle(item.color)
                .frame(width: 58, alignment: .trailing)
        }
        .frame(minHeight: 40)
        .contentShape(Rectangle())
    }
}

private struct NoopAgeHealthHubRow: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                NoopCanonicalGlyph(name: .heart, size: 19, color: NoopHTMLColor.green)
                    .frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Health hub")
                        .font(NoopHTMLFont.sans(13.5))
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text("your record, your markers, and what they add up to")
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(Color(hex: 0x7F8A85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
                NoopFixedChevron(direction: .right, color: NoopHTMLColor.faint)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))
        }
        .buttonStyle(NoopHTMLPressStyle())
    }
}

private struct NoopAgeMethodRow: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                NoopAgeInfoGlyph()
                VStack(alignment: .leading, spacing: 2) {
                    Text("How this is figured")
                        .font(NoopHTMLFont.sans(13.5))
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text("six inputs, one model, and what it cannot see")
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(Color(hex: 0x7F8A85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
                NoopFixedChevron(direction: .right, color: NoopHTMLColor.faint)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))
        }
        .buttonStyle(NoopHTMLPressStyle())
    }
}

private struct NoopAgeInfoGlyph: View {
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 24
            var path = Path()
            path.addEllipse(in: CGRect(x: 4.4, y: 4.4, width: 15.2, height: 15.2))
            path.move(to: CGPoint(x: 12, y: 10.6))
            path.addLine(to: CGPoint(x: 12, y: 15.8))
            path.move(to: CGPoint(x: 12, y: 8.1))
            path.addLine(to: CGPoint(x: 12, y: 8.2))
            context.stroke(
                path.applying(CGAffineTransform(scaleX: scale, y: scale)),
                with: .color(NoopHTMLColor.green),
                style: StrokeStyle(lineWidth: 1.7 * scale, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(width: 20, height: 20)
        .accessibilityHidden(true)
    }
}

private struct NoopDriverScale: View {
    let item: NoopAgeDriver

    private var minimum: Double { number(in: item.minimum) }
    private var maximum: Double { number(in: item.maximum) }
    private var current: Double { number(in: item.current) }
    private var average: Double { number(in: item.average) }
    private var higherIsBetter: Bool { item.id != "rhr" }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                let width = proxy.size.width
                let currentX = markerX(for: current, width: width)
                ZStack(alignment: .topLeading) {
                    Text(item.current)
                        .font(NoopHTMLFont.sans(11, weight: .semibold))
                        .foregroundStyle(NoopHTMLColor.ink)
                        .fixedSize()
                        .position(x: currentX, y: 6.5)

                    NoopDriverMarkerTriangle(pointsDown: true)
                        .fill(NoopHTMLColor.ink)
                        .frame(width: 10, height: 6)
                        .position(x: currentX, y: 19)
                }
            }
            .frame(height: 22)

            HStack(spacing: 3) {
                ForEach(0..<10, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(segmentColor(at: index))
                        .frame(height: 12)
                }
            }
            .frame(height: 12)

            GeometryReader { proxy in
                let width = proxy.size.width
                let averageX = markerX(for: average, width: width)
                ZStack(alignment: .topLeading) {
                    NoopDriverMarkerTriangle(pointsDown: false)
                        .fill(Color(hex: 0x8B958F))
                        .frame(width: 10, height: 6)
                        .position(x: averageX, y: 3)

                    Text(item.average)
                        .font(NoopHTMLFont.sans(11, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x8B958F))
                        .fixedSize()
                        .position(x: averageX, y: 15.5)
                }
            }
            .frame(height: 22)

            HStack {
                Text(item.minimum); Spacer(); Text(item.scale); Spacer(); Text(item.maximum)
            }
            .font(NoopHTMLFont.sans(10.5))
            .foregroundStyle(NoopHTMLColor.faint)
        }
        .padding(.top, 4)
    }

    private func number(in label: String) -> Double {
        let token = label.split(whereSeparator: { $0.isWhitespace }).first ?? Substring(label)
        return Double(token.filter { "0123456789.-".contains($0) }) ?? 0
    }

    private func markerX(for value: Double, width: CGFloat) -> CGFloat {
        guard maximum > minimum else { return width / 2 }
        let fraction = min(0.96, max(0.04, (value - minimum) / (maximum - minimum)))
        return width * CGFloat(fraction)
    }

    private func segmentColor(at index: Int) -> Color {
        let raw = Double(index) / 9
        let quality = higherIsBetter ? raw : 1 - raw
        if quality > 0.62 { return NoopHTMLColor.green.opacity(0.28 + quality * 0.5) }
        if quality > 0.35 { return Color.white.opacity(0.13) }
        return Color(hex: 0xF2B45C).opacity(0.5 - quality * 0.5)
    }
}

private struct NoopAgeDriverTrendChart: View {
    let item: NoopAgeDriver

    private var minimum: Double { number(in: item.minimum) }
    private var maximum: Double { number(in: item.maximum) }
    private var current: Double { number(in: item.current) }
    private var average: Double { number(in: item.average) }

    private var values: [Double] {
        var result = (0..<10).map { index -> Double in
            let i = Double(index)
            let t = i / 9
            return average + (current - average) * t + sin(i * 1.6) * (maximum - minimum) * 0.012
        }
        result[9] = current
        return result
    }

    var body: some View {
        Canvas { context, size in
            let points = values
            guard points.count > 1,
                  let smallest = points.min(),
                  let largest = points.max() else { return }

            let padding = (largest - smallest) * 0.5 + 0.3
            let span = max(largest - smallest + padding * 2, 0.001)
            let scale = min(size.width / 300, size.height / 84)
            let origin = CGPoint(
                x: (size.width - 300 * scale) / 2,
                y: (size.height - 84 * scale) / 2
            )
            func point(_ index: Int) -> CGPoint {
                CGPoint(
                    x: origin.x + 300 * scale * CGFloat(index) / CGFloat(points.count - 1),
                    y: origin.y + 84 * scale * CGFloat((largest + padding - points[index]) / span)
                )
            }

            var line = Path()
            line.move(to: point(0))
            for index in points.indices.dropFirst() { line.addLine(to: point(index)) }
            context.stroke(
                line,
                with: .color(item.color),
                style: StrokeStyle(lineWidth: 1.9 * scale, lineCap: .round, lineJoin: .round)
            )

            let end = point(points.count - 1)
            let radius = 3.2 * scale
            let dot = Path(ellipseIn: CGRect(
                x: end.x - radius,
                y: end.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
            context.fill(dot, with: .color(NoopHTMLColor.canvas))
            context.stroke(dot, with: .color(item.color), lineWidth: 1.9 * scale)
        }
        .frame(height: 84)
        .accessibilityLabel("Ten-week trend for \(item.name)")
    }

    private func number(in label: String) -> Double {
        let token = label.split(whereSeparator: { $0.isWhitespace }).first ?? Substring(label)
        return Double(token.filter { "0123456789.-".contains($0) }) ?? 0
    }
}

private struct NoopDriverMarkerTriangle: Shape {
    let pointsDown: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if pointsDown {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        } else {
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }
}

private struct NoopAgeDomain: Identifiable {
    let id: String
    let name: String
    let score: Int
    let weight: Int
    let height: CGFloat
    static let all: [NoopAgeDomain] = [
        .init(id: "cardio", name: "Cardiovascular", score: 78, weight: 28, height: 11),
        .init(id: "activity", name: "Activity", score: 64, weight: 24, height: 9),
        .init(id: "composition", name: "Body composition", score: 71, weight: 18, height: 7),
        .init(id: "recovery", name: "Recovery", score: 82, weight: 15, height: 5.5),
        .init(id: "lifestyle", name: "Lifestyle", score: 55, weight: 15, height: 5.5)
    ]
}

private struct NoopAgeRequirement {
    let name: String
    let detail: String
    let status: String
    static let all: [NoopAgeRequirement] = [
        .init(name: "Nights of sleep", detail: "4 of the last 7 nights · needs 7", status: "Building"),
        .init(name: "Nocturnal variability", detail: "5 of 14 nights · needs 14", status: "Building"),
        .init(name: "Resting heart rate baseline", detail: "14 nights, holding steady", status: "Ready"),
        .init(name: "Step history", detail: "9 days recorded", status: "Ready"),
        .init(name: "Cardio fitness estimate", detail: "no walk or run long enough to read yet", status: "Needed"),
        .init(name: "Body composition", detail: "sharpens the domain breakdown, never the age", status: "Optional")
    ]
}

private struct NoopAgeRequirementRow: View {
    let item: NoopAgeRequirement
    private var color: Color {
        switch item.status {
        case "Ready": NoopHTMLColor.green
        case "Building": NoopHTMLColor.night
        case "Needed": Color(hex: 0xF2B45C)
        default: NoopHTMLColor.muted
        }
    }
    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            NoopAgeRequirementMark(status: item.status, color: color)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).font(NoopHTMLFont.sans(13.5))
                Text(item.detail).font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy)
            }
            Spacer()
            NoopSectionLabel(item.status, color: color)
        }
        .frame(minHeight: 34)
        .padding(.vertical, 15)
    }
}

private struct NoopAgeRequirementMark: View {
    let status: String
    let color: Color

    var body: some View {
        Group {
            if status == "Optional" {
                Rectangle()
                    .fill(NoopHTMLColor.faint)
                    .frame(width: 15, height: 1.5)
                    .frame(width: 15, height: 15, alignment: .top)
                    .offset(y: 7)
            } else if status == "Ready" {
                Circle()
                    .fill(color)
                    .overlay(Circle().stroke(color, lineWidth: 1.5))
                    .overlay(Circle().strokeBorder(NoopHTMLColor.card, lineWidth: 2.5).padding(1.5))
                    .frame(width: 15, height: 15)
            } else if status == "Building" {
                ZStack {
                    Circle().fill(color)
                    HStack(spacing: 0) {
                        Color.clear
                        NoopHTMLColor.card
                    }
                    .clipShape(Circle())
                    Circle().stroke(color, lineWidth: 1.5)
                }
                .frame(width: 15, height: 15)
            } else {
                Circle()
                    .stroke(color, lineWidth: 1.5)
                    .frame(width: 15, height: 15)
            }
        }
        .frame(width: 15, height: 15)
    }
}

private struct NoopAgeHealthLinks: View {
    let biomarkers: () -> Void
    let monitor: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            row(
                title: "Biomarkers",
                detail: "2 of 7 markers outside the lab band · drawn 14 Aug",
                glyph: .drop,
                color: Color(hex: 0xF2B45C),
                action: biomarkers
            )
            Divider().overlay(NoopHTMLColor.border).frame(height: 0.5)
            row(
                title: "Health monitor",
                detail: "nothing flagged in 30 days",
                glyph: .heart,
                color: NoopHTMLColor.green,
                action: monitor
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private func row(
        title: String,
        detail: String,
        glyph: NoopCanonicalGlyphName,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                NoopCanonicalGlyph(name: glyph, size: 19, color: color)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(NoopHTMLFont.sans(13.5))
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text(detail)
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(Color(hex: 0x7F8A85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.90)
                }
                Spacer(minLength: 0)
                NoopA4CSSChevron(direction: .right, color: NoopHTMLColor.faint)
            }
            .frame(minHeight: 60)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(NoopHTMLPressStyle())
    }
}

private struct NoopAgeInput {
    let name: String
    let cover: String
    let partial: Bool
    static let all: [NoopAgeInput] = [
        .init(name: "Resting heart rate", cover: "14 of 14 nights", partial: false),
        .init(name: "Cardio fitness", cover: "estimated 6 days ago", partial: false),
        .init(name: "Sleep duration", cover: "13 of 14 nights", partial: false),
        .init(name: "Sleep regularity", cover: "13 of 14 nights", partial: false),
        .init(name: "Nocturnal variability", cover: "14 of 14 nights", partial: false),
        .init(name: "Daily steps", cover: "11 of 14 days · 3 days unworn", partial: true)
    ]
}

private struct NoopAgeStatePill: View {
    let partial: Bool

    var body: some View {
        Text(partial ? "PARTIAL" : "READING")
            .font(NoopHTMLFont.sans(10, weight: .semibold))
            .tracking(0.9)
            .foregroundStyle(partial ? Color(hex: 0xF3C888) : Color(hex: 0x8FEFC0))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                (partial ? NoopHTMLColor.warm : NoopHTMLColor.green).opacity(0.12),
                in: RoundedRectangle(cornerRadius: 7)
            )
    }
}

private enum NoopAgeNot {
    static let all = [
        "Not a prediction about you. It is a comparison with a population, and populations do not have birthdays.",
        "Not a diagnosis, and not a screen for anything. A number that looks fine does not rule anything out.",
        "Not blood work. Six wrist signals cannot see your cholesterol, and this model does not pretend to."
    ]
}

private struct NoopHealthVital {
    let name: String
    let value: String
    let unit: String
    let baseline: String
    static let all: [NoopHealthVital] = [
        .init(name: "Resting heart rate", value: "52", unit: "bpm", baseline: "14-night avg 54"),
        .init(name: "Variability", value: "68", unit: "ms", baseline: "14-night avg 66"),
        .init(name: "Breathing rate", value: "14.2", unit: "rpm", baseline: "14-night avg 14.4"),
        .init(name: "Blood oxygen", value: "97", unit: "%", baseline: "within your usual range"),
        .init(name: "Skin temperature", value: "−0.2", unit: "°C", baseline: "against your own baseline")
    ]
}
