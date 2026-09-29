import Foundation
import SwiftData

/// Set / rest timing logic.
///
/// A workout alternates between two phases:
/// - **Working**: counting up from `phaseStartedAt` (or from `restEndsAt` once a rest has run out).
/// - **Resting**: counting down to `restEndsAt`, started automatically when a set is checked off.
extension Workout {
    func isResting(at now: Date) -> Bool {
        guard let end = restEndsAt else { return false }
        return now < end
    }

    func restRemaining(at now: Date) -> TimeInterval {
        guard let end = restEndsAt else { return 0 }
        return max(0, end.timeIntervalSince(now))
    }

    var plannedRest: TimeInterval {
        guard let start = restStartedAt, let end = restEndsAt else { return 0 }
        return end.timeIntervalSince(start)
    }

    /// Start of the current working phase, or nil while resting.
    func workPhaseStart(at now: Date) -> Date? {
        if let end = restEndsAt {
            return now < end ? nil : end
        }
        return phaseStartedAt ?? startedAt
    }

    var lastCompletedSet: WorkoutSet? {
        completedSets.max { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }
    }

    /// The first set that hasn't been checked off yet, with its exercise and position.
    var nextSet: (exercise: WorkoutExercise, set: WorkoutSet, number: Int, of: Int)? {
        for exercise in sortedExercises {
            let sets = exercise.sortedSets
            if let index = sets.firstIndex(where: { !$0.isCompleted }) {
                return (exercise, sets[index], index + 1, sets.count)
            }
        }
        return nil
    }

    var nextUpDescription: String? {
        guard let next = nextSet else { return nil }
        let unit = UserDefaults.standard.string(forKey: SettingsKey.weightUnit) ?? WeightUnit.kg.rawValue
        return "\(next.exercise.name) · Set \(next.number)/\(next.of) · "
            + Format.setSummary(reps: next.set.reps, weight: next.set.weight, unit: unit)
    }

    // MARK: Actions

    func complete(_ set: WorkoutSet, at now: Date = .now) {
        closeRest(at: now)
        let start = phaseStartedAt ?? startedAt
        set.isCompleted = true
        set.completedAt = now
        set.workSeconds = max(0, now.timeIntervalSince(start))

        let planned = set.exercise?.restSeconds ?? 0
        let rest = set.isWarmup ? min(planned, 60) : planned
        if rest > 0 {
            let end = now.addingTimeInterval(TimeInterval(rest))
            restStartedAt = now
            restEndsAt = end
            phaseStartedAt = nil
            RestNotifier.schedule(at: end, nextUp: nextUpDescription)
        } else {
            phaseStartedAt = now
        }
    }

    func uncomplete(_ set: WorkoutSet) {
        set.isCompleted = false
        set.completedAt = nil
        set.workSeconds = nil
        set.restSeconds = nil
    }

    func skipRest(at now: Date = .now) {
        closeRest(at: now)
    }

    func adjustRest(by delta: TimeInterval, at now: Date = .now) {
        guard let end = restEndsAt, now < end else { return }
        let newEnd = end.addingTimeInterval(delta)
        if newEnd <= now {
            closeRest(at: now)
        } else {
            restEndsAt = newEnd
            RestNotifier.schedule(at: newEnd, nextUp: nextUpDescription)
        }
    }

    /// Ends the workout, dropping sets that were never checked off.
    func finish(in context: ModelContext, at now: Date = .now) {
        closeRest(at: now)
        endedAt = now
        phaseStartedAt = nil

        for exercise in exercises {
            let unfinished = exercise.sets.filter { !$0.isCompleted }
            exercise.sets.removeAll { !$0.isCompleted }
            unfinished.forEach { context.delete($0) }
        }
        let empty = exercises.filter { $0.sets.isEmpty }
        exercises.removeAll { $0.sets.isEmpty }
        empty.forEach { context.delete($0) }
    }

    func discard(in context: ModelContext) {
        RestNotifier.cancel()
        context.delete(self)
    }

    /// Records how long the rest actually lasted and switches back to the working phase.
    private func closeRest(at now: Date) {
        guard let start = restStartedAt, let end = restEndsAt else { return }
        let stop = min(now, end)
        lastCompletedSet?.restSeconds = max(0, stop.timeIntervalSince(start))
        phaseStartedAt = stop
        restStartedAt = nil
        restEndsAt = nil
        RestNotifier.cancel()
    }
}
