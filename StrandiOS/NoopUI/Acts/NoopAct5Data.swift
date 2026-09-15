#if os(iOS)
import SwiftUI

// MARK: - plumbing/data · the two doors
//
// Import and backup are the same two formats read in opposite directions. The way in is ONE drop
// target, not twelve rows: the importer works out what it was handed from content and key shape, so
// the catalog of twelve is documentation and lives one tap down.
//
// Reading, what-was-written and the-wrong-file are explicit navigation states because Debug capture
// and restoration must be deterministic. They deliberately carry no back button: Stop, Done and
// Choose another file are the exits drawn by the HTML. Blush is the family hue; amber is spent only
// on the rejected file that needs something from the reader.
//
// Metrics below are the handoff's, read off the drawn frames rather than paraphrased: section labels
// sit ABOVE their card, trailing notes sit BELOW it, list cards are padded 4/16 with a hairline
// between rows, and the two figure heroes are Outfit 200.

struct NoopDataScreen: View {
    @ObservedObject var navigation: NoopNavigation
    @State private var connectedServices: Set<String> = ["Apple Health"]

    private static let blush = Color(hex: 0xE08A9B)
    private static let blushLight = Color(hex: 0xF6D3DA)
    private static let blushInk = Color(hex: 0x201013)
    /// rgb(139,149,143) — the handoff's sub-copy and section-label grey inside the phone.
    private static let dim = Color(hex: 0x8B958F)

    var body: some View {
        switch navigation.route {
        case .importHistory: importScreen
        case .reading: reading
        case .imported: imported
        case .rejected: rejected
        case .backup: backupScreen
        default: dataHome
        }
    }

    // MARK: 1 · The door in, and 5 · the door out

    private var importScreen: some View {
        NoopScreen(topInset: 56, horizontalInset: 18) {
            VStack(alignment: .leading, spacing: 0) {
                NoopBackHeader(label: "Your data") { navigation.back(or: .data) }

                VStack(alignment: .leading, spacing: 0) {
                    Text("Bring your history in")
                        .font(NoopHTMLFont.outfit(23))
                        .tracking(-0.46)
                        .foregroundStyle(NoopHTMLColor.ink)
                        .padding(.horizontal, 2)

                    dropTarget
                        .padding(.top, 16)

                    section("Stored on this phone") {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline, spacing: 7) {
                                figure("1,284", "days")
                                figure("1,190", "sleeps")
                                Spacer(minLength: 0)
                            }
                            Text("14 Feb 2023 — today")
                                .font(NoopHTMLFont.sans(11.5))
                                .foregroundStyle(NoopHTMLColor.faint)
                        }
                        .padding(.vertical, 15)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 22).fill(NoopHTMLColor.card))
                        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
                    }
                    .padding(.top, 18)

                    section(
                        "What it can read",
                        note: "A renamed or re-zipped export still routes correctly — it is read by content, not by filename."
                    ) {
                        Button { navigation.show(.importCatalog) } label: {
                            rowsCard([
                                RowModel(title: "Wearable exports",
                                         note: "WHOOP, Apple Health, Oura, Fitbit, Garmin, Mi Band",
                                         trailing: .chevron, padding: 13),
                                RowModel(title: "Single files",
                                         note: "Workouts, nutrition, lab markers, lifting",
                                         trailing: .chevron, padding: 13)
                            ])
                        }
                        .buttonStyle(NoopHTMLPressStyle())
                    }
                    .padding(.top, 18)

                    Text("Your scores stay yours. Noop recomputes Rest, Charge and Effort from the raw heart rate, variability and sleep it finds. A brand’s own score is kept for reference and never shown as one of yours — so your numbers here will not match your old app’s.")
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(Self.dim)
                        .lineSpacing(3.5)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 16)
                }
            }
        }
    }

    /// One drop target, drawn in the screen's own hue so it reads as the way in rather than as
    /// another card. Radius 28 and a full-weight border are the handoff's — this is the only
    /// panel on the surface that is not the standard 22/0.5 card.
    private var dropTarget: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(Self.blush.opacity(0.13))
                    .overlay(Circle().strokeBorder(Self.blush.opacity(0.3), lineWidth: 0.5))
                NoopCanonicalGlyph(name: .download, size: 21, color: Self.blush)
            }
            .frame(width: 47, height: 47)

            Text("Hand it one file")
                .font(NoopHTMLFont.outfit(19))
                .tracking(-0.38)
                .foregroundStyle(NoopHTMLColor.ink)
                .padding(.top, 12)

            Text("A zip, a folder, or a single file. Noop reads it and works out what it is — you don’t pick a brand.")
                .font(NoopHTMLFont.sans(12.5))
                .foregroundStyle(NoopHTMLColor.copy)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 5)

            Button {
                navigation.importStartedAt = Date()
                navigation.replace(with: .reading)
            } label: {
                Text("Choose a file or folder")
                    .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                    .foregroundStyle(Self.blushInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Self.blush.opacity(0.92), in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(NoopHTMLPressStyle())
            .padding(.top, 14)

            Text("Sharing to Noop from Files or Mail works too")
                .font(NoopHTMLFont.sans(11))
                .foregroundStyle(NoopHTMLColor.faint)
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .background(RoundedRectangle(cornerRadius: 28).fill(Self.blush.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(Self.blush.opacity(0.34), lineWidth: 1))
    }

    private func figure(_ value: String, _ unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(value)
                .font(NoopHTMLFont.outfit200(26))
                .tracking(-0.78)
                .monospacedDigit()
                .foregroundStyle(NoopHTMLColor.ink)
            Text(unit)
                .font(NoopHTMLFont.sans(12.5))
                .foregroundStyle(NoopHTMLColor.copy)
        }
    }

    // MARK: 5 · The door out

    private var backupContents: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 0) {
                        NoopSectionLabel("Last snapshot", color: Self.dim)
                        Text("2 days ago")
                            .font(NoopHTMLFont.outfit(21, weight: .light))
                            .tracking(-0.42)
                            .foregroundStyle(NoopHTMLColor.ink)
                            .padding(.top, 4)
                        Text("iCloud Drive · 214 MB")
                            .font(NoopHTMLFont.sans(11.5))
                            .foregroundStyle(NoopHTMLColor.faint)
                            .padding(.top, 5)
                    }
                    Spacer(minLength: 0)
                    // Blush, not amber: the schedule is being kept. Amber here is reserved for a
                    // snapshot that has actually been missed.
                    schedulePill
                }

                Divider().overlay(NoopHTMLColor.border).padding(.top, 12)

                HStack(spacing: 8) {
                    NoopCanonicalGlyph(name: .clock, size: 13, color: NoopHTMLColor.faint)
                    Text("Next on Sunday, keeping the last 8")
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(Self.dim)
                }
                .padding(.top, 10)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 17)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 24).fill(NoopHTMLColor.card))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))

            section("Take one now", noteView: AnyView(approximateNote)) {
                rowsCard([
                    RowModel(title: "Everything, exactly · .noopbak",
                             note: "The whole database, your settings, and which build wrote it. The phone-to-phone path.",
                             noteColor: Self.dim, noteSize: 11.5,
                             trailing: .glyph(.download, Self.blush.opacity(0.8), 17), padding: 14),
                    RowModel(title: "A readable copy · WHOOP CSV",
                             note: "Four CSVs in a zip. Reads back into Noop, and into the Android build.",
                             noteColor: Self.dim, noteSize: 11.5,
                             trailing: .glyph(.download, Self.blush.opacity(0.8), 17), padding: 14)
                ])
            }

            section(
                "On a new phone",
                note: "There is no account and no server, so this file is the only way your history reaches another phone. That is the whole reason this screen ships with Act 5.",
                noteColor: Self.dim
            ) {
                Button { navigation.enter(.importHistory, from: .data) } label: {
                    rowsCard([
                        RowModel(title: "Restore from a .noopbak",
                                 note: "Replaces everything on this phone. It will tell you which build wrote the file first.",
                                 noteColor: Self.dim, noteSize: 11.5,
                                 trailing: .chevron, padding: 14)
                    ])
                }
                .buttonStyle(NoopHTMLPressStyle())
            }

        }
    }

    private var backupScreen: some View {
        NoopScreen(topInset: 56, horizontalInset: 18) {
            VStack(alignment: .leading, spacing: 0) {
                NoopBackHeader(label: "Your data") { navigation.back(or: .data) }
                Text("Backup and sync")
                    .font(NoopHTMLFont.outfit(23))
                    .tracking(-0.46)
                    .foregroundStyle(NoopHTMLColor.ink)
                    .padding(.horizontal, 2)
                backupContents
                    .padding(.top, 18)
            }
        }
    }

    private var schedulePill: some View {
        HStack(spacing: 6) {
            Circle().fill(Self.blush.opacity(0.75)).frame(width: 5, height: 5)
            Text("Weekly")
                .font(NoopHTMLFont.sans(10.5, weight: .semibold))
                .tracking(0.63)
                .foregroundStyle(Self.blushLight)
        }
        .padding(.horizontal, 9)
        .frame(height: 24)
        .background(RoundedRectangle(cornerRadius: 10).fill(Self.blush.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Self.blush.opacity(0.3), lineWidth: 0.5))
    }

    /// The tag is named in the app's own voice, so it is set apart from the sentence around it.
    private var approximateNote: some View {
        (
            Text("In the CSV, anything Noop worked out itself is tagged ")
            + Text("noop (APPROXIMATE)").font(NoopHTMLFont.sans(11)).foregroundColor(Self.dim)
            + Text(" and skipped on the way back in, and Apple Health rows are left out entirely so they cannot be mis-attributed to a strap.")
        )
        .font(NoopHTMLFont.sans(11.5))
        .foregroundStyle(NoopHTMLColor.faint)
        .lineSpacing(3.5)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: The other half of the screen's name
    //
    // The doors are new; these are not. They sit below the way out because a person comes here to
    // move their history far more often than to read what the strap records.

    private var dataHome: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 13) {
                NoopBackHeader(label: "You") { navigation.back(or: .you) }
                    .padding(.horizontal, -2)
                    .padding(.bottom, -10)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Data and permissions")
                        .font(NoopHTMLFont.outfit(25))
                        .tracking(-0.625)
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text("What is collected, where it sits, and how to take it with you.")
                        .font(NoopHTMLFont.sans(13.5))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .lineSpacing(4)
                }

                NoopHTMLCard(radius: 22, padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        NoopSectionLabel("What the strap records")
                        VStack(alignment: .leading, spacing: 10) {
                            dataFact("Pulse, and the gap between beats", "Continuously while worn. This is where sleep stages, stress and recovery all come from.")
                            dataFact("Movement", "To tell sleep from lying still, and to auto-pause a session.")
                            dataFact("Skin temperature and blood oxygen", "Overnight, as deviations from your own normal rather than absolute figures.")
                            dataFact("What you log", "Coffee, drinks, meals, naps, intimacy. Only what you tap.")
                        }
                    }
                }

                NoopHTMLCard(radius: 22, padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        NoopSectionLabel("Where it lives")
                        VStack(alignment: .leading, spacing: 11) {
                            dataPlace("On your phone", "Everything raw: every beat, every night, the whole 221. It never has to leave to be useful.", glyph: .watch)
                            dataPlace("On Noop’s servers", "Nothing. There is no account and no server — a restore comes from your own backup file.", glyph: .cloud)
                        }
                    }
                }

                VStack(spacing: 0) {
                    dataConnection("Apple Health", "writes sleep, workouts and vitals")
                    Rectangle().fill(NoopHTMLColor.border).frame(height: 0.5)
                    dataConnection("Strava", "would write sessions only")
                    Rectangle().fill(NoopHTMLColor.border).frame(height: 0.5)
                    dataConnection("Google Fit", "not connected")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))

                VStack(spacing: 8) {
                    VStack(spacing: 0) {
                        dataRoute("Bring your history in", "One file, any brand — Noop works out what it is", glyph: .download) {
                            navigation.enter(.importHistory, from: .data)
                        }
                        Rectangle().fill(NoopHTMLColor.border).frame(height: 0.5)
                        dataRoute("Backup and sync", "Last snapshot 2 days ago · iCloud Drive", glyph: .upload) {
                            navigation.enter(.backup, from: .data)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))

                    Button { navigation.show(.destructiveConfirmation("your account and data")) } label: {
                        HStack(spacing: 9) {
                            NoopCanonicalGlyph(name: .trash, size: 19, color: Color(hex: 0xF3A472))
                            Text("Delete my account and data")
                                .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                        }
                        .foregroundStyle(Color(hex: 0xF3A472))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(NoopHTMLColor.amber.opacity(0.1), in: RoundedRectangle(cornerRadius: 17))
                        .overlay(RoundedRectangle(cornerRadius: 17).strokeBorder(NoopHTMLColor.amber.opacity(0.3), lineWidth: 0.5))
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                }

                Text("Nothing here is sold, and there is no advertising identifier in the app. Deleting takes effect immediately and the export is a plain file you can read yourself.")
                    .font(NoopHTMLFont.sans(11.5))
                    .foregroundStyle(NoopHTMLColor.faint)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2)
            }
        }
    }

    private func dataFact(_ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Circle().fill(NoopHTMLColor.blue).frame(width: 7, height: 7).padding(.top, 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.ink)
                Text(detail).font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color(hex: 0x7F8A85)).lineSpacing(3)
            }
        }
    }

    private func dataPlace(_ title: String, _ detail: String, glyph: NoopCanonicalGlyphName) -> some View {
        HStack(alignment: .top, spacing: 12) {
            NoopCanonicalGlyph(name: glyph, size: 19, color: Self.blush).frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.ink)
                Text(detail).font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color(hex: 0x7F8A85)).lineSpacing(3)
            }
        }
    }

    private func dataConnection(_ title: String, _ detail: String) -> some View {
        HStack(spacing: 13) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(NoopHTMLFont.sans(13.5)).foregroundStyle(NoopHTMLColor.ink)
                Text(detail).font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color(hex: 0x7F8A85))
            }
            Spacer(minLength: 8)
            NoopA5TintToggle(isOn: connectedServices.contains(title), tint: Self.blush) {
                if connectedServices.contains(title) { connectedServices.remove(title) }
                else { connectedServices.insert(title) }
            }
        }
        .frame(minHeight: 62)
    }

    private func dataRoute(_ title: String, _ detail: String, glyph: NoopCanonicalGlyphName, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                NoopCanonicalGlyph(name: glyph, size: 19, color: Self.blush).frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(NoopHTMLFont.sans(13.5)).foregroundStyle(NoopHTMLColor.ink)
                    Text(detail).font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color(hex: 0x7F8A85))
                }
                Spacer(minLength: 8)
                NoopChevron()
            }
            .padding(.vertical, 14)
        }
        .buttonStyle(NoopHTMLPressStyle())
    }

    // MARK: 2 · Reading

    private var reading: some View {
        NoopScreen(topInset: 56, horizontalInset: 18) {
            VStack(alignment: .leading, spacing: 18) {
                NoopScreenHeader("Apple Health", eyebrow: "Reading")
                    .padding(.bottom, -18)

                VStack(alignment: .leading, spacing: 13) {
                    // The figure and the bar are one number, read twice.
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                        let fraction = Self.readFraction(from: navigation.importStartedAt, at: timeline.date)
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(Int(fraction * 100))")
                                .font(NoopHTMLFont.outfit200(44))
                                .tracking(-1.76)
                                .monospacedDigit()
                                .foregroundStyle(NoopHTMLColor.ink)
                            Text("%")
                                .font(NoopHTMLFont.sans(15))
                                .foregroundStyle(NoopHTMLColor.copy)
                            Spacer(minLength: 8)
                            Text("export.xml · 2.4 GB")
                                .font(NoopHTMLFont.sans(11.5))
                                .foregroundStyle(NoopHTMLColor.faint)
                        }
                    }
                    .frame(height: 44)

                    readingBar

                    Text("Streaming it a piece at a time and aggregating as it goes, so a file this size never has to fit in memory.")
                        .font(NoopHTMLFont.sans(12.5))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .lineSpacing(3.5)
                        .fixedSize(horizontal: false, vertical: true)
                }

                section("Found so far") {
                    rowsCard([
                        RowModel(title: "Sleeps", trailing: .value("1,904", NoopHTMLColor.ink), padding: 12),
                        RowModel(title: "Resting heart rate", trailing: .value("2,210 days", NoopHTMLColor.ink), padding: 12),
                        RowModel(title: "Variability", trailing: .value("1,860 nights", NoopHTMLColor.ink), padding: 12),
                        RowModel(title: "Workouts", trailing: .value("just started", NoopHTMLColor.faint), padding: 12)
                    ])
                }

                VStack(alignment: .leading, spacing: 10) {
                    Button { navigation.replace(with: .importHistory) } label: {
                        Text("Stop")
                            .font(NoopHTMLFont.sans(13.5, weight: .medium))
                            .foregroundStyle(NoopHTMLColor.inkSoft)
                            .frame(maxWidth: .infinity)
                            .frame(height: 47)
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5))
                    }
                    .buttonStyle(NoopHTMLPressStyle())

                    Text("Stopping keeps what has been written already. Nothing here leaves the phone — there is no server to send it to.")
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .lineSpacing(3.5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var readingBar: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let fraction = Self.readFraction(from: navigation.importStartedAt, at: timeline.date)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06))
                    RoundedRectangle(cornerRadius: 6).fill(Self.blush).frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: 12)
        }
    }

    /// A read walks from the handoff's 41% toward done; the figure and the bar both read it.
    private static func readFraction(from started: Date?, at now: Date) -> Double {
        guard let started else { return 0.41 }
        return min(0.92, 0.41 + now.timeIntervalSince(started) / 60)
    }

    // MARK: 3 · What was written

    private var imported: some View {
        NoopScreen(topInset: 56, horizontalInset: 18) {
            VStack(alignment: .leading, spacing: 18) {
                NoopScreenHeader("Seven years, in", eyebrow: "Imported · WHOOP 5.0 export")
                    .padding(.bottom, -18)

                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("2,547")
                                .font(NoopHTMLFont.outfit200(44))
                                .tracking(-1.76)
                                .monospacedDigit()
                                .foregroundStyle(NoopHTMLColor.ink)
                            Text("days")
                                .font(NoopHTMLFont.sans(14))
                                .foregroundStyle(NoopHTMLColor.copy)
                        }
                        Text("12 Feb 2019 — 28 Aug 2026")
                            .font(NoopHTMLFont.sans(12))
                            .foregroundStyle(Self.dim)
                    }
                    Spacer(minLength: 8)
                    ZStack {
                        Circle().fill(Self.blush.opacity(0.13))
                            .overlay(Circle().strokeBorder(Self.blush.opacity(0.3), lineWidth: 0.5))
                        NoopCanonicalGlyph(name: .check, size: 16, color: Self.blush)
                    }
                    .frame(width: 35, height: 35)
                    .padding(.top, 10)
                }

                section(
                    "By category",
                    note: "Only what the export carried was written. What it did not carry stays blank rather than becoming a zero — a missing night and a bad night should never look alike."
                ) {
                    rowsCard([
                        RowModel(title: "Sleeps", note: "with stages",
                                 trailing: .value("2,491", NoopHTMLColor.ink), padding: 12),
                        RowModel(title: "Cycles", note: "day boundaries and strain",
                                 trailing: .value("2,540", NoopHTMLColor.ink), padding: 12),
                        RowModel(title: "Workouts",
                                 trailing: .value("1,208", NoopHTMLColor.ink), padding: 12),
                        RowModel(title: "Resting heart rate",
                                 trailing: .value("2,547 days", NoopHTMLColor.ink), padding: 12),
                        RowModel(title: "Variability",
                                 trailing: .value("2,533 nights", NoopHTMLColor.ink), padding: 12),
                        // Unknown stays nil, not zero: the title dims and the value is a dash.
                        RowModel(title: "Skin temperature", titleColor: Self.dim, note: "not in a 5.0 export",
                                 trailing: .value("—", NoopHTMLColor.faint), padding: 12),
                        RowModel(title: "Blood oxygen", titleColor: Self.dim, note: "not in a 5.0 export",
                                 trailing: .value("—", NoopHTMLColor.faint), padding: 12)
                    ])
                }

                VStack(alignment: .leading, spacing: 10) {
                    Button { navigation.reset(to: .data) } label: {
                        Text("Done")
                            .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                            .foregroundStyle(Self.blushInk)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(Self.blush.opacity(0.92), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(NoopHTMLPressStyle())

                    Button { navigation.replace(with: .importHistory) } label: {
                        Text("Import something else")
                            .font(NoopHTMLFont.sans(13.5, weight: .medium))
                            .foregroundStyle(NoopHTMLColor.inkSoft)
                            .frame(maxWidth: .infinity)
                            .frame(height: 47)
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5))
                    }
                    .buttonStyle(NoopHTMLPressStyle())

                    (
                        Text("Rest and Charge are being recomputed from what came in. Your first fourteen days will carry a ")
                        + Text("building").font(NoopHTMLFont.serif(14, italic: true))
                        + Text(" chip while the baselines catch up.")
                    )
                    .font(NoopHTMLFont.sans(11.5))
                    .foregroundStyle(Self.dim)
                    .lineSpacing(3.5)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: 4 · The wrong file — the one screen that earns amber

    private var rejected: some View {
        NoopScreen(topInset: 56, horizontalInset: 18) {
            VStack(alignment: .leading, spacing: 18) {
                NoopScreenHeader("This one is the raw log", eyebrow: "Nothing was written")
                    .padding(.bottom, -18)

                // Amber is spent here and nowhere else on this surface: the file wants something
                // from the reader. The action below it stays blush, because it is not the alarm.
                VStack(alignment: .leading, spacing: 11) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle().fill(NoopHTMLColor.warm.opacity(0.14))
                            NoopCanonicalGlyph(name: .file, size: 16, color: NoopHTMLColor.warm)
                        }
                        .frame(width: 30, height: 30)
                        Text("Oura/heartrate.csv")
                            .font(NoopHTMLFont.sans(12.5))
                            .foregroundStyle(NoopHTMLColor.warm)
                    }
                    Text("That is Oura’s raw heart-rate log — one row per reading, with no daily summary Noop can attach to a date. There is nothing wrong with the file; it is the wrong one of the set.")
                        .font(NoopHTMLFont.sans(13))
                        .foregroundStyle(NoopHTMLColor.inkSoft)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 17)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 24).fill(NoopHTMLColor.warm.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(NoopHTMLColor.warm.opacity(0.26), lineWidth: 0.5))

                section(
                    "Two ways out",
                    note: "The JSON is the better of the two: one file, every category, and Noop can tell it from Fitbit’s and Garmin’s by its keys."
                ) {
                    rowsCard([
                        RowModel(title: "Export as JSON instead",
                                 note: "Oura app → Account → Export Data. One file, every category.",
                                 noteColor: Self.dim, noteSize: 11.5, trailing: .chevron, padding: 14),
                        RowModel(title: "Or hand it the daily CSVs",
                                 note: "sleep, readiness or activity — the summaries, not the logs.",
                                 noteColor: Self.dim, noteSize: 11.5, trailing: .chevron, padding: 14)
                    ])
                }

                VStack(alignment: .leading, spacing: 10) {
                    Button { navigation.replace(with: .importHistory) } label: {
                        Text("Choose another file")
                            .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                            .foregroundStyle(Self.blushInk)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(Self.blush.opacity(0.92), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(NoopHTMLPressStyle())

                    Text("Your 1,284 stored days are untouched. A rejected file changes nothing — it is read, judged and dropped.")
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(Self.dim)
                        .lineSpacing(3.5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: The surface's vocabulary
    //
    // A section is a 10/600 label ABOVE its card and an optional note BELOW it — never inside.

    private func section<Content: View>(
        _ title: String,
        note: String? = nil,
        noteColor: Color = NoopHTMLColor.faint,
        noteView: AnyView? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            NoopSectionLabel(title, color: Self.dim)
            content()
            if let noteView {
                noteView
            } else if let note {
                Text(note)
                    .font(NoopHTMLFont.sans(11.5))
                    .foregroundStyle(noteColor)
                    .lineSpacing(3.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, -1)
            }
        }
    }

    private enum RowTrailing {
        case none
        case chevron
        case value(String, Color)
        case glyph(NoopCanonicalGlyphName, Color, CGFloat)
    }

    private struct RowModel {
        var title: String
        var titleColor: Color = NoopHTMLColor.inkSoft
        var note: String = ""
        var noteColor: Color = NoopHTMLColor.faint
        var noteSize: CGFloat = 11
        var leading: NoopCanonicalGlyphName? = nil
        var trailing: RowTrailing = .none
        var padding: CGFloat = 12
    }

    /// The handoff's list card: padded 4/16, one hairline between rows and none after the last.
    private func rowsCard(_ rows: [RowModel]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                listRow(row)
                if index < rows.count - 1 {
                    Rectangle()
                        .fill(NoopHTMLColor.border)
                        .frame(height: 0.5)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22).fill(NoopHTMLColor.card))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
    }

    @ViewBuilder
    private func listRow(_ row: RowModel) -> some View {
        HStack(alignment: row.note.isEmpty ? .firstTextBaseline : .center, spacing: 11) {
            if let leading = row.leading {
                NoopCanonicalGlyph(name: leading, size: 18, color: Self.blush)
                    .frame(width: 20)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .font(NoopHTMLFont.sans(13))
                    .foregroundStyle(row.titleColor)
                if !row.note.isEmpty {
                    Text(row.note)
                        .font(NoopHTMLFont.sans(row.noteSize))
                        .foregroundStyle(row.noteColor)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            switch row.trailing {
            case .none:
                EmptyView()
            case .chevron:
                NoopFixedChevron(direction: .right, color: NoopHTMLColor.faint)
            case let .value(text, color):
                Text(text)
                    .font(NoopHTMLFont.sans(12.5, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(color)
            case let .glyph(name, color, size):
                NoopCanonicalGlyph(name: name, size: size, color: color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, row.padding)
    }
}

// MARK: - The twelve, one tap down

struct NoopImportCatalogSheet: View {
    @ObservedObject var navigation: NoopNavigation

    private static let groups: [(String, [(String, String)])] = [
        ("Wearables · six", [
            ("WHOOP", ".zip or folder — the four CSVs; 4.0, 5.0 and MG. Biomarker export too."),
            ("Apple Health", "export.zip, export.xml or a folder. Streamed and aggregated on-device."),
            ("Oura", "Account → Export Data JSON, or the per-category daily CSVs."),
            ("Fitbit", "Google Takeout → Fitbit → JSON."),
            ("Garmin", "Connect → Export Your Data, the GDPR .zip."),
            ("Xiaomi / Mi Band", "The Mi Fitness sandbox folder, a .zip of it, or the bare user_id.db.")
        ]),
        ("Files · six", [
            ("A single workout", "GPX, TCX or FIT."),
            ("Nutrition", "Daily CSV from Cronometer or MacroFactor."),
            ("Lab markers", "CSV."),
            ("A lab report", "As text."),
            ("Lifting", "A strength-training log."),
            ("The strap", "Live over Bluetooth — the one that is not a file.")
        ])
    ]

    var body: some View {
        NoopBottomSheet(title: "What it can read", dismiss: navigation.dismissOverlay, showsDone: true) {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(Self.groups.enumerated()), id: \.offset) { _, group in
                    VStack(alignment: .leading, spacing: 11) {
                        NoopSectionLabel(group.0, color: Color(hex: 0x8B958F))
                        ForEach(Array(group.1.enumerated()), id: \.offset) { index, item in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.0)
                                    .font(NoopHTMLFont.sans(13))
                                    .foregroundStyle(NoopHTMLColor.inkSoft)
                                Text(item.1)
                                    .font(NoopHTMLFont.sans(11.5))
                                    .foregroundStyle(Color(hex: 0x8B958F))
                                    .lineSpacing(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            if index < group.1.count - 1 {
                                Divider().overlay(NoopHTMLColor.border)
                            }
                        }
                    }
                }
                Text("Oura, Fitbit and Garmin share one importer and are told apart by JSON key shape. That is why the screen shows a summary and this list sits behind a chevron: it is documentation, not a control.")
                    .font(NoopHTMLFont.sans(11.5))
                    .foregroundStyle(NoopHTMLColor.faint)
                    .lineSpacing(3.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 8)
            }
        }
    }
}
#endif
