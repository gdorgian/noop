#if os(iOS)
import SwiftUI
import WhoopStore
import StrandTraining

// MARK: - Exercise choices

/// One exercise the picker can offer: from the wearer's own Lift vocabulary, or from the bundled
/// catalogue (ExerciseDB via hasaneyldrm/exercises-dataset, MIT), mapped onto Lift muscles.
struct NoopFitnessExerciseChoice: Identifiable, Equatable {
    let name: String
    let primary: LiftMuscle?
    let secondaries: [LiftMuscle]
    let equipment: String?
    let isYours: Bool
    var definition: TrainingExercise? = nil
    var id: String { definition?.id ?? (isYours ? "y:" : "c:") + name }

    static func choice(_ e: TrainingExercise, yours: Bool = false) -> Self {
        .init(name: e.title, primary: e.primaryMuscleId.flatMap(liftMuscle),
              secondaries: e.secondaryMuscleIds.compactMap(liftMuscle),
              equipment: e.equipmentIds.map { $0.replacingOccurrences(of: "-", with: " ").capitalized }.joined(separator: ", "),
              isYours: yours, definition: e)
    }

    static func choice(_ row: LiftExerciseRow) -> Self {
        if let json = row.definitionJSON, let data = json.data(using: .utf8),
           let definition = try? JSONDecoder().decode(TrainingExercise.self, from: data) {
            var choice = Self.choice(definition, yours: true)
            choice = .init(name: row.name, primary: row.primaryMuscle, secondaries: row.secondaryMuscles,
                           equipment: choice.equipment, isYours: true, definition: definition)
            return choice
        }
        let known = (TrainingStarterCatalog.exercises + BundledExerciseCatalog.exercises).first {
            NoopFitnessExercisePicker.fold($0.title) == NoopFitnessExercisePicker.fold(row.name)
        }
        return .init(name: row.name, primary: row.primaryMuscle, secondaries: row.secondaryMuscles,
                     equipment: known?.equipmentIds.joined(separator: ", "), isYours: true, definition: known)
    }

    var muscleLine: String { LiftMuscleSummary.line(primary: primary, secondaries: secondaries) }

    /// The catalogue's anatomy ids onto the Lift log's muscle vocabulary. Hip flexors have no Lift
    /// muscle of their own, so they are left out rather than misfiled.
    static func liftMuscle(_ catalogId: String) -> LiftMuscle? {
        switch catalogId {
        case "chest", "upper_chest", "lower_chest": .chest
        case "front_delts": .frontDelts
        case "side_delts": .sideDelts
        case "rear_delts", "rotator_cuff": .rearDelts
        case "triceps": .triceps
        case "biceps": .biceps
        case "forearms": .forearms
        case "lats": .lats
        case "upper_back", "rhomboids": .upperBack
        case "traps", "upper_traps", "lower_traps": .traps
        case "lower_back": .lowerBack
        case "abdominals", "upper_abs", "lower_abs", "serratus": .abs
        case "obliques": .obliques
        case "quadriceps", "inner_quadriceps", "outer_quadriceps": .quads
        case "hamstrings": .hamstrings
        case "glutes": .glutes
        case "adductors": .adductors
        case "abductors": .abductors
        case "calves", "tibialis": .calves
        case "neck": .neck
        default: nil
        }
    }

    static let catalogue = (TrainingStarterCatalog.exercises + BundledExerciseCatalog.exercises).map { choice($0) }
}

/// Search the local catalogue, inspect a movement, and add selections in the order they were chosen.
struct NoopFitnessExercisePicker: View {
    let yours: [LiftExerciseRow]
    var onPick: ((NoopFitnessExerciseChoice) -> Void)? = nil
    var onPickMany: (([NoopFitnessExerciseChoice]) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var selected: [NoopFitnessExerciseChoice] = []
    @State private var groups = Set<String>()
    @State private var equipment = Set<String>()
    @State private var filter: String?
    @State private var detail: NoopFitnessExerciseChoice?
    @State private var creating = false
    @State private var custom: [NoopFitnessExerciseChoice] = []

    static func fold(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "-", with: " ").split(separator: " ").joined(separator: " ")
    }

    static func rank(_ name: String, _ q: String) -> Int? {
        let n = fold(name)
        guard n.contains(q) else { return nil }
        return (n == q ? 0 : n.hasPrefix(q) ? 1 : 2) * 1000 + n.count
    }

    private var choices: [NoopFitnessExerciseChoice] {
        var seen = Set<String>()
        let all = custom + yours.map(NoopFitnessExerciseChoice.choice) + NoopFitnessExerciseChoice.catalogue
        return all.filter { seen.insert(Self.fold($0.name)).inserted }
    }

    private var results: [NoopFitnessExerciseChoice] {
        let q = Self.fold(query.trimmingCharacters(in: .whitespacesAndNewlines))
        return choices.filter { c in
            (q.isEmpty || Self.rank(c.name, q) != nil)
                && (groups.isEmpty || groups.contains(c.primary?.rawValue ?? ""))
                && (equipment.isEmpty || !equipment.isDisjoint(with: c.definition?.equipmentIds ?? []))
        }.sorted {
            let a = q.isEmpty ? 0 : Self.rank($0.name, q) ?? 0
            let b = q.isEmpty ? 0 : Self.rank($1.name, q) ?? 0
            return a == b ? $0.name.localizedStandardCompare($1.name) == .orderedAscending : a < b
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Text("Exercise library").font(NoopHTMLFont.sheetTitle)
                Spacer()
                Button("Add (\(selected.count))") {
                    if let onPickMany { onPickMany(selected) }
                    else { selected.forEach { onPick?($0) } }
                    dismiss()
                }.disabled(selected.isEmpty)
            }
            TextField("Search exercises", text: $query).autocorrectionDisabled()
                .padding(12).background(NoopHTMLColor.cardRaised, in: RoundedRectangle(cornerRadius: 12))
            HStack {
                Button(groups.isEmpty ? "All groups" : "Groups (\(groups.count))") { filter = "groups" }
                Button(equipment.isEmpty ? "All equipment" : "Equipment (\(equipment.count))") { filter = "equipment" }
                Spacer()
            }.buttonStyle(.bordered)
            ScrollView {
                LazyVStack(spacing: 8) {
                    Button { creating = true } label: {
                        Label("Add custom exercise", systemImage: "plus").frame(maxWidth: .infinity, alignment: .leading).padding(14)
                    }
                    ForEach(results) { row($0) }
                    if results.isEmpty { Text("No matching exercises").foregroundStyle(NoopHTMLColor.copy).padding() }
                    Text("Catalogue: ExerciseDB via hasaneyldrm/exercises-dataset, MIT licence.")
                        .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.muted)
                }
            }
        }
        .padding(20).font(NoopHTMLFont.sans(14)).foregroundStyle(NoopHTMLColor.ink)
        .tint(NoopHTMLColor.volt).background(NoopHTMLColor.canvas)
        .sensoryFeedback(.selection, trigger: selected.count)
        .sheet(item: $detail) { NoopFitnessExerciseDetail(choice: $0).noopSheet() }
        .sheet(isPresented: Binding(get: { filter != nil }, set: { if !$0 { filter = nil } })) {
            if filter == "groups" {
                NoopFitnessChecklist(title: "muscle groups", options: LiftMuscle.ordered.map { ($0.rawValue, $0.displayName) }, selection: $groups)
            } else {
                NoopFitnessChecklist(title: "equipment", options: TrainingEquipmentCatalog.known.sorted().map {
                    ($0, $0.replacingOccurrences(of: "-", with: " ").capitalized)
                }, selection: $equipment)
            }
        }
        .sheet(isPresented: $creating) {
            NoopFitnessCustomExercise { choice in
                custom.append(choice)
                if onPickMany == nil { selected = [choice] } else { selected.append(choice) }
            }.noopSheet()
        }
        .noopSheet()
    }

    private func row(_ choice: NoopFitnessExerciseChoice) -> some View {
        HStack(spacing: 10) {
            NoopExerciseMedia(choice: choice, thumbnail: true)
            Button { select(choice) } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(choice.name).font(NoopHTMLFont.sans(14, weight: .medium)).foregroundStyle(NoopHTMLColor.ink)
                    Text(choice.equipment ?? choice.muscleLine).font(NoopHTMLFont.sans(12)).foregroundStyle(NoopHTMLColor.copy)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.plain)
            Button { detail = choice } label: { Image(systemName: "info.circle").frame(width: 32, height: 44) }
                .accessibilityLabel("About \(choice.name)")
            Button { select(choice) } label: {
                Image(systemName: selected.contains(where: { $0.id == choice.id }) ? "checkmark.circle.fill" : "plus")
                    .frame(width: 32, height: 44)
            }.accessibilityLabel(selected.contains(where: { $0.id == choice.id }) ? "Deselect \(choice.name)" : "Select \(choice.name)")
        }.padding(10).background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private func select(_ choice: NoopFitnessExerciseChoice) {
        withAnimation(.spring(response: 0.3)) {
            if selected.contains(where: { $0.id == choice.id }) { selected.removeAll { $0.id == choice.id } }
            else if onPickMany == nil { selected = [choice] }
            else { selected.append(choice) }
        }
    }
}

// MARK: - Routine editor

struct NoopFitnessRoutineEditor: View {
    @ObservedObject var navigation: NoopNavigation
    @ObservedObject var fitness: NoopFitnessModel
    @EnvironmentObject private var repo: Repository
    @EnvironmentObject private var profile: ProfileStore
    @EnvironmentObject private var settings: NoopFitnessSettings
    @AppStorage(UnitPrefs.systemKey) private var unitSystemRaw = UnitSystem.metric.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    struct Line: Identifiable, Equatable {
        var choice: NoopFitnessExerciseChoice
        var plan: RoutineExercise
        var pounds = false
        var id: UUID { plan.id }
    }
    struct History: Identifiable {
        let id = UUID()
        let lineID: UUID
        let date: Date
        let sets: [RoutineSetPlan]
    }

    @State private var name = ""
    @State private var lines: [Line] = []
    @State private var program: LiftProgramRow?
    @State private var vocabulary: [LiftExerciseRow] = []
    @State private var picking = false
    @State private var insertion: Int?
    @State private var replacement: UUID?
    @State private var saving = false
    @State private var error: String?
    @State private var confirmDelete = false
    @State private var loaded = false
    @State private var planIt = false
    @State private var repeatPlan = NoopFitnessRepeatPlan()
    @State private var detail: NoopFitnessExerciseChoice?
    @State private var reorder = false
    @State private var progressionID: UUID?
    @State private var restID: UUID?
    @State private var repRangeID: UUID?
    @State private var repsLow = 6
    @State private var repsHigh = 10
    @State private var history: History?
    @State private var toast: String?
    @State private var feedback = 0
    /// The set field being typed in, as "<set id>.<w|r>"; drives the bar above the number pad.
    @FocusState private var focusedField: String?

    private var units: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }
    private var isNew: Bool { navigation.fitnessRoutineID == nil }
    private var spring: Animation? { reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.85) }
    private var typedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    /// What an unnamed routine is saved as: its muscles ("Quads & Glutes"), else its first exercise.
    private var suggestedName: String {
        var muscles: [String] = []
        for line in lines {
            guard let m = line.choice.primary?.displayName, !muscles.contains(m) else { continue }
            muscles.append(m)
        }
        if (1...2).contains(muscles.count) { return muscles.joined(separator: " & ") }
        if muscles.count > 2 { return "Full body" }
        return lines.first?.choice.name ?? "Routine"
    }
    private var canSave: Bool {
        !lines.isEmpty
            && (isNew || loaded) && lines.allSatisfy { line in
                !line.plan.sets.isEmpty && line.plan.sets.allSatisfy { set in
                    (set.targetWeightKg.map { $0.isFinite && $0 >= 0 } ?? true)
                        && (set.repsMin.map { $0 > 0 } ?? true)
                        && (set.targetDurationS.map { $0 > 0 } ?? true)
                        && (set.restSeconds.map { $0 >= 0 } ?? true)
                }
            } && (!planIt || (repeatPlan.isValid && !repeatPlan.dates.isEmpty))
    }

    var body: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    NoopBackHeader(label: isNew ? "Fitness" : "Routine") { navigation.back(or: .fitness) }
                    Spacer()
                    Menu {
                        Button("Reorder exercises") { reorder = true }.disabled(lines.count < 2)
                        if !isNew { Button("Delete routine", role: .destructive) { confirmDelete = true } }
                    } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                }
                Text(isNew ? "New routine" : "Edit routine").font(NoopHTMLFont.sheetTitle)
                TextField(lines.isEmpty ? "Routine name" : suggestedName, text: $name)
                    .focused($focusedField, equals: "name").submitLabel(.done)
                    .font(NoopHTMLFont.sans(17, weight: .medium)).padding(15)
                    .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 16))
                if lines.isEmpty {
                    VStack(spacing: 16) {
                        Text("No exercises yet").font(NoopHTMLFont.sheetTitle)
                        Text("Choose movements to build your routine.").foregroundStyle(NoopHTMLColor.copy)
                        Button("Add exercises") { openPicker() }.buttonStyle(.borderedProminent).foregroundStyle(NoopHTMLColor.voltInk)
                    }.frame(maxWidth: .infinity).padding(.vertical, 36)
                }
                ForEach($lines) { $line in
                    lineCard($line)
                    if linkedToNext(line.id) {
                        Image(systemName: "link").foregroundStyle(NoopHTMLColor.volt).frame(maxWidth: .infinity)
                            .accessibilityLabel("Superset")
                    }
                }
                // An already-scheduled routine keeps its schedule on the routine page; a second plan here
                // would add a duplicate set of dates.
                if isNew || !settings.plans.contains(where: {
                    $0.routineID == navigation.fitnessRoutineID && $0.isUpcoming(asOf: Date())
                }) {
                    NoopFitnessPanel {
                        Toggle("Put it on the calendar", isOn: $planIt)
                        if planIt { NoopFitnessRepeatEditor(plan: $repeatPlan) }
                    }
                }
                if let error { Text(error).foregroundStyle(NoopHTMLColor.red) }
            }
        }
        .font(NoopHTMLFont.sans(14)).foregroundStyle(NoopHTMLColor.ink).tint(NoopHTMLColor.volt)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            // Hidden while typing: the bar above the number pad carries Done, and the pad would otherwise
            // push these two up into the set being edited.
            if focusedField == nil {
                HStack(spacing: 10) {
                    NoopFitnessActionButton(title: "Add exercise", weight: .secondary) { openPicker() }
                    NoopFitnessActionButton(title: saving ? "Saving…" : "Save", enabled: canSave && !saving) {
                        Task { await save() }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 8)
                .background(LinearGradient(colors: [NoopHTMLColor.canvas.opacity(0), NoopHTMLColor.canvas],
                                           startPoint: .top, endPoint: .center).ignoresSafeArea())
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) { keypadBar }
        }
        .overlay(alignment: .top) {
            if let toast { Text(toast).padding(12).background(NoopHTMLColor.cardRaised, in: Capsule()).padding(.top, 50) }
        }
        .task(id: toast) {
            guard toast != nil else { return }
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(spring) { toast = nil }
        }
        .sensoryFeedback(.selection, trigger: feedback)
        .sheet(isPresented: $picking) {
            NoopFitnessExercisePicker(yours: vocabulary, onPickMany: { choices in add(choices) }).noopSheet()
        }
        .sheet(item: $detail) { NoopFitnessExerciseDetail(choice: $0).noopSheet() }
        .sheet(isPresented: $reorder) { reorderSheet }
        .sheet(isPresented: Binding(get: { progressionID != nil }, set: { if !$0 { progressionID = nil } })) {
            if let index = lines.firstIndex(where: { $0.id == progressionID }) {
                NoopFitnessProgressionEditor(configuration: Binding(
                    get: { lines[index].plan.progression ?? .init() },
                    set: { lines[index].plan.progression = $0 })).noopSheet()
            }
        }
        .sheet(isPresented: Binding(get: { restID != nil }, set: { if !$0 { restID = nil } })) {
            if let index = lines.firstIndex(where: { $0.id == restID }) {
                NoopFitnessRestSheet(exercise: lines[index].choice.name, seconds: Binding(
                    get: { lines[index].plan.restSeconds },
                    set: { value in
                        lines[index].plan.restSeconds = value
                        for set in lines[index].plan.sets.indices { lines[index].plan.sets[set].restSeconds = value }
                    }), done: { restID = nil })
                .noopSheet([.height(400)])
            }
        }
        .sheet(isPresented: Binding(get: { repRangeID != nil }, set: { if !$0 { repRangeID = nil } })) {
            NoopFitnessRepRangeSheet(exercise: lines.first { $0.id == repRangeID }?.choice.name ?? "",
                                     low: $repsLow, high: $repsHigh) {
                if let index = lines.firstIndex(where: { $0.id == repRangeID }) {
                    for set in lines[index].plan.sets.indices {
                        lines[index].plan.sets[set].repsMin = repsLow
                        lines[index].plan.sets[set].repsMax = repsHigh
                    }
                }
                repRangeID = nil
            }
            .noopSheet([.height(430)])
        }
        .sheet(item: $history) { value in
            NoopFitnessLastTimeSheet(exercise: lines.first { $0.id == value.lineID }?.choice.name ?? "",
                                     date: value.date, sets: value.sets, units: units) {
                if let index = lines.firstIndex(where: { $0.id == value.lineID }) { lines[index].plan.sets = value.sets }
                history = nil
            }
            .noopSheet([.height(CGFloat(250 + min(value.sets.count, 8) * 41))])
        }
        .alert("Delete this routine?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { Task { await archive() } }
        } message: { Text("Your logged sessions will be kept.") }
        .task { await load() }
    }

    private func lineCard(_ line: Binding<Line>) -> some View {
        let value = line.wrappedValue
        let index = lines.firstIndex { $0.id == value.id } ?? 0
        let timed = value.choice.definition?.mode == .duration || value.choice.definition?.mode == .distanceDuration
        let bodyweight = Self.isBodyweight(value.choice)
        let setCount = value.plan.sets.count
        return NoopFitnessPanel {
            HStack {
                NoopExerciseMedia(choice: value.choice, thumbnail: true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(value.choice.name).font(NoopHTMLFont.sans(15, weight: .semibold))
                    Text("\(bodyweight ? "Bodyweight" : value.choice.equipment ?? value.choice.muscleLine) · \(setCount) \(setCount == 1 ? "set" : "sets")")
                        .font(NoopHTMLFont.sans(12)).foregroundStyle(NoopHTMLColor.copy)
                }
                Spacer(minLength: 0)
                Button { restID = value.id } label: { Image(systemName: "timer").frame(width: 32, height: 44) }.accessibilityLabel("Rest timer")
                Menu {
                    Section {
                        if !timed { Button { openRepRange(value) } label: { Label("Target rep range", systemImage: "arrow.left.and.right") } }
                        Button { restID = value.id } label: { Label("Rest timer", systemImage: "timer") }
                        Button { progressionID = value.id } label: { Label("Progression", systemImage: "chart.line.uptrend.xyaxis") }
                        Button { Task { await lastTime(value.id) } } label: { Label("Last time", systemImage: "clock.arrow.circlepath") }
                        Button { line.pounds.wrappedValue.toggle() } label: {
                            Label(value.pounds ? "Use kilograms" : "Use pounds", systemImage: "scalemass")
                        }
                    }
                    Section {
                        Button { replacement = value.id; picking = true } label: { Label("Replace", systemImage: "arrow.triangle.2.circlepath") }
                        if value.plan.supersetId != nil {
                            Button { unlink(value.plan.supersetId) } label: { Label("Remove superset", systemImage: "link.badge.minus") }
                        } else {
                            Button { link(index) } label: { Label("Superset with next", systemImage: "link") }
                                .disabled(index + 1 >= lines.count)
                        }
                        Button { duplicate(index) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                        Button { openPicker(at: index + 1) } label: { Label("Add exercise below", systemImage: "text.badge.plus") }
                    }
                    Section {
                        Button { move(index, by: -1) } label: { Label("Move up", systemImage: "arrow.up") }.disabled(index == 0)
                        Button { move(index, by: 1) } label: { Label("Move down", systemImage: "arrow.down") }.disabled(index == lines.count - 1)
                        Button { detail = value.choice } label: { Label("About this exercise", systemImage: "info.circle") }
                    }
                    Button(role: .destructive) {
                        withAnimation(spring) { lines.removeAll { $0.id == value.id }; normalizeGroups(); feedback += 1 }
                    } label: { Label("Remove exercise", systemImage: "trash") }
                } label: { Image(systemName: "ellipsis").frame(width: 32, height: 44) }
                    .accessibilityLabel("Exercise actions")
            }
            HStack {
                Text("SET").frame(width: 30)
                Text(bodyweight ? (value.pounds ? "+LB" : "+KG") : (value.pounds ? "LB" : "KG")).frame(maxWidth: .infinity)
                Text(timed ? "TIME (s)" : "REPS").frame(maxWidth: .infinity)
                Text("REST").frame(maxWidth: .infinity)
            }.font(NoopHTMLFont.sans(10, weight: .semibold)).tracking(1).foregroundStyle(NoopHTMLColor.copy)
            ForEach(line.plan.sets) { set in
                let number = (value.plan.sets.firstIndex { $0.id == set.wrappedValue.id } ?? 0) + 1
                let id = set.wrappedValue.id.uuidString
                HStack(spacing: 8) {
                    Text("\(number)").font(NoopHTMLFont.sans(14, weight: .semibold)).foregroundStyle(NoopHTMLColor.copy)
                        .frame(width: 30)
                    numberField("Weight", placeholder: bodyweight ? "BW" : "—", focus: id + ".w", value: Binding(get: {
                        set.wrappedValue.targetWeightKg.map { value.pounds ? $0 * 2.2046226218 : $0 }
                    }, set: { set.wrappedValue.targetWeightKg = $0.map { value.pounds ? $0 / 2.2046226218 : $0 } }))
                    if !timed, let low = set.wrappedValue.repsMin, let high = set.wrappedValue.repsMax, high > low {
                        // A range is set with the range sheet, so the cell opens it rather than a number pad.
                        Button { focusedField = nil; openRepRange(value) } label: {
                            Text("\(low)–\(high)").font(NoopHTMLFont.sans(15, weight: .medium)).monospacedDigit()
                                .foregroundStyle(NoopHTMLColor.ink)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(NoopHTMLColor.cardRaised, in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(NoopHTMLPressStyle())
                        .accessibilityLabel("Reps, \(low) to \(high)")
                    } else {
                        integerField(timed ? "Seconds" : "Reps", focus: id + ".r", value: Binding(get: {
                            timed ? set.wrappedValue.targetDurationS : set.wrappedValue.repsMin
                        }, set: {
                            if timed { set.wrappedValue.targetDurationS = $0 }
                            else { set.wrappedValue.repsMin = $0; set.wrappedValue.repsMax = $0 }
                        }))
                    }
                    Button { focusedField = nil; restID = value.id } label: {
                        Text(NoopRestFormat.clock(set.wrappedValue.restSeconds ?? value.plan.restSeconds))
                            .font(NoopHTMLFont.sans(15)).monospacedDigit().foregroundStyle(NoopHTMLColor.inkSoft)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(NoopHTMLColor.cardRaised, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                    .accessibilityLabel("Rest, \(NoopRestFormat.clock(set.wrappedValue.restSeconds ?? value.plan.restSeconds))")
                }
                .modifier(NoopSwipeToDelete { removeSet(set.wrappedValue.id, from: value.id) })
                .contextMenu { Button("Delete set", role: .destructive) { removeSet(set.wrappedValue.id, from: value.id) } }
                .accessibilityAction(named: "Delete set") { removeSet(set.wrappedValue.id, from: value.id) }
            }
            HStack {
                Button("Progression") { progressionID = value.id }
                Spacer()
                Button("Add set") {
                    withAnimation(spring) {
                        line.plan.sets.wrappedValue.append(copySet(value.plan.sets.last ?? .init()))
                        feedback += 1
                    }
                }
            }.padding(.top, 8)
            TextField("Note (optional)", text: Binding(get: { line.plan.note.wrappedValue ?? "" }, set: { line.plan.note.wrappedValue = $0 }))
                .padding(10).background(NoopHTMLColor.cardRaised, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func numberField(_ label: String, placeholder: String, focus: String, value: Binding<Double?>) -> some View {
        TextField(placeholder, value: value, format: .number.precision(.fractionLength(0...2)))
            .keyboardType(.decimalPad).multilineTextAlignment(.center).accessibilityLabel(label)
            .font(NoopHTMLFont.sans(15, weight: .medium)).monospacedDigit()
            .focused($focusedField, equals: focus)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(NoopHTMLColor.cardRaised, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(NoopHTMLColor.volt.opacity(focusedField == focus ? 0.7 : 0), lineWidth: 1))
    }

    private func integerField(_ label: String, focus: String, value: Binding<Int?>) -> some View {
        TextField("—", value: value, format: .number).keyboardType(.numberPad)
            .multilineTextAlignment(.center).accessibilityLabel(label)
            .font(NoopHTMLFont.sans(15, weight: .medium)).monospacedDigit()
            .focused($focusedField, equals: focus)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(NoopHTMLColor.cardRaised, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(NoopHTMLColor.volt.opacity(focusedField == focus ? 0.7 : 0), lineWidth: 1))
    }

    private func openRepRange(_ line: Line) {
        repsLow = min(100, max(1, line.plan.sets.first?.repsMin ?? 6))
        repsHigh = min(100, max(repsLow, line.plan.sets.first?.repsMax ?? 10))
        repRangeID = line.id
    }

    /// No external load: a blank weight is the body alone, and a typed one is added load (vest, belt).
    static func isBodyweight(_ choice: NoopFitnessExerciseChoice) -> Bool {
        switch choice.definition?.mode {
        case .bodyweightReps?, .weightedBodyweight?, .assistedBodyweight?: return true
        default: return false
        }
    }

    /// Every typable field in screen order, so Next walks weight → reps → next set → next exercise.
    private var fieldOrder: [String] {
        lines.flatMap { line in line.plan.sets.flatMap { ["\($0.id.uuidString).w", "\($0.id.uuidString).r"] } }
    }

    /// Above the number pad: nudge the value, go to the next field, or put the pad away.
    @ViewBuilder
    private var keypadBar: some View {
        if let focus = focusedField, focus != "name" {
            Button { nudge(focus, by: -1) } label: { Image(systemName: "minus") }.accessibilityLabel("Less")
            Button { nudge(focus, by: 1) } label: { Image(systemName: "plus") }.accessibilityLabel("More")
            Spacer()
            if let next = fieldOrder.firstIndex(of: focus).map({ $0 + 1 }), next < fieldOrder.count {
                Button("Next") { focusedField = fieldOrder[next] }
            }
            Button("Done") { focusedField = nil }.fontWeight(.semibold)
        }
    }

    /// −/+ on the focused field: 2.5 kg (5 lb) for weight, one rep for reps.
    private func nudge(_ focus: String, by direction: Int) {
        let parts = focus.split(separator: ".")
        guard parts.count == 2, let setID = UUID(uuidString: String(parts[0])),
              let li = lines.firstIndex(where: { $0.plan.sets.contains { $0.id == setID } }),
              let si = lines[li].plan.sets.firstIndex(where: { $0.id == setID }) else { return }
        let timed = lines[li].choice.definition?.mode == .duration || lines[li].choice.definition?.mode == .distanceDuration
        if parts[1] == "w" {
            let step = lines[li].pounds ? 5 / 2.2046226218 : 2.5
            let next = max(0, (lines[li].plan.sets[si].targetWeightKg ?? 0) + Double(direction) * step)
            lines[li].plan.sets[si].targetWeightKg = next > 0 ? next : nil
        } else if timed {
            lines[li].plan.sets[si].targetDurationS = max(5, (lines[li].plan.sets[si].targetDurationS ?? 30) + direction * 5)
        } else {
            let reps = max(1, (lines[li].plan.sets[si].repsMin ?? 0) + direction)
            lines[li].plan.sets[si].repsMin = reps
            lines[li].plan.sets[si].repsMax = reps
        }
        feedback += 1
    }

    private var reorderSheet: some View {
        VStack(spacing: 16) {
            HStack { Text("Reorder exercises").font(NoopHTMLFont.sheetTitle); Spacer(); Button("Done") { reorder = false } }
            List {
                ForEach(lines) { line in Text(line.choice.name).listRowBackground(NoopHTMLColor.card) }
                    .onMove { source, destination in
                        withAnimation(spring) {
                            var plans = lines.map(\.plan)
                            RoutineEditing.move(&plans, from: source, to: destination)
                            let byID = Dictionary(uniqueKeysWithValues: lines.map { ($0.id, $0) })
                            lines = plans.compactMap { byID[$0.id] }
                            feedback += 1
                        }
                    }
            }.environment(\.editMode, .constant(.active)).scrollContentBackground(.hidden)
        }.padding(20).background(NoopHTMLColor.canvas).noopSheet()
    }

    private func openPicker(at index: Int? = nil) { insertion = index; replacement = nil; picking = true }

    private func add(_ choices: [NoopFitnessExerciseChoice]) {
        guard !choices.isEmpty else { return }
        withAnimation(spring) {
            if let replacement, let index = lines.firstIndex(where: { $0.id == replacement }), let choice = choices.first {
                lines[index].choice = choice
                lines[index].plan.exerciseId = choice.id
                lines[index].plan.sets = (0..<3).map { _ in .init() }
                lines[index].plan.progression = nil
            } else {
                let new = choices.map { choice in
                    Line(choice: choice, plan: .init(exerciseId: choice.id, sets: (0..<3).map { _ in .init() }), pounds: units == .imperial)
                }
                lines.insert(contentsOf: new, at: min(insertion ?? lines.count, lines.count))
                toast = new.count == 1 ? "1 exercise added" : "\(new.count) exercises added"
                for line in new { Task { await prefill(line.id) } }
            }
            normalizeGroups(); feedback += 1
        }
        insertion = nil; replacement = nil
    }

    private func linkedToNext(_ id: UUID) -> Bool {
        guard let index = lines.firstIndex(where: { $0.id == id }), index + 1 < lines.count,
              let group = lines[index].plan.supersetId else { return false }
        return group == lines[index + 1].plan.supersetId
    }

    private func link(_ index: Int) {
        guard index + 1 < lines.count else { return }
        let group = lines[index].plan.supersetId ?? UUID()
        let nextGroup = lines[index + 1].plan.supersetId
        for i in lines.indices where i == index || i == index + 1 || (nextGroup != nil && lines[i].plan.supersetId == nextGroup) {
            lines[i].plan.supersetId = group
        }
        feedback += 1
    }

    private func unlink(_ group: UUID?) {
        for index in lines.indices where lines[index].plan.supersetId == group { lines[index].plan.supersetId = nil }
    }

    private func normalizeGroups() {
        // Inserting a movement in the middle of a group must not leave a non-contiguous superset.
        let groups = Set(lines.compactMap { $0.plan.supersetId })
        for group in groups {
            let indices = lines.indices.filter { lines[$0].plan.supersetId == group }
            if indices.count < 2 || indices.last! - indices.first! + 1 != indices.count { unlink(group) }
        }
    }

    private func move(_ index: Int, by delta: Int) {
        guard lines.indices.contains(index + delta) else { return }
        withAnimation(spring) { lines.swapAt(index, index + delta); normalizeGroups(); feedback += 1 }
    }

    private func duplicate(_ index: Int) {
        let old = lines[index]
        let plan = RoutineEditing.duplicate(.init(title: "", exercises: [old.plan]), title: "", now: 0).exercises[0]
        withAnimation(spring) { lines.insert(.init(choice: old.choice, plan: plan, pounds: old.pounds), at: index + 1); normalizeGroups() }
    }

    private func copySet(_ set: RoutineSetPlan) -> RoutineSetPlan {
        .init(phase: set.phase, intensifier: set.intensifier, targetWeightKg: set.targetWeightKg,
              repsMin: set.repsMin, repsMax: set.repsMax, targetDurationS: set.targetDurationS,
              targetDistanceM: set.targetDistanceM, restSeconds: set.restSeconds,
              intensifierConfiguration: set.intensifierConfiguration)
    }

    private func removeSet(_ id: UUID, from lineID: UUID) {
        guard let index = lines.firstIndex(where: { $0.id == lineID }) else { return }
        withAnimation(spring) { lines[index].plan.sets.removeAll { $0.id == id }; feedback += 1 }
    }

    private func previous(_ id: UUID) async -> History? {
        guard let line = lines.first(where: { $0.id == id }), let store = await repo.storeHandle() else { return nil }
        let now = Int(Date().timeIntervalSince1970)
        let sessions = (try? await store.liftSessions(deviceId: repo.deviceId, fromTs: 0, toTs: now)) ?? []
        for session in sessions.sorted(by: { $0.startTs > $1.startTs }) where session.endTs != nil {
            let sets = ((try? await store.liftSets(sessionId: session.id)) ?? []).filter { $0.exercise == line.choice.name && !$0.isWarmup }
            if !sets.isEmpty {
                return History(lineID: id, date: Date(timeIntervalSince1970: Double(session.startTs)), sets: sets.sorted { $0.ord < $1.ord }.map {
                    .init(targetWeightKg: $0.weightKg, repsMin: $0.reps, repsMax: $0.reps, restSeconds: $0.restSec)
                })
            }
        }
        return nil
    }

    private func prefill(_ id: UUID) async {
        guard let initial = lines.first(where: { $0.id == id })?.plan,
              let previous = await previous(id), let index = lines.firstIndex(where: { $0.id == id }), lines[index].plan == initial else { return }
        lines[index].plan.sets = previous.sets
    }

    private func lastTime(_ id: UUID) async {
        if let previous = await previous(id) { history = previous }
        else { toast = "No previous session for this exercise" }
    }

    private func load() async {
        guard !loaded, let store = await repo.storeHandle() else { return }
        do {
            vocabulary = try await store.liftExercises(deviceId: repo.deviceId)
            if let id = navigation.fitnessRoutineID {
                program = try await store.liftPrograms(deviceId: repo.deviceId, includeArchived: true).first { $0.id == id }
                name = program?.name ?? ""
                let items = try await store.liftProgramItems(programId: id)
                lines = items.sorted { $0.ord < $1.ord }.map { item in
                    let choice = vocabulary.first { $0.name == item.exercise }.map(NoopFitnessExerciseChoice.choice)
                        ?? NoopFitnessExerciseChoice.catalogue.first { $0.name == item.exercise }
                        ?? .init(name: item.exercise, primary: nil, secondaries: [], equipment: nil, isYours: true)
                    let decoded = item.planJSON.flatMap { $0.data(using: .utf8) }.flatMap { try? JSONDecoder().decode(RoutineExercise.self, from: $0) }
                    let plan = decoded ?? RoutineExercise(id: UUID(uuidString: item.id) ?? UUID(), exerciseId: choice.id,
                        sets: (0..<max(1, item.targetSets ?? 3)).map { _ in
                            .init(targetWeightKg: item.targetWeightKg, repsMin: item.targetRepsLow, repsMax: item.targetRepsHigh)
                        }, restSeconds: item.restSec ?? 120, note: item.note)
                    return Line(choice: choice, plan: plan, pounds: units == .imperial)
                }
            }
            loaded = true
        } catch { self.error = "The routine could not be loaded. Reopen it to try again." }
    }

    private func save() async {
        guard canSave, !saving, let store = await repo.storeHandle() else { return }
        saving = true
        defer { saving = false }
        let now = Int(Date().timeIntervalSince1970)
        let id = program?.id ?? navigation.fitnessRoutineID ?? "routine-\(UUID().uuidString)"
        let title = typedName.isEmpty ? suggestedName : typedName
        let row = LiftProgramRow(id: id, deviceId: repo.deviceId, name: title, note: program?.note,
                                 createdAt: program?.createdAt ?? now, updatedAt: now, archived: false)
        do {
            let items = try lines.enumerated().map { ord, line in
                let set = line.plan.sets.first
                return LiftProgramItemRow(id: line.id.uuidString, deviceId: repo.deviceId, programId: id, ord: ord,
                    exercise: line.choice.name, targetSets: line.plan.sets.count, targetRepsLow: set?.repsMin,
                    targetRepsHigh: set?.repsMax, targetRpe: nil, targetWeightKg: set?.targetWeightKg,
                    restSec: line.plan.restSeconds, note: line.plan.note,
                    planJSON: String(decoding: try JSONEncoder().encode(line.plan), as: UTF8.self))
            }
            let exercises = try lines.map { line in
                let known = vocabulary.first { $0.name == line.choice.name }
                return LiftExerciseRow(id: known?.id ?? "ex-\(UUID().uuidString)", deviceId: repo.deviceId,
                    name: line.choice.name, primaryMuscle: line.choice.primary, secondaryMuscles: line.choice.secondaries,
                    createdAt: known?.createdAt ?? now, lastUsedTs: known?.lastUsedTs,
                    definitionJSON: try line.choice.definition.map { String(decoding: try JSONEncoder().encode($0), as: UTF8.self) })
            }
            _ = try await store.upsertLiftExercises(exercises)
            try await store.saveLiftProgram(row, items: items)
            if planIt { settings.schedule(routineID: id, name: title, dates: repeatPlan.dates, includesTime: repeatPlan.includesTime) }
            NoopFitnessModel.markChanged()
            await repo.refresh()
            await fitness.load(repo: repo, profile: profile)
            navigation.fitnessRoutineID = id
            navigation.back(or: .fitness)
        } catch { self.error = "The routine could not be saved. Your edits are still here; try again." }
    }

    private func archive() async {
        guard var row = program, let store = await repo.storeHandle() else { return }
        do {
            row.archived = true
            row.updatedAt = Int(Date().timeIntervalSince1970)
            let items = try await store.liftProgramItems(programId: row.id)
            try await store.saveLiftProgram(row, items: items)
            settings.removeUpcoming(routineID: row.id)
            settings.routineToast = "Routine deleted"
            NoopFitnessModel.markChanged()
            await repo.refresh()
            await fitness.load(repo: repo, profile: profile)
            navigation.fitnessRoutineID = nil
            navigation.reset(to: .fitness)
        } catch { self.error = "The routine could not be deleted. Try again." }
    }
}

struct NoopFitnessProgressionEditor: View {
    @Binding var configuration: ProgressionConfiguration
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Form {
            Section {
                Picker("Progression", selection: $configuration.policy) {
                    ForEach(ProgressionPolicy.allCases, id: \.self) { Text($0.rawValue.replacingOccurrences(of: "_", with: " ").capitalized).tag($0) }
                }
                Stepper("Load increase: \(configuration.weightIncrementKg, specifier: "%.1f") kg", value: $configuration.weightIncrementKg, in: 0.5...20, step: 0.5)
                Stepper("Minimum reps: \(configuration.repsMin)", value: $configuration.repsMin, in: 1...configuration.repsMax)
                Stepper("Maximum reps: \(configuration.repsMax)", value: $configuration.repsMax, in: configuration.repsMin...100)
                Stepper("Time increase: \(configuration.durationIncrementS)s", value: $configuration.durationIncrementS, in: 1...120)
                Stepper("Failures before deload: \(configuration.failuresBeforeDeload)", value: $configuration.failuresBeforeDeload, in: 1...10)
            }.listRowBackground(NoopHTMLColor.card)
            Button("Done") { dismiss() }
        }.scrollContentBackground(.hidden).background(NoopHTMLColor.canvas)
            .foregroundStyle(NoopHTMLColor.ink).tint(NoopHTMLColor.volt).font(NoopHTMLFont.sans(14))
    }
}
#endif

/// Swipe a row left to delete it, the way Mail and Reminders do: the row follows the finger over a red
/// strip with a trash symbol, a long enough swipe sends it off and deletes, a short one springs back.
/// Only a clearly horizontal drag is taken, so the page still scrolls.
struct NoopSwipeToDelete: ViewModifier {
    let onDelete: () -> Void
    @State private var offset: CGFloat = 0
    @State private var tracking = false
    private let trigger: CGFloat = 96

    func body(content: Content) -> some View {
        content
            .background(NoopHTMLColor.card)
            .offset(x: offset)
            .background(alignment: .trailing) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(NoopHTMLColor.red.opacity(min(1, 0.35 + Double(-offset / trigger) * 0.65)))
                    .overlay(alignment: .trailing) {
                        Image(systemName: "trash.fill").font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .scaleEffect(-offset >= trigger ? 1.15 : 1)
                            .padding(.trailing, 16)
                    }
                    .opacity(offset < -4 ? 1 : 0)
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 16)
                    .onChanged { drag in
                        if !tracking {
                            guard abs(drag.translation.width) > abs(drag.translation.height) * 1.6 else { return }
                            tracking = true
                        }
                        offset = min(0, drag.translation.width)
                    }
                    .onEnded { drag in
                        defer { tracking = false }
                        guard tracking else { return }
                        if -drag.translation.width >= trigger || drag.predictedEndTranslation.width < -trigger * 2 {
                            withAnimation(.easeIn(duration: 0.18)) { offset = -500 }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { onDelete() }
                                offset = 0
                            }
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { offset = 0 }
                        }
                    }
            )
            .sensoryFeedback(.impact(weight: .medium), trigger: -offset >= trigger)
            .clipped()
    }
}
