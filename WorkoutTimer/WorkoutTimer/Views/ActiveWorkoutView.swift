import SwiftUI
import SwiftData
import UIKit

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var context
    @Bindable var workout: Workout
    @AppStorage(SettingsKey.keepScreenAwake) private var keepScreenAwake = true
    @AppStorage(SettingsKey.defaultRestSeconds) private var defaultRest = 90
    @State private var showingPicker = false
    @State private var confirmFinish = false
    @State private var confirmDiscard = false

    var body: some View {
        List {
            Section {
                TextField("Workout name", text: $workout.name)
                    .font(.headline)
                HStack {
                    Label("Elapsed", systemImage: "timer")
                    Spacer()
                    Text(workout.startedAt, style: .timer)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Label("Sets done", systemImage: "checkmark.circle")
                    Spacer()
                    Text("\(workout.completedSets.count) / \(workout.allSets.count)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(workout.sortedExercises) { exercise in
                ExerciseSection(exercise: exercise, workout: workout)
            }

            Section {
                Button {
                    showingPicker = true
                } label: {
                    Label("Add Exercise", systemImage: "plus.circle.fill")
                }
            }

            Section {
                Button {
                    confirmFinish = true
                } label: {
                    Label("Finish Workout", systemImage: "flag.checkered")
                        .bold()
                }
                Button(role: .destructive) {
                    confirmDiscard = true
                } label: {
                    Label("Discard Workout", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Active Workout")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            TimerBanner(workout: workout)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Finish") { confirmFinish = true }
                    .bold()
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { dismissKeyboard() }
            }
        }
        .sheet(isPresented: $showingPicker) {
            ExercisePickerView { name in addExercise(named: name) }
        }
        .confirmationDialog("Finish this workout?", isPresented: $confirmFinish, titleVisibility: .visible) {
            Button("Finish Workout") { finish() }
        } message: {
            Text("Sets you haven't checked off will be removed.")
        }
        .confirmationDialog("Discard this workout?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard Workout", role: .destructive) { workout.discard(in: context) }
        } message: {
            Text("Nothing from this session will be saved.")
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = keepScreenAwake }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .task(id: workout.restEndsAt) {
            await buzzWhenRestEnds()
        }
    }

    private func addExercise(named name: String) {
        let order = (workout.exercises.map(\.order).max() ?? -1) + 1
        let exercise = WorkoutExercise(name: name, order: order, restSeconds: defaultRest)
        workout.exercises.append(exercise)
        exercise.sets.append(WorkoutSet(order: 0, reps: 10, weight: 0))
    }

    private func finish() {
        dismissKeyboard()
        workout.finish(in: context)
    }

    /// Vibrates when the rest countdown hits zero while the app is on screen.
    private func buzzWhenRestEnds() async {
        guard let end = workout.restEndsAt else { return }
        let remaining = end.timeIntervalSinceNow
        guard remaining > 0 else { return }
        try? await Task.sleep(for: .seconds(remaining))
        guard !Task.isCancelled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

struct ExerciseSection: View {
    @Environment(\.modelContext) private var context
    @Bindable var exercise: WorkoutExercise
    let workout: Workout
    @AppStorage(SettingsKey.weightUnit) private var unit = WeightUnit.kg.rawValue

    var body: some View {
        Section {
            HStack(spacing: 12) {
                Text("SET").frame(width: 32)
                Text("REPS").frame(maxWidth: .infinity)
                Text(unit.uppercased()).frame(maxWidth: .infinity)
                Image(systemName: "checkmark").frame(width: 44)
            }
            .font(.caption2.bold())
            .foregroundStyle(.secondary)

            ForEach(Array(exercise.sortedSets.enumerated()), id: \.element.id) { index, set in
                SetRowView(set: set, number: index + 1) { toggle(set) }
            }
            .onDelete(perform: deleteSets)

            Button(action: addSet) {
                Label("Add Set", systemImage: "plus")
            }
        } header: {
            HStack {
                Text(exercise.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .textCase(nil)
                Spacer()
                Menu {
                    Picker("Rest Timer", selection: $exercise.restSeconds) {
                        ForEach(RestOptions.values(including: exercise.restSeconds), id: \.self) { seconds in
                            Text(Format.rest(seconds)).tag(seconds)
                        }
                    }
                    Divider()
                    Button(role: .destructive, action: removeExercise) {
                        Label("Remove Exercise", systemImage: "trash")
                    }
                } label: {
                    Label("Rest \(Format.rest(exercise.restSeconds))", systemImage: "timer")
                        .font(.caption)
                        .textCase(nil)
                }
            }
        }
    }

    private func toggle(_ set: WorkoutSet) {
        if set.isCompleted {
            workout.uncomplete(set)
        } else {
            dismissKeyboard()
            workout.complete(set)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    private func addSet() {
        let last = exercise.sortedSets.last
        exercise.sets.append(WorkoutSet(
            order: (last?.order ?? -1) + 1,
            reps: last?.reps ?? 10,
            weight: last?.weight ?? 0
        ))
    }

    private func deleteSets(at offsets: IndexSet) {
        let sorted = exercise.sortedSets
        let doomed = offsets.map { sorted[$0] }
        exercise.sets.removeAll { set in doomed.contains { $0.id == set.id } }
        doomed.forEach { context.delete($0) }
        for (index, set) in exercise.sortedSets.enumerated() {
            set.order = index
        }
    }

    private func removeExercise() {
        workout.exercises.removeAll { $0.id == exercise.id }
        context.delete(exercise)
    }
}
