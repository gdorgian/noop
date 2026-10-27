#if os(iOS)
import SwiftUI
import UIKit
import StrandAnalytics
import WhoopStore

// MARK: - Act 9 · The instrument

/// The Instrument is entered from Trends; it deliberately does not add a sixth tab. The fixture
/// below is the prototype's deterministic 258-night record and is visible only through the
/// Debug-only `--demo-seed` shell. Release data is supplied by the verified app shell instead.
enum NoopInstrumentLoadState { case waiting, loading, ready, empty, partial, unavailable }

struct NoopAct9Screens: View {
    @ObservedObject var navigation: NoopNavigation
    let data: NoopInstrumentData
    var loadState: NoopInstrumentLoadState = .ready
    var retry: (() -> Void)?
    var metricSheet = false
    @AppStorage("noop.schedule.kind") private var scheduleKind = "mostly-nights"
    @AppStorage(UnitPrefs.systemKey) private var bodyUnits = UnitSystem.metric.rawValue
    @AppStorage("noop.act9.range") private var rangeRaw = NoopInstrumentRange.thirty.rawValue
    @SceneStorage("noop.act9.end-day") private var endDayRaw = ""
    @EnvironmentObject private var repo: Repository
    @SceneStorage("noop.act9.filter") private var filterRaw = NoopInstrumentGroupFilter.all.rawValue

    init(navigation: NoopNavigation, data: NoopInstrumentData, loadState: NoopInstrumentLoadState = .ready, retry: (() -> Void)? = nil, metricSheet: Bool = false) {
        self.navigation = navigation
        self.data = data
        self.loadState = loadState
        self.retry = retry
        self.metricSheet = metricSheet
    }

    private var presentedData: NoopInstrumentData {
        let _ = bodyUnits
        return data.adjustedForSchedule(
            isNightWorker: NoopScheduleInference.isNightWorker(kind: scheduleKind)
        )
    }

    private var range: Binding<NoopInstrumentRange> {
        Binding(
            get: {
                if overviewWindow != nil { return .overview }
                let requested = NoopInstrumentRange(rawValue: rangeRaw).flatMap { $0 == .overview ? nil : $0 } ?? .ninety
                return requested.isAvailable(total: presentedData.historyCount) ? requested : .all
            },
            set: {
                if let overviewWindow { endDayRaw = Self.dayKey(overviewWindow.end) }
                navigation.instrumentOverviewWindow = nil
                rangeRaw = $0.rawValue
            }
        )
    }

    private var overviewWindow: NoopInstrumentOverviewWindow? {
        guard let context = navigation.instrumentOverviewWindow, context.deviceId == repo.deviceId else { return nil }
        return context
    }

    private static func dayKey(_ date: Date) -> String {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private var selectedEnd: Date? {
        if let overviewWindow { return overviewWindow.end }
        guard let first = presentedData.historyDates.compactMap({ $0 }).first,
              let last = presentedData.historyDates.compactMap({ $0 }).last else { return nil }
        let requested = HistoryDateWindow.date(dayKey: endDayRaw) ?? last
        return min(last, max(first, requested))
    }

    private var windowData: NoopInstrumentData {
        if let overviewWindow { return presentedData.between(start: overviewWindow.start, end: overviewWindow.end) }
        return selectedEnd.map { presentedData.ending(on: $0) } ?? presentedData
    }

    private var windowContext: NoopInstrumentWindowContext? {
        let dates = presentedData.historyDates.compactMap { $0 }
        guard let first = dates.first, let last = dates.last, let end = selectedEnd,
              let window = HistoryDateWindow(endingOn: end, dayCount: range.wrappedValue.requestedDayCount,
                                             firstDay: first, calendar: .current) else { return nil }
        return NoopInstrumentWindowContext(first: first, last: last, start: overviewWindow?.start ?? window.start, end: end,
                                            totalDays: presentedData.historyCount,
                                            step: overviewWindow.map { max(1, Calendar.current.dateComponents([.day], from: $0.start, to: $0.end).day.map { $0 + 1 } ?? 1) }
                                                ?? range.wrappedValue.requestedDayCount ?? max(1, dates.count)) { date in
            if let overviewWindow {
                let offset = Calendar.current.dateComponents([.day], from: overviewWindow.end, to: date).day ?? 0
                let start = Calendar.current.date(byAdding: .day, value: offset, to: overviewWindow.start) ?? date
                navigation.instrumentOverviewWindow = .init(start: start, end: date, metricKey: overviewWindow.metricKey,
                                                            weeklySummary: nil, deviceId: overviewWindow.deviceId)
            } else {
                endDayRaw = Calendar.current.isDate(date, inSameDayAs: last) ? "" : Self.dayKey(date)
            }
        }
    }

    var body: some View {
        Group {
            if data.historyCount == 0 && (loadState == .waiting || loadState == .loading || loadState == .unavailable) {
                NoopScreen(topInset: 56) {
                    VStack(alignment: .leading, spacing: 16) {
                        NoopInstrumentBackHeader(label: "Trends") { navigation.back(or: .trends) }
                        Text(loadState == .unavailable ? "History could not be loaded" : "Loading recorded history")
                            .font(NoopHTMLFont.outfit(25)).foregroundStyle(NoopHTMLColor.ink)
                        if loadState == .unavailable {
                            Text("Your saved history has not been changed. Try again to read it.")
                                .font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.copy)
                            Button("Try again") { retry?() }.frame(minHeight: 44).buttonStyle(NoopPlainHitStyle())
                        } else { ProgressView().tint(NoopHTMLColor.night) }
                    }
                }
            } else {
                screens
                    .safeAreaInset(edge: .top, spacing: 0) {
                        if loadState == .partial {
                            HStack(spacing: 12) {
                                Text("Some history could not be refreshed. Available readings are shown.")
                                    .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.warm)
                                    .fixedSize(horizontal: false, vertical: true)
                                Button("Try again") { retry?() }
                                    .font(NoopHTMLFont.sans(12, weight: .semibold))
                                    .frame(minWidth: 44, minHeight: 44).buttonStyle(NoopPlainHitStyle())
                            }
                            .padding(.horizontal, 12).frame(maxWidth: .infinity).background(NoopHTMLColor.card)
                        }
                    }
            }
        }
            .environment(\.noopInstrumentWindow, windowContext)
            .onChange(of: repo.deviceId) { _ in
                endDayRaw = ""
                navigation.instrumentOverviewWindow = nil
            }
    }

    @ViewBuilder private var screens: some View {
        switch metricSheet ? NoopRoute.instrumentMetric : navigation.route {
        case .instrumentIndex:
            NoopInstrumentIndexScreen(
                navigation: navigation,
                range: range,
                filterRaw: $filterRaw,
                data: windowData
            )
        case .instrumentMetric:
            NoopInstrumentMetricScreen(
                navigation: navigation,
                range: range,
                data: windowData, windowStart: windowContext?.start
            )
        case .instrumentCompare:
            NoopInstrumentCompareScreen(navigation: navigation, range: range, data: windowData)
        case .instrumentEffects:
            NoopInstrumentEffectsScreen(navigation: navigation, range: range, data: windowData)
        case .instrumentRaw, .instrumentCapture:
            NoopInstrumentRawScreen(navigation: navigation)
        default:
            NoopInstrumentIndexScreen(
                navigation: navigation,
                range: range,
                filterRaw: $filterRaw,
                data: windowData
            )
        }
    }
}

private struct NoopInstrumentIndexScreen: View {
    @ObservedObject var navigation: NoopNavigation
    @Binding var range: NoopInstrumentRange
    @Binding var filterRaw: String
    let data: NoopInstrumentData

    private var filter: NoopInstrumentGroupFilter {
        NoopInstrumentGroupFilter(rawValue: filterRaw) ?? .all
    }

    private var visibleGroups: [NoopInstrumentGroup] {
        NoopInstrumentGroup.allCases.filter { filter == .all || filter.group == $0 }
    }

    var body: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 0) {
                NoopInstrumentBackHeader(label: "Trends") {
                    navigation.back(or: .trends)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("All signals")
                        .font(NoopHTMLFont.outfit(25))
                        .tracking(-0.625)
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text("Browse your metrics by category. Open a signal for its interactive history, recorded values and comparisons.")
                        .font(NoopHTMLFont.sans(13.5))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .lineSpacing(4.2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                NoopInstrumentRangeControl(
                    range: $range,
                    worn: data.indexNightCount(for: range),
                    availableDays: data.historyCount
                )
                    // Swift's multiline text block resolves seven points shorter than the
                    // browser's explicit 13.5/21.6 line box. Keep the next authored edge at
                    // the HTML's y=222 instead of letting every row drift upward.
                    .padding(.top, 18)

                NoopFlowLayout(spacing: 6) {
                    ForEach(NoopInstrumentGroupFilter.allCases) { item in
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) { filterRaw = item.rawValue }
                        } label: {
                            Text(item.rawValue)
                                .font(NoopHTMLFont.sans(11.5, weight: .medium))
                                .foregroundStyle(item == filter ? Color(hex: 0xC6CEE8) : NoopHTMLColor.copy)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 36)
                                .background(
                                    item == filter ? NoopHTMLColor.night.opacity(0.20) : Color.white.opacity(0.05),
                                    in: RoundedRectangle(cornerRadius: 11)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 11)
                                        .stroke(item == filter ? NoopHTMLColor.night.opacity(0.42) : Color.white.opacity(0.07), lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(NoopHTMLPressStyle())
                        .accessibilityAddTraits(item == filter ? .isSelected : [])
                    }
                }
                .padding(.top, 12)

                VStack(alignment: .leading, spacing: 16) {
                    ForEach(visibleGroups) { group in
                        NoopInstrumentGroupCard(
                            group: group,
                            rows: data.snapshots(group: group, range: range),
                            open: open
                        )
                    }
                }
                .padding(.top, 13)

                VStack(alignment: .leading, spacing: 9) {
                    VStack(spacing: 0) {
                        NoopInstrumentDoor(
                            title: NoopRoute.instrumentCompare.screenTitle,
                            detail: "compare two patterns and their timing",
                            glyph: .overlay,
                            action: { navigation.push(.instrumentCompare) }
                        )
                        Divider().overlay(NoopHTMLColor.border).frame(height: 0.5)
                        NoopInstrumentDoor(
                            title: NoopRoute.instrumentEffects.screenTitle,
                            detail: "the ranking, the lag, and what one more costs",
                            glyph: .bolt,
                            action: { navigation.push(.instrumentEffects) }
                        )
                        Divider().overlay(NoopHTMLColor.border).frame(height: 0.5)
                        DisclosureGroup {
                        NoopInstrumentDoor(
                            title: "Raw capture",
                            detail: "record the 100 Hz motion stream to this phone",
                            glyph: .bolt,
                            action: { navigation.push(.instrumentRaw) }
                        )
                        } label: {
                            Text("Advanced tools").font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.ink).frame(minHeight: 44)
                        }
                        .tint(NoopHTMLColor.night)

                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))

                    Text("Everything here is an association in your own data. Noop will not tell you one thing caused another, and it will not draw a line it cannot defend at the length you asked for.")
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .lineSpacing(3.9)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 2)
                }
                .padding(.top, 16)
            }
        }
    }

    private func open(_ row: NoopInstrumentSnapshot) {
        navigation.instrumentMetricKey = row.signal.key
        navigation.push(.instrumentMetric)
    }
}

private struct NoopInstrumentWindowContext {
    let first: Date
    let last: Date
    let start: Date
    let end: Date
    let totalDays: Int
    let step: Int
    let setEnd: (Date) -> Void
}

private struct NoopInstrumentWindowKey: EnvironmentKey {
    static let defaultValue: NoopInstrumentWindowContext? = nil
}

private extension EnvironmentValues {
    var noopInstrumentWindow: NoopInstrumentWindowContext? {
        get { self[NoopInstrumentWindowKey.self] }
        set { self[NoopInstrumentWindowKey.self] = newValue }
    }
}

private struct NoopInstrumentDateNavigation: View {
    let window: NoopInstrumentWindowContext
    var range: Binding<NoopInstrumentRange>?
    var availableDays = 0
    @State private var choosingDate = false

    private var earlier: Date? { Calendar.current.date(byAdding: .day, value: -window.step, to: window.end).map { max($0, window.first) } }
    private var later: Date? { Calendar.current.date(byAdding: .day, value: window.step, to: window.end).map { min($0, window.last) } }
    private var label: String {
        let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate("d MMM y")
        return "\(f.string(from: window.start)) – \(f.string(from: window.end))"
    }

    var body: some View {
        VStack(spacing: 5) {
            if let range {
                HStack(spacing: 2) {
                    footerStep(.left, enabled: window.end > window.first) {
                        if let earlier { window.setEnd(earlier) }
                    }
                    ForEach(NoopInstrumentRange.allCases.filter { $0 != .overview }) { item in
                        Button {
                            withAnimation(NoopMotion.swap) { range.wrappedValue = item }
                        } label: {
                            Text(item.label)
                                .font(NoopHTMLFont.sans(12.5, weight: .semibold))
                                .foregroundStyle(item == range.wrappedValue ? NoopHTMLColor.ink : NoopHTMLColor.copy)
                                .frame(maxWidth: .infinity).frame(minHeight: 44)
                                .background(item == range.wrappedValue ? Color.white.opacity(0.09) : .clear, in: Capsule())
                        }
                        .disabled(!item.isAvailable(total: availableDays))
                        .opacity(item.isAvailable(total: availableDays) ? 1 : 0.4)
                        .accessibilityAddTraits(item == range.wrappedValue ? .isSelected : [])
                    }
                    footerStep(.right, enabled: window.end < window.last) {
                        if let later { window.setEnd(later) }
                    }
                }
                .padding(3)
                .background(Color.white.opacity(0.04), in: Capsule())
                Button { choosingDate = true } label: {
                    Label(label, systemImage: "calendar").frame(minHeight: 44)
                }
                .accessibilityLabel("Choose dates, \(label)")
            } else {
                legacyNavigation
            }
        }
        .font(NoopHTMLFont.sans(11.5))
        .foregroundStyle(NoopHTMLColor.copy)
        .buttonStyle(NoopPlainHitStyle())
        .sheet(isPresented: Binding(get: { choosingDate && range == nil }, set: { choosingDate = $0 })) { calendarSheet }
        .navigationDestination(isPresented: Binding(get: { choosingDate && range != nil }, set: { choosingDate = $0 })) {
            calendarSheet.toolbar(.hidden, for: .navigationBar)
        }
    }

    private func footerStep(_ direction: NoopFixedChevron.Direction, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button { withAnimation(NoopMotion.swap) { action() } } label: {
            NoopFixedChevron(direction: direction, color: enabled ? NoopHTMLColor.inkSoft : NoopHTMLColor.chevronDim)
                .frame(width: 34, height: 44)
        }
        .disabled(!enabled)
        .accessibilityLabel(direction == .left ? "Previous date window" : "Next date window")
    }

    private var legacyNavigation: some View {
        HStack(spacing: 4) {
            Button { if let earlier { window.setEnd(earlier) } } label: {
                Image(systemName: "chevron.left").frame(width: 36, height: 44)
            }
            .disabled(window.end <= window.first)
            .accessibilityLabel("Previous date window")
            Spacer(minLength: 0)
            Button { choosingDate = true } label: {
                HStack(spacing: 7) {
                    Image(systemName: "calendar")
                    Text(label).multilineTextAlignment(.center)
                }
                .frame(minHeight: 44)
            }
            .accessibilityLabel("Choose dates, \(label)")
            Spacer(minLength: 0)
            Button { if let later { window.setEnd(later) } } label: {
                Image(systemName: "chevron.right").frame(width: 36, height: 44)
            }
            .disabled(window.end >= window.last)
            .accessibilityLabel("Next date window")
        }
        .font(NoopHTMLFont.sans(11.5))
        .foregroundStyle(NoopHTMLColor.copy)
        .buttonStyle(NoopPlainHitStyle())
    }

    private var calendarSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Choose dates").font(NoopHTMLFont.sheetTitle)
                Spacer()
                Button("Done") { choosingDate = false }.frame(minWidth: 44, minHeight: 44)
            }
            DatePicker("Period ending", selection: Binding(get: { window.end }, set: window.setEnd),
                       in: window.first...window.last, displayedComponents: .date)
                .datePickerStyle(.graphical)
            Button("Return to latest") { window.setEnd(window.last); choosingDate = false }
                .frame(minHeight: 44)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .foregroundStyle(NoopHTMLColor.ink)
        .tint(NoopHTMLColor.night)
        .background(NoopHTMLColor.canvas)
        .noopSheet()
        .preferredColorScheme(.dark)
    }
}

private struct NoopInstrumentRangeControl: View {
    @Environment(\.noopInstrumentWindow) private var dateWindow
    @Binding var range: NoopInstrumentRange
    let worn: Int
    let availableDays: Int
    var chartFooter = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if chartFooter, let dateWindow {
                NoopInstrumentDateNavigation(window: dateWindow, range: $range, availableDays: dateWindow.totalDays)
            } else {
                rangePicker
            }
        }
    }

    private var rangePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            if range == .overview {
                Text("TRENDS PERIOD")
                    .font(NoopHTMLFont.sans(10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(NoopHTMLColor.muted)
            }
            NoopInstrumentRangeTabs(range: $range, availableDays: dateWindow?.totalDays ?? availableDays)
            if let dateWindow { NoopInstrumentDateNavigation(window: dateWindow) }

            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("\(worn)")
                    .font(NoopHTMLFont.outfit(17, weight: .light))
                    .monospacedDigit()
                    .foregroundStyle(NoopHTMLColor.ink)
                Text(note)
                    .font(NoopHTMLFont.sans(12))
                    .foregroundStyle(Color(hex: 0x7F8A85))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 3)
        }
    }

    private var note: String {
        switch range {
        case .overview:
            "recorded days within the dates opened from Trends"
        case .all:
            "recorded days across \(availableDays) calendar days"
        case .year:
            if range.isAvailable(total: availableDays) {
                "recorded days in this 365-day window"
            } else {
                "recorded days in the available history"
            }
        case .thirty, .ninety, .halfYear:
            "recorded days in this \(range.requestedDayCount ?? availableDays)-day window"
        }
    }
}

private struct NoopInstrumentRangeTabs: View {
    @Binding var range: NoopInstrumentRange
    let availableDays: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(NoopInstrumentRange.allCases.filter { $0 != .overview }) { item in
                Button {
                    guard item.isAvailable(total: availableDays) else { return }
                    withAnimation(.easeInOut(duration: 0.22)) { range = item }
                } label: {
                    Text(item.label)
                        .font(NoopHTMLFont.sans(12.5, weight: .semibold))
                        .foregroundStyle(item == range ? Color(hex: 0xC6CEE8) : item.isAvailable(total: availableDays) ? NoopHTMLColor.copy : NoopHTMLColor.ink.opacity(0.38))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 38)
                        .background(item == range ? NoopHTMLColor.night.opacity(0.20) : .clear, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(NoopHTMLPressStyle())
                .disabled(!item.isAvailable(total: availableDays))
                .accessibilityAddTraits(item == range ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.07), lineWidth: 0.5))
    }
}

private struct NoopInstrumentGroupCard: View {
    let group: NoopInstrumentGroup
    let rows: [NoopInstrumentSnapshot]
    let open: (NoopInstrumentSnapshot) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(group.heading.uppercased())
                    .font(NoopHTMLFont.sans(10, weight: .semibold))
                    .tracking(1.3)
                    .foregroundStyle(NoopHTMLColor.muted)
                Spacer()
                Text("\(rows.count) signals")
                    .font(NoopHTMLFont.sans(10.5))
                    .foregroundStyle(NoopHTMLColor.faint)
            }
            .padding(.horizontal, 3)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 {
                        Divider().overlay(Color.white.opacity(0.055)).frame(height: 0.5)
                    }
                    Button { open(row) } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(row.signal.name)
                                    .font(NoopHTMLFont.sans(13.5))
                                    .foregroundStyle(NoopHTMLColor.ink)
                                    .lineLimit(1)
                                HStack(alignment: .firstTextBaseline, spacing: 5) {
                                    Text(row.value)
                                        .font(NoopHTMLFont.outfit(19, weight: .light))
                                        .tracking(-0.38)
                                        .monospacedDigit()
                                        .foregroundStyle(NoopHTMLColor.ink)
                                    Text(row.unit)
                                        .font(NoopHTMLFont.sans(11))
                                        .foregroundStyle(NoopHTMLColor.muted)
                                        .lineLimit(1)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            VStack(alignment: .trailing, spacing: 6) {
                                Text(row.delta)
                                    .font(NoopHTMLFont.sans(10.5, weight: .semibold))
                                    .foregroundStyle(row.style.chipInk)
                                    .padding(.horizontal, 8)
                                    .frame(minHeight: 23)
                                    .background(row.style.chipFill, in: RoundedRectangle(cornerRadius: 7))
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                NoopInstrumentSparkline(points: row.points, color: row.style.stroke)
                            }
                            .fixedSize(horizontal: true, vertical: false)
                            .frame(minWidth: 86, alignment: .trailing)

                            NoopFixedChevron(direction: .right, color: NoopHTMLColor.chevronDim)
                                .frame(width: 7)
                        }
                        .frame(minHeight: 68)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 2)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))
        }
    }
}

private struct NoopInstrumentSparkline: View {
    let points: [CGPoint?]
    let color: Color

    var body: some View {
        Canvas { context, _ in
            var path = Path()
            var previousWasMeasured = false
            for point in points {
                guard let point else {
                    previousWasMeasured = false
                    continue
                }
                if previousWasMeasured { path.addLine(to: point) }
                else { path.move(to: point) }
                previousWasMeasured = true
            }
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
            if let last = points.compactMap({ $0 }).last {
                context.fill(Path(ellipseIn: CGRect(x: last.x - 2.4, y: last.y - 2.4, width: 4.8, height: 4.8)), with: .color(color))
            }
        }
        .frame(width: 86, height: 26)
        .accessibilityHidden(true)
    }
}

private struct NoopInstrumentDoor: View {
    let title: String
    let detail: String
    let glyph: NoopCanonicalGlyphName
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                NoopCanonicalGlyph(name: glyph, size: 20, color: NoopHTMLColor.night)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(NoopHTMLFont.sans(13.5)).foregroundStyle(NoopHTMLColor.ink)
                    Text(detail).font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color(hex: 0x7F8A85))
                }
                Spacer(minLength: 8)
                NoopFixedChevron(direction: .right, color: NoopHTMLColor.chevronDim)
            }
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(NoopHTMLPressStyle())
    }
}

private struct NoopInstrumentBackHeader: View {
    @Environment(\.noopBackLabel) private var actualParent
    let label: String
    let action: () -> Void

    init(label: String, action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }

    var body: some View {
        HStack(spacing: 12) {
            NoopBackButton(action: action)
            .accessibilityLabel("Back to \(actualParent ?? label)")
            NoopBackTitle(actualParent ?? label)
            Spacer()
        }
        .padding(.horizontal, -2)
        .padding(.bottom, 16)
    }
}

/// The visual grammar follows instrument/raw and instrument/capture. Prototype sample rows are
/// confined to `--demo-seed`; outside that Debug fixture every value comes from persisted IMU data.
private struct NoopInstrumentRawScreen: View {
    @ObservedObject var navigation: NoopNavigation
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var live: NoopLiveGlance
    @StateObject private var store = RawDataSessionStore()
    @State private var now = Date()
    @State private var deleteCandidate: RawDataSessionStore.Session?
    @State private var errorMessage: String?
    @State private var exporting = false

    private var sessions: [RawDataSessionStore.Session] {
        return store.sessions
    }

    private var active: RawDataSessionStore.Session? {
        store.active
    }

    private var selected: RawDataSessionStore.Session? {
        if let id = navigation.instrumentRawSessionID {
            return sessions.first { $0.id == id }
        }
        return sessions.first { !$0.active }
    }

    var body: some View {
        Group {
            if navigation.route == .instrumentCapture { captureScreen }
            else { rawScreen }
        }
        .task { restoreActiveCaptureIfPossible() }
        .onChange(of: live.bonded) { _, bonded in
            if bonded { restoreActiveCaptureIfPossible() }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now = $0 }
        .alert("Raw capture", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .confirmationDialog("Delete this capture?", isPresented: Binding(
            get: { deleteCandidate != nil }, set: { if !$0 { deleteCandidate = nil } }
        ), titleVisibility: .visible) {
            Button("Delete capture", role: .destructive) {
                guard let candidate = deleteCandidate else { return }
                deleteCandidate = nil
                if store.removeMetadata(candidate.id) { navigation.back(or: .instrumentRaw) }
                else { errorMessage = "The capture could not be deleted. Its record was kept so you can try again." }
            }
            Button("Cancel", role: .cancel) { deleteCandidate = nil }
        } message: { Text("Its local session record and captured motion data will be deleted permanently.") }
    }

    private var rawScreen: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 0) {
                NoopInstrumentBackHeader(label: "All signals") {
                    navigation.back(or: .instrumentIndex)
                }
                Text("Raw capture")
                    .font(NoopHTMLFont.outfit(25)).tracking(-0.625)
                    .foregroundStyle(NoopHTMLColor.ink)
                Text("Accelerometer and gyroscope at 100 Hz from a connected WHOOP 5/MG, written to this phone. Nothing is uploaded or fed into another Noop screen.")
                    .font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.copy)
                    .lineSpacing(4.5).fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)

                armCard.padding(.top, 16)
                VStack(alignment: .leading, spacing: 10) {
                    NoopSectionLabel("What it will record")
                    specRow("Channels", "accel · gyro")
                    specRow("Rate", "100 Hz")
                    specRow("Written to", "this phone")
                    specRow("Leaves the phone", "only if you export")
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
                .padding(.top, 12)

                HStack {
                    NoopSectionLabel("Captures on this phone")
                    Spacer()
                    Text("\(sessions.count) files")
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(NoopHTMLColor.copy)
                }
                .padding(.horizontal, 4).padding(.top, 18).padding(.bottom, 9)

                if sessions.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No captures yet").font(NoopHTMLFont.sans(13))
                            .foregroundStyle(NoopHTMLColor.ink)
                        Text("Arm one above. Nothing is running in the background and nothing starts on its own.")
                            .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(17).frame(maxWidth: .infinity, alignment: .leading)
                    .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20))
                } else {
                    VStack(spacing: 0) {
                        ForEach(sessions) { session in
                            Button {
                                navigation.instrumentRawSessionID = session.id
                                navigation.push(.instrumentCapture)
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("cap_\(session.id.suffix(6))")
                                            .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(NoopHTMLColor.ink)
                                        Text(Self.date(session.startedAtMs))
                                            .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.copy)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 3) {
                                        Text(Self.duration(session, now: now))
                                            .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(NoopHTMLColor.ink)
                                        Text(Self.size(stats(for: session).bytes))
                                            .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.copy)
                                    }
                                    NoopFixedChevron(direction: .right, color: NoopHTMLColor.chevronDim)
                                }
                                .frame(minHeight: 68).contentShape(Rectangle())
                            }
                            .buttonStyle(NoopPlainHitStyle())
                            if session.id != sessions.last?.id {
                                Divider().overlay(NoopHTMLColor.border).frame(height: 0.5)
                            }
                        }
                    }
                    .padding(.horizontal, 15)
                    .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20))
                }
                Text("Captures remain on this phone until you delete them. Export opens the iOS share sheet; Noop does not send a capture on its own.")
                    .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy)
                    .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2).padding(.top, 13)
            }
        }
    }

    private var armCard: some View {
        let active = self.active
        let stats = active.map { stats(for: $0) }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Circle().fill(active == nil ? Color.white.opacity(0.2) : Color(hex: 0xE3574E))
                    .frame(width: 9, height: 9)
                Text(active == nil ? "Not recording" : live.bonded ? "Recording" : "Armed · disconnected")
                    .font(NoopHTMLFont.sans(10, weight: .semibold)).tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(active == nil ? NoopHTMLColor.copy : Color(hex: 0xF2B3AE))
            }
            HStack(alignment: .bottom) {
                Text(active.map { Self.duration($0, now: now) } ?? "00:00")
                    .font(.system(size: active == nil ? 26 : 38, weight: .semibold, design: .monospaced))
                    .foregroundStyle(active == nil ? Color(hex: 0x3E4643) : NoopHTMLColor.ink)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Self.size(stats?.bytes ?? 0))
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text(active == nil ? "nothing recorded now" : "100 Hz · \(stats?.coveredSeconds ?? 0) s covered")
                        .font(NoopHTMLFont.sans(10.5)).foregroundStyle(NoopHTMLColor.copy)
                }
            }
            Text(active == nil
                 ? "Arming records until you stop it. It does not stop when you leave this screen. A connected WHOOP 5/MG is required."
                 : live.bonded
                    ? "The strap is sending 100 Hz motion data. This uses noticeable battery and continues after you leave this screen until you stop it."
                    : "The strap is disconnected, so no new samples can arrive. The capture remains armed and can resume when the strap reconnects.")
                .font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color(hex: 0xB7C3C9))
                .lineSpacing(3.5).fixedSize(horizontal: false, vertical: true)
            Button {
                if active == nil { start() }
                else { Task { await stop() } }
            } label: {
                Text(active == nil ? "Arm capture" : "Stop recording")
                    .font(NoopHTMLFont.sans(15, weight: .semibold))
                    .foregroundStyle(active == nil ? NoopHTMLColor.ink : Color(hex: 0x1A0705))
                    .frame(maxWidth: .infinity).frame(minHeight: 56)
                    .background(active == nil ? Color.white.opacity(0.07) : Color(hex: 0xE3574E),
                                in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(active == nil ? Color.white.opacity(0.16) : Color.clear, lineWidth: 0.5))
            }
            .buttonStyle(NoopPlainHitStyle())
        }
        .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(active == nil ? NoopHTMLColor.card : Color(hex: 0xE3574E).opacity(0.09),
                    in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22)
            .strokeBorder(active == nil ? NoopHTMLColor.border : Color(hex: 0xE3574E).opacity(0.42), lineWidth: 0.5))
    }

    private var captureScreen: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 0) {
                NoopInstrumentBackHeader(label: "Raw capture") {
                    navigation.back(or: .instrumentRaw)
                }
                if let selected {
                    Text("cap_\(selected.id.suffix(6))")
                        .font(.system(size: 19, weight: .semibold, design: .monospaced))
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text(Self.date(selected.startedAtMs))
                        .font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.copy)
                        .padding(.top, 5)
                    let stats = stats(for: selected)
                    VStack(spacing: 0) {
                        captureRow("Duration", Self.duration(selected, now: now))
                        captureRow("Channels", "2")
                        captureRow("Rate", "100 Hz")
                        captureRow("Samples / channel", "\(stats.coveredSeconds * 100)")
                        captureRow("Covered seconds", "\(stats.coveredSeconds)")
                        captureRow("Size on disk", Self.size(stats.bytes))
                        specRow("Source", "WHOOP 5/MG", minHeight: 46)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 4)
                    .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20))
                    .padding(.top, 16)
                    VStack(alignment: .leading, spacing: 11) {
                        HStack {
                            NoopSectionLabel("Samples per channel")
                            Spacer()
                            Text("100 Hz").font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(NoopHTMLColor.copy)
                        }
                        coverageRow("accel", stats.coveredSeconds * 100)
                        coverageRow("gyro", stats.coveredSeconds * 100)
                        Text("Only complete recorded seconds are counted. An exact gap-by-gap waveform is not available here, so none is invented.")
                            .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.copy)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16).background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20))
                    .padding(.top, 12)
                    Button { Task { await export(selected) } } label: {
                        Text(exporting ? "Preparing export…" : "Export capture")
                            .font(NoopHTMLFont.sans(14, weight: .semibold))
                            .frame(maxWidth: .infinity).frame(minHeight: 52)
                    }
                    .buttonStyle(NoopPlainHitStyle()).disabled(exporting || selected.active)
                    .foregroundStyle(NoopHTMLColor.ink)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 17))
                    .padding(.top, 12)
                    Button { deleteCandidate = selected } label: {
                        Text("Delete this capture").font(NoopHTMLFont.sans(14))
                            .frame(maxWidth: .infinity).frame(minHeight: 52)
                    }
                    .buttonStyle(NoopPlainHitStyle()).disabled(selected.active)
                    .foregroundStyle(NoopHTMLColor.ink)
                    .overlay(RoundedRectangle(cornerRadius: 17)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
                    .padding(.top, 8)
                    Text("Export creates a local ZIP of the recorded stream and opens the share sheet. Where it goes after that is your decision.")
                        .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 2).padding(.top, 12)
                } else {
                    Text("This capture is no longer on this phone.")
                        .font(NoopHTMLFont.sans(13.5)).foregroundStyle(NoopHTMLColor.copy)
                }
            }
        }
    }

    private func specRow(_ name: String, _ value: String, minHeight: CGFloat = 17) -> some View {
        HStack(spacing: 12) {
            Text(name).font(NoopHTMLFont.sans(12.5)).foregroundStyle(Color(hex: 0xC6CEC9))
            Spacer(minLength: 0)
            Text(value).font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(NoopHTMLColor.ink).multilineTextAlignment(.trailing)
        }
        .frame(minHeight: minHeight)
    }

    private func captureRow(_ name: String, _ value: String) -> some View {
        specRow(name, value, minHeight: 46)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.white.opacity(0.06)).frame(height: 0.5)
            }
    }

    private func coverageRow(_ name: String, _ count: Int) -> some View {
        HStack(spacing: 11) {
            Text(name).font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                .frame(width: 52, alignment: .leading)
            Rectangle().fill(NoopHTMLColor.blue.opacity(count == 0 ? 0.15 : 0.55))
                .frame(height: 12).clipShape(RoundedRectangle(cornerRadius: 3))
        
            Text(count.formatted(.number.grouping(.automatic)))
                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(NoopHTMLColor.ink)
    }

    private func stats(for session: RawDataSessionStore.Session) -> ImuSessionFileStore.Stats {
        let from = Int(session.startedAtMs / 1_000)
        let endMs = session.endedAtMs ?? Int64(now.timeIntervalSince1970 * 1_000)
        return ImuSessionFileStore.shared.stats(session.id, from: from, to: Int(endMs / 1_000))
    }

    private func start() {
        guard live.bonded, model.ble.isWhoop5 else {
            errorMessage = "Connect a WHOOP 5/MG before arming a capture."
            return
        }
        guard let session = store.start(deviceId: model.ble.deviceId) else { return }
        guard model.ble.startGroundTruthRawCapture(sessionId: session.id) else {
            store.stop()
            _ = store.removeMetadata(session.id)
            errorMessage = "The motion stream could not be started. No capture was kept."
            return
        }
    }

    private func restoreActiveCaptureIfPossible() {
        guard let session = store.active, live.bonded, model.ble.isWhoop5 else { return }
        _ = model.ble.startGroundTruthRawCapture(sessionId: session.id)
    }

    private func stop() async {
        await model.ble.stopGroundTruthRawCapture()
        store.stop()
    }

    private func export(_ session: RawDataSessionStore.Session) async {
        guard let endMs = session.endedAtMs else { return }
        exporting = true
        defer { exporting = false }
        let from = Int(session.startedAtMs / 1_000)
        let to = Int(endMs / 1_000)
        let segments = ImuSessionFileStore.shared.exportSegments(session.id, from: from, to: to)
        guard !segments.isEmpty else {
            errorMessage = "There are no complete motion samples to export from this capture."
            return
        }
        var entries = store.exportEntries(for: session, sensorAvailable: true)
        entries += segments.map { FileExport.BundleEntry(name: "imu/\($0.name)", data: $0.data) }
        if await FileExport.exportBundle(entries: entries,
                                         suggestedName: "noop-5mg-raw-\(session.id).zip") == nil {
            errorMessage = "The export file could not be created or shared."
        } else {
            store.markExported(session.id)
        }
    }

    private static func date(_ milliseconds: Int64) -> String {
        Date(timeIntervalSince1970: Double(milliseconds) / 1_000)
            .formatted(date: .abbreviated, time: .shortened)
    }

    private static func duration(_ session: RawDataSessionStore.Session, now: Date) -> String {
        let end = session.endedAtMs ?? Int64(now.timeIntervalSince1970 * 1_000)
        let seconds = max(0, Int((end - session.startedAtMs) / 1_000))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private static func size(_ bytes: Int64) -> String {
        bytes < 1_000_000 ? "\(max(0, bytes / 1_000)) kB"
            : String(format: "%.1f MB", Double(bytes) / 1_000_000)
    }
}

private struct NoopInstrumentMetricScreen: View {
    @ObservedObject var navigation: NoopNavigation
    @Binding var range: NoopInstrumentRange
    let data: NoopInstrumentData
    @State private var selectedDate: Date?
    @State private var showAllReadings = false
    @State private var showingDataContext = false

    private var selectedReading: NoopInstrumentReading? {
        model.readings.first { $0.date == selectedDate }
    }

    private func select(_ reading: NoopInstrumentReading) {
        selectDate(reading.date)
    }

    private func selectDate(_ date: Date) {
        guard selectedDate != date else { return }
        selectedDate = date
        UISelectionFeedbackGenerator().selectionChanged()
    }
    private var selectedMissingDay: Bool { selectedDate != nil && selectedReading == nil }
    private var hasDisplayValue: Bool { !selectedMissingDay && !model.readings.isEmpty }
    private var latestAssessment: NoopInstrumentAssessment? {
        guard !selectedMissingDay, selectedDate == nil || selectedDate == model.readings.last?.date else { return nil }
        return model.assessment
    }
    private var relatedSignals: [NoopInstrumentSignal] {
        data.signals.filter { $0.group == model.signal.group }
    }

    private let model: NoopInstrumentMetricModel

    init(navigation: NoopNavigation, range: Binding<NoopInstrumentRange>, data: NoopInstrumentData, windowStart: Date? = nil) {
        self.navigation = navigation
        self._range = range
        self.data = data
        // Build once per parent input update; scrubbing must not rerun every correlation.
        self.model = data.metric(key: navigation.instrumentMetricKey, range: range.wrappedValue, windowStart: windowStart)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                NoopSheetHeader(title: model.signal.name, closeLabel: "Close metric details") {
                    navigation.dismissMetricSheet()
                }
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 12)
                ScrollViewReader { scroll in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            metricValueHeader.id("metric-top")
                            relatedMetricPicker
                            metricSections
                        }
                        .padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 32)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: navigation.instrumentMetricKey) { _ in scroll.scrollTo("metric-top", anchor: .top) }
                }
            }
            .background(NoopHTMLColor.canvas)
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(NoopHTMLColor.night)
        .preferredColorScheme(.dark)
        .onChange(of: navigation.instrumentMetricKey) { _ in selectedDate = nil; showAllReadings = false; showingDataContext = false }
        .onChange(of: model.readings) { _ in
            selectedDate = nil
            showAllReadings = false
        }
    }

    private var metricSections: some View {
        VStack(alignment: .leading, spacing: 14) {
            metricChartCard
            NoopInstrumentRangeControl(
                range: $range,
                worn: model.worn,
                availableDays: data.historyCount,
                chartFooter: true
            )

            if let trendAnalysis { metricTrendAnalysisCard(trendAnalysis) }
            else if model.comparison != nil { metricComparisonCard }
            if !model.readings.isEmpty { metricReadingsCard }
            metricDataContext
            if model.thin {
                VStack(alignment: .leading, spacing: 9) {
                    Text(model.readings.isEmpty ? "No recorded values" : "Relationships need more history")
                        .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text(model.thinNote)
                        .font(NoopHTMLFont.sans(12.5))
                        .foregroundStyle(Color(hex: 0xC9D0EE))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .background(NoopHTMLColor.night.opacity(0.08), in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.night.opacity(0.22), lineWidth: 0.5))
            }

            if !model.moves.isEmpty { metricMovesCard }

            metricLinksCard

            Text("Correlations are computed over the nights where both signals exist, at the best of three lags, and shown only above twenty-one nights and 0.22. Association, not cause.")
                .font(NoopHTMLFont.sans(11.5))
                .foregroundStyle(NoopHTMLColor.faint)
                .lineSpacing(3.9)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 2)
        }
    }

    private var metricValueHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(hasDisplayValue ? selectedReading?.value ?? model.value : "No data")
                        .font(NoopHTMLFont.outfit(hasDisplayValue ? 44 : 32, weight: .light))
                        .monospacedDigit().foregroundStyle(NoopHTMLColor.ink)
                    if hasDisplayValue {
                        Text(model.unit).font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.copy)
                    }
                }
                if let date = selectedDate ?? model.readings.last?.date ?? model.plot.series.samples.last?.date {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(NoopHTMLFont.sans(12)).foregroundStyle(NoopHTMLColor.faint)
                }
            }
            Spacer(minLength: 0)
            if let assessment = latestAssessment {
                VStack(alignment: .trailing, spacing: 5) {
                    Text(assessment.label).font(NoopHTMLFont.sans(13, weight: .semibold))
                        .foregroundStyle(assessment.outside ? NoopHTMLColor.warm : NoopHTMLColor.inkSoft)
                    if let range = assessment.personalRange {
                        Text("\(NoopInstrumentData.chartTickLabel(range.lowerBound, key: model.signal.key))–\(NoopInstrumentData.chartTickLabel(range.upperBound, key: model.signal.key)) \(model.unit)")
                            .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.faint)
                        Text(assessment.rangeCaption).font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.faint)
                    }
                }
            } else if !hasDisplayValue {
                Text("Nothing recorded").font(NoopHTMLFont.sans(12)).foregroundStyle(NoopHTMLColor.faint)
            }
        }
    }

    private var relatedMetricPicker: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(relatedSignals) { signal in
                        Button {
                            navigation.instrumentMetricKey = signal.key
                            if let window = navigation.instrumentOverviewWindow {
                                navigation.instrumentOverviewWindow = .init(start: window.start, end: window.end,
                                    metricKey: signal.key, weeklySummary: nil, deviceId: window.deviceId)
                            }
                        } label: {
                            Text(signal.name).font(NoopHTMLFont.sans(12.5, weight: .medium))
                                .foregroundStyle(signal.key == model.signal.key ? NoopHTMLColor.ink : NoopHTMLColor.copy)
                                .padding(.horizontal, 15).frame(minHeight: 44)
                                .background(signal.key == model.signal.key ? NoopHTMLColor.night.opacity(0.25) : Color.white.opacity(0.04), in: Capsule())
                        }
                        .id(signal.key)
                        .buttonStyle(NoopPlainHitStyle())
                        .accessibilityAddTraits(signal.key == model.signal.key ? .isSelected : [])
                    }
                }
            }
            .onAppear { proxy.scrollTo(model.signal.key, anchor: .center) }
        }
    }

    private var metricChartCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(model.span.uppercased())
                    .font(NoopHTMLFont.sans(10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(NoopHTMLColor.faint)
                Spacer()
                // Only a trusted assessment earns a chip here; a bare first-to-last "+5" read as unexplained.
                if let assessment = model.assessment, assessment.rangeCaption == "Personal range" {
                    NoopInstrumentDeltaChip(text: assessment.label, style: assessment.outside ? .bad : model.style, fontSize: 11, radius: 8, horizontalPadding: 9)
                }
            }

            NoopHistoryPlot(presentation: model.plot, tint: model.assessment?.outside == true ? NoopHTMLColor.warm : NoopHTMLColor.night,
                            scoreColors: model.signal.key == "recovery", measurements: model.signal.key == "weight",
                            bridgeMissingMeasurements: model.signal.key == "weight",
                            selectsMissingDays: model.signal.group != .body && !model.signal.behavior,
                            averageLabel: "Avg. \(model.average) \(model.unit)",
                            selectedDate: selectedDate,
                            valueLabel: { NoopInstrumentData.axisLabel($0, key: model.signal.key) },
                            axisValueLabel: { NoopInstrumentData.chartTickLabel($0, key: model.signal.key) },
                            onSelect: selectDate)
                .frame(height: 260)

            HStack {
                ForEach(Array(model.axis.enumerated()), id: \.offset) { index, label in
                    Text(label)
                    if index < model.axis.count - 1 { Spacer() }
                }
            }
            .font(NoopHTMLFont.sans(10.5))
            .foregroundStyle(NoopHTMLColor.faint)
            .padding(.leading, 16)
            .padding(.trailing, 44)

            HStack(spacing: 6) {
                if model.plot.bandSegments.contains(where: { $0.count > 1 }) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill((model.assessment?.outside == true ? NoopHTMLColor.warm : NoopHTMLColor.night).opacity(0.24))
                        .frame(width: 12, height: 8)
                    Text("30-day variability")
                } else if model.signal.key == "weight" {
                    Text("Dotted links join recorded measurements")
                } else {
                    Text(model.signal.behavior ? "Seven-day rates" : "Recorded daily values")
                }
                Spacer(minLength: 4)
                Text("\(model.readings.count) values").monospacedDigit()
            }
            .font(NoopHTMLFont.sans(11))
            .foregroundStyle(NoopHTMLColor.faint)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 13)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private var metricDataContext: some View {
        DisclosureGroup(isExpanded: $showingDataContext) {
            VStack(alignment: .leading, spacing: 9) {
                if let window = navigation.instrumentOverviewWindow, window.metricKey == model.signal.key,
                   let summary = window.weeklySummary { Text(summary) }
                Text(model.read)
                if model.signal.key == "cap" {
                    Text("Capacity is an estimate of aerobic fitness, expressed as ml/kg/min. It is not a laboratory measurement.")
                    Text("Aura uses its recorded VO₂ max estimates when available, falling back to Apple Health when that history is empty. The source below identifies the selected reading; the chart and recorded values share the same history.")
                }
                Text(model.chartNote)
                if model.trendAnalysis != nil {
                    Text("Trends analysis compares seven-day means from your recorded history up to the window's last day. Each mean requires at least four recorded days. A direction is not a health assessment.")
                }
                Text("\(model.readings.count) recorded values across \(model.plot.series.samples.count) calendar days shown. Missing values are not zero.")
                if let assessment = model.assessment {
                    Text("Latest assessment · \(assessment.label) · \(assessment.day)")
                        .foregroundStyle(assessment.outside ? NoopHTMLColor.warm : NoopHTMLColor.inkSoft)
                    if let range = assessment.personalRange {
                        Text("\(assessment.rangeCaption) · \(NoopInstrumentData.axisLabel(range.lowerBound, key: model.signal.key))–\(NoopInstrumentData.axisLabel(range.upperBound, key: model.signal.key)) \(model.unit)")
                        Text(assessment.rangeCaption == "Personal range"
                             ? "From the same trusted baseline used by Aura’s vital assessment. The shaded variability band is separate."
                             : "No trusted baseline yet, so this is your own last 30 days: mean ± one standard deviation of at least fourteen recorded days, the same band the chart shades. It describes where the latest value sits, not whether it is healthy.")
                    }
                    if assessment.outside {
                        Text("Amber line tint reflects the latest off-range assessment, not a classification of every historical point.")
                    }
                }
                if model.signal.key == "recovery" {
                    Text("Line colours follow Aura’s recovery scale for each recorded score.")
                }
                Text("Source · \((selectedReading ?? model.readings.last)?.source ?? (model.signal.behavior ? "Recorded journal answers" : "Source details unavailable"))")
                Text(model.signal.key == "weight" ? "The source supplies a daily aggregate. This list does not claim to show every individual weigh-in. Body-measurement unit preferences apply throughout this view." : "The period average uses recorded daily values, not a time-weighted average.")
                Text(model.signal.behavior ? "Frequencies use recorded answers. A missing journal answer does not mean the behaviour did not happen." : "The shaded band, when available, shows observed 30-day variability. It does not classify a result as normal, poor or optimal.")
            }
            .font(NoopHTMLFont.sans(12)).foregroundStyle(NoopHTMLColor.copy).padding(.top, 10)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("About this signal").font(NoopHTMLFont.sans(13, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                Text("Sources, coverage and method").font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy)
            }
            .frame(minHeight: 44)
        }
        .tint(NoopHTMLColor.night).padding(.horizontal, 16).padding(.vertical, 5)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
    }

    private var trendAnalysis: AuraHistoryTrendAnalysis? {
        guard let analysis = model.trendAnalysis,
              analysis.rows.contains(where: { $0.change != nil }) else { return nil }
        return analysis
    }

    private func trendChangeLabel(_ change: Double) -> String {
        let magnitude = NoopInstrumentData.chartTickLabel(abs(change), key: model.signal.key)
        let zero = NoopInstrumentData.chartTickLabel(0, key: model.signal.key)
        let sign = magnitude == zero ? "" : change > 0 ? "+" : "−"
        return "\(sign)\(magnitude) \(model.unit)".trimmingCharacters(in: .whitespaces)
    }

    private func metricTrendAnalysisCard(_ analysis: AuraHistoryTrendAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Trends analysis").font(NoopHTMLFont.sans(15, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
            if let asOf = analysis.asOf {
                Text("Through \(asOf.formatted(date: .abbreviated, time: .omitted))")
                    .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.faint)
            }
            HStack {
                Text("Period").frame(width: 66, alignment: .leading)
                Text("Change"); Spacer(); Text("Trend")
            }
            .font(NoopHTMLFont.sans(11, weight: .medium)).foregroundStyle(NoopHTMLColor.faint)
            ForEach(analysis.rows) { row in
                HStack(spacing: 10) {
                    Text("\(row.days)-day").frame(width: 66, alignment: .leading)
                    if let change = row.change {
                        // Direction only: an arrow in a neutral tint, flat when the change rounds to zero.
                        // Up is not good and down is not bad for every signal, so neither is coloured as such.
                        let flat = !trendChangeLabel(change).hasPrefix("+") && !trendChangeLabel(change).hasPrefix("−")
                        Image(systemName: flat ? "arrow.right" : change > 0 ? "arrow.up" : "arrow.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(flat ? NoopHTMLColor.faint : NoopHTMLColor.canvas)
                            .frame(width: 18, height: 18)
                            .background(flat ? Color.white.opacity(0.08) : NoopHTMLColor.blueLight, in: Circle())
                            .accessibilityHidden(true)
                        Text(trendChangeLabel(change))
                            .monospacedDigit()
                        Spacer(minLength: 4)
                        NoopHistoryPlot(presentation: .init(series: row.trend, showVariability: false),
                                        tint: NoopHTMLColor.night, compact: true)
                            .frame(width: 70, height: 26)
                    } else {
                        Text("Not enough data").font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.faint)
                        Spacer(minLength: 0)
                    }
                }
                .font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.inkSoft)
                .frame(minHeight: 36)
                if row.days != analysis.rows.last?.days { Divider().overlay(NoopHTMLColor.border) }
            }
            Text("Seven-day averages · recorded days only")
                .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy)
            if model.comparison != nil {
                DisclosureGroup {
                    metricComparisonContent.padding(.top, 10)
                } label: {
                    Text("Compare whole periods").font(NoopHTMLFont.sans(12.5, weight: .medium))
                        .foregroundStyle(NoopHTMLColor.inkSoft).frame(minHeight: 44)
                }
                .tint(NoopHTMLColor.inkSoft)
            }
        }
        .padding(16).background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
    }

    private var metricComparisonCard: some View {
        metricComparisonContent.padding(16).background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
    }

    private var metricComparisonContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PERIOD COMPARISON").font(NoopHTMLFont.sans(10, weight: .semibold)).tracking(1.2).foregroundStyle(NoopHTMLColor.muted)
            if let comparison = model.comparison {
                ForEach([("This period", comparison.current), ("Previous equal period", comparison.previous)], id: \.0) { label, period in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(label); Spacer()
                            Text(period.average.map { NoopInstrumentData.axisLabel($0, key: model.signal.key) + " " + model.unit } ?? "Not enough data")
                        }
                        Text("\(period.start.formatted(date: .abbreviated, time: .omitted)) – \(period.end.formatted(date: .abbreviated, time: .omitted)) · \(period.count) recorded values")
                            .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.muted)
                    }
                }
                Text("Means of recorded daily values. Different coverage can affect the comparison.")
                    .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy)
            }
        }
        .font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.ink)
    }

    private var metricReadingsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(model.signal.behavior ? "SEVEN-DAY RATES" : "RECORDED DAILY VALUES")
                .font(NoopHTMLFont.sans(10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(NoopHTMLColor.muted)
            LazyVStack(spacing: 0) {
                ForEach(Array(model.readings.reversed().prefix(showAllReadings ? model.readings.count : 5))) { reading in
                    Button { select(reading) } label: {
                        HStack {
                            Text(reading.date.formatted(date: .abbreviated, time: .omitted))
                                .foregroundStyle(NoopHTMLColor.copy)
                            Spacer()
                            Text("\(reading.value) \(model.unit)")
                                .monospacedDigit()
                                .foregroundStyle(NoopHTMLColor.ink)
                        }
                        .font(NoopHTMLFont.sans(13))
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(NoopPlainHitStyle())
                }
            }
            if model.readings.count > 5 {
                Button(showAllReadings ? "Show fewer" : "Show all \(model.readings.count) values") {
                    showAllReadings.toggle()
                }
                .font(NoopHTMLFont.sans(12, weight: .semibold))
                .foregroundStyle(NoopHTMLColor.ink)
                .frame(minHeight: 44)
                .buttonStyle(NoopPlainHitStyle())
            }
        }
        .padding(16)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private var metricMovesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("WHAT IT MOVES WITH")
                    .font(NoopHTMLFont.sans(10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(NoopHTMLColor.muted)
                Spacer()
                Text("strongest first")
                    .font(NoopHTMLFont.sans(10.5))
                    .foregroundStyle(NoopHTMLColor.faint)
            }

            VStack(alignment: .leading, spacing: 14) {
                ForEach(model.moves) { move in
                    Button {
                        navigation.instrumentCompareAKey = model.signal.key
                        navigation.instrumentCompareBKey = move.signal.key
                        navigation.instrumentCompareShift = move.lag
                        navigation.push(.instrumentCompare)
                    } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(move.signal.name)
                                    .font(NoopHTMLFont.sans(13))
                                    .foregroundStyle(NoopHTMLColor.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                                Text(move.lagLabel.uppercased())
                                    .font(NoopHTMLFont.sans(10, weight: .semibold))
                                    .tracking(0.4)
                                    .foregroundStyle(move.lag == 0 ? NoopHTMLColor.copy : Color(hex: 0xB7C0E8))
                                    .padding(.horizontal, 7)
                                    .frame(minHeight: 20)
                                    .background(move.lag == 0 ? Color.white.opacity(0.05) : NoopHTMLColor.night.opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
                                    .fixedSize(horizontal: true, vertical: false)
                                Text(move.coefficient)
                                    .font(NoopHTMLFont.outfit(16))
                                    .monospacedDigit()
                                    .foregroundStyle(Color(hex: 0xB7C0E8))
                                    .fixedSize()
                            }

                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.07))
                                    Capsule()
                                        .fill(NoopHTMLColor.night)
                                        .frame(width: proxy.size.width * move.barFraction)
                                }
                            }
                            .frame(height: 5)

                            Text(move.read)
                                .font(NoopHTMLFont.sans(11.5))
                                .foregroundStyle(Color(hex: 0x7F8A85))
                                .lineSpacing(3.1)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                }
            }
        }
        .padding(16)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private var metricLinksCard: some View {
        VStack(spacing: 0) {
            if model.signal.key == "sleep" {
                NoopInstrumentDoor(title: "Sleep rhythm", detail: "regularity, timing and your sleep need", glyph: .clock) {
                    navigation.push(.rhythm)
                }
                Divider().overlay(NoopHTMLColor.border).frame(height: 0.5)
            }
            NoopInstrumentDoor(title: NoopRoute.instrumentCompare.screenTitle, detail: "compare patterns, with the day-shift", glyph: .overlay) {
                navigation.instrumentCompareAKey = model.signal.key
                navigation.instrumentCompareBKey = model.signal.key == "hrv" ? "reg" : "hrv"
                navigation.instrumentCompareShift = 0
                navigation.push(.instrumentCompare)
            }
            Divider().overlay(NoopHTMLColor.border).frame(height: 0.5)
            NoopInstrumentDoor(title: "Ask Svea about this", detail: "she gets this dossier, not just the number", glyph: .chat) {
                navigation.reset(to: .coach)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))
    }
}

private struct NoopInstrumentDeltaChip: View {
    let text: String
    let style: NoopInstrumentChangeStyle
    var fontSize: CGFloat = 10.5
    var radius: CGFloat = 7
    var horizontalPadding: CGFloat = 8

    var body: some View {
        Text(text)
            .font(NoopHTMLFont.sans(fontSize, weight: .semibold))
            .foregroundStyle(style.chipInk)
            .padding(.horizontal, horizontalPadding)
            .frame(height: fontSize == 11 ? 24 : 23)
            .background(style.chipFill, in: RoundedRectangle(cornerRadius: radius))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }
}

private struct NoopInstrumentCompareScreen: View {
    @ObservedObject var navigation: NoopNavigation
    @Binding var range: NoopInstrumentRange
    let data: NoopInstrumentData

    private var model: NoopInstrumentComparisonModel {
        data.comparison(
            firstKey: navigation.instrumentCompareAKey,
            secondKey: navigation.instrumentCompareBKey,
            shift: navigation.instrumentCompareShift,
            range: range
        )
    }

    var body: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 0) {
                NoopInstrumentBackHeader(label: "All signals") {
                    navigation.back(or: .instrumentIndex)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(NoopRoute.instrumentCompare.screenTitle)
                        .font(NoopHTMLFont.outfit(25))
                        .tracking(-0.625)
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text(data.isPrototype
                         ? "Same axis, same window. The shift control asks whether one of them arrives a day late."
                         : "Same axis, same window. The shift control compares readings on the same day and up to two days apart.")
                        .font(NoopHTMLFont.sans(13.5))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .lineSpacing(4.2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 8) {
                        NoopInstrumentCompareSlotButton(tag: "A", signal: model.first, color: NoopHTMLColor.night) {
                            navigation.show(.instrumentSignalPickerA)
                        }
                        NoopInstrumentCompareSlotButton(tag: "B", signal: model.second, color: NoopHTMLColor.green) {
                            navigation.show(.instrumentSignalPickerB)
                        }
                    }

                    NoopInstrumentRangeControl(
                        range: $range,
                        worn: model.worn,
                        availableDays: data.historyCount
                    )

                    comparisonChartCard
                    comparisonFitCard
                    comparisonShiftCard

                    Text("Two lines that move together is not one causing the other. The fit is only drawn when it clears the bar, and it is left off when it does not.")
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .lineSpacing(3.9)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 2)
                }
                .padding(.top, 14)
            }
        }
    }

    private var comparisonChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            NoopInstrumentComparisonChart(model: model)

            HStack {
                ForEach(Array(model.axis.enumerated()), id: \.offset) { index, label in
                    Text(label)
                    if index < model.axis.count - 1 { Spacer() }
                }
            }
            .font(NoopHTMLFont.sans(10.5))
            .foregroundStyle(NoopHTMLColor.faint)

            HStack(spacing: 14) {
                comparisonLegend(color: NoopHTMLColor.night, label: model.first.name)
                comparisonLegend(color: NoopHTMLColor.green, label: model.secondLegend)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 13)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private func comparisonLegend(color: Color, label: String) -> some View {
        HStack(spacing: 7) {
            Capsule().fill(color).frame(width: 16, height: 3)
            Text(label)
                .font(NoopHTMLFont.sans(11))
                .foregroundStyle(NoopHTMLColor.copy)
                .lineLimit(1)
        }
    }

    private var comparisonFitCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(model.clears ? "THE FIT" : "NO FIT DRAWN")
                    .font(NoopHTMLFont.sans(10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(model.clears ? Color(hex: 0xC9D0EE) : NoopHTMLColor.muted)
                Spacer()
                Text("\(model.fitCount) nights with both")
                    .font(NoopHTMLFont.sans(11))
                    .foregroundStyle(NoopHTMLColor.faint)
                    .monospacedDigit()
            }
            Text(model.fitCoefficient)
                .font(NoopHTMLFont.outfit(26, weight: .light))
                .tracking(-0.78)
                .monospacedDigit()
                .foregroundStyle(NoopHTMLColor.ink)
            Text("Each signal uses its own value scale; line height compares patterns, not equal units. " + model.fitRead)
                .font(NoopHTMLFont.sans(12.5))
                .foregroundStyle(Color(hex: 0xC9D0EE))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 17)
        .background {
            if model.clears {
                NoopCSSLinearGradient(colors: [NoopHTMLColor.night.opacity(0.16), NoopHTMLColor.night.opacity(0.03)], degrees: 158)
            } else {
                NoopHTMLColor.card
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(model.clears ? NoopHTMLColor.night.opacity(0.30) : Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }

    private var comparisonShiftCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("SHIFT BY A DAY")
                    .font(NoopHTMLFont.sans(10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(NoopHTMLColor.muted)
                Spacer()
                Text(model.bestLabel)
                    .font(NoopHTMLFont.sans(10.5))
                    .foregroundStyle(NoopHTMLColor.faint)
            }

            HStack(spacing: 5) {
                ForEach(model.shifts) { option in
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            navigation.instrumentCompareShift = option.lag
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(option.label)
                                .font(NoopHTMLFont.sans(10.5))
                                .foregroundStyle(option.selected ? Color(hex: 0xC6CEE8) : Color(hex: 0x7F8A85))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Text(option.coefficient)
                                .font(NoopHTMLFont.outfit(16))
                                .monospacedDigit()
                                .foregroundStyle(option.selected ? NoopHTMLColor.ink : NoopHTMLColor.copy)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(option.selected ? NoopHTMLColor.night.opacity(0.18) : Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 13))
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(option.selected ? NoopHTMLColor.night.opacity(0.40) : Color.white.opacity(0.06), lineWidth: 0.5))
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                }
            }

            Text(model.shiftRead)
                .font(NoopHTMLFont.sans(11.5))
                .foregroundStyle(Color(hex: 0x7F8A85))
                .lineSpacing(3.3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))
    }
}

private struct NoopInstrumentCompareSlotButton: View {
    let tag: String
    let signal: NoopInstrumentSignal
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(tag)
                    .font(NoopHTMLFont.sans(11, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x0B0E1A))
                    .frame(width: 22, height: 22)
                    .background(color, in: RoundedRectangle(cornerRadius: 7))
                VStack(alignment: .leading, spacing: 2) {
                    Text(signal.name)
                        .font(NoopHTMLFont.sans(13))
                        .foregroundStyle(NoopHTMLColor.ink)
                        .lineLimit(1)
                    Text(signal.behavior ? "days a week" : signal.unit)
                        .font(NoopHTMLFont.sans(10.5))
                        .foregroundStyle(Color(hex: 0x7F8A85))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 13)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.07), lineWidth: 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(NoopHTMLPressStyle())
    }
}

private struct NoopInstrumentComparisonChart: View {
    let model: NoopInstrumentComparisonModel

    var body: some View { chartBody.noopChartZoom() }

    @ViewBuilder private var chartBody: some View {
        Canvas { context, size in
            let xOffset = max(0, (size.width - 300) / 2)
            func point(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x + xOffset, y: p.y) }
            func draw(_ points: [CGPoint?], color: Color, dash: [CGFloat]) {
                var path = Path()
                var previousWasMeasured = false
                for item in points {
                    guard let item else {
                        previousWasMeasured = false
                        continue
                    }
                    if previousWasMeasured {
                        path.addLine(to: point(item))
                    } else {
                        path.move(to: point(item))
                    }
                    previousWasMeasured = true
                }
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: dash))
                if let last = points.compactMap({ $0 }).last {
                    let center = point(last)
                    context.fill(Path(ellipseIn: CGRect(x: center.x - 3.4, y: center.y - 3.4, width: 6.8, height: 6.8)), with: .color(color))
                }
            }
            draw(model.firstLine, color: NoopHTMLColor.night, dash: [])
            draw(model.secondLine, color: NoopHTMLColor.green, dash: [5, 4])
        }
        .frame(maxWidth: .infinity)
        .frame(height: 130)
        .accessibilityHidden(true)
    }
}

enum NoopInstrumentSignalSlot {
    case first
    case second
}

struct NoopInstrumentSignalPickerSheet: View {
    @ObservedObject var navigation: NoopNavigation
    let slot: NoopInstrumentSignalSlot

    @AppStorage("noop.schedule.kind") private var scheduleKind = "mostly-nights"
    private var data: NoopInstrumentData {
        NoopInstrumentData.prototype.adjustedForSchedule(
            isNightWorker: NoopScheduleInference.isNightWorker(kind: scheduleKind)
        )
    }
    private var selectedKey: String {
        slot == .first ? navigation.instrumentCompareAKey : navigation.instrumentCompareBKey
    }

    var body: some View {
        GeometryReader { proxy in
            let viewportWidth = min(proxy.size.width, UIScreen.main.bounds.width)
            ZStack(alignment: .bottom) {
                NoopBackdropBlur(style: .regular, intensity: 0.18)
                Color(hex: 0x040605, alpha: 0.66)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: navigation.dismissOverlay)

                VStack(spacing: 0) {
                    VStack(spacing: 11) {
                        NoopSheetGrabber()

                        HStack(alignment: .bottom, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(slot == .first ? "First signal" : "Second signal")
                                    .font(NoopHTMLFont.sheetTitle)
                                    .tracking(-0.525)
                                    .foregroundStyle(NoopHTMLColor.ink)
                                Text("Any signal Noop keeps, including the things you log")
                                    .font(NoopHTMLFont.sans(11.5))
                                    .foregroundStyle(Color(hex: 0x7F8A85))
                            }
                            Spacer(minLength: 0)
                            Button(action: navigation.dismissOverlay) {
                                NoopCanonicalGlyph(name: .x, size: 14, color: NoopHTMLColor.inkSoft)
                                    .frame(width: 32, height: 32)
                                    .background(Color.white.opacity(0.07), in: Circle())
                            }
                            .buttonStyle(NoopHTMLPressStyle())
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 10)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(data.signals.enumerated()), id: \.element.id) { index, signal in
                                if index > 0 {
                                    Divider().overlay(Color.white.opacity(0.055)).frame(height: 0.5)
                                }
                                Button {
                                    if slot == .first {
                                        navigation.instrumentCompareAKey = signal.key
                                    } else {
                                        navigation.instrumentCompareBKey = signal.key
                                    }
                                    navigation.dismissOverlay()
                                } label: {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(signal.name)
                                                .font(NoopHTMLFont.sans(13.5, weight: signal.key == selectedKey ? .semibold : .regular))
                                                .foregroundStyle(signal.key == selectedKey ? Color(hex: 0xC6CEE8) : NoopHTMLColor.ink)
                                            Text(signal.group == .logged ? "what you log" : "\(signal.group.rawValue.lowercased()) · \(signal.unit)")
                                                .font(NoopHTMLFont.sans(10.5))
                                                .foregroundStyle(Color(hex: 0x7F8A85))
                                                .lineLimit(1)
                                        }
                                        Spacer(minLength: 0)
                                        if signal.key == selectedKey {
                                            Circle()
                                                .fill(NoopHTMLColor.night)
                                                .frame(width: 9, height: 9)
                                                .shadow(color: NoopHTMLColor.night.opacity(0.6), radius: 5)
                                        } else {
                                            Circle()
                                                .stroke(Color.white.opacity(0.16), lineWidth: 1.2)
                                                .frame(width: 9, height: 9)
                                        }
                                    }
                                    .frame(minHeight: 54)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(NoopHTMLPressStyle())
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 28)
                    }
                    .scrollIndicators(.hidden)
                }
                .frame(width: viewportWidth)
                .frame(maxHeight: proxy.size.height * 0.76)
                .background(NoopHTMLColor.card, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
                .overlay(alignment: .top) {
                    UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                        .stroke(NoopHTMLColor.borderStrong, lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.6), radius: 22, y: -14)
                .noopDragToDismiss(navigation.dismissOverlay)
            }
            .frame(width: viewportWidth, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

private struct NoopInstrumentEffectsScreen: View {
    @ObservedObject var navigation: NoopNavigation
    @Binding var range: NoopInstrumentRange
    let data: NoopInstrumentData

    @State private var selectedBehaviorKey: String?

    init(navigation: NoopNavigation, range: Binding<NoopInstrumentRange>, data: NoopInstrumentData) {
        self.navigation = navigation
        self._range = range
        self.data = data
        _selectedBehaviorKey = State(initialValue: nil)
    }

    private var model: NoopInstrumentEffectsModel {
        data.effects(
            range: range,
            selectedKey: selectedBehaviorKey,
            mode: NoopInstrumentEffectsMode.debugRequested,
            doseMode: NoopInstrumentDoseMode.debugRequested
        )
    }

    var body: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 0) {
                NoopInstrumentBackHeader(label: "All signals") {
                    navigation.back(or: .instrumentIndex)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(NoopRoute.instrumentEffects.screenTitle)
                        .font(NoopHTMLFont.outfit(25))
                        .tracking(-0.625)
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text(model.intro)
                        .font(NoopHTMLFont.sans(13.5))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .lineSpacing(4.2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 11) {
                    // The final HTML intentionally omits the nights-count line on this route.
                    NoopInstrumentRangeTabs(range: $range, availableDays: data.historyCount)

                    switch model.state {
                    case .ranked:
                        rankedCard
                    case .learning:
                        learningCard
                    case .nothing:
                        nothingCard
                    }

                    withWithoutCard
                    // The prototype's −6% deep-sleep alcohol prior has no published source in
                    // this app. Never present it as a measured or literature-backed Release fact.
                    if data.isPrototype { doseCard }

                    Text("Every line on this screen is an association in your own days, written by the engine that found it. None of them is a claim that one thing caused another.")
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .lineSpacing(3.9)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 2)
                }
                .padding(.top, 14)
            }
        }
    }

    private var rankedCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(model.rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 {
                    Divider().overlay(Color.white.opacity(0.055)).frame(height: 0.5)
                }
                Button {
                    selectedBehaviorKey = row.key
                } label: {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(row.name)
                                .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                                .foregroundStyle(NoopHTMLColor.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            Text(row.effect)
                                .font(NoopHTMLFont.outfit(19))
                                .monospacedDigit()
                                .foregroundStyle(row.positive ? Color(hex: 0x8FEFC0) : Color(hex: 0xB7C0E8))
                        }

                        HStack(spacing: 0) {
                            ForEach(NoopInstrumentLag.allCases) { lag in
                                NoopInstrumentLagMarker(lag: lag, selectedLag: row.lag)
                                    .frame(maxWidth: .infinity)
                            }
                        }

                        Text(row.read)
                            .font(NoopHTMLFont.sans(11.5))
                            .foregroundStyle(Color(hex: 0x7F8A85))
                            .lineSpacing(3.1)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 15)
                    .contentShape(Rectangle())
                }
                .buttonStyle(NoopHTMLPressStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private var learningCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Still learning")
                .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                .foregroundStyle(NoopHTMLColor.ink)
            Text("A behaviour needs five days with it and five without before Noop will rank it. These are the ones that are short, and which side is short — because “log a few days without it” is something you can act on, and “not enough data” is not.")
                .font(NoopHTMLFont.sans(12.5))
                .foregroundStyle(Color(hex: 0xC9D0EE))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(model.learningLines, id: \.self) { line in
                    HStack(alignment: .top, spacing: 9) {
                        Circle()
                            .fill(NoopHTMLColor.night)
                            .frame(width: 5, height: 5)
                            .padding(.top, 6)
                        Text(line)
                            .font(NoopHTMLFont.sans(12))
                            .foregroundStyle(Color(hex: 0xC9D0EE))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding(17)
        .background(NoopHTMLColor.night.opacity(0.08), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.night.opacity(0.22), lineWidth: 0.5))
    }

    private var nothingCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Nothing here clears the bar")
                .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                .foregroundStyle(NoopHTMLColor.ink)
            Text("Six behaviours, \(model.eligibleCount) of them with enough days on both sides, and not one of them moves your readiness by more than the day-to-day wobble. That is a real answer, and a slightly uncomfortable one: at this window, what you are doing is not what is deciding your mornings.")
                .font(NoopHTMLFont.sans(12.5))
                .foregroundStyle(NoopHTMLColor.copy)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            if let detail = model.nothingDetail {
                Text(detail)
                    .font(NoopHTMLFont.sans(12))
                    .foregroundStyle(Color(hex: 0x7F8A85))
                    .lineSpacing(3.6)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(17)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
    }

    private var withWithoutCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("WITH AND WITHOUT")
                    .font(NoopHTMLFont.sans(10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(NoopHTMLColor.muted)
                Spacer()
                Text(model.pair.name)
                    .font(NoopHTMLFont.sans(10.5))
                    .foregroundStyle(NoopHTMLColor.faint)
            }

            if model.pair.ready {
                VStack(spacing: 13) {
                    NoopInstrumentMeanRow(label: "With it", value: model.pair.withValue, days: model.pair.withDays, spread: model.pair.withSpread, marker: model.pair.withMarker, color: NoopHTMLColor.warm)
                    NoopInstrumentMeanRow(label: "Without it", value: model.pair.withoutValue, days: model.pair.withoutDays, spread: model.pair.withoutSpread, marker: model.pair.withoutMarker, color: NoopHTMLColor.green)
                }

                Text(model.pair.read)
                    .font(NoopHTMLFont.sans(12.5))
                    .foregroundStyle(NoopHTMLColor.inkSoft)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                Text(model.pair.overlap)
                    .font(NoopHTMLFont.sans(11.5))
                    .foregroundStyle(Color(hex: 0x7F8A85))
                    .lineSpacing(3.3)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(model.pair.thinRead)
                    .font(NoopHTMLFont.sans(12.5))
                    .foregroundStyle(Color(hex: 0xC9D0EE))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private var doseCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("WHAT ONE MORE COSTS")
                    .font(NoopHTMLFont.sans(10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(NoopHTMLColor.muted)
                Spacer()
                Text(model.dose.state.uppercased())
                    .font(NoopHTMLFont.sans(10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(model.dose.chipInk)
                    .padding(.horizontal, 8)
                    .frame(minHeight: 22)
                    .background(model.dose.chipFill, in: RoundedRectangle(cornerRadius: 6))
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(model.dose.number)
                    .font(NoopHTMLFont.outfit(34, weight: .thin))
                    .tracking(-1.02)
                    .monospacedDigit()
                    .foregroundStyle(model.dose.hue)
                Text("% deep sleep, per drink")
                    .font(NoopHTMLFont.sans(12))
                    .foregroundStyle(Color(hex: 0x8B958F))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07))
                    Capsule().fill(NoopHTMLColor.night).frame(width: proxy.size.width * model.dose.ownership)
                }
            }
            .frame(height: 5)

            Text(model.dose.read)
                .font(NoopHTMLFont.sans(12))
                .foregroundStyle(NoopHTMLColor.copy)
                .lineSpacing(3.2)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 7) {
                ForEach(model.dose.steps) { step in
                    HStack(spacing: 10) {
                        Text(step.label)
                            .font(NoopHTMLFont.sans(11.5))
                            .foregroundStyle(Color(hex: 0x7F8A85))
                            .frame(width: 52, alignment: .leading)
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.06))
                                Capsule()
                                    .fill(model.dose.hue)
                                    .opacity(model.dose.ownership)
                                    .frame(width: proxy.size.width * step.fraction)
                            }
                        }
                        .frame(height: 6)
                        Text(step.value)
                            .font(NoopHTMLFont.sans(11.5))
                            .monospacedDigit()
                            .foregroundStyle(model.dose.hue)
                            .frame(width: 52, alignment: .trailing)
                    }
                }
            }
            .padding(.top, 2)

            Text("Colour is ownership: grey while the figure is borrowed from the literature, the screen’s hue once enough of your own nights sit behind it. It never shows a borrowed number as though it were measured.")
                .font(NoopHTMLFont.sans(11.5))
                .foregroundStyle(NoopHTMLColor.faint)
                .lineSpacing(3.3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))
    }
}

private struct NoopInstrumentLagMarker: View {
    let lag: NoopInstrumentLag
    let selectedLag: Int

    var body: some View {
        VStack(spacing: 5) {
            if lag.rawValue == selectedLag {
                Circle()
                    .fill(NoopHTMLColor.night)
                    .frame(width: 9, height: 9)
                    .shadow(color: NoopHTMLColor.night.opacity(0.6), radius: 5)
            } else {
                Circle()
                    .stroke(Color.white.opacity(lag.rawValue < selectedLag ? 0.22 : 0.13), lineWidth: 1.2)
                    .frame(width: 7, height: 7)
                    .frame(height: 9)
            }
            Text(lag.effectLabel.uppercased())
                .font(NoopHTMLFont.sans(9.5, weight: .semibold))
                .tracking(0.57)
                .foregroundStyle(lag.rawValue == selectedLag ? Color(hex: 0xB7C0E8) : NoopHTMLColor.faint)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }
}

private struct NoopInstrumentMeanRow: View {
    let label: String
    let value: String
    let days: String
    let spread: ClosedRange<CGFloat>
    let marker: CGFloat
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(label)
                    .font(NoopHTMLFont.sans(12.5))
                    .foregroundStyle(NoopHTMLColor.inkSoft)
                Spacer()
                Text(value)
                    .font(NoopHTMLFont.outfit(20))
                    .monospacedDigit()
                    .foregroundStyle(NoopHTMLColor.ink)
                Text(days)
                    .font(NoopHTMLFont.sans(11))
                    .foregroundStyle(NoopHTMLColor.muted)
            }
            GeometryReader { proxy in
                let left = proxy.size.width * spread.lowerBound
                let width = proxy.size.width * max(0.02, spread.upperBound - spread.lowerBound)
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06))
                    Capsule()
                        .fill(color.opacity(0.28))
                        .frame(width: width)
                        .offset(x: left)
                    Capsule()
                        .fill(color)
                        .frame(width: 2.5, height: 14)
                        .offset(x: proxy.size.width * marker - 1.25)
                }
            }
            .frame(height: 8)
        }
    }
}

private enum NoopInstrumentRange: String, CaseIterable, Identifiable {
    case overview = "overview"
    case thirty = "30"
    case ninety = "90"
    case halfYear = "180"
    case year = "365"
    case all = "All"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .overview: "Trends period"
        case .thirty: "30D"
        case .ninety: "3M"
        case .halfYear: "6M"
        case .year: "1Y"
        case .all: "All"
        }
    }
    var requestedDayCount: Int? {
        switch self {
        case .thirty: 30
        case .ninety: 90
        case .halfYear: 180
        case .year: 365
        case .all, .overview: nil
        }
    }

    func dayCount(total: Int) -> Int {
        min(requestedDayCount ?? total, total)
    }

    func isAvailable(total: Int) -> Bool {
        guard let requestedDayCount else { return true }
        return requestedDayCount <= total
    }
}

private enum NoopInstrumentGroup: String, CaseIterable, Identifiable {
    case night = "Night"
    case day = "Day"
    case effort = "Effort"
    case body = "Body"
    case logged = "Logged"

    var id: String { rawValue }
    var heading: String { self == .logged ? "What you log" : rawValue }
}

private enum NoopInstrumentGroupFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case night = "Night"
    case day = "Day"
    case effort = "Effort"
    case body = "Body"
    case logged = "Logged"

    var id: String { rawValue }
    var group: NoopInstrumentGroup? { NoopInstrumentGroup(rawValue: rawValue) }
}

private struct NoopInstrumentSignal: Identifiable {
    let key: String
    let name: String
    let group: NoopInstrumentGroup
    let unit: String
    let decimals: Int
    let better: Int
    let threshold: Double
    var hours = false
    var big = false
    var behavior = false

    var id: String { key }
}

private enum NoopInstrumentChangeStyle {
    case thin, flat, neutral, good, bad

    var stroke: Color {
        switch self {
        case .thin: Color(hex: 0x4A5450)
        case .flat: Color(hex: 0x7F8A85)
        case .neutral: NoopHTMLColor.night
        case .good: NoopHTMLColor.green
        case .bad: NoopHTMLColor.warm
        }
    }

    var chipInk: Color {
        switch self {
        case .thin: Color(hex: 0x7F8A85)
        case .flat: NoopHTMLColor.inkSoft
        case .neutral: Color(hex: 0xC6CEE8)
        case .good: Color(hex: 0x8FEFC0)
        case .bad: Color(hex: 0xF3C888)
        }
    }

    var chipFill: Color {
        switch self {
        case .thin: Color.white.opacity(0.05)
        case .flat: Color.white.opacity(0.06)
        case .neutral: NoopHTMLColor.night.opacity(0.16)
        case .good: NoopHTMLColor.green.opacity(0.13)
        case .bad: NoopHTMLColor.warm.opacity(0.13)
        }
    }
}

private struct NoopInstrumentSnapshot: Identifiable {
    let signal: NoopInstrumentSignal
    let value: String
    let unit: String
    let delta: String
    let style: NoopInstrumentChangeStyle
    let points: [CGPoint?]

    var id: String { signal.key }
}

private struct NoopInstrumentAssessment: Equatable {
    let day: String
    let value: Double
    let label: String
    let outside: Bool
    let personalRange: ClosedRange<Double>?
    var rangeCaption = "Personal range"
}

private struct NoopInstrumentReading: Identifiable, Equatable {
    let date: Date
    let value: String
    var source: String? = nil
    var id: Date { date }
}

private struct NoopInstrumentMove: Identifiable {
    let signal: NoopInstrumentSignal
    let coefficient: String
    let lag: Int
    let lagLabel: String
    let barFraction: CGFloat
    let read: String

    var id: String { signal.key }
}

private struct NoopInstrumentMetricModel {
    let signal: NoopInstrumentSignal
    let value: String
    let unit: String
    let read: String
    let worn: Int
    let span: String
    let delta: String
    let style: NoopInstrumentChangeStyle
    let thin: Bool
    let thinNote: String
    let chartNote: String
    let axis: [String]
    let moves: [NoopInstrumentMove]
    let readings: [NoopInstrumentReading]
    let average: String
    let plot: AuraHistoryPresentation
    let comparison: AuraHistoryComparison?
    let trendAnalysis: AuraHistoryTrendAnalysis?
    let assessment: NoopInstrumentAssessment?
}

private struct NoopInstrumentShiftOption: Identifiable {
    let lag: Int
    let label: String
    let coefficient: String
    let selected: Bool
    var id: Int { lag }
}

private struct NoopInstrumentComparisonModel {
    let first: NoopInstrumentSignal
    let second: NoopInstrumentSignal
    let worn: Int
    /// Nil preserves a missing observation as a visible gap, never an invented point.
    let firstLine: [CGPoint?]
    let secondLine: [CGPoint?]
    let axis: [String]
    let secondLegend: String
    let fitCount: Int
    let fitCoefficient: String
    let clears: Bool
    let fitRead: String
    let shifts: [NoopInstrumentShiftOption]
    let bestLabel: String
    let shiftRead: String
}

private enum NoopInstrumentLag: Int, CaseIterable, Identifiable {
    case same = 0
    case next = 1
    case twoDays = 2

    var id: Int { rawValue }
    var effectLabel: String {
        switch self {
        case .same: "Same day"
        case .next: "Next morning"
        case .twoDays: "Two days"
        }
    }
}

private enum NoopInstrumentEffectsMode: String {
    case ranked, learning, nothing

    static var debugRequested: Self {
        #if DEBUG
        let arguments = CommandLine.arguments
        if let flag = arguments.firstIndex(of: "--noop-instrument-effects"),
           arguments.indices.contains(flag + 1),
           let value = Self(rawValue: arguments[flag + 1]) {
            return value
        }
        #endif
        return .ranked
    }
}

private enum NoopInstrumentDoseMode: String {
    case auto, borrowed, blending, yours, disagrees

    static var debugRequested: Self {
        #if DEBUG
        let arguments = CommandLine.arguments
        if let flag = arguments.firstIndex(of: "--noop-instrument-dose"),
           arguments.indices.contains(flag + 1),
           let value = Self(rawValue: arguments[flag + 1]) {
            return value
        }
        #endif
        return .auto
    }
}

private enum NoopInstrumentEffectsState {
    case ranked, learning, nothing
}

private struct NoopInstrumentEffectRow: Identifiable {
    let key: String
    let name: String
    let effect: String
    let positive: Bool
    let lag: Int
    let read: String
    var id: String { key }
}

private struct NoopInstrumentPairModel {
    let name: String
    let ready: Bool
    let withValue: String
    let withDays: String
    let withSpread: ClosedRange<CGFloat>
    let withMarker: CGFloat
    let withoutValue: String
    let withoutDays: String
    let withoutSpread: ClosedRange<CGFloat>
    let withoutMarker: CGFloat
    let read: String
    let overlap: String
    let thinRead: String
}

private struct NoopInstrumentDoseStep: Identifiable {
    let label: String
    let fraction: CGFloat
    let value: String
    var id: String { label }
}

private struct NoopInstrumentDoseModel {
    let state: String
    let number: String
    let ownership: CGFloat
    let hue: Color
    let chipInk: Color
    let chipFill: Color
    let read: String
    let steps: [NoopInstrumentDoseStep]
}

private struct NoopInstrumentEffectsModel {
    let state: NoopInstrumentEffectsState
    let intro: String
    let rows: [NoopInstrumentEffectRow]
    let learningLines: [String]
    let eligibleCount: Int
    let nothingDetail: String?
    let pair: NoopInstrumentPairModel
    let dose: NoopInstrumentDoseModel
}

private struct NoopInstrumentCorrelation {
    let coefficient: Double
    let count: Int
    let lag: Int
}

private struct NoopInstrumentGroupStats {
    let withMean: Double
    let withoutMean: Double
    let withCount: Int
    let withoutCount: Int
    let withDeviation: Double
    let withoutDeviation: Double
}

private struct NoopInstrumentBehavior {
    let key: String
    let name: String
    let onPhrase: String
}

private struct NoopInstrumentRankedBehavior {
    let behavior: NoopInstrumentBehavior
    let difference: Double
    let lag: Int
    let stats: NoopInstrumentGroupStats?
    let percent: Double
}

struct NoopInstrumentData {
    static let prototype = NoopInstrumentData()
    static func title(for key: String) -> String? { prototype.signal(key: key)?.name }
    static let empty = NoopInstrumentData(dayKeys: [], values: [:], drinkDoses: [])
    private static let count = 258

    fileprivate let signals: [NoopInstrumentSignal]
    let historyCount: Int
    private let values: [String: [Double?]]
    private let contextValues: [String: [Double?]]
    private let contextDates: [Date?]
    private let sourceNames: [String: [String: String]]
    let hadReadFailure: Bool
    private let assessments: [String: NoopInstrumentAssessment]
    private let drinkDoses: [Double?]
    private let dayKeys: [String]
    fileprivate let historyDates: [Date?]
    fileprivate let isPrototype: Bool

    init() {
        let gaps = Set([3, 17, 34, 52, 61, 79, 96, 112, 130, 151, 177, 203].map { Self.count - 1 - $0 })
        var regularity: [Double] = []
        var drink: [Double] = []
        var drinks: [Double] = []
        var caffeine: [Double] = []
        var late: [Double] = []
        var screen: [Double] = []
        var walk: [Double] = []
        var hard: [Double] = []
        var load: [Double] = []

        for index in 0..<Self.count {
            let progress = Double(index) / Double(Self.count - 1)
            let reg = max(0.05, min(1, 0.33 + 0.53 * max(0, (progress - 0.22) / 0.78) + (Self.hash(index) - 0.5) * 0.16))
            regularity.append(reg)
            let hadDrink = Self.hash(index + 11) > 0.74 ? 1.0 : 0.0
            drink.append(hadDrink)
            let drinksHash = Self.hash(index + 12)
            drinks.append(hadDrink > 0 ? (drinksHash > 0.72 ? 3 : drinksHash > 0.42 ? 2 : 1) : 0)
            caffeine.append(Self.hash(index + 21) > 0.6 ? 1 : 0)
            late.append(Self.hash(index + 31) > 0.78 ? 1 : 0)
            screen.append(Self.hash(index + 41) > 0.72 - 0.24 * reg ? 1 : 0)
            walk.append(Self.hash(index + 51) > 0.44 ? 1 : 0)
            hard.append(Self.hash(index + 61) > 0.85 ? 1 : 0)
            load.append(hard[index] > 0 ? 68 + Self.hash(index + 62) * 42 : (Self.hash(index + 63) > 0.44 ? 16 + Self.hash(index + 64) * 32 : 0))
        }

        func previous(_ array: [Double], _ index: Int) -> Double { array[max(0, index - 1)] }
        func make(first: Int = 0, _ value: (Int) -> Double) -> [Double?] {
            (0..<Self.count).map { index in
                gaps.contains(index) || index < first ? nil : value(index)
            }
        }

        var generated: [String: [Double?]] = [:]
        generated["sleep"] = make { 6.34 + 1.18 * regularity[$0] - 0.44 * previous(drink, $0) - 0.24 * previous(late, $0) - 0.3 * previous(screen, $0) + (Self.hash($0 + 70) - 0.5) * 0.52 }
        generated["reg"] = make { 64 - 46 * regularity[$0] + (Self.hash($0 + 80) - 0.5) * 15 }
        generated["deep"] = make { 19.4 + 6.3 * regularity[$0] - 2.9 * previous(drinks, $0) - 0.9 * previous(late, $0) + (Self.hash($0 + 90) - 0.5) * 3.3 }
        generated["rem"] = make { 20.2 + 3.5 * regularity[$0] - 1.9 * previous(drink, $0) + (Self.hash($0 + 100) - 0.5) * 3.7 }
        generated["hrv"] = make { 33 + 17.2 * regularity[$0] - 7.2 * previous(drink, $0) - 0.034 * previous(load, $0) + (Self.hash($0 + 110) - 0.5) * 6.6 }
        generated["rhr"] = make { 62.4 - 5.2 * regularity[$0] + 2.4 * previous(drink, $0) + 0.014 * previous(load, $0) + (Self.hash($0 + 120) - 0.5) * 2.1 }
        generated["breath"] = make { 14.6 - 0.56 * regularity[$0] + 0.42 * previous(drink, $0) + (Self.hash($0 + 130) - 0.5) * 0.48 }
        generated["temp"] = make { -0.02 + 0.16 * previous(drink, $0) + (Self.hash($0 + 140) - 0.5) * 0.2 }
        generated["spo2"] = make(first: Self.count - 19) { 96.4 + 0.6 * regularity[$0] - 0.3 * previous(drink, $0) + (Self.hash($0 + 150) - 0.5) * 0.66 }
        generated["recovery"] = make { max(6, min(99, 54 + 31 * regularity[$0] - 15 * previous(drink, $0) - 0.12 * previous(load, $0) + (Self.hash($0 + 160) - 0.5) * 12)) }
        generated["stress"] = make { max(0, 74 - 34 * regularity[$0] + 17 * late[$0] + 0.055 * load[$0] + (Self.hash($0 + 170) - 0.5) * 28) }
        generated["steps"] = make { 4100 + 5600 * walk[$0] + 1800 * regularity[$0] + (Self.hash($0 + 180) - 0.5) * 2300 }
        generated["load"] = make { load[$0] }
        generated["cap"] = make { 40.3 + 3.9 * max(0, (Double($0) / Double(Self.count - 1) - 0.3) / 0.7) + (Self.hash($0 + 190) - 0.5) * 0.5 }
        generated["age"] = make { 38.6 - 4.4 * max(0, (Double($0) / Double(Self.count - 1) - 0.25) / 0.75) + (Self.hash($0 + 200) - 0.5) * 0.4 }
        generated["weight"] = make { 78.4 - 1.8 * max(0, (Double($0) / Double(Self.count - 1) - 0.2) / 0.8) + (Self.hash($0 + 210) - 0.5) * 0.66 }
        generated["b_drink"] = make { drink[$0] }
        generated["b_caff"] = make { caffeine[$0] }
        generated["b_late"] = make { late[$0] }
        generated["b_screen"] = make { screen[$0] }
        generated["b_walk"] = make { walk[$0] }
        generated["b_hard"] = make { hard[$0] }
        values = generated
        contextValues = generated
        sourceNames = [:]
        hadReadFailure = false
        assessments = [:]
        drinkDoses = drinks.map(Optional.some)
        dayKeys = (0..<Self.count).map { "prototype-\($0)" }
        let anchor = Calendar.current.startOfDay(for: Date())
        historyDates = (0..<Self.count).map { Calendar.current.date(byAdding: .day, value: $0 - (Self.count - 1), to: anchor) }
        contextDates = historyDates
        historyCount = Self.count
        isPrototype = true

        signals = [
            .init(key: "rhr", name: "Resting pulse", group: .night, unit: "bpm", decimals: 0, better: -1, threshold: 1.2),
            .init(key: "hrv", name: "Variability", group: .night, unit: "ms", decimals: 0, better: 1, threshold: 3.2),
            .init(key: "sleep", name: "Time asleep", group: .night, unit: "hours", decimals: 1, better: 1, threshold: 0.32, hours: true),
            .init(key: "reg", name: "Bedtime drift", group: .night, unit: "minutes", decimals: 0, better: -1, threshold: 7),
            .init(key: "deep", name: "Deep sleep", group: .night, unit: "% of the night", decimals: 1, better: 1, threshold: 1.4),
            .init(key: "rem", name: "REM", group: .night, unit: "% of the night", decimals: 1, better: 1, threshold: 1.6),
            .init(key: "breath", name: "Breathing rate", group: .night, unit: "breaths a minute", decimals: 1, better: -1, threshold: 0.32),
            .init(key: "temp", name: "Skin temperature", group: .night, unit: "°C from your own", decimals: 2, better: 0, threshold: 0.09),
            .init(key: "spo2", name: "Blood oxygen", group: .night, unit: "%", decimals: 1, better: 1, threshold: 0.4),
            .init(key: "recovery", name: "Readiness", group: .day, unit: "out of 100", decimals: 0, better: 1, threshold: 4),
            .init(key: "stress", name: "Stress minutes", group: .day, unit: "minutes", decimals: 0, better: -1, threshold: 9),
            .init(key: "steps", name: "Steps", group: .day, unit: "a day", decimals: 0, better: 1, threshold: 700, big: true),
            .init(key: "load", name: "Training load", group: .effort, unit: "a day", decimals: 0, better: 0, threshold: 8),
            .init(key: "cap", name: "Capacity", group: .body, unit: "ml/kg/min", decimals: 1, better: 1, threshold: 0.5),
            .init(key: "age", name: "Body age", group: .body, unit: "years", decimals: 1, better: -1, threshold: 0.4),
            .init(key: "weight", name: "Weight", group: .body, unit: "kg", decimals: 1, better: 0, threshold: 0.5),
            .init(key: "b_drink", name: "A drink after \("20:00".noopClock)", group: .logged, unit: "days a week", decimals: 1, better: 0, threshold: 0.4, behavior: true),
            .init(key: "b_caff", name: "Caffeine after \("14:00".noopClock)", group: .logged, unit: "days a week", decimals: 1, better: 0, threshold: 0.4, behavior: true),
            .init(key: "b_late", name: "A late meal", group: .logged, unit: "days a week", decimals: 1, better: 0, threshold: 0.4, behavior: true),
            .init(key: "b_screen", name: "Screen past midnight", group: .logged, unit: "days a week", decimals: 1, better: 0, threshold: 0.4, behavior: true),
            .init(key: "b_walk", name: "A walk over 8k steps", group: .logged, unit: "days a week", decimals: 1, better: 0, threshold: 0.4, behavior: true),
            .init(key: "b_hard", name: "A hard session", group: .logged, unit: "days a week", decimals: 1, better: 0, threshold: 0.3, behavior: true)
        ]
    }

    private init(
        dayKeys: [String],
        values: [String: [Double?]],
        drinkDoses: [Double?],
        signals: [NoopInstrumentSignal]? = nil,
        isPrototype: Bool = false,
        historyDates: [Date?]? = nil,
        contextValues: [String: [Double?]]? = nil,
        contextDates: [Date?]? = nil,
        sourceNames: [String: [String: String]] = [:],
        hadReadFailure: Bool = false,
        assessments: [String: NoopInstrumentAssessment] = [:]
    ) {
        self.signals = signals ?? Self.prototype.signals
        self.dayKeys = dayKeys
        self.historyDates = historyDates ?? dayKeys.map { HistoryDateWindow.date(dayKey: $0) }
        self.contextValues = contextValues ?? values
        self.contextDates = contextDates ?? self.historyDates
        self.sourceNames = sourceNames
        self.hadReadFailure = hadReadFailure
        self.assessments = assessments
        historyCount = dayKeys.count
        self.values = values
        self.drinkDoses = drinkDoses
        self.isPrototype = isPrototype
    }

    fileprivate func adjustedForSchedule(isNightWorker: Bool) -> NoopInstrumentData {
        guard isNightWorker else { return self }
        let renamed = signals.map { signal in
            guard signal.key == "reg" else { return signal }
            return NoopInstrumentSignal(
                key: signal.key,
                name: "Anchor drift",
                group: signal.group,
                unit: signal.unit,
                decimals: signal.decimals,
                better: signal.better,
                threshold: signal.threshold,
                hours: signal.hours,
                big: signal.big,
                behavior: signal.behavior
            )
        }
        return NoopInstrumentData(
            dayKeys: dayKeys,
            values: values,
            drinkDoses: drinkDoses,
            signals: renamed,
            isPrototype: isPrototype,
            historyDates: historyDates, contextValues: contextValues, contextDates: contextDates, sourceNames: sourceNames,
            hadReadFailure: hadReadFailure, assessments: assessments
        )
    }

    fileprivate func between(start: Date, end: Date) -> NoopInstrumentData {
        let calendar = Calendar.current
        guard let window = HistoryDateWindow(endingOn: end, dayCount: nil, firstDay: start, calendar: calendar) else { return .empty }
        let dates = window.calendarDays(calendar: calendar)
        let indexByDay = Dictionary(historyDates.enumerated().compactMap { index, date in
            date.map { (calendar.startOfDay(for: $0), index) }
        }, uniquingKeysWith: { _, last in last })
        func select(_ rows: [Double?]) -> [Double?] {
            dates.map { date in
                guard let index = indexByDay[date], rows.indices.contains(index) else { return nil }
                return rows[index]
            }
        }
        return NoopInstrumentData(dayKeys: dates.map(Repository.localDayKey),
                                  values: values.mapValues(select), drinkDoses: select(drinkDoses),
                                  signals: signals, isPrototype: isPrototype,
                                  historyDates: dates.map(Optional.some), contextValues: contextValues, contextDates: contextDates,
                                  sourceNames: sourceNames, hadReadFailure: hadReadFailure, assessments: assessments)
    }

    fileprivate func ending(on date: Date) -> NoopInstrumentData {
        guard let first = historyDates.compactMap({ $0 }).first,
              let window = HistoryDateWindow(endingOn: date, dayCount: nil, firstDay: first, calendar: .current) else { return .empty }
        let indices = window.indices(in: historyDates)
        func select(_ rows: [Double?]) -> [Double?] { indices.map { rows.indices.contains($0) ? rows[$0] : nil } }
        return NoopInstrumentData(dayKeys: indices.map { dayKeys[$0] },
                                  values: values.mapValues(select), drinkDoses: select(drinkDoses),
                                  signals: signals, isPrototype: isPrototype,
                                  historyDates: indices.map { historyDates[$0] }, contextValues: contextValues, contextDates: contextDates, sourceNames: sourceNames, hadReadFailure: hadReadFailure, assessments: assessments)
    }

    fileprivate func signal(key: String) -> NoopInstrumentSignal? { signals.first { $0.key == key } }

    fileprivate func indexNightCount(for range: NoopInstrumentRange) -> Int {
        let count = range.dayCount(total: historyCount)
        let nightSeries = signals
            .filter { $0.group == .night }
            .map { Array((values[$0.key] ?? []).suffix(count)) }
        guard !nightSeries.isEmpty else { return 0 }
        return (0..<count).reduce(into: 0) { total, index in
            if nightSeries.contains(where: { index < $0.count && $0[index] != nil }) {
                total += 1
            }
        }
    }

    fileprivate func snapshots(group: NoopInstrumentGroup, range: NoopInstrumentRange) -> [NoopInstrumentSnapshot] {
        signals.filter { $0.group == group }.map { snapshot($0, range: range) }
    }

    private func snapshot(_ signal: NoopInstrumentSignal, range: NoopInstrumentRange) -> NoopInstrumentSnapshot {
        let shown = tail(values[signal.key] ?? [], count: range.dayCount(total: historyCount))
        let clean = shown.compactMap { $0 }
        let first = shown.compactMap { $0 }.first
        let last = shown.compactMap { $0 }.last
        let thin = clean.count < 21
        let value: String
        let delta: String
        let style: NoopInstrumentChangeStyle

        if signal.behavior {
            if clean.isEmpty {
                value = "—"
                delta = "no days yet"
                style = .thin
            } else {
                let rate = clean.reduce(0, +) / Double(clean.count) * 7
                value = String(format: "%.1f", rate)
                let half = shown.count / 2
                let early = shown.prefix(half).compactMap { $0 }
                let late = shown.suffix(from: half).compactMap { $0 }
                let earlyRate = early.reduce(0, +) / Double(max(1, early.count))
                let lateRate = late.reduce(0, +) / Double(max(1, late.count))
                let movement = (lateRate - earlyRate) * 7
                let flat = abs(movement) < signal.threshold
                delta = flat ? "about the same" : (movement > 0 ? "+" : "−") + String(format: "%.1f a week", abs(movement))
                style = flat ? .flat : .neutral
            }
        } else {
            value = Self.format(last, signal: signal)
            let movement = (last ?? 0) - (first ?? last ?? 0)
            if clean.count < 2 {
                delta = "\(clean.count) recorded values"
            } else if movement == 0 {
                delta = "unchanged"
            } else {
                let amount: String
                if signal.hours {
                    amount = "\(Int((abs(movement) * 60).rounded())) min"
                } else {
                    amount = Self.format(abs(movement), signal: signal)
                }
                delta = (movement > 0 ? "+" : "−") + amount
            }
            style = thin ? .thin : .neutral
        }

        return NoopInstrumentSnapshot(
            signal: signal,
            value: value,
            unit: signal.hours ? "" : signal.key == "weight" ? UnitFormatter.massUnit(UnitSystem(rawValue: UserDefaults.standard.string(forKey: UnitPrefs.systemKey) ?? "") ?? .metric) : signal.behavior ? "days a week" : signal.unit,
            delta: delta,
            style: style,
            points: Self.sparkPoints(shown, interpolate: isPrototype)
        )
    }

    private func tail(_ values: [Double?], count: Int) -> [Double?] {
        Array(values.suffix(min(count, values.count))).map { $0.flatMap { $0.isFinite ? $0 : nil } }
    }

    private static func hash(_ value: Int) -> Double {
        let raw = sin(Double(value) * 127.1 + 311.7) * 43_758.5453
        return raw - floor(raw)
    }

    static func axisLabel(_ value: Double, key: String) -> String {
        guard let signal = prototype.signal(key: key) else { return value.formatted() }
        return format(value, signal: signal)
    }
    // Axis positions can fall between whole-unit readings. Keep that precision on the grid,
    // while selected readings and records retain the metric's established display precision.
    static func chartTickLabel(_ value: Double, key: String) -> String {
        guard let signal = prototype.signal(key: key) else { return value.formatted() }
        if signal.big || signal.hours || key == "weight" { return format(value, signal: signal) }
        return value.formatted(.number.precision(.fractionLength(0...max(1, signal.decimals))))
    }
    private static func format(_ value: Double?, signal: NoopInstrumentSignal) -> String {
        guard let value, value.isFinite else { return "—" }
        if signal.key == "weight" {
            let system = UnitSystem(rawValue: UserDefaults.standard.string(forKey: UnitPrefs.systemKey) ?? "") ?? .metric
            return decimal(system == .imperial ? UnitFormatter.kgToPounds(value) : value, places: 1)
        }
        if signal.big {
            return integerFormatter.string(from: NSNumber(value: value.rounded())) ?? String(format: "%.0f", value)
        }
        if signal.hours {
            guard value >= 0, value < Double(Int.max / 60) else { return "—" }
            let minutes = Int((value * 60).rounded())
            return "\(minutes / 60)h \(String(format: "%02d", minutes % 60))m"
        }
        return String(format: "%.*f", signal.decimals, value)
    }

    private static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private static func sparkPoints(_ values: [Double?], interpolate: Bool) -> [CGPoint?] {
        let step = values.count > 46 ? Int(ceil(Double(values.count) / 46.0)) : 1
        // Keep every measured day in Release, even at subpixel spacing. Sampling could skip an
        // unmeasured day and falsely join the two adjacent readings in a tiny sparkline.
        let sampled: [Double?] = interpolate
            ? values.enumerated().filter { $0.offset.isMultiple(of: step) }.map(\.element)
            : values
        var chartValues = sampled
        if interpolate {
            var previous: Double?
            for index in chartValues.indices {
                if let value = chartValues[index] {
                    previous = value
                } else {
                    var nextIndex = index
                    while nextIndex < chartValues.count, chartValues[nextIndex] == nil { nextIndex += 1 }
                    let next = nextIndex < chartValues.count ? chartValues[nextIndex] : previous
                    chartValues[index] = previous == nil ? next : next == nil ? previous : ((previous ?? 0) + (next ?? 0)) / 2
                }
            }
        }
        let clean = chartValues.compactMap { $0 }
        guard !clean.isEmpty else { return [] }
        let low = clean.min() ?? 0
        let high = clean.max() ?? low + 1
        let span = high - low == 0 ? 1 : high - low
        return chartValues.enumerated().map { index, value in
            value.map {
                let x = CGFloat(index) / CGFloat(max(1, chartValues.count - 1)) * 86
                let y = 26 - CGFloat(($0 - low) / span) * 20 - 3
                return CGPoint(x: x, y: y)
            }
        }
    }
}

@MainActor
final class NoopInstrumentLiveStore: ObservableObject {
    @Published private(set) var data = NoopInstrumentData.empty
    @Published private(set) var isLoading = false
    @Published private(set) var state: NoopInstrumentLoadState = .waiting

    private var loadedRefreshSequence: Int?
    private var loadedDeviceId: String?
    private var loadingDeviceId: String?
    private var requestId = UUID()

    func data(for deviceId: String) -> NoopInstrumentData { loadingDeviceId == deviceId ? data : .empty }
    func state(for deviceId: String) -> NoopInstrumentLoadState { loadingDeviceId == deviceId ? state : .waiting }

    func load(from repo: Repository, force: Bool = false) async {
        let deviceId = repo.deviceId
        if loadingDeviceId != deviceId {
            requestId = UUID()
            data = .empty
            loadingDeviceId = deviceId
            isLoading = false
        }
        guard repo.loaded else { state = .waiting; return }
        let sequence = repo.refreshSeq
        guard force || loadedDeviceId != deviceId || loadedRefreshSequence != sequence else { return }
        let request = UUID()
        requestId = request
        if loadingDeviceId != deviceId { data = .empty }
        loadingDeviceId = deviceId
        isLoading = true
        state = .loading
        let storeAvailable = await repo.storeHandle() != nil
        guard requestId == request, repo.deviceId == deviceId else { return }
        guard storeAvailable else { state = .unavailable; isLoading = false; return }
        let loaded = await NoopInstrumentData.load(from: repo)
        // A superseded request must not publish another device's history or end its loading state.
        guard requestId == request else { return }
        defer { isLoading = false }
        guard !Task.isCancelled, repo.deviceId == deviceId, repo.refreshSeq == sequence else { return }
        if loaded.hadReadFailure {
            if loaded.historyCount > 0 { data = loaded }
            state = data.historyCount > 0 ? .partial : .unavailable
            return
        }
        data = loaded
        state = loaded.historyCount > 0 ? .ready : .empty
        loadedDeviceId = deviceId
        loadedRefreshSequence = sequence
    }
}

@MainActor
private extension NoopInstrumentData {
    static func load(from repo: Repository) async -> NoopInstrumentData {
        typealias DaySeries = [String: Double]

        var otherSources: [String: [String: String]] = [:]
        var hadReadFailure = false
        func resolved(_ key: String, source: String = Repository.whoopSource) async -> DaySeries {
            let result = await repo.resolvedSeries(
                key: key,
                source: source,
                days: 4_000,
                fullHistory: true
            )
            hadReadFailure = hadReadFailure || result.readFailed
            otherSources[key] = Dictionary(result.points.map { ($0.day, NoopTrendDailyHistory.sourceLabel($0.source)) }, uniquingKeysWith: { _, last in last })
            return Dictionary(result.values.map { ($0.day, $0.value) }, uniquingKeysWith: { _, latest in latest })
        }

        var bySignal: [String: DaySeries] = [:]
        let trendPayload = await NoopTrendDailyHistory.loadWithSources(from: repo)
        let trendDaily = trendPayload.values
        hadReadFailure = hadReadFailure || trendPayload.readFailed
        var sourceNames = trendPayload.sources
        sourceNames["sleep"] = sourceNames["sleep_total_min"]
        bySignal["rhr"] = trendDaily["rhr"]
        bySignal["hrv"] = trendDaily["hrv"]
        bySignal["breath"] = await resolved("resp_rate")
        let skinTemperature = await resolved("skin_temp")
        // The Act 9 signal is explicitly a deviation "from your own". WHOOP CSV imports carry
        // absolute wrist temperature under the same legacy key, so those values stay absent here
        // rather than being mislabeled as deviations.
        bySignal["temp"] = skinTemperature.filter { !VitalBands.isAbsoluteSkinTemp($0.value) }
        bySignal["spo2"] = await resolved("spo2")
        bySignal["recovery"] = await resolved("recovery")
        let strapSteps = await resolved("steps")
        let appleSteps = await resolved("steps", source: Repository.appleHealthSource)
        // The product's default step source is Apple Health, but a measured strap total is still
        // a real signal and fills days Apple does not carry.
        bySignal["steps"] = strapSteps.merging(appleSteps) { _, apple in apple }
        bySignal["load"] = await resolved("strain")
        bySignal["cap"] = trendDaily["cap"]
        bySignal["age"] = await resolved("body_age")
        bySignal["weight"] = await resolved("weight", source: Repository.appleHealthSource)

        let sleepMinutes = trendDaily["sleep_total_min"] ?? [:]
        let deepMinutes = await resolved("sleep_deep_min")
        let remMinutes = await resolved("sleep_rem_min")
        bySignal["sleep"] = sleepMinutes.mapValues { $0 / 60.0 }
        bySignal["deep"] = ratioSeries(part: deepMinutes, total: sleepMinutes)
        bySignal["rem"] = ratioSeries(part: remMinutes, total: sleepMinutes)

        let sleepSessions = await repo.allSleepSessions(days: 4_000)
        bySignal["reg"] = bedtimeDriftSeries(sessions: sleepSessions)

        // The persisted `stress` metric is a 0...3 daily score (or /100 from Xiaomi), while this
        // design asks for measured stress MINUTES. Those quantities are not interchangeable, so the
        // row remains absent until a genuine minutes series exists.

        let journal = await repo.journalEntries(days: 4_000)
        let numericJournal = await repo.numericJournalSeries()

        let behaviorRules: [(key: String, matches: (String) -> Bool)] = [
            ("b_drink", { exactTimeQuestion($0, tokens: ["after 20", "after 8 pm", "after 8pm"]) && alcoholQuestion($0) }),
            ("b_caff", { exactTimeQuestion($0, tokens: ["after 14", "after 2 pm", "after 2pm"]) && caffeineQuestion($0) }),
            ("b_late", { normalized($0).contains("late meal") || normalized($0).contains("eat close to bedtime") }),
            ("b_screen", { normalized($0).contains("screen past midnight") || normalized($0).contains("screen after midnight") }),
            ("b_hard", {
                let value = normalized($0)
                return value.contains("hard session") || value.contains("hard workout") || value.contains("strenuous session")
            })
        ]

        var knownBehaviorDays: [String: Set<String>] = [:]
        var yesBehaviorDays: [String: Set<String>] = [:]
        for rule in behaviorRules {
            let matching = journal.filter { rule.matches($0.question) }
            if !matching.isEmpty {
                knownBehaviorDays[rule.key] = Set(matching.map(\.day))
                yesBehaviorDays[rule.key] = Set(matching.filter(\.answeredYes).map(\.day))
            }
        }

        var allDays = Set(bySignal.values.flatMap(\.keys))
        allDays.formUnion(journal.map(\.day))
        let today = Repository.localDayKey(Date())
        allDays = Set(allDays.filter { $0 <= today && HistoryDateWindow.date(dayKey: $0) != nil })
        if !allDays.isEmpty { allDays.insert(today) }
        let dayKeys = continuousDays(from: allDays)
        guard !dayKeys.isEmpty else { return .init(dayKeys: [], values: [:], drinkDoses: [], hadReadFailure: hadReadFailure) }

        var aligned: [String: [Double?]] = [:]
        for signal in Self.prototype.signals {
            let series = bySignal[signal.key] ?? [:]
            aligned[signal.key] = dayKeys.map { series[$0] }
        }

        for rule in behaviorRules {
            guard let knownDays = knownBehaviorDays[rule.key] else { continue }
            let yesDays = yesBehaviorDays[rule.key] ?? []
            aligned[rule.key] = dayKeys.map { day in
                guard knownDays.contains(day) else { return nil }
                return yesDays.contains(day) ? 1.0 : 0.0
            }
        }

        if let steps = bySignal["steps"], !steps.isEmpty {
            aligned["b_walk"] = dayKeys.map { day in
                steps[day].map { $0 >= 8_000 ? 1.0 : 0.0 }
            }
        }

        // Dose is genuinely "per drink", so a numeric alcohol item is usable even when the
        // journal wording does not establish the Act 9 ranking row's stricter after-20:00 claim.
        var alcoholDoseByDay: [String: Double] = [:]
        for (question, series) in numericJournal where alcoholQuestion(question) {
            for (day, dose) in series { alcoholDoseByDay[day] = max(alcoholDoseByDay[day] ?? 0, dose) }
        }
        for entry in journal where entry.answeredYes && alcoholQuestion(entry.question) {
            if alcoholDoseByDay[entry.day] == nil { alcoholDoseByDay[entry.day] = 1 }
        }
        let knownAlcoholDays = Set(journal.lazy.filter { alcoholQuestion($0.question) }.map(\.day))
        let doses: [Double?] = dayKeys.map { day in
            guard knownAlcoholDays.contains(day) else { return nil }
            return alcoholDoseByDay[day] ?? 0
        }

        for (key, sourceKey) in [("breath", "resp_rate"), ("spo2", "spo2"), ("recovery", "recovery"), ("weight", "weight"), ("age", "body_age"), ("temp", "skin_temp")] {
            sourceNames[key] = otherSources[sourceKey]
        }
        var assessments: [String: NoopInstrumentAssessment] = [:]
        let readings = BodyVitalSigns.readings(sourceRows: repo.vitalMetricRows, temperatureUnit: .celsius)
        for reading in readings {
            guard let day = reading.day, let value = reading.value, value.isFinite,
                  reading.caveat == nil, reading.banding.band != .noData else { continue }
            let key = reading.key == "resp" ? "breath" : reading.key
            let range: ClosedRange<Double>?
            if reading.banding.basis == .personal, let personal = reading.personal, personal.trusted {
                let width = Baselines.sigma(personal) * VitalBands.sigmaK
                range = (personal.baseline - width)...(personal.baseline + width)
            } else { range = nil }
            assessments[key] = .init(day: day, value: value,
                                     label: reading.banding.basis == .personal
                                        ? (reading.banding.band == .outOfRange ? "Off personal range" : "Within personal range")
                                        : (reading.banding.band == .outOfRange ? "Outside typical range" : "Within typical range"),
                                     outside: reading.banding.band == .outOfRange, personalRange: range)
        }
        return NoopInstrumentData(dayKeys: dayKeys, values: aligned, drinkDoses: doses, sourceNames: sourceNames, hadReadFailure: hadReadFailure, assessments: assessments)
    }

    static func ratioSeries(part: [String: Double], total: [String: Double]) -> [String: Double] {
        var result: [String: Double] = [:]
        for (day, partValue) in part {
            guard let totalValue = total[day], totalValue > 0 else { continue }
            result[day] = partValue / totalValue * 100
        }
        return result
    }

    static func bedtimeDriftSeries(sessions: [CachedSleepSession]) -> [String: Double] {
        let calendar = Calendar.current
        var longestByWakeDay: [String: CachedSleepSession] = [:]
        for session in sessions where session.endTs > session.effectiveStartTs {
            let wakeDay = dayKey(for: session.endTs, calendar: calendar)
            let duration = session.endTs - session.effectiveStartTs
            if let current = longestByWakeDay[wakeDay], current.endTs - current.effectiveStartTs >= duration {
                continue
            }
            longestByWakeDay[wakeDay] = session
        }

        let starts: [(day: String, minute: Double)] = longestByWakeDay.map { day, session in
            let date = Date(timeIntervalSince1970: TimeInterval(session.effectiveStartTs))
            let components = calendar.dateComponents([.hour, .minute, .second], from: date)
            let minute = Double((components.hour ?? 0) * 60 + (components.minute ?? 0))
                + Double(components.second ?? 0) / 60
            return (day, minute)
        }
        guard !starts.isEmpty else { return [:] }

        let turn = 2 * Double.pi
        let sine = starts.reduce(0.0) { $0 + sin($1.minute / 1_440 * turn) }
        let cosine = starts.reduce(0.0) { $0 + cos($1.minute / 1_440 * turn) }
        var angle = atan2(sine, cosine)
        if angle < 0 { angle += turn }
        let anchorMinute = angle / turn * 1_440

        return Dictionary(uniqueKeysWithValues: starts.map { item in
            let direct = abs(item.minute - anchorMinute)
            return (item.day, min(direct, 1_440 - direct))
        })
    }

    static func continuousDays(from rawDays: Set<String>) -> [String] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let parsed = rawDays.compactMap { day -> Date? in
            let parts = day.split(separator: "-")
            guard parts.count == 3,
                  let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else { return nil }
            return calendar.date(from: DateComponents(year: year, month: month, day: day))
        }
        guard let first = parsed.min() else { return [] }
        let last = min(parsed.max() ?? Date(), calendar.startOfDay(for: Date()))
        guard first <= last else { return [] }

        var result: [String] = []
        var cursor = first
        while cursor <= last {
            let components = calendar.dateComponents([.year, .month, .day], from: cursor)
            if let year = components.year, let month = components.month, let day = components.day {
                result.append(String(format: "%04d-%02d-%02d", year, month, day))
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor), next > cursor else { break }
            cursor = next
        }
        return result
    }

    static func dayKey(for timestamp: Int, calendar: Calendar) -> String {
        let components = calendar.dateComponents(
            [.year, .month, .day],
            from: Date(timeIntervalSince1970: TimeInterval(timestamp))
        )
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .replacingOccurrences(of: ":", with: "")
    }

    static func exactTimeQuestion(_ value: String, tokens: [String]) -> Bool {
        let value = normalized(value)
        return tokens.contains { value.contains($0.replacingOccurrences(of: ":", with: "")) }
    }

    static func alcoholQuestion(_ value: String) -> Bool {
        let value = normalized(value)
        return value.contains("alcohol") || value.contains("drink")
    }

    static func caffeineQuestion(_ value: String) -> Bool {
        normalized(value).contains("caffeine")
    }
}

private extension NoopInstrumentData {
    func axisLabels(for range: NoopInstrumentRange) -> [String] {
        let dates = Array(historyDates.suffix(range.dayCount(total: historyCount)))
        guard !dates.isEmpty else { return ["", "", "", ""] }
        let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate("d MMM")
        return [0, dates.count / 3, dates.count * 2 / 3, dates.count - 1].map { i in
            dates[i].map { f.string(from: $0) } ?? ""
        }
    }

    static let lagWords = ["same night", "next morning", "two days on"]

    static let behaviors: [NoopInstrumentBehavior] = [
        .init(key: "b_drink", name: "A drink after \("20:00".noopClock)", onPhrase: "on the evenings you had one"),
        .init(key: "b_caff", name: "Caffeine after \("14:00".noopClock)", onPhrase: "on the days you had some"),
        .init(key: "b_hard", name: "A hard session", onPhrase: "on the days you went hard"),
        .init(key: "b_late", name: "A late meal", onPhrase: "on the nights you ate late"),
        .init(key: "b_screen", name: "Screen past midnight", onPhrase: "on the nights you were up late on a screen"),
        .init(key: "b_walk", name: "A walk over 8k steps", onPhrase: "on the days you walked")
    ]

    func metric(key: String, range: NoopInstrumentRange, windowStart: Date? = nil) -> NoopInstrumentMetricModel {
        let metricSignal = signal(key: key) ?? signals.first(where: { $0.key == "hrv" })!
        let raw = tail(values[metricSignal.key] ?? [], count: range.dayCount(total: historyCount))
        let series = metricSignal.behavior ? tail(trailingWeeklyRate(values[metricSignal.key] ?? []), count: raw.count) : raw
        let clean = series.compactMap { $0 }
        let ends = firstAndLast(series)
        let thin = clean.count < 21
        let change = (ends.last ?? 0) - (ends.first ?? ends.last ?? 0)
        let read: String = {
            guard !clean.isEmpty else { return "No recorded value falls inside this window." }
            if thin { return "\(clean.count) recorded values in this period." }
            return "First recorded value \(Self.format(ends.first, signal: metricSignal)); latest \(Self.format(ends.last, signal: metricSignal)). Direction alone is not a health assessment."
        }()

        let displayChange = metricSignal.key == "weight" && UnitFormatter.massUnit(UnitSystem(rawValue: UserDefaults.standard.string(forKey: UnitPrefs.systemKey) ?? "") ?? .metric) == "lb"
            ? UnitFormatter.kgToPounds(change) : change
        let deltaAmount = metricSignal.hours
            ? "\(Int((abs(change) * 60).rounded())) min"
            : Self.decimal(abs(displayChange), places: metricSignal.decimals)
        let delta = clean.count < 2 ? "\(clean.count) values" : change == 0 ? "unchanged" : Self.signed(change, amount: deltaAmount)

        let plotDates = Array(historyDates.suffix(raw.count))
        let dated = DatedChartSeries(samples: series.enumerated().compactMap { index, value in
            guard plotDates.indices.contains(index), let date = plotDates[index] else { return nil }
            return .init(date: date, value: value)
        })
        let full = DatedChartSeries(samples: (contextValues[metricSignal.key] ?? []).enumerated().compactMap { index, value in
            guard contextDates.indices.contains(index), let date = contextDates[index] else { return nil }
            return .init(date: date, value: value)
        })
        let assessment = assessments[metricSignal.key].flatMap { item -> NoopInstrumentAssessment? in
            guard let last = dated.points.last,
                  let day = HistoryDateWindow.date(dayKey: item.day),
                  Calendar.current.isDate(day, inSameDayAs: last.date), abs(last.value - item.value) < 0.000001 else { return nil }
            return item
        }
        let plot = AuraHistoryPresentation(series: dated, context: full,
                                           showVariability: !metricSignal.behavior && metricSignal.key != "weight")
        let comparison = (!metricSignal.behavior && range != .all)
            ? plotDates.last.flatMap { $0 }.flatMap { end in
                HistoryDateWindow(endingOn: end, dayCount: range.requestedDayCount, firstDay: windowStart ?? end, calendar: .current)
                    .flatMap { AuraHistoryComparison(series: full, start: windowStart ?? $0.start, end: end) }
            } : nil

        let moves = signals
            .filter { $0.key != metricSignal.key }
            .map { other -> (NoopInstrumentSignal, NoopInstrumentCorrelation) in
                let result = bestLag(
                    first: tail(values[other.key] ?? [], count: range.dayCount(total: historyCount)),
                    second: raw
                )
                return (other, result)
            }
            .filter { $0.1.count >= 21 && abs($0.1.coefficient) >= 0.22 }
            .sorted { abs($0.1.coefficient) > abs($1.1.coefficient) }
            .prefix(4)
            .map { other, result in
                let positive = result.coefficient > 0
                let lagDescription = Self.lagWords[result.lag]
                let relation: String
                if other.behavior {
                    let day = result.lag == 0 ? "same day" : result.lag == 1 ? "morning after" : "second day after"
                    relation = "On the \(day) \(other.name.lowercased()), your \(metricSignal.name.lowercased()) runs \(positive ? "higher" : "lower") than on days without it."
                } else {
                    relation = "A higher \(other.name.lowercased()) comes with a \(positive ? "higher" : "lower") \(metricSignal.name.lowercased()), strongest \(lagDescription)."
                }
                return NoopInstrumentMove(
                    signal: other,
                    coefficient: Self.signed(result.coefficient, amount: Self.decimal(abs(result.coefficient), places: 2)),
                    lag: result.lag,
                    lagLabel: lagDescription,
                    barFraction: CGFloat(min(1, abs(result.coefficient) / 0.8)),
                    read: relation
                )
            }

        return NoopInstrumentMetricModel(
            signal: metricSignal,
            value: Self.format(ends.last, signal: metricSignal),
            unit: metricSignal.hours ? "" : metricSignal.key == "weight" ? UnitFormatter.massUnit(UnitSystem(rawValue: UserDefaults.standard.string(forKey: UnitPrefs.systemKey) ?? "") ?? .metric) : metricSignal.behavior ? "days a week" : metricSignal.unit,
            read: read,
            worn: clean.count,
            span: range == .overview ? "Trends period" : range == .all ? "All \(historyCount) days in window" : "\(range.requestedDayCount ?? historyCount)-day window",
            delta: delta,
            style: thin ? .thin : .neutral,
            thin: thin,
            thinNote: clean.isEmpty
                    ? "No recorded days fall inside this window. Noop keeps the signal on the list and waits for a real measurement instead of filling the gap."
                    : "Only \(clean.count) recorded day\(clean.count == 1 ? "" : "s") \(clean.count == 1 ? "falls" : "fall") inside this window. Relationship analysis needs at least twenty-one paired days. Recorded values remain available.",
            chartNote: metricSignal.key == "weight"
                ? "Daily weight values from the recorded source. Dotted connectors guide the eye between measurements; they do not imply continuous measurement."
                : metricSignal.behavior
                    ? "Seven-day frequency derived from recorded answers. Missing answers remain unknown."
                    : plot.bands.isEmpty
                        ? "Recorded values · not enough recent data for a variability band."
                        : "Shading · 30-day variability, mean ±1 SD. Not a normal range.",
            axis: axisLabels(for: range),
            moves: Array(moves),
            readings: series.enumerated().compactMap { index, value in
                guard let value, plotDates.indices.contains(index), let date = plotDates[index] else { return nil }
                return NoopInstrumentReading(date: date, value: Self.format(value, signal: metricSignal),
                                             source: isPrototype ? "Demo fixture" : sourceNames[metricSignal.key]?[dayKeys.suffix(raw.count).dropFirst(index).first ?? ""])
            },
            average: Self.format(clean.isEmpty ? nil : clean.reduce(0) { $0 + $1 / Double(clean.count) }, signal: metricSignal),
            plot: plot, comparison: comparison,
            // Changes are read from the whole recorded history up to the window's last day, so a 30-day
            // window can still answer "30-day" and "90-day" (it could not when confined to the window).
            trendAnalysis: !metricSignal.behavior && metricSignal.group != .body
                ? AuraHistoryTrendAnalysis(series: .init(samples: full.samples.filter { sample in
                    dated.points.last.map { sample.date <= $0.date } ?? false })) : nil,
            assessment: assessment ?? Self.observedRange(full, through: dated.points.last?.date, decimals: metricSignal.decimals)
        )
    }

    func comparison(firstKey: String, secondKey: String, shift: Int, range: NoopInstrumentRange) -> NoopInstrumentComparisonModel {
        let first = signal(key: firstKey) ?? signals.first(where: { $0.key == "hrv" })!
        let second = signal(key: secondKey) ?? signals.first(where: { $0.key == "reg" })!
        let safeShift = min(2, max(0, shift))
        let window = range.dayCount(total: historyCount)
        let firstRaw = tail(values[first.key] ?? [], count: window)
        let secondRaw = tail(values[second.key] ?? [], count: window)
        let firstSampled = isPrototype
            ? sampledInterpolated(firstRaw, maximum: 60).map(Optional.some)
            : sampledMeasured(firstRaw, maximum: 60)
        let secondSampled = isPrototype
            ? sampledInterpolated(secondRaw, maximum: 60).map(Optional.some)
            : sampledMeasured(secondRaw, maximum: 60)
        let firstScale = chartScale(values: firstSampled.compactMap { $0 }, count: firstSampled.count,
                                    width: 300, height: 130, padding: 10)
        let secondScale = chartScale(values: secondSampled.compactMap { $0 }, count: secondSampled.count,
                                     width: 300, height: 130, padding: 10)
        let firstLine = firstSampled.enumerated().map { index, value in value.map { firstScale.point(value: $0, index: index) } }
        let secondLine = secondSampled.enumerated().map { index, value in value.map { secondScale.point(value: $0, index: index) } }
        let fit = correlation(first: firstRaw, second: secondRaw, lag: safeShift)
        let clears = abs(fit.coefficient) >= 0.28 && fit.count >= 21
        let strength = abs(fit.coefficient) >= 0.6
            ? "They move together."
            : abs(fit.coefficient) >= 0.4
                ? "They move together, loosely."
                : abs(fit.coefficient) >= 0.28 ? "A weak relationship." : "No relationship worth drawing."
        let shiftPhrase = safeShift == 0 ? "" : ", with \(second.name.lowercased()) read \(safeShift) day\(safeShift > 1 ? "s" : "") later"
        let fitRead = clears
            ? "\(strength) \(first.name) and \(second.name.lowercased())\(shiftPhrase). That is a tendency across \(fit.count) nights, not a rule about any one of them."
            : "At this length and this shift the two do not track each other closely enough to draw a line through. Noop leaves it off rather than drawing something faint and letting you read meaning into it."

        let options = (0...2).map { lag -> NoopInstrumentShiftOption in
            let result = correlation(first: firstRaw, second: secondRaw, lag: lag)
            return .init(
                lag: lag,
                label: lag == 0 ? "same day" : lag == 1 ? "+1 day" : "+2 days",
                coefficient: !isPrototype && result.count == 0
                    ? "—" : Self.signed(result.coefficient, amount: Self.decimal(abs(result.coefficient), places: 2)),
                selected: lag == safeShift
            )
        }
        let best = (0...2)
            .map { correlation(first: firstRaw, second: secondRaw, lag: $0) }
            .max { abs($0.coefficient) < abs($1.coefficient) } ?? .init(coefficient: 0, count: 0, lag: 0)
        let bestName = best.lag == 0 ? "same day" : "+\(best.lag) day\(best.lag > 1 ? "s" : "")"
        let shiftRead: String
        if !isPrototype && best.count == 0 {
            shiftRead = "No paired readings are available for this window yet. A day shift cannot be compared."
        } else if isPrototype {
            shiftRead = best.lag == 0
                ? "Shifting does not improve it: whatever these two share, they share it on the same day."
                : "Reading \(second.name.lowercased()) \(best.lag) day\(best.lag > 1 ? "s" : "") later fits better than reading them together — the effect arrives after the day it was caused on, which is exactly what the lag treatment on the effects screen is for."
        } else {
            shiftRead = best.lag == 0
                ? "The strongest observed association is on the same day. This does not establish cause."
                : "The observed association is strongest when \(second.name.lowercased()) is read \(best.lag) day\(best.lag > 1 ? "s" : "") later. Timing alone does not establish cause."
        }

        return NoopInstrumentComparisonModel(
            first: first,
            second: second,
            worn: fit.count,
            firstLine: firstLine,
            secondLine: secondLine,
            axis: axisLabels(for: range),
            secondLegend: second.name + (safeShift == 0 ? "" : " · shifted \(safeShift) day\(safeShift > 1 ? "s" : "")"),
            fitCount: fit.count,
            fitCoefficient: !isPrototype && fit.count == 0
                ? "—" : Self.signed(fit.coefficient, amount: Self.decimal(abs(fit.coefficient), places: 2)),
            clears: clears,
            fitRead: fitRead,
            shifts: options,
            bestLabel: !isPrototype && best.count == 0 ? "no paired readings" : "strongest observed at \(bestName)",
            shiftRead: shiftRead
        )
    }

    func effects(
        range: NoopInstrumentRange,
        selectedKey: String?,
        mode: NoopInstrumentEffectsMode,
        doseMode: NoopInstrumentDoseMode
    ) -> NoopInstrumentEffectsModel {
        let window = range.dayCount(total: historyCount)
        let target = tail(values["recovery"] ?? [], count: window)
        let targetValues = target.compactMap { $0 }
        let targetMean = targetValues.reduce(0, +) / Double(max(1, targetValues.count))
        let ranked: [NoopInstrumentRankedBehavior]
        if isPrototype {
            ranked = Self.behaviors.map { behavior -> NoopInstrumentRankedBehavior in
                let behaviorValues = tail(values[behavior.key] ?? [], count: window)
                var bestDifference = 0.0
                var bestLag = 0
                var bestStats: NoopInstrumentGroupStats?
                for lag in 0...2 {
                    let stats = groupStats(behavior: behaviorValues, target: target, lag: lag)
                    guard stats.withCount >= 5, stats.withoutCount >= 5 else { continue }
                    let difference = stats.withMean - stats.withoutMean
                    if abs(difference) > abs(bestDifference) {
                        bestDifference = difference
                        bestLag = lag
                        bestStats = stats
                    }
                }
                return .init(
                    behavior: behavior,
                    difference: bestDifference,
                    lag: bestLag,
                    stats: bestStats,
                    percent: targetMean == 0 ? 0 : bestDifference / targetMean * 100
                )
            }
        } else {
            let keys = Array(dayKeys.suffix(window))
            let outcomeByDay = Dictionary(uniqueKeysWithValues: zip(keys, target).compactMap { day, value in
                value.map { (day, $0) }
            })
            var behaviorResponses: [String: [String: Bool]] = [:]
            for behavior in Self.behaviors {
                let behaviorValues = tail(values[behavior.key] ?? [], count: window)
                behaviorResponses[behavior.key] = Dictionary(
                    uniqueKeysWithValues: zip(keys, behaviorValues).compactMap { day, value in
                        value.map { (day, $0 > 0) }
                    }
                )
            }
            let engineRows = EffectRanker.rank(
                responses: behaviorResponses,
                outcomeByDay: outcomeByDay,
                outcome: "Readiness"
            )
            let rowsByKey = Dictionary(uniqueKeysWithValues: engineRows.map { ($0.behavior, $0) })
            ranked = Self.behaviors.map { behavior in
                guard let result = rowsByKey[behavior.key] else {
                    return .init(behavior: behavior, difference: 0, lag: 0, stats: nil, percent: 0)
                }
                let behaviorValues = tail(values[behavior.key] ?? [], count: window)
                let stats = groupStats(behavior: behaviorValues, target: target, lag: result.lag)
                let difference = result.effect.delta
                return .init(
                    behavior: behavior,
                    difference: difference,
                    lag: result.lag,
                    stats: stats,
                    percent: targetMean == 0 ? 0 : difference / targetMean * 100
                )
            }
        }
        let eligible = ranked.filter { $0.stats != nil }
        let cleared = eligible
            .filter { abs($0.percent) >= 3.5 }
            .sorted { abs($0.percent) > abs($1.percent) }
        let short = ranked.filter { $0.stats == nil }

        let state: NoopInstrumentEffectsState = {
            switch mode {
            case .learning: return .learning
            case .nothing: return .nothing
            case .ranked:
                if !cleared.isEmpty { return .ranked }
                return short.count > 2 ? .learning : .nothing
            }
        }()
        let intro: String = {
            switch state {
            case .nothing:
                return isPrototype
                    ? "Six behaviours against your readiness, at three lags each. This window has an answer you may not enjoy."
                    : "No logged behaviour clears the association threshold in this window. That is also a result."
            case .learning:
                if isPrototype {
                    return "Six behaviours against your readiness. Two of them do not have enough days on both sides yet, and it says which side is short."
                }
                return "Six behaviours against your readiness. \(short.count) of them do not have enough days on both sides yet, and it says which side is short."
            case .ranked:
                return isPrototype
                    ? "Six behaviours against your readiness, at the lag where the effect actually lands — not the day you did the thing."
                    : "Logged behaviours compared with readiness on the same day and up to two days later. These are associations, not causal effects."
            }
        }()

        let rows = cleared.map { item in
            let stats = item.stats!
            let amount = Int(abs(item.percent).rounded())
            return NoopInstrumentEffectRow(
                key: item.behavior.key,
                name: item.behavior.name,
                effect: "\(item.percent > 0 ? "+" : "−")\(amount)%",
                positive: item.percent > 0,
                lag: item.lag,
                read: "Readiness runs \(amount)% \(item.percent > 0 ? "higher" : "lower") \(Self.lagWords[item.lag]), across \(stats.withCount) days with and \(stats.withoutCount) without."
            )
        }

        let learningSource: [(behavior: NoopInstrumentBehavior, stats: NoopInstrumentGroupStats)] = {
            if !short.isEmpty {
                var thinRows: [(behavior: NoopInstrumentBehavior, stats: NoopInstrumentGroupStats)] = []
                for item in short {
                    let behaviorValues = tail(values[item.behavior.key] ?? [], count: window)
                    let stats = groupStats(behavior: behaviorValues, target: target, lag: 1)
                    thinRows.append((behavior: item.behavior, stats: stats))
                }
                return thinRows
            }

            var candidates: [(behavior: NoopInstrumentBehavior, stats: NoopInstrumentGroupStats)] = []
            for behavior in Self.behaviors {
                let behaviorValues = tail(values[behavior.key] ?? [], count: window)
                let stats = groupStats(behavior: behaviorValues, target: target, lag: 1)
                candidates.append((behavior: behavior, stats: stats))
            }
            candidates.sort {
                let leftCount = min($0.stats.withCount, $0.stats.withoutCount)
                let rightCount = min($1.stats.withCount, $1.stats.withoutCount)
                return leftCount < rightCount
            }
            return Array(candidates.prefix(2))
        }()
        let learningLines = learningSource.map { item -> String in
            let stats = item.stats
            let thinWith = stats.withCount <= stats.withoutCount
            let rawMissing = 5 - (thinWith ? stats.withCount : stats.withoutCount)
            let missing = isPrototype ? max(1, rawMissing) : max(0, rawMissing)
            let action = thinWith
                ? "Log \(missing) more day\(missing > 1 ? "s" : "") with it."
                : "Give it \(missing) more day\(missing > 1 ? "s" : "") off."
            return "\(item.behavior.name) — \(stats.withCount) days with it, \(stats.withoutCount) without. \(action)"
        }

        let selected = selectedKey.flatMap { key in ranked.first { $0.behavior.key == key } }
            ?? cleared.first
            ?? ranked.first { $0.behavior.key == "b_drink" }!
        let pairStats = selected.stats ?? groupStats(
            behavior: tail(values[selected.behavior.key] ?? [], count: window),
            target: target,
            lag: 1
        )
        let pair = pairModel(behavior: selected.behavior, rank: selected, stats: pairStats)

        return NoopInstrumentEffectsModel(
            state: state,
            intro: intro,
            rows: rows,
            learningLines: learningLines,
            eligibleCount: eligible.count,
            nothingDetail: isPrototype
                ? "Sleep regularity is doing the work instead. It is on Rhythm, and it is not a behaviour you log — it is one you keep."
                : nil,
            pair: pair,
            dose: doseModel(range: range, forced: doseMode)
        )
    }

    func pairModel(
        behavior: NoopInstrumentBehavior,
        rank: NoopInstrumentRankedBehavior,
        stats: NoopInstrumentGroupStats
    ) -> NoopInstrumentPairModel {
        let low = min(stats.withMean - stats.withDeviation, stats.withoutMean - stats.withoutDeviation) - 3
        let high = max(stats.withMean + stats.withDeviation, stats.withoutMean + stats.withoutDeviation) + 3
        let span = high - low == 0 ? 1 : high - low
        func fraction(_ value: Double) -> CGFloat { CGFloat((value - low) / span) }
        let withSpread = fraction(stats.withMean - stats.withDeviation)...fraction(stats.withMean + stats.withDeviation)
        let withoutSpread = fraction(stats.withoutMean - stats.withoutDeviation)...fraction(stats.withoutMean + stats.withoutDeviation)
        let difference = stats.withMean - stats.withoutMean
        let lag = rank.stats == nil ? 1 : rank.lag
        let read = abs(difference) < 3
            ? "No real difference. \(stats.withCount) days with and \(stats.withoutCount) without, and the two averages sit inside each other’s ordinary spread."
            : "Readiness averages \(Int(abs(difference).rounded())) points \(difference > 0 ? "higher" : "lower") \(Self.lagWords[lag]) \(behavior.onPhrase)."
        let overlapLow = max(stats.withMean - stats.withDeviation, stats.withoutMean - stats.withoutDeviation)
        let overlapHigh = min(stats.withMean + stats.withDeviation, stats.withoutMean + stats.withoutDeviation)
        let overlap = overlapHigh > overlapLow
            ? "The shaded spans overlap between \(Int(overlapLow.rounded())) and \(Int(overlapHigh.rounded())), which is why this is a tendency and not a rule. Plenty of individual days go the other way."
            : "The two spans do not overlap at all across this window, which is as clean as an association in one person’s data gets."
        let thin = "Only \(stats.withCount) days with it and \(stats.withoutCount) without in this window. Noop needs five on each side before it will put two averages next to each other."
        return .init(
            name: behavior.name,
            ready: stats.withCount >= 5 && stats.withoutCount >= 5,
            withValue: "\(Int(stats.withMean.rounded()))",
            withDays: "\(stats.withCount) days",
            withSpread: withSpread,
            withMarker: fraction(stats.withMean),
            withoutValue: "\(Int(stats.withoutMean.rounded()))",
            withoutDays: "\(stats.withoutCount) days",
            withoutSpread: withoutSpread,
            withoutMarker: fraction(stats.withoutMean),
            read: read,
            overlap: overlap,
            thinRead: thin
        )
    }

    func doseModel(range: NoopInstrumentRange, forced: NoopInstrumentDoseMode) -> NoopInstrumentDoseModel {
        let window = range.dayCount(total: historyCount)
        let deep = tail(values["deep"] ?? [], count: window)
        let doses = Array(drinkDoses.suffix(min(window, drinkDoses.count)))
        var doseNights = 0
        for index in deep.indices where index > 0 && index - 1 < doses.count {
            if deep[index] != nil, let dose = doses[index - 1], dose > 0 {
                doseNights += 1
            }
        }

        var sumX = 0.0, sumY = 0.0, sumXX = 0.0, sumXY = 0.0
        var count = 0
        if deep.count > 1 {
            for index in 1..<deep.count {
                guard let y = deep[index], index - 1 < doses.count, let x = doses[index - 1] else { continue }
                count += 1
                sumX += x
                sumY += y
                sumXX += x * x
                sumXY += x * y
            }
        }
        let denominator = Double(count) * sumXX - sumX * sumX
        let handoffPersonal = count > 2
            ? (Double(count) * sumXY - sumX * sumY) / (denominator == 0 ? 1 : denominator)
            : 0
        let enginePairs: [(Double, Double)] = deep.indices.compactMap { index in
            guard index > 0, index - 1 < doses.count,
                  let dose = doses[index - 1], let value = deep[index] else { return nil }
            return (dose, value)
        }
        let personal = isPrototype
            ? handoffPersonal
            : (CorrelationEngine.pearson(enginePairs)?.slope ?? 0)
        let published = -6.0
        let weight = Double(doseNights) / Double(doseNights + 18)
        let blended = published * (1 - weight) + personal * weight
        let disagrees = doseNights >= 40 && abs(personal - published) > 3
        let state: NoopInstrumentDoseMode = forced == .auto
            ? (doseNights < 8 ? .borrowed : disagrees ? .disagrees : doseNights < 40 ? .blending : .yours)
            : forced
        let shown = state == .borrowed ? published : (state == .yours || state == .disagrees ? personal : blended)
        let ownership: CGFloat = state == .borrowed ? 0.06 : state == .blending ? 0.48 : state == .disagrees ? 0.88 : 1
        let hue = state == .borrowed ? NoopHTMLColor.inkSoft : state == .blending ? Color(hex: 0xAFB9E2) : NoopHTMLColor.night
        let read: String
        switch state {
        case .borrowed:
            read = "Published figure. \(doseNights) of your nights so far — not you yet."
        case .blending, .auto:
            read = "\(doseNights) of your nights. Half yours, and moving — watch it across weeks, not visits."
        case .yours:
            read = "\(doseNights) of your nights behind it. This is your own number now, not the literature’s."
        case .disagrees:
            read = "\(doseNights) nights, and yours point \(abs(personal) < abs(published) ? "gentler" : "harder") than the literature’s −6. Both are shown; neither is hidden."
        }
        let chipInk = state == .borrowed ? NoopHTMLColor.copy : state == .disagrees ? Color(hex: 0xE9C48A) : Color(hex: 0xB7C0E8)
        let chipFill = state == .borrowed ? Color.white.opacity(0.06) : state == .disagrees ? NoopHTMLColor.warm.opacity(0.14) : NoopHTMLColor.night.opacity(0.14)
        let labels = ["One", "Two", "Three"]
        let steps = (1...3).map { multiplier -> NoopInstrumentDoseStep in
            let value = shown * Double(multiplier)
            return .init(
                label: labels[multiplier - 1],
                fraction: CGFloat(min(1, abs(value) / 20)),
                value: Self.signed(value, amount: Self.decimal(abs(value), places: 1))
            )
        }
        return .init(
            state: state.rawValue.prefix(1).uppercased() + state.rawValue.dropFirst(),
            number: Self.signed(shown, amount: Self.decimal(abs(shown), places: 1)),
            ownership: ownership,
            hue: hue,
            chipInk: chipInk,
            chipFill: chipFill,
            read: read,
            steps: steps
        )
    }

    func trailingWeeklyRate(_ values: [Double?]) -> [Double?] {
        values.indices.map { index in
            let lower = max(0, index - 6)
            let window = values[lower...index].compactMap { $0 }
            return window.isEmpty ? nil : window.reduce(0, +) / Double(window.count) * 7
        }
    }

    func firstAndLast(_ values: [Double?]) -> (first: Double?, last: Double?) {
        (values.compactMap { $0 }.first, values.compactMap { $0 }.last)
    }

    func sampledInterpolated(_ values: [Double?], maximum: Int) -> [Double] {
        let step = values.count > maximum ? Int(ceil(Double(values.count) / Double(maximum))) : 1
        let sampled = values.enumerated().filter { $0.offset.isMultiple(of: step) }.map(\.element)
        var result = sampled
        var previous: Double?
        for index in result.indices {
            if let value = result[index] {
                previous = value
                continue
            }
            var nextIndex = index
            while nextIndex < result.count, result[nextIndex] == nil { nextIndex += 1 }
            let next = nextIndex < result.count ? result[nextIndex] : previous
            result[index] = previous == nil ? next : next == nil ? previous : ((previous ?? 0) + (next ?? 0)) / 2
        }
        return result.compactMap { $0 }
    }

    /// Keep missing observations missing in the real record; the prototype alone uses a filled line.
    func sampledMeasured(_ values: [Double?], maximum _: Int) -> [Double?] {
        // Canvas can draw the full year. Decimating this series could skip a missing day and
        // connect two measured days across an unmarked gap.
        values
    }

    struct ChartScale {
        let low: Double
        let span: Double
        let count: Int
        let width: CGFloat
        let height: CGFloat
        let padding: CGFloat

        func point(value: Double, index: Int) -> CGPoint {
            let x = CGFloat(index) / CGFloat(max(1, count - 1)) * width
            let y = height - CGFloat((value - low) / span) * (height - padding * 2) - padding
            return CGPoint(x: x, y: y)
        }
    }

    func chartScale(values: [Double], count: Int? = nil,
                    width: CGFloat, height: CGFloat, padding: CGFloat) -> ChartScale {
        let low = values.min() ?? 0
        let high = values.max() ?? low + 1
        return .init(low: low, span: high == low ? 1 : high - low, count: count ?? values.count,
                     width: width, height: height, padding: padding)
    }

    func regression(values: [Double], scale: ChartScale) -> (start: CGPoint, end: CGPoint)? {
        guard !values.isEmpty else { return nil }
        var sumX = 0.0, sumY = 0.0, sumXX = 0.0, sumXY = 0.0
        for (index, value) in values.enumerated() {
            let x = Double(index)
            sumX += x
            sumY += value
            sumXX += x * x
            sumXY += x * value
        }
        let count = Double(values.count)
        let denominator = count * sumXX - sumX * sumX
        let slope = (count * sumXY - sumX * sumY) / (denominator == 0 ? 1 : denominator)
        let intercept = (sumY - slope * sumX) / count
        return (
            scale.point(value: intercept, index: 0),
            scale.point(value: intercept + slope * Double(values.count - 1), index: values.count - 1)
        )
    }

    func correlation(first: [Double?], second: [Double?], lag: Int) -> NoopInstrumentCorrelation {
        if !isPrototype {
            let count = min(dayKeys.count, min(first.count, second.count))
            guard lag >= 0, count > lag else {
                return .init(coefficient: 0, count: 0, lag: lag)
            }
            let keys = Array(dayKeys.suffix(count))
            let firstValues = Array(first.suffix(count))
            let secondValues = Array(second.suffix(count))
            let firstSeries = zip(keys, firstValues).compactMap { day, value in
                value.map { (day: day, value: $0) }
            }
            let secondSeries = zip(keys, secondValues).compactMap { day, value in
                value.map { (day: day, value: $0) }
            }
            let pairedCount = (0..<(count - lag)).reduce(into: 0) { result, index in
                if firstValues[index] != nil, secondValues[index + lag] != nil { result += 1 }
            }
            let result = CorrelationEngine.lagged(x: firstSeries, y: secondSeries, lagDays: lag)
            return .init(coefficient: result?.r ?? 0, count: result?.n ?? pairedCount, lag: lag)
        }

        var count = 0
        var sumA = 0.0, sumB = 0.0, sumAA = 0.0, sumBB = 0.0, sumAB = 0.0
        guard lag >= 0, first.count > lag else { return .init(coefficient: 0, count: 0, lag: lag) }
        for index in 0..<(first.count - lag) {
            guard let a = first[index], let b = second[index + lag] else { continue }
            count += 1
            sumA += a
            sumB += b
            sumAA += a * a
            sumBB += b * b
            sumAB += a * b
        }
        guard count >= 8 else { return .init(coefficient: 0, count: count, lag: lag) }
        let n = Double(count)
        let covariance = sumAB / n - (sumA / n) * (sumB / n)
        let varianceA = sumAA / n - pow(sumA / n, 2)
        let varianceB = sumBB / n - pow(sumB / n, 2)
        guard varianceA > 0, varianceB > 0 else { return .init(coefficient: 0, count: count, lag: lag) }
        return .init(coefficient: covariance / sqrt(varianceA * varianceB), count: count, lag: lag)
    }

    func bestLag(first: [Double?], second: [Double?]) -> NoopInstrumentCorrelation {
        (0...2)
            .map { correlation(first: first, second: second, lag: $0) }
            .max { abs($0.coefficient) < abs($1.coefficient) }
            ?? .init(coefficient: 0, count: 0, lag: 0)
    }

    func groupStats(behavior: [Double?], target: [Double?], lag: Int) -> NoopInstrumentGroupStats {
        var withValues: [Double] = []
        var withoutValues: [Double] = []
        guard behavior.count > lag else {
            return .init(withMean: 0, withoutMean: 0, withCount: 0, withoutCount: 0, withDeviation: 0, withoutDeviation: 0)
        }
        for index in 0..<(behavior.count - lag) {
            guard let flag = behavior[index], let value = target[index + lag] else { continue }
            if flag > 0 { withValues.append(value) } else { withoutValues.append(value) }
        }
        func mean(_ values: [Double]) -> Double { values.reduce(0, +) / Double(max(1, values.count)) }
        func deviation(_ values: [Double], mean: Double) -> Double {
            guard values.count >= 2 else { return 0 }
            return sqrt(values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count - 1))
        }
        let withMean = mean(withValues)
        let withoutMean = mean(withoutValues)
        return .init(
            withMean: withMean,
            withoutMean: withoutMean,
            withCount: withValues.count,
            withoutCount: withoutValues.count,
            withDeviation: deviation(withValues, mean: withMean),
            withoutDeviation: deviation(withoutValues, mean: withoutMean)
        )
    }

    /// Where the latest value sits against the wearer's own last 30 days, for metrics with no trusted
    /// vital assessment: mean ± 1 SD of at least fourteen recorded days, the band the chart already
    /// shades. Worded as position, never as healthy or poor, and never tints the line amber.
    static func observedRange(_ series: DatedChartSeries, through end: Date?, decimals: Int) -> NoopInstrumentAssessment? {
        let calendar = Calendar.current
        guard let end,
              let latest = series.samples.last(where: { $0.date <= end && $0.value != nil }),
              let value = latest.value, calendar.isDate(latest.date, inSameDayAs: end),
              let start = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: end)) else { return nil }
        let values = series.samples.filter { $0.date >= start && $0.date <= end }.compactMap(\.value)
        guard values.count >= 14 else { return nil }
        let mean = values.reduce(0, +) / Double(values.count)
        let sd = (values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count - 1)).squareRoot()
        guard mean.isFinite, sd.isFinite else { return nil }
        // Rounded to the signal's own precision, so a whole-number pulse reads 54–60, not 54–59.6.
        let scale = pow(10, Double(decimals))
        let range = ((mean - sd) * scale).rounded() / scale...((mean + sd) * scale).rounded() / scale
        let label = value > range.upperBound ? "Above your usual" : value < range.lowerBound ? "Below your usual" : "Within your usual"
        return .init(day: Repository.localDayKey(latest.date), value: value, label: label, outside: false,
                     personalRange: range, rangeCaption: "Last 30 days")
    }

    static func signed(_ value: Double, amount: String) -> String {
        (value > 0 ? "+" : "−") + amount
    }

    static func decimal(_ value: Double, places: Int) -> String {
        String(format: "%.*f", places, value)
    }
}
#endif
