import Foundation
import UIKit

enum SettingsKey {
    static let weightUnit = "weightUnit"
    static let defaultRestSeconds = "defaultRestSeconds"
    static let keepScreenAwake = "keepScreenAwake"
}

enum WeightUnit: String, CaseIterable, Identifiable {
    case kg, lb
    var id: String { rawValue }
    var label: String { self == .kg ? "Kilograms (kg)" : "Pounds (lb)" }
}

enum Format {
    /// 75 -> "1:15", 3725 -> "1:02:05"
    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    static func weight(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    static func rest(_ seconds: Int) -> String {
        if seconds == 0 { return "Off" }
        if seconds < 60 { return "\(seconds)s" }
        if seconds % 60 == 0 { return "\(seconds / 60) min" }
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    /// "10 × 60 kg", or "10 reps" for bodyweight movements.
    static func setSummary(reps: Int, weight: Double, unit: String) -> String {
        weight > 0 ? "\(reps) × \(Format.weight(weight)) \(unit)" : "\(reps) reps"
    }
}

enum RestOptions {
    static let standard = [0, 15, 30, 45, 60, 75, 90, 105, 120, 150, 180, 210, 240, 300, 360, 420, 480, 600]

    static func values(including value: Int) -> [Int] {
        standard.contains(value) ? standard : (standard + [value]).sorted()
    }
}

enum Movement {
    static let common = [
        "Bench Press", "Incline Bench Press", "Dumbbell Bench Press", "Incline Dumbbell Press",
        "Chest Fly", "Push-Up", "Dip",
        "Squat", "Front Squat", "Goblet Squat", "Leg Press", "Lunge", "Bulgarian Split Squat",
        "Leg Extension", "Leg Curl", "Calf Raise", "Hip Thrust",
        "Deadlift", "Romanian Deadlift", "Sumo Deadlift", "Good Morning",
        "Overhead Press", "Dumbbell Shoulder Press", "Lateral Raise", "Rear Delt Fly", "Face Pull",
        "Pull-Up", "Chin-Up", "Lat Pulldown", "Barbell Row", "Dumbbell Row", "Seated Cable Row",
        "Shrug", "Bicep Curl", "Hammer Curl", "Preacher Curl",
        "Tricep Pushdown", "Skull Crusher", "Overhead Tricep Extension",
        "Plank", "Hanging Leg Raise", "Cable Crunch", "Russian Twist",
        "Kettlebell Swing", "Clean", "Snatch", "Thruster", "Burpee", "Box Jump",
    ]
}

func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
