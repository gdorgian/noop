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
                    .frame(width: 110, height: 28)
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
        if offset == 0 { return "TODAY" }
        let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate("EEE MMM d")
        return f.string(from: date).uppercased()
    }

    private func arrow(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            NoopHaptics.play(.tick)
            action()
        } label: {
            Image(systemName: symbol).font(.system(size: 13, weight: .heavy))
                .foregroundStyle(enabled ? NoopHTMLColor.ink : NoopHTMLColor.chevronDim)
                .frame(width: 28, height: 28)
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

    @State private var dragX: CGFloat = 0
    @State private var tracking: Bool?

    func body(content: Content) -> some View {
        content
            .offset(x: dragX)
            .opacity(1 - min(0.6, abs(dragX) / 500))
            .simultaneousGesture(DragGesture(minimumDistance: 14)
                .onChanged { g in
                    if tracking == nil {
                        tracking = abs(g.translation.width) > abs(g.translation.height) * 1.4
                    }
                    guard tracking == true else { return }
                    let next = offset + (g.translation.width > 0 ? 1 : -1)
                    let open = next >= 0 && next <= maxBack
                    dragX = g.translation.width * (open ? 0.9 : 0.22)
                }
                .onEnded { g in
                    defer { tracking = nil }
                    guard tracking == true else { return }
                    let w = g.predictedEndTranslation.width
                    let next = offset + (w > 0 ? 1 : -1)
                    guard abs(w) > 90, next >= 0, next <= maxBack else {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { dragX = 0 }
                        return
                    }
                    let away: CGFloat = w > 0 ? 260 : -260
                    NoopHaptics.play(.tick)
                    withAnimation(.easeIn(duration: 0.13)) { dragX = away } completion: {
                        offset = next
                        dragX = -away
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) { dragX = 0 }
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

    /// Tall enough for a six-week month.
    static let height: CGFloat = 545
    private static let rowHeight: CGFloat = 62

    @Environment(\.dismiss) private var dismiss
    @State private var month: Date = Calendar.current.startOfDay(for: Date())
    @State private var turn: Edge = .trailing

    private var calendar: Calendar { var c = Calendar.current; c.firstWeekday = 2; return c }
    private var today: Date { calendar.startOfDay(for: Date()) }
    private var selected: Date { calendar.date(byAdding: .day, value: -offset, to: today) ?? today }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(title).font(NoopHTMLFont.sans(NoopType.body, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                HStack {
                    Button { dismiss() } label: {
                        NoopIconDiscShape(size: .small) { Image(systemName: "xmark").font(.system(size: 13, weight: .semibold)) }
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                    .accessibilityLabel("Close")
                    Spacer()
                    Button {
                        NoopHaptics.play(.tick)
                        offset = 0
                        dismiss()
                    } label: {
                        Text("Today").font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                            .foregroundStyle(offset == 0 ? NoopHTMLColor.faint : NoopHTMLColor.blueLight)
                            .padding(.horizontal, 14).frame(height: NoopControlSize.small.height)
                            .background(Color.white.opacity(0.06), in: Capsule())
                            .noopHitTarget()
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                    .disabled(offset == 0)
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
                    if let day { cell(day) } else { Color.clear.frame(height: Self.rowHeight) }
                }
            }
            .id(month)
            .transition(.asymmetric(insertion: .move(edge: turn).combined(with: .opacity),
                                    removal: .move(edge: turn == .trailing ? .leading : .trailing).combined(with: .opacity)))
            .frame(maxHeight: .infinity, alignment: .top)
            .clipped()
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
        let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate("MMMM y"); return f.string(from: month)
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
            .frame(maxWidth: .infinity).frame(height: Self.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(NoopHTMLPressStyle())
        .disabled(closed)
        .accessibilityLabel(dayLabel(day, r))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func dayLabel(_ day: Date, _ r: NoopDayRing?) -> String {
        let f = DateFormatter(); f.dateStyle = .full
        return f.string(from: day) + (r.map { ", \(Int(($0.fill * 100).rounded())) percent" } ?? ", no reading")
    }
}
