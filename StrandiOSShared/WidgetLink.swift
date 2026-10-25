import Foundation

/// A widget or Live Activity tap that opens one screen: `noop://open/<route>?from=<parent>`.
///
/// The route and parent are `NoopRoute` raw values, kept as strings here because the widget extension
/// does not compile the app's navigation. The app checks both against `NoopRoute` before acting, so a
/// link from an older widget build that names a screen which no longer exists does nothing.
public struct WidgetLink: Equatable, Sendable {
    public static let scheme = "noop"
    public static let host = "open"

    public let route: String
    public let parent: String?
    /// What the link acts on, for a start link: the sport name or the routine id.
    public let item: String?

    public init(route: String, parent: String? = nil, item: String? = nil) {
        self.route = route
        self.parent = parent
        self.item = item
    }

    public init?(url: URL) {
        guard url.scheme == Self.scheme, url.host == Self.host else { return nil }
        let route = url.pathComponents.dropFirst().first ?? ""
        guard !route.isEmpty else { return nil }
        self.route = route
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        parent = items?.first { $0.name == "from" }?.value
        item = items?.first { $0.name == "item" }?.value
    }

    public var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = Self.host
        components.path = "/" + route
        var items: [URLQueryItem] = []
        if let parent { items.append(URLQueryItem(name: "from", value: parent)) }
        if let item { items.append(URLQueryItem(name: "item", value: item)) }
        if !items.isEmpty { components.queryItems = items }
        return components.url ?? URL(string: "noop://open")!
    }

    public static let sleep = WidgetLink(route: "rest", parent: "today")
    public static let steps = WidgetLink(route: "today")
    public static let vitals = WidgetLink(route: "vitals", parent: "today")
    public static let weight = WidgetLink(route: "fitness-body", parent: "fitness")
    public static let workouts = WidgetLink(route: "fitness")
    public static let consistency = WidgetLink(route: "fitness-calendar", parent: "fitness")
    public static let goal = WidgetLink(route: "goal", parent: "you")
    public static let liveSession = WidgetLink(route: "live", parent: "fitness")
    /// Start a recorded session of a sport, or a saved routine, as the Fitness tiles do.
    public static func startSport(_ name: String) -> WidgetLink { WidgetLink(route: "start-sport", item: name) }
    public static func startRoutine(_ id: String) -> WidgetLink { WidgetLink(route: "start-routine", item: id) }
}

public extension Notification.Name {
    /// Posted by the app with a `noop://open/…` URL; the shell routes it.
    static let noopOpenWidgetLink = Notification.Name("noop.openWidgetLink")
}
