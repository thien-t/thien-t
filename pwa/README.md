# Workout Timer (web app / PWA)

The Workout Timer as an installable web app: plain HTML, CSS and JavaScript with no build step and no backend. It works fully offline, and all data is stored on your phone in IndexedDB.

**Live URL (after setup below):** https://thien-t.github.io/thien-t/

## Install on iPhone

1. Open the URL in **Safari**. It must be Safari; other browsers on iOS can't install web apps with offline support.
2. Tap **Share**, then **Add to Home Screen**, then **Add**.
3. Open **Workouts** from your Home Screen. It runs full screen and works with no signal.

> The Home Screen app keeps its own storage, separate from Safari's. Deleting the icon deletes your data, so use **Settings → Export Full Backup (JSON)** regularly and save the file to Files or iCloud Drive.

## Features

- A live workout screen. Each set has weight, reps and a ✓ checkbox. The PREVIOUS column shows last session's numbers; tap it to copy them.
- Set timer (counts up) and rest timer (counts down, with −15s, +15s and Skip). Rest starts on its own when you tick a set, and actual rest and set times are recorded.
- RIR (reps in reserve) for each set. Tap a set's number to mark it as a warm-up or delete it.
- Double-progression advice for each movement: add weight, beat last time, push closer to failure, or drop weight.
- **Volume** tab: hard sets per muscle per week, measured against 10–20 sets.
- Routines, including a one-tap hypertrophy **Push / Pull / Legs** template.
- History with per-set details, notes and **Save as Routine**.
- Backup:
  - **JSON** is a full backup (settings, routines, workouts, custom movements), restored with "Replace" or "Merge".
  - **CSV** has one row per set of your finished workouts, for spreadsheets. It can also be imported back.

## How the timers stay accurate

The app never counts ticks. It stores timestamps (`Date.now()`): when the workout started, when the current set started, and when rest ends. Every number on screen is calculated from "now". Locking the phone, switching apps or closing the app doesn't affect the timers, and they show the correct time as soon as you return. The Screen Wake Lock API keeps the display on during a workout where supported (Settings → Keep screen awake).

## Differences from the native iOS app

| Native feature | Web app |
|---|---|
| "Rest over" notification when the phone is locked or the app is in the background | **Not possible.** iOS web apps can't schedule local notifications, and push needs a server. The countdown is correct as soon as you reopen the app. |
| Haptic buzz | **Not possible.** Safari on iPhone has no Vibration API. You get a beep and a flash instead, while the app is on screen. The silent switch can mute the beep. |
| Keep screen awake | Uses Screen Wake Lock: iOS 16.4+, reliable in Home Screen apps from **iOS 18.4**. |
| SwiftData storage | IndexedDB, plus JSON/CSV export and import. |

## Deploy to GitHub Pages (free)

This repo includes `.github/workflows/deploy-pwa.yml`, which publishes the `pwa/` folder.

1. On GitHub, open the repo → **Settings → Pages** → **Build and deployment → Source: GitHub Actions**.
2. Merge this branch into **main**. Every push to `main` that changes `pwa/` redeploys. You can also run it by hand: **Actions → Deploy Workout Timer PWA → Run workflow**.
3. The site appears at `https://thien-t.github.io/thien-t/` (the URL is shown in the workflow run).

Every deploy stamps a new build id into the service worker. Installed copies of the app then show **"A new version is available → Update"** the next time they're opened.

## Run locally

```sh
cd pwa
python3 -m http.server 8000
# open http://localhost:8000
```

Service workers need `https://` or `localhost`.

## Files

```
pwa/
├── index.html              App shell, iOS meta tags
├── manifest.webmanifest    Name, icons, standalone display
├── sw.js                   Offline cache (app shell, cache-first)
├── css/app.css             iOS-style UI, light and dark mode
├── icons/                  Home Screen and manifest icons (180, 192, 512, maskable, favicon)
└── js/
    ├── app.js              Screens, navigation, timer loop, wake lock, sound, import/export UI
    ├── timer.js            Timestamp-based set/rest logic
    ├── progression.js      Last-session lookup and double-progression advice
    ├── catalog.js          Muscles, movements, hypertrophy defaults, PPL template
    ├── model.js            Data shapes and stats
    ├── store.js            In-memory state mirrored to IndexedDB
    ├── db.js               IndexedDB wrapper
    ├── backup.js           JSON/CSV export and import
    ├── format.js, ui.js, util.js
```
