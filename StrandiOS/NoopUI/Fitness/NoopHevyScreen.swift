#if os(iOS)
import SwiftUI
import StrandImport

/// Hevy, connected: one sheet to link the account, see where the sync stands, choose what crosses, copy
/// routines into Programs and let go again. The engine is `HevySync`.
struct NoopHevyScreen: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var hevy = HevySync.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var keyDraft = ""
    @State private var connected = HevySync.shared.hasKey
    @State private var picked: Set<String> = []
    @State private var confirmingDisconnect = false
    @State private var finishedPulse = 0
    @FocusState private var keyFocused: Bool

    private let accent = NoopHTMLColor.volt

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NoopSpace.l) {
                NoopSheetHeader(title: "Hevy") { dismiss() }
                hero
                if connected { connectedBody } else { connectBody }
            }
            .padding(.horizontal, NoopSpace.l)
            .padding(.bottom, NoopSpace.xxl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(NoopHTMLColor.canvas.ignoresSafeArea())
        .environment(\.noopAccent, .volt)
        .sensoryFeedback(.success, trigger: finishedPulse)
        .onChange(of: hevy.phase) { _, phase in if case .done = phase { finishedPulse += 1 } }
        .confirmationDialog("Disconnect Hevy?", isPresented: $confirmingDisconnect, titleVisibility: .visible) {
            Button("Keep the sessions already here") { disconnect(remove: false) }
            Button("Remove them too", role: .destructive) { disconnect(remove: true) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Noop forgets the key. Nothing in Hevy changes.")
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: NoopSpace.m) {
            HStack(spacing: 0) {
                disc(symbol: "dumbbell.fill", label: "Hevy")
                NoopHevyLink(active: hevy.isBusy, joined: connected, color: accent)
                    .frame(height: 20)
                disc(symbol: "waveform.path.ecg", label: "Noop")
            }
            VStack(spacing: 6) {
                Text(connected ? "Hevy and Noop, in step" : "Bring Hevy into Noop")
                    .font(NoopHTMLFont.outfit(NoopType.title2))
                    .tracking(-0.6)
                    .foregroundStyle(NoopHTMLColor.ink)
                    .multilineTextAlignment(.center)
                Text(connected
                     ? "Workouts logged in Hevy arrive here with every set, and count toward your records, muscles and volume."
                     : "Every workout with every set, your routines and your body measurements. Noop stays the record.")
                    .font(NoopHTMLFont.sans(NoopType.footnote))
                    .foregroundStyle(NoopHTMLColor.copy)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, NoopSpace.xs)
    }

    private func disc(symbol: String, label: String) -> some View {
        VStack(spacing: NoopSpace.xs) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(connected ? accent : NoopHTMLColor.inkSoft)
                .frame(width: 72, height: 72)
                .background(Color.white.opacity(0.06), in: Circle())
                .overlay(Circle().strokeBorder(connected ? accent.opacity(0.35) : NoopHTMLColor.borderStrong, lineWidth: 0.5))
                .animation(NoopMotion.swap, value: connected)
            Text(label)
                .font(NoopHTMLFont.sans(NoopType.caption, weight: .medium))
                .foregroundStyle(NoopHTMLColor.copy)
        }
    }

    // MARK: - Not connected

    private var connectBody: some View {
        VStack(alignment: .leading, spacing: NoopSpace.m) {
            VStack(alignment: .leading, spacing: NoopSpace.s) {
                bullet("figure.strengthtraining.traditional", "Every workout, set by set",
                       "Under Noop's own exercise names where they match, so your history joins up.")
                bullet("list.bullet.rectangle", "Routines into Programs", "You choose which. Copies, never links.")
                bullet("scalemass", "Body measurements", "Weight, body fat and the tape, into Body.")
                bullet("arrow.left.arrow.right", "Edits follow", "Change or delete a workout in Hevy and Noop follows at the next sync.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(NoopSpace.m)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))

            VStack(alignment: .leading, spacing: NoopSpace.xs) {
                NoopSectionLabel("Your Hevy API key")
                HStack(spacing: NoopSpace.s) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(keyFocused ? accent : NoopHTMLColor.muted)
                    SecureField("Paste it here", text: $keyDraft)
                        .font(NoopHTMLFont.sans(NoopType.subhead))
                        .foregroundStyle(NoopHTMLColor.ink)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($keyFocused)
                        .submitLabel(.go)
                        .onSubmit(connect)
                }
                .padding(.horizontal, NoopSpace.m)
                .frame(height: 52)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: NoopRadius.control, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: NoopRadius.control, style: .continuous)
                    .strokeBorder(keyFocused ? accent.opacity(0.45) : NoopHTMLColor.border, lineWidth: 0.5))
                .animation(NoopMotion.swap, value: keyFocused)
                Button {
                    if let url = URL(string: "https://hevy.com/settings?developer") { openURL(url) }
                } label: {
                    Text("Make one in Hevy › Settings › Developer  ↗")
                        .font(NoopHTMLFont.sans(NoopType.caption))
                        .foregroundStyle(accent)
                }
                .buttonStyle(NoopPlainHitStyle())
            }

            status
            NoopActionButton(title: hevy.isBusy ? "Connecting…" : "Connect", systemImage: "link",
                             enabled: !keyDraft.trimmingCharacters(in: .whitespaces).isEmpty && !hevy.isBusy, action: connect)
            Text("The key stays in this phone's Keychain. Noop talks to Hevy only to sync, and never to anyone else.")
                .font(NoopHTMLFont.sans(NoopType.eyebrow))
                .foregroundStyle(NoopHTMLColor.faint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func bullet(_ symbol: String, _ title: String, _ line: String) -> some View {
        HStack(alignment: .top, spacing: NoopSpace.s) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                Text(line).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Connected

    private var connectedBody: some View {
        VStack(alignment: .leading, spacing: NoopSpace.m) {
            VStack(alignment: .leading, spacing: NoopSpace.s) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(hevy.account ?? "Hevy")
                            .font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                            .foregroundStyle(NoopHTMLColor.ink)
                        Text(syncedLine)
                            .font(NoopHTMLFont.sans(NoopType.caption))
                            .foregroundStyle(NoopHTMLColor.copy)
                            .contentTransition(.opacity)
                    }
                    Spacer()
                    Text("\(hevy.sessionCount)")
                        .font(NoopHTMLFont.outfit(NoopType.title2, weight: .light))
                        .foregroundStyle(NoopHTMLColor.ink)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(hevy.sessionCount)))
                        .animation(.snappy, value: hevy.sessionCount)
                }
                status
                NoopActionButton(title: hevy.isBusy ? "Syncing…" : "Sync now", systemImage: "arrow.triangle.2.circlepath",
                                 variant: .secondary, size: .medium, enabled: !hevy.isBusy) {
                    Task { await hevy.sync(repo: model.repo) }
                }
            }
            .padding(NoopSpace.m)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))

            VStack(spacing: 0) {
                NoopToggleRow(title: "Body measurements", subtitle: "Weight, body fat and the tape from Hevy, into Body.",
                              isOn: $hevy.bringBody)
                    .padding(.vertical, NoopSpace.xs)
                Divider().overlay(NoopHTMLColor.border)
                NoopToggleRow(title: "Send Noop sessions to Hevy",
                              subtitle: "Each lift you finish here, once, at the next sync. Hevy's copy never comes back as a second session.",
                              isOn: $hevy.sendSessions)
                    .padding(.vertical, NoopSpace.xs)
            }
            .padding(.horizontal, NoopSpace.m)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))

            routinesCard

            NoopActionButton(title: "Disconnect Hevy", variant: .destructive, size: .medium) { confirmingDisconnect = true }
                .padding(.top, NoopSpace.xs)
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private var syncedLine: String {
        guard let last = hevy.lastSync else { return "Not synced yet" }
        let ago = last.timeIntervalSinceNow > -60 ? "just now" : last.formatted(.relative(presentation: .named))
        return "Synced \(ago) · sessions from Hevy"
    }

    private var routinesCard: some View {
        VStack(alignment: .leading, spacing: NoopSpace.s) {
            NoopSectionHeader(title: "Routines", actionTitle: hevy.routines.isEmpty ? "Read them" : nil,
                              action: hevy.routines.isEmpty ? { Task { await hevy.loadRoutines() } } : nil) { EmptyView() }
            if hevy.routines.isEmpty {
                Text("Copy any of your Hevy routines into Programs, to start them here.")
                    .font(NoopHTMLFont.sans(NoopType.caption))
                    .foregroundStyle(NoopHTMLColor.copy)
            } else {
                VStack(spacing: 0) {
                    ForEach(hevy.routines, id: \.id) { r in
                        let on = picked.contains(r.id)
                        Button {
                            withAnimation(NoopMotion.swap) { if on { picked.remove(r.id) } else { picked.insert(r.id) } }
                        } label: {
                            HStack(spacing: NoopSpace.s) {
                                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(on ? accent : NoopHTMLColor.muted)
                                    .contentTransition(.symbolEffect(.replace))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(r.title).font(NoopHTMLFont.sans(NoopType.footnote, weight: .medium)).foregroundStyle(NoopHTMLColor.ink)
                                    Text(r.exercises.prefix(3).map { HevySync.noopName($0.title) }.joined(separator: ", ")
                                         + (r.exercises.count > 3 ? " and \(r.exercises.count - 3) more" : ""))
                                        .font(NoopHTMLFont.sans(NoopType.caption))
                                        .foregroundStyle(NoopHTMLColor.faint)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                            }
                            .frame(minHeight: 52)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(NoopPlainHitStyle())
                        .sensoryFeedback(.selection, trigger: on)
                        if r.id != hevy.routines.last?.id { Divider().overlay(NoopHTMLColor.border) }
                    }
                }
                NoopActionButton(title: picked.isEmpty ? "Choose routines" : picked.count == 1 ? "Add 1 to Programs" : "Add \(picked.count) to Programs",
                                 systemImage: "plus", size: .medium, enabled: !picked.isEmpty && !hevy.isBusy) {
                    Task {
                        _ = await hevy.importRoutines(picked, repo: model.repo)
                        withAnimation(NoopMotion.swap) { picked = [] }
                    }
                }
            }
        }
        .padding(NoopSpace.m)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
    }

    // MARK: - Status

    @ViewBuilder private var status: some View {
        switch hevy.phase {
        case .idle: EmptyView()
        case .working(let line):
            HStack(spacing: NoopSpace.xs) {
                ProgressView().controlSize(.small).tint(accent)
                Text(line).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                    .contentTransition(.opacity)
            }
            .animation(NoopMotion.swap, value: line)
        case .done(let line):
            Label(line, systemImage: "checkmark.circle.fill")
                .font(NoopHTMLFont.sans(NoopType.caption, weight: .medium))
                .foregroundStyle(accent)
                .transition(.opacity)
        case .failed(let line):
            Label(line, systemImage: "exclamationmark.triangle.fill")
                .font(NoopHTMLFont.sans(NoopType.caption))
                .foregroundStyle(NoopHTMLColor.red)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Actions

    private func connect() {
        keyFocused = false
        let key = keyDraft
        Task {
            if await hevy.connect(key: key, repo: model.repo) {
                keyDraft = ""
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { connected = true }
            }
        }
    }

    private func disconnect(remove: Bool) {
        Task {
            await hevy.disconnect(removeImported: remove, repo: model.repo)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { connected = false }
        }
    }
}

/// The line between the two discs: dashed and quiet when apart, solid when joined, with light running
/// along it while a sync is under way.
private struct NoopHevyLink: View {
    let active: Bool
    let joined: Bool
    let color: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !active)) { context in
            Canvas { ctx, size in
                let y = size.height / 2
                var line = Path()
                line.move(to: CGPoint(x: 6, y: y))
                line.addLine(to: CGPoint(x: size.width - 6, y: y))
                ctx.stroke(line, with: .color(joined ? color.opacity(0.45) : Color.white.opacity(0.18)),
                           style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: joined ? [] : [3, 5]))
                guard active else { return }
                let t = context.date.timeIntervalSinceReferenceDate
                for i in 0..<3 {
                    let phase = (t * 0.8 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                    let x = 6 + (size.width - 12) * (1 - phase)
                    let dot = Path(ellipseIn: CGRect(x: x - 3, y: y - 3, width: 6, height: 6))
                    ctx.fill(dot, with: .color(color.opacity(sin(phase * .pi))))
                }
            }
        }
    }
}
#endif
