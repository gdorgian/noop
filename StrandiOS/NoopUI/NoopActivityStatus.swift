import SwiftUI

// MARK: - Activity status
//
// What the wearer says about themselves right now: training as usual, unwell, injured or taking a
// break. It is set from Today's header and kept for as long as they choose, after which it returns to
// Active on its own. It is the wearer's word, stored on the phone; nothing is inferred.

enum NoopActivityStatus: String, CaseIterable, Identifiable {
    case active, sick, injured, onBreak

    var id: String { rawValue }

    var title: String {
        switch self {
        case .active: "Active"
        case .sick: "Sick"
        case .injured: "Injured"
        case .onBreak: "On a break"
        }
    }

    var detail: String {
        switch self {
        case .active: "Training and moving as usual"
        case .sick: "Unwell and resting it off"
        case .injured: "Letting an injury heal"
        case .onBreak: "Time away from training"
        }
    }

    var symbol: String {
        switch self {
        case .active: "figure.run"
        case .sick: "bed.double.fill"
        case .injured: "bandage.fill"
        case .onBreak: "beach.umbrella.fill"
        }
    }

    /// The tile's light and deep ends.
    var tint: (Color, Color) {
        switch self {
        case .active: (Color(hex: 0x52DDB0), Color(hex: 0x17876A))
        case .sick: (Color(hex: 0xFFD45C), Color(hex: 0xD99A14))
        case .injured: (Color(hex: 0xFF8A7A), Color(hex: 0xC83A3A))
        case .onBreak: (Color(hex: 0x7FA8FF), Color(hex: 0x3A5FD0))
        }
    }

    /// How long a status is kept before it returns to Active; nil keeps it until changed.
    enum Keep: Int, CaseIterable, Identifiable {
        case untilChanged = 0, day = 1, threeDays = 3, week = 7, twoWeeks = 14
        var id: Int { rawValue }
        var title: String {
            switch self {
            case .untilChanged: "Until changed"
            case .day: "1 day"
            case .threeDays: "3 days"
            case .week: "1 week"
            case .twoWeeks: "2 weeks"
            }
        }
    }

    static let statusKey = "noop.activityStatus"
    static let untilKey = "noop.activityStatusUntil"
}

/// The status as stored, already returned to Active once its time ran out.
struct NoopActivityStatusState {
    var status: NoopActivityStatus
    /// When it ends; nil until changed.
    var until: Date?

    static func load() -> NoopActivityStatusState {
        let d = UserDefaults.standard
        let status = NoopActivityStatus(rawValue: d.string(forKey: NoopActivityStatus.statusKey) ?? "") ?? .active
        let t = d.double(forKey: NoopActivityStatus.untilKey)
        let until = t > 0 ? Date(timeIntervalSince1970: t) : nil
        if let until, until < Date() { return .init(status: .active, until: nil) }
        return .init(status: status, until: until)
    }

    func save() {
        let d = UserDefaults.standard
        d.set(status.rawValue, forKey: NoopActivityStatus.statusKey)
        d.set(until?.timeIntervalSince1970 ?? 0, forKey: NoopActivityStatus.untilKey)
    }

    var untilText: String {
        guard let until else { return "Until changed" }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()),
                                                   to: Calendar.current.startOfDay(for: until)).day ?? 0
        if days <= 1 { return "Until tomorrow" }
        let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate("EEE MMM d")
        return "Until \(f.string(from: until))"
    }
}

/// The status's tile: a pill in its colour, lit from the top, with the symbol in white.
struct NoopActivityStatusTile: View {
    let status: NoopActivityStatus
    /// The pill's height; it is a little wider than tall.
    var side: CGFloat = 34

    var body: some View {
        Capsule()
            .fill(LinearGradient(colors: [status.tint.0, status.tint.1], startPoint: .top, endPoint: .bottom))
            .overlay {
                // A soft sheen on the upper half, and a fine light rim.
                Capsule().fill(LinearGradient(colors: [.white.opacity(0.28), .white.opacity(0)], startPoint: .top, endPoint: .center))
                    .padding(1.5)
                Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 0.75).blendMode(.plusLighter)
            }
            .overlay {
                Image(systemName: status.symbol).font(.system(size: side * 0.44, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.22), radius: 1, y: 1)
            }
            .frame(width: side * 1.42, height: side)
            .shadow(color: status.tint.1.opacity(0.45), radius: 7, y: 3)
    }
}

/// Today's header chip: the tile, the status and how long it holds, and a chevron.
struct NoopActivityStatusChip: View {
    let state: NoopActivityStatusState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                NoopActivityStatusTile(status: state.status, side: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text(state.status.title).font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text(state.untilText).font(NoopHTMLFont.sans(NoopType.caption))
                        .foregroundStyle(NoopHTMLColor.copy)
                }
                .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold))
                    .foregroundStyle(NoopHTMLColor.faint)
                    .padding(.trailing, 6)
            }
            .padding(5)
            .frame(height: 46)
            .background(Color.white.opacity(0.06), in: Capsule())
            .overlay(Capsule().strokeBorder(NoopHTMLColor.borderStrong, lineWidth: 0.5))
            .contentShape(Capsule())
        }
        .buttonStyle(NoopHTMLPressStyle())
        .accessibilityLabel("Activity status, \(state.status.title), \(state.untilText)")
    }
}

/// The sheet: four statuses, how long to keep the chosen one, and Update.
struct NoopActivityStatusSheet: View {
    @Binding var state: NoopActivityStatusState
    @Environment(\.dismiss) private var dismiss
    @State private var choice: NoopActivityStatus = .active
    @State private var keep: NoopActivityStatus.Keep = .untilChanged

    static let height: CGFloat = 520

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Text("Activity status").font(NoopHTMLFont.sans(NoopType.body, weight: .semibold))
                    .foregroundStyle(NoopHTMLColor.ink)
                HStack {
                    Button { dismiss() } label: {
                        NoopIconDiscShape(size: .small) { Image(systemName: "xmark").font(.system(size: 13, weight: .semibold)) }
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                    .accessibilityLabel("Close")
                    Spacer()
                }
            }
            .padding(.top, 22).padding(.bottom, 8)

            ForEach(NoopActivityStatus.allCases) { s in row(s) }

            HStack(spacing: 10) {
                Image(systemName: "timer").font(.system(size: 15, weight: .medium)).foregroundStyle(NoopHTMLColor.inkSoft)
                Text("Keep status").font(NoopHTMLFont.sans(NoopType.subhead, weight: .medium)).foregroundStyle(NoopHTMLColor.ink)
                Spacer()
                Menu {
                    Picker("Keep status", selection: $keep) {
                        ForEach(NoopActivityStatus.Keep.allCases) { Text($0.title).tag($0) }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(choice == .active ? "Until changed" : keep.title)
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .semibold))
                    }
                    .font(NoopHTMLFont.sans(NoopType.subhead)).foregroundStyle(NoopHTMLColor.copy)
                }
                .disabled(choice == .active)
            }
            .padding(.horizontal, 16).frame(height: 50)
            .overlay(Capsule().strokeBorder(NoopHTMLColor.borderStrong, lineWidth: 0.5))
            .opacity(choice == .active ? 0.55 : 1)

            Spacer(minLength: 0)

            NoopActionButton(title: "Update") {
                var next = NoopActivityStatusState(status: choice, until: nil)
                if choice != .active, keep != .untilChanged {
                    next.until = Calendar.current.date(byAdding: .day, value: keep.rawValue, to: Date())
                }
                next.save()
                state = next
                NoopHaptics.play(.save)
                dismiss()
            }
            .padding(.bottom, 28)
        }
        .padding(.horizontal, 20)
        .onAppear {
            choice = state.status
            if let until = state.until {
                let days = Int((until.timeIntervalSinceNow / 86_400).rounded(.up))
                keep = NoopActivityStatus.Keep.allCases.last { $0.rawValue <= max(1, days) && $0 != .untilChanged } ?? .day
            }
        }
    }

    private func row(_ s: NoopActivityStatus) -> some View {
        let on = s == choice
        return Button {
            NoopHaptics.play(.tick)
            withAnimation(.snappy(duration: 0.2)) { choice = s }
        } label: {
            HStack(spacing: 14) {
                NoopActivityStatusTile(status: s, side: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.title).font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                    Text(s.detail).font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
                }
                Spacer(minLength: 4)
                ZStack {
                    Circle().strokeBorder(on ? NoopHTMLColor.ink : NoopHTMLColor.faint, lineWidth: 1.5)
                    if on { Circle().fill(NoopHTMLColor.ink).padding(5) }
                }
                .frame(width: 22, height: 22)
            }
            .padding(.horizontal, 12).frame(height: 66)
            .background(Color.white.opacity(on ? 0.09 : 0.045), in: RoundedRectangle(cornerRadius: 33, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 33, style: .continuous)
                .strokeBorder(Color.white.opacity(on ? 0.16 : 0.06), lineWidth: 0.75))
        }
        .buttonStyle(NoopHTMLPressStyle())
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
