import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.weightUnit) private var unit = WeightUnit.kg.rawValue
    @AppStorage(SettingsKey.defaultRestSeconds) private var defaultRest = 90
    @AppStorage(SettingsKey.keepScreenAwake) private var keepScreenAwake = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Units") {
                    Picker("Weight", selection: $unit) {
                        ForEach(WeightUnit.allCases) { unit in
                            Text(unit.label).tag(unit.rawValue)
                        }
                    }
                }

                Section {
                    RestPicker(title: "Default Rest", seconds: $defaultRest)
                    Toggle("Keep Screen Awake", isOn: $keepScreenAwake)
                } header: {
                    Text("Timer")
                } footer: {
                    Text("Default rest is used for exercises you add. Each exercise's rest can be changed from its menu during a workout.")
                }

                Section {
                    Button("Allow Rest Notifications") {
                        RestNotifier.requestAuthorization()
                    }
                } footer: {
                    Text("Get an alert when your rest is over, even with your phone locked.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
