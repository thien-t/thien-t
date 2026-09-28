import Foundation
import SwiftData

enum MuscleGroup: String, CaseIterable, Identifiable {
    case push = "Push", pull = "Pull", legs = "Legs", core = "Core"
    var id: String { rawValue }
    var muscles: [Muscle] { Muscle.allCases.filter { $0.group == self } }
}

enum Muscle: String, CaseIterable, Identifiable, Codable {
    case chest, frontDelts, sideDelts, rearDelts, triceps
    case lats, upperBack, traps, biceps, forearms
    case quads, hamstrings, glutes, calves
    case abs, lowerBack

    var id: String { rawValue }

    var name: String {
        switch self {
        case .chest: "Chest"
        case .frontDelts: "Front Delts"
        case .sideDelts: "Side Delts"
        case .rearDelts: "Rear Delts"
        case .triceps: "Triceps"
        case .lats: "Lats"
        case .upperBack: "Upper Back"
        case .traps: "Traps"
        case .biceps: "Biceps"
        case .forearms: "Forearms"
        case .quads: "Quads"
        case .hamstrings: "Hamstrings"
        case .glutes: "Glutes"
        case .calves: "Calves"
        case .abs: "Abs"
        case .lowerBack: "Lower Back"
        }
    }

    var group: MuscleGroup {
        switch self {
        case .chest, .frontDelts, .sideDelts, .triceps: .push
        case .lats, .upperBack, .rearDelts, .traps, .biceps, .forearms: .pull
        case .quads, .hamstrings, .glutes, .calves: .legs
        case .abs, .lowerBack: .core
        }
    }

    /// Muscles we hold to the 10–20 hard sets/week hypertrophy target. The rest
    /// (front delts, traps, forearms, abs, lower back) get plenty of indirect work
    /// from compounds, so their volume is shown but not graded.
    var hasWeeklyTarget: Bool {
        switch self {
        case .frontDelts, .traps, .forearms, .abs, .lowerBack: false
        default: true
        }
    }
}

/// Hypertrophy defaults for a movement: rep range, effort, rest and load jump.
struct MovementDefaults {
    var repLow: Int
    var repHigh: Int
    var targetRIR: Int
    var restSeconds: Int
    var increment: Double

    /// For movements that aren't in the catalog and haven't been tagged.
    static var fallback: MovementDefaults {
        let rest = UserDefaults.standard.object(forKey: SettingsKey.defaultRestSeconds) as? Int ?? 120
        return MovementDefaults(repLow: 8, repHigh: 12, targetRIR: 2, restSeconds: rest, increment: 2.5)
    }
}

struct MovementInfo {
    let name: String
    let primary: Muscle
    let secondary: [Muscle]
    let isCompound: Bool

    init(_ name: String, _ primary: Muscle, _ secondary: [Muscle] = [], compound: Bool) {
        self.name = name
        self.primary = primary
        self.secondary = secondary
        self.isCompound = compound
    }

    var defaults: MovementDefaults {
        if isCompound {
            // Heavier, lower-rep work; longer rest keeps rep quality up on the next set.
            return MovementDefaults(repLow: 6, repHigh: 10, targetRIR: 2, restSeconds: 150, increment: 2.5)
        }
        switch primary {
        case .sideDelts, .rearDelts, .calves, .abs, .forearms:
            return MovementDefaults(repLow: 12, repHigh: 20, targetRIR: 1, restSeconds: 90, increment: 2.5)
        default:
            return MovementDefaults(repLow: 10, repHigh: 15, targetRIR: 1, restSeconds: 90, increment: 2.5)
        }
    }
}

enum MovementCatalog {
    static let all: [MovementInfo] = [
        // Chest
        .init("Bench Press", .chest, [.triceps, .frontDelts], compound: true),
        .init("Incline Bench Press", .chest, [.frontDelts, .triceps], compound: true),
        .init("Dumbbell Bench Press", .chest, [.triceps, .frontDelts], compound: true),
        .init("Incline Dumbbell Press", .chest, [.frontDelts, .triceps], compound: true),
        .init("Machine Chest Press", .chest, [.triceps, .frontDelts], compound: true),
        .init("Push-Up", .chest, [.triceps, .frontDelts], compound: true),
        .init("Dip", .chest, [.triceps, .frontDelts], compound: true),
        .init("Chest Fly", .chest, compound: false),
        .init("Cable Crossover", .chest, compound: false),
        // Shoulders
        .init("Overhead Press", .frontDelts, [.sideDelts, .triceps], compound: true),
        .init("Dumbbell Shoulder Press", .frontDelts, [.sideDelts, .triceps], compound: true),
        .init("Lateral Raise", .sideDelts, compound: false),
        .init("Cable Lateral Raise", .sideDelts, compound: false),
        .init("Rear Delt Fly", .rearDelts, compound: false),
        .init("Face Pull", .rearDelts, [.upperBack], compound: false),
        // Triceps
        .init("Close-Grip Bench Press", .triceps, [.chest, .frontDelts], compound: true),
        .init("Tricep Pushdown", .triceps, compound: false),
        .init("Skull Crusher", .triceps, compound: false),
        .init("Overhead Tricep Extension", .triceps, compound: false),
        // Back
        .init("Pull-Up", .lats, [.biceps, .upperBack], compound: true),
        .init("Chin-Up", .lats, [.biceps], compound: true),
        .init("Lat Pulldown", .lats, [.biceps, .upperBack], compound: true),
        .init("Straight-Arm Pulldown", .lats, compound: false),
        .init("Barbell Row", .upperBack, [.lats, .biceps, .rearDelts], compound: true),
        .init("Dumbbell Row", .lats, [.upperBack, .biceps], compound: true),
        .init("Seated Cable Row", .upperBack, [.lats, .biceps, .rearDelts], compound: true),
        .init("Chest-Supported Row", .upperBack, [.lats, .rearDelts, .biceps], compound: true),
        .init("Shrug", .traps, compound: false),
        // Biceps & forearms
        .init("Bicep Curl", .biceps, [.forearms], compound: false),
        .init("Hammer Curl", .biceps, [.forearms], compound: false),
        .init("Incline Dumbbell Curl", .biceps, compound: false),
        .init("Preacher Curl", .biceps, compound: false),
        .init("Wrist Curl", .forearms, compound: false),
        // Quads & glutes
        .init("Squat", .quads, [.glutes], compound: true),
        .init("Front Squat", .quads, [.glutes], compound: true),
        .init("Hack Squat", .quads, [.glutes], compound: true),
        .init("Goblet Squat", .quads, [.glutes], compound: true),
        .init("Leg Press", .quads, [.glutes], compound: true),
        .init("Lunge", .quads, [.glutes], compound: true),
        .init("Bulgarian Split Squat", .quads, [.glutes], compound: true),
        .init("Leg Extension", .quads, compound: false),
        .init("Hip Thrust", .glutes, [.hamstrings], compound: true),
        // Hamstrings & posterior chain
        .init("Deadlift", .hamstrings, [.glutes, .lowerBack, .traps], compound: true),
        .init("Romanian Deadlift", .hamstrings, [.glutes, .lowerBack], compound: true),
        .init("Sumo Deadlift", .glutes, [.quads, .hamstrings, .lowerBack], compound: true),
        .init("Good Morning", .hamstrings, [.glutes, .lowerBack], compound: true),
        .init("Leg Curl", .hamstrings, compound: false),
        .init("Seated Leg Curl", .hamstrings, compound: false),
        .init("Back Extension", .lowerBack, [.glutes, .hamstrings], compound: false),
        .init("Kettlebell Swing", .glutes, [.hamstrings], compound: true),
        // Calves & core
        .init("Calf Raise", .calves, compound: false),
        .init("Seated Calf Raise", .calves, compound: false),
        .init("Plank", .abs, compound: false),
        .init("Hanging Leg Raise", .abs, compound: false),
        .init("Cable Crunch", .abs, compound: false),
        .init("Russian Twist", .abs, compound: false),
    ]

    private static let byName: [String: MovementInfo] = Dictionary(
        all.map { ($0.name.lowercased(), $0) },
        uniquingKeysWith: { first, _ in first }
    )

    static func builtIn(_ name: String) -> MovementInfo? {
        byName[name.lowercased()]
    }
}

/// Looks up which muscles a movement trains: your own tags first, then the built-in catalog.
struct MuscleResolver {
    private let custom: [String: MovementInfo]

    init(custom: [CustomMovement]) {
        self.custom = Dictionary(
            custom.compactMap { movement in movement.info.map { (movement.name.lowercased(), $0) } },
            uniquingKeysWith: { first, _ in first }
        )
    }

    func info(for name: String) -> MovementInfo? {
        custom[name.lowercased()] ?? MovementCatalog.builtIn(name)
    }

    func defaults(for name: String) -> MovementDefaults {
        info(for: name)?.defaults ?? .fallback
    }
}

/// A movement you typed yourself, tagged with the muscles it trains.
@Model
final class CustomMovement {
    @Attribute(.unique) var name: String
    var primaryRaw: String
    var secondaryRaw: [String] = []
    var isCompound: Bool = false

    init(name: String, primary: Muscle, secondary: [Muscle], isCompound: Bool) {
        self.name = name
        self.primaryRaw = primary.rawValue
        self.secondaryRaw = secondary.map(\.rawValue)
        self.isCompound = isCompound
    }

    var info: MovementInfo? {
        guard let primary = Muscle(rawValue: primaryRaw) else { return nil }
        return MovementInfo(name, primary, secondaryRaw.compactMap(Muscle.init(rawValue:)), compound: isCompound)
    }
}

/// A hypertrophy-focused Push / Pull / Legs split. Run it twice a week (6 days) to land
/// most muscles in the 10–20 hard sets/week range.
enum PPLTemplate {
    private struct Item {
        let name: String
        let sets: Int
        let low: Int
        let high: Int
        let rir: Int
        let rest: Int
    }

    private static let days: [(String, [Item])] = [
        ("Push", [
            Item(name: "Bench Press", sets: 3, low: 6, high: 10, rir: 2, rest: 180),
            Item(name: "Incline Dumbbell Press", sets: 3, low: 8, high: 12, rir: 2, rest: 150),
            Item(name: "Dumbbell Shoulder Press", sets: 3, low: 8, high: 12, rir: 2, rest: 150),
            Item(name: "Lateral Raise", sets: 4, low: 12, high: 20, rir: 1, rest: 90),
            Item(name: "Tricep Pushdown", sets: 3, low: 10, high: 15, rir: 1, rest: 90),
            Item(name: "Overhead Tricep Extension", sets: 2, low: 10, high: 15, rir: 1, rest: 90),
        ]),
        ("Pull", [
            Item(name: "Lat Pulldown", sets: 3, low: 8, high: 12, rir: 2, rest: 150),
            Item(name: "Barbell Row", sets: 3, low: 6, high: 10, rir: 2, rest: 180),
            Item(name: "Seated Cable Row", sets: 3, low: 10, high: 15, rir: 1, rest: 120),
            Item(name: "Face Pull", sets: 3, low: 12, high: 20, rir: 1, rest: 90),
            Item(name: "Bicep Curl", sets: 3, low: 8, high: 12, rir: 1, rest: 90),
            Item(name: "Hammer Curl", sets: 2, low: 10, high: 15, rir: 1, rest: 90),
        ]),
        ("Legs", [
            Item(name: "Squat", sets: 3, low: 6, high: 10, rir: 2, rest: 180),
            Item(name: "Romanian Deadlift", sets: 3, low: 8, high: 12, rir: 2, rest: 180),
            Item(name: "Leg Press", sets: 3, low: 10, high: 15, rir: 2, rest: 150),
            Item(name: "Leg Curl", sets: 3, low: 10, high: 15, rir: 1, rest: 90),
            Item(name: "Leg Extension", sets: 3, low: 10, high: 15, rir: 1, rest: 90),
            Item(name: "Calf Raise", sets: 4, low: 12, high: 20, rir: 1, rest: 90),
        ]),
    ]

    static func install(into context: ModelContext) {
        for (offset, (name, items)) in days.enumerated() {
            let routine = Routine(name: name, createdAt: .now.addingTimeInterval(TimeInterval(offset)))
            context.insert(routine)
            for (index, item) in items.enumerated() {
                routine.exercises.append(RoutineExercise(
                    name: item.name,
                    order: index,
                    targetSets: item.sets,
                    repRangeLow: item.low,
                    repRangeHigh: item.high,
                    targetRIR: item.rir,
                    restSeconds: item.rest
                ))
            }
        }
    }
}
