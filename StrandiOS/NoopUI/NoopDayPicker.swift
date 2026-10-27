import SwiftUI

// MARK: - Day picker
//
// How a score page moves through days, combining two habits: a pill with arrows either side steps a
// day at a time (and a sideways swipe on the page's header does the same), and a tap on the date opens
// a month sheet where every day is a capsule holding that day's ring, so a good or bad stretch can be
// seen before choosing a day.

/// The pill: ‹ date ›, the date on a lighter inner capsule that opens the month sheet. Measured from
/// WHOOP's on a 440 pt screen: 166 × 28 overall, a 110 pt date capsule between two 28 pt arrow cells,
/// the date in 11 pt bold tracked capitals. `offset`
/// counts days back from today; it never goes past today or past `maxBack`. The pill keeps one width
/// whatever the date says, so the arrows never move under the thumb.
struct NoopDayPill: View {
    @Binding var offset: Int
    var maxBack = 365
    let openCalendar: () -> Void

    private var date: Date { Calendar.current.date(byAdding: .day, value: -offset, to: Calendar.current.startOfDay(for: Date())) ?? Date() }

    var body: some View {
        HStack(spacing: 0) {
            arrow("chevron.left", enabled: offset < maxBack) { offset += 1 }
            Button(action: openCalendar) {
                Text(Self.label(date, offset: offset))
                    .font(NoopHTMLFont.sans(11, weight: .bold)).tracking(1.6)
                    .monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .foregroundStyle(NoopHTMLColor.ink)
                    .contentTransition(.numericText(countsDown: offset > 0))
                    .padding(.horizontal, 10)
                    .frame(minWidth: 110, minHeight: 28)
                    .background(Color.white.opacity(0.14), in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(NoopHTMLPressStyle())
            .accessibilityLabel("\(Self.label(date, offset: offset)), open the calendar")
            arrow("chevron.right", enabled: offset > 0) { offset -= 1 }
        }
        .padding(.vertical, 0.5)
        .background(Color.white.opacity(0.05), in: Capsule())
        .animation(.snappy(duration: 0.22), value: offset)
    }

    static func label(_ date: Date, offset: Int) -> String {
        offset == 0 ? "TODAY" : dayFormatter.string(from: date).uppercased()
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate("EEE MMM d"); return f
    }()

    private func arrow(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            NoopHaptics.play(.tick)
            action()
        } label: {
            Image(systemName: symbol).font(.system(size: 13, weight: .heavy))
                .foregroundStyle(enabled ? NoopHTMLColor.ink : NoopHTMLColor.chevronDim)
                .frame(minWidth: 28, minHeight: 28)
                .noopHitTarget()
        }
        .buttonStyle(NoopHTMLPressStyle())
        .disabled(!enabled)
        .accessibilityLabel(symbol == "chevron.left" ? "Previous day" : "Next day")
    }
}

/// A horizontal swipe on a header steps a day: right for the day before, left for the next. The
/// header follows the finger, leaves the way it was pushed, and the new day comes in from the other
/// side; past the first or last day it only stretches and settles back. Put it outside the header's
/// `.id(day)`, so it keeps its place while the header underneath is replaced.
struct NoopDaySwipe: ViewModifier {
    @Binding var offset: Int
    var maxBack = 365

    /// The live drag, which the system clears itself when a drag is cancelled (the scroll view takes
    /// over, the app leaves the screen), so the header can never be left part-way across.
    @GestureState private var drag: (x: CGFloat, horizontal: Bool?) = (0, nil)
    /// Where the header settles from once the finger lifts.
    @State private var settle: CGFloat = 0

    private func reach(_ width: CGFloat) -> CGFloat {
        let next = offset + (width > 0 ? 1 : -1)
        return width * (next >= 0 && next <= maxBack ? 0.9 : 0.22)
    }

    func body(content: Content) -> some View {
        let x = drag.x + settle
        content
            .offset(x: x)
            .opacity(1 - min(0.6, abs(x) / 500))
            .simultaneousGesture(DragGesture(minimumDistance: 14)
                .updating($drag) { g, state, _ in
                    if state.horizontal == nil {
                        state.horizontal = abs(g.translation.width) > abs(g.translation.height) * 1.4
                    }
                    state.x = state.horizontal == true ? reach(g.translation.width) : 0
                }
                .onEnded { g in
                    guard abs(g.translation.width) > abs(g.translation.height) * 1.4 else { return }
                    // The live drag clears in this same update; carry its position over so nothing jumps.
                    settle = reach(g.translation.width)
                    let w = g.predictedEndTranslation.width
                    let next = offset + (w > 0 ? 1 : -1)
                    guard abs(w) > 90, next >= 0, next <= maxBack else {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { settle = 0 }
                        return
                    }
                    let away: CGFloat = w > 0 ? 260 : -260
                    NoopHaptics.play(.tick)
                    withAnimation(.easeIn(duration: 0.13)) { settle = away } completion: {
                        offset = next
                        settle = -away
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) { settle = 0 }
                    }
                })
    }
}

// MARK: Month sheet

/// One day's ring in the month sheet: how full, in which colour; nil for a day with no reading.
typealias NoopDayRing = (fill: Double, color: Color)

/// A month at a time: close, the page's name and Today along the top, the month between its arrows,
/// then each day as its number over its ring. The chosen day's number sits on a white disc, today's
/// is in the accent, and days that cannot be opened keep only a faint number. A sideways swipe on the
/// grid turns the month.
struct NoopDayCalendarSheet: View {
    @Binding var offset: Int
    var maxBack = 365
    let title: String
    /// The ring for a day, or nil.
    let ring: (Date) -> NoopDayRing?

    /// A first guess at the sheet's height; the sheet then sizes itself to the month it shows.
    static let height: CGFloat = 560
    private static let rowHeight: CGFloat = 62
    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate("MMMM y"); return f
    }()
    private static let fullFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .full; return f
    }()

    @Environment(\.dismiss) private var dismiss
    @State private var month: Date = Calendar.current.startOfDay(for: Date())
    @State private var turn: Edge = .trailing

    private var calendar: Calendar { var c = Calendar.current; c.firstWeekday = 2; return c }
    private var today: Date { calendar.startOfDay(for: Date()) }
    private var selected: Date { calendar.date(byAdding: .day, value: -offset, to: today) ?? today }

    var body: some View {
        VStack(spacing: 0) {
            NoopSheetHeader(title: title, close: { dismiss() }) {
                NoopSheetAction(title: "Today", enabled: offset != 0) {
                    NoopHaptics.play(.tick)
                    offset = 0
                    dismiss()
                }
            }
            .padding(.top, 22)

            HStack {
                monthArrow("chevron.left", enabled: canGoBack) { shift(-1) }
                Spacer()
                Text(monthTitle).font(NoopHTMLFont.outfit(NoopType.title3)).foregroundStyle(NoopHTMLColor.ink)
                    .contentTransition(.opacity)
                Spacer()
                monthArrow("chevron.right", enabled: canGoForward) { shift(1) }
            }
            .padding(.top, 18).padding(.bottom, 16)

            HStack(spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, d in
                    Text(d).font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold)).tracking(0.6)
                        .foregroundStyle(NoopHTMLColor.faint).frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 8)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                    if let day { cell(day) } else { Color.clear.frame(minHeight: Self.rowHeight) }
                }
            }
            .id(month)
            .transition(.asymmetric(insertion: .move(edge: turn).combined(with: .opacity),
                                    removal: .move(edge: turn == .trailing ? .leading : .trailing).combined(with: .opacity)))
            .padding(.bottom, 16)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 20).onEnded { g in
                guard abs(g.translation.width) > 50, abs(g.translation.width) > abs(g.translation.height) else { return }
                if g.translation.width < 0, canGoForward { shift(1) }
                if g.translation.width > 0, canGoBack { shift(-1) }
            })
        }
        .padding(.horizontal, 18)
        .onAppear { month = calendar.date(from: calendar.dateComponents([.year, .month], from: selected)) ?? today }
    }

    private var monthTitle: String {
        Self.monthFormatter.string(from: month)
    }

    private var weekdaySymbols: [String] {
        let s = calendar.veryShortWeekdaySymbols
        return Array(s[(calendar.firstWeekday - 1)...] + s[..<(calendar.firstWeekday - 1)])
    }

    /// The month's days, padded at the front so the first falls under its weekday.
    private var cells: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let lead = (calendar.component(.weekday, from: month) - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: lead) + range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: month) }
    }

    private var oldest: Date { calendar.date(byAdding: .day, value: -maxBack, to: today) ?? today }
    private var canGoBack: Bool { month > oldest }
    private var canGoForward: Bool { (calendar.date(byAdding: .month, value: 1, to: month) ?? today) <= today }

    private func shift(_ by: Int) {
        guard let m = calendar.date(byAdding: .month, value: by, to: month) else { return }
        NoopHaptics.play(.tick)
        turn = by > 0 ? .trailing : .leading
        withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) { month = m }
    }

    private func monthArrow(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            NoopIconDiscShape(size: .small) {
                Image(systemName: symbol).font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(enabled ? NoopHTMLColor.ink : NoopHTMLColor.chevronDim)
            }
        }
        .buttonStyle(NoopHTMLPressStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel(symbol == "chevron.left" ? "Previous month" : "Next month")
    }

    @ViewBuilder
    private func cell(_ day: Date) -> some View {
        let closed = day > today || day < oldest
        let isSelected = calendar.isDate(day, inSameDayAs: selected)
        let isToday = calendar.isDate(day, inSameDayAs: today)
        let r = closed ? nil : ring(day)
        Button {
            offset = calendar.dateComponents([.day], from: day, to: today).day ?? 0
            NoopHaptics.play(.pass)
            dismiss()
        } label: {
            VStack(spacing: 5) {
                Text("\(calendar.component(.day, from: day))")
                    .font(NoopHTMLFont.sans(NoopType.footnote, weight: isSelected || isToday ? .bold : .medium)).monospacedDigit()
                    .foregroundStyle(isSelected ? NoopHTMLColor.canvas
                                     : closed ? NoopHTMLColor.faint.opacity(0.6)
                                     : isToday ? NoopHTMLColor.blueLight : NoopHTMLColor.inkSoft)
                    .frame(width: 30, height: 30)
                    .background { if isSelected { Circle().fill(NoopHTMLColor.ink) } }
                ZStack {
                    if !closed {
                        Circle().stroke(Color.white.opacity(0.08), lineWidth: 3.5)
                        if let r {
                            Circle().trim(from: 0, to: max(0.03, min(1, r.fill)))
                                .stroke(r.color, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                        }
                    }
                }
                .frame(width: 22, height: 22)
            }
            .frame(maxWidth: .infinity).frame(minHeight: Self.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(NoopHTMLPressStyle())
        .disabled(closed)
        .accessibilityLabel(dayLabel(day, r))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func dayLabel(_ day: Date, _ r: NoopDayRing?) -> String {
        Self.fullFormatter.string(from: day) + (r.map { ", \(Int(($0.fill * 100).rounded())) percent" } ?? ", no reading")
    }
}
