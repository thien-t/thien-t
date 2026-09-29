import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            WorkoutTab()
                .tabItem { Label("Workout", systemImage: "stopwatch") }
            RoutinesView()
                .tabItem { Label("Routines", systemImage: "list.bullet.clipboard") }
            VolumeView()
                .tabItem { Label("Volume", systemImage: "chart.bar.fill") }
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
        }
    }
}

/// Shows the in-progress workout if there is one, otherwise the start screen.
struct WorkoutTab: View {
    @Query(filter: #Predicate<Workout> { $0.endedAt == nil }, sort: \Workout.startedAt, order: .reverse)
    private var activeWorkouts: [Workout]

    var body: some View {
        NavigationStack {
            if let workout = activeWorkouts.first {
                ActiveWorkoutView(workout: workout)
            } else {
                StartWorkoutView()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Routine.self, Workout.self, CustomMovement.self], inMemory: true)
}
