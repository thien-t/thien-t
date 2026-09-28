import SwiftUI

/// Floating panel at the bottom of the active workout:
/// counts up while you're doing a set, counts down while you rest.
struct TimerBanner: View {
    let workout: Workout

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let now = context.date
            Group {
                if workout.isResting(at: now) {
                    resting(now: now)
                } else {
                    working(now: now)
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    private func resting(now: Date) -> some View {
        let remaining = workout.restRemaining(at: now)
        let total = workout.plannedRest
        let progress = total > 0 ? min(1, max(0, (total - remaining) / total)) : 1

        return VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label("Rest", systemImage: "pause.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Spacer()
                Text(Format.clock(remaining.rounded(.up)))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
            }
            ProgressView(value: progress)
                .tint(.orange)
            HStack {
                Button("−15s") { workout.adjustRest(by: -15) }
                Button("+15s") { workout.adjustRest(by: 15) }
                Spacer()
                Button("Skip Rest") { workout.skipRest() }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
            }
            .buttonStyle(.bordered)
            if let next = workout.nextUpDescription {
                Text("Next: \(next)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
            }
        }
    }

    private func working(now: Date) -> some View {
        let start = workout.workPhaseStart(at: now) ?? now
        let restJustEnded = workout.restEndsAt != nil

        return HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Label(restJustEnded ? "Rest over — lift!" : "Set timer",
                      systemImage: "figure.strengthtraining.traditional")
                    .font(.headline)
                    .foregroundStyle(.green)
                Text(workout.nextUpDescription ?? "Add an exercise to get started")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(Format.clock(now.timeIntervalSince(start)))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
    }
}
