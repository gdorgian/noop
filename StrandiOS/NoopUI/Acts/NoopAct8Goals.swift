import SwiftUI
import UIKit
import PhotosUI
import UniformTypeIdentifiers
import StrandImport
import StrandDesign
import WhoopStore

@MainActor
final class NoopLabReviewDraft: ObservableObject {
    fileprivate enum Origin: Equatable {
        case photo
        case manual
    }

    fileprivate enum ReadState: Equatable {
        case empty
        case reading
        case read
        case nothingLegible
    }

    @Published fileprivate var image: UIImage?
    @Published fileprivate var filename = ""
    @Published fileprivate var reportDay: String?
    @Published fileprivate var state: ReadState = .empty
    @Published fileprivate var candidates: [NoopOCRCandidate] = []
    @Published fileprivate var origin: Origin?

    private var generation = UUID()

    fileprivate var isManual: Bool { origin == .manual }

    fileprivate func begin(_ photo: NoopPickedLabPhoto) -> Bool {
        guard let image = UIImage(data: photo.data) else { return false }
        generation = UUID()
        self.image = image
        origin = .photo
        filename = photo.filename.trimmingCharacters(in: .whitespacesAndNewlines)
        reportDay = nil
        candidates = []
        state = .reading
        return true
    }

    /// Starts the honest no-photo route. Every field is empty; the examples live only in each
    /// text field's placeholder and can therefore never be mistaken for a result or saved.
    fileprivate func beginManual(at date: Date = Date()) {
        generation = UUID()
        image = nil
        origin = .manual
        filename = ""
        reportDay = Self.manualDayFormatter.string(from: date)
        candidates = NoopOCRCandidate.manualFields
        state = .read
    }

    func read(_ data: Data) async {
        let activeGeneration = generation
        do {
            let lines = try await LabReportImageTextExtractor.observations(from: data)
            guard activeGeneration == generation else { return }
            reportDay = Self.reportDay(in: lines.map(\.text))
            candidates = Self.candidates(from: lines)
            state = candidates.isEmpty ? .nothingLegible : .read
        } catch {
            guard activeGeneration == generation else { return }
            candidates = []
            state = .nothingLegible
        }
    }

    func scrub() {
        generation = UUID()
        image = nil
        origin = nil
        filename = ""
        reportDay = nil
        candidates = []
        state = .empty
    }

    #if DEBUG
    func seedDemoReviewIfNeeded() {
        guard origin == nil, NoopContentPolicy.allowsPrototypeContent else { return }
        let size = CGSize(width: 1000, height: 720)
        let renderer = UIGraphicsImageRenderer(size: size)
        let rendered = renderer.image { context in
            UIColor(red: 0.86, green: 0.83, blue: 0.76, alpha: 1).setFill()
            context.cgContext.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.12, green: 0.10, blue: 0.08, alpha: 0.72).setFill()
            "HAEMATOLOGY · SERUM                         14 AUGUST 2026".draw(
                at: CGPoint(x: 72, y: 66),
                withAttributes: [.font: UIFont.monospacedSystemFont(ofSize: 25, weight: .semibold), .foregroundColor: UIColor.black.withAlphaComponent(0.66)]
            )
            context.cgContext.fill(CGRect(x: 72, y: 112, width: 856, height: 2))
            let rows = [
                "Haemoglobin                         138      g/L",
                "Ferritin                             28      µg/L",
                "Vitamin D, 25-OH                     52      nmol/L",
                "ApoB                               0.78      g/L",
                "hs-CRP                              0.6      mg/L"
            ]
            for (index, row) in rows.enumerated() {
                row.draw(
                    at: CGPoint(x: 78, y: 165 + CGFloat(index) * 86),
                    withAttributes: [.font: UIFont.monospacedSystemFont(ofSize: 27, weight: index == 1 ? .semibold : .regular), .foregroundColor: UIColor.black.withAlphaComponent(0.78)]
                )
            }
        }
        image = rendered
        origin = .photo
        filename = "IMG_4471"
        reportDay = "2026-08-14"
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--noop-labs-reading") {
            state = .reading
            candidates = []
            return
        }
        if arguments.contains("--noop-labs-nothing-legible") {
            state = .nothingLegible
            candidates = []
            return
        }
        state = .read
        candidates = NoopOCRCandidate.samplesWithRects
    }
    #endif

    fileprivate var captionDate: String? {
        guard let reportDay, let date = Self.dayFormatter.date(from: reportDay) else { return nil }
        return Self.captionFormatter.string(from: date)
    }

    private static func candidates(from lines: [LabReportImageTextExtractor.RecognizedLine]) -> [NoopOCRCandidate] {
        struct Found {
            let parsed: LabReportTextCandidate
            let line: LabReportImageTextExtractor.RecognizedLine
            let index: Int
        }
        var foundByMarker: [String: Found] = [:]
        for (index, line) in lines.enumerated() {
            let parsed = LabReportTextImport.parse(text: line.text)
            for candidate in parsed.candidates {
                let found = Found(parsed: candidate, line: line, index: index)
                if let previous = foundByMarker[candidate.markerKey], previous.line.confidence >= line.confidence {
                    continue
                }
                foundByMarker[candidate.markerKey] = found
            }
        }
        return foundByMarker.values.sorted { $0.index < $1.index }.map { found in
            let definition = MarkerCatalog.definition(for: found.parsed.markerKey)
            let name = definition?.displayName ?? found.parsed.markerKey.replacingOccurrences(of: "_", with: " ").capitalized
            let decimals = definition?.decimals ?? 2
            let value = found.parsed.value.formatted(.number.precision(.fractionLength(0...decimals)))
            let visionRect = found.line.boundingBox
            let topLeftRect = CGRect(
                x: visionRect.minX,
                y: 1 - visionRect.maxY,
                width: visionRect.width,
                height: visionRect.height
            )
            return NoopOCRCandidate(
                id: "\(found.index)-\(found.parsed.markerKey)",
                markerKey: found.parsed.markerKey,
                category: found.parsed.category,
                name: name,
                value: value,
                unit: found.parsed.unit,
                raw: found.line.text,
                confidence: found.line.confidence < 0.75 ? "check this" : "clear read",
                lowConfidence: found.line.confidence < 0.75,
                sourceRect: topLeftRect
            )
        }
    }

    private static func reportDay(in lines: [String]) -> String? {
        let text = lines.joined(separator: " ")
        let patterns = [
            "(?i)\\b[0-3]?[0-9]\\s+(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\\s+(?:19|20)[0-9]{2}\\b",
            "\\b(?:19|20)[0-9]{2}-[01][0-9]-[0-3][0-9]\\b"
        ]
        for pattern in patterns {
            guard let range = text.range(of: pattern, options: .regularExpression) else { continue }
            let token = String(text[range])
            for formatter in reportDateFormatters {
                if let date = formatter.date(from: token) { return dayFormatter.string(from: date) }
            }
        }
        return nil
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter
    }()

    private static let manualDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let captionFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "d MMMM"
        return formatter
    }()

    private static let reportDateFormatters: [DateFormatter] = ["d MMMM yyyy", "d MMM yyyy", "yyyy-MM-dd"].map { format in
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = format
        formatter.isLenient = false
        return formatter
    }
}

fileprivate struct NoopPickedLabPhoto: Sendable {
    let data: Data
    let filename: String
}

private enum NoopLabPhotoSource: String, Identifiable {
    case camera
    case library
    var id: String { rawValue }
}

private struct NoopLabPhotoDoor: ViewModifier {
    @Binding var isChoosingSource: Bool
    @Binding var source: NoopLabPhotoSource?
    let title: String
    let onPhoto: (NoopPickedLabPhoto) -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                title,
                isPresented: $isChoosingSource,
                titleVisibility: .visible
            ) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Take a photo") { source = .camera }
                }
                Button("Choose from Photos") { source = .library }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(item: $source) { selectedSource in
                NoopLabPhotoPicker(source: selectedSource) { photo in
                    source = nil
                    if let photo { onPhoto(photo) }
                }
                .ignoresSafeArea()
            }
    }
}

private extension View {
    func noopLabPhotoDoor(
        isChoosingSource: Binding<Bool>,
        source: Binding<NoopLabPhotoSource?>,
        title: String = "Add lab results",
        onPhoto: @escaping (NoopPickedLabPhoto) -> Void
    ) -> some View {
        modifier(NoopLabPhotoDoor(
            isChoosingSource: isChoosingSource,
            source: source,
            title: title,
            onPhoto: onPhoto
        ))
    }
}

private struct NoopLabPhotoPicker: UIViewControllerRepresentable {
    let source: NoopLabPhotoSource
    let completion: (NoopPickedLabPhoto?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }

    func makeUIViewController(context: Context) -> UIViewController {
        switch source {
        case .camera:
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.cameraCaptureMode = .photo
            picker.delegate = context.coordinator
            return picker
        case .library:
            var configuration = PHPickerConfiguration(photoLibrary: .shared())
            configuration.filter = .images
            configuration.selectionLimit = 1
            configuration.preferredAssetRepresentationMode = .current
            let picker = PHPickerViewController(configuration: configuration)
            picker.delegate = context.coordinator
            return picker
        }
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate, PHPickerViewControllerDelegate {
        let completion: (NoopPickedLabPhoto?) -> Void

        init(completion: @escaping (NoopPickedLabPhoto?) -> Void) {
            self.completion = completion
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            completion(nil)
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let url = info[.imageURL] as? URL,
               let data = try? Data(contentsOf: url) {
                completion(NoopPickedLabPhoto(data: data, filename: url.lastPathComponent))
                return
            }
            guard let image = info[.originalImage] as? UIImage,
                  let data = image.jpegData(compressionQuality: 1) else {
                completion(nil)
                return
            }
            completion(NoopPickedLabPhoto(data: data, filename: "Camera photo"))
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider else {
                completion(nil)
                return
            }
            let suggestedName = provider.suggestedName
            provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, _ in
                guard let url, let data = try? Data(contentsOf: url) else {
                    DispatchQueue.main.async { self.completion(nil) }
                    return
                }
                let filename = suggestedName.flatMap { $0.isEmpty ? nil : $0 }
                    ?? url.lastPathComponent
                DispatchQueue.main.async {
                    self.completion(NoopPickedLabPhoto(data: data, filename: filename))
                }
            }
        }
    }
}

struct NoopAct8Screens: View {
    @ObservedObject var navigation: NoopNavigation
    @ObservedObject var labDraft: NoopLabReviewDraft

    var body: some View {
        switch navigation.route {
        case .goal:
            NoopGoalJourney(navigation: navigation)
        case .setGoal:
            NoopGoalSet(navigation: navigation)
        case .labs:
            NoopLabsHome(navigation: navigation, draft: labDraft)
        case .picker:
            NoopLabPicker(navigation: navigation, draft: labDraft)
        case .review:
            NoopLabReview(navigation: navigation, draft: labDraft)
        case .marker:
            NoopMarkerDetail(navigation: navigation)
        default:
            NoopGoalJourney(navigation: navigation)
        }
    }
}

// MARK: - Journey

private struct NoopGoalJourney: View {
    @ObservedObject var navigation: NoopNavigation
    @ObservedObject private var goalStore = CoachGoalStore.shared
    @AppStorage("noop.html.active-goal-kind") private var activeKind = NoopGoalKind.distance.rawValue
    @AppStorage("noop.html.active-goal-title") private var activeTitle = "Half marathon on 26 October, finishing comfortably."
    @State private var weekState = "open"

    var body: some View {
        NoopScreen(bottomInset: 118, topInset: 56) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 12) {
                    Button { navigation.reset(to: .you) } label: {
                        ZStack {
                            Circle().fill(Color.white.opacity(0.06)).overlay(Circle().stroke(NoopHTMLColor.borderStrong, lineWidth: 0.5))
                            NoopFixedChevron(direction: .left, color: NoopHTMLColor.inkSoft).offset(x: -1)
                        }.frame(width: 34, height: 34)
                    }.buttonStyle(.plain)
                    Text("You").font(NoopHTMLFont.sans(13.5)).foregroundStyle(NoopHTMLColor.copy)
                    Spacer()
                    Button("Change it") { navigation.push(.setGoal) }
                        .buttonStyle(NoopHTMLButtonStyle(kind: .secondary))
                        .frame(height: 30)
                }
                .padding(.horizontal, -2)

                HStack {
                    NoopSectionLabel("One goal at a time")
                    Spacer()
                    Text(deadlineLabel).font(NoopHTMLFont.sans(10.5)).foregroundStyle(NoopHTMLColor.faint)
                }.padding(.top, 8)

                NoopGoalRouteGraphic()

                VStack(alignment: .leading, spacing: 6) {
                    Text(displayedTitle)
                        .font(NoopHTMLFont.outfit(25, weight: .light)).tracking(-0.7).lineSpacing(2)
                    Text(goalSubtitle)
                        .font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.copy).lineSpacing(4)
                }
                .padding(.horizontal, 2)
                .padding(.top, 6)
                .padding(.bottom, 2)

                NoopAct8GradientCard(
                    tint: NoopHTMLColor.green,
                    degrees: 158,
                    startOpacity: 0.15,
                    endColor: Color.white.opacity(0.02),
                    borderOpacity: 0.34,
                    padding: EdgeInsets(top: 17, leading: 17, bottom: 16, trailing: 17)
                ) {
                    VStack(alignment: .leading, spacing: 11) {
                        HStack(spacing: 9) {
                            Circle().fill(NoopHTMLColor.green).shadow(color: NoopHTMLColor.green, radius: 5).frame(width: 8, height: 8)
                            NoopSectionLabel("The data says yes", color: Color(hex: 0x8FEFC0))
                        }
                        Text(feasibilityCopy)
                            .font(NoopHTMLFont.sans(13.5)).foregroundStyle(Color(hex: 0xDCE3E0)).lineSpacing(6.3)
                    }
                }
                .padding(.top, 14)

                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            NoopSectionLabel("Waypoints")
                            Spacer()
                            Text("only ticked when it happened").font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.faint)
                        }.padding(.bottom, 2)
                        ForEach(Array(waypoints.enumerated()), id: \.offset) { index, waypoint in
                            HStack(alignment: .top, spacing: 12) {
                                Group {
                                    if waypoint.done { Circle().fill(Color(hex: 0xF2B45C)).shadow(color: Color(hex: 0xF2B45C), radius: 6) }
                                    else { Circle().stroke(Color.white.opacity(0.24), style: StrokeStyle(lineWidth: 1.6, dash: [3, 3])) }
                                }.frame(width: 17, height: 17).padding(.top, 2)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(waypoint.title).font(NoopHTMLFont.sans(13.5)).foregroundStyle(waypoint.done ? NoopHTMLColor.ink : NoopHTMLColor.inkSoft)
                                    Text(waypoint.detail).font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy).lineSpacing(2)
                                }
                                Spacer()
                                NoopPill(text: waypoint.tag, color: waypoint.done ? Color(hex: 0xF6DCB4) : NoopHTMLColor.copy)
                            }.padding(.vertical, 14)
                            if index < waypoints.count - 1 { Divider().overlay(NoopHTMLColor.border) }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(NoopHTMLColor.border, lineWidth: 0.5))
                .padding(.top, 10)

                NoopAct8GradientCard(
                    tint: NoopHTMLColor.night,
                    degrees: 160,
                    startOpacity: 0.14,
                    endColor: NoopHTMLColor.night.opacity(0.03),
                    borderOpacity: 0.30,
                    padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
                ) {
                    VStack(alignment: .leading, spacing: 11) {
                        HStack {
                            NoopSectionLabel("This week, from Svea", color: Color(hex: 0xC9D0EE)); Spacer()
                            NoopPill(text: "written", color: Color(hex: 0xA9B4E0))
                        }
                        Text(weekProposal).font(NoopHTMLFont.sans(13.5)).foregroundStyle(Color(hex: 0xDCE3E0)).lineSpacing(4)
                        if weekState == "open" {
                            GeometryReader { proxy in
                                let unit = max(0, proxy.size.width - 7) / 2.4
                                HStack(spacing: 7) {
                                    Button("Take the week") { weekState = "taken" }
                                        .buttonStyle(NoopAct8WeekActionStyle(primary: true))
                                        .frame(width: unit * 1.4)
                                    Button("Not this week") { weekState = "skipped" }
                                        .buttonStyle(NoopAct8WeekActionStyle(primary: false))
                                        .frame(width: unit)
                                }
                            }
                            .frame(height: 42)
                        } else {
                            HStack {
                                Text(weekState == "taken" ? "This week is in. Svea will still check each morning" : "Left out. The route holds and the date does not move for one week")
                                    .font(NoopHTMLFont.sans(12.5))
                                Spacer()
                                Button("Undo") { weekState = "open" }.font(NoopHTMLFont.sans(11.5, weight: .semibold)).foregroundStyle(Color(hex: 0xA9B4E0))
                            }.padding(12).background(NoopHTMLColor.night.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
                .padding(.top, 10)

                NoopAct8BiomarkerLink(detail: biomarkersSummary) { navigation.push(.labs) }
                    .padding(.top, 10)
                Text("Progress is counted from sessions that were actually recorded on your wrist. Noop will not credit you for a week it did not see, and it will not invent a streak to keep you going.")
                    .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(3)
                    .padding(.horizontal, 2)
                    .padding(.top, 6)
            }
        }
    }

    private var activeStoredGoal: CoachGoal? {
        NoopContentPolicy.allowsPrototypeContent ? nil : goalStore.activeGoals.first
    }
    private var displayedTitle: String {
        NoopContentPolicy.allowsPrototypeContent
            ? "Half marathon on 26 October, finishing comfortably."
            : activeStoredGoal?.title ?? activeTitle
    }
    private var deadlineLabel: String {
        if NoopContentPolicy.allowsPrototypeContent { return "11 weeks to 26 October" }
        guard let deadline = activeStoredGoal?.targetDate else { return "11 weeks to 26 October" }
        let weeks = max(0, Calendar.current.dateComponents([.weekOfYear], from: Date(), to: deadline).weekOfYear ?? 0)
        return "\(weeks) weeks to \(deadline.formatted(.dateTime.day().month(.wide)))"
    }
    private var goalKind: NoopGoalKind {
        if NoopContentPolicy.allowsPrototypeContent { return .distance }
        if let stored = activeStoredGoal {
            switch stored.kind {
            case .sleep: return .sleep
            case .consistency: return .sleep
            case .weight: return .composition
            case .run: return NoopGoalKind(rawValue: activeKind) ?? .distance
            default: break
            }
        }
        return NoopGoalKind(rawValue: activeKind) ?? .distance
    }
    private var goalSubtitle: String {
        switch goalKind {
        case .distance: "Set 4 August. Two waypoints reached, both recorded on your wrist — 34 km a week at 6:04, and seventeen of the last thirty-one nights over your own need."
        case .pace: "Set from your recent sessions. Every waypoint is credited only when the target pace was recorded on your wrist."
        case .sleep: "Built from the bedtime window you chose and the nights the strap actually saw — missed nights are left blank, never guessed."
        case .composition: "Built from values you entered yourself. Noop dates every change and never treats the strap as a body-composition sensor."
        }
    }
    private var feasibilityCopy: String {
        switch goalKind {
        case .distance: "Twelve kilometres at 6:04 with heart rate under 150, on 34 km a week and eleven weeks left. The route asks for 55 km at peak, which is a 9% build — inside what your sleep has been absorbing."
        case .pace: "Your last four comparable efforts are moving in the right direction. The route keeps the hard work under the load your sleep has absorbed."
        case .sleep: "Your current timing already lands inside the chosen window on five nights a week. The route asks for consistency before it asks for a tighter window."
        case .composition: "The target sits inside the rate of change recorded over your last three entries. Wearable estimates are not used to make this call."
        }
    }
    private var weekProposal: String {
        goalKind == .distance
            ? "Four runs: two easy, one 14 km on Saturday, and Wednesday only if Tuesday night lands over your need. Nothing in this week is fixed — it moves with the mornings."
            : "Three small steps this week, each tied to the measurements that support this goal. Nothing is credited until it is recorded."
    }
    private var waypoints: [NoopGoalWaypoint] {
        switch goalKind {
        case .distance:
            [
                .init(title: "First 12 km run", detail: "done 3 August, at 6:04/km", tag: "reached", done: true),
                .init(title: "Four weeks inside your bedtime hour", detail: "done 17 August — the reason the rest is possible", tag: "reached", done: true),
                .init(title: "18 km at conversational pace", detail: "the next one. Two attempts allowed, no penalty for either", tag: "next", done: false),
                .init(title: "A week at 55 km without a poor night", detail: "the load ceiling this route is built around", tag: "ahead", done: false),
                .init(title: "Half marathon, 26 October", detail: "the goal. Nothing about the date is a promise", tag: "the day", done: false)
            ]
        case .pace:
            genericWaypoints(["Baseline effort recorded", "Three repeats inside target", "Target pace over half the distance", "Full-distance rehearsal", "Target effort"])
        case .sleep:
            genericWaypoints(["Five nights inside the window", "First full week", "Four steady weekends", "Eight-week run", "Regularity target"])
        case .composition:
            genericWaypoints(["Baseline entered", "First dated change", "Four-week trend", "Halfway value", "Target value"])
        }
    }
    private func genericWaypoints(_ labels: [String]) -> [NoopGoalWaypoint] {
        labels.enumerated().map { .init(title: $0.element, detail: $0.offset < 2 ? "recorded and dated" : "credited only when measured", tag: $0.offset < 2 ? "reached" : ($0.offset == 2 ? "next" : "ahead"), done: $0.offset < 2) }
    }
    private var biomarkersSummary: String {
        let outside = NoopLabMarker.all.filter(\.isOutside).count
        return "\(outside) of \(NoopLabMarker.all.count) outside the lab band · drawn 14 August"
    }
}

private struct NoopGoalRouteGraphic: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let spin = reduceMotion ? 0 : now.truncatingRemainder(dividingBy: 110) / 110 * 360
            let pulsePhase = now.truncatingRemainder(dividingBy: 9) / 9
            let pulse = reduceMotion ? 0.70 : 0.70 + 0.30 * ((1 - cos(pulsePhase * 2 * .pi)) / 2)

            ZStack {
                Ellipse()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: Color(hex: 0xF2B45C).opacity(0.22), location: 0),
                                .init(color: Color(hex: 0xF2B45C).opacity(0), location: 0.62)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 270)
                    .blur(radius: 18)
                    .opacity(pulse)

                routeSpecks
                    .rotationEffect(.degrees(spin))

                Canvas { context, size in
                    func point(_ t: Double) -> CGPoint {
                        CGPoint(
                            x: (22 + t * 296) / 330 * size.width,
                            y: (128 - sin(t * 2.1) * 58 - t * 26 + sin(t * 6.1) * 5) / 220 * size.height
                        )
                    }

                    func drawSegments(_ target: inout GraphicsContext) {
                        for index in 0..<36 {
                            let t0 = Double(index) / 36
                            let t1 = Double(index + 1) / 36
                            let done = t1 <= 0.46
                            let edge = !done && t0 <= 0.46
                            var segment = Path()
                            segment.move(to: point(t0))
                            segment.addLine(to: point(t1))
                            target.stroke(
                                segment,
                                with: .color(done ? Color(hex: 0xF2B45C) : edge ? Color(hex: 0xF2B45C).opacity(0.5) : Color.white.opacity(0.11)),
                                style: StrokeStyle(lineWidth: done ? 7 : 4, lineCap: .round)
                            )
                        }
                    }

                    context.drawLayer { glow in
                        glow.opacity = 0.85
                        glow.addFilter(.blur(radius: 8))
                        drawSegments(&glow)
                    }
                    drawSegments(&context)

                    for t in [0.06, 0.30, 0.52, 0.76, 0.97] {
                        let done = t <= 0.46
                        let center = point(t)
                        let radius: CGFloat = done ? 6 : 5
                        let dot = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                        context.fill(dot, with: .color(done ? Color(hex: 0xF2B45C) : NoopHTMLColor.canvas))
                        context.stroke(dot, with: .color(done ? Color(hex: 0xF6DCB4) : Color.white.opacity(0.3)), lineWidth: 1.8)
                    }
                }
                .frame(width: 330, height: 220)

                VStack {
                    Spacer()
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("46%")
                                .font(NoopHTMLFont.outfit200(50))
                                .tracking(-2.25)
                                .shadow(color: .black.opacity(0.75), radius: 12, y: 2)
                            Text("OF THE ROUTE, RECORDED")
                                .font(NoopHTMLFont.sans(10.5, weight: .semibold))
                                .tracking(1.68)
                                .foregroundStyle(Color(hex: 0x93A0A6))
                        }
                        Spacer()
                    }
                }
                .padding(.bottom, 6)

                VStack {
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("26 OCTOBER")
                                .font(NoopHTMLFont.sans(9.5, weight: .semibold))
                                .tracking(1.14)
                                .foregroundStyle(NoopHTMLColor.faint)
                            Text("the day itself")
                                .font(NoopHTMLFont.sans(11))
                                .foregroundStyle(NoopHTMLColor.copy)
                        }
                    }
                    Spacer()
                }
                .padding(.top, 6)
                .padding(.trailing, 2)
            }
            .frame(height: 252)
        }
    }

    private var routeSpecks: some View {
        Canvas { context, size in
            for index in 0..<30 {
                let angle = Double(index) * 2.39996 + hash(index) * 1.3
                let radius = 0.72 + hash(index + 40) * 0.34
                let diameter = 1 + hash(index + 9) * 2
                let center = CGPoint(
                    x: size.width * (0.5 + cos(angle) * radius * 0.47),
                    y: size.height * (0.5 + sin(angle) * radius * 0.47)
                )
                let rect = CGRect(
                    x: center.x - diameter / 2,
                    y: center.y - diameter / 2,
                    width: diameter,
                    height: diameter
                )
                context.drawLayer { dot in
                    dot.addFilter(.shadow(color: Color(hex: 0xF2B45C).opacity(0.7), radius: diameter * 2.6))
                    dot.fill(
                        Path(ellipseIn: rect),
                        with: .color(Color(hex: 0xFFE8C4).opacity(0.14 + hash(index + 3) * 0.38))
                    )
                }
            }
        }
        .frame(width: 250, height: 250)
    }

    private func hash(_ number: Int) -> Double {
        let value = sin(Double(number) * 127.1 + 311.7) * 43_758.5453
        return value - floor(value)
    }
}

private struct NoopAct8GradientCard<Content: View>: View {
    let tint: Color
    let degrees: Double
    let startOpacity: Double
    let endColor: Color
    let borderOpacity: Double
    let padding: EdgeInsets
    let content: Content

    init(
        tint: Color,
        degrees: Double,
        startOpacity: Double,
        endColor: Color,
        borderOpacity: Double,
        padding: EdgeInsets,
        @ViewBuilder content: () -> Content
    ) {
        self.tint = tint
        self.degrees = degrees
        self.startOpacity = startOpacity
        self.endColor = endColor
        self.borderOpacity = borderOpacity
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                NoopCSSLinearGradient(
                    colors: [tint.opacity(startOpacity), endColor],
                    degrees: degrees
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(tint.opacity(borderOpacity), lineWidth: 0.5)
            }
    }
}

private struct NoopAct8BiomarkerLink: View {
    let detail: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                NoopCanonicalGlyph(name: .drop, size: 20, color: NoopHTMLColor.warm)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Biomarkers")
                        .font(NoopHTMLFont.sans(13.5))
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text(detail)
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(Color(hex: 0x7F8A85))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                NoopFixedChevron(direction: .right, color: NoopHTMLColor.faint)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 66)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(NoopHTMLColor.border, lineWidth: 0.5)
            }
        }
        .buttonStyle(NoopHTMLPressStyle())
    }
}

// MARK: - Set goal

private struct NoopGoalSet: View {
    @ObservedObject var navigation: NoopNavigation
    @ObservedObject private var goalStore = CoachGoalStore.shared
    @AppStorage("noop.html.goal-week-index") private var weekIndex = 4
    @AppStorage("noop.html.goal-draft-title") private var draftTitle = "Half marathon on 26 October, finishing comfortably."
    @AppStorage("noop.html.active-goal-kind") private var activeKind = NoopGoalKind.distance.rawValue
    @AppStorage("noop.html.active-goal-title") private var activeTitle = "Half marathon on 26 October, finishing comfortably."
    @State private var showCommitConfirmation = false
    private let labels = ["6 weeks", "2 months", "10 weeks", "3 months", "15 weeks", "4 months", "20 weeks", "5 months", "6 months", "8 months", "10 months", "a year"]

    var body: some View {
        ZStack {
            NoopScreen(bottomInset: 118, topInset: 56) {
                VStack(alignment: .leading, spacing: 12) {
                    NoopBackHeader(label: "Journey") { navigation.back(or: .goal) }
                        .padding(.horizontal, -2)
                        .padding(.bottom, -14)
                    Text("Set the goal").font(NoopHTMLFont.outfit(25, weight: .light)).tracking(-0.7)

                    NoopHTMLCard(radius: 24, padding: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            NoopSectionLabel("What are you aiming at")
                            NoopFlowLayout(spacing: 7) {
                                ForEach(NoopGoalKind.allCases) { kind in
                                    Button {
                                        navigation.selectedGoal = kind
                                        navigation.show(.goalEditor)
                                    } label: {
                                        Text(kind.rawValue).font(NoopHTMLFont.sans(12, weight: .semibold))
                                            .foregroundStyle(navigation.selectedGoal == kind ? Color(hex: 0x1E1405) : NoopHTMLColor.inkSoft)
                                            .padding(.horizontal, 13).frame(height: 36)
                                            .background(navigation.selectedGoal == kind ? Color(hex: 0xF2B45C) : Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 11))
                                            .overlay(RoundedRectangle(cornerRadius: 11).stroke(navigation.selectedGoal == kind ? .clear : Color.white.opacity(0.1), lineWidth: 0.5))
                                    }.buttonStyle(.plain)
                                }
                            }
                            HStack {
                                Text("By when").font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.inkSoft)
                                Spacer()
                                Text(labels[selectedWeekIndex]).font(.system(size: 12.5, weight: .semibold, design: .monospaced)).foregroundStyle(Color(hex: 0xF6DCB4))
                            }.padding(.top, 4)
                            HStack(alignment: .bottom, spacing: 5) {
                                ForEach(labels.indices, id: \.self) { index in
                                    Button { weekIndex = index } label: {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(index == selectedWeekIndex ? Color(hex: 0xF2B45C) : index < selectedWeekIndex ? Color(hex: 0xF2B45C).opacity(0.32) : Color.white.opacity(0.1))
                                            .frame(height: index == selectedWeekIndex ? 34 : 24)
                                    }.buttonStyle(.plain)
                                }
                            }
                            HStack { Text("6 weeks"); Spacer(); Text("a year") }.font(NoopHTMLFont.sans(10.5)).foregroundStyle(NoopHTMLColor.faint)
                        }
                    }

                    NoopAct8GradientCard(
                        tint: feasibility.color,
                        degrees: 158,
                        startOpacity: 0.15,
                        endColor: Color.white.opacity(0.02),
                        borderOpacity: 0.34,
                        padding: EdgeInsets(top: 17, leading: 17, bottom: 16, trailing: 17)
                    ) {
                        VStack(alignment: .leading, spacing: 11) {
                            HStack(spacing: 9) {
                                Circle().fill(feasibility.color).shadow(color: feasibility.color, radius: 5).frame(width: 8, height: 8)
                                NoopSectionLabel(feasibility.kicker, color: feasibility.light)
                            }
                            Text(feasibility.body).font(NoopHTMLFont.sans(13.5)).foregroundStyle(Color(hex: 0xDCE3E0)).lineSpacing(4)
                            if let fix = feasibility.fix {
                                VStack(alignment: .leading, spacing: 7) {
                                    NoopSectionLabel("What the data would accept")
                                    Text(fix).font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.inkSoft).lineSpacing(3)
                                }.padding(12).background(NoopHTMLColor.canvas.opacity(0.4), in: RoundedRectangle(cornerRadius: 16))
                            }
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(NoopGoalEvidence.all) { evidence in
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack { Text(evidence.name).font(NoopHTMLFont.sans(12.5)); Spacer(); Text(evidence.value).font(.system(size: 11.5, weight: .semibold, design: .monospaced)) }
                                        NoopProgressBar(
                                            progress: evidence.progress * feasibility.factor,
                                            color: evidenceColor(for: evidence),
                                            height: 6
                                        )
                                        Text(evidence.note).font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.copy)
                                    }
                                }
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 5)
                        }
                    }

                    NoopHTMLCard(radius: 24, padding: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            NoopSectionLabel("Safety check", color: Color(hex: 0xF3C888))
                            Text(feasibility.safety).font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.inkSoft).lineSpacing(3)
                            Text("Noop will not build a route that adds more than ten percent of weekly load a week, and it will hold a week back rather than meet a date. If that means the date moves, it says the date moves.")
                                .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.copy).lineSpacing(3)
                        }
                    }

                    Button(feasibility.commitLabel) {
                        if feasibility.kind == .realistic { commit() } else { showCommitConfirmation = true }
                    }.buttonStyle(NoopGoalCommitStyle(primary: feasibility.kind == .realistic))

                    Text("One goal at a time, on purpose. A second one would compete with the first for the same nights of sleep, and the app would have to pretend it did not.")
                        .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(3).padding(.horizontal, 2)
                }
            }
            if showCommitConfirmation {
                NoopBottomSheet(title: "Commit anyway?", dismiss: { showCommitConfirmation = false }) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("The data does not support this date as written. Noop will save the goal, but it will keep its safety limits and say when the date has to move.")
                            .font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.copy).lineSpacing(4)
                        Button("Commit anyway") { showCommitConfirmation = false; commit() }
                            .buttonStyle(NoopHTMLButtonStyle(kind: .primary, fullWidth: true))
                        Button("Keep editing") { showCommitConfirmation = false }
                            .buttonStyle(NoopHTMLButtonStyle(kind: .quiet, fullWidth: true))
                    }
                }
            }
        }
    }

    private var feasibility: NoopGoalFeasibility {
        if selectedWeekIndex <= 1 { return .unrealistic }
        if selectedWeekIndex <= 3 { return .ambitious }
        return .realistic
    }
    private var selectedWeekIndex: Int { max(0, min(labels.count - 1, weekIndex)) }
    private func evidenceColor(for evidence: NoopGoalEvidence) -> Color {
        let value = evidence.progress * feasibility.factor
        if value > 0.7 { return NoopHTMLColor.green }
        if value > 0.5 { return NoopHTMLColor.warm }
        return Color(hex: 0xE9A288)
    }
    private func commit() {
        activeKind = navigation.selectedGoal.rawValue
        activeTitle = draftTitle
        let defaults = UserDefaults.standard
        let deadlineWeeks = [6, 8, 10, 12, 15, 16, 20, 22, 26, 35, 43, 52][selectedWeekIndex]
        let deadline = Calendar.current.date(byAdding: .weekOfYear, value: deadlineWeeks, to: Date())
        let kind: CoachGoal.Kind
        let baseline: Double?
        let target: Double?
        switch navigation.selectedGoal {
        case .distance:
            kind = .run
            baseline = 12
            switch defaults.string(forKey: "noop.html.goal.distance") ?? "Half marathon" {
            case "5K": target = 5
            case "10K": target = 10
            case "Marathon": target = 42.195
            default: target = 21.0975
            }
        case .pace:
            kind = .run
            baseline = nil
            target = nil
        case .sleep:
            kind = .consistency
            baseline = nil
            target = Double(defaults.string(forKey: "noop.html.goal.sleep-nights") ?? "5")
        case .composition:
            kind = (defaults.string(forKey: "noop.html.goal.composition-metric") ?? "Weight") == "Weight" ? .weight : .custom
            baseline = nil
            target = Double(defaults.string(forKey: "noop.html.goal.target-value") ?? "")
        }
        for existing in goalStore.activeGoals {
            goalStore.setAside(existing.id, reason: "Replaced by the new one-goal route")
        }
        let draft = CoachGoal(
            kind: kind,
            title: draftTitle,
            baseline: baseline,
            target: target,
            targetDate: deadline,
            history: [.init(date: Date(), what: "Set in the Noop Journey")]
        )
        let acknowledgement: CoachGoal.RiskAcknowledgement? = feasibility.kind == .realistic ? nil : .init(
            verdict: feasibility.kicker,
            reason: "Confirmed with Commit anyway",
            date: Date()
        )
        goalStore.commit(draft, acknowledgedRisk: acknowledgement)
        navigation.reset(to: .goal)
    }
}

/// The canonical Set screen remains intact; selecting a kind opens this HTML-styled editor for
/// the details that the static proof did not render.
struct NoopGoalEditorSheet: View {
    @ObservedObject var navigation: NoopNavigation
    @State private var activity = "Run"
    @State private var distance = "Half marathon"
    @State private var eventDistance = "10K"
    @State private var finishTime = "00:52:00"
    @State private var sleepAnchor = "23:00–07:00"
    @State private var sleepDrift = "±45 min"
    @State private var nights = "5"
    @State private var compositionMetric = "Weight"
    @State private var targetValue = "72"

    var body: some View {
        NoopBottomSheet(title: navigation.selectedGoal.rawValue, dismiss: navigation.dismissOverlay, showsDone: true) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch navigation.selectedGoal {
                    case .distance:
                        fieldPicker("Activity", selection: $activity, values: ["Run", "Ride", "Swim", "Walk"])
                        fieldPicker("Target distance", selection: $distance, values: ["5K", "10K", "Half marathon", "Marathon", "Custom"])
                    case .pace:
                        fieldPicker("Activity", selection: $activity, values: ["Run", "Ride", "Swim", "Walk"])
                        fieldPicker("Event distance", selection: $eventDistance, values: ["5K", "10K", "Half marathon", "Marathon", "Custom"])
                        textField("Target finish time", text: $finishTime, keyboard: .numbersAndPunctuation)
                        Text("Finish time and target pace stay linked.").font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.copy)
                    case .sleep:
                        textField("Target sleep window", text: $sleepAnchor)
                        fieldPicker("Acceptable drift", selection: $sleepDrift, values: ["±30 min", "±45 min", "±60 min"])
                        fieldPicker("Nights each week", selection: $nights, values: ["4", "5", "6", "7"])
                    case .composition:
                        fieldPicker("Metric", selection: $compositionMetric, values: ["Weight", "Waist", "Body fat"])
                        textField("Target value", text: $targetValue, keyboard: .decimalPad)
                        Text(compositionMetric == "Weight" ? "kg" : compositionMetric == "Waist" ? "cm" : "%")
                            .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy)
                    }
                    Text("Prefilled from your current profile and record. Every value remains editable.")
                        .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(3)
                    Button("Save goal details") { save() }
                        .buttonStyle(NoopHTMLButtonStyle(kind: .primary, fullWidth: true))
                }
            }.frame(maxHeight: 470)
        }
        .task { load() }
    }

    private func fieldPicker(_ label: String, selection: Binding<String>, values: [String]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy)
            Picker(label, selection: selection) { ForEach(values, id: \.self) { Text($0).tag($0) } }
                .pickerStyle(.menu).tint(NoopHTMLColor.ink)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 48)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 15))
        }
    }
    private func textField(_ label: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy)
            TextField(label, text: text).keyboardType(keyboard).font(NoopHTMLFont.sans(13.5)).padding(.horizontal, 14).frame(height: 48)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.11), lineWidth: 0.5))
        }
    }
    private func load() {
        let defaults = UserDefaults.standard
        activity = defaults.string(forKey: "noop.html.goal.activity") ?? "Run"
        distance = defaults.string(forKey: "noop.html.goal.distance") ?? "Half marathon"
        eventDistance = defaults.string(forKey: "noop.html.goal.event-distance") ?? "10K"
        finishTime = defaults.string(forKey: "noop.html.goal.finish-time") ?? "00:52:00"
        sleepAnchor = defaults.string(forKey: "noop.html.goal.sleep-anchor") ?? "23:00–07:00"
        sleepDrift = defaults.string(forKey: "noop.html.goal.sleep-drift") ?? "±45 min"
        nights = defaults.string(forKey: "noop.html.goal.sleep-nights") ?? "5"
        compositionMetric = defaults.string(forKey: "noop.html.goal.composition-metric") ?? "Weight"
        targetValue = defaults.string(forKey: "noop.html.goal.target-value") ?? "72"
    }
    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(activity, forKey: "noop.html.goal.activity")
        defaults.set(distance, forKey: "noop.html.goal.distance")
        defaults.set(eventDistance, forKey: "noop.html.goal.event-distance")
        defaults.set(finishTime, forKey: "noop.html.goal.finish-time")
        defaults.set(sleepAnchor, forKey: "noop.html.goal.sleep-anchor")
        defaults.set(sleepDrift, forKey: "noop.html.goal.sleep-drift")
        defaults.set(nights, forKey: "noop.html.goal.sleep-nights")
        defaults.set(compositionMetric, forKey: "noop.html.goal.composition-metric")
        defaults.set(targetValue, forKey: "noop.html.goal.target-value")
        let title: String
        switch navigation.selectedGoal {
        case .distance: title = "\(distance) \(activity.lowercased()), finishing comfortably."
        case .pace: title = "\(eventDistance) \(activity.lowercased()) in \(finishTime)."
        case .sleep: title = "Sleep inside \(sleepAnchor), \(nights) nights each week."
        case .composition: title = "\(compositionMetric) at \(targetValue) \(compositionMetric == "Weight" ? "kg" : compositionMetric == "Waist" ? "cm" : "%")."
        }
        defaults.set(title, forKey: "noop.html.goal-draft-title")
        navigation.dismissOverlay()
    }
}

// MARK: - Biomarkers

private struct NoopLabsHome: View {
    @ObservedObject var navigation: NoopNavigation
    @ObservedObject var draft: NoopLabReviewDraft
    @EnvironmentObject private var repo: Repository
    @StateObject private var book = NoopLabBook()
    private var markers: [NoopLabMarker] { NoopLabMarker.all(attaching: book) }
    // A marker with nothing recorded is neither in nor out of its band, so it is counted in
    // neither total. The denominator stays the full nine — the ring reads "of 9 in band"
    // (48-designer-answers-9-september.md §2) because nine is what `labs` keeps, not how many
    // happen to have a value today.
    private var inBandCount: Int { markers.filter(\.isInBand).count }
    /// Seeded, the hero counts band membership, because the fixture carries the design's bands.
    /// In Release there are no bands to count, so it reports what is actually recorded rather than
    /// asserting nine markers sit inside ranges nobody supplied.
    private var heroCount: Int { NoopContentPolicy.allowsPrototypeContent ? inBandCount : recordedCount }
    private var heroCaption: String {
        NoopContentPolicy.allowsPrototypeContent
            ? "of \(markers.count) in band"
            : "of \(markers.count) recorded"
    }
    private var outsideCount: Int { markers.filter(\.isOutside).count }
    private var recordedCount: Int { markers.filter(\.isRecorded).count }
    private var outOfBandLine: String {
        guard recordedCount > 0 else {
            return book.unavailable ? "the Lab Book could not be opened" : "nothing recorded yet"
        }
        guard NoopContentPolicy.allowsPrototypeContent else {
            // No shipped reference ranges, so nothing here may be described as inside or outside
            // one. The line names the sources instead, which is a recorded fact.
            let sources = book.sources
            if sources == ["manual"] { return "entered by hand" }
            if sources.isEmpty { return "recorded on this phone" }
            return "from \(sources.count) source\(sources.count == 1 ? "" : "s"), kept on this phone"
        }
        switch outsideCount {
        case 0: return "every recorded marker inside the lab\u{2019}s band"
        case 1: return "one marker outside the lab\u{2019}s band"
        case let count: return "\(count) markers outside the lab\u{2019}s band"
        }
    }
    private var latestDrawLabel: String? {
        if NoopContentPolicy.allowsPrototypeContent { return "drawn 14 August · Karolinska" }
        // The most recent day a reading is dated to. No clinic: the store records a source, not a
        // laboratory, and naming one would be inventing provenance.
        return book.latestDateLabel
    }
    var body: some View {
        NoopScreen(bottomInset: 118, topInset: 56) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 12) {
                    // 47-act8-goals.md §8.3: `labs` is a second root, not a child of `goal`. Its
                    // chevron reads You and leaves the act. The destination said `goal` — a parent
                    // the user never passed through, and the one case where the button and the
                    // label disagreed.
                    Button { navigation.reset(to: .you) } label: {
                        ZStack {
                            Circle().fill(Color.white.opacity(0.06))
                                .overlay(Circle().stroke(NoopHTMLColor.borderStrong, lineWidth: 0.5))
                            NoopFixedChevron(direction: .left, color: NoopHTMLColor.inkSoft).offset(x: -1)
                        }
                        .frame(width: 34, height: 34)
                    }.buttonStyle(.plain)
                    Text("You").font(NoopHTMLFont.sans(13.5)).foregroundStyle(NoopHTMLColor.copy)
                    Spacer()
                    // Add results enters the picker. It must not raise a photo-source dialogue:
                    // the picker is where the privacy sentence lives, and where the by-hand route
                    // is offered alongside the camera.
                    Button("Add results") { navigation.enterLabPicker() }.buttonStyle(NoopGoalWarmButtonStyle())
                }
                .padding(.horizontal, -2)
                HStack {
                    NoopSectionLabel("Biomarkers")
                    Spacer()
                    if let latestDrawLabel {
                        Text(latestDrawLabel)
                            .font(NoopHTMLFont.sans(10.5))
                            .foregroundStyle(NoopHTMLColor.faint)
                    }
                }
                .padding(.top, 8)
                NoopHelixHero(markers: markers.map { NoopHelixMarker(id: $0.id, outOfBand: $0.isOutside) })
                    .padding(.top, 6)

                // The helix has no centre to hold the count, so the reading sits under it: the
                // numeral on the left, the caption naming what a rung is on the right.
                HStack(alignment: .bottom, spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(heroCount)")
                                .font(NoopHTMLFont.outfit200(38))
                                .tracking(-1.71)
                                .monospacedDigit()
                            Text(heroCaption)
                                .font(NoopHTMLFont.sans(12))
                                .foregroundStyle(Color(hex: 0x7F8A85))
                                .fixedSize()
                        }
                        Text(outOfBandLine)
                            .font(NoopHTMLFont.sans(10.5))
                            .foregroundStyle(NoopHTMLColor.faint)
                            .fixedSize()
                    }
                    Spacer(minLength: 0)
                    Text("each rung is one marker")
                        .font(NoopHTMLFont.sans(10.5))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .multilineTextAlignment(.trailing)
                        .lineSpacing(3)
                }

                VStack(spacing: 0) {
                    ForEach(Array(markers.enumerated()), id: \.offset) { index, marker in
                        Button {
                            navigation.selectedMarker = marker.name
                            navigation.push(.marker)
                        } label: {
                            HStack(spacing: 12) {
                                Circle().fill(marker.color).shadow(color: marker.color, radius: 5).frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(marker.name).font(NoopHTMLFont.sans(13.5))
                                    Text(marker.listDetail)
                                        .font(NoopHTMLFont.sans(11))
                                        .foregroundStyle(Color(hex: 0x7F8A85))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                VStack(alignment: .trailing, spacing: 2) {
                                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        Text(marker.valueText).font(NoopHTMLFont.outfit(20, weight: .light))
                                        Text(marker.shownUnit).font(NoopHTMLFont.sans(11)).foregroundStyle(Color(hex: 0x7F8A85))
                                    }
                                    Text(marker.bandTag)
                                        .font(NoopHTMLFont.sans(10.5, weight: .semibold))
                                        .foregroundStyle(marker.isOutside ? Color(hex: 0xF6DCB4) : NoopHTMLColor.copy)
                                }
                                NoopFixedChevron(direction: .right, color: NoopHTMLColor.faint)
                            }
                            .frame(minHeight: 62)
                            .padding(.vertical, 13)
                        }
                        .buttonStyle(.plain)
                        if index < markers.count - 1 { Divider().overlay(NoopHTMLColor.border) }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(NoopHTMLColor.border, lineWidth: 0.5))
                .padding(.top, 10)

                NoopHTMLCard(radius: 24, padding: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        NoopSectionLabel("Not measured here")
                        Text("Nothing on this screen came off the strap. These are numbers you or your clinic entered, kept beside the wearable data so they can be read together — and dated, because a ferritin from March is not a fact about today.")
                            .font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.copy).lineSpacing(4)
                    }
                }
                .padding(.top, 10)
                Text("Reference bands are the laboratory's, not a target. Out of range is a reason to ask someone, not a verdict — and Noop will not tell you what to do about a blood test.")
                    .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(3)
                    .padding(.horizontal, 2)
                    .padding(.top, 6)
            }
        }
        .task(id: repo.deviceId) {
            // Read once on arrival, and again if the active strap changes. Save calls
            // `repo.refresh()` and resets to `labs`, so returning from `review` re-runs this and
            // the list shows what was actually written rather than what was typed.
            await book.load(store: await repo.storeHandle(), deviceId: repo.deviceId)
        }
    }
}

// MARK: - Picker

/// `goal/picker` — photograph the report (`47-act8-goals.md` §8.6).
///
/// The step the build skipped. Every door into the lab-import family lands here: *Add results* on
/// `labs`, the + on either Act 8 root, and Act 5's *A lab result to import* row. Before this screen
/// existed those doors went straight to `review`, which meant handing someone a set of read values
/// for a photograph they had never taken.
///
/// Two things on this screen are load-bearing rather than decorative. The **privacy sentence** sits
/// here because this is where the camera opens — it is a photograph of a person's blood work, and
/// the promise has to be readable at the moment they decide to take it, not in a settings page. And
/// the **by-hand row** is the route that makes `labs` complete with no Vision work at all, which is
/// why `50-wiring.md` can hold `review`'s OCR without holding the act.
private struct NoopLabPicker: View {
    @ObservedObject var navigation: NoopNavigation
    @ObservedObject var draft: NoopLabReviewDraft
    @State private var photoSource: NoopLabPhotoSource?

    private var seeded: Bool { NoopContentPolicy.allowsPrototypeContent }

    var body: some View {
        NoopScreen(bottomInset: 116, topInset: 56) {
            VStack(alignment: .leading, spacing: 0) {
                header
                // NoopScreen already frames content at `viewportWidth - 40` with 20 pt of its own
                // horizontal padding, which is the HTML's `padding: 6px 20px 0`. Adding another 20
                // here left 322 pt and the 110 pt tile row wrapped to two columns instead of three.
                VStack(alignment: .leading, spacing: 13) {
                    instruction
                    takePhotoButton
                    if seeded { recentTiles } else { chooseFromPhotosRow }
                    byHandRow
                    footnote
                }
                .padding(.top, 6)
            }
        }
        // No confirmation dialogue here. This screen *is* the source chooser — camera, the tiles,
        // or the by-hand row — so a second sheet asking the same question is the defect the picker
        // was written to remove.
        .sheet(item: $photoSource) { source in
            NoopLabPhotoPicker(source: source) { photo in
                photoSource = nil
                if let photo { accept(photo) }
            }
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button { navigation.back(or: .labs) } label: {
                ZStack {
                    Circle().fill(Color.white.opacity(0.06))
                        .overlay(Circle().stroke(NoopHTMLColor.borderStrong, lineWidth: 0.5))
                    NoopFixedChevron(direction: .left, color: NoopHTMLColor.inkSoft).offset(x: -1)
                }
                .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Biomarkers")
            Text("Biomarkers").font(NoopHTMLFont.sans(13.5)).foregroundStyle(NoopHTMLColor.copy)
            Spacer()
        }
        .padding(.horizontal, -2)   // NoopScreen gives 20; the HTML header sits at 18
        .padding(.bottom, 6)
    }

    private var instruction: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Photograph the report")
                .font(NoopHTMLFont.outfit(25, weight: .light))
                .tracking(-0.75)          // −.03em × 25 (00-RULES §1: tracking is points, not ems)
                .foregroundStyle(NoopHTMLColor.ink)
                .lineSpacing(NoopSpecType.lineSpacing(size: 25, cssLineHeight: 1.24, face: NoopSpecType.Face.outfitLight))
                .fixedSize(horizontal: false, vertical: true)
            Text("One page at a time, flat and filling the frame. Reading happens on this phone — the photo never leaves it, and it is dropped when you are done.")
                .font(NoopHTMLFont.sans(12.5))
                .foregroundStyle(NoopHTMLColor.muted)
                .lineSpacing(NoopSpecType.lineSpacing(size: 12.5, cssLineHeight: 1.6, face: NoopSpecType.Face.sansRegular))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var takePhotoButton: some View {
        Button {
            photoSource = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .library
        } label: {
            HStack(spacing: 9) {
                NoopCanonicalGlyph(name: .camera, size: 19, color: Color(hex: 0x1E1405))
                Text("Take a photo")
                    .font(NoopHTMLFont.sans(15, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x1E1405))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(NoopHTMLColor.warm)   // #F2B45C — Act 8 lab chrome, not the attention amber
            )
        }
        .buttonStyle(.plain)
    }

    // `[bound]` in the spec: recent camera-roll candidates, so a report photographed earlier does
    // not need re-taking. There is no PhotoKit fetch behind them yet, so the tiles render only
    // under `--demo-seed` — a release build shows no tile row rather than six invented dates
    // (00-RULES §0a). Tapping one opens the library, which is what the row promises either way.
    private var recentTiles: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Or pick one you already have")
                .font(NoopHTMLFont.sans(10, weight: .semibold))
                .tracking(1.4)            // .14em × 10
                .textCase(.uppercase)
                .foregroundStyle(Color(hex: 0x6C7570))
                .padding(.top, 6)
                .padding(.horizontal, 2)
                .padding(.bottom, 9)
            NoopLabRecentTileRow { photoSource = .library }
        }
    }

    /// Until real PhotoKit thumbnails are bound, production exposes the real library picker
    /// directly instead of drawing the prototype's six invented report tiles and dates.
    private var chooseFromPhotosRow: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Or pick one you already have")
                .font(NoopHTMLFont.sans(10, weight: .semibold))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Color(hex: 0x6C7570))
                .padding(.horizontal, 2)
            Button { photoSource = .library } label: {
                HStack(spacing: 10) {
                    NoopCanonicalGlyph(name: .file, size: 19, color: NoopHTMLColor.warm)
                    Text("Choose from Photos")
                        .font(NoopHTMLFont.sans(13.5, weight: .medium))
                    Spacer()
                    NoopFixedChevron(direction: .right, color: NoopHTMLColor.faint)
                }
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var byHandRow: some View {
        Button {
            draft.beginManual()
            // Replace Picker rather than stacking Review on top of it. Both the visible chevron
            // and the leading-edge swipe on Review return directly to Biomarkers in the HTML.
            navigation.replace(with: .review)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Enter results by hand")
                        .font(NoopHTMLFont.sans(13.5))
                        .foregroundStyle(Color(hex: 0xEDF1EF))
                    Text("All nine markers, no photo. Every row is optional, and the confirm step drops its strips because there is no page to check against.")
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(Color(hex: 0x7F8A85))
                        .lineSpacing(NoopSpecType.lineSpacing(size: 11.5, cssLineHeight: 1.45, face: NoopSpecType.Face.sansRegular))
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                NoopFixedChevron(direction: .right, color: NoopHTMLColor.faint)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(NoopHTMLColor.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Enter results by hand")
    }

    private var footnote: some View {
        Text("Cancelling here adds nothing, and a photo you back out of is not remembered.")
            .font(NoopHTMLFont.sans(11.5))
            .foregroundStyle(Color(hex: 0x57605C))
            .lineSpacing(NoopSpecType.lineSpacing(size: 11.5, cssLineHeight: 1.6, face: NoopSpecType.Face.sansRegular))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 2)
            .padding(.top, 2)
    }

    private func accept(_ photo: NoopPickedLabPhoto) {
        guard draft.begin(photo) else { return }
        // Review's canonical parent is Labs, not Picker. Replacing leaves [.labs, .review], so
        // the interactive back gesture and the chevron walk the same map.
        navigation.replace(with: .review)
        Task { await draft.read(photo.data) }
    }
}

/// The page-shaped tiles under *Or pick one you already have*. 110 × 132 at radius 14, with the
/// ruled-paper gradient rotated a degree or so each way so a row of them does not read as a grid of
/// identical rectangles.
private struct NoopLabRecentTileRow: View {
    let onPick: () -> Void

    private let stamps = ["Today", "Today", "14 Aug", "14 Aug", "2 Jul", "2 Jul"]

    var body: some View {
        let columns = [GridItem(.adaptive(minimum: 110, maximum: 110), spacing: 7, alignment: .leading)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 7) {
            ForEach(Array(stamps.enumerated()), id: \.offset) { index, stamp in
                Button(action: onPick) {
                    ZStack(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(hex: 0x101413))
                        page(index: index)
                        Text(stamp)
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .tracking(0.54)
                            .foregroundStyle(Color(hex: 0xEDF1EF))
                            .shadow(color: .black.opacity(0.8), radius: 6, y: 1)
                            .padding(.leading, 8)
                            .padding(.bottom, 7)
                    }
                    .frame(width: 110, height: 132)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("A photo from \(stamp)")
            }
        }
    }

    private func page(index: Int) -> some View {
        LinearGradient(
            colors: [Color(hex: 0xDFD9CB), Color(hex: 0xBEB6A3)],
            startPoint: .init(x: 0.13, y: 0), endPoint: .init(x: 0.87, y: 1)   // 163°
        )
        .overlay(
            GeometryReader { proxy in
                Path { path in
                    var y: CGFloat = 0
                    while y < proxy.size.height {
                        path.addRect(CGRect(x: 0, y: y, width: proxy.size.width, height: 1))
                        y += 7
                    }
                }
                .fill(Color(hex: 0x1E1A14).opacity(0.16))
            }
        )
        .rotationEffect(.degrees(index % 3 == 1 ? 1.4 : -1.2))
        .padding(index % 2 == 1 ? EdgeInsets(top: -8, leading: -12, bottom: -8, trailing: -12)
                                : EdgeInsets(top: -10, leading: -8, bottom: -10, trailing: -8))
    }
}

private struct NoopLabReview: View {
    @ObservedObject var navigation: NoopNavigation
    @ObservedObject var draft: NoopLabReviewDraft
    @EnvironmentObject private var repo: Repository
    @State private var errorID: String?
    @State private var saving = false
    @State private var saveError: String?
    @State private var isChoosingSource = false
    @State private var photoSource: NoopLabPhotoSource?
    @State private var viewerTarget: NoopLabViewerTarget?

    var body: some View {
        NoopScreen(bottomInset: 150, topInset: 56) {
            VStack(alignment: .leading, spacing: 0) {
                reviewHeader
                VStack(alignment: .leading, spacing: 12) {
                    if let image = draft.image {
                        NoopLabImageCard(
                            image: image,
                            state: draft.state,
                            filename: draft.filename,
                            reportDate: draft.captionDate,
                            retake: { isChoosingSource = true },
                            open: { viewerTarget = NoopLabViewerTarget(rect: nil) }
                        )
                    }

                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            NoopSectionLabel("Nothing is stored yet", color: Color(hex: 0xF3C888)); Spacer()
                            Text(reviewPill.uppercased())
                                .font(NoopHTMLFont.sans(9, weight: .semibold))
                                .tracking(1.08)
                                .foregroundStyle(Color(hex: 0xF3C888))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color(hex: 0xF3C888).opacity(0.45), lineWidth: 0.5)
                                )
                        }
                        Text(reviewTitle)
                            .font(NoopHTMLFont.outfit(25, weight: .light))
                            .tracking(-0.75)
                            .lineSpacing(NoopSpecType.lineSpacing(size: 25, cssLineHeight: 1.24, face: NoopSpecType.Face.outfitLight))
                        Text(reviewInstructions)
                            .font(NoopHTMLFont.sans(12.5))
                            .foregroundStyle(NoopHTMLColor.copy)
                            .lineSpacing(NoopSpecType.lineSpacing(size: 12.5, cssLineHeight: 1.6, face: NoopSpecType.Face.sansRegular))
                    }
                    if let saveError {
                        Text(saveError)
                            .font(NoopHTMLFont.sans(11.5))
                            .foregroundStyle(NoopHTMLColor.red)
                            .lineSpacing(3)
                    }

                    VStack(spacing: 9) {
                        ForEach(Array($draft.candidates.enumerated()), id: \.element.id) { index, $candidate in
                            NoopOCRCandidateCard(
                                candidate: $candidate,
                                image: draft.image,
                                reportDate: draft.captionDate,
                                isManual: draft.isManual,
                                error: errorID == candidate.id ? "Enter a numeric value." : nil,
                                openSource: { rect in viewerTarget = NoopLabViewerTarget(rect: rect) },
                                beginEditing: { beginEditing(candidateID: candidate.id) }
                            ) {
                                if validate(candidate) {
                                    candidate.status = .corrected
                                    candidate.editing = false
                                    errorID = nil
                                } else {
                                    errorID = candidate.id
                                }
                            }
                            .transition(.opacity)
                            .animation(.linear(duration: 0.16).delay(Double(index) * 0.024), value: draft.candidates.count)
                        }
                    }

                    NoopHTMLCard(radius: 24, padding: 16) {
                        VStack(alignment: .leading, spacing: 9) {
                            NoopSectionLabel("What happens to the file")
                            ForEach(fileFacts, id: \.self) { fact in
                                NoopLabFileFact(fact)
                            }
                        }
                    }
                }
                .padding(.top, 6)
            }
        }
        // Keep the fixed action bar out of the scroll view's layout calculation. As a ZStack
        // sibling its intrinsic width expands the root and the bar overhangs the screen —
        // the same trap Act 7's composer documents.
        .overlay(alignment: .bottom) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(confirmedCount == 0 ? "Nothing confirmed yet" : "\(confirmedCount) \(confirmedCount == 1 ? "result" : "results") will be stored")
                        .font(NoopHTMLFont.sans(12.5, weight: .semibold))
                    Text(reviewNote).font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.copy)
                }
                Spacer()
                Button(saving ? "Saving…" : "Save") { Task { await save() } }
                    .font(NoopHTMLFont.sans(13, weight: .semibold))
                    .foregroundStyle(confirmedCount > 0 ? Color(hex: 0x1E1405) : NoopHTMLColor.faint)
                    .padding(.horizontal, 20).frame(height: 40)
                    .background(confirmedCount > 0 ? Color(hex: 0xF2B45C) : Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 13))
                    .disabled(confirmedCount == 0 || saving)
            }
            .padding(.horizontal, 16).frame(height: 64)
            .background(Color(hex: 0x171C1A, alpha: 0.92), in: RoundedRectangle(cornerRadius: 22))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.45), radius: 13, y: 4)
            .padding(.horizontal, 14).padding(.bottom, 92)
        }
        .noopLabPhotoDoor(
            isChoosingSource: $isChoosingSource,
            source: $photoSource,
            title: retakeDoorTitle,
            onPhoto: acceptRetake
        )
        .fullScreenCover(item: $viewerTarget) { target in
            if let image = draft.image {
                NoopLabImageViewer(image: image, focusRect: target.rect) {
                    viewerTarget = nil
                }
            }
        }
        .onAppear(perform: ensureValidArrival)
    }

    private var reviewHeader: some View {
        HStack(spacing: 12) {
            Button(action: leaveWithoutSaving) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.06))
                        .overlay(Circle().stroke(NoopHTMLColor.borderStrong, lineWidth: 0.5))
                    NoopFixedChevron(direction: .left, color: NoopHTMLColor.inkSoft).offset(x: -1)
                }
                .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Biomarkers")
            Text("Biomarkers")
                .font(NoopHTMLFont.sans(13.5))
                .foregroundStyle(NoopHTMLColor.copy)
            Spacer()
        }
        .padding(.horizontal, -2)
        .padding(.bottom, 6)
    }

    private var confirmedCount: Int { draft.candidates.filter { $0.status == .confirmed || $0.status == .corrected }.count }
    private var discardedCount: Int { draft.candidates.filter { $0.status == .discarded }.count }
    private var pendingCount: Int { draft.candidates.filter { $0.status == .pending }.count }

    private var retakeDoorTitle: String {
        guard confirmedCount > 0 else { return "Replace report photo" }
        let word = switch confirmedCount {
        case 1: "one"
        case 2: "two"
        case 3: "three"
        case 4: "four"
        case 5: "five"
        case 6: "six"
        case 7: "seven"
        case 8: "eight"
        case 9: "nine"
        default: "\(confirmedCount)"
        }
        return "This clears the \(word) you have checked."
    }

    private var reviewPill: String {
        if draft.isManual { return "entered, not measured" }
        return switch draft.state {
        case .reading: "reading locally"
        case .nothingLegible: "nothing read"
        case .empty, .read: "read, not measured"
        }
    }

    private var reviewTitle: String {
        if draft.isManual {
            return "Nine fields, and nothing filled in for you. Type the ones your sheet has."
        }
        return switch draft.state {
        case .reading:
            "Reading the page on this phone."
        case .nothingLegible:
            "No candidates were read from this photo."
        case .empty:
            "Choose a report photo to begin."
        case .read:
            "\(candidateCountWord) candidates were read off your photo. Confirm the ones that are right."
        }
    }

    private var candidateCountWord: String {
        let count = draft.candidates.count
        return switch count {
        case 0: "No"
        case 1: "One"
        case 2: "Two"
        case 3: "Three"
        case 4: "Four"
        case 5: "Five"
        case 6: "Six"
        case 7: "Seven"
        case 8: "Eight"
        case 9: "Nine"
        default: "\(count)"
        }
    }

    private var reviewInstructions: String {
        if draft.isManual {
            return "The nine markers Noop keeps, in the order a printed panel runs them. No photo, so no strips and no confidence: there is no page to check a number against, and the app will not dress a typed value as a read one. Every row is optional — leave one out and it is not stored."
        }
        return switch draft.state {
        case .reading:
            "Read on this phone, nothing uploaded. Candidates will appear here when the read is done."
        case .nothingLegible:
            "Read on this phone, nothing uploaded. Retake with another photo; nothing from this read will be kept."
        case .empty:
            "Nothing is uploaded or stored before you confirm it."
        case .read:
            "Read on this phone, nothing uploaded. Each row shows the strip of the page it came from — check the number against it, fix it if the read is wrong, and discard anything you would rather not keep."
        }
    }

    private var fileFacts: [String] {
        if draft.isManual {
            return [
                "What you type is stored when you save it, and discarded rows are not remembered — not as a value, and not as “you declined this”.",
                "No photograph was taken and none is needed. There is no page to check these against, so no row claims one.",
                "Nothing was uploaded. This is a local entry into your own lab book."
            ]
        }
        return [
            "The photo and the text read from it are deleted when you leave this screen, whatever you decide.",
            "Discarded rows are not remembered — not as a value, and not as “you declined this”.",
            "Nothing was uploaded. The read happened on this phone, and it is the one part of the app that would rather be slow than remote."
        ]
    }

    private var reviewNote: String {
        if confirmedCount == 0 {
            return draft.isManual
                ? "Type a value and use it — Save does nothing until then"
                : "Confirm or fix a row — Save does nothing until then"
        }
        if pendingCount > 0 {
            return "\(pendingCount) still to check · \(discardedCount) discarded"
        }
        if let date = draft.captionDate {
            return "\(discardedCount) discarded · the rest dated \(date)"
        }
        return "\(discardedCount) discarded"
    }

    private func validate(_ candidate: NoopOCRCandidate) -> Bool {
        let text = candidate.draftValue.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(text) else {
            return false
        }
        return value.isFinite
    }

    private func beginEditing(candidateID: String) {
        for index in draft.candidates.indices {
            draft.candidates[index].editing = false
        }
        guard let index = draft.candidates.firstIndex(where: { $0.id == candidateID }) else { return }
        draft.candidates[index].draftValue = draft.isManual ? "" : draft.candidates[index].value
        draft.candidates[index].editing = true
        errorID = nil
    }

    @MainActor
    private func save() async {
        guard confirmedCount > 0, !saving else { return }
        saving = true
        saveError = nil
        let confirmed = draft.candidates.filter { $0.status == .confirmed || $0.status == .corrected }
        guard let day = draft.reportDay else {
            saving = false
            saveError = "No report date was read, so these results cannot be dated or saved yet."
            return
        }
        guard let store = await repo.storeHandle() else {
            saving = false
            saveError = "Couldn’t open the local Lab Book. Nothing was saved."
            return
        }

        let epoch = LabBookFormat.noonEpoch(day)
        let rows = confirmed.compactMap { candidate -> LabMarkerRow? in
            let definition = markerDefinition(for: candidate)
            let rawValue = (candidate.status == .corrected ? candidate.draftValue : candidate.value)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let value = Double(rawValue.replacingOccurrences(of: ",", with: ".")),
                  let definition else { return nil }
            return LabMarkerRow(
                id: "\(definition.key)-\(epoch)-\(UUID().uuidString.prefix(8))",
                deviceId: repo.deviceId,
                markerKey: definition.key,
                category: definition.category.rawValue,
                day: day,
                takenAt: epoch,
                value: value,
                valueText: nil,
                unit: candidate.unit,
                source: draft.isManual ? "manual" : LabReportTextImport.sourceId,
                note: draft.isManual
                    ? "Entered manually by the user."
                    : (candidate.status == .corrected ? "Corrected by the user after an on-device document read." : nil),
                referenceText: nil
            )
        }
        guard rows.count == confirmed.count else {
            saving = false
            saveError = "One confirmed row could not be read as a known marker and numeric value. Nothing was saved."
            return
        }

        do {
            try await store.upsertLabMarkers(rows)
            let defaults = UserDefaults.standard
            for candidate in confirmed {
                let value = candidate.status == .corrected ? candidate.draftValue : candidate.value
                defaults.set(
                    value.trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: ",", with: "."),
                    forKey: "noop.html.marker.\(candidate.name).value"
                )
            }
            if let captionDate = draft.captionDate {
                defaults.set(captionDate, forKey: "noop.html.last-lab-draw")
                for candidate in confirmed {
                    defaults.set(captionDate, forKey: "noop.html.marker.\(candidate.name).date")
                }
            }
            await repo.refresh()
            draft.scrub()
            if navigation.route == .review { navigation.reset(to: .labs) }
        } catch {
            saveError = "Couldn’t save these readings to the local Lab Book. Nothing was changed."
        }
        saving = false
    }

    private func markerDefinition(for candidate: NoopOCRCandidate) -> MarkerDefinition? {
        if let definition = MarkerCatalog.definition(for: candidate.markerKey) {
            return definition
        }
        switch candidate.markerKey {
        case "custom_apob":
            return MarkerCatalog.custom(
                key: candidate.markerKey,
                displayName: candidate.name,
                unit: candidate.unit,
                decimals: 2
            )
        case "custom_creatine_kinase":
            return MarkerCatalog.custom(
                key: candidate.markerKey,
                displayName: candidate.name,
                unit: candidate.unit,
                decimals: 0
            )
        default:
            return nil
        }
    }

    private func ensureValidArrival() {
        #if DEBUG
        if NoopContentPolicy.allowsPrototypeContent,
           ProcessInfo.processInfo.arguments.contains("--noop-labs-manual"),
           draft.origin == nil {
            draft.beginManual()
        } else {
            draft.seedDemoReviewIfNeeded()
        }
        #endif
        if draft.origin == nil || (!draft.isManual && draft.image == nil) {
            navigation.reset(to: .labs)
        }
    }

    private func leaveWithoutSaving() {
        draft.scrub()
        errorID = nil
        saveError = nil
        navigation.reset(to: .labs)
    }

    private func acceptRetake(_ photo: NoopPickedLabPhoto) {
        guard draft.begin(photo) else { return }
        errorID = nil
        saveError = nil
        Task { await draft.read(photo.data) }
    }
}

private struct NoopLabViewerTarget: Identifiable {
    let id = UUID()
    let rect: CGRect?
}

private struct NoopLabImageCard: View {
    let image: UIImage
    let state: NoopLabReviewDraft.ReadState
    let filename: String
    let reportDate: String?
    let retake: () -> Void
    let open: () -> Void

    var body: some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 132)
                .blur(radius: state == .nothingLegible ? 2.4 : 0)
                .clipped()

            if state == .nothingLegible {
                Color(hex: 0x040605, alpha: 0.42)
            }

            if state == .reading {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    GeometryReader { proxy in
                        let phase = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.4) / 1.4
                        LinearGradient(
                            colors: [Color.white.opacity(0.03), Color.white.opacity(0.09), Color.white.opacity(0.03)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: proxy.size.width * 1.7)
                        .offset(x: -proxy.size.width * 0.7 + proxy.size.width * CGFloat(phase) * 1.7)
                    }
                }
                Text("READING THE PAGE")
                    .font(NoopHTMLFont.sans(10.5, weight: .semibold))
                    .tracking(1.05)
                    .foregroundStyle(Color(hex: 0x6C7570))
            } else {
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [Color(hex: 0x040605, alpha: 0), Color(hex: 0x040605, alpha: 0.90)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 52)
                }

                HStack(spacing: 10) {
                    Text(state == .nothingLegible ? "Nothing legible on this one" : caption)
                        .font(NoopHTMLFont.sans(10.5))
                        .foregroundStyle(state == .nothingLegible ? Color(hex: 0xF3C888) : NoopHTMLColor.inkSoft)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 0)
                    Button("Retake", action: retake)
                        .font(NoopHTMLFont.sans(11, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xF6DCB4))
                        .buttonStyle(.plain)
                }
                .padding(.leading, 12)
                .padding(.trailing, 10)
                .padding(.bottom, 9)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .frame(height: 132)
        .background(Color(hex: 0x101413))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(state == .nothingLegible ? NoopHTMLColor.warm.opacity(0.28) : Color.white.opacity(0.09), lineWidth: 0.5)
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture {
            guard state != .reading else { return }
            open()
        }
    }

    private var caption: String {
        ([filename] + (reportDate.map { [$0] } ?? []) + ["read on this phone"])
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

private struct NoopLabSourceStrip: View {
    let image: UIImage
    let rect: CGRect

    var body: some View {
        GeometryReader { proxy in
            let crop = padded(rect)
            let imageWidth = max(1, image.size.width)
            let imageHeight = max(1, image.size.height)
            let scale = proxy.size.height / max(1, crop.height * imageHeight)
            let renderedWidth = imageWidth * scale
            let renderedHeight = imageHeight * scale
            let rawX = proxy.size.width - crop.maxX * renderedWidth
            let rawY = -crop.minY * renderedHeight
            let x = min(0, max(proxy.size.width - renderedWidth, rawX))
            let y = min(0, max(proxy.size.height - renderedHeight, rawY))

            Image(uiImage: image)
                .resizable()
                .frame(width: renderedWidth, height: renderedHeight)
                .offset(x: x, y: y)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 132, height: 26)
        .background(Color(hex: 0x0C0E0D))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
    }

    private func padded(_ source: CGRect) -> CGRect {
        let amount = source.height * 0.35
        let expanded = source.insetBy(dx: -amount, dy: -amount)
        return expanded.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
    }
}

private struct NoopLabImageViewer: View {
    let image: UIImage
    let focusRect: CGRect?
    let close: () -> Void
    @State private var committedScale: CGFloat = 1
    @State private var liveMagnification: CGFloat = 1
    @State private var committedOffset: CGSize = .zero
    @State private var liveDrag: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            let safeWidth = max(1, proxy.size.width)
            let safeHeight = max(1, proxy.size.height)
            let imageAspect = max(0.001, image.size.width / max(1, image.size.height))
            let viewportAspect = safeWidth / safeHeight
            let fittedSize = imageAspect > viewportAspect
                ? CGSize(width: safeWidth, height: safeWidth / imageAspect)
                : CGSize(width: safeHeight * imageAspect, height: safeHeight)
            let focus = paddedFocusRect
            let focusScale = focus.map {
                min(8, max(1, min(
                    (safeWidth - 40) / max(1, $0.width * fittedSize.width),
                    (safeHeight - 110) / max(1, $0.height * fittedSize.height)
                )))
            } ?? 1
            let scale = min(10, max(1, focusScale * committedScale * liveMagnification))
            let focusOffset = focus.map {
                CGSize(
                    width: (0.5 - $0.midX) * fittedSize.width * scale,
                    height: (0.5 - $0.midY) * fittedSize.height * scale
                )
            } ?? .zero

            ZStack(alignment: .topTrailing) {
                Color(hex: 0x050706).ignoresSafeArea()
                Image(uiImage: image)
                    .resizable()
                    .frame(width: fittedSize.width, height: fittedSize.height)
                    .scaleEffect(scale)
                    .offset(
                        x: focusOffset.width + committedOffset.width + liveDrag.width,
                        y: focusOffset.height + committedOffset.height + liveDrag.height
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        MagnifyGesture()
                            .onChanged { liveMagnification = $0.magnification }
                            .onEnded {
                                committedScale = min(10 / focusScale, max(1 / focusScale, committedScale * $0.magnification))
                                liveMagnification = 1
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { liveDrag = $0.translation }
                            .onEnded {
                                committedOffset.width += $0.translation.width
                                committedOffset.height += $0.translation.height
                                liveDrag = .zero
                            }
                    )

                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(NoopHTMLColor.ink)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.14), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(.top, 54)
                .padding(.trailing, 18)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var paddedFocusRect: CGRect? {
        guard let focusRect else { return nil }
        let amount = focusRect.height * 0.35
        return focusRect.insetBy(dx: -amount, dy: -amount)
            .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
    }
}

private struct NoopOCRCandidateCard: View {
    @Binding var candidate: NoopOCRCandidate
    let image: UIImage?
    let reportDate: String?
    let isManual: Bool
    let error: String?
    let openSource: (CGRect) -> Void
    let beginEditing: () -> Void
    let saveCorrection: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(candidate.shownName)
                        .font(NoopHTMLFont.sans(13.5))
                        .lineLimit(2)
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(candidate.shownValue)
                            .font(NoopHTMLFont.outfit(30, weight: .light))
                            .tracking(-0.9)
                            .monospacedDigit()
                            .foregroundStyle(candidate.shownValue == "—" ? Color(hex: 0x3F4744) : NoopHTMLColor.ink)
                        Text(candidate.shownUnit)
                            .font(NoopHTMLFont.sans(11.5))
                            .foregroundStyle(Color(hex: 0x7F8A85))
                    }
                    if isManual {
                        Text(candidate.status == .corrected
                            ? "typed in by you — there is no page to check it against"
                            : "not filled in")
                            .font(NoopHTMLFont.sans(11))
                            .foregroundStyle(Color(hex: 0x7F8A85))
                            .lineSpacing(3)
                    } else if candidate.lowConfidence {
                        Text("Check this")
                            .font(NoopHTMLFont.sans(11, weight: .semibold))
                            .foregroundStyle(Color(hex: 0xF3C888))
                            .padding(.horizontal, 7)
                            .frame(height: 22)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: 0xF3C888).opacity(0.45), lineWidth: 0.5))
                    } else {
                        Text("clear read")
                            .font(NoopHTMLFont.sans(11))
                            .foregroundStyle(Color(hex: 0x7F8A85))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !isManual {
                    VStack(alignment: .trailing, spacing: 5) {
                        if let image, let rect = candidate.sourceRect {
                            Button { openSource(rect) } label: {
                                NoopLabSourceStrip(image: image, rect: rect)
                            }
                            .buttonStyle(.plain)
                            Text("FROM THE PAGE")
                                .font(NoopHTMLFont.sans(9.5, weight: .semibold))
                                .tracking(0.95)
                                .foregroundStyle(NoopHTMLColor.faint)
                        } else {
                            Text(candidate.raw)
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundStyle(NoopHTMLColor.inkSoft)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .padding(.horizontal, 8)
                                .frame(width: 132, height: 26)
                                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.09), lineWidth: 0.5))
                            Text("AS READ")
                                .font(NoopHTMLFont.sans(9.5, weight: .semibold))
                                .tracking(0.95)
                                .foregroundStyle(NoopHTMLColor.faint)
                        }
                    }
                    .frame(width: 132)
                }
            }

            if candidate.editing {
                VStack(alignment: .leading, spacing: 10) {
                    Text(isManual ? "Type the value from your sheet" : "Correct the value")
                        .font(NoopHTMLFont.sans(10, weight: .semibold))
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Color(hex: 0xF3C888))
                    HStack(spacing: 8) {
                        TextField(
                            isManual ? "e.g. \(candidate.example ?? "")" : candidate.value,
                            text: $candidate.draftValue
                        )
                        .keyboardType(.decimalPad)
                        Text(candidate.unit)
                            .font(NoopHTMLFont.sans(12))
                            .foregroundStyle(Color(hex: 0x7F8A85))
                    }
                    Text(editNote)
                        .font(NoopHTMLFont.sans(11))
                        .foregroundStyle(Color(hex: 0x7F8A85))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    if let error { Text(error).font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.red) }
                    HStack(spacing: 7) {
                        Button("Use this value", action: saveCorrection)
                            .buttonStyle(NoopOCRActionStyle(primary: true, enabled: hasDraftValue))
                            .disabled(!hasDraftValue)
                        Button("Cancel") { candidate.editing = false }.buttonStyle(NoopOCRActionStyle())
                    }
                }
                .textFieldStyle(NoopOCRTextFieldStyle())
                .padding(.horizontal, 13)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(Color(hex: 0xF2B45C).opacity(0.32), lineWidth: 0.5)
                )
            } else if candidate.status == .pending {
                if isManual {
                    HStack(spacing: 7) {
                        Button("Type it in", action: beginEditing)
                            .buttonStyle(NoopOCRActionStyle(primary: true))
                            .frame(maxWidth: .infinity)
                        Button("Leave it out") { candidate.status = .discarded }
                            .buttonStyle(NoopOCRActionStyle())
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    GeometryReader { proxy in
                        let unit = max(0, proxy.size.width - 14) / 3.3
                        HStack(spacing: 7) {
                            Button("Confirm") { candidate.status = .confirmed }
                                .buttonStyle(NoopOCRActionStyle(primary: true))
                                .frame(width: unit * 1.3)
                            Button("Fix", action: beginEditing)
                                .buttonStyle(NoopOCRActionStyle())
                                .frame(width: unit)
                            Button("Discard") { candidate.status = .discarded }
                                .buttonStyle(NoopOCRActionStyle())
                                .frame(width: unit)
                        }
                    }
                    .frame(height: 40)
                }
            } else {
                HStack {
                    Text(candidate.status.message(
                        reportDate: reportDate,
                        isManual: isManual,
                        value: candidate.shownValue,
                        unit: candidate.unit
                    ))
                        .font(NoopHTMLFont.sans(12))
                        .foregroundStyle(NoopHTMLColor.inkSoft)
                    Spacer()
                    Button("Undo") { candidate.status = .pending }
                        .font(NoopHTMLFont.sans(11.5, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xF6DCB4))
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 40)
                .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.09), lineWidth: 0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 15)
        .padding(.bottom, 16)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(candidate.lowConfidence && !isManual ? Color(hex: 0xF3C888).opacity(0.34) : Color.white.opacity(0.07), lineWidth: 0.5)
        )
    }

    private var hasDraftValue: Bool {
        !candidate.draftValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var editNote: String {
        if isManual {
            return "Nothing is filled in for you and there is no page to check it against, so the row is stored as entered rather than read. Leave it out and nothing is stored."
        }
        let read = candidate.readToken ?? (candidate.raw.isEmpty ? candidate.value : candidate.raw)
        return "Read as “\(read)”. What you type replaces it, and the row is stored as corrected — not as read."
    }
}

private struct NoopMarkerDetail: View {
    @ObservedObject var navigation: NoopNavigation
    @EnvironmentObject private var repo: Repository
    @StateObject private var book = NoopLabBook()
    private var marker: NoopLabMarker {
        let all = NoopLabMarker.all(attaching: book)
        return all.first { $0.name == navigation.selectedMarker } ?? all[0]
    }
    var body: some View {
        NoopScreen(bottomInset: 118, topInset: 56) {
            VStack(alignment: .leading, spacing: 12) {
                NoopBackHeader(label: "Biomarkers") { navigation.back(or: .labs) }
                    .padding(.horizontal, -2)
                    .padding(.bottom, -14)
                VStack(alignment: .leading, spacing: 0) {
                    Text(marker.name).font(NoopHTMLFont.outfit(25, weight: .regular)).tracking(-0.6)
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Text(marker.valueText).font(NoopHTMLFont.outfit200(54)).tracking(-2.4)
                        Text(marker.unit).font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.copy)
                        NoopPill(text: marker.detailBandTag, color: marker.color)
                    }
                    Text(marker.readCopy).font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.copy).lineSpacing(4)
                }

                NoopHTMLCard(radius: 24, padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            NoopSectionLabel(NoopContentPolicy.allowsPrototypeContent ? "Four draws" : "Recorded result")
                            Spacer()
                            // The eyebrow may only promise shading where a band is actually drawn.
                            Text(marker.chartBand == nil ? "dated results" : "shaded — the lab's band")
                                .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.faint)
                        }
                        NoopMarkerTrend(marker: marker)
                        if NoopContentPolicy.allowsPrototypeContent {
                            HStack { Text("Jun 25"); Spacer(); Text("Nov 25"); Spacer(); Text("Mar 26"); Spacer(); Text("14 Aug") }
                                .font(NoopHTMLFont.sans(10.5)).foregroundStyle(NoopHTMLColor.faint)
                        } else if let date = marker.recordedDateText {
                            HStack { Spacer(); Text(date) }
                                .font(NoopHTMLFont.sans(10.5)).foregroundStyle(NoopHTMLColor.faint)
                        }
                        Text(marker.bandNote)
                            .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.copy).lineSpacing(3)
                    }
                    .padding(.bottom, 5)
                }
                .padding(.top, 6)

                if NoopContentPolicy.allowsPrototypeContent {
                    NoopHTMLCard(radius: 24, padding: 16) {
                        VStack(alignment: .leading, spacing: 11) {
                            NoopSectionLabel("What it sits next to")
                            NoopMarkerBeside("Haemoglobin, same draw", "141 g/L")
                            NoopMarkerBeside("Weekly distance that month", "34 km")
                            NoopMarkerBeside("Nights over your need, that month", "17 of 31")
                            Text("Shown together because they were drawn on the same day, not because Noop found a relationship. It has four points — that is not enough to claim one.")
                                .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.copy).lineSpacing(3)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    NoopSectionLabel("Worth a retest", color: Color(hex: 0xF3C888))
                    Text(marker.retestCopy)
                        .font(NoopHTMLFont.sans(12.5))
                        .foregroundStyle(Color(hex: 0xDCE3E0))
                        .lineSpacing(4)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(NoopHTMLColor.warm.opacity(0.08), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(NoopHTMLColor.warm.opacity(0.26), lineWidth: 0.5))
                Text(marker.chartBand == nil
                     ? "Entered by you, from a laboratory report. Noop stores and dates it, shows any range you recorded with it, and stops there — it is not a diagnosis and not advice."
                     : "Entered by you, from a laboratory report. Noop stores and dates it, draws it against the band the lab gave, and stops there — it is not a diagnosis and not advice.")
                    .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(3)
                    .padding(.horizontal, 2)
                    .padding(.top, -10)
            }
        }
        .task(id: repo.deviceId) {
            await book.load(store: await repo.storeHandle(), deviceId: repo.deviceId)
        }
    }
}

// MARK: - Act 8 data and components

private struct NoopGoalWaypoint { let title: String; let detail: String; let tag: String; let done: Bool }
private struct NoopGoalEvidence: Identifiable {
    let id: String; let name: String; let value: String; let note: String; let progress: Double
    static let all: [NoopGoalEvidence] = [
        .init(id: "long", name: "Longest run this year", value: "12 km", note: "the route needs 18 km on the way", progress: 0.66),
        .init(id: "week", name: "Weekly distance now", value: "34 km", note: "the route peaks at 55 km", progress: 0.62),
        .init(id: "time", name: "Weeks available", value: "11", note: "a gentle build wants 14", progress: 0.78)
    ]
}
private enum NoopGoalFeasibilityKind { case realistic, ambitious, unrealistic }
private struct NoopGoalFeasibility {
    let kind: NoopGoalFeasibilityKind; let kicker: String; let body: String; let fix: String?; let safety: String; let commitLabel: String; let color: Color; let light: Color; let factor: Double
    static let realistic = NoopGoalFeasibility(kind: .realistic, kicker: "The data says yes", body: "Twelve kilometres at 6:04 with heart rate under 150, on 34 km a week and eleven weeks left. The route asks for 55 km at peak, which is a 9% build — inside what your sleep has been absorbing.", fix: nil, safety: "Two easy weeks are written into the route on purpose, and a poor run of sleep moves the next hard week rather than deleting it.", commitLabel: "Keep this route", color: NoopHTMLColor.green, light: Color(hex: 0x8FEFC0), factor: 1)
    static let ambitious = NoopGoalFeasibility(kind: .ambitious, kicker: "Possible, with one condition", body: "The distance is there but the build is steep. The selected date asks for more than your last two blocks absorbed without a poor night.", fix: "Move the date later, or hold the peak lower and take the day slower. The distance is not the risk; the ramp is.", safety: "The saved route keeps the weekly load ceiling even when the date asks for more.", commitLabel: "Commit anyway", color: Color(hex: 0xF2B45C), light: Color(hex: 0xF6DCB4), factor: 0.84)
    static let unrealistic = NoopGoalFeasibility(kind: .unrealistic, kicker: "The data says not by then", body: "Your longest run and the selected date would require a weekly build above every block your sleep has absorbed this year.", fix: "Choose a later date or a shorter event. Both make a route Noop can actually build.", safety: "Noop will not build above its safety ceiling. It will save the goal only after confirmation and say when the date has to move.", commitLabel: "Commit anyway", color: Color(hex: 0xE9A288), light: Color(hex: 0xF0BBA6), factor: 0.62)
}

/// How many markers `labs` keeps, for the one caller outside Act 8 — Act 5's Biomarkers row on
/// `you`. That row carried a literal `7`, so it went on saying seven after the list became nine.
/// Reading the count is what stops it drifting again.
enum NoopLabCatalog {
    static var markerCount: Int { NoopLabMarker.all.count }
}

private struct NoopLabMarker: Identifiable {
    let id: String; let name: String; let unit: String; let low: Double; let high: Double; let defaultValue: Double; let trend: [Double]; let trendText: String; let contextCopy: String
    /// The store's `markerKey`. The display `id` is the design's slug; this is the identity the
    /// Lab Book writes and reads, and the two are deliberately not the same string.
    let storeKey: String
    /// The latest reading the Lab Book actually holds, attached by the screen. When present it is
    /// the source of truth for the value, its date, its unit and whether a range exists at all.
    var live: NoopLabReading? = nil
    /// Every dated reading the Lab Book holds for this marker, ascending. Real points only.
    var liveSeries: [Double] = []

    /// The design's `low`/`high` are demo fixtures. `MarkerDefinition.referenceTextHint` is
    /// documented as "NOT a shipped reference range" and `higherIsBetter` as "ALWAYS nil (NOOP
    /// makes no value judgement)", so outside the seeded fixture there is no band to be in or out
    /// of — only the range the user typed on their own reading, shown back verbatim.
    var demoBandApplies: Bool { NoopContentPolicy.allowsPrototypeContent }
    /// The value this marker actually holds, or `nil` when nothing has been recorded for it.
    ///
    /// 00-RULES.md §0a: a prototype figure may exist only behind **both** `#if DEBUG` and
    /// `--demo-seed`. This read used to end in `?? defaultValue`, so a release build with an empty
    /// store rendered an invented blood result for a marker the user had never entered — a health
    /// value is the first thing that rule names by name. A real saved value wins in every build; the
    /// seeded figure is reachable only through `NoopContentPolicy`; otherwise the marker is absent
    /// and the screen renders its absent state rather than a plausible number.
    var value: Double? {
        if let live { return live.value }
        return NoopContentPolicy.allowsPrototypeContent ? defaultValue : nil
    }
    var isRecorded: Bool { value != nil }
    /// Absent is not "outside": a marker with nothing recorded is neither in nor out of its band.
    var isOutside: Bool {
        guard demoBandApplies, let value else { return false }
        return value < low || value > high
    }
    var isInBand: Bool {
        guard demoBandApplies, let value else { return false }
        return value >= low && value <= high
    }
    var color: Color {
        guard isRecorded else { return NoopHTMLColor.faint }
        return isOutside ? Color(hex: 0xF2B45C) : NoopHTMLColor.green
    }
    var valueText: String { value?.formatted(.number.precision(.fractionLength(0...2))) ?? "—" }
    /// The stored reading's unit, falling back to the design's only for an empty row.
    var shownUnit: String { live?.unit ?? unit }
    var rangeText: String { "\(number(low))–\(number(high)) \(unit)" }
    /// The band the chart may shade, or `nil` when there is none to shade. Outside the seeded
    /// fixture NOOP ships no reference range, so nothing is drawn and nothing is described.
    var chartBand: (low: Double, high: Double)? { demoBandApplies ? (low, high) : nil }
    var recordedDateText: String? {
        if let live { return live.dayLabel }
        return NoopContentPolicy.allowsPrototypeContent ? "14 Aug" : nil
    }
    var listDetail: String {
        if demoBandApplies {
            guard let recordedDateText else { return "band \(rangeText)" }
            return "band \(rangeText) · \(recordedDateText)"
        }
        // Release: only what was recorded. A range appears solely because the user typed one on
        // their own reading; the design's band is a fixture and saying it here would be inventing
        // a clinical reference for this person's blood work.
        var parts: [String] = []
        if let reference = live?.referenceText { parts.append("band \(reference)") }
        if let recordedDateText { parts.append(recordedDateText) }
        return parts.isEmpty ? "not recorded" : parts.joined(separator: " · ")
    }
    var bandTag: String {
        guard value != nil else { return "not recorded" }
        guard demoBandApplies, let value else { return "recorded" }
        return value < low ? "below band" : value > high ? "above band" : "in band"
    }
    var detailBandTag: String {
        guard value != nil else { return "not recorded" }
        guard demoBandApplies, let value else { return "recorded" }
        return value < low ? "below the band" : value > high ? "above the band" : "in the band"
    }
    /// The dated series behind the trend chart. Empty when the marker holds nothing — there is no
    /// history to draw for a value that was never recorded, and an invented one is the failure
    /// 00-RULES §0a names.
    var series: [Double] {
        // Real dated readings win wherever they exist: the chart draws what was recorded, in the
        // order it was recorded. The seeded four-point `trend` is a fixture and stays behind the
        // demo gate; outside it a single reading is a single point, never a manufactured curve.
        if !liveSeries.isEmpty { return liveSeries }
        guard let value else { return [] }
        return NoopContentPolicy.allowsPrototypeContent ? trend : [value]
    }
    var trendDirection: String {
        guard series.count > 1 else { return "one recorded result, not yet a trend" }
        guard let first = series.first, let last = series.last else { return "not yet a trend" }
        let threshold = max(0.01, abs(first) * 0.03)
        if last < first - threshold { return "lower across these four dated draws" }
        if last > first + threshold { return "higher across these four dated draws" }
        return "broadly stable across these four dated draws"
    }
    var readCopy: String {
        guard NoopContentPolicy.allowsPrototypeContent else {
            return "One dated result. \(dynamicContextCopy)"
        }
        let note = htmlNote
        return "Four draws in fourteen months. \(note.prefix(1).uppercased())\(note.dropFirst())."
    }
    var htmlNote: String {
        guard demoBandApplies else { return bandTag }
        switch id {
        case "ferritin": return isOutside ? "under the band, and the one worth asking about" : "inside, at the low end of a very wide band"
        case "vitamin-d": return isOutside ? "under the band, which for August is early" : "inside, in August — it falls by February"
        case "apob": return isOutside ? "over the band, and the first thing a clinician would look at" : "comfortably inside"
        case "hs-crp": return isOutside ? "over the band — worth repeating before reading anything into it" : "low, which is where you want it"
        case "hba1c": return isOutside ? "over the band" : "inside, and stable across four draws"
        case "tsh": return isOutside ? "over the band" : "inside"
        case "alt": return isOutside ? "over the band, in a hard training block" : "inside, and it moves with hard training weeks"
        default: return bandTag
        }
    }
    var chartMinimum: Double { (series + (chartBand.map { [$0.low] } ?? [])).min().map { $0 * 0.86 } ?? 0 }
    var chartMaximum: Double { (series + (chartBand.map { [$0.low] } ?? [])).max().map { $0 * 1.14 } ?? 1 }
    var bandNote: String {
        guard demoBandApplies else {
            // Shown back verbatim because it is the user's own text, not a range NOOP supplies.
            guard let reference = live?.referenceText else {
                return "No reference range was recorded with this result, so none is drawn."
            }
            return "The range recorded with this result: \(reference)."
        }
        let topVisible = high <= chartMaximum
        let bottomVisible = low >= chartMinimum
        if topVisible && bottomVisible {
            return "The shaded area is the band the laboratory gave: \(number(low)) to \(number(high)) \(unit)."
        }
        if topVisible {
            return "The shaded area is the laboratory’s band. Its lower limit, \(number(low)) \(unit), sits below this scale."
        }
        return "The shaded area is the laboratory’s band from \(number(low)) \(unit) upward. Its upper limit, \(number(high)) \(unit), is far off this scale and is not drawn."
    }
    var retestCopy: String {
        guard NoopContentPolicy.allowsPrototypeContent else {
            return isOutside
                ? "A single out-of-band result is not conclusive. Ask a clinician whether and when a repeat draw would be useful."
                : "Noop does not infer a retest schedule from one recorded result."
        }
        if id == "ferritin" && isOutside {
            return "A single low ferritin inside a training block is common and not conclusive. The usual advice is a repeat draw in eight to twelve weeks — 9 November is the earliest that would tell you anything new."
        }
        if !isOutside {
            return "Nothing here asks for a retest before your next routine draw. Noop will keep this dated result beside the next one."
        }
        return "A single out-of-band result is not conclusive. Ask a clinician whether and when a repeat draw would be useful."
    }
    var dynamicContextCopy: String {
        guard let value else {
            return "Nothing has been recorded for \(name) yet. Add a result from a report or type one in, and Noop will show it against the laboratory’s band."
        }
        guard demoBandApplies else {
            let dated = live.map { " dated \($0.dayLabel)" } ?? ""
            return "\(name) is \(valueText) \(shownUnit)\(dated), \(trendDirection). Noop records the dated value and does not compare it to a range it was not given. One result is not a diagnosis; discuss it with a clinician if you want it interpreted."
        }
        let position = value < low ? "below" : value > high ? "above" : "inside"
        let markerFact: String
        switch id {
        case "vitamin-d": markerFact = "Noop does not assume a seasonal cause."
        case "hs-crp": markerFact = "Noop does not attach an inflammatory cause to a single value."
        case "hba1c": markerFact = "Noop records the dated series without turning it into a metabolic conclusion."
        case "tsh": markerFact = "Interpretation depends on clinical context Noop does not have."
        case "alt": markerFact = "Noop does not attribute the change to training or anything else."
        case "apob": markerFact = "Noop records the laboratory comparison and makes no treatment claim."
        default: markerFact = "Noop records the dated value and does not infer a cause."
        }
        return "\(name) is \(position) the laboratory’s band and is \(trendDirection). \(markerFact) One result is not a diagnosis; discuss it with a clinician if you want it interpreted."
    }
    private func number(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0...2))) }

    /// The nine markers `labs` keeps, in the order a printed panel runs them
    /// (`48-designer-answers-9-september.md` §2 and `47-act8-goals.md` §8.4).
    ///
    /// Nine rather than seven, because the by-hand route and the Biomarkers list are one list: a
    /// typed value has to have somewhere to live, so Haemoglobin and Creatine kinase are markers
    /// here and not just fields on a form. The bands and the seeded values are the HTML's.
    static let definitions: [NoopLabMarker] = [
        .init(id: "haemoglobin", name: "Haemoglobin", unit: "g/L", low: 130, high: 170, defaultValue: 141, trend: [140, 142, 141, 141], trendText: "steady across these four dated draws", contextCopy: "This result is inside the laboratory’s band and steady across these dated draws. Noop records the dated series and draws no conclusion from it.", storeKey: "haemoglobin"),
        .init(id: "ferritin", name: "Ferritin", unit: "µg/L", low: 30, high: 400, defaultValue: 28, trend: [42, 38, 33, 28], trendText: "lower across these four dated draws", contextCopy: "This result is below the laboratory’s band. One result is not a diagnosis; discuss the dated value and its downward trend with a clinician if you want it interpreted.", storeKey: "ferritin"),
        .init(id: "vitamin-d", name: "Vitamin D", unit: "nmol/L", low: 50, high: 125, defaultValue: 44, trend: [63, 58, 51, 44], trendText: "lower across these four dated draws", contextCopy: "This result is below the laboratory’s band. Seasonal timing can matter, but Noop does not infer a cause; a clinician can interpret the value in context.", storeKey: "vitamin_d"),
        .init(id: "apob", name: "ApoB", unit: "g/L", low: 0.5, high: 1.0, defaultValue: 0.78, trend: [0.88, 0.84, 0.8, 0.78], trendText: "slightly lower than the previous draw", contextCopy: "This result is inside the laboratory’s band and slightly lower than the prior draw. Noop records that fact and makes no treatment claim.", storeKey: "custom_apob"),
        .init(id: "hba1c", name: "HbA1c", unit: "mmol/mol", low: 20, high: 42, defaultValue: 33, trend: [34, 33, 33, 33], trendText: "stable across the four draws", contextCopy: "This result is inside the laboratory’s band and stable across these dated draws. Noop does not turn that into a clinical conclusion.", storeKey: "hba1c"),
        .init(id: "hs-crp", name: "hs-CRP", unit: "mg/L", low: 0, high: 3, defaultValue: 0.6, trend: [1.1, 0.8, 0.7, 0.6], trendText: "lower across the four draws", contextCopy: "This result is inside the laboratory’s band. A single inflammatory marker is not a diagnosis, and Noop does not attach a cause to it.", storeKey: "crp"),
        .init(id: "tsh", name: "TSH", unit: "mIU/L", low: 0.4, high: 4, defaultValue: 2.1, trend: [2.4, 2.2, 2.2, 2.1], trendText: "close to the preceding values", contextCopy: "This result is inside the laboratory’s band and close to the preceding values. Interpretation belongs with the clinical context Noop does not have.", storeKey: "tsh"),
        .init(id: "alt", name: "ALT", unit: "U/L", low: 10, high: 50, defaultValue: 41, trend: [35, 38, 44, 41], trendText: "below the preceding draw", contextCopy: "This result is inside the laboratory’s band and below the preceding draw. Noop shows the dated series without attributing the change to training or anything else.", storeKey: "alt"),
        .init(id: "creatine-kinase", name: "Creatine kinase", unit: "U/L", low: 30, high: 200, defaultValue: 186, trend: [96, 118, 152, 186], trendText: "higher across these four dated draws", contextCopy: "This result is inside the laboratory’s band and higher across these dated draws. The value moves with recent hard efforts; Noop reports it without attributing a cause.", storeKey: "custom_creatine_kinase")
    ]
    static var all: [NoopLabMarker] { definitions }

    /// The nine definitions with the Lab Book's latest reading attached to each.
    ///
    /// The list is always all nine, recorded or not: a marker with nothing stored is still a row
    /// showing its absent state, which is RULES §12 rather than a screen that shrinks as the store
    /// empties.
    @MainActor
    static func all(attaching book: NoopLabBook) -> [NoopLabMarker] {
        definitions.map { definition in
            var marker = definition
            let state = book.markers.first { $0.key == definition.storeKey }
            marker.live = state?.latest
            marker.liveSeries = (state?.history ?? []).map(\.value)
            return marker
        }
    }
}

private enum NoopOCRStatus {
    case pending, confirmed, corrected, discarded

    func message(reportDate: String?, isManual: Bool, value: String, unit: String) -> String {
        switch self {
        case .confirmed:
            reportDate.map { "Will be stored, dated \($0)" } ?? "Will be stored once the report date is known"
        case .corrected:
            isManual
                ? "Stored as \(value) \(unit), as you typed it"
                : "Stored as \(value) \(unit), corrected by you"
        case .discarded:
            isManual
                ? "Left out. Not stored, and not remembered as declined"
                : "Discarded. Not stored, and the file is not kept either"
        case .pending:
            ""
        }
    }
}
private struct NoopOCRCandidate: Identifiable {
    let id: String
    let markerKey: String
    let category: LabMarkerCategory
    let name: String
    let value: String
    let unit: String
    let raw: String
    let confidence: String
    let lowConfidence: Bool
    /// The exact value-shaped token printed on the page when it can be preserved separately.
    /// Real OCR may only provide the complete source line, which remains the honest fallback.
    let readToken: String?
    /// Normalized, top-left image coordinates for the complete source line.
    let sourceRect: CGRect?
    let example: String?
    var status: NoopOCRStatus = .pending
    var editing = false
    var draftValue = ""

    init(
        id: String,
        markerKey: String,
        category: LabMarkerCategory,
        name: String,
        value: String,
        unit: String,
        raw: String,
        confidence: String,
        lowConfidence: Bool,
        sourceRect: CGRect?,
        readToken: String? = nil,
        example: String? = nil
    ) {
        self.id = id
        self.markerKey = markerKey
        self.category = category
        self.name = name
        self.value = value
        self.unit = unit
        self.raw = raw
        self.confidence = confidence
        self.lowConfidence = lowConfidence
        self.sourceRect = sourceRect
        self.readToken = readToken
        self.example = example
    }

    var shownName: String { name }
    var shownValue: String {
        let text = status == .corrected ? draftValue : value
        return text.isEmpty ? "—" : text
    }
    var shownUnit: String { unit }

    static let manualFields: [NoopOCRCandidate] = [
        .init(id: "manual-haemoglobin", markerKey: "haemoglobin", category: .bloodPanel, name: "Haemoglobin", value: "", unit: "g/L", raw: "", confidence: "", lowConfidence: false, sourceRect: nil, example: "141"),
        .init(id: "manual-ferritin", markerKey: "ferritin", category: .bloodPanel, name: "Ferritin", value: "", unit: "µg/L", raw: "", confidence: "", lowConfidence: false, sourceRect: nil, example: "28"),
        .init(id: "manual-vitamin-d", markerKey: "vitamin_d", category: .bloodPanel, name: "Vitamin D", value: "", unit: "nmol/L", raw: "", confidence: "", lowConfidence: false, sourceRect: nil, example: "52"),
        .init(id: "manual-apob", markerKey: "custom_apob", category: .other, name: "ApoB", value: "", unit: "g/L", raw: "", confidence: "", lowConfidence: false, sourceRect: nil, example: "0.78"),
        .init(id: "manual-hba1c", markerKey: "hba1c", category: .bloodPanel, name: "HbA1c", value: "", unit: "mmol/mol", raw: "", confidence: "", lowConfidence: false, sourceRect: nil, example: "33"),
        .init(id: "manual-hs-crp", markerKey: "crp", category: .bloodPanel, name: "hs-CRP", value: "", unit: "mg/L", raw: "", confidence: "", lowConfidence: false, sourceRect: nil, example: "0.6"),
        .init(id: "manual-tsh", markerKey: "tsh", category: .bloodPanel, name: "TSH", value: "", unit: "mIU/L", raw: "", confidence: "", lowConfidence: false, sourceRect: nil, example: "2.1"),
        .init(id: "manual-alt", markerKey: "alt", category: .bloodPanel, name: "ALT", value: "", unit: "U/L", raw: "", confidence: "", lowConfidence: false, sourceRect: nil, example: "41"),
        .init(id: "manual-creatine-kinase", markerKey: "custom_creatine_kinase", category: .other, name: "Creatine kinase", value: "", unit: "U/L", raw: "", confidence: "", lowConfidence: false, sourceRect: nil, example: "186")
    ]
    static let samples = [
        NoopOCRCandidate(id: "ferritin", markerKey: "ferritin", category: .bloodPanel, name: "Ferritin", value: "28", unit: "µg/L", raw: "Ferritin  28 µg/L", confidence: "clear read", lowConfidence: false, sourceRect: nil, readToken: "28"),
        NoopOCRCandidate(id: "vitamin-d", markerKey: "vitamin_d", category: .bloodPanel, name: "Vitamin D", value: "52", unit: "nmol/L", raw: "Vitamin D, 25-OH  52 nmol/L", confidence: "clear read", lowConfidence: false, sourceRect: nil, readToken: "52"),
        NoopOCRCandidate(id: "apob", markerKey: "custom_apob", category: .other, name: "ApoB", value: "0.78", unit: "g/L", raw: "ApoB  O.78 g/L", confidence: "check this", lowConfidence: true, sourceRect: nil, readToken: "O.78"),
        NoopOCRCandidate(id: "hs-crp", markerKey: "crp", category: .bloodPanel, name: "hs-CRP", value: "0.6", unit: "mg/L", raw: "hsCRP  <0,6", confidence: "check this", lowConfidence: true, sourceRect: nil, readToken: "<0,6")
    ]

    static let samplesWithRects: [NoopOCRCandidate] = [
        NoopOCRCandidate(id: "ferritin", markerKey: "ferritin", category: .bloodPanel, name: "Ferritin", value: "28", unit: "µg/L", raw: "Ferritin  28 µg/L", confidence: "clear read", lowConfidence: false, sourceRect: CGRect(x: 0.07, y: 0.32, width: 0.86, height: 0.075), readToken: "28"),
        NoopOCRCandidate(id: "vitamin-d", markerKey: "vitamin_d", category: .bloodPanel, name: "Vitamin D", value: "52", unit: "nmol/L", raw: "Vitamin D, 25-OH  52 nmol/L", confidence: "clear read", lowConfidence: false, sourceRect: CGRect(x: 0.07, y: 0.44, width: 0.86, height: 0.075), readToken: "52"),
        NoopOCRCandidate(id: "apob", markerKey: "custom_apob", category: .other, name: "ApoB", value: "0.78", unit: "g/L", raw: "ApoB  O.78 g/L", confidence: "check this", lowConfidence: true, sourceRect: CGRect(x: 0.07, y: 0.56, width: 0.86, height: 0.075), readToken: "O.78"),
        NoopOCRCandidate(id: "hs-crp", markerKey: "crp", category: .bloodPanel, name: "hs-CRP", value: "0.6", unit: "mg/L", raw: "hsCRP  <0,6", confidence: "check this", lowConfidence: true, sourceRect: CGRect(x: 0.07, y: 0.68, width: 0.86, height: 0.075), readToken: "<0,6")
    ]
}

private struct NoopMarkerTrend: View {
    let marker: NoopLabMarker
    var body: some View {
        Canvas { context, size in
            let minValue = marker.chartMinimum
            let maxValue = marker.chartMaximum
            let span = max(0.001, maxValue - minValue)
            func y(_ value: Double) -> CGFloat { CGFloat((maxValue - value) / span) * size.height }
            // Only a band NOOP actually has may be drawn. Outside the seeded fixture there is no
            // reference range, so the chart plots the dated points on their own rather than
            // shading a range the user was never given.
            let band = marker.chartBand
            let topVisible = band.map { $0.high <= maxValue } ?? false
            let bottomVisible = band.map { $0.low >= minValue } ?? false
            if let band {
                let bandTop = topVisible ? y(band.high) : 0
                let bandBottom = bottomVisible ? y(band.low) : size.height
                context.fill(
                    Path(CGRect(x: 0, y: bandTop, width: size.width, height: max(2, bandBottom - bandTop))),
                    with: .color(NoopHTMLColor.green.opacity(0.10))
                )
            }
            let bandTop = topVisible ? y(band?.high ?? 0) : 0
            let bandBottom = bottomVisible ? y(band?.low ?? 0) : size.height
            if topVisible {
                var boundary = Path()
                boundary.move(to: CGPoint(x: 0, y: bandTop))
                boundary.addLine(to: CGPoint(x: size.width, y: bandTop))
                context.stroke(boundary, with: .color(NoopHTMLColor.green.opacity(0.32)), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
            }
            if bottomVisible {
                var boundary = Path()
                boundary.move(to: CGPoint(x: 0, y: bandBottom))
                boundary.addLine(to: CGPoint(x: size.width, y: bandBottom))
                context.stroke(boundary, with: .color(NoopHTMLColor.green.opacity(0.32)), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
            }

            var line = Path()
            var points: [CGPoint] = []
            for (index, value) in marker.series.enumerated() {
                let denominator = max(1, marker.series.count - 1)
                let x = marker.series.count == 1
                    ? size.width
                    : CGFloat(index) / CGFloat(denominator) * size.width
                let point = CGPoint(x: x, y: y(value))
                index == 0 ? line.move(to: point) : line.addLine(to: point)
                points.append(point)
            }
            context.stroke(line, with: .color(Color(hex: 0xF2B45C)), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

            for point in points {
                let dot = Path(ellipseIn: CGRect(x: point.x - 3.6, y: point.y - 3.6, width: 7.2, height: 7.2))
                context.fill(dot, with: .color(NoopHTMLColor.canvas))
                context.stroke(dot, with: .color(Color(hex: 0xF2B45C)), lineWidth: 2)
            }
        }.frame(height: 118)
    }
}

private struct NoopMarkerBeside: View {
    let label: String; let value: String
    init(_ label: String, _ value: String) { self.label = label; self.value = value }
    var body: some View { HStack(alignment: .firstTextBaseline) { Text(label).font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.inkSoft); Spacer(); Text(value).font(.system(size: 11.5, weight: .semibold, design: .monospaced)) } }
}
private struct NoopLabFileFact: View {
    let text: String; init(_ text: String) { self.text = text }
    var body: some View { HStack(alignment: .top, spacing: 10) { Circle().fill(Color(hex: 0xF2B45C)).frame(width: 5, height: 5).padding(.top, 6); Text(text).font(NoopHTMLFont.sans(12)).foregroundStyle(NoopHTMLColor.copy).lineSpacing(3) } }
}

private struct NoopOCRTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(NoopHTMLFont.outfit(19, weight: .light))
            .tracking(-0.38)
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(Color(hex: 0x0A0C0B).opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.14), lineWidth: 0.5))
    }
}
private struct NoopOCRActionStyle: ButtonStyle {
    var primary = false
    var enabled = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(NoopHTMLFont.sans(12.5, weight: .semibold))
            .foregroundStyle(primary ? (enabled ? NoopHTMLColor.warmInk : NoopHTMLColor.faint) : NoopHTMLColor.inkSoft)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                primary ? (enabled ? NoopHTMLColor.warm : Color.white.opacity(0.07)) : Color.white.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 13)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 13)
                    .stroke(primary ? Color.clear : Color.white.opacity(0.10), lineWidth: 0.5)
            }
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}
private struct NoopGoalActionStyle: ButtonStyle {
    var primary = false
    func makeBody(configuration: Configuration) -> some View { configuration.label.font(NoopHTMLFont.sans(12.5, weight: .semibold)).foregroundStyle(primary ? Color(hex: 0x1E1405) : NoopHTMLColor.inkSoft).frame(maxWidth: .infinity).frame(height: 42).background(primary ? Color(hex: 0xF2B45C) : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(primary ? .clear : Color.white.opacity(0.1), lineWidth: 0.5)).opacity(configuration.isPressed ? 0.82 : 1) }
}
private struct NoopAct8WeekActionStyle: ButtonStyle {
    let primary: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(NoopHTMLFont.sans(12.5, weight: .semibold))
            .foregroundStyle(primary ? Color(hex: 0x0C1024) : NoopHTMLColor.inkSoft)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(primary ? NoopHTMLColor.night : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(primary ? Color.clear : Color.white.opacity(0.1), lineWidth: 0.5)
            }
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}
private struct NoopGoalCommitStyle: ButtonStyle {
    let primary: Bool
    func makeBody(configuration: Configuration) -> some View { configuration.label.font(NoopHTMLFont.sans(14, weight: .semibold)).foregroundStyle(primary ? Color(hex: 0x1E1405) : NoopHTMLColor.inkSoft).frame(maxWidth: .infinity).frame(height: 52).background(primary ? Color(hex: 0xF2B45C) : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(primary ? .clear : Color.white.opacity(0.14), lineWidth: 0.5)).opacity(configuration.isPressed ? 0.82 : 1) }
}
private struct NoopGoalWarmButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label.font(NoopHTMLFont.sans(11.5, weight: .semibold)).foregroundStyle(Color(hex: 0xF6DCB4)).padding(.horizontal, 12).frame(height: 30).background(Color(hex: 0xF2B45C).opacity(0.14), in: RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: 0xF2B45C).opacity(0.32), lineWidth: 0.5)).opacity(configuration.isPressed ? 0.82 : 1) }
}

// MARK: - Lab Book adapter

// The Act 8 lab family, backed by what the Lab Book actually holds.
//
// The canonical screens (`labs`, `picker`, `review`, `marker`) were reading a `UserDefaults`
// display mirror written by Save. That mirror is a convenience, not a record: it holds one value
// per marker NAME, keeps no history, no source and no date beyond a caption string, and it is
// written from the same screen that renders it. This adapter replaces it for Release with reads of
// the real `labMarker` table, so the screens show what was stored rather than what was last typed.
//
// **What this type will not do.** Everything here is a recorded fact or absent. Where the Lab Book
// has nothing, the value stays `nil` and the screen renders its absent state — no zero, no demo
// band, no clinic, no invented date, no neighbouring marker standing in, no trend drawn from a
// single point, and no interpretation of what a number means. That is `00-RULES.md` §0a applied to
// the one screen in the app whose subject is somebody's blood work.
//
// **Reference ranges.** NOOP ships none, and this is settled in two places already:
// `LabMarkerRow.referenceText` is documented as "User-entered reference range, shown back verbatim.
// NOOP ships none", and `MarkerDefinition.referenceTextHint` says it is "NOT a shipped reference
// range" while `higherIsBetter` is "ALWAYS nil (NOOP makes no value judgement)". So a band exists
// only when the user recorded one, and a marker without one is shown without a band rather than
// against the design's demo range. The 130–170 in the handoff is a fixture, and using it in Release
// would be inventing a clinical reference for somebody's haemoglobin.
//
// The demo fixtures are untouched: under `#if DEBUG` **and** `--demo-seed` the screens keep reading
// `NoopLabMarker`, so the canonical 402×874 appearance still matches the prototype exactly.

/// One reading, exactly as the Lab Book stored it.
struct NoopLabReading: Equatable, Identifiable {
    let id: String
    let value: Double
    /// The stored `yyyy-MM-dd` day key — the day the reading is dated to, not the day it was typed.
    let day: String
    let takenAt: Int
    let unit: String
    let source: String
    /// Present only when the user recorded a range on this reading.
    let referenceText: String?

    init(row: LabMarkerRow, value: Double) {
        self.id = row.id
        self.value = value
        self.day = row.day
        self.takenAt = row.takenAt
        self.unit = row.unit
        self.source = row.source
        self.referenceText = row.referenceText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? row.referenceText
            : nil
    }

    /// "14 August" — from the stored day key, never from `Date()`. A reading with an unparseable
    /// day keeps its raw key rather than being given today's date.
    var dayLabel: String {
        guard let date = Self.dayParser.date(from: day) else { return day }
        return Self.dayLabeller.string(from: date)
    }

    private static let dayParser: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let dayLabeller: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.setLocalizedDateFormatFromTemplate("d MMMM")
        return f
    }()
}

/// A marker as the Lab Book holds it: its identity, and whatever readings exist for it.
struct NoopLabMarkerState: Equatable, Identifiable {
    /// The store's `markerKey`, which is the identity that survives a rename of the display label.
    let key: String
    let displayName: String
    /// The unit to show on an empty row. Taken from the catalogue, so it describes the marker
    /// rather than asserting a reading.
    let canonicalUnit: String
    let decimals: Int
    /// Ascending by `takenAt`, exactly as the store returns them.
    let history: [NoopLabReading]

    var id: String { key }
    var latest: NoopLabReading? { history.last }
    var isRecorded: Bool { latest != nil }

    /// The unit to display: the reading's own, falling back to the catalogue's for an empty row.
    var unit: String { latest?.unit ?? canonicalUnit }

    /// A range only exists when the user recorded one on the latest reading.
    var referenceText: String? { latest?.referenceText }
    var hasRange: Bool { referenceText != nil }

    var valueText: String {
        guard let latest else { return "—" }
        return latest.value.formatted(.number.precision(.fractionLength(0...max(0, decimals))))
    }

    /// Only a series of two or more dated points is a history worth drawing. One point is a point.
    var drawableHistory: [NoopLabReading] { history.count >= 2 ? history : [] }
}

/// Loads the Act 8 lab family from the real Lab Book.
///
/// One read per marker key, in the fixed catalogue order the design uses, so the list is stable
/// whether or not anything has been recorded — a marker with no readings is still a row, showing
/// its absent state. That is `00-RULES.md` §12: the card renders and says what is missing rather
/// than disappearing.
@MainActor
final class NoopLabBook: ObservableObject {
    /// The nine markers `labs` keeps, in the order a printed panel runs them
    /// (`48-designer-answers-9-september.md` §2). Keys match what Save writes.
    static let markerKeys: [(key: String, name: String, unit: String, decimals: Int)] = [
        ("haemoglobin", "Haemoglobin", "g/L", 0),
        ("ferritin", "Ferritin", "µg/L", 0),
        ("vitamin_d", "Vitamin D", "nmol/L", 0),
        ("custom_apob", "ApoB", "g/L", 2),
        ("hba1c", "HbA1c", "mmol/mol", 0),
        ("crp", "hs-CRP", "mg/L", 1),
        ("tsh", "TSH", "mIU/L", 1),
        ("alt", "ALT", "U/L", 0),
        ("custom_creatine_kinase", "Creatine kinase", "U/L", 0),
    ]

    @Published private(set) var markers: [NoopLabMarkerState] = []
    /// Distinguishes "nothing recorded" from "not read yet", so the screen can hold its shape
    /// during the load instead of flashing an empty state it will immediately contradict.
    @Published private(set) var hasLoaded = false
    /// Set when the store could not be opened or a read threw. The screen says so rather than
    /// rendering an empty Lab Book, which would be a different and untrue statement.
    @Published private(set) var unavailable = false

    var recordedCount: Int { markers.filter(\.isRecorded).count }
    /// Only markers whose latest reading carries a user-recorded range can be judged against one.
    var rangedMarkers: [NoopLabMarkerState] { markers.filter(\.hasRange) }

    /// The most recently dated reading across all markers. Absent when nothing is recorded — the
    /// header then says nothing rather than naming a date.
    var latestReading: NoopLabReading? {
        markers.compactMap(\.latest).max { $0.takenAt < $1.takenAt }
    }
    var latestDayLabel: String? { latestReading?.dayLabel }

    /// "drawn" is a claim about when blood was taken. A manual row is dated to the day it was
    /// typed, which is a truthful source for *entry* and not for the draw — someone entering a
    /// result off a March report today would otherwise read "drawn 10 September". The header says
    /// which it is rather than assuming the two are the same.
    var latestDateLabel: String? {
        guard let latest = latestReading else { return nil }
        return latest.source == "manual" ? "entered \(latest.dayLabel)" : "drawn \(latest.dayLabel)"
    }

    /// The sources actually present, so the header can name where readings came from without
    /// asserting a clinic the app was never told about.
    var sources: [String] {
        Array(Set(markers.compactMap(\.latest?.source))).sorted()
    }

    func load(store: WhoopStore?, deviceId: String) async {
        guard let store else {
            markers = Self.emptyStates()
            unavailable = true
            hasLoaded = true
            return
        }
        var built: [NoopLabMarkerState] = []
        var failed = false
        for entry in Self.markerKeys {
            let rows: [LabMarkerRow]
            do {
                rows = try await store.labMarkers(deviceId: deviceId, markerKey: entry.key)
            } catch {
                failed = true
                rows = []
            }
            // A qualitative row (`value == nil`, meaning in `valueText`) is not plottable and is
            // not a number this screen can place against a range, so it is skipped rather than
            // coerced to zero.
            let readings = rows.compactMap { row -> NoopLabReading? in
                guard let value = row.value else { return nil }
                return NoopLabReading(row: row, value: value)
            }
            built.append(
                NoopLabMarkerState(
                    key: entry.key,
                    displayName: entry.name,
                    canonicalUnit: MarkerCatalog.definition(for: entry.key)?.canonicalUnit ?? entry.unit,
                    decimals: MarkerCatalog.definition(for: entry.key)?.decimals ?? entry.decimals,
                    history: readings
                )
            )
        }
        markers = built
        unavailable = failed
        hasLoaded = true
    }

    private static func emptyStates() -> [NoopLabMarkerState] {
        markerKeys.map {
            NoopLabMarkerState(
                key: $0.key,
                displayName: $0.name,
                canonicalUnit: MarkerCatalog.definition(for: $0.key)?.canonicalUnit ?? $0.unit,
                decimals: MarkerCatalog.definition(for: $0.key)?.decimals ?? $0.decimals,
                history: []
            )
        }
    }
}
