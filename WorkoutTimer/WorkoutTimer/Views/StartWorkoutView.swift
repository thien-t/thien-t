import SwiftUI
import SwiftData

struct StartWorkoutView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Routine.createdAt) private var routines: [Routine]
    @Query(filter: #Predicate<Workout> { $0.endedAt != nil }, sort: \Workout.startedAt, order: .reverse)
    private var finishedWorkouts: [Workout]
    @State private var showingSettings = false

    var body: some View {
        List {
            Section {
                Button(action: startEmpty) {
                    Label("Start Empty Workout", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("Start from a Routine") {
                if routines.isEmpty {
                    Text("Plan movements, rep ranges, effort and rest times in the Routines tab, then start them here.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button {
                        PPLTemplate.install(into: context)
                    } label: {
                        Label("Add Push / Pull / Legs Routines", systemImage: "square.stack.3d.up.fill")
                    }
                }
                ForEach(routines) { routine in
                    Button {
                        start(from: routine)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(routine.name).font(.headline).foregroundStyle(.primary)
                                Text(routine.summary).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "play.circle.fill").font(.title2)
                        }
                    }
                }
            }
        }
        .navigationTitle("Workout")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }

    private func startEmpty() {
        let workout = Workout(name: Self.defaultName())
        context.insert(workout)
        RestNotifier.requestAuthorization()
    }

    private func start(from routine: Routine) {
        let workout = Workout(name: routine.name)
        context.insert(workout)
        let history = PerformanceHistory(workouts: finishedWorkouts)
        for (index, planned) in routine.sortedExercises.enumerated() {
            let exercise = WorkoutExercise(from: planned, order: index)
            workout.exercises.append(exercise)
            exercise.fillSets(
                count: planned.targetSets,
                last: history.last(planned.name),
                fallbackWeight: planned.targetWeight
            )
        }
        RestNotifier.requestAuthorization()
    }

    private static func defaultName() -> String {
        switch Calendar.current.component(.hour, from: .now) {
        case 4..<12: return "Morning Workout"
        case 12..<17: return "Afternoon Workout"
        default: return "Evening Workout"
        }
    }
}
