import SwiftUI

struct SetRowView: View {
    @Bindable var set: WorkoutSet
    let number: Int
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Text("\(number)")
                    .font(.headline)
                    .frame(width: 32)

                TextField("0", value: $set.reps, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)

                TextField("0", value: $set.weight, format: .number.precision(.fractionLength(0...2)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)

                Button(action: onToggle) {
                    Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title)
                        .foregroundStyle(set.isCompleted ? Color.green : Color.secondary)
                }
                .buttonStyle(.borderless)
                .frame(width: 44)
                .accessibilityLabel(set.isCompleted ? "Mark set \(number) not done" : "Complete set \(number)")
            }

            if set.isCompleted, let timing = timingText {
                Text(timing)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .padding(.leading, 44)
            }
        }
        .listRowBackground(set.isCompleted ? Color.green.opacity(0.12) : nil)
    }

    private var timingText: String? {
        var parts: [String] = []
        if let work = set.workSeconds, work >= 1 { parts.append("Set \(Format.clock(work))") }
        if let rest = set.restSeconds { parts.append("Rested \(Format.clock(rest))") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
