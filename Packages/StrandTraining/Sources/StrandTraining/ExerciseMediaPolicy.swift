import Foundation

/// Pinned content identifiers only; no wearer or workout information belongs in a media request.
public enum ExerciseMediaPolicy {
    public enum Kind: String, Sendable { case animation, thumbnail }

    public static func url(for exercise: TrainingExercise, kind: Kind) -> URL? {
        let media = TrainingStarterCatalog.mediaReferences[exercise.id.replacingOccurrences(of: "noop:", with: "")] ?? exercise.mediaId
        guard let entry = BundledExerciseCatalog.exercises.first(where: {
            $0.mediaId == media && media != nil
        }), let source = entry.sourceId, let media = entry.mediaId,
              let provenance = BundledExerciseCatalog.sourceRevision,
              let revision = provenance.split(separator: "@").last?.split(separator: ":").first else { return nil }
        return url(revision: String(revision), sourceId: source, mediaId: media, kind: kind)
    }

    public static func url(revision: String, sourceId: String, mediaId: String, kind: Kind) -> URL? {
        let allowed = CharacterSet.alphanumerics
        guard [revision, sourceId, mediaId].allSatisfy({
            !$0.isEmpty && $0.unicodeScalars.allSatisfy(allowed.contains)
        }) else { return nil }
        let path = kind == .animation ? "videos/\(sourceId)-\(mediaId).gif" : "images/\(sourceId)-\(mediaId).jpg"
        return URL(string: "https://raw.githubusercontent.com/hasaneyldrm/exercises-dataset/\(revision)/\(path)")
    }

    public struct CacheEntry: Equatable, Sendable {
        public let name: String
        public let bytes: Int
        public let accessed: Date
        public init(name: String, bytes: Int, accessed: Date) {
            self.name = name; self.bytes = bytes; self.accessed = accessed
        }
    }

    public static func evictions(_ entries: [CacheEntry], limit: Int = ExerciseContentLimits.mediaCacheBytes) -> [String] {
        var bytes = entries.reduce(0) { $0 + max(0, $1.bytes) }
        var removed: [String] = []
        for entry in entries.sorted(by: { ($0.accessed, $0.name) < ($1.accessed, $1.name) }) {
            guard bytes > max(0, limit) else { break }
            bytes -= max(0, entry.bytes)
            removed.append(entry.name)
        }
        return removed
    }
}
