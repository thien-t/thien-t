import Foundation
import SwiftData

/// A logged workout session. While `endedAt` is nil the workout is in progress.
@Model
final class Workout {
    var name: String
    var startedAt: Date
    var endedAt: Date? = nil
    var notes: String = ""
    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.workout)
    var exercises: [WorkoutExercise] = []

    // Live timer state, persisted so timers survive the app being closed.
    /// When the current working phase began (workout start, or end of the last rest).
    var phaseStartedAt: Date? = nil
    var restStartedAt: Date? = nil
    var restEndsAt: Date? = nil

    init(name: String, startedAt: Date = .now) {
        self.name = name
        self.startedAt = startedAt
        self.phaseStartedAt = startedAt
    }

    var isActive: Bool { endedAt == nil }

    var sortedExercises: [WorkoutExercise] {
        exercises.sorted { $0.order < $1.order }
    }

    var allSets: [WorkoutSet] { sortedExercises.flatMap(\.sortedSets) }
    var completedSets: [WorkoutSet] { allSets.filter(\.isCompleted) }
    var workingSets: [WorkoutSet] { completedSets.filter { !$0.isWarmup } }
    var hardSetCount: Int { allSets.filter(\.isHardSet).count }

    var duration: TimeInterval { (endedAt ?? .now).timeIntervalSince(startedAt) }
    var totalReps: Int { workingSets.reduce(0) { $0 + $1.reps } }
    var totalVolume: Double { workingSets.reduce(0) { $0 + Double($1.reps) * $1.weight } }
    var totalWorkTime: TimeInterval { completedSets.reduce(0) { $0 + ($1.workSeconds ?? 0) } }
    var totalRestTime: TimeInterval { completedSets.reduce(0) { $0 + ($1.restSeconds ?? 0) } }
}

@Model
final class WorkoutExercise {
    var name: String
    var order: Int
    var restSeconds: Int
    var repRangeLow: Int = 8
    var repRangeHigh: Int = 12
    var targetRIR: Int = 2
    var weightIncrement: Double = 2.5
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.exercise)
    var sets: [WorkoutSet] = []
    var workout: Workout?

    init(
        name: String,
        order: Int,
        restSeconds: Int,
        repRangeLow: Int = 8,
        repRangeHigh: Int = 12,
        targetRIR: Int = 2,
        weightIncrement: Double = 2.5
    ) {
        self.name = name
        self.order = order
        self.restSeconds = restSeconds
        self.repRangeLow = repRangeLow
        self.repRangeHigh = repRangeHigh
        self.targetRIR = targetRIR
        self.weightIncrement = weightIncrement
    }

    convenience init(name: String, order: Int, defaults: MovementDefaults) {
        self.init(
            name: name,
            order: order,
            restSeconds: defaults.restSeconds,
            repRangeLow: defaults.repLow,
            repRangeHigh: defaults.repHigh,
            targetRIR: defaults.targetRIR,
            weightIncrement: defaults.increment
        )
    }

    convenience init(from planned: RoutineExercise, order: Int) {
        self.init(
            name: planned.name,
            order: order,
            restSeconds: planned.restSeconds,
            repRangeLow: planned.repRangeLow,
            repRangeHigh: planned.repRangeHigh,
            targetRIR: planned.targetRIR,
            weightIncrement: planned.weightIncrement
        )
    }

    var repRangeText: String { "\(repRangeLow)–\(repRangeHigh) reps" }

    var sortedSets: [WorkoutSet] {
        sets.sorted { $0.order < $1.order }
    }
}

@Model
final class WorkoutSet {
    var order: Int
    var reps: Int
    var weight: Double
    var isCompleted: Bool = false
    /// Warm-up sets don't count toward volume or progression.
    var isWarmup: Bool = false
    /// Reps in reserve: how many more reps you could have done (4 means 4+).
    var rir: Int? = nil
    var completedAt: Date? = nil
    /// How long the set itself took (from the end of the previous rest to checking it off).
    var workSeconds: Double? = nil
    /// How long you actually rested after this set.
    var restSeconds: Double? = nil
    var exercise: WorkoutExercise?

    init(order: Int, reps: Int, weight: Double) {
        self.order = order
        self.reps = reps
        self.weight = weight
    }
}
