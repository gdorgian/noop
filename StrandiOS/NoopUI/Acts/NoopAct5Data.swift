#if os(iOS)
import SwiftUI

// MARK: - plumbing/data · the two doors
//
// Import and backup are the same two formats read in opposite directions, so they share one screen.
// The way in is ONE drop target, not twelve rows: `detectAndImport` works out what it was handed by
// filename and JSON key shape, so the catalog of twelve is documentation and lives one tap down.
//
// Reading, what-was-written and the-wrong-file are states this screen becomes during an import, not
// destinations — they add no routes. Blush throughout, the hue the screen already carries; amber is
// spent only on the two cases that want something from the reader (a rejected file, a stale
// snapshot), which is the reserved meaning.

struct NoopDataScreen: View {
    @ObservedObject var navigation: NoopNavigation

    private static let blush = Color(hex: 0xE08A9B)
    private static let blushLight = Color(hex: 0xF6D3DA)
    private static let dim = Color(hex: 0x7F8A85)

    var body: some View {
        switch navigation.dataState {
        case .idle: doors
        case .reading: reading
        case .written: written
        case .rejected: rejected
        }
    }

    // MARK: 1 · The door in, and 5 · the door out

    private var doors: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 13) {
                header

                NoopHTMLCard(radius: 22, padding: 16) {
                    VStack(alignment: .leading, spacing: 11) {
                        Text("Hand it one file")
                            .font(NoopHTMLFont.sans(14.5, weight: .semibold))
                            .foregroundStyle(NoopHTMLColor.ink)
                        Text("A zip, a folder, or a single file. Noop reads it and works out what it is — you don’t pick a brand.")
                            .font(NoopHTMLFont.sans(12.5))
                            .foregroundStyle(NoopHTMLColor.copy)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                        Button { navigation.beginImport(at: Date()) } label: {
                            Text("Choose a file or folder")
                                .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                                .foregroundStyle(Color(hex: 0x2A0E14))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Self.blush, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(NoopHTMLPressStyle())
                        Text("Sharing to Noop from Files or Mail works too")
                            .font(NoopHTMLFont.sans(11))
                            .foregroundStyle(NoopHTMLColor.faint)
                            .frame(maxWidth: .infinity)
                    }
                }

                storedOnThisPhone
                whatItCanRead

                Text("Your scores stay yours. Noop recomputes Rest, Charge and Effort from the raw heart rate, variability and sleep it finds. A brand’s own score is kept for reference and never shown as one of yours — so your numbers here will not match your old app’s.")
                    .font(NoopHTMLFont.sans(11.5))
                    .foregroundStyle(NoopHTMLColor.faint)
                    .lineSpacing(3.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2)

                doorOut
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 13) {
            act5BackHeader("You") { navigation.reset(to: .you) }
            VStack(alignment: .leading, spacing: 6) {
                NoopSectionLabel("Your data", color: Self.blush)
                Text("Bring your history in")
                    .font(NoopHTMLFont.outfit(25, weight: .regular))
                    .tracking(-0.6)
                    .foregroundStyle(NoopHTMLColor.ink)
            }
            .padding(.bottom, 2)
        }
    }

    private var storedOnThisPhone: some View {
        NoopHTMLCard(radius: 22, padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                NoopSectionLabel("Stored on this phone")
                HStack(spacing: 22) {
                    figure("1,284", "days")
                    figure("1,204", "sleeps")
                    Spacer(minLength: 0)
                }
                Text("14 Feb 2023 — today")
                    .font(NoopHTMLFont.sans(11))
                    .foregroundStyle(NoopHTMLColor.faint)
            }
        }
    }

    private func figure(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(NoopHTMLFont.outfit(23, weight: .light))
                .tracking(-0.7)
                .monospacedDigit()
                .foregroundStyle(NoopHTMLColor.ink)
            Text(label)
                .font(NoopHTMLFont.sans(11))
                .foregroundStyle(Self.dim)
        }
    }

    /// Two summary rows and a chevron. The twelve are behind it because they are documentation,
    /// not a control — nothing here asks the reader to identify their own export.
    private var whatItCanRead: some View {
        Button { navigation.show(.importCatalog) } label: {
            NoopHTMLCard(radius: 22, padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        NoopSectionLabel("What it can read")
                        Spacer()
                        NoopFixedChevron(direction: .right, color: NoopHTMLColor.faint)
                    }
                    keyValue("Wearable exports", "WHOOP, Apple Health, Oura, Fitbit, Garmin, Mi Band")
                    Divider().overlay(NoopHTMLColor.border)
                    keyValue("Single files", "Workouts, nutrition, lab markers, lifting")
                    Text("A renamed or re-zipped export still routes correctly — it is read by content, not by filename.")
                        .font(NoopHTMLFont.sans(11))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }
        }
        .buttonStyle(NoopHTMLPressStyle())
    }

    private func keyValue(_ key: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(key)
                .font(NoopHTMLFont.sans(13))
                .foregroundStyle(NoopHTMLColor.inkSoft)
            Text(value)
                .font(NoopHTMLFont.sans(11.5))
                .foregroundStyle(Self.dim)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 5 · The door out

    private var doorOut: some View {
        VStack(alignment: .leading, spacing: 13) {
            NoopSectionLabel("Backup and sync", color: Self.blush)
                .padding(.top, 8)

            NoopHTMLCard(radius: 22, padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Last snapshot")
                                .font(NoopHTMLFont.sans(13))
                                .foregroundStyle(NoopHTMLColor.inkSoft)
                            Text("iCloud Drive · 214 MB")
                                .font(NoopHTMLFont.sans(11.5))
                                .foregroundStyle(Self.dim)
                        }
                        Spacer(minLength: 8)
                        // Amber here only when a scheduled snapshot has been missed; two days is not.
                        NoopPill(text: "2 days ago", color: Self.blush)
                    }
                    Divider().overlay(NoopHTMLColor.border)
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Weekly")
                                .font(NoopHTMLFont.sans(13))
                                .foregroundStyle(NoopHTMLColor.inkSoft)
                            Text("Next on Sunday, keeping the last 8")
                                .font(NoopHTMLFont.sans(11.5))
                                .foregroundStyle(Self.dim)
                        }
                        Spacer(minLength: 0)
                    }
                    Button { } label: {
                        Text("Take one now")
                            .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                            .foregroundStyle(NoopHTMLColor.inkSoft)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.14), lineWidth: 0.5))
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                }
            }

            NoopHTMLCard(radius: 22, padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    keyValue("Everything, exactly · .noopbak", "The whole database, your settings, and which build wrote it. The phone-to-phone path.")
                    Divider().overlay(NoopHTMLColor.border)
                    keyValue("A readable copy · WHOOP CSV", "Four CSVs in a zip. Reads back into Noop, and into the Android build.")
                    Text("In the CSV, anything Noop worked out itself is tagged noop (APPROXIMATE) and skipped on the way back in, and Apple Health rows are left out entirely so they cannot be mis-attributed to a strap.")
                        .font(NoopHTMLFont.sans(11))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }

            NoopHTMLCard(radius: 22, padding: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    NoopSectionLabel("On a new phone")
                    Text("Restore from a .noopbak")
                        .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text("Replaces everything on this phone. It will tell you which build wrote the file first.")
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text("There is no account and no server, so this file is the only way your history reaches another phone. That is the whole reason this screen ships with Act 5.")
                .font(NoopHTMLFont.sans(11.5))
                .foregroundStyle(NoopHTMLColor.faint)
                .lineSpacing(3.5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 2)

            permissions
        }
    }

    // MARK: The other half of the screen's name
    //
    // The doors are new; these are not. They sit below the way out because a person comes here to
    // move their history far more often than to read what the strap records.

    private var permissions: some View {
        VStack(alignment: .leading, spacing: 13) {
            NoopSectionLabel("What is collected", color: Self.blush)
                .padding(.top, 8)

            NoopHTMLCard(radius: 22, padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    NoopSectionLabel("What the strap records")
                    bullet("Pulse, and the gap between beats", "Continuously while worn. This is where sleep stages, stress and recovery all come from.")
                    bullet("Movement", "To tell sleep from lying still, and to auto-pause a session.")
                    bullet("Skin temperature and blood oxygen", "Overnight, as deviations from your own normal rather than absolute figures.")
                    bullet("What you log", "Coffee, drinks, meals, naps, intimacy. Only what you tap.")
                }
                .padding(.vertical, 3)
            }

            NoopHTMLCard(radius: 22, padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    NoopSectionLabel("Where it lives")
                    place("On your phone", "Everything raw: every beat, every night, the whole 221. It never has to leave to be useful.", glyph: .watch)
                    place("On Noop’s servers", "Nothing. There is no account and no server — a restore comes from your own backup file.", glyph: .cloud)
                }
                .padding(.vertical, 3)
            }

            Button { navigation.show(.destructiveConfirmation("your account and data")) } label: {
                Label("Delete my account and data", systemImage: "trash")
                    .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xF3A472))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(NoopHTMLColor.amber.opacity(0.1), in: RoundedRectangle(cornerRadius: 17))
                    .overlay(RoundedRectangle(cornerRadius: 17).stroke(NoopHTMLColor.amber.opacity(0.3), lineWidth: 0.5))
            }
            .buttonStyle(NoopHTMLPressStyle())

            Text("Nothing here is sold, and there is no advertising identifier in the app. Deleting takes effect immediately.")
                .font(NoopHTMLFont.sans(11.5))
                .foregroundStyle(NoopHTMLColor.faint)
                .lineSpacing(3.5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 2)
        }
    }

    private func bullet(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(NoopHTMLFont.sans(13))
                .foregroundStyle(NoopHTMLColor.inkSoft)
            Text(detail)
                .font(NoopHTMLFont.sans(11.5))
                .foregroundStyle(Self.dim)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func place(_ title: String, _ detail: String, glyph: NoopCanonicalGlyphName) -> some View {
        HStack(alignment: .top, spacing: 12) {
            NoopCanonicalGlyph(name: glyph, size: 18, color: Self.blush)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(NoopHTMLFont.sans(13))
                    .foregroundStyle(NoopHTMLColor.inkSoft)
                Text(detail)
                    .font(NoopHTMLFont.sans(11.5))
                    .foregroundStyle(Self.dim)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 2 · Reading

    private var reading: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 13) {
                act5BackHeader("You") { navigation.dataState = .idle }
                VStack(alignment: .leading, spacing: 6) {
                    NoopSectionLabel("Reading", color: Self.blush)
                    Text("Apple Health")
                        .font(NoopHTMLFont.outfit(25, weight: .regular))
                        .tracking(-0.6)
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text("export.xml · 2.4 GB")
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(Self.dim)
                }
                .padding(.bottom, 2)

                NoopHTMLCard(radius: 22, padding: 16) {
                    VStack(alignment: .leading, spacing: 13) {
                        readingBar
                        Text("Streaming it a piece at a time and aggregating as it goes, so a file this size never has to fit in memory.")
                            .font(NoopHTMLFont.sans(12))
                            .foregroundStyle(NoopHTMLColor.copy)
                            .lineSpacing(3.5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                NoopHTMLCard(radius: 22, padding: 16) {
                    VStack(alignment: .leading, spacing: 11) {
                        NoopSectionLabel("Found so far")
                        countRow("Sleeps", "1,904", dimValue: false)
                        countRow("Resting heart rate", "2,210 days", dimValue: false)
                        countRow("Variability", "1,860 nights", dimValue: false)
                        countRow("Workouts", "just started", dimValue: true)
                    }
                }

                Button { navigation.dataState = .written } label: {
                    Text("Stop")
                        .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                        .foregroundStyle(NoopHTMLColor.inkSoft)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.14), lineWidth: 0.5))
                }
                .buttonStyle(NoopHTMLPressStyle())

                Text("Stopping keeps what has been written already. Nothing here leaves the phone — there is no server to send it to.")
                    .font(NoopHTMLFont.sans(11.5))
                    .foregroundStyle(NoopHTMLColor.faint)
                    .lineSpacing(3.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2)
            }
        }
    }

    private var readingBar: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let started = navigation.importStartedAt ?? timeline.date
            let elapsed = timeline.date.timeIntervalSince(started)
            let fraction = min(0.92, 0.08 + elapsed / 26)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07))
                    Capsule().fill(Self.blush).frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: 5)
        }
    }

    private func countRow(_ key: String, _ value: String, dimValue: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key)
                .font(NoopHTMLFont.sans(13))
                .foregroundStyle(NoopHTMLColor.inkSoft)
            Spacer(minLength: 8)
            Text(value)
                .font(NoopHTMLFont.sans(13))
                .monospacedDigit()
                .foregroundStyle(dimValue ? Self.dim : NoopHTMLColor.ink)
        }
    }

    // MARK: 3 · What was written

    private var written: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 13) {
                act5BackHeader("You") { navigation.dataState = .idle }
                VStack(alignment: .leading, spacing: 6) {
                    NoopSectionLabel("Imported · WHOOP 5.0 export", color: Self.blush)
                    Text("Seven years, in")
                        .font(NoopHTMLFont.outfit(25, weight: .regular))
                        .tracking(-0.6)
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text("12 Feb 2019 — 28 Aug 2026")
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(Self.dim)
                }
                .padding(.bottom, 2)

                NoopHTMLCard(radius: 22, padding: 16) {
                    VStack(alignment: .leading, spacing: 11) {
                        NoopSectionLabel("By category")
                        writtenRow("Sleeps", note: "with stages", value: "2,491", blank: false)
                        writtenRow("Cycles", note: "day boundaries and strain", value: "2,540", blank: false)
                        writtenRow("Workouts", note: "", value: "1,208", blank: false)
                        writtenRow("Resting heart rate", note: "", value: "2,547 days", blank: false)
                        writtenRow("Variability", note: "", value: "2,533 nights", blank: false)
                        writtenRow("Skin temperature", note: "not in a 5.0 export", value: "—", blank: true)
                        writtenRow("Blood oxygen", note: "not in a 5.0 export", value: "—", blank: true)
                    }
                }

                Text("Only what the export carried was written. What it did not carry stays blank rather than becoming a zero — a missing night and a bad night should never look alike.")
                    .font(NoopHTMLFont.sans(11.5))
                    .foregroundStyle(NoopHTMLColor.faint)
                    .lineSpacing(3.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2)

                VStack(spacing: 8) {
                    Button { navigation.dataState = .idle } label: {
                        Text("Done")
                            .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                            .foregroundStyle(Color(hex: 0x2A0E14))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Self.blush, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                    Button { navigation.dataState = .idle } label: {
                        Text("Import something else")
                            .font(NoopHTMLFont.sans(13))
                            .foregroundStyle(Self.dim)
                            .frame(height: 40)
                    }
                    .buttonStyle(.plain)
                }

                Text("Rest and Charge are being recomputed from what came in. Your first fourteen days will carry a building chip while the baselines catch up.")
                    .font(NoopHTMLFont.sans(11.5))
                    .foregroundStyle(NoopHTMLColor.faint)
                    .lineSpacing(3.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2)
            }
        }
    }

    private func writtenRow(_ key: String, note: String, value: String, blank: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(key)
                    .font(NoopHTMLFont.sans(13))
                    .foregroundStyle(blank ? Color(hex: 0x8B958F) : NoopHTMLColor.inkSoft)
                if !note.isEmpty {
                    Text(note)
                        .font(NoopHTMLFont.sans(11))
                        .foregroundStyle(blank ? Color(hex: 0x8B958F) : Self.dim)
                }
            }
            Spacer(minLength: 8)
            Text(value)
                .font(NoopHTMLFont.sans(13))
                .monospacedDigit()
                .foregroundStyle(blank ? Self.dim : NoopHTMLColor.ink)
        }
    }

    // MARK: 4 · The wrong file — the one screen that earns amber

    private var rejected: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 13) {
                act5BackHeader("You") { navigation.dataState = .idle }
                VStack(alignment: .leading, spacing: 6) {
                    NoopSectionLabel("Nothing was written", color: NoopHTMLColor.warm)
                    Text("This one is the raw log")
                        .font(NoopHTMLFont.outfit(25, weight: .regular))
                        .tracking(-0.6)
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text("Oura/heartrate.csv")
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(Color(hex: 0xF3C888))
                }
                .padding(.bottom, 2)

                VStack(alignment: .leading, spacing: 10) {
                    Text("That is Oura’s raw heart-rate log — one row per reading, with no daily summary Noop can attach to a date. There is nothing wrong with the file; it is the wrong one of the set.")
                        .font(NoopHTMLFont.sans(12.5))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(NoopHTMLColor.warm.opacity(0.10), in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.warm.opacity(0.30), lineWidth: 0.5))

                NoopHTMLCard(radius: 22, padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        NoopSectionLabel("Two ways out")
                        keyValue("Export as JSON instead", "Oura app → Account → Export Data. One file, every category.")
                        Divider().overlay(NoopHTMLColor.border)
                        keyValue("Or hand it the daily CSVs", "sleep, readiness or activity — the summaries, not the logs.")
                        Text("The JSON is the better of the two: one file, every category, and Noop can tell it from Fitbit’s and Garmin’s by its keys.")
                            .font(NoopHTMLFont.sans(11))
                            .foregroundStyle(NoopHTMLColor.faint)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                    }
                }

                Button { navigation.dataState = .idle } label: {
                    Text("Choose another file")
                        .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x1E1405))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(NoopHTMLColor.warm, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(NoopHTMLPressStyle())

                Text("Your 1,284 stored days are untouched. A rejected file changes nothing — it is read, judged and dropped.")
                    .font(NoopHTMLFont.sans(11.5))
                    .foregroundStyle(NoopHTMLColor.faint)
                    .lineSpacing(3.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2)
            }
        }
    }

    private func act5BackHeader(_ label: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Button(action: action) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.06))
                        .overlay(Circle().stroke(NoopHTMLColor.borderStrong, lineWidth: 0.5))
                    NoopFixedChevron(direction: .left, color: NoopHTMLColor.inkSoft).offset(x: -1)
                }
                .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            Text(label)
                .font(NoopHTMLFont.sans(13.5))
                .foregroundStyle(NoopHTMLColor.copy)
            Spacer()
        }
        .padding(.horizontal, -2)
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
                        NoopSectionLabel(group.0)
                        ForEach(Array(group.1.enumerated()), id: \.offset) { index, item in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.0)
                                    .font(NoopHTMLFont.sans(13))
                                    .foregroundStyle(NoopHTMLColor.inkSoft)
                                Text(item.1)
                                    .font(NoopHTMLFont.sans(11.5))
                                    .foregroundStyle(Color(hex: 0x7F8A85))
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
