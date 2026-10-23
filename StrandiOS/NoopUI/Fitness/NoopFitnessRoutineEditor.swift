#if os(iOS)
import SwiftUI
import WhoopStore
import StrandTraining

// MARK: - Exercise choices

/// One exercise the picker can offer: from the wearer's own Lift vocabulary, or from the bundled
/// catalogue (ExerciseDB via hasaneyldrm/exercises-dataset, MIT), mapped onto Lift muscles.
struct NoopFitnessExerciseChoice: Identifiable, Hashable {
    let name: String
    let primary: LiftMuscle?
    let secondaries: [LiftMuscle]
    let equipment: String?
    let isYours: Bool
    var id: String { (isYours ? "y:" : "c:") + name }

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

    static let catalogue: [NoopFitnessExerciseChoice] = BundledExerciseCatalog.exercises.map { e in
        let primary = e.primaryMuscleId.flatMap(liftMuscle)
        let secondaries = e.secondaryMuscleIds.compactMap(liftMuscle).filter { $0 != primary }
        return .init(name: e.title, primary: primary, secondaries: Array(NSOrderedSet(array: secondaries)) as? [LiftMuscle] ?? secondaries,
                     equipment: e.equipmentIds.first.map { $0.replacingOccurrences(of: "_", with: " ").capitalized },
                     isYours: false)
    }
}

/// Search your own exercises and the catalogue, or add a new name with the muscle it works.
struct NoopFitnessExercisePicker: View {
    let yours: [LiftExerciseRow]
    let onPick: (NoopFitnessExerciseChoice) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var newPrimary: LiftMuscle?
    @FocusState private var searching: Bool

    /// Lowercased with hyphens and doubled spaces folded, so "push up" finds "Push-Up".
    static func fold(_ s: String) -> String {
        s.lowercased().replacingOccurrences(of: "-", with: " ").split(separator: " ").joined(separator: " ")
    }

    /// Closest first: an exact name, then names that start with the query, then any other match;
    /// shorter names before longer ones within each.
    static func rank(_ name: String, _ q: String) -> Int? {
        let n = fold(name)
        guard n.contains(q) else { return nil }
        return (n == q ? 0 : n.hasPrefix(q) ? 1 : 2) * 1000 + n.count
    }

    var body: some View {
        let q = query.trimmingCharacters(in: .whitespaces)
        let fq = Self.fold(q)
        let mine = yours
            .filter { q.isEmpty || Self.rank($0.name, fq) != nil }
            .sorted { ($0.lastUsedTs ?? 0) > ($1.lastUsedTs ?? 0) }
            .map { NoopFitnessExerciseChoice(name: $0.name, primary: $0.primaryMuscle, secondaries: $0.secondaryMuscles,
                                              equipment: nil, isYours: true) }
        let names = Set(mine.map { $0.name.lowercased() })
        let catalogue = q.count < 2 ? [] : NoopFitnessExerciseChoice.catalogue
            .compactMap { c in Self.rank(c.name, fq).map { (c, $0) } }
            .filter { !names.contains($0.0.name.lowercased()) }
            .sorted { $0.1 < $1.1 }
            .prefix(60)
            .map(\.0)
        let exact = !q.isEmpty && !(mine + catalogue).contains { Self.fold($0.name) == fq }

        VStack(spacing: 0) {
            HStack {
                Text("Add exercise").font(NoopHTMLFont.outfit(21)).foregroundStyle(NoopHTMLColor.ink)
                Spacer()
                Button("Done") { dismiss() }
                    .font(NoopHTMLFont.sans(14, weight: .semibold)).foregroundStyle(NoopHTMLColor.blueLight)
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 12)
            TextField("Search 1,300 exercises or type a new one", text: $query)
                .font(NoopHTMLFont.sans(15))
                .foregroundStyle(NoopHTMLColor.ink)
                .padding(.horizontal, 14).frame(height: 44)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .padding(.horizontal, 20)
                .autocorrectionDisabled()
                .focused($searching)
                .onAppear { searching = true }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    if exact && mine.isEmpty && catalogue.isEmpty {
                        newExercise(q)
                    }
                    if !mine.isEmpty {
                        NoopSectionLabel("Yours").padding(.top, 10)
                        ForEach(mine) { row($0) }
                    }
                    if !catalogue.isEmpty {
                        NoopSectionLabel("Catalogue").padding(.top, 10)
                        ForEach(Array(catalogue)) { row($0) }
                    } else if q.count < 2 {
                        Text("Type two letters to search the catalogue.")
                            .font(NoopHTMLFont.sans(12)).foregroundStyle(NoopHTMLColor.muted).padding(.top, 10)
                    }
                    if exact && !(mine.isEmpty && catalogue.isEmpty) {
                        NoopSectionLabel("Not listed?").padding(.top, 10)
                        newExercise(q)
                    }
                    Text("Catalogue: ExerciseDB via hasaneyldrm/exercises-dataset, MIT licence.")
                        .font(NoopHTMLFont.sans(10.5)).foregroundStyle(NoopHTMLColor.muted).padding(.top, 14)
                }
                .padding(.horizontal, 20).padding(.vertical, 8)
            }
        }
        .background(NoopHTMLColor.canvas.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func row(_ c: NoopFitnessExerciseChoice) -> some View {
        Button {
            onPick(c)
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(c.name).font(NoopHTMLFont.sans(14.5, weight: .medium)).foregroundStyle(NoopHTMLColor.ink)
                    Text([c.muscleLine, c.equipment].compactMap { $0 }.joined(separator: " · "))
                        .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy)
                }
                Spacer()
                NoopCanonicalGlyph(name: .plus, size: 15, color: NoopHTMLColor.volt)
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(NoopHTMLPressStyle())
    }

    private func newExercise(_ name: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("New: \(name)").font(NoopHTMLFont.sans(14.5, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
            Text("Which muscle does it mainly work? It decides where its sets count.")
                .font(NoopHTMLFont.sans(12)).foregroundStyle(NoopHTMLColor.copy)
            NoopFlowLayout(spacing: 6) {
                ForEach(LiftMuscle.ordered, id: \.self) { m in
                    Button { newPrimary = m } label: {
                        Text(m.displayName).font(NoopHTMLFont.sans(12, weight: .semibold))
                            .foregroundStyle(newPrimary == m ? NoopHTMLColor.voltInk : NoopHTMLColor.inkSoft)
                            .padding(.horizontal, 10).frame(minHeight: 28)
                            .background(newPrimary == m ? NoopHTMLColor.volt : Color.white.opacity(0.06), in: Capsule())
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                }
            }
            Button {
                onPick(.init(name: name, primary: newPrimary, secondaries: [], equipment: nil, isYours: false))
                dismiss()
            } label: {
                Text("Add \(name)").font(NoopHTMLFont.sans(14, weight: .semibold)).foregroundStyle(NoopHTMLColor.voltInk)
                    .frame(maxWidth: .infinity).frame(minHeight: 42)
                    .background(NoopHTMLColor.volt, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(NoopHTMLPressStyle())
        }
        .padding(14)
        .background(NoopHTMLColor.volt.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(NoopHTMLColor.volt.opacity(0.3), lineWidth: 0.5))
    }
}

// MARK: - Routine editor

/// Builds or edits a routine: a name and an ordered list of exercises, each with its sets, reps,
/// weight and rest. Saved as a Lift program, so a routine and its history stay one record.
struct NoopFitnessRoutineEditor: View {
    @ObservedObject var navigation: NoopNavigation
    @ObservedObject var fitness: NoopFitnessModel
    @EnvironmentObject private var repo: Repository
    @EnvironmentObject private var profile: ProfileStore
    @AppStorage(UnitPrefs.systemKey) private var unitSystemRaw = UnitSystem.metric.rawValue

    struct Line: Identifiable, Equatable {
        var id = UUID().uuidString
        var exercise: String
        var primary: LiftMuscle?
        var secondaries: [LiftMuscle]
        var sets = 3
        var repsLow = ""
        var repsHigh = ""
        var weight = ""
        var restSec = 120
        var note = ""
    }

    @State private var name = ""
    @State private var lines: [Line] = []
    @State private var program: LiftProgramRow?
    @State private var vocabulary: [LiftExerciseRow] = []
    @State private var picking = false
    @State private var saving = false
    @State private var error: String?
    @State private var confirmDelete = false
    @State private var loaded = false
    @State private var planIt = false
    @State private var repeatPlan = NoopFitnessRepeatPlan()
    @EnvironmentObject private var settings: NoopFitnessSettings

    private var units: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }
    private var isNew: Bool { navigation.fitnessRoutineID == nil }

    var body: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    NoopBackHeader(label: isNew ? "Fitness" : "Routine") { navigation.back(or: .fitness) }
                    Spacer()
                    Button { Task { await save() } } label: {
                        Text(saving ? "Saving…" : "Save")
                            .font(NoopHTMLFont.sans(14, weight: .semibold)).foregroundStyle(NoopHTMLColor.voltInk)
                            .padding(.horizontal, 18).frame(minHeight: 34)
                            .background(NoopHTMLColor.volt.opacity(canSave ? 1 : 0.4), in: Capsule())
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                    .disabled(!canSave || saving)
                }

                Text(isNew ? "New routine" : "Edit routine").font(NoopHTMLFont.outfit(27)).foregroundStyle(NoopHTMLColor.ink)

                TextField("Name, like Full body A", text: $name)
                    .font(NoopHTMLFont.sans(17, weight: .medium))
                    .foregroundStyle(NoopHTMLColor.ink)
                    .padding(.horizontal, 15).frame(height: 52)
                    .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(NoopHTMLColor.borderStrong, lineWidth: 0.5))

                if lines.isEmpty {
                    Text("Add the exercises in the order you do them. Every target is optional — a name alone is a line you can log against.")
                        .font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.copy)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach($lines) { $line in
                    lineCard($line)
                }

                Button { picking = true } label: {
                    HStack(spacing: 8) {
                        NoopCanonicalGlyph(name: .plus, size: 15, color: NoopHTMLColor.volt)
                        Text("Add exercise").font(NoopHTMLFont.sans(14.5, weight: .semibold)).foregroundStyle(NoopHTMLColor.volt)
                    }
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(NoopHTMLColor.volt.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
                }
                .buttonStyle(NoopHTMLPressStyle())

                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $planIt.animation(NoopMotion.swap)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Put it on the calendar").font(NoopHTMLFont.sans(15, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                            Text("Plan the days you will do it; Fitness shows it on those days.")
                                .font(NoopHTMLFont.sans(12)).foregroundStyle(NoopHTMLColor.copy)
                        }
                    }
                    .tint(NoopHTMLColor.volt)
                    if planIt {
                        NoopFitnessRepeatEditor(plan: $repeatPlan)
                    }
                }
                .padding(16)
                .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))

                if let error {
                    Text(error).font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.red)
                }

                if !isNew {
                    Button { confirmDelete = true } label: {
                        Text("Delete routine").font(NoopHTMLFont.sans(14, weight: .semibold)).foregroundStyle(NoopHTMLColor.red)
                            .frame(maxWidth: .infinity).frame(minHeight: 46)
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                    .padding(.top, 8)
                }
            }
        }
        .sheet(isPresented: $picking) {
            NoopFitnessExercisePicker(yours: vocabulary) { choice in
                lines.append(Line(exercise: choice.name, primary: choice.primary, secondaries: choice.secondaries))
            }
        }
        .confirmationDialog("Delete this routine?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete routine", role: .destructive) { Task { await archive() } }
        } message: {
            Text("Sessions you already logged from it stay in your record.")
        }
        .task { await load() }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !lines.isEmpty && (!planIt || repeatPlan.isValid)
    }

    private func lineCard(_ line: Binding<Line>) -> some View {
        let index = lines.firstIndex { $0.id == line.wrappedValue.id } ?? 0
        return NoopFitnessPanel {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(line.wrappedValue.exercise).font(NoopHTMLFont.sans(15, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                    Text(LiftMuscleSummary.line(primary: line.wrappedValue.primary, secondaries: line.wrappedValue.secondaries))
                        .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy)
                }
                Spacer()
                Menu {
                    Button("Move up") { move(index, by: -1) }.disabled(index == 0)
                    Button("Move down") { move(index, by: 1) }.disabled(index == lines.count - 1)
                    Button("Duplicate") { var copy = line.wrappedValue; copy.id = UUID().uuidString; lines.insert(copy, at: index + 1) }
                    Button("Remove", role: .destructive) { lines.removeAll { $0.id == line.wrappedValue.id } }
                } label: {
                    Text("•••").font(NoopHTMLFont.sans(13, weight: .bold)).foregroundStyle(NoopHTMLColor.inkSoft)
                        .frame(width: 36, height: 30).background(Color.white.opacity(0.06), in: Capsule())
                }
            }
            HStack(spacing: 8) {
                stepper("Sets", value: line.sets, range: 1...12)
                stepper("Rest", value: line.restSec, range: 0...600, step: 15, format: { LiftFormat.duration($0) })
            }
            HStack(spacing: 8) {
                field(LiftFormat.weightUnit(units), text: line.weight)
                field("Reps", text: line.repsLow)
                field("to", text: line.repsHigh)
            }
            TextField("Note (optional)", text: line.note)
                .font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.inkSoft)
                .padding(.horizontal, 12).frame(height: 38)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
    }

    private func move(_ i: Int, by d: Int) {
        let j = i + d
        guard lines.indices.contains(i), lines.indices.contains(j) else { return }
        withAnimation(NoopMotion.swap) { lines.swapAt(i, j) }
    }

    private func stepper(_ label: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int = 1,
                         format: @escaping (Int) -> String = { "\($0)" }) -> some View {
        HStack(spacing: 6) {
            Text(label).font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy)
            Spacer(minLength: 2)
            Button { value.wrappedValue = max(range.lowerBound, value.wrappedValue - step) } label: { nudge("−") }
                .buttonStyle(NoopHTMLPressStyle())
            Text(format(value.wrappedValue)).font(NoopHTMLFont.sans(14, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                .monospacedDigit().frame(minWidth: 34)
            Button { value.wrappedValue = min(range.upperBound, value.wrappedValue + step) } label: { nudge("+") }
                .buttonStyle(NoopHTMLPressStyle())
        }
        .padding(.horizontal, 10).frame(height: 42)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func nudge(_ t: String) -> some View {
        Text(t).font(NoopHTMLFont.outfit(17)).foregroundStyle(NoopHTMLColor.inkSoft)
            .frame(width: 28, height: 28).background(Color.white.opacity(0.07), in: Circle())
    }

    private func field(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(NoopHTMLFont.sans(10.5)).foregroundStyle(NoopHTMLColor.copy)
            TextField("—", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(NoopHTMLFont.sans(15, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                .frame(height: 38)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
    }

    private func load() async {
        guard !loaded, let store = await repo.storeHandle() else { return }
        loaded = true
        vocabulary = (try? await store.liftExercises(deviceId: repo.deviceId)) ?? []
        guard let id = navigation.fitnessRoutineID else { return }
        program = ((try? await store.liftPrograms(deviceId: repo.deviceId, includeArchived: true)) ?? []).first { $0.id == id }
        name = program?.name ?? ""
        let items = ((try? await store.liftProgramItems(programId: id)) ?? []).sorted { $0.ord < $1.ord }
        lines = items.map { item in
            let known = vocabulary.first { $0.name == item.exercise }
            return Line(id: item.id, exercise: item.exercise, primary: known?.primaryMuscle,
                        secondaries: known?.secondaryMuscles ?? [], sets: item.targetSets ?? 3,
                        repsLow: item.targetRepsLow.map(String.init) ?? "",
                        repsHigh: item.targetRepsHigh.map(String.init) ?? "",
                        weight: item.targetWeightKg.map { LiftFormat.trim(LiftFormat.display(fromKilograms: $0, system: units)) } ?? "",
                        restSec: item.restSec ?? 120, note: item.note ?? "")
        }
    }

    private func save() async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let store = await repo.storeHandle() else { return }
        saving = true
        defer { saving = false }
        let now = Int(Date().timeIntervalSince1970)
        let id = program?.id ?? navigation.fitnessRoutineID ?? "routine-\(UUID().uuidString)"
        let row = LiftProgramRow(id: id, deviceId: repo.deviceId, name: trimmed, note: program?.note,
                                 createdAt: program?.createdAt ?? now, updatedAt: now, archived: false)
        let items = lines.enumerated().map { ord, l in
            LiftProgramItemRow(
                id: l.id, deviceId: repo.deviceId, programId: id, ord: ord, exercise: l.exercise,
                targetSets: l.sets, targetRepsLow: Int(l.repsLow), targetRepsHigh: Int(l.repsHigh) ?? Int(l.repsLow),
                targetRpe: nil,
                targetWeightKg: LiftFormat.number(l.weight).map { LiftFormat.kilograms(fromDisplay: $0, system: units) },
                restSec: l.restSec, note: l.note.isEmpty ? nil : l.note)
        }
        // A new name joins the exercise vocabulary with its muscles, so its sets count where they belong.
        let known = Set(vocabulary.map(\.name))
        let newExercises = lines.filter { !known.contains($0.exercise) }.map {
            LiftExerciseRow(id: "ex-\(UUID().uuidString)", deviceId: repo.deviceId, name: $0.exercise,
                            primaryMuscle: $0.primary, secondaryMuscles: $0.secondaries, createdAt: now, lastUsedTs: nil)
        }
        do {
            if !newExercises.isEmpty { _ = try await store.upsertLiftExercises(newExercises) }
            try await store.saveLiftProgram(row, items: items)
            NoopFitnessModel.markChanged()
            if planIt { settings.schedule(routineID: id, name: trimmed, dates: repeatPlan.dates) }
        } catch {
            self.error = "The routine could not be saved. Your edits are still here; try again."
            return
        }
        await repo.refresh()
        await fitness.load(repo: repo, profile: profile)
        navigation.fitnessRoutineID = id
        navigation.back(or: .fitness)
    }

    private func archive() async {
        guard var row = program, let store = await repo.storeHandle() else { return }
        row.archived = true
        row.updatedAt = Int(Date().timeIntervalSince1970)
        let items = (try? await store.liftProgramItems(programId: row.id)) ?? []
        try? await store.saveLiftProgram(row, items: items)
        NoopFitnessModel.markChanged()
        await repo.refresh()
        await fitness.load(repo: repo, profile: profile)
        navigation.fitnessRoutineID = nil
        navigation.reset(to: .fitness)
    }
}
#endif
