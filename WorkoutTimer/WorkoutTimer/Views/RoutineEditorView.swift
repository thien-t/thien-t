import SwiftUI
import SwiftData

struct RoutineEditorView: View {
    @Environment(\.modelContext) private var context
    @Bindable var routine: Routine
    @AppStorage(SettingsKey.weightUnit) private var unit = WeightUnit.kg.rawValue
    @Query private var customMovements: [CustomMovement]
    @State private var showingPicker = false

    init(routine: Routine) {
        _routine = Bindable(routine)
    }

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
                let defaults = MuscleResolver(custom: customMovements).defaults(for: name)
                routine.exercises.append(RoutineExercise(name: name, order: order, defaults: defaults))
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
            Stepper("Rep range low: \(exercise.repRangeLow)", value: $exercise.repRangeLow, in: 1...exercise.repRangeHigh)
            Stepper("Rep range high: \(exercise.repRangeHigh)", value: $exercise.repRangeHigh, in: exercise.repRangeLow...50)
            Picker("Target RIR", selection: $exercise.targetRIR) {
                ForEach(0...4, id: \.self) { value in
                    Text(value == 0 ? "0 (failure)" : "\(value)").tag(value)
                }
            }
            Picker("Weight jump", selection: $exercise.weightIncrement) {
                ForEach(WeightIncrement.values(including: exercise.weightIncrement), id: \.self) { value in
                    Text("+\(Format.weight(value)) \(unit)").tag(value)
                }
            }
            HStack {
                Text("Starting weight (\(unit))")
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
        } footer: {
            Text("Starting weight is only used the first time. After that, weights come from your last session and progress automatically.")
        }
    }
}

enum WeightIncrement {
    static let standard: [Double] = [0.5, 1, 1.25, 2, 2.5, 5, 10]

    static func values(including value: Double) -> [Double] {
        standard.contains(value) ? standard : (standard + [value]).sorted()
    }
}
