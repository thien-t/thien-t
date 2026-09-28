const pad = (n) => String(n).padStart(2, '0');

/** 75 -> "1:15", 3725 -> "1:02:05" */
export function clock(seconds) {
  const t = Math.max(0, Math.floor(seconds));
  const h = Math.floor(t / 3600), m = Math.floor((t % 3600) / 60), s = t % 60;
  return h > 0 ? `${h}:${pad(m)}:${pad(s)}` : `${m}:${pad(s)}`;
}

const number = (n, digits) =>
  Number(n || 0).toLocaleString(undefined, { maximumFractionDigits: digits });

export const weight = (n) => number(n, 2);
export const sets = (n) => number(n, 1);
export const rir = (v) => (v >= 4 ? '4+' : String(v));

export function rest(seconds) {
  if (seconds === 0) return 'Off';
  if (seconds < 60) return `${seconds}s`;
  if (seconds % 60 === 0) return `${seconds / 60} min`;
  return `${Math.floor(seconds / 60)}:${pad(seconds % 60)}`;
}

/** "60 kg × 10" (weight × reps, same order as the PREVIOUS column), or "10 reps" for bodyweight. */
export const setSummary = (reps, w, unit) => (w > 0 ? `${weight(w)} ${unit} × ${reps}` : `${reps} reps`);

/** "1 set", "2.5 sets" */
export const setCount = (n, noun = 'set') => `${sets(n)} ${n === 1 ? noun : noun + 's'}`;

/** Compact "60 × 10 @2" used in the PREVIOUS column. */
export function previous(set) {
  let text = set.weight > 0 ? `${weight(set.weight)} × ${set.reps}` : `${set.reps} reps`;
  if (set.rir != null) text += ` @${rir(set.rir)}`;
  return text;
}

export const dateTime = (ts) =>
  new Date(ts).toLocaleString(undefined, { weekday: 'short', month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' });
export const dayShort = (ts) => new Date(ts).toLocaleDateString(undefined, { month: 'short', day: 'numeric' });

const withValue = (list, v) => (list.includes(v) ? list : [...list, v].sort((a, b) => a - b));

export const REST_OPTIONS = [0, 15, 30, 45, 60, 75, 90, 105, 120, 150, 180, 210, 240, 300, 360, 420, 480, 600];
export const restOptions = (v) => withValue(REST_OPTIONS, v);

export const INCREMENTS = [0.5, 1, 1.25, 2, 2.5, 5, 10];
export const incrementOptions = (v) => withValue(INCREMENTS, v);

export const REP_RANGES = [[5, 8], [6, 10], [8, 12], [10, 15], [12, 20], [15, 30]];
export function repRangeOptions(low, high) {
  const list = REP_RANGES.map((r) => r.join('-'));
  const key = `${low}-${high}`;
  return list.includes(key) ? list : [...list, key];
}
