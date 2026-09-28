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
                LabeledContent("Sets", value: "\(workout.completedSets.count)")
                LabeledContent("Reps", value: "\(workout.totalReps)")
                if workout.totalVolume > 0 {
                    LabeledContent("Volume", value: "\(Format.weight(workout.totalVolume)) \(unit)")
                }
                LabeledContent("Time in sets", value: Format.clock(workout.totalWorkTime))
                LabeledContent("Time resting", value: Format.clock(workout.totalRestTime))
            }

            ForEach(workout.sortedExercises) { exercise in
                Section(exercise.name) {
                    ForEach(Array(exercise.sortedSets.enumerated()), id: \.element.id) { index, set in
                        HStack {
                            Text("\(index + 1)")
                                .foregroundStyle(.secondary)
                                .frame(width: 24, alignment: .leading)
                            Text(Format.setSummary(reps: set.reps, weight: set.weight, unit: unit))
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

    private func saveAsRoutine() {
        let routine = Routine(name: workout.name)
        context.insert(routine)
        for (index, exercise) in workout.sortedExercises.enumerated() {
            let sets = exercise.sortedSets
            routine.exercises.append(RoutineExercise(
                name: exercise.name,
                order: index,
                targetSets: max(1, sets.count),
                targetReps: sets.last?.reps ?? 10,
                targetWeight: sets.map(\.weight).max() ?? 0,
                restSeconds: exercise.restSeconds
            ))
        }
        savedAsRoutine = true
    }
}
