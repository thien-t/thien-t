import SwiftUI
import SwiftData

/// Hard sets per muscle for a week, against the 10–20 sets/week hypertrophy target.
struct VolumeView: View {
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @Query private var customMovements: [CustomMovement]
    @State private var weekOffset = 0
    @State private var tagging: TagRequest?

    private struct TagRequest: Identifiable {
        let name: String
        var id: String { name }
    }

    private var week: DateInterval {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: .now) ?? .now
        return calendar.dateInterval(of: .weekOfYear, for: day) ?? DateInterval(start: day, duration: 7 * 86_400)
    }

    private var weekTitle: String {
        switch weekOffset {
        case 0: return "This Week"
        case -1: return "Last Week"
        default:
            let end = week.end.addingTimeInterval(-1)
            let style = Date.FormatStyle.dateTime.month(.abbreviated).day()
            return "\(week.start.formatted(style)) – \(end.formatted(style))"
        }
    }

    var body: some View {
        let tally = VolumeTally(
            workouts: workouts.filter { week.contains($0.startedAt) },
            resolver: MuscleResolver(custom: customMovements)
        )
        let graded = Muscle.allCases.filter(\.hasWeeklyTarget)
        let onTarget = graded.filter { VolumeStatus(sets: tally.sets(for: $0)) == .onTarget }.count

        NavigationStack {
            List {
                Section {
                    HStack {
                        Button {
                            weekOffset -= 1
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .accessibilityLabel("Previous week")
                        Spacer()
                        Text(weekTitle).font(.headline)
                        Spacer()
                        Button {
                            weekOffset += 1
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(weekOffset >= 0)
                        .accessibilityLabel("Next week")
                    }
                    .buttonStyle(.borderless)

                    HStack {
                        StatTile(value: "\(onTarget)/\(graded.count)", label: "Muscles on target")
                        StatTile(value: "\(tally.hardSets)", label: "Hard sets")
                        StatTile(value: "\(tally.sessions)", label: "Workouts")
                    }
                }

                ForEach(MuscleGroup.allCases) { group in
                    Section(group.rawValue) {
                        ForEach(group.muscles) { muscle in
                            MuscleVolumeRow(muscle: muscle, sets: tally.sets(for: muscle))
                        }
                    }
                }

                if !tally.untagged.isEmpty {
                    Section {
                        ForEach(tally.untagged.sorted(), id: \.self) { name in
                            Button {
                                tagging = TagRequest(name: name)
                            } label: {
                                HStack {
                                    Text(name).foregroundStyle(.primary)
                                    Spacer()
                                    Text("Tag muscles").font(.caption)
                                }
                            }
                        }
                    } header: {
                        Text("Untagged movements")
                    } footer: {
                        Text("These sets aren't counted yet. Tag them so they count toward the right muscles.")
                    }
                }

                Section {
                } footer: {
                    Text("""
                    A hard set is a completed working set within 3 reps of failure (RIR 0–3). \
                    Warm-ups don't count. Sets with no RIR logged are counted. A movement's main \
                    muscle gets 1 set and the other muscles it works get ½. Most people grow best \
                    with about 10–20 hard sets per muscle per week, spread over 2 or more sessions.
                    """)
                }
            }
            .navigationTitle("Weekly Volume")
            .sheet(item: $tagging) { request in
                NavigationStack {
                    MuscleTagView(name: request.name)
                }
            }
        }
    }
}

struct VolumeTally {
    private var perMuscle: [Muscle: Double] = [:]
    private(set) var hardSets = 0
    private(set) var untagged = Set<String>()
    let sessions: Int

    init(workouts: [Workout], resolver: MuscleResolver) {
        sessions = workouts.count
        for workout in workouts {
            for exercise in workout.exercises {
                let hard = exercise.sets.filter(\.isHardSet).count
                guard hard > 0 else { continue }
                hardSets += hard
                guard let info = resolver.info(for: exercise.name) else {
                    untagged.insert(exercise.name)
                    continue
                }
                perMuscle[info.primary, default: 0] += Double(hard)
                for muscle in info.secondary {
                    perMuscle[muscle, default: 0] += Double(hard) * 0.5
                }
            }
        }
    }

    func sets(for muscle: Muscle) -> Double {
        perMuscle[muscle] ?? 0
    }
}

enum VolumeStatus {
    case under, onTarget, high

    static let targetRange = 10.0...20.0

    init(sets: Double) {
        if sets < Self.targetRange.lowerBound {
            self = .under
        } else if sets > Self.targetRange.upperBound {
            self = .high
        } else {
            self = .onTarget
        }
    }

    var label: String {
        switch self {
        case .under: "Under"
        case .onTarget: "On target"
        case .high: "High"
        }
    }

    var symbol: String {
        switch self {
        case .under: "arrow.down.circle.fill"
        case .onTarget: "checkmark.circle.fill"
        case .high: "arrow.up.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .under: .orange
        case .onTarget: .green
        case .high: .indigo
        }
    }
}

private struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.bold()).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct MuscleVolumeRow: View {
    let muscle: Muscle
    let sets: Double

    private var status: VolumeStatus? {
        muscle.hasWeeklyTarget ? VolumeStatus(sets: sets) : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(muscle.name).font(.subheadline)
                Spacer()
                Text("\(Format.sets(sets)) sets")
                    .font(.subheadline.bold())
                    .monospacedDigit()
                if let status {
                    Label(status.label, systemImage: status.symbol)
                        .font(.caption)
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(status.color)
                        .frame(width: 92, alignment: .trailing)
                } else {
                    Text("Indirect")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 92, alignment: .trailing)
                }
            }
            VolumeMeter(sets: sets, color: status?.color ?? .secondary, showsTarget: status != nil)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(muscle.name), \(Format.sets(sets)) hard sets\(status.map { ", \($0.label)" } ?? "")")
    }
}

/// Horizontal meter on a 0–25 set scale with the 10–20 target band shaded.
struct VolumeMeter: View {
    let sets: Double
    let color: Color
    let showsTarget: Bool

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let scale = max(25, sets)
            let x: (Double) -> CGFloat = { CGFloat($0 / scale) * width }
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemFill))
                if showsTarget {
                    let band = VolumeStatus.targetRange
                    Rectangle()
                        .fill(Color.green.opacity(0.18))
                        .frame(width: x(band.upperBound) - x(band.lowerBound))
                        .offset(x: x(band.lowerBound))
                }
                if sets > 0 {
                    Capsule()
                        .fill(color)
                        .frame(width: max(8, x(sets)))
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: 8)
    }
}
