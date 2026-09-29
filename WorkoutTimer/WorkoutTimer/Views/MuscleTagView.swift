import SwiftUI
import SwiftData

/// Tag a custom movement with the muscles it trains.
struct MuscleTagView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let name: String
    /// Called after saving. When nil, the view dismisses itself.
    let onSave: (() -> Void)?

    @State private var primary: Muscle = .chest
    @State private var secondary: Set<Muscle> = []
    @State private var isCompound = false

    init(name: String, onSave: (() -> Void)? = nil) {
        self.name = name
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section {
                Picker("Main muscle", selection: $primary) {
                    ForEach(MuscleGroup.allCases) { group in
                        Section(group.rawValue) {
                            ForEach(group.muscles) { muscle in
                                Text(muscle.name).tag(muscle)
                            }
                        }
                    }
                }
                Toggle("Compound (multi-joint)", isOn: $isCompound)
            } footer: {
                Text("Compound movements default to 6–10 reps and longer rest. Isolation movements default to 10–15 reps.")
            }

            Section {
                ForEach(Muscle.allCases.filter { $0 != primary }) { muscle in
                    Button {
                        if secondary.contains(muscle) {
                            secondary.remove(muscle)
                        } else {
                            secondary.insert(muscle)
                        }
                    } label: {
                        HStack {
                            Text(muscle.name).foregroundStyle(.primary)
                            Spacer()
                            if secondary.contains(muscle) {
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                            }
                        }
                    }
                }
            } header: {
                Text("Also works")
            } footer: {
                Text("Each set counts as 1 set for the main muscle and ½ set for these.")
            }
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
            }
        }
        .onAppear(perform: loadExisting)
    }

    private func existing() -> CustomMovement? {
        let target = name
        let descriptor = FetchDescriptor<CustomMovement>(predicate: #Predicate<CustomMovement> { $0.name == target })
        return try? context.fetch(descriptor).first
    }

    private func loadExisting() {
        guard let info = existing()?.info ?? MovementCatalog.builtIn(name) else { return }
        primary = info.primary
        secondary = Set(info.secondary)
        isCompound = info.isCompound
    }

    private func save() {
        let muscles = Muscle.allCases.filter { secondary.contains($0) && $0 != primary }
        if let movement = existing() {
            movement.primaryRaw = primary.rawValue
            movement.secondaryRaw = muscles.map(\.rawValue)
            movement.isCompound = isCompound
        } else {
            context.insert(CustomMovement(name: name, primary: primary, secondary: muscles, isCompound: isCompound))
        }
        if let onSave {
            onSave()
        } else {
            dismiss()
        }
    }
}
