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

    var duration: TimeInterval { (endedAt ?? .now).timeIntervalSince(startedAt) }
    var totalReps: Int { completedSets.reduce(0) { $0 + $1.reps } }
    var totalVolume: Double { completedSets.reduce(0) { $0 + Double($1.reps) * $1.weight } }
    var totalWorkTime: TimeInterval { completedSets.reduce(0) { $0 + ($1.workSeconds ?? 0) } }
    var totalRestTime: TimeInterval { completedSets.reduce(0) { $0 + ($1.restSeconds ?? 0) } }
}

@Model
final class WorkoutExercise {
    var name: String
    var order: Int
    var restSeconds: Int
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.exercise)
    var sets: [WorkoutSet] = []
    var workout: Workout?

    init(name: String, order: Int, restSeconds: Int) {
        self.name = name
        self.order = order
        self.restSeconds = restSeconds
    }

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
