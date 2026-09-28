import SwiftUI
import SwiftData

struct RoutineEditorView: View {
    @Environment(\.modelContext) private var context
    @Bindable var routine: Routine
    @AppStorage(SettingsKey.weightUnit) private var unit = WeightUnit.kg.rawValue
    @AppStorage(SettingsKey.defaultRestSeconds) private var defaultRest = 90
    @State private var showingPicker = false

    var body: some View {
        Form {
            Section("Routine Name") {
                TextField("Name", text: $routine.name)
            }

            ForEach(routine.sortedExercises) { exercise in
                RoutineExerciseSection(exercise: exercise, unit: unit) {
                    remove(exercise)
                }
            }

            Section {
                Button {
                    showingPicker = true
                } label: {
                    Label("Add Exercise", systemImage: "plus.circle.fill")
                }
            }
        }
        .navigationTitle(routine.name.isEmpty ? "Routine" : routine.name)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { dismissKeyboard() }
            }
        }
        .sheet(isPresented: $showingPicker) {
            ExercisePickerView { name in
                let order = (routine.exercises.map(\.order).max() ?? -1) + 1
                routine.exercises.append(RoutineExercise(name: name, order: order, restSeconds: defaultRest))
            }
        }
    }

    private func remove(_ exercise: RoutineExercise) {
        routine.exercises.removeAll { $0.id == exercise.id }
        context.delete(exercise)
    }
}

struct RoutineExerciseSection: View {
    @Bindable var exercise: RoutineExercise
    let unit: String
    let onRemove: () -> Void

    var body: some View {
        Section {
            Stepper("Sets: \(exercise.targetSets)", value: $exercise.targetSets, in: 1...20)
            Stepper("Reps: \(exercise.targetReps)", value: $exercise.targetReps, in: 1...100)
            HStack {
                Text("Weight (\(unit))")
                Spacer()
                TextField("0", value: $exercise.targetWeight, format: .number.precision(.fractionLength(0...2)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 120)
            }
            RestPicker(seconds: $exercise.restSeconds)
            Button("Remove Exercise", role: .destructive, action: onRemove)
        } header: {
            Text(exercise.name)
        }
    }
}
