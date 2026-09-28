# Workout Timer (iPhone)

A SwiftUI + SwiftData iPhone app that times your strength workouts: movements, sets, reps, weights and rest periods.

## Features

- **Live workout screen**
  - Total elapsed time for the session.
  - Each movement has a set table with editable **reps** and **weight** and a checkbox for each set.
  - **Set timer**: counts up while you do a set. Check the set off and the app records how long the set took.
  - **Rest timer**: starts on its own when you check off a set, using that movement's rest time. You get:
    - a big countdown with a progress bar
    - **−15s / +15s** and **Skip Rest** buttons
    - a preview of the next set
    - a vibration plus a notification when rest is over, which still arrives if your phone is locked or the app is in the background
  - Actual rest time is recorded for every set.
  - Add or remove movements and sets as you go. Change a movement's rest time from its menu.
  - The screen stays awake during a workout (you can turn this off in Settings).
  - Timers are saved, so closing the app mid-workout doesn't lose anything.
- **Routines**: plan workouts with target sets, reps, weight and rest for each movement, then start one with a single tap.
- **History**: finished workouts with duration, sets, reps, total volume, time spent in sets and time spent resting, plus per-set details. There's a weekly summary, notes, and **Save as Routine** to repeat a workout.
- **Movement picker**: about 50 common lifts, the movements you've used before, or any name you type.
- **Settings**: kg or lb, default rest time, and whether to keep the screen awake.

## Run it on your iPhone

Requirements: a Mac with **Xcode 16 or later**, and an iPhone on **iOS 17 or later**.

1. Open `WorkoutTimer/WorkoutTimer.xcodeproj` in Xcode.
2. Select the **WorkoutTimer** target → **Signing & Capabilities** → choose your **Team**. A free Apple ID works; add it under Xcode → Settings → Accounts. If Xcode complains that the bundle identifier is taken, change it to something unique, such as `com.yourname.WorkoutTimer`.
3. Connect your iPhone, pick it as the run destination, and press **Run** (⌘R).
4. On the phone, the first time only: turn on **Developer Mode** (Settings → Privacy & Security), and trust your developer certificate (Settings → General → VPN & Device Management).
5. Allow notifications when asked, so you get alerts when rest is over.

You can also run it in the iOS Simulator by choosing any iPhone simulator as the destination.

> With a free Apple ID, apps you install yourself expire after 7 days. Just press Run again to reinstall; your data is kept.

## Project layout

```
WorkoutTimer/
├── WorkoutTimerApp.swift        App entry, SwiftData container, notification delegate
├── Models/
│   ├── Routine.swift            Routine + RoutineExercise (planned targets)
│   ├── Workout.swift            Workout → WorkoutExercise → WorkoutSet (logged data)
│   └── Workout+Timer.swift      Set/rest timer logic (complete set, skip/adjust rest, finish)
├── Support/
│   ├── RestNotifier.swift       Local "rest over" notifications
│   └── Format.swift             Formatting, settings keys, rest options, movement list
└── Views/                       SwiftUI screens (active workout, timer banner, routines, history, settings)
```
