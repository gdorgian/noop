#if os(iOS)
import SwiftUI
import StrandTraining
import WhoopStore

struct NoopFitnessExerciseDetail: View {
    let choice: NoopFitnessExerciseChoice
    @State private var guide = false
    @AppStorage(ExerciseMediaStore.enabledKey) private var animations = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    Text(choice.name).font(NoopHTMLFont.sheetTitle)
                    Spacer()
                    Button("Done") { dismiss() }
                }
                Text(choice.equipment ?? "Equipment not specified").foregroundStyle(NoopHTMLColor.copy)
                NoopExerciseMedia(choice: choice)
                if !animations {
                    Button("Show animations") { animations = true }.buttonStyle(.borderedProminent)
                        .foregroundStyle(NoopHTMLColor.voltInk)
                    Text("Downloads exercise media from GitHub and keeps an offline cache on this phone.")
                        .font(NoopHTMLFont.sans(12)).foregroundStyle(NoopHTMLColor.copy)
                }
                Picker("Exercise details", selection: $guide) {
                    Text("About").tag(false)
                    Text("Guide").tag(true)
                }.pickerStyle(.segmented)
                if guide {
                    let steps = instructions
                    if steps.isEmpty { Text("No instructions are available for this exercise.").foregroundStyle(NoopHTMLColor.copy) }
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)").foregroundStyle(NoopHTMLColor.volt)
                            Text(step).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                } else {
                    chips("Equipment", values: choice.definition?.equipmentIds.map { $0.replacingOccurrences(of: "-", with: " ").capitalized } ?? [])
                    chips("Primary muscles", values: choice.definition?.primaryMuscleId.map { [muscleName($0)] } ?? choice.primary.map { [$0.displayName] } ?? [])
                    chips("Secondary muscles", values: choice.definition?.secondaryMuscleIds.map(muscleName) ?? choice.secondaries.map(\.displayName))
                    NoopSectionLabel("How to log")
                    Text(logTip).foregroundStyle(NoopHTMLColor.copy)
                }
            }.padding(20)
        }
        .font(NoopHTMLFont.sans(14)).foregroundStyle(NoopHTMLColor.ink)
        .tint(NoopHTMLColor.volt).background(NoopHTMLColor.canvas)
    }

    private var instructions: [String] {
        guard let definition = choice.definition else { return [] }
        if !definition.instructions.isEmpty { return definition.instructions }
        guard let media = definition.mediaId else { return [] }
        return BundledExerciseCatalog.exercises.first { $0.mediaId == media }?.instructions ?? []
    }

    private func muscleName(_ id: String) -> String {
        TrainingMuscleCatalog.all.first { $0.id == id }?.name ?? id.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private var logTip: String {
        switch choice.definition?.mode {
        case .bodyweightReps, .weightedBodyweight:
            "Weight 0 means bodyweight. Enter only added load for a vest or belt."
        case .duration, .distanceDuration:
            "Enter the time in seconds for each set."
        default:
            "Enter the load and completed repetitions for each set. Keep the same load convention between sessions."
        }
    }

    private func chips(_ title: String, values: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            NoopSectionLabel(title)
            NoopFlowLayout(spacing: 6) {
                ForEach(values, id: \.self) { value in
                    Text(value).padding(.horizontal, 10).padding(.vertical, 6)
                        .background(NoopHTMLColor.cardRaised, in: Capsule())
                }
            }
        }
    }
}

struct NoopFitnessChecklist: View {
    let title: String
    let options: [(String, String)]
    @Binding var selection: Set<String>
    @State private var draft = Set<String>()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Filter by \(title)").font(NoopHTMLFont.sheetTitle)
            List {
                Button { draft.removeAll() } label: { row("All \(title)", on: draft.isEmpty) }
                ForEach(options, id: \.0) { id, label in
                    Button { if !draft.insert(id).inserted { draft.remove(id) } } label: { row(label, on: draft.contains(id)) }
                }
                .listRowBackground(NoopHTMLColor.card)
            }.scrollContentBackground(.hidden)
            Button("Filter by \(title)") { selection = draft; dismiss() }
                .buttonStyle(.borderedProminent).foregroundStyle(NoopHTMLColor.voltInk)
        }.padding(20).foregroundStyle(NoopHTMLColor.ink).font(NoopHTMLFont.sans(14))
            .tint(NoopHTMLColor.volt).background(NoopHTMLColor.canvas).noopSheet()
            .onAppear { draft = selection }
    }

    private func row(_ title: String, on: Bool) -> some View {
        HStack { Text(title); Spacer(); Image(systemName: on ? "checkmark.square.fill" : "square") }
    }
}

struct NoopFitnessCustomExercise: View {
    let onSave: (NoopFitnessExerciseChoice) -> Void
    @EnvironmentObject private var repo: Repository
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var equipment = "bodyweight"
    @State private var duration = false
    @State private var primary = "chest"
    @State private var secondaries = Set<String>()
    @State private var error: String?
    @State private var saving = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack { Text("Custom exercise").font(NoopHTMLFont.sheetTitle); Spacer(); Button("Cancel") { dismiss() } }
                TextField("Exercise name", text: $name).padding(12).background(NoopHTMLColor.cardRaised, in: RoundedRectangle(cornerRadius: 12))
                Picker("Equipment", selection: $equipment) {
                    ForEach(TrainingEquipmentCatalog.known.sorted(), id: \.self) { Text($0.replacingOccurrences(of: "-", with: " ").capitalized).tag($0) }
                }
                Picker("Type", selection: $duration) { Text("Reps").tag(false); Text("Duration").tag(true) }.pickerStyle(.segmented)
                Picker("Primary muscle", selection: $primary) {
                    ForEach(TrainingMuscleCatalog.all) { Text($0.name).tag($0.id) }
                }
                NoopSectionLabel("Secondary muscles (optional)")
                NoopFlowLayout(spacing: 6) {
                    ForEach(TrainingMuscleCatalog.all.filter { $0.id != primary }) { muscle in
                        Button {
                            if !secondaries.insert(muscle.id).inserted { secondaries.remove(muscle.id) }
                        } label: {
                            Text(muscle.name).padding(8)
                                .foregroundStyle(secondaries.contains(muscle.id) ? NoopHTMLColor.voltInk : NoopHTMLColor.ink)
                                .background(secondaries.contains(muscle.id) ? NoopHTMLColor.volt : NoopHTMLColor.cardRaised, in: Capsule())
                        }
                    }
                }
                if let error { Text(error).foregroundStyle(NoopHTMLColor.red) }
                Button(saving ? "Saving…" : "Save") { Task { await save() } }
                    .buttonStyle(.borderedProminent).foregroundStyle(NoopHTMLColor.voltInk)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || saving)
            }.padding(20)
        }.font(NoopHTMLFont.sans(14)).foregroundStyle(NoopHTMLColor.ink)
            .tint(NoopHTMLColor.volt).background(NoopHTMLColor.canvas)
    }

    private func save() async {
        guard let store = await repo.storeHandle() else { error = "Storage is unavailable. Try again."; return }
        saving = true
        defer { saving = false }
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let existing = try await store.liftExercises(deviceId: repo.deviceId)
            guard !existing.contains(where: { NoopFitnessExercisePicker.fold($0.name) == NoopFitnessExercisePicker.fold(title) }) else {
                error = "An exercise with this name already exists."; return
            }
            let mode: TrainingMeasurementMode = duration ? .duration : TrainingEquipmentCatalog.carriesExternalLoad([equipment]) ? .weightReps : .bodyweightReps
            let exercise = TrainingExercise(id: "custom-\(UUID().uuidString)", title: title, mode: mode,
                                            primaryMuscleId: primary, secondaryMuscleIds: secondaries.filter { $0 != primary }.sorted(),
                                            equipmentIds: [equipment])
            let choice = NoopFitnessExerciseChoice.choice(exercise, yours: true)
            let json = String(decoding: try JSONEncoder().encode(exercise), as: UTF8.self)
            _ = try await store.upsertLiftExercises([.init(id: exercise.id, deviceId: repo.deviceId, name: title,
                primaryMuscle: choice.primary, secondaryMuscles: choice.secondaries,
                createdAt: Int(Date().timeIntervalSince1970), lastUsedTs: nil, definitionJSON: json)])
            onSave(choice); dismiss()
        } catch { self.error = "The exercise could not be saved. Try again." }
    }
}
#endif
