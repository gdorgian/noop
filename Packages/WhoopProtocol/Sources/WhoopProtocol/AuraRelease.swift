import Foundation

/// One published Noop Aura release, read from the fork's GitHub releases.
///
/// Aura ships many builds on one upstream version ("v12.0.0-aura.1206", then a beta
/// "v12.0.0-aura.1220"), so the version alone can never say a release is new: the build number does.
/// Comparing only the upstream version is how the bell stayed silent through every Aura beta.
public struct AuraRelease: Equatable, Sendable {

    public enum Kind: String, Equatable, Sendable {
        /// A pre-release: try it and report.
        case beta
        /// A new major version over the installed one (13.x over 12.x).
        case major
        /// Any other release.
        case release
    }

    public let version: String
    public let build: Int
    public let prerelease: Bool
    public let name: String
    public let url: URL
    public let notes: String

    public init(version: String, build: Int, prerelease: Bool, name: String, url: URL, notes: String) {
        self.version = version
        self.build = build
        self.prerelease = prerelease
        self.name = name
        self.url = url
        self.notes = notes
    }

    /// "v12.0.0-aura.1220" → ("12.0.0", 1220). Nil for any tag that is not an Aura one.
    public static func parseTag(_ tag: String) -> (version: String, build: Int)? {
        var t = Substring(tag.trimmingCharacters(in: .whitespaces))
        if t.first == "v" || t.first == "V" { t = t.dropFirst() }
        let parts = t.components(separatedBy: "-aura.")
        guard parts.count == 2, !parts[0].isEmpty, let build = Int(parts[1]) else { return nil }
        return (parts[0], build)
    }

    /// How this release stands against what is installed.
    public func kind(installedVersion: String) -> Kind {
        if prerelease { return .beta }
        let mine = VersionCheck.segments(installedVersion).first ?? 0
        let theirs = VersionCheck.segments(version).first ?? 0
        return theirs > mine ? .major : .release
    }

    /// What the bell should announce: the newest full release past the installed build, and the newest
    /// beta past both, newest first. One row per channel, so a run of betas reads as one, not five.
    public static func announcements(_ releases: [AuraRelease], installedBuild: Int) -> [AuraRelease] {
        let newer = releases.filter { $0.build > installedBuild }.sorted { $0.build > $1.build }
        let stable = newer.first { !$0.prerelease }
        let beta = newer.first { $0.prerelease && $0.build > (stable?.build ?? installedBuild) }
        return [beta, stable].compactMap { $0 }
    }
}
