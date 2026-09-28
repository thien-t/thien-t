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
    var repRangeLow: Int = 8
    var repRangeHigh: Int = 12
    /// Reps in reserve to aim for on working sets (0 = failure).
    var targetRIR: Int = 2
    /// How much to add once you hit the top of the rep range on every set.
    var weightIncrement: Double = 2.5
    /// Starting weight, used the first time you do the movement.
    var targetWeight: Double
    var restSeconds: Int
    var routine: Routine?

    init(
        name: String,
        order: Int,
        targetSets: Int = 3,
        repRangeLow: Int = 8,
        repRangeHigh: Int = 12,
        targetRIR: Int = 2,
        weightIncrement: Double = 2.5,
        targetWeight: Double = 0,
        restSeconds: Int = 120
    ) {
        self.name = name
        self.order = order
        self.targetSets = targetSets
        self.repRangeLow = repRangeLow
        self.repRangeHigh = repRangeHigh
        self.targetRIR = targetRIR
        self.weightIncrement = weightIncrement
        self.targetWeight = targetWeight
        self.restSeconds = restSeconds
    }

    convenience init(name: String, order: Int, defaults: MovementDefaults) {
        self.init(
            name: name,
            order: order,
            repRangeLow: defaults.repLow,
            repRangeHigh: defaults.repHigh,
            targetRIR: defaults.targetRIR,
            weightIncrement: defaults.increment,
            restSeconds: defaults.restSeconds
        )
    }
}
