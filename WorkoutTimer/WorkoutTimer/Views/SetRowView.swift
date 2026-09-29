import SwiftUI

struct SetRowView: View {
    @Bindable var set: WorkoutSet
    /// "1", "2"… for working sets, "W" for warm-ups.
    let label: String
    /// The matching working set from last session.
    let previous: WorkoutSet?
    let targetRIR: Int
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Button {
                    set.isWarmup.toggle()
                } label: {
                    Text(label)
                        .font(.headline)
                        .foregroundStyle(set.isWarmup ? Color.orange : Color.primary)
                        .frame(width: 28, height: 32)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(set.isWarmup ? "Warm-up set" : "Set \(label)")
                .accessibilityHint(set.isWarmup ? "Makes this a working set" : "Marks this as a warm-up set")

                Button(action: copyPrevious) {
                    Text(previous.map(Format.previous) ?? "—")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderless)
                .disabled(previous == nil || set.isCompleted)
                .accessibilityHint("Copies last session's weight and reps")

                TextField("0", value: $set.weight, format: .number.precision(.fractionLength(0...2)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 68)

                TextField("0", value: $set.reps, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 52)

                Button(action: onToggle) {
                    Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title)
                        .foregroundStyle(set.isCompleted ? Color.green : Color.secondary)
                }
                .buttonStyle(.borderless)
                .frame(width: 36)
                .accessibilityLabel(set.isCompleted ? "Mark set \(label) not done" : "Complete set \(label)")
            }

            if set.isCompleted && !set.isWarmup {
                RIRPicker(rir: $set.rir, target: targetRIR)
                    .padding(.leading, 36)
            }

            if set.isCompleted, let timing = timingText {
                Text(timing)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .padding(.leading, 36)
            }
        }
        .listRowBackground(set.isCompleted ? Color.green.opacity(0.12) : nil)
    }

    private func copyPrevious() {
        guard let previous else { return }
        set.weight = previous.weight
        set.reps = previous.reps
    }

    private var timingText: String? {
        var parts: [String] = []
        if let work = set.workSeconds, work >= 1 { parts.append("Set \(Format.clock(work))") }
        if let rest = set.restSeconds { parts.append("Rested \(Format.clock(rest))") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// Quick "how many more reps could you have done?" tap row.
struct RIRPicker: View {
    @Binding var rir: Int?
    let target: Int

    var body: some View {
        HStack(spacing: 6) {
            Text("RIR")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            ForEach(0...4, id: \.self) { value in
                let selected = rir == value
                Button {
                    rir = selected ? nil : value
                } label: {
                    Text(Format.rir(value))
                        .font(.caption.bold())
                        .frame(minWidth: 30, minHeight: 26)
                        .foregroundStyle(selected ? Color.white : Color.primary)
                        .background(selected ? color(for: value) : Color(.tertiarySystemFill), in: Capsule())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("\(Format.rir(value)) reps in reserve")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
            if let rir {
                if rir >= 4 {
                    Label("Too easy", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            } else {
                Text("Reps left?")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Green when at or near the target effort, orange when well short of failure.
    private func color(for value: Int) -> Color {
        value > target + 1 ? .orange : .green
    }
}
