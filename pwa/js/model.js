import { uid } from './util.js';

export const DEFAULT_SETTINGS = { unit: 'kg', defaultRest: 120, keepAwake: true, sound: true };

export function newWorkout(name, now = Date.now()) {
  return {
    id: uid(), name, startedAt: now, endedAt: null, notes: '',
    // Live timer state (ms timestamps), persisted so timers survive the app closing.
    phaseStartedAt: now, restStartedAt: null, restEndsAt: null,
    exercises: [],
  };
}

export function newExercise(name, d) {
  return {
    id: uid(), name, rest: d.rest, repLow: d.repLow, repHigh: d.repHigh,
    targetRIR: d.targetRIR, increment: d.increment, sets: [],
  };
}

export function exerciseFromRoutine(r) {
  return newExercise(r.name, r);
}

export function newSet(reps, weight) {
  return {
    id: uid(), reps, weight, done: false, warmup: false, rir: null,
    completedAt: null, workSec: null, restSec: null,
  };
}

export function newRoutine(name, now = Date.now()) {
  return { id: uid(), name, createdAt: now, exercises: [] };
}

export function newRoutineExercise(name, d, sets = 3) {
  return {
    id: uid(), name, sets, repLow: d.repLow, repHigh: d.repHigh, targetRIR: d.targetRIR,
    increment: d.increment, startWeight: 0, rest: d.rest,
  };
}

// Stats
export const duration = (w, now = Date.now()) => ((w.endedAt ?? now) - w.startedAt) / 1000;
export const workingSets = (w) => w.exercises.flatMap((e) => e.sets.filter((s) => s.done && !s.warmup));
/** Completed working set within 3 reps of failure. Sets with no RIR logged get the benefit of the doubt. */
export const isHardSet = (s) => s.done && !s.warmup && (s.rir ?? 0) <= 3;
export const hardSetCount = (w) => w.exercises.reduce((n, e) => n + e.sets.filter(isHardSet).length, 0);
export const totalReps = (w) => workingSets(w).reduce((n, s) => n + s.reps, 0);
export const totalVolume = (w) => workingSets(w).reduce((n, s) => n + s.reps * s.weight, 0);
export const totalWork = (w) => w.exercises.reduce((n, e) => n + e.sets.reduce((m, s) => m + (s.done ? s.workSec ?? 0 : 0), 0), 0);
export const totalRest = (w) => w.exercises.reduce((n, e) => n + e.sets.reduce((m, s) => m + (s.done ? s.restSec ?? 0 : 0), 0), 0);
