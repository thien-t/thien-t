import Foundation
import SwiftData

/// A reusable workout plan: a list of movements with target sets, reps, weight and rest.
@Model
final class Routine {
    var name: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \RoutineExercise.routine)
    var exercises: [RoutineExercise] = []

    init(name: String, createdAt: Date = .now) {
        self.name = name
        self.createdAt = createdAt
    }

    var sortedExercises: [RoutineExercise] {
        exercises.sorted { $0.order < $1.order }
    }

    var summary: String {
        let setCount = exercises.reduce(0) { $0 + $1.targetSets }
        let noun = exercises.count == 1 ? "exercise" : "exercises"
        return "\(exercises.count) \(noun) · \(setCount) sets"
    }
}

@Model
final class RoutineExercise {
    var name: String
    var order: Int
    var targetSets: Int
    var targetReps: Int
    var targetWeight: Double
    var restSeconds: Int
    var routine: Routine?

    init(
        name: String,
        order: Int,
        targetSets: Int = 3,
        targetReps: Int = 10,
        targetWeight: Double = 0,
        restSeconds: Int = 90
    ) {
        self.name = name
        self.order = order
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.restSeconds = restSeconds
    }
}
