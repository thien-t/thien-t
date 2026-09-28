import SwiftUI
import SwiftData
import UIKit

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var context
    @Bindable var workout: Workout
    @Query(filter: #Predicate<Workout> { $0.endedAt != nil }, sort: \Workout.startedAt, order: .reverse)
    private var finishedWorkouts: [Workout]
    @Query private var customMovements: [CustomMovement]
    @AppStorage(SettingsKey.keepScreenAwake) private var keepScreenAwake = true
    @State private var showingPicker = false
    @State private var confirmFinish = false
    @State private var confirmDiscard = false

    init(workout: Workout) {
        _workout = Bindable(workout)
    }

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
                ExerciseSection(exercise: exercise, workout: workout, last: history.last(exercise.name))
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

    private var history: PerformanceHistory {
        PerformanceHistory(workouts: finishedWorkouts)
    }

    private func addExercise(named name: String) {
        let order = (workout.exercises.map(\.order).max() ?? -1) + 1
        let defaults = MuscleResolver(custom: customMovements).defaults(for: name)
        let exercise = WorkoutExercise(name: name, order: order, defaults: defaults)
        workout.exercises.append(exercise)
        let last = history.last(name)
        exercise.fillSets(count: last?.sets.count ?? 3, last: last, fallbackWeight: 0)
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
    let last: LastSession?
    @AppStorage(SettingsKey.weightUnit) private var unit = WeightUnit.kg.rawValue

    private struct Row: Identifiable {
        let set: WorkoutSet
        let label: String
        let previous: WorkoutSet?
        var id: PersistentIdentifier { set.persistentModelID }
    }

    /// Warm-ups are labelled "W"; working sets are numbered and matched
    /// against the same working set from last session.
    private var rows: [Row] {
        var working = 0
        var result: [Row] = []
        for set in exercise.sortedSets {
            if set.isWarmup {
                result.append(Row(set: set, label: "W", previous: nil))
            } else {
                let previous = last.flatMap { working < $0.sets.count ? $0.sets[working] : nil }
                result.append(Row(set: set, label: "\(working + 1)", previous: previous))
                working += 1
            }
        }
        return result
    }

    var body: some View {
        Section {
            CoachRow(exercise: exercise, last: last, unit: unit)

            HStack(spacing: 8) {
                Text("SET").frame(width: 28)
                Text("PREVIOUS").frame(maxWidth: .infinity, alignment: .leading)
                Text(unit.uppercased()).frame(width: 68)
                Text("REPS").frame(width: 52)
                Image(systemName: "checkmark").frame(width: 36)
            }
            .font(.caption2.bold())
            .foregroundStyle(.secondary)

            ForEach(rows) { row in
                SetRowView(set: row.set, label: row.label, previous: row.previous,
                           targetRIR: exercise.targetRIR) {
                    toggle(row.set)
                }
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
                    .pickerStyle(.menu)
                    Picker("Rep Range", selection: repRangeBinding) {
                        ForEach(RepRange.options(including: repRangeBinding.wrappedValue)) { range in
                            Text(range.label).tag(range)
                        }
                    }
                    .pickerStyle(.menu)
                    Picker("Target RIR", selection: $exercise.targetRIR) {
                        ForEach(0...4, id: \.self) { value in
                            Text("RIR \(value)").tag(value)
                        }
                    }
                    .pickerStyle(.menu)
                    Divider()
                    Button(role: .destructive, action: removeExercise) {
                        Label("Remove Exercise", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
                .accessibilityLabel("\(exercise.name) options")
            }
        }
    }

    private var repRangeBinding: Binding<RepRange> {
        Binding {
            RepRange(low: exercise.repRangeLow, high: exercise.repRangeHigh)
        } set: { range in
            exercise.repRangeLow = range.low
            exercise.repRangeHigh = range.high
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
            reps: last?.reps ?? exercise.repRangeLow,
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

/// Today's target and what to do versus last session.
struct CoachRow: View {
    let exercise: WorkoutExercise
    let last: LastSession?
    let unit: String

    var body: some View {
        let advice = exercise.advice(last: last)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Label(exercise.repRangeText, systemImage: "target")
                Label("RIR \(exercise.targetRIR)", systemImage: "gauge.with.dots.needle.67percent")
                Label(Format.rest(exercise.restSeconds), systemImage: "timer")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)

            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title(advice)).font(.subheadline.bold())
                    Text(detail(advice)).font(.caption).foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: advice.symbol).foregroundStyle(color(advice))
            }

            if let last {
                Text("Last: \(last.date.formatted(.dateTime.month(.abbreviated).day())) · "
                     + last.sets.map(Format.previous).joined(separator: ", "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    private func title(_ advice: ProgressionAdvice) -> String {
        switch advice {
        case .firstTime: "New movement"
        case .increaseWeight(let weight): "Add weight → \(Format.weight(weight)) \(unit)"
        case .reduceWeight(let weight): "Drop to \(Format.weight(weight)) \(unit)"
        case .pushHarder: "Push closer to failure"
        case .beatReps: "Beat last time"
        }
    }

    private func detail(_ advice: ProgressionAdvice) -> String {
        let low = exercise.repRangeLow, high = exercise.repRangeHigh
        switch advice {
        case .firstTime:
            return "Pick a weight you can lift for \(low)–\(high) reps with about \(exercise.targetRIR) left in the tank."
        case .increaseWeight:
            return "You hit \(high)+ reps on every set. Start at \(low) reps and build back up."
        case .reduceWeight:
            return "Most sets fell below \(low) reps last time. Lighten up and own the range."
        case .pushHarder(let average):
            return "Last session averaged \(Format.sets(average)) RIR vs a target of \(exercise.targetRIR). Add reps or weight."
        case .beatReps:
            return "Same weight, aim for +1 rep per set until you hit \(high)."
        }
    }

    private func color(_ advice: ProgressionAdvice) -> Color {
        switch advice {
        case .firstTime: .secondary
        case .increaseWeight: .green
        case .reduceWeight: .orange
        case .pushHarder: .purple
        case .beatReps: .blue
        }
    }
}

struct RepRange: Hashable, Identifiable {
    let low: Int
    let high: Int
    var id: String { label }
    var label: String { "\(low)–\(high) reps" }

    static let standard = [
        RepRange(low: 5, high: 8), RepRange(low: 6, high: 10), RepRange(low: 8, high: 12),
        RepRange(low: 10, high: 15), RepRange(low: 12, high: 20), RepRange(low: 15, high: 30),
    ]

    static func options(including range: RepRange) -> [RepRange] {
        standard.contains(range) ? standard : (standard + [range]).sorted { ($0.low, $0.high) < ($1.low, $1.high) }
    }
}
