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
    var selectsMissingDays = false
    var referenceValue: Double?
    var averageLabel: String?
    var selectedDate: Date?
    var valueLabel: (Double) -> String = { $0.formatted(.number.precision(.fractionLength(0...1))) }
    var axisValueLabel: ((Double) -> String)?
    var onSelect: ((Date) -> Void)?
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var localSelection: Date?

    private var chosen: Date? { selectedDate ?? localSelection }
    private func color(_ value: Double) -> Color {
        scoreColors ? NoopSpecTokens.chargeColor(charge: value) : tint
    }
    private func axisLabel(_ value: Double) -> String { axisValueLabel?(value) ?? valueLabel(value) }
    // A single geometry definition keeps touch selection aligned with the rendered dates.
    private func plotRect(_ size: CGSize) -> CGRect {
        let labelWidth = CGFloat(presentation.ticks.map { axisLabel($0).count }.max() ?? 0) * 6 + 12
        let gutter: CGFloat = compact ? 6 : min(82, max(44, labelWidth))
        let inset: CGFloat = compact ? 6 : (size.height >= 170 ? 16 : 8)
        return CGRect(x: inset, y: inset, width: max(1, size.width - gutter - inset), height: max(1, size.height - inset * 2))
    }
    private func select(x: CGFloat, size: CGSize) {
        let plot = plotRect(size)
        let fraction = Double((x - plot.minX) / plot.width)
        let date = selectsMissingDays ? presentation.series.nearestSample(to: fraction)?.date : presentation.series.nearestPoint(to: fraction)?.date
        guard let date else { return }
        if let onSelect { onSelect(date) } else { localSelection = date }
    }
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let plot = plotRect(size)
                let spacious = !compact && size.height >= 170
                guard !presentation.series.points.isEmpty else { return }
                let samples = presentation.series.samples
                let first = samples.first?.date ?? .distantPast
                let duration = (samples.last?.date ?? first).timeIntervalSince(first)
                func x(_ date: Date) -> CGFloat { plot.minX + plot.width * CGFloat(duration > 0 ? date.timeIntervalSince(first) / duration : 1) }
                func y(_ value: Double) -> CGFloat { plot.minY + plot.height * CGFloat(1 - presentation.fraction(value)) }
                func point(_ item: DatedChartSeries.Point) -> CGPoint { .init(x: x(item.date), y: y(item.value)) }
                if !compact {
                    for value in presentation.ticks {
                        let py = y(value)
                        var grid = Path(); grid.move(to: .init(x: plot.minX, y: py)); grid.addLine(to: .init(x: plot.maxX, y: py))
                        context.stroke(grid, with: .color(NoopHTMLColor.ink.opacity(contrast == .increased ? 0.30 : 0.10)), lineWidth: 0.5)
                        context.draw(Text(axisLabel(value)).font(NoopHTMLFont.sans(spacious ? 11 : 9.5)).foregroundColor(NoopHTMLColor.faint),
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
                    context.fill(band, with: .linearGradient(
                        Gradient(colors: [tint.opacity(contrast == .increased ? 0.30 : 0.20), tint.opacity(contrast == .increased ? 0.20 : 0.08)]),
                        startPoint: .init(x: 0, y: plot.minY), endPoint: .init(x: 0, y: plot.maxY)))
                }
                if !compact, let average = presentation.average {
                    var line = Path(); line.move(to: .init(x: plot.minX, y: y(average))); line.addLine(to: .init(x: plot.maxX, y: y(average)))
                    context.stroke(line, with: .color(tint.opacity(contrast == .increased ? 0.85 : 0.60)), style: .init(lineWidth: 1, dash: [2, 4]))
                }
                if let referenceValue, referenceValue.isFinite {
                    var target = Path(); target.move(to: .init(x: plot.minX, y: y(referenceValue))); target.addLine(to: .init(x: plot.maxX, y: y(referenceValue)))
                    context.stroke(target, with: .color(tint.opacity(0.7)), style: .init(lineWidth: 1, dash: [6, 3]))
                }
                for segment in (measurements && bridgeMissingMeasurements ? [presentation.series.points] : presentation.series.segments) {
                    let stroke = StrokeStyle(lineWidth: compact ? 1.8 : (spacious ? 2.8 : 2.2), lineCap: .round, lineJoin: .round, dash: measurements ? [3, 5] : [])
                    if scoreColors {
                        for i in segment.indices.dropFirst() {
                            let previous = segment[i - 1], current = segment[i]
                            var line = Path(); line.move(to: point(previous)); line.addLine(to: point(current))
                            context.stroke(line, with: .linearGradient(Gradient(colors: [color(previous.value), color(current.value)]),
                                                                      startPoint: point(previous), endPoint: point(current)), style: stroke)
                        }
                    } else {
                        var line = Path()
                        for (index, item) in segment.enumerated() {
                            index == 0 ? line.move(to: point(item)) : line.addLine(to: point(item))
                        }
                        context.stroke(line, with: .color(tint), style: stroke)
                    }
                }
                let points = presentation.series.points
                let selected = chosen == nil ? points.last : points.first { $0.date == chosen }
                if !compact, let chosen {
                    var guide = Path(); guide.move(to: .init(x: x(chosen), y: plot.minY)); guide.addLine(to: .init(x: x(chosen), y: plot.maxY))
                    context.stroke(guide, with: .color(NoopHTMLColor.inkSoft.opacity(0.40)), style: .init(lineWidth: 1, dash: [2, 3]))
                }
                for item in points where (!compact && points.count <= 65) || item.date == selected?.date || points.count == 1 {
                    let p = point(item), active = item.date == selected?.date
                    let radius: CGFloat = active ? (compact ? 2.8 : (spacious ? 5.5 : 4)) : (spacious ? 3.5 : 2.5)
                    if active && !compact && contrast != .increased {
                        let haloRadius: CGFloat = spacious ? 20 : 12
                        let halo = Path(ellipseIn: CGRect(x: p.x - haloRadius, y: p.y - haloRadius, width: haloRadius * 2, height: haloRadius * 2))
                        context.fill(halo, with: .radialGradient(Gradient(colors: [color(item.value).opacity(0.48), color(item.value).opacity(0)]),
                                                               center: p, startRadius: radius, endRadius: haloRadius))
                    }
                    let circle = Path(ellipseIn: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2))
                    context.fill(circle, with: .color(active ? color(item.value) : NoopHTMLColor.card))
                    context.stroke(circle, with: .color(active && !compact ? NoopHTMLColor.ink : color(item.value)), lineWidth: active && !compact ? 2.5 : (spacious ? 2 : 1.7))
                }
                if spacious, let average = presentation.average {
                    let label = context.resolve(Text(averageLabel ?? "Avg. \(valueLabel(average))")
                        .font(NoopHTMLFont.sans(10.5, weight: .semibold)).foregroundColor(NoopHTMLColor.ink))
                    let measured = label.measure(in: CGSize(width: plot.width - 20, height: 24))
                    let badgeWidth = min(plot.width - 16, measured.width + 16)
                    // Put the badge on the opposite side to the selected/latest observation.
                    let badgeX = (selected.map { x($0.date) } ?? plot.maxX) > plot.midX ? plot.minX + 4 : plot.maxX - badgeWidth - 4
                    let badgeY = min(plot.maxY - 12, max(plot.minY + 12, y(average)))
                    let rect = CGRect(x: badgeX, y: badgeY - 11, width: badgeWidth, height: 22)
                    let capsule = Path(roundedRect: rect, cornerRadius: 11)
                    context.fill(capsule, with: .color(NoopHTMLColor.cardRaised))
                    context.stroke(capsule, with: .color(tint.opacity(0.65)), lineWidth: 0.8)
                    context.draw(label, at: .init(x: rect.midX, y: rect.midY))
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
                let dates = selectsMissingDays ? presentation.series.samples.map(\.date) : presentation.series.points.map(\.date)
                guard !dates.isEmpty else { return }
                let index = dates.firstIndex(of: chosen ?? .distantPast) ?? dates.count - 1
                let next = direction == .increment ? min(dates.count - 1, index + 1) : max(0, index - 1)
                if let onSelect { onSelect(dates[next]) } else { localSelection = dates[next] }
            }
        }
        .onChange(of: presentation.series) { _ in localSelection = nil }
        .allowsHitTesting(!compact)
        .accessibilityHidden(compact)
    }
    private var accessibilityValue: String {
        if let chosen, selectsMissingDays, presentation.series.points.first(where: { $0.date == chosen }) == nil {
            return "No recorded value, \(chosen.formatted(date: .complete, time: .omitted))"
        }
        guard let point = presentation.series.points.first(where: { $0.date == chosen }) ?? presentation.series.points.last else { return "No recorded values" }
        let reading = "\(valueLabel(point.value)), \(point.date.formatted(date: .complete, time: .omitted))"
        guard let average = presentation.average else { return reading }
        return "\(reading). Period average: \(averageLabel ?? valueLabel(average))"
    }
}
#endif
