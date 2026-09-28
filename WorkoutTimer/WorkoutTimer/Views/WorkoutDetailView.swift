import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var workout: Workout
    @AppStorage(SettingsKey.weightUnit) private var unit = WeightUnit.kg.rawValue
    @State private var savedAsRoutine = false

    var body: some View {
        List {
            Section("Summary") {
                LabeledContent("Date", value: workout.startedAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Duration", value: Format.clock(workout.duration))
                LabeledContent("Working sets", value: "\(workout.workingSets.count)")
                LabeledContent("Hard sets (RIR ≤ 3)", value: "\(workout.hardSetCount)")
                LabeledContent("Reps", value: "\(workout.totalReps)")
                if workout.totalVolume > 0 {
                    LabeledContent("Volume", value: "\(Format.weight(workout.totalVolume)) \(unit)")
                }
                LabeledContent("Time in sets", value: Format.clock(workout.totalWorkTime))
                LabeledContent("Time resting", value: Format.clock(workout.totalRestTime))
            }

            ForEach(workout.sortedExercises) { exercise in
                Section(exercise.name) {
                    ForEach(setLabels(exercise), id: \.set.id) { label, set in
                        HStack {
                            Text(label)
                                .foregroundStyle(set.isWarmup ? Color.orange : Color.secondary)
                                .frame(width: 24, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(Format.setSummary(reps: set.reps, weight: set.weight, unit: unit))
                                if let rir = set.rir, !set.isWarmup {
                                    Text("RIR \(Format.rir(rir))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                if let work = set.workSeconds, work >= 1 {
                                    Text("Set \(Format.clock(work))")
                                }
                                if let rest = set.restSeconds {
                                    Text("Rest \(Format.clock(rest))")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        }
                    }
                }
            }

            Section("Notes") {
                TextField("How did it feel?", text: $workout.notes, axis: .vertical)
                    .lineLimit(2...6)
            }

            Section {
                Button(action: saveAsRoutine) {
                    Label("Save as Routine", systemImage: "square.and.arrow.down")
                }
                .disabled(workout.exercises.isEmpty)
            }
        }
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Saved to Routines", isPresented: $savedAsRoutine) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Start “\(workout.name)” again any time from the Workout tab.")
        }
    }

    /// "W" for warm-ups, 1, 2, 3… for working sets.
    private func setLabels(_ exercise: WorkoutExercise) -> [(label: String, set: WorkoutSet)] {
        var working = 0
        return exercise.sortedSets.map { set -> (label: String, set: WorkoutSet) in
            if set.isWarmup { return ("W", set) }
            working += 1
            return ("\(working)", set)
        }
    }

    private func saveAsRoutine() {
        let routine = Routine(name: workout.name)
        context.insert(routine)
        for (index, exercise) in workout.sortedExercises.enumerated() {
            let sets = exercise.sortedSets.filter { !$0.isWarmup }
            routine.exercises.append(RoutineExercise(
                name: exercise.name,
                order: index,
                targetSets: max(1, sets.count),
                repRangeLow: exercise.repRangeLow,
                repRangeHigh: exercise.repRangeHigh,
                targetRIR: exercise.targetRIR,
                weightIncrement: exercise.weightIncrement,
                targetWeight: sets.map(\.weight).max() ?? 0,
                restSeconds: exercise.restSeconds
            ))
        }
        savedAsRoutine = true
    }
}
