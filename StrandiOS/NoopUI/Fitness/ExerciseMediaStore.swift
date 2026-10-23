#if os(iOS)
import SwiftUI
import ImageIO
import StrandTraining
import StrandFitness

actor ExerciseMediaStore {
    static let shared = ExerciseMediaStore()
    static let enabledKey = "noop.fitness.exerciseAnimations"
    private let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("ExerciseMedia", isDirectory: true)
    private var session: URLSession?

    private final class NoRedirect: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
        func urlSession(_ session: URLSession, task: URLSessionTask,
                        willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                        completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
    }

    func cancelDownloads() {
        session?.invalidateAndCancel()
        session = nil
    }

    func data(for exercise: TrainingExercise, kind: ExerciseMediaPolicy.Kind) async -> Data? {
        guard UserDefaults.standard.bool(forKey: Self.enabledKey), !Task.isCancelled,
              let remote = ExerciseMediaPolicy.url(for: exercise, kind: kind) else { return nil }
        let file = directory.appendingPathComponent(remote.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent
                                                   + "-" + remote.lastPathComponent)
        let fm = FileManager.default
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        evict()
        if let data = try? Data(contentsOf: file) {
            try? fm.setAttributes([.modificationDate: Date()], ofItemAtPath: file.path)
            return data
        }
        if session == nil {
            let config = URLSessionConfiguration.ephemeral
            config.urlCache = nil
            config.httpCookieStorage = nil
            config.httpShouldSetCookies = false
            config.timeoutIntervalForRequest = 20
            session = URLSession(configuration: config, delegate: NoRedirect(), delegateQueue: nil)
        }
        guard let session else { return nil }
        do {
            let (bytes, response) = try await session.bytes(from: remote)
            guard let response = response as? HTTPURLResponse, response.statusCode == 200,
                  response.expectedContentLength <= 12 * 1_024 * 1_024 else { return nil }
            var data = Data()
            for try await byte in bytes {
                if data.count % 16_384 == 0 {
                    guard !Task.isCancelled, UserDefaults.standard.bool(forKey: Self.enabledKey),
                          data.count < 12 * 1_024 * 1_024 else { return nil }
                }
                data.append(byte)
            }
            guard !Task.isCancelled, UserDefaults.standard.bool(forKey: Self.enabledKey),
                  let source = CGImageSourceCreateWithData(data as CFData, nil),
                  CGImageSourceGetCount(source) > 0 else { return nil }
            try data.write(to: file, options: .atomic)
            evict()
            return data
        } catch { return nil }
    }

    private func evict() {
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: directory,
                     includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])) ?? []
        let entries = files.compactMap { url -> ExerciseMediaPolicy.CacheEntry? in
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]) else { return nil }
            return .init(name: url.lastPathComponent, bytes: values.fileSize ?? 0,
                         accessed: values.contentModificationDate ?? .distantPast)
        }
        for name in ExerciseMediaPolicy.evictions(entries) {
            try? fm.removeItem(at: directory.appendingPathComponent(name))
        }
    }
}

private struct ExerciseFrames: @unchecked Sendable {
    var images: [CGImage] = []
    var ends: [Double] = []
    var duration: Double { ends.last ?? 1 }

    init(data: Data, animated: Bool) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return }
        let count = min(CGImageSourceGetCount(source), animated ? 300 : 1)
        for index in 0..<count {
            let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                            kCGImageSourceThumbnailMaxPixelSize: 360]
            guard let frame = CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary) else { continue }
            let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
            let gif = props?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let delay = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
                ?? (gif?[kCGImagePropertyGIFDelayTime] as? Double) ?? 0.1
            images.append(frame)
            ends.append((ends.last ?? 0) + max(0.02, delay))
        }
    }
}

struct NoopExerciseMedia: View {
    let choice: NoopFitnessExerciseChoice
    var thumbnail = false
    /// A fixed square thumbnail with no credit line under it, for pages that credit the media once.
    var tile: CGFloat? = nil
    @AppStorage(ExerciseMediaStore.enabledKey) private var enabled = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var frames: ExerciseFrames?
    @State private var visible = false
    @State private var started = Date()

    var body: some View {
        VStack(spacing: 4) {
            Group {
                if enabled, let frames, !frames.images.isEmpty {
                    TimelineView(.animation(minimumInterval: 1.0 / 30,
                                            paused: thumbnail || reduceMotion || !visible || scenePhase != .active)) { context in
                        let elapsed = reduceMotion ? 0 : context.date.timeIntervalSince(started).truncatingRemainder(dividingBy: frames.duration)
                        let index = frames.ends.firstIndex { $0 > elapsed } ?? 0
                        Image(decorative: frames.images[index], scale: 1)
                            .resizable().scaledToFit()
                    }
                    .background(NoopHTMLColor.ink)
                } else {
                    NoopFitnessBodyMap(color: { group in
                        FitnessMuscleGroup.forMuscleId(choice.definition?.primaryMuscleId ?? choice.primary?.rawValue ?? "") == group ? NoopHTMLColor.volt : NoopHTMLColor.muted
                    }, compact: true)
                    .padding(8)
                }
            }
            .frame(height: tile ?? (thumbnail ? 48 : 210))
            .frame(maxWidth: .infinity)
            .background(NoopHTMLColor.cardRaised)
            .clipShape(RoundedRectangle(cornerRadius: tile.map { $0 * 0.26 } ?? (thumbnail ? 10 : 20), style: .continuous))
            if tile == nil {
                Text("© Gym visual").font(NoopHTMLFont.sans(thumbnail ? 8 : 11)).foregroundStyle(NoopHTMLColor.copy)
                    .opacity(enabled && frames?.images.isEmpty == false ? 1 : 0)
                    .accessibilityHidden(!enabled || frames?.images.isEmpty != false)
            }
        }
        .frame(width: tile ?? (thumbnail ? 64 : nil))
        .onAppear { visible = true; started = Date() }
        .onDisappear { visible = false }
        .onGeometryChange(for: Bool.self) { proxy in
            proxy.frame(in: .global).intersects(UIScreen.main.bounds)
        } action: { visible = $0 }
        .task(id: "\(choice.id)-\(enabled)-\(reduceMotion)") {
            frames = nil
            guard enabled, let exercise = choice.definition,
                  let data = await ExerciseMediaStore.shared.data(for: exercise, kind: thumbnail ? .thumbnail : .animation) else { return }
            let animated = !thumbnail && !reduceMotion
            let decoded = await Task.detached(priority: .utility) { ExerciseFrames(data: data, animated: animated) }.value
            guard !Task.isCancelled, enabled else { return }
            frames = decoded
        }
    }
}

struct NoopExerciseAnimationToggle: View {
    @AppStorage(ExerciseMediaStore.enabledKey) private var enabled = false
    var body: some View {
        Toggle(isOn: $enabled) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Exercise animations").font(NoopHTMLFont.sans(14, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                Text("Download exercise media from GitHub when viewed. Cached media works offline.")
                    .font(NoopHTMLFont.sans(12)).foregroundStyle(NoopHTMLColor.copy)
            }
        }
        .tint(NoopHTMLColor.volt)
        .onChange(of: enabled) { _, on in
            if !on { Task { await ExerciseMediaStore.shared.cancelDownloads() } }
        }
    }
}
#endif
