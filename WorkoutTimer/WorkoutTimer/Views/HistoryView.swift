import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Workout> { $0.endedAt != nil }, sort: \Workout.startedAt, order: .reverse)
    private var workouts: [Workout]
    @AppStorage(SettingsKey.weightUnit) private var unit = WeightUnit.kg.rawValue

    private var thisWeek: [Workout] {
        guard let week = Calendar.current.dateInterval(of: .weekOfYear, for: .now) else { return [] }
        return workouts.filter { week.contains($0.startedAt) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !workouts.isEmpty {
                    Section("This Week") {
                        HStack {
                            StatView(value: "\(thisWeek.count)", label: "Workouts")
                            StatView(value: Format.clock(thisWeek.reduce(0) { $0 + $1.duration }), label: "Time")
                            StatView(value: "\(thisWeek.reduce(0) { $0 + $1.hardSetCount })", label: "Hard sets")
                        }
                    }
                }

                Section {
                    ForEach(workouts) { workout in
                        NavigationLink {
                            WorkoutDetailView(workout: workout)
                        } label: {
                            WorkoutRow(workout: workout, unit: unit)
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { workouts[$0] }.forEach { context.delete($0) }
                    }
                }
            }
            .overlay {
                if workouts.isEmpty {
                    ContentUnavailableView(
                        "No Workouts Yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Finished workouts show up here with their times, sets and volume.")
                    )
                }
            }
            .navigationTitle("History")
        }
    }
}

private struct StatView: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.bold()).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct WorkoutRow: View {
    let workout: Workout
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(workout.name).font(.headline)
            Text(workout.startedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 14) {
                Label(Format.clock(workout.duration), systemImage: "timer")
                Label("\(workout.hardSetCount) hard sets", systemImage: "square.stack.3d.up")
                if workout.totalVolume > 0 {
                    Label("\(Format.weight(workout.totalVolume)) \(unit)", systemImage: "scalemass")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        .padding(.vertical, 2)
    }
}
