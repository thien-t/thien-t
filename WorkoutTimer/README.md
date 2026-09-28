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
- **Hypertrophy coaching**
  - **Last session on every set**: a PREVIOUS column shows what you did last time (for example `60 × 10 @2`). Tap it to copy those numbers. Sets are pre-filled from your last session and the progression advice.
  - **RIR logging**: after checking off a set, tap how many reps you had left (0, 1, 2, 3 or 4+). Sets at 4+ RIR are flagged "Too easy".
  - **Double progression**: each movement has a rep range, target RIR and weight jump. A coach line on each exercise tells you what to do today:
    - **Add weight**: you hit the top of the range on every set last time.
    - **Beat last time**: same weight, +1 rep per set.
    - **Push closer to failure**: last session's RIR was well above target.
    - **Drop weight**: most sets fell below the range.
  - **Warm-up sets**: tap a set's number to mark it **W**. Warm-ups get a short rest and don't count toward volume or progression.
  - **Weekly volume (Volume tab)**: hard sets per muscle (RIR 0–3, working sets only). The main muscle gets 1 set and the other muscles a movement works get ½. Each muscle is compared to the **10–20 sets/week** target, marked Under, On target or High. You can browse previous weeks, and tag custom movements with their muscles.
  - **Push / Pull / Legs template**: one tap adds hypertrophy-focused Push, Pull and Legs routines, designed to be run twice a week.
- **Routines**: plan workouts with sets, rep range, target RIR, weight jump and rest for each movement, then start one with a single tap.
- **History**: finished workouts with duration, sets, reps, total volume, time spent in sets and time spent resting, plus per-set details. There's a weekly summary, notes, and **Save as Routine** to repeat a workout.
- **Movement picker**: about 55 lifts tagged with the muscles they train, the movements you've used before, or any name you type (then tag its muscles). You can search by movement or by muscle.
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
│   ├── Workout+Timer.swift      Set/rest timer logic (complete set, skip/adjust rest, finish)
├── Support/
│   ├── RestNotifier.swift       Local "rest over" notifications
│   └── Format.swift             Formatting, settings keys, rest options, movement list
└── Views/                       SwiftUI screens (active workout, timer banner, routines, history, settings)
```
