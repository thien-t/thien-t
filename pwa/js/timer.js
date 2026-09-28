/**
 * Set / rest timing. Everything is stored as Date.now() timestamps and every display is
 * computed from "now", so timers stay exact across screen lock, backgrounding and relaunch.
 *
 * A workout alternates between:
 *  - working: counting up from phaseStartedAt (or from restEndsAt once a rest has run out)
 *  - resting: counting down to restEndsAt, started when a set is checked off
 */
import * as F from './format.js';

export const isResting = (w, now) => w.restEndsAt != null && now < w.restEndsAt;
export const restRemaining = (w, now) => (w.restEndsAt != null ? Math.max(0, (w.restEndsAt - now) / 1000) : 0);
export const plannedRest = (w) =>
  w.restStartedAt != null && w.restEndsAt != null ? (w.restEndsAt - w.restStartedAt) / 1000 : 0;

/** Start of the current working phase, or null while resting. */
export function workPhaseStart(w, now) {
  if (w.restEndsAt != null) return now < w.restEndsAt ? null : w.restEndsAt;
  return w.phaseStartedAt ?? w.startedAt;
}

function lastCompletedSet(w) {
  let best = null;
  for (const ex of w.exercises) {
    for (const s of ex.sets) if (s.done && (!best || s.completedAt > best.completedAt)) best = s;
  }
  return best;
}

export function nextSet(w) {
  for (const ex of w.exercises) {
    const i = ex.sets.findIndex((s) => !s.done);
    if (i >= 0) return { ex, set: ex.sets[i], number: i + 1, of: ex.sets.length };
  }
  return null;
}

export function nextUpText(w, unit) {
  const n = nextSet(w);
  if (!n) return null;
  const label = n.set.warmup ? 'Warm-up' : `Set ${n.number}/${n.of}`;
  return `${n.ex.name} · ${label} · ${F.setSummary(n.set.reps, n.set.weight, unit)}`;
}

/** Records how long the rest actually lasted and switches back to working. */
function closeRest(w, now) {
  if (w.restStartedAt == null || w.restEndsAt == null) return;
  const stop = Math.min(now, w.restEndsAt);
  const last = lastCompletedSet(w);
  if (last) last.restSec = Math.max(0, (stop - w.restStartedAt) / 1000);
  w.phaseStartedAt = stop;
  w.restStartedAt = null;
  w.restEndsAt = null;
}

export function complete(w, ex, set, now = Date.now()) {
  closeRest(w, now);
  const start = w.phaseStartedAt ?? w.startedAt;
  set.done = true;
  set.completedAt = now;
  set.workSec = Math.max(0, (now - start) / 1000);
  const rest = set.warmup ? Math.min(ex.rest, 60) : ex.rest;
  if (rest > 0) {
    w.restStartedAt = now;
    w.restEndsAt = now + rest * 1000;
    w.phaseStartedAt = null;
  } else {
    w.phaseStartedAt = now;
  }
}

export function uncomplete(set) {
  set.done = false;
  set.completedAt = null;
  set.workSec = null;
  set.restSec = null;
}

export const skipRest = (w, now = Date.now()) => closeRest(w, now);

export function adjustRest(w, deltaSeconds, now = Date.now()) {
  if (w.restEndsAt == null || now >= w.restEndsAt) return;
  const end = w.restEndsAt + deltaSeconds * 1000;
  if (end <= now) closeRest(w, now);
  else w.restEndsAt = end;
}

/** Ends the workout, dropping sets that were never checked off. */
export function finish(w, now = Date.now()) {
  closeRest(w, now);
  w.endedAt = now;
  w.phaseStartedAt = null;
  for (const ex of w.exercises) ex.sets = ex.sets.filter((s) => s.done);
  w.exercises = w.exercises.filter((e) => e.sets.length);
}
