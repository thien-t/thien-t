import SwiftUI
import SwiftData

struct RoutinesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Routine.createdAt) private var routines: [Routine]
    @State private var path: [Routine] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(routines) { routine in
                    NavigationLink(value: routine) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(routine.name).font(.headline)
                            Text(routine.summary).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    offsets.map { routines[$0] }.forEach { context.delete($0) }
                }
            }
            .overlay {
                if routines.isEmpty {
                    ContentUnavailableView {
                        Label("No Routines", systemImage: "list.bullet.clipboard")
                    } description: {
                        Text("Plan a workout with movements, sets, reps, weights and rest times.")
                    } actions: {
                        Button("Create Routine", action: addRoutine)
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Routines")
            .navigationDestination(for: Routine.self) { routine in
                RoutineEditorView(routine: routine)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: addRoutine) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New Routine")
                }
            }
        }
    }

    private func addRoutine() {
        let routine = Routine(name: "New Routine")
        context.insert(routine)
        path.append(routine)
    }
}
