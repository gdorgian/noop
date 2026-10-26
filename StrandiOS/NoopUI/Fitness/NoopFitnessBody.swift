#if os(iOS)
import SwiftUI
import PhotosUI
import WhoopStore

/// Body: weight, body fat and tape measurements over time, and progress photos — the part of training
/// a strap cannot see.
///
/// A new weight or waist also becomes the profile's, so the models that read body size (energy, VO₂max)
/// use the latest number without it being typed twice. Photos are image files on this phone; they are
/// not part of a Noop backup, and the page says so.
struct NoopFitnessBodyScreen: View {
    @ObservedObject var navigation: NoopNavigation
    @EnvironmentObject private var repo: Repository
    @EnvironmentObject private var profile: ProfileStore
    @AppStorage(UnitPrefs.systemKey) private var unitSystemRaw = UnitSystem.metric.rawValue
    @State private var measurements: [BodyMeasurementRow] = []
    @State private var photos: [ProgressPhotoRow] = []
    @State private var selected: BodyMeasurementKind = .weight
    @State private var window: NoopExerciseSummary.Window = .year
    @State private var logging = false
    @State private var pick: PhotosPickerItem?
    @State private var viewing: ProgressPhotoRow?
    @State private var comparing = false
    @State private var error: String?

    private var units: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }

    var body: some View {
        NoopFitnessPage(navigation: navigation, title: "Body",
                        subtitle: "Weight, body fat and measurements over time, and photos to see the change.") {
            VStack(alignment: .leading, spacing: 22) {
                NoopActionButton(title: "Log measurements") { logging = true }
                if measurements.isEmpty {
                    NoopExerciseEmpty(text: "Nothing logged yet. Weigh in, or take a tape to your waist, and the trend starts here.")
                } else {
                    trend
                    latest
                }
                photosSection
                if let error { Text(error).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.red) }
            }
        }
        .task(id: repo.refreshSeq) { await load() }
        .sheet(isPresented: $logging) {
            NoopBodyLogSheet(units: units, latest: latestByKind) { entries in
                Task { await save(entries) }
            }
            .noopSheet([.large])
        }
        .sheet(item: $viewing) { photo in
            NoopProgressPhotoViewer(photo: photo) { Task { await delete(photo) } }.noopSheet([.large])
        }
        .sheet(isPresented: $comparing) {
            NoopProgressCompare(photos: photos).noopSheet([.large])
        }
        .onChange(of: pick) { _, item in
            guard let item else { return }
            Task { await addPhoto(item) }
        }
    }

    // MARK: Trend

    private var kindsWithData: [BodyMeasurementKind] {
        BodyMeasurementKind.allCases.filter { k in measurements.contains { $0.kind == k } }
    }

    private var trend: some View {
        let kinds = kindsWithData
        let kind = kinds.contains(selected) ? selected : (kinds.first ?? .weight)
        let points = measurements.filter { $0.kind == kind }.map {
            NoopTrendPoint(id: $0.id, ts: $0.ts, value: NoopBodyFormat.display($0.value, kind, units))
        }
        return VStack(alignment: .leading, spacing: NoopSpace.s) {
            if kinds.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: NoopSpace.xs) {
                        ForEach(kinds, id: \.self) { k in NoopChip(title: k.title, isOn: kind == k) { selected = k } }
                    }
                }
            }
            NoopTrendChartCard(points: NoopTrendPoint.within(window, points),
                               label: { NoopBodyFormat.label($0, kind, units) }, tint: NoopHTMLColor.blush)
                .animation(NoopMotion.swap, value: kind)
            NoopTabs(options: NoopExerciseSummary.Window.allCases.map { ($0.rawValue, $0) }, selection: $window)
        }
    }

    private var latestByKind: [BodyMeasurementKind: BodyMeasurementRow] {
        var out: [BodyMeasurementKind: BodyMeasurementRow] = [:]
        for m in measurements { out[m.kind] = m }   // oldest first, so the last write is the newest
        return out
    }

    private var latest: some View {
        VStack(alignment: .leading, spacing: 8) {
            NoopSectionLabel("Latest")
            ForEach(kindsWithData, id: \.self) { kind in
                let rows = measurements.filter { $0.kind == kind }
                if let last = rows.last {
                    let previous = rows.dropLast().last
                    Button { withAnimation(NoopMotion.swap) { selected = kind } } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(kind.title).font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                                Text(Date(timeIntervalSince1970: Double(last.ts)).formatted(.dateTime.day().month(.abbreviated).year()))
                                    .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                            }
                            Spacer()
                            if let previous {
                                let delta = NoopBodyFormat.display(last.value, kind, units) - NoopBodyFormat.display(previous.value, kind, units)
                                if abs(delta) >= 0.05 {
                                    // Against the previous entry, not the chart's window: said so beside the chart's chip.
                                    Text("\(delta > 0 ? "+" : "−")\(NoopBodyFormat.label(abs(delta), kind, units)) since last")
                                        .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold)).monospacedDigit()
                                        .foregroundStyle(NoopHTMLColor.copy)
                                }
                            }
                            Text(NoopBodyFormat.label(NoopBodyFormat.display(last.value, kind, units), kind, units))
                                .font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).monospacedDigit()
                                .foregroundStyle(NoopHTMLColor.ink)
                        }
                        .padding(14)
                        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(selected == kind ? NoopHTMLColor.blush.opacity(0.4) : NoopHTMLColor.border, lineWidth: 0.6))
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                    .contextMenu {
                        // Apple Health's own weigh-ins are deleted in Health, not here.
                        if !last.id.hasPrefix(Self.healthPrefix) {
                            Button(role: .destructive) { Task { await deleteMeasurement(last) } } label: {
                                Label("Delete this entry", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Photos

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                NoopSectionLabel("Progress photos")
                Spacer()
                if photos.count >= 2 {
                    Button("Compare") { comparing = true }
                        .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold)).foregroundStyle(NoopHTMLColor.blush)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    PhotosPicker(selection: $pick, matching: .images, photoLibrary: .shared()) {
                        VStack(spacing: 8) {
                            NoopCanonicalGlyph(name: .camera, size: 20, color: NoopHTMLColor.inkSoft)
                            Text("Add photo").font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
                                .foregroundStyle(NoopHTMLColor.inkSoft)
                        }
                        .frame(width: 104, height: 138)
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.16), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
                    }
                    ForEach(photos, id: \.id) { photo in
                        Button { viewing = photo } label: {
                            NoopProgressThumb(photo: photo).frame(width: 104, height: 138)
                        }
                        .buttonStyle(NoopHTMLPressStyle())
                    }
                }
            }
            Text("Photos stay on this phone. They are not part of a Noop backup, so keep your own copy of any you want to keep.")
                .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Store

    private func load() async {
        guard let store = await repo.storeHandle() else { return }
        let logged = (try? await store.bodyMeasurements(deviceId: repo.deviceId)) ?? []
        measurements = await Self.mergingHealth(logged, store: store)
        photos = (try? await store.progressPhotos(deviceId: repo.deviceId)) ?? []
    }

    /// Weigh-ins Apple Health brought in (the series Trends draws) join the hand-logged ones, so the
    /// page agrees with Trends. A day that already has a logged value keeps it. These rows are read-only.
    static func mergingHealth(_ logged: [BodyMeasurementRow], store: WhoopStore) async -> [BodyMeasurementRow] {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        var rows = logged
        for (key, kind) in [("weight", BodyMeasurementKind.weight), ("body_fat", .bodyFat)] {
            let loggedDays = Set(logged.filter { $0.kind == kind }.map { Repository.localDayKey(Date(timeIntervalSince1970: TimeInterval($0.ts))) })
            let points = (try? await store.metricSeries(deviceId: "apple-health", key: key, from: "0000-00-00", to: "9999-99-99")) ?? []
            for p in points where !loggedDays.contains(p.day) && p.value > 0 {
                guard let day = parser.date(from: p.day) else { continue }
                let ts = Int(day.addingTimeInterval(12 * 3600).timeIntervalSince1970)
                rows.append(BodyMeasurementRow(id: healthPrefix + "\(key)-\(p.day)", deviceId: "apple-health",
                                               ts: ts, kind: kind, value: p.value))
            }
        }
        return rows.sorted { $0.ts < $1.ts }
    }

    static let healthPrefix = "health-"

    private func save(_ entries: [BodyMeasurementRow]) async {
        guard !entries.isEmpty, let store = await repo.storeHandle() else { return }
        do {
            try await store.upsertBodyMeasurements(entries)
            // The newest weight and waist are the profile's too (energy, VO₂max read them from there).
            let newest = latestByKind
            for e in entries {
                guard newest[e.kind].map({ e.ts >= $0.ts }) ?? true else { continue }
                if e.kind == .weight { profile.weightKg = e.value }
                if e.kind == .waist { profile.waistCm = e.value }
            }
            if let first = entries.first { selected = first.kind }
            await load()
        } catch {
            self.error = "The measurements could not be saved. Try again."
        }
    }

    private func deleteMeasurement(_ row: BodyMeasurementRow) async {
        guard let store = await repo.storeHandle() else { return }
        _ = try? await store.deleteBodyMeasurement(id: row.id)
        await load()
    }

    private func addPhoto(_ item: PhotosPickerItem) async {
        defer { pick = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let file = NoopProgressPhotoFiles.save(data), let store = await repo.storeHandle() else {
            error = "That photo could not be added."
            return
        }
        let row = ProgressPhotoRow(id: file.id, deviceId: repo.deviceId, ts: Int(Date().timeIntervalSince1970),
                                   pose: nil, fileName: file.name)
        _ = try? await store.upsertProgressPhoto(row)
        await load()
    }

    private func delete(_ photo: ProgressPhotoRow) async {
        guard let store = await repo.storeHandle() else { return }
        _ = try? await store.deleteProgressPhoto(id: photo.id)
        NoopProgressPhotoFiles.remove(photo.fileName)
        viewing = nil
        await load()
    }
}

// MARK: - Logging

/// One sheet for every measurement taken now: fill in what was measured, leave the rest blank.
private struct NoopBodyLogSheet: View {
    let units: UnitSystem
    let latest: [BodyMeasurementKind: BodyMeasurementRow]
    let onSave: ([BodyMeasurementRow]) -> Void

    @EnvironmentObject private var repo: Repository
    @Environment(\.dismiss) private var dismiss
    @State private var text: [BodyMeasurementKind: String] = [:]
    @State private var date = Date()
    @State private var problem: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Log measurements").font(NoopHTMLFont.sheetTitle).foregroundStyle(NoopHTMLColor.ink)
                    Spacer()
                    Button("Cancel") { dismiss() }.foregroundStyle(NoopHTMLColor.inkSoft)
                }
                DatePicker("Taken", selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                    .font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.ink)
                group("Body", [.weight, .bodyFat])
                group("Torso", [.neck, .shoulders, .chest, .waist, .hips])
                group("Arms", [.leftBicep, .rightBicep, .leftForearm, .rightForearm])
                group("Legs", [.leftThigh, .rightThigh, .leftCalf, .rightCalf])
                if let problem { Text(problem).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.red) }
                NoopActionButton(title: "Save", enabled: !entries.isEmpty) {
                    if let bad = invalid { problem = "\(bad.title) looks out of range. Check the number and the unit."; return }
                    onSave(entries)
                    dismiss()
                }
            }
            .padding(20)
        }
        .background(NoopHTMLColor.canvas)
        .tint(NoopHTMLColor.blush)
    }

    private func group(_ title: String, _ kinds: [BodyMeasurementKind]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            NoopSectionLabel(title)
            VStack(spacing: 0) {
                ForEach(Array(kinds.enumerated()), id: \.element) { i, kind in
                    HStack {
                        Text(kind.title).font(NoopHTMLFont.sans(NoopType.subhead)).foregroundStyle(NoopHTMLColor.ink)
                        Spacer()
                        TextField(latest[kind].map { LiftFormat.trim(NoopBodyFormat.display($0.value, kind, units)) } ?? "—",
                                  text: Binding(get: { text[kind] ?? "" }, set: { text[kind] = $0 }))
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                            .font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).monospacedDigit()
                            .foregroundStyle(NoopHTMLColor.ink).frame(width: 90)
                        Text(NoopBodyFormat.unit(kind, units)).font(NoopHTMLFont.sans(NoopType.caption))
                            .foregroundStyle(NoopHTMLColor.copy).frame(width: 26, alignment: .leading)
                    }
                    .frame(minHeight: 48).padding(.horizontal, 14)
                    if i < kinds.count - 1 { Divider().overlay(NoopHTMLColor.border).padding(.leading, 14) }
                }
            }
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    /// Each typed value, converted to the stored unit.
    private var entries: [BodyMeasurementRow] {
        let ts = Int(date.timeIntervalSince1970)
        return BodyMeasurementKind.allCases.compactMap { kind in
            guard let raw = text[kind]?.replacingOccurrences(of: ",", with: "."), let shown = Double(raw), shown > 0 else { return nil }
            return BodyMeasurementRow(id: "body-\(kind.rawValue)-\(ts)", deviceId: repo.deviceId, ts: ts, kind: kind,
                                      value: NoopBodyFormat.stored(shown, kind, units))
        }
    }

    private var invalid: BodyMeasurementKind? {
        entries.first { !$0.kind.plausible.contains($0.value) }?.kind
    }
}

// MARK: - Photos

enum NoopProgressPhotoFiles {
    static var folder: URL? {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let url = docs.appendingPathComponent("ProgressPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Re-encode the picked image as a JPEG no larger than 1600 px on its long edge: enough to compare,
    /// small enough not to fill the phone. Returns the new file's id and name.
    static func save(_ data: Data) -> (id: String, name: String)? {
        guard let image = UIImage(data: data), let folder else { return nil }
        let scale = min(1, 1600 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let jpeg = resized.jpegData(compressionQuality: 0.82) else { return nil }
        let id = UUID().uuidString
        let name = "\(id).jpg"
        do {
            try jpeg.write(to: folder.appendingPathComponent(name), options: [.atomic, .completeFileProtection])
            return (id, name)
        } catch { return nil }
    }

    static func image(_ name: String) -> UIImage? {
        folder.flatMap { UIImage(contentsOfFile: $0.appendingPathComponent(name).path) }
    }

    static func remove(_ name: String) {
        guard let folder else { return }
        try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
    }
}

private struct NoopProgressThumb: View {
    let photo: ProgressPhotoRow
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let image = NoopProgressPhotoFiles.image(photo.fileName) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                NoopHTMLColor.card
            }
            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
            Text(Date(timeIntervalSince1970: Double(photo.ts)).formatted(.dateTime.day().month(.abbreviated)))
                .font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold)).foregroundStyle(.white)
                .padding(8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct NoopProgressPhotoViewer: View {
    let photo: ProgressPhotoRow
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirm = false

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text(Date(timeIntervalSince1970: Double(photo.ts)).formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                    .font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                Spacer()
                Button { confirm = true } label: { Image(systemName: "trash") }.foregroundStyle(NoopHTMLColor.red)
                    .accessibilityLabel("Delete photo")
                Button("Done") { dismiss() }.foregroundStyle(NoopHTMLColor.inkSoft).padding(.leading, 12)
            }
            if let image = NoopProgressPhotoFiles.image(photo.fileName) {
                Image(uiImage: image).resizable().scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .background(NoopHTMLColor.canvas)
        .alert("Delete this photo?", isPresented: $confirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { onDelete() }
        } message: { Text("It is removed from this phone. Noop keeps no other copy.") }
    }
}

/// Two photos, one over the other, split by a handle you drag: before on the left, after on the right.
private struct NoopProgressCompare: View {
    let photos: [ProgressPhotoRow]
    @Environment(\.dismiss) private var dismiss
    @State private var beforeID: String?
    @State private var afterID: String?
    @State private var split: CGFloat = 0.5

    private var before: ProgressPhotoRow? { photos.first { $0.id == beforeID } ?? photos.last }
    private var after: ProgressPhotoRow? { photos.first { $0.id == afterID } ?? photos.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Compare").font(NoopHTMLFont.sheetTitle).foregroundStyle(NoopHTMLColor.ink)
                Spacer()
                Button("Done") { dismiss() }.foregroundStyle(NoopHTMLColor.inkSoft)
            }
            if let before, let after,
               let a = NoopProgressPhotoFiles.image(before.fileName), let b = NoopProgressPhotoFiles.image(after.fileName) {
                GeometryReader { geo in
                    ZStack {
                        Image(uiImage: b).resizable().scaledToFill().frame(width: geo.size.width, height: geo.size.height).clipped()
                        Image(uiImage: a).resizable().scaledToFill().frame(width: geo.size.width, height: geo.size.height).clipped()
                            .mask(alignment: .leading) { Rectangle().frame(width: geo.size.width * split) }
                        Rectangle().fill(.white).frame(width: 2).position(x: geo.size.width * split, y: geo.size.height / 2)
                        Circle().fill(.white).frame(width: 34, height: 34)
                            .overlay(Image(systemName: "arrow.left.and.right").font(.system(size: 13, weight: .bold)).foregroundStyle(.black))
                            .position(x: geo.size.width * split, y: geo.size.height / 2)
                    }
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { split = min(1, max(0, $0.location.x / geo.size.width)) })
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .aspectRatio(3 / 4, contentMode: .fit)
                .sensoryFeedback(.selection, trigger: split > 0.5)
                HStack {
                    picker("Before", selection: $beforeID, current: before)
                    Spacer()
                    picker("After", selection: $afterID, current: after)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .background(NoopHTMLColor.canvas)
    }

    private func picker(_ title: String, selection: Binding<String?>, current: ProgressPhotoRow) -> some View {
        Menu {
            ForEach(photos, id: \.id) { p in
                Button(Date(timeIntervalSince1970: Double(p.ts)).formatted(.dateTime.day().month(.abbreviated).year())) { selection.wrappedValue = p.id }
            }
        } label: {
            VStack(alignment: title == "Before" ? .leading : .trailing, spacing: 2) {
                Text(title.uppercased()).font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold)).tracking(1).foregroundStyle(NoopHTMLColor.muted)
                Text(Date(timeIntervalSince1970: Double(current.ts)).formatted(.dateTime.day().month(.abbreviated).year()))
                    .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
            }
        }
    }
}

enum NoopBodyFormat {
    static func display(_ stored: Double, _ kind: BodyMeasurementKind, _ units: UnitSystem) -> Double {
        switch kind.unit {
        case .mass: LiftFormat.display(fromKilograms: stored, system: units)
        case .percent: stored
        case .length: units == .imperial ? stored / 2.54 : stored
        }
    }

    static func stored(_ shown: Double, _ kind: BodyMeasurementKind, _ units: UnitSystem) -> Double {
        switch kind.unit {
        case .mass: LiftFormat.kilograms(fromDisplay: shown, system: units)
        case .percent: shown
        case .length: units == .imperial ? shown * 2.54 : shown
        }
    }

    static func unit(_ kind: BodyMeasurementKind, _ units: UnitSystem) -> String {
        switch kind.unit {
        case .mass: LiftFormat.weightUnit(units)
        case .percent: "%"
        case .length: units == .imperial ? "in" : "cm"
        }
    }

    static func label(_ shown: Double, _ kind: BodyMeasurementKind, _ units: UnitSystem) -> String {
        let n = (shown * 10).rounded() / 10
        return kind.unit == .percent ? "\(LiftFormat.trim(n))%" : "\(LiftFormat.trim(n)) \(unit(kind, units))"
    }
}
#endif
