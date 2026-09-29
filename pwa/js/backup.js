/** JSON (full backup) and CSV (workout history, one row per set) export/import. */
import { uid } from './util.js';
import { DEFAULT_SETTINGS } from './model.js';
import { MUSCLES } from './catalog.js';

const APP_ID = 'workout-timer';

// ---------- JSON ----------

export function toJSON(state) {
  return JSON.stringify({
    app: APP_ID,
    format: 1,
    exportedAt: new Date().toISOString(),
    settings: state.settings,
    routines: state.routines,
    workouts: state.workouts,
    movements: state.movements,
  }, null, 2);
}

export function fromJSON(text) {
  let data;
  try {
    data = JSON.parse(text);
  } catch {
    throw new Error('This file isn’t valid JSON.');
  }
  if (!data || data.app !== APP_ID || !Array.isArray(data.workouts)) {
    throw new Error('This isn’t a Workout Timer backup file.');
  }
  return {
    settings: normalizeSettings(data.settings),
    routines: (data.routines ?? []).map(normalizeRoutine),
    workouts: data.workouts.map(normalizeWorkout),
    movements: (data.movements ?? []).map(normalizeMovement).filter(Boolean),
  };
}

// ---------- CSV ----------

const COLUMNS = [
  'workout_id', 'workout_name', 'started_at', 'ended_at', 'notes',
  'exercise_index', 'exercise', 'rep_low', 'rep_high', 'target_rir', 'weight_increment', 'rest_planned_sec',
  'set_index', 'warmup', 'weight', 'unit', 'reps', 'rir', 'completed_at', 'set_sec', 'rested_sec',
];

const iso = (ts) => (ts == null ? '' : new Date(ts).toISOString());

function cell(v) {
  const s = v == null ? '' : String(v);
  return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

export function toCSV(workouts, unit) {
  const lines = [COLUMNS.join(',')];
  const finished = workouts.filter((w) => w.endedAt).sort((a, b) => a.startedAt - b.startedAt);
  for (const w of finished) {
    w.exercises.forEach((ex, ei) => {
      ex.sets.forEach((s, si) => {
        lines.push([
          w.id, w.name, iso(w.startedAt), iso(w.endedAt), w.notes,
          ei + 1, ex.name, ex.repLow, ex.repHigh, ex.targetRIR, ex.increment, ex.rest,
          si + 1, s.warmup ? 1 : 0, s.weight, unit, s.reps, s.rir ?? '', iso(s.completedAt),
          s.workSec == null ? '' : Math.round(s.workSec), s.restSec == null ? '' : Math.round(s.restSec),
        ].map(cell).join(','));
      });
    });
  }
  return lines.join('\r\n') + '\r\n';
}

/** RFC 4180 parser: quoted fields, escaped quotes, commas and newlines inside quotes. */
export function parseCSV(text) {
  const rows = [];
  let row = [], field = '', quoted = false;
  const s = text.replace(/^﻿/, '');
  for (let i = 0; i < s.length; i++) {
    const c = s[i];
    if (quoted) {
      if (c === '"' && s[i + 1] === '"') { field += '"'; i++; }
      else if (c === '"') quoted = false;
      else field += c;
    } else if (c === '"') quoted = true;
    else if (c === ',') { row.push(field); field = ''; }
    else if (c === '\n' || c === '\r') {
      if (c === '\r' && s[i + 1] === '\n') i++;
      row.push(field); rows.push(row); row = []; field = '';
    } else field += c;
  }
  if (field !== '' || row.length) { row.push(field); rows.push(row); }
  return rows.filter((r) => r.some((f) => f.trim() !== ''));
}

/** Rebuilds finished workouts from an exported CSV. */
export function fromCSV(text) {
  const rows = parseCSV(text);
  if (rows.length < 2) throw new Error('The CSV file has no rows.');
  const header = rows[0].map((h) => h.trim().toLowerCase());
  for (const need of ['workout_id', 'started_at', 'exercise', 'reps']) {
    if (!header.includes(need)) throw new Error(`The CSV is missing the “${need}” column.`);
  }
  const get = (r, name) => r[header.indexOf(name)] ?? '';
  const num = (v, d = 0) => (v === '' || v == null || !Number.isFinite(Number(v)) ? d : Number(v));
  const time = (v) => { const t = Date.parse(v); return Number.isFinite(t) ? t : null; };

  const workouts = new Map();
  for (const r of rows.slice(1)) {
    const id = get(r, 'workout_id') || `${get(r, 'started_at')}|${get(r, 'workout_name')}`;
    let w = workouts.get(id);
    if (!w) {
      const startedAt = time(get(r, 'started_at'));
      if (startedAt == null) continue;
      w = {
        id, name: get(r, 'workout_name') || 'Workout', startedAt,
        endedAt: time(get(r, 'ended_at')) ?? startedAt, notes: get(r, 'notes'),
        phaseStartedAt: null, restStartedAt: null, restEndsAt: null, exercises: [], _ex: new Map(),
      };
      workouts.set(id, w);
    }
    const exKey = `${get(r, 'exercise_index')}|${get(r, 'exercise')}`;
    let ex = w._ex.get(exKey);
    if (!ex) {
      ex = {
        id: uid(), name: get(r, 'exercise') || 'Exercise',
        repLow: num(get(r, 'rep_low'), 8), repHigh: num(get(r, 'rep_high'), 12),
        targetRIR: num(get(r, 'target_rir'), 2), increment: num(get(r, 'weight_increment'), 2.5),
        rest: num(get(r, 'rest_planned_sec'), 120), sets: [],
      };
      w._ex.set(exKey, ex);
      w.exercises.push(ex);
    }
    const rir = get(r, 'rir');
    ex.sets.push({
      id: uid(), reps: num(get(r, 'reps')), weight: num(get(r, 'weight')), done: true,
      warmup: ['1', 'true', 'yes'].includes(get(r, 'warmup').toLowerCase()),
      rir: rir === '' ? null : num(rir), completedAt: time(get(r, 'completed_at')),
      workSec: get(r, 'set_sec') === '' ? null : num(get(r, 'set_sec')),
      restSec: get(r, 'rested_sec') === '' ? null : num(get(r, 'rested_sec')),
    });
  }
  return [...workouts.values()].map(({ _ex, ...w }) => normalizeWorkout(w));
}

// ---------- normalizers (defend against partial/old files) ----------

const n = (v, d) => (typeof v === 'number' && Number.isFinite(v) ? v : d);
const nOrNull = (v) => (typeof v === 'number' && Number.isFinite(v) ? v : null);
const str = (v, d = '') => (typeof v === 'string' ? v : d);

function normalizeSettings(s) {
  const out = { ...DEFAULT_SETTINGS };
  if (s && typeof s === 'object') {
    if (s.unit === 'kg' || s.unit === 'lb') out.unit = s.unit;
    out.defaultRest = n(s.defaultRest, out.defaultRest);
    if (typeof s.keepAwake === 'boolean') out.keepAwake = s.keepAwake;
    if (typeof s.sound === 'boolean') out.sound = s.sound;
  }
  return out;
}

function normalizeSet(s) {
  return {
    id: str(s?.id) || uid(), reps: n(s?.reps, 0), weight: n(s?.weight, 0), done: !!s?.done,
    warmup: !!s?.warmup, rir: nOrNull(s?.rir), completedAt: nOrNull(s?.completedAt),
    workSec: nOrNull(s?.workSec), restSec: nOrNull(s?.restSec),
  };
}

function normalizeWorkout(w) {
  const startedAt = n(w?.startedAt, Date.now());
  return {
    id: str(w?.id) || uid(), name: str(w?.name, 'Workout'), startedAt,
    endedAt: nOrNull(w?.endedAt), notes: str(w?.notes),
    phaseStartedAt: nOrNull(w?.phaseStartedAt), restStartedAt: nOrNull(w?.restStartedAt),
    restEndsAt: nOrNull(w?.restEndsAt),
    exercises: (Array.isArray(w?.exercises) ? w.exercises : []).map((e) => ({
      id: str(e?.id) || uid(), name: str(e?.name, 'Exercise'), rest: n(e?.rest, 120),
      repLow: n(e?.repLow, 8), repHigh: n(e?.repHigh, 12), targetRIR: n(e?.targetRIR, 2),
      increment: n(e?.increment, 2.5),
      sets: (Array.isArray(e?.sets) ? e.sets : []).map(normalizeSet),
    })),
  };
}

function normalizeRoutine(r) {
  return {
    id: str(r?.id) || uid(), name: str(r?.name, 'Routine'), createdAt: n(r?.createdAt, Date.now()),
    exercises: (Array.isArray(r?.exercises) ? r.exercises : []).map((e) => ({
      id: str(e?.id) || uid(), name: str(e?.name, 'Exercise'), sets: n(e?.sets, 3),
      repLow: n(e?.repLow, 8), repHigh: n(e?.repHigh, 12), targetRIR: n(e?.targetRIR, 2),
      increment: n(e?.increment, 2.5), startWeight: n(e?.startWeight, 0), rest: n(e?.rest, 120),
    })),
  };
}

function normalizeMovement(m) {
  const name = str(m?.name).trim();
  if (!name || !MUSCLES[m?.primary]) return null;
  return {
    key: name.toLowerCase(), name, primary: m.primary,
    secondary: (Array.isArray(m.secondary) ? m.secondary : []).filter((k) => MUSCLES[k] && k !== m.primary),
    compound: !!m.compound,
  };
}

// ---------- files ----------

/** iOS home-screen apps: the share sheet ("Save to Files") is the reliable way out. */
export async function saveFile(filename, text, type) {
  const blob = new Blob([text], { type });
  const file = new File([blob], filename, { type });
  if (navigator.canShare?.({ files: [file] })) {
    try {
      await navigator.share({ files: [file], title: filename });
      return 'shared';
    } catch (err) {
      if (err?.name === 'AbortError') return 'cancelled';
      // Fall through to a download link.
    }
  }
  const url = URL.createObjectURL(blob);
  const a = Object.assign(document.createElement('a'), { href: url, download: filename });
  document.body.append(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 10_000);
  return 'downloaded';
}

export const stamp = () => new Date().toISOString().slice(0, 10);
