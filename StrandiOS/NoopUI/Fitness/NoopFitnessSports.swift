#if os(iOS)
import SwiftUI
import UIKit

// MARK: - Starting a cardio session

/// Starts any recorded sport under the one-session rule every start button keeps. Weights are green
/// (volt) across Fitness; cardio and every other sport are Aura blue.
enum NoopCardioStarter {
    /// Returns the running session that blocked the start, if one did.
    @MainActor
    static func start(_ sport: String, goal: CardioGoal? = nil, zone: Int? = nil, app: AppModel,
                      live: LiftSessionController, navigation: NoopNavigation) -> NoopRunningSession? {
        if let running = NoopRunningSession.current(app: app, lift: live, navigation: navigation) { return running }
        app.startWorkout(sport: sport, targetZone: zone, goal: goal)
        navigation.beginSession(at: app.activeWorkout?.start ?? Date())
        navigation.push(.live)
        return nil
    }
}

// MARK: - Sports, grouped

/// The workout catalogue arranged for choosing: groups a person scans by, and a symbol per sport. The
/// names stay the catalogue's own (they are stored verbatim); only the grouping is presentation.
enum NoopSportGroups {
    struct Group: Identifiable {
        let title: String
        let sports: [String]
        var id: String { title }
    }

    static let groups: [Group] = [
        .init(title: "Cardio", sports: ["Running", "Walking", "Cycling", "Hiking", "Treadmill run", "Treadmill walk",
                                        "Indoor cycle", "Spinning", "Elliptical", "Rowing", "Row machine", "Stair climber",
                                        "Jump rope", "Rucking", "Nordic walking", "Mountain biking", "Wheelchair"]),
        .init(title: "Water", sports: ["Pool swim", "Open-water swim", "Water polo", "Surfing", "Kayaking", "Sailing",
                                       "Stand-up paddleboard", "Scuba diving", "Kiteboarding"]),
        .init(title: "Gym and studio", sports: ["HIIT", "CrossFit", "Boot camp", "Calisthenics", "Bodybuilding",
                                                "Weightlifting", "Powerlifting", "Yoga", "Pilates", "Stretching",
                                                "Dancing", "Ballet", "Breakdancing", "Cheerleading", "Gymnastics",
                                                "Climbing", "Meditation"]),
        .init(title: "Racket", sports: ["Tennis", "Padel", "Pickleball", "Squash", "Badminton", "Racquetball",
                                        "Table tennis"]),
        .init(title: "Team", sports: ["Soccer", "Basketball", "Volleyball", "Sand volleyball", "Baseball", "Softball",
                                      "American football", "Australian football", "Gaelic football", "Rugby",
                                      "Cricket", "Handball", "Ice Hockey", "Field hockey", "Lacrosse", "Netball",
                                      "Hurling/Camogie", "Frisbee", "Spikeball"]),
        .init(title: "Combat", sports: ["Boxing", "Kickboxing", "Martial arts", "Jiu jitsu", "Judo", "Fencing"]),
        .init(title: "Snow and ice", sports: ["Skiing", "Snowboarding", "Snowshoeing", "Ice skating", "Curling"]),
        .init(title: "Outdoors and more", sports: ["Golf", "Disc golf", "Inline skating", "Skateboarding",
                                                   "Horseback riding", "Archery", "Fishing", "Hunting", "Bowling",
                                                   "Billiards", "Darts", "Motocross", "Motor racing", "Gaming"]),
    ]

    /// Every catalogue sport, grouped; a sport the groups do not name falls into the last group, so the
    /// catalogue can grow without a sport going missing here.
    static var all: [Group] {
        let named = Set(groups.flatMap(\.sports))
        let catalog = WorkoutCatalog.all.map(\.name).filter { $0 != "Strength" && $0 != "Other" }
        let rest = catalog.filter { !named.contains($0) }
        let known = Set(catalog)
        var out = groups.map { Group(title: $0.title, sports: $0.sports.filter(known.contains)) }
        if !rest.isEmpty, let last = out.indices.last {
            out[last] = Group(title: out[last].title, sports: out[last].sports + rest)
        }
        return out.filter { !$0.sports.isEmpty }
    }

    /// The sports shown on Fitness when there is no history yet.
    static let starters = ["Running", "Walking", "Cycling", "HIIT", "Pool swim", "Yoga"]

    /// Exact symbols for names a substring rule would get wrong (Table tennis is not tennis, American
    /// football is not soccer). Each is checked to exist on this system before it is used.
    static let exactSymbols: [String: String] = [
        "Table tennis": "figure.table.tennis", "Badminton": "figure.badminton", "Squash": "figure.squash",
        "Racquetball": "figure.racquetball", "Pickleball": "figure.pickleball", "Padel": "figure.tennis",
        "Volleyball": "figure.volleyball", "Sand volleyball": "figure.volleyball", "Baseball": "figure.baseball",
        "Softball": "figure.softball", "American football": "figure.american.football",
        "Australian football": "figure.australian.football", "Gaelic football": "figure.australian.football",
        "Rugby": "figure.rugby", "Cricket": "figure.cricket", "Handball": "figure.handball",
        "Ice Hockey": "figure.hockey", "Field hockey": "figure.hockey", "Lacrosse": "figure.lacrosse",
        "Hurling/Camogie": "figure.hockey", "Frisbee": "figure.disc.sports", "Disc golf": "figure.disc.sports",
        "Water polo": "figure.waterpolo", "Sailing": "figure.sailing", "Kayaking": "figure.rower",
        "Stand-up paddleboard": "figure.surfing", "Kiteboarding": "figure.surfing", "Scuba diving": "figure.pool.swim",
        "Snowboarding": "figure.snowboarding", "Ice skating": "figure.skating", "Inline skating": "figure.skating",
        "Curling": "figure.curling", "Snowshoeing": "figure.hiking", "Golf": "figure.golf",
        "Archery": "figure.archery", "Bowling": "figure.bowling", "Fishing": "figure.fishing",
        "Hunting": "figure.hunting", "Horseback riding": "figure.equestrian.sports", "Fencing": "figure.fencing",
        "Gymnastics": "figure.gymnastics", "Kickboxing": "figure.kickboxing", "Jiu jitsu": "figure.wrestling",
        "Judo": "figure.wrestling", "Jump rope": "figure.jumprope", "Stair climber": "figure.stair.stepper",
        "Meditation": "figure.mind.and.body", "Wheelchair": "figure.roll", "Gaming": "gamecontroller.fill",
        "Calisthenics": "figure.cross.training", "Boot camp": "figure.cross.training", "CrossFit": "figure.cross.training",
        "Bodybuilding": "figure.strengthtraining.traditional", "Weightlifting": "figure.strengthtraining.traditional",
        "Powerlifting": "figure.strengthtraining.traditional", "Ballet": "figure.dance", "Breakdancing": "figure.dance",
        "Cheerleading": "figure.dance", "Mountain biking": "figure.outdoor.cycle", "Spinning": "figure.indoor.cycle",
        "Treadmill walk": "figure.walk", "Rucking": "figure.hiking", "Nordic walking": "figure.walk",
        "Row machine": "figure.rower", "Skateboarding": "skateboard.fill", "Motocross": "figure.outdoor.cycle",
        "Motor racing": "steeringwheel", "Billiards": "circle.circle", "Darts": "scope", "Spikeball": "figure.volleyball",
        "Netball": "figure.basketball",
    ]

    private static var verified: [String: Bool] = [:]

    /// The exact symbol for a sport, when it has one and this system draws it.
    static func exactSymbol(_ sport: String) -> String? {
        guard let name = exactSymbols[sport] else { return nil }
        if let ok = verified[name] { return ok ? name : nil }
        let ok = UIImage(systemName: name) != nil
        verified[name] = ok
        return ok ? name : nil
    }
}

// MARK: - Fitness section

/// "Cardio and sports" on Fitness: the sports this person actually does, newest first, each a tap from
/// a recorded session, and every other sport one sheet away.
struct NoopFitnessSportsSection: View {
    @ObservedObject var navigation: NoopNavigation
    let workouts: [NoopFitnessHistory.Workout]
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var live: LiftSessionController
    @State private var refusal: NoopRunningSession?
    @State private var choosing = false

    /// Up to six: the cardio sports done most recently, then the starters to fill the row.
    private var shown: [(sport: String, last: Date?)] {
        var out: [(String, Date?)] = []
        for w in workouts.filter({ !$0.isStrength }).sorted(by: { $0.start > $1.start }) {
            let name = w.title
            guard !name.isEmpty, !["detected", "other", "activity"].contains(name.lowercased()),
                  !out.contains(where: { $0.0.caseInsensitiveCompare(name) == .orderedSame }) else { continue }
            out.append((name, w.start))
            if out.count == 6 { return out }
        }
        for s in NoopSportGroups.starters where !out.contains(where: { $0.0 == s }) {
            out.append((s, nil))
            if out.count == 6 { break }
        }
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let refusal {
                Text("\(refusal.name) is still running. Finish it before starting another session.")
                    .font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.blueLight)
                    .transition(.opacity)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(shown, id: \.sport) { item in
                    NoopSportTile(sport: item.sport, detail: item.last.map(Self.ago)) { start(item.sport) }
                }
            }
            Button { choosing = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "square.grid.2x2.fill").font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(NoopHTMLColor.blueLight)
                    Text("Every sport").font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                    Text("\(WorkoutCatalog.all.count - 2) to choose from").font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                    Spacer()
                    NoopFixedChevron(direction: .right, color: NoopHTMLColor.chevronDim)
                }
                .padding(.horizontal, 16).frame(minHeight: 50)
                .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
            }
            .buttonStyle(NoopHTMLPressStyle())
        }
        .padding(.bottom, 22)
        .sheet(isPresented: $choosing) {
            NoopSportPickerSheet(recent: shown.filter { $0.last != nil }.map(\.sport)) { sport in
                choosing = false
                start(sport)
            }
            .noopSheet()
        }
    }

    private func start(_ sport: String, goal: CardioGoal? = nil, zone: Int? = nil) {
        if let blocked = NoopCardioStarter.start(sport, goal: goal, zone: zone, app: app, live: live, navigation: navigation) {
            withAnimation(NoopMotion.swap) { refusal = blocked }
        }
    }

    private static func ago(_ d: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "Today" }
        if cal.isDateInYesterday(d) { return "Yesterday" }
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: d), to: cal.startOfDay(for: Date())).day ?? 0
        return days < 7 ? d.formatted(.dateTime.weekday(.wide)) : d.formatted(.dateTime.day().month(.abbreviated))
    }
}

/// One sport to start: its figure on a blue disc, the name, and when it was last done.
struct NoopSportTile: View {
    let sport: String
    var detail: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: NoopFitnessCardioLive.symbol(for: sport))
                    .font(.system(size: 20, weight: .medium)).foregroundStyle(NoopHTMLColor.blueLight)
                    .frame(width: 44, height: 44)
                    .background(NoopHTMLColor.blueLight.opacity(0.13), in: Circle())
                VStack(spacing: 1) {
                    Text(sport).font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                        .lineLimit(1).minimumScaleFactor(0.75)
                    Text(detail ?? "Start").font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.copy)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14).padding(.horizontal, 6)
            .background(
                LinearGradient(colors: [NoopHTMLColor.blueLight.opacity(0.07), NoopHTMLColor.card], startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
        }
        .buttonStyle(NoopHTMLPressStyle())
        .accessibilityLabel("Start \(sport)")
    }
}

// MARK: - Every sport

/// Every sport in the catalogue, grouped the way people look for them, with search. Tapping one starts it.
struct NoopSportPickerSheet: View {
    var recent: [String] = []
    let pick: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var groups: [NoopSportGroups.Group] {
        var all = NoopSportGroups.all
        if !recent.isEmpty { all.insert(.init(title: "Recent", sports: recent), at: 0) }
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return all }
        let hits = all.dropFirst(recent.isEmpty ? 0 : 1).flatMap(\.sports).filter { $0.localizedCaseInsensitiveContains(q) }
        return hits.isEmpty ? [] : [.init(title: "Matches", sports: hits)]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Start a session").font(NoopHTMLFont.sheetTitle).foregroundStyle(NoopHTMLColor.ink)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(NoopHTMLColor.inkSoft)
                        .frame(width: 36, height: 36).background(Color.white.opacity(0.07), in: Circle())
                        .noopHitTarget()
                }
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 20).padding(.top, 20)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 14, weight: .semibold)).foregroundStyle(NoopHTMLColor.copy)
                TextField("Search sports", text: $query)
                    .font(NoopHTMLFont.sans(NoopType.subhead)).foregroundStyle(NoopHTMLColor.ink)
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(NoopHTMLColor.copy)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 14).frame(minHeight: 46)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 6)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22, pinnedViews: []) {
                    if groups.isEmpty {
                        Text("No sport by that name. Start the closest one and rename it afterwards.")
                            .font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
                            .padding(.top, 20)
                    }
                    ForEach(groups) { g in
                        VStack(alignment: .leading, spacing: 10) {
                            NoopSectionLabel(g.title)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                                ForEach(g.sports, id: \.self) { s in
                                    NoopSportTile(sport: s) { pick(s) }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(NoopHTMLColor.canvas.ignoresSafeArea())
    }
}
#endif
