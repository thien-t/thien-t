import SwiftUI
import SwiftData

/// Pick a movement from common lifts, ones you've used before, or type your own.
struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var pastExercises: [WorkoutExercise]
    @Query private var plannedExercises: [RoutineExercise]
    @State private var search = ""
    private let onPick: (String) -> Void

    init(onPick: @escaping (String) -> Void) {
        self.onPick = onPick
    }

    private var trimmedSearch: String {
        search.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var allNames: [String] {
        var seen = Set<String>()
        var names: [String] = []
        for name in pastExercises.map(\.name) + plannedExercises.map(\.name) + Movement.common
        where !name.isEmpty && seen.insert(name.lowercased()).inserted {
            names.append(name)
        }
        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var filteredNames: [String] {
        trimmedSearch.isEmpty ? allNames : allNames.filter { $0.localizedCaseInsensitiveContains(trimmedSearch) }
    }

    private var canAddCustom: Bool {
        !trimmedSearch.isEmpty
            && !allNames.contains { $0.caseInsensitiveCompare(trimmedSearch) == .orderedSame }
    }

    var body: some View {
        NavigationStack {
            List {
                if canAddCustom {
                    Section {
                        Button {
                            pick(trimmedSearch)
                        } label: {
                            Label("Add “\(trimmedSearch)”", systemImage: "plus.circle.fill")
                        }
                    }
                }
                Section {
                    ForEach(filteredNames, id: \.self) { name in
                        Button(name) { pick(name) }
                            .foregroundStyle(.primary)
                    }
                }
            }
            .searchable(text: $search,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search or type a movement")
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func pick(_ name: String) {
        onPick(name)
        dismiss()
    }
}
