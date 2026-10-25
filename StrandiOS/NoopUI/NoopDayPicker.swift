import SwiftUI

// MARK: - Day picker
//
// How a score page moves through days, combining two habits: a pill with arrows either side steps a
// day at a time (and a sideways swipe on the page's header does the same), and a tap on the date opens
// a month sheet where every day is a capsule holding that day's ring, so a good or bad stretch can be
// seen before choosing a day.

/// The pill: ‹ date ⌄ ›. `offset` counts days back from today; it never goes past today or past
/// `maxBack`.
struct NoopDayPill: View {
    @Binding var offset: Int
    var maxBack = 365
    let openCalendar: () -> Void

    private var date: Date { Calendar.current.date(byAdding: .day, value: -offset, to: Calendar.current.startOfDay(for: Date())) ?? Date() }

    var body: some View {
        HStack(spacing: 2) {
            arrow("chevron.left", enabled: offset < maxBack) { offset += 1 }
            Button(action: openCalendar) {
                HStack(spacing: 6) {
                    Text(Self.label(date, offset: offset)).font(NoopHTMLFont.sans(NoopType.caption, weight: .bold)).tracking(1.4)
                        .monospacedDigit()
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold)).opacity(0.7)
                }
                .foregroundStyle(NoopHTMLColor.ink)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(Color.white.opacity(0.10), in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(NoopHTMLPressStyle())
            .accessibilityLabel("\(Self.label(date, offset: offset)), open the calendar")
            arrow("chevron.right", enabled: offset > 0) { offset -= 1 }
        }
        .padding(3)
        .background(Color.white.opacity(0.05), in: Capsule())
        .animation(.snappy(duration: 0.2), value: offset)
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
            Image(systemName: symbol).font(.system(size: 13, weight: .bold))
                .foregroundStyle(enabled ? NoopHTMLColor.ink : NoopHTMLColor.chevronDim)
                .frame(width: 34, height: 34)
                .noopHitTarget()
        }
        .buttonStyle(NoopHTMLPressStyle())
        .disabled(!enabled)
        .accessibilityLabel(symbol == "chevron.left" ? "Previous day" : "Next day")
    }
}

/// A horizontal swipe on a header steps a day: left for the next day, right for the one before.
struct NoopDaySwipe: ViewModifier {
    @Binding var offset: Int
    var maxBack = 365

    func body(content: Content) -> some View {
        content.simultaneousGesture(DragGesture(minimumDistance: 24).onEnded { g in
            guard abs(g.translation.width) > 60, abs(g.translation.width) > abs(g.translation.height) * 1.8 else { return }
            let next = offset + (g.translation.width > 0 ? 1 : -1)
            guard next >= 0, next <= maxBack else { return }
            NoopHaptics.play(.tick)
            withAnimation(.snappy(duration: 0.25)) { offset = next }
        })
    }
}

// MARK: Month sheet

/// One day's ring in the month sheet: how full, in which colour; nil for a day with no reading.
typealias NoopDayRing = (fill: Double, color: Color)

struct NoopDayCalendarSheet: View {
    @Binding var offset: Int
    var maxBack = 365
    let title: String
    /// The ring for a day, or nil.
    let ring: (Date) -> NoopDayRing?

    @Environment(\.dismiss) private var dismiss
    @State private var month: Date = Calendar.current.startOfDay(for: Date())

    private var calendar: Calendar { var c = Calendar.current; c.firstWeekday = 2; return c }
    private var today: Date { calendar.startOfDay(for: Date()) }
    private var selected: Date { calendar.date(byAdding: .day, value: -offset, to: today) ?? today }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(monthTitle).font(NoopHTMLFont.outfit(NoopType.title3)).foregroundStyle(NoopHTMLColor.ink)
                Spacer()
                monthArrow("chevron.left", enabled: canGoBack) { shift(-1) }
                monthArrow("chevron.right", enabled: canGoForward) { shift(1) }
            }
            .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 14)
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { d in
                    Text(d).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.muted).frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12).padding(.bottom, 8)
            Divider().overlay(NoopHTMLColor.border)
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 14) {
                    ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                        if let day { cell(day) } else { Color.clear.frame(height: 78) }
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 16)
            }
            HStack {
                Button {
                    offset = 0
                    dismiss()
                } label: {
                    Text("Today").font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).foregroundStyle(NoopHTMLColor.blueLight)
                        .padding(.horizontal, 20).frame(height: 44)
                        .background(Color.white.opacity(0.06), in: Capsule())
                }
                .buttonStyle(NoopHTMLPressStyle())
                Spacer()
                Text(title).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.muted)
            }
            .padding(.horizontal, 20).padding(.bottom, 18).padding(.top, 6)
        }
        .background(NoopHTMLColor.canvas)
        .onAppear { month = calendar.date(from: calendar.dateComponents([.year, .month], from: selected)) ?? today }
    }

    private var monthTitle: String {
        let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate("MMMM y"); return f.string(from: month)
    }

    private var weekdaySymbols: [String] {
        let s = calendar.shortWeekdaySymbols
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
        if let m = calendar.date(byAdding: .month, value: by, to: month) {
            NoopHaptics.play(.tick)
            withAnimation(.snappy(duration: 0.25)) { month = m }
        }
    }

    private func monthArrow(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 14, weight: .semibold))
                .foregroundStyle(enabled ? NoopHTMLColor.ink : NoopHTMLColor.chevronDim)
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(enabled ? 0.07 : 0.02), in: Circle())
        }
        .buttonStyle(NoopHTMLPressStyle())
        .disabled(!enabled)
    }

    @ViewBuilder
    private func cell(_ day: Date) -> some View {
        let future = day > today
        let tooOld = day < oldest
        let isSelected = calendar.isDate(day, inSameDayAs: selected)
        let isToday = calendar.isDate(day, inSameDayAs: today)
        let r = future || tooOld ? nil : ring(day)
        Button {
            offset = calendar.dateComponents([.day], from: day, to: today).day ?? 0
            NoopHaptics.play(.pass)
            dismiss()
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle().stroke(Color.white.opacity(future ? 0.05 : 0.10), lineWidth: 5)
                    if let r {
                        Circle().trim(from: 0, to: max(0.02, min(1, r.fill)))
                            .stroke(r.color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                }
                .frame(width: 28, height: 28)
                Text("\(calendar.component(.day, from: day))")
                    .font(NoopHTMLFont.sans(NoopType.subhead, weight: isSelected ? .bold : .medium)).monospacedDigit()
                    .foregroundStyle(isToday ? NoopHTMLColor.blueLight : future || tooOld ? NoopHTMLColor.faint : NoopHTMLColor.ink)
            }
            .frame(maxWidth: .infinity).frame(height: 78)
            .background(Color.white.opacity(isSelected ? 0.10 : 0.03), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(isSelected ? 0.30 : 0.07), lineWidth: isSelected ? 1 : 0.5))
        }
        .buttonStyle(NoopHTMLPressStyle())
        .disabled(future || tooOld)
        .accessibilityLabel(dayLabel(day, r))
    }

    private func dayLabel(_ day: Date, _ r: NoopDayRing?) -> String {
        let f = DateFormatter(); f.dateStyle = .full
        return f.string(from: day) + (r.map { ", \(Int(($0.fill * 100).rounded())) percent" } ?? ", no reading")
    }
}
