import Foundation

/// The most recent finished session of a movement (working sets only).
struct LastSession {
    let date: Date
    let sets: [WorkoutSet]
}

/// Index of the latest finished performance of every movement, by name.
struct PerformanceHistory {
    private var sessions: [String: LastSession] = [:]

    /// - Parameter workouts: finished workouts, newest first.
    init(workouts: [Workout]) {
        for workout in workouts {
            for exercise in workout.exercises {
                let key = exercise.name.lowercased()
                guard sessions[key] == nil else { continue }
                let sets = exercise.sortedSets.filter { $0.isCompleted && !$0.isWarmup }
                guard !sets.isEmpty else { continue }
                sessions[key] = LastSession(date: workout.startedAt, sets: sets)
            }
        }
    }

    func last(_ name: String) -> LastSession? {
        sessions[name.lowercased()]
    }
}

/// Double progression: work up to the top of the rep range on every set,
/// then add weight and start again at the bottom.
enum ProgressionAdvice: Equatable {
    case firstTime
    case increaseWeight(to: Double)
    case reduceWeight(to: Double)
    case pushHarder(averageRIR: Double)
    case beatReps

    var symbol: String {
        switch self {
        case .firstTime: "sparkles"
        case .increaseWeight: "arrow.up.circle.fill"
        case .reduceWeight: "arrow.down.circle.fill"
        case .pushHarder: "bolt.circle.fill"
        case .beatReps: "arrow.right.circle.fill"
        }
    }
}

enum Progression {
    static func advice(
        last: LastSession?,
        repLow: Int,
        repHigh: Int,
        targetRIR: Int,
        increment: Double
    ) -> ProgressionAdvice {
        guard let sets = last?.sets, !sets.isEmpty else { return .firstTime }
        let topWeight = sets.map(\.weight).max() ?? 0

        if sets.allSatisfy({ $0.reps >= repHigh }) {
            return .increaseWeight(to: topWeight + increment)
        }
        let belowRange = sets.filter { $0.reps < repLow }.count
        if belowRange * 2 > sets.count, topWeight > increment {
            return .reduceWeight(to: topWeight - increment)
        }
        let rirs = sets.compactMap(\.rir)
        if rirs.count == sets.count {
            let average = Double(rirs.reduce(0, +)) / Double(rirs.count)
            if average >= Double(targetRIR) + 2 {
                return .pushHarder(averageRIR: average)
            }
        }
        return .beatReps
    }

    /// Weight and reps to pre-fill for each set of today's session.
    static func plan(
        setCount: Int,
        last: LastSession?,
        advice: ProgressionAdvice,
        repLow: Int,
        repHigh: Int,
        fallbackWeight: Double
    ) -> [(reps: Int, weight: Double)] {
        let previous = last?.sets ?? []
        return (0..<max(1, setCount)).map { index -> (reps: Int, weight: Double) in
            let prev = index < previous.count ? previous[index] : previous.last
            switch advice {
            case .firstTime:
                return (repLow, fallbackWeight)
            case .increaseWeight(let weight), .reduceWeight(let weight):
                return (repLow, weight)
            case .pushHarder, .beatReps:
                guard let prev else { return (repLow, fallbackWeight) }
                return (min(repHigh, max(repLow, prev.reps + 1)), prev.weight)
            }
        }
    }
}

extension WorkoutExercise {
    func advice(last: LastSession?) -> ProgressionAdvice {
        Progression.advice(last: last, repLow: repRangeLow, repHigh: repRangeHigh,
                           targetRIR: targetRIR, increment: weightIncrement)
    }

    /// Adds `count` sets pre-filled from last session and the progression advice.
    func fillSets(count: Int, last: LastSession?, fallbackWeight: Double) {
        let plan = Progression.plan(
            setCount: count,
            last: last,
            advice: advice(last: last),
            repLow: repRangeLow,
            repHigh: repRangeHigh,
            fallbackWeight: fallbackWeight
        )
        let start = (sets.map(\.order).max() ?? -1) + 1
        for (index, target) in plan.enumerated() {
            sets.append(WorkoutSet(order: start + index, reps: target.reps, weight: target.weight))
        }
    }
}

extension WorkoutSet {
    /// A set that counts toward weekly hypertrophy volume: a completed working set
    /// taken within 3 reps of failure. Sets with no RIR logged are given the benefit of the doubt.
    var isHardSet: Bool {
        isCompleted && !isWarmup && (rir ?? 0) <= 3
    }
}
