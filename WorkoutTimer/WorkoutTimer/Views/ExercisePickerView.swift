import SwiftUI
import SwiftData

/// Pick a movement from the catalog, ones you've used before, or type your own
/// (you'll tag which muscles it trains so it counts toward weekly volume).
struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var pastExercises: [WorkoutExercise]
    @Query private var plannedExercises: [RoutineExercise]
    @Query private var customMovements: [CustomMovement]
    @State private var search = ""
    @State private var taggingName: String?
    private let onPick: (String) -> Void

    init(onPick: @escaping (String) -> Void) {
        self.onPick = onPick
    }

    private var resolver: MuscleResolver { MuscleResolver(custom: customMovements) }

    private var trimmedSearch: String {
        search.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var allNames: [String] {
        var seen = Set<String>()
        var names: [String] = []
        let sources = customMovements.map(\.name) + pastExercises.map(\.name)
            + plannedExercises.map(\.name) + MovementCatalog.all.map(\.name)
        for name in sources where !name.isEmpty && seen.insert(name.lowercased()).inserted {
            names.append(name)
        }
        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var filteredNames: [String] {
        guard !trimmedSearch.isEmpty else { return allNames }
        let query = trimmedSearch
        return allNames.filter { name in
            name.localizedCaseInsensitiveContains(query)
                || (resolver.info(for: name)?.primary.name.localizedCaseInsensitiveContains(query) ?? false)
        }
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
                            taggingName = trimmedSearch
                        } label: {
                            Label("Add “\(trimmedSearch)”", systemImage: "plus.circle.fill")
                        }
                    }
                }
                Section {
                    ForEach(filteredNames, id: \.self) { name in
                        Button {
                            pick(name)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(name).foregroundStyle(.primary)
                                Text(muscleSummary(name))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .searchable(text: $search,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search movement or muscle")
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $taggingName) { name in
                MuscleTagView(name: name) { pick(name) }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func muscleSummary(_ name: String) -> String {
        guard let info = resolver.info(for: name) else { return "Untagged — won't count toward volume" }
        return ([info.primary] + info.secondary).map(\.name).joined(separator: " · ")
    }

    private func pick(_ name: String) {
        onPick(name)
        dismiss()
    }
}
