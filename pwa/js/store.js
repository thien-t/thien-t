/**
 * In-memory app state mirrored to IndexedDB. The whole dataset is small (one person's
 * training log), so it's loaded once at startup and every change is written through.
 */
import * as db from './db.js';
import { DEFAULT_SETTINGS } from './model.js';

export const state = {
  routines: [],
  workouts: [],
  movements: [],
  settings: { ...DEFAULT_SETTINGS },
};

let onError = (err) => console.error(err);
export const setErrorHandler = (fn) => { onError = fn; };
const guard = (p) => p.catch((err) => onError(err));

export async function loadAll() {
  const [routines, workouts, movements, meta] = await Promise.all(db.STORES.map((s) => db.getAll(s)));
  state.routines = routines;
  state.workouts = workouts;
  state.movements = movements;
  const saved = meta.find((m) => m.key === 'settings')?.value ?? {};
  state.settings = { ...DEFAULT_SETTINGS, ...saved };
}

export const activeWorkout = () => state.workouts.find((w) => !w.endedAt) ?? null;

// Workouts: typing in reps/weight fields is debounced; everything else saves immediately.
const pending = new Map();
let timer = null;

export function saveWorkout(w) {
  pending.delete(w.id);
  return guard(db.put('workouts', w));
}

export function saveWorkoutSoon(w) {
  pending.set(w.id, w);
  clearTimeout(timer);
  timer = setTimeout(flushPending, 400);
}

export function flushPending() {
  clearTimeout(timer);
  for (const w of pending.values()) guard(db.put('workouts', w));
  pending.clear();
}

export function deleteWorkout(w) {
  pending.delete(w.id);
  state.workouts = state.workouts.filter((x) => x !== w);
  return guard(db.remove('workouts', w.id));
}

export const saveRoutine = (r) => guard(db.put('routines', r));
export function deleteRoutine(r) {
  state.routines = state.routines.filter((x) => x !== r);
  return guard(db.remove('routines', r.id));
}

export function saveMovement(m) {
  const i = state.movements.findIndex((x) => x.key === m.key);
  if (i >= 0) state.movements[i] = m;
  else state.movements.push(m);
  return guard(db.put('movements', m));
}

export const saveSettings = () => guard(db.put('meta', { key: 'settings', value: state.settings }));

/** Import helpers. `data` = { routines, workouts, movements, settings? } (already validated). */
export async function replaceEverything(data) {
  flushPending();
  const settings = { ...DEFAULT_SETTINGS, ...(data.settings ?? {}) };
  await db.replaceAll({
    routines: data.routines,
    workouts: data.workouts,
    movements: data.movements,
    meta: [{ key: 'settings', value: settings }],
  });
  await loadAll();
}

export async function mergeIn(data) {
  flushPending();
  await db.putMany('routines', data.routines ?? []);
  await db.putMany('workouts', data.workouts ?? []);
  await db.putMany('movements', data.movements ?? []);
  await loadAll();
}
