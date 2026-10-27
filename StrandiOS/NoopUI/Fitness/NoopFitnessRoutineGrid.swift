#if os(iOS)
import SwiftUI

struct NoopFitnessRoutineGrid: View {
    @ObservedObject var navigation: NoopNavigation
    let routines: [NoopFitnessSnapshot.Routine]
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var byName = false

    private var filtered: [NoopFitnessSnapshot.Routine] {
        routines.filter { query.isEmpty || NoopFitnessExercisePicker.rank($0.name, NoopFitnessExercisePicker.fold(query)) != nil }
            .sorted {
                if byName || $0.createdAt == $1.createdAt { return $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                return $0.createdAt > $1.createdAt
            }
    }

    var body: some View {
        VStack(spacing: 16) {
            NoopSheetHeader(title: "Routines", close: { dismiss() }) {
                NoopGlassDisc(symbol: "plus", label: "New routine") {
                    dismiss(); navigation.fitnessRoutineID = nil; navigation.push(.fitnessRoutineEdit)
                }
            }
            TextField("Search routines", text: $query).padding(12)
                .background(NoopHTMLColor.cardRaised, in: RoundedRectangle(cornerRadius: 12))
            Picker("Sort", selection: $byName) { Text("Recently added").tag(false); Text("Name").tag(true) }.pickerStyle(.segmented)
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(filtered) { routine in
                        Button {
                            dismiss(); navigation.fitnessRoutineID = routine.id; navigation.push(.fitnessRoutine)
                        } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                Image(systemName: "dumbbell").foregroundStyle(NoopHTMLColor.volt)
                                Text(routine.name).font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).lineLimit(2)
                                Text("\(routine.exercises) exercises · \(routine.sets) sets")
                                    .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                            }.frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
                                .padding(14).background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 18))
                        }.buttonStyle(NoopHTMLPressStyle())
                    }
                }
                if filtered.isEmpty { Text(routines.isEmpty ? "No routines yet" : "No matching routines").padding(24) }
            }
        }.padding(20).foregroundStyle(NoopHTMLColor.ink).tint(NoopHTMLColor.volt)
            .font(NoopHTMLFont.sans(NoopType.subhead)).background(NoopHTMLColor.canvas)
    }
}
#endif
