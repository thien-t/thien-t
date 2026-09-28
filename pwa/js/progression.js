import { newSet } from './model.js';

/** Latest finished session of every movement (working sets only), keyed by lowercase name. */
export function buildHistory(workouts) {
  const finished = workouts.filter((w) => w.endedAt).sort((a, b) => b.startedAt - a.startedAt);
  const map = new Map();
  for (const w of finished) {
    for (const ex of w.exercises) {
      const key = ex.name.toLowerCase();
      if (map.has(key)) continue;
      const sets = ex.sets.filter((s) => s.done && !s.warmup);
      if (sets.length) map.set(key, { date: w.startedAt, sets });
    }
  }
  return map;
}

/**
 * Double progression: work up to the top of the rep range on every set, then add weight.
 * Returns { kind: 'first' | 'increase' | 'reduce' | 'harder' | 'beat', weight?, average? }.
 */
export function advice(ex, last) {
  const sets = last?.sets ?? [];
  if (!sets.length) return { kind: 'first' };
  const top = Math.max(...sets.map((s) => s.weight));
  if (sets.every((s) => s.reps >= ex.repHigh)) return { kind: 'increase', weight: top + ex.increment };
  const below = sets.filter((s) => s.reps < ex.repLow).length;
  if (below * 2 > sets.length && top > ex.increment) return { kind: 'reduce', weight: top - ex.increment };
  const rirs = sets.map((s) => s.rir).filter((r) => r != null);
  if (rirs.length === sets.length) {
    const average = rirs.reduce((a, b) => a + b, 0) / rirs.length;
    if (average >= ex.targetRIR + 2) return { kind: 'harder', average };
  }
  return { kind: 'beat' };
}

/** Weight and reps to pre-fill for each set today. */
export function plan(count, last, adv, ex, fallbackWeight) {
  const prev = last?.sets ?? [];
  return Array.from({ length: Math.max(1, count) }, (_, i) => {
    const p = prev[i] ?? prev.at(-1);
    switch (adv.kind) {
      case 'increase':
      case 'reduce':
        return { reps: ex.repLow, weight: adv.weight };
      case 'harder':
      case 'beat':
        if (p) return { reps: Math.min(ex.repHigh, Math.max(ex.repLow, p.reps + 1)), weight: p.weight };
        return { reps: ex.repLow, weight: fallbackWeight };
      default:
        return { reps: ex.repLow, weight: fallbackWeight };
    }
  });
}

export function fillSets(ex, count, last, fallbackWeight = 0) {
  for (const t of plan(count, last, advice(ex, last), ex, fallbackWeight)) {
    ex.sets.push(newSet(t.reps, t.weight));
  }
}
