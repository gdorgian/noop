#if os(iOS)
import SwiftUI
import StrandDesign

/// Shared plot rendering inside the owning screen's existing frame. Stage, load and composition
/// charts retain their own geometry; this view is for dated scalar observations.
struct NoopHistoryPlot: View {
    let presentation: AuraHistoryPresentation
    var tint: Color = NoopHTMLColor.night
    var scoreColors = false
    var measurements = false
    var bridgeMissingMeasurements = false
    var compact = false
    var referenceValue: Double?
    var selectedDate: Date?
    var valueLabel: (Double) -> String = { $0.formatted(.number.precision(.fractionLength(0...1))) }
    var onSelect: ((Date) -> Void)?
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var localSelection: Date?

    private var chosen: Date? { selectedDate ?? localSelection }
    private func color(_ value: Double) -> Color {
        scoreColors ? NoopSpecTokens.chargeColor(charge: value) : tint
    }
    private func select(x: CGFloat, size: CGSize) {
        let width = max(1, size.width - (compact ? 12 : 48))
        guard let point = presentation.series.nearestPoint(to: Double((x - 6) / width)) else { return }
        if let onSelect { onSelect(point.date) }
        else { localSelection = point.date }
    }
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let width = max(1, size.width - (compact ? 12 : 48))
                let height = max(1, size.height - 12)
                guard !presentation.series.points.isEmpty else { return }
                let samples = presentation.series.samples
                let first = samples.first?.date ?? .distantPast
                let duration = (samples.last?.date ?? first).timeIntervalSince(first)
                func x(_ date: Date) -> CGFloat { 6 + width * CGFloat(duration > 0 ? date.timeIntervalSince(first) / duration : 1) }
                func y(_ value: Double) -> CGFloat { 6 + height * CGFloat(1 - presentation.fraction(value)) }
                func point(_ item: DatedChartSeries.Point) -> CGPoint { .init(x: x(item.date), y: y(item.value)) }
                if !compact {
                    for value in presentation.ticks {
                        let py = y(value)
                        var grid = Path(); grid.move(to: .init(x: 6, y: py)); grid.addLine(to: .init(x: width + 6, y: py))
                        context.stroke(grid, with: .color(NoopHTMLColor.ink.opacity(contrast == .increased ? 0.25 : 0.08)), lineWidth: 0.5)
                        context.draw(Text(valueLabel(value)).font(NoopHTMLFont.sans(9.5)).foregroundColor(NoopHTMLColor.muted),
                                     at: .init(x: size.width - 1, y: py), anchor: .trailing)
                    }
                }
                for segment in presentation.bandSegments where segment.count > 1 {
                    var band = Path()
                    for (i, item) in segment.enumerated() {
                        let p = CGPoint(x: x(item.date), y: y(item.high))
                        i == 0 ? band.move(to: p) : band.addLine(to: p)
                    }
                    for item in segment.reversed() { band.addLine(to: .init(x: x(item.date), y: y(item.low))) }
                    band.closeSubpath()
                    context.fill(band, with: .color(tint.opacity(contrast == .increased ? 0.22 : 0.12)))
                }
                if !compact, let average = presentation.average {
                    var line = Path(); line.move(to: .init(x: 6, y: y(average))); line.addLine(to: .init(x: width + 6, y: y(average)))
                    context.stroke(line, with: .color(NoopHTMLColor.inkSoft.opacity(0.5)), style: .init(lineWidth: 1, dash: [3, 4]))
                }
                if let referenceValue, referenceValue.isFinite {
                    var target = Path(); target.move(to: .init(x: 6, y: y(referenceValue))); target.addLine(to: .init(x: width + 6, y: y(referenceValue)))
                    context.stroke(target, with: .color(tint.opacity(0.7)), style: .init(lineWidth: 1, dash: [6, 3]))
                }
                for segment in (measurements && bridgeMissingMeasurements ? [presentation.series.points] : presentation.series.segments) {
                    for i in segment.indices.dropFirst() {
                        let previous = segment[i - 1], current = segment[i]
                        var line = Path(); line.move(to: point(previous)); line.addLine(to: point(current))
                        context.stroke(line, with: .color(color(current.value)),
                                       style: .init(lineWidth: compact ? 1.8 : 2, lineCap: .round, lineJoin: .round, dash: measurements ? [3, 4] : []))
                    }
                }
                let points = presentation.series.points
                let selected = points.first { $0.date == chosen } ?? points.last
                if !compact, let selected, chosen != nil {
                    var guide = Path(); guide.move(to: .init(x: x(selected.date), y: 0)); guide.addLine(to: .init(x: x(selected.date), y: size.height))
                    context.stroke(guide, with: .color(NoopHTMLColor.inkSoft.opacity(0.35)), style: .init(lineWidth: 1, dash: [2, 3]))
                }
                for item in points where (!compact && points.count <= 65) || item.date == selected?.date || points.count == 1 {
                    let p = point(item), active = item.date == selected?.date
                    let radius: CGFloat = active ? (compact ? 2.8 : 4.2) : 2.5
                    let circle = Path(ellipseIn: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2))
                    context.fill(circle, with: .color(active ? color(item.value) : NoopHTMLColor.card))
                    context.stroke(circle, with: .color(color(item.value)), lineWidth: active ? 1.5 : 1.7)
                }
            }
            .overlay {
                if !compact && presentation.series.points.isEmpty {
                    Text("No recorded values in this period").font(NoopHTMLFont.sans(12)).foregroundStyle(NoopHTMLColor.muted)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { position in select(x: position.x, size: geometry.size) }
            .simultaneousGesture(DragGesture(minimumDistance: 12).onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                select(x: value.location.x, size: geometry.size)
            })
            .accessibilityElement()
            .accessibilityLabel(measurements ? "Recorded measurements" : "Recorded history")
            .accessibilityValue(accessibilityValue)
            .accessibilityAdjustableAction { direction in
                let rows = presentation.series.points
                guard !rows.isEmpty else { return }
                let index = rows.firstIndex { $0.date == chosen } ?? rows.count - 1
                let next = direction == .increment ? min(rows.count - 1, index + 1) : max(0, index - 1)
                if let onSelect { onSelect(rows[next].date) } else { localSelection = rows[next].date }
            }
        }
        .onChange(of: presentation.series) { _ in localSelection = nil }
        .allowsHitTesting(!compact)
        .accessibilityHidden(compact)
    }
    private var accessibilityValue: String {
        guard let point = presentation.series.points.first(where: { $0.date == chosen }) ?? presentation.series.points.last else { return "No recorded values" }
        return "\(valueLabel(point.value)), \(point.date.formatted(date: .complete, time: .omitted))"
    }
}
#endif
