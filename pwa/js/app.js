import { h, icon, openSheet, sheetHeader, confirmSheet, actionSheet, toast } from './ui.js';
import * as F from './format.js';
import * as T from './timer.js';
import { MUSCLES, GROUPS, MOVEMENTS, PPL, musclesIn, makeResolver, defaultsFor, builtInMovement } from './catalog.js';
import { buildHistory, advice, fillSets } from './progression.js';
import {
  newWorkout, newExercise, exerciseFromRoutine, newSet, newRoutine, newRoutineExercise,
  duration, workingSets, isHardSet, hardSetCount, totalReps, totalVolume, totalWork, totalRest,
} from './model.js';
import {
  state, loadAll, activeWorkout, saveWorkout, saveWorkoutSoon, flushPending, deleteWorkout,
  saveRoutine, deleteRoutine, saveMovement, saveSettings, replaceEverything, mergeIn, setErrorHandler,
} from './store.js';
import { toJSON, fromJSON, toCSV, fromCSV, saveFile, stamp } from './backup.js';
import { parseNumber, weekRange } from './util.js';

const BUILD = '__BUILD__';
const root = document.getElementById('app');

// ---------------------------------------------------------------------------
// Navigation: four tabs, each with its own stack of pushed screens.
// ---------------------------------------------------------------------------

const TABS = [
  { id: 'workout', label: 'Workout', icon: 'stopwatch' },
  { id: 'routines', label: 'Routines', icon: 'list' },
  { id: 'volume', label: 'Volume', icon: 'chart' },
  { id: 'history', label: 'History', icon: 'history' },
];

const ui = {
  tab: 'workout',
  stacks: { workout: [], routines: [], volume: [], history: [] },
  weekOffset: 0,
};

function render({ resetScroll = false } = {}) {
  const y = window.scrollY;
  root.replaceChildren(buildScreen(), tabBar());
  window.scrollTo(0, resetScroll ? 0 : y);
  tick(true);
  syncWakeLock();
}

function buildScreen() {
  const route = ui.stacks[ui.tab].at(-1);
  switch (ui.tab) {
    case 'workout': {
      const w = activeWorkout();
      return w ? screenActive(w) : screenStart();
    }
    case 'routines': {
      const r = route && state.routines.find((x) => x.id === route.id);
      return r ? screenRoutineEditor(r) : screenRoutines();
    }
    case 'volume':
      return screenVolume();
    case 'history': {
      const w = route && state.workouts.find((x) => x.id === route.id);
      return w ? screenWorkoutDetail(w) : screenHistory();
    }
  }
}

function push(route) {
  ui.stacks[ui.tab].push(route);
  render({ resetScroll: true });
}

function pop() {
  ui.stacks[ui.tab].pop();
  render({ resetScroll: true });
}

function goTab(id) {
  if (ui.tab === id) ui.stacks[id] = [];
  ui.tab = id;
  render({ resetScroll: true });
}

function tabBar() {
  return h('nav', { class: 'tabbar', 'aria-label': 'Sections' },
    TABS.map((t) => h('button', {
      class: 'tab' + (ui.tab === t.id ? ' active' : ''),
      'aria-current': ui.tab === t.id ? 'page' : null,
      onclick: () => goTab(t.id),
    }, icon(t.icon), h('span', {}, t.label))));
}

// ---------------------------------------------------------------------------
// Shared building blocks
// ---------------------------------------------------------------------------

function header({ title, back, trailing, large = true }) {
  return [
    h('header', { class: 'topbar' },
      h('div', { class: 'topbar-side' },
        back ? h('button', { class: 'nav-btn back', onclick: pop }, icon('chevronLeft'), back) : null),
      large ? null : h('h1', { class: 'topbar-title' }, title),
      h('div', { class: 'topbar-side end' }, trailing ?? null)),
    large ? h('h1', { class: 'large-title' }, title) : null,
  ];
}

const sectionTitle = (text) => h('h2', { class: 'section-title' }, text);
const footer = (text) => h('p', { class: 'section-footer' }, text);
const card = (...children) => h('div', { class: 'card' }, ...children);

function rowButton(content, onclick, cls = '') {
  return h('button', { class: `row row-btn ${cls}`, onclick }, content);
}

function valueRow(label, value) {
  return h('div', { class: 'row' }, h('span', { class: 'grow' }, label), h('span', { class: 'muted mono' }, value));
}

/** options: [[value, label], ...] */
function selectRow(label, options, value, onChange) {
  const id = `sel-${Math.random().toString(36).slice(2)}`;
  return h('div', { class: 'row' },
    h('label', { class: 'grow', for: id }, label),
    h('select', { id, class: 'select', value: String(value), onchange: (e) => onChange(e.target.value) },
      options.map(([v, text]) => h('option', { value: String(v) }, text))));
}

function stepperRow(label, value, min, max, onChange) {
  return h('div', { class: 'row' },
    h('span', { class: 'grow' }, label),
    h('div', { class: 'stepper', role: 'group', 'aria-label': label },
      h('button', { 'aria-label': `Decrease ${label}`, disabled: value <= min, onclick: () => onChange(value - 1) }, '−'),
      h('span', { class: 'stepper-value mono', 'aria-live': 'polite' }, value),
      h('button', { 'aria-label': `Increase ${label}`, disabled: value >= max, onclick: () => onChange(value + 1) }, '+')));
}

function toggleRow(label, checked, onChange) {
  const id = `tg-${Math.random().toString(36).slice(2)}`;
  return h('div', { class: 'row' },
    h('label', { class: 'grow', for: id }, label),
    h('input', { id, type: 'checkbox', class: 'switch', role: 'switch', checked, onchange: (e) => onChange(e.target.checked) }));
}

function numInput(value, onValue, { decimal, label }) {
  return h('input', {
    class: 'num', type: 'text', inputmode: decimal ? 'decimal' : 'numeric', autocomplete: 'off',
    enterkeyhint: 'done', placeholder: '0', value: value ? String(value) : '', 'aria-label': label,
    onfocus: (e) => setTimeout(() => e.target.setSelectionRange(0, e.target.value.length), 0),
    oninput: (e) => {
      const v = parseNumber(e.target.value);
      e.target.classList.toggle('invalid', v == null);
      if (v != null) onValue(v);
    },
    onkeydown: (e) => { if (e.key === 'Enter') e.target.blur(); },
  });
}

function emptyState({ iconName, title, text, actions = [] }) {
  return h('div', { class: 'empty' },
    icon(iconName, 'icon empty-icon'),
    h('h2', {}, title),
    h('p', {}, text),
    actions.map(([label, fn, primary]) => h('button', { class: primary ? 'btn-primary' : 'btn-secondary', onclick: fn }, label)));
}

const unit = () => state.settings.unit;
const resolver = () => makeResolver(state.movements);
const sortedRoutines = () => [...state.routines].sort((a, b) => a.createdAt - b.createdAt);

function routineSummary(r) {
  const sets = r.exercises.reduce((n, e) => n + e.sets, 0);
  return `${r.exercises.length} ${r.exercises.length === 1 ? 'exercise' : 'exercises'} · ${sets} sets`;
}

// ---------------------------------------------------------------------------
// Workout tab: start screen
// ---------------------------------------------------------------------------

const isStandalone = () => window.matchMedia('(display-mode: standalone)').matches || navigator.standalone === true;
const isIOS = () => /iPhone|iPad|iPod/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);

function installHint() {
  if (isStandalone() || !isIOS() || sessionStorage.getItem('hideInstallHint')) return null;
  const el = h('div', { class: 'card hint-card' },
    h('div', { class: 'row' },
      h('div', { class: 'grow' },
        h('div', { class: 'row-title' }, 'Install on your iPhone'),
        h('div', { class: 'row-sub' }, 'Tap ', icon('share', 'icon inline'), ' Share, then “Add to Home Screen”. It then works offline, full screen.')),
      h('button', { class: 'nav-btn', 'aria-label': 'Dismiss', onclick: () => { sessionStorage.setItem('hideInstallHint', '1'); el.remove(); } }, '✕')));
  return el;
}

function screenStart() {
  const routines = sortedRoutines();
  return h('div', { class: 'screen' },
    header({
      title: 'Workout',
      trailing: h('button', { class: 'icon-btn', 'aria-label': 'Settings', onclick: openSettings }, icon('settings')),
    }),
    installHint(),
    h('button', { class: 'btn-primary big', onclick: () => startWorkout(null) }, icon('play'), 'Start Empty Workout'),
    sectionTitle('Start from a routine'),
    card(routines.length
      ? routines.map((r) => rowButton([
        h('div', { class: 'grow' }, h('div', { class: 'row-title' }, r.name), h('div', { class: 'row-sub' }, routineSummary(r))),
        h('span', { class: 'accent' }, icon('playCircle', 'icon lg')),
      ], () => startWorkout(r)))
      : [
        h('div', { class: 'row muted' }, 'Plan movements, rep ranges, effort and rest in the Routines tab, then start them here.'),
        rowButton([icon('stack'), 'Add Push / Pull / Legs routines'], addPPL, 'accent'),
      ]));
}

function defaultWorkoutName() {
  const hour = new Date().getHours();
  if (hour >= 4 && hour < 12) return 'Morning Workout';
  if (hour >= 12 && hour < 17) return 'Afternoon Workout';
  return 'Evening Workout';
}

function startWorkout(routine) {
  const w = newWorkout(routine ? routine.name : defaultWorkoutName());
  if (routine) {
    const history = buildHistory(state.workouts);
    for (const r of routine.exercises) {
      const ex = exerciseFromRoutine(r);
      w.exercises.push(ex);
      fillSets(ex, r.sets, history.get(r.name.toLowerCase()), r.startWeight);
    }
  }
  state.workouts.push(w);
  saveWorkout(w);
  requestPersistentStorage();
  unlockAudio();
  render({ resetScroll: true });
}

function addPPL() {
  const now = Date.now();
  PPL.forEach(([name, items], i) => {
    const r = newRoutine(name, now + i);
    for (const [exName, sets, repLow, repHigh, targetRIR, rest] of items) {
      r.exercises.push(newRoutineExercise(exName, { repLow, repHigh, targetRIR, rest, increment: 2.5 }, sets));
    }
    state.routines.push(r);
    saveRoutine(r);
  });
  toast('Added Push, Pull and Legs');
  render();
}

// ---------------------------------------------------------------------------
// Workout tab: active workout
// ---------------------------------------------------------------------------

function screenActive(w) {
  const history = buildHistory(state.workouts);
  const all = w.exercises.flatMap((e) => e.sets);
  return h('div', { class: 'screen has-banner' },
    header({
      title: 'Active Workout', large: false,
      trailing: h('button', { class: 'nav-btn bold', onclick: () => confirmFinish(w) }, 'Finish'),
    }),
    card(
      h('div', { class: 'row' }, h('input', {
        class: 'plain-input title-input', value: w.name, placeholder: 'Workout name', 'aria-label': 'Workout name',
        oninput: (e) => { w.name = e.target.value; saveWorkoutSoon(w); },
      })),
      h('div', { class: 'row' }, h('span', { class: 'grow' }, 'Elapsed'),
        h('span', { class: 'muted mono', 'data-tick': 'elapsed' }, F.clock(duration(w)))),
      valueRow('Sets done', `${all.filter((s) => s.done).length} / ${all.length}`)),
    w.exercises.map((ex) => exerciseCard(w, ex, history.get(ex.name.toLowerCase()))),
    card(rowButton([icon('plusCircle'), 'Add Exercise'], () => openPicker((name) => addExerciseToWorkout(w, name)), 'accent')),
    card(
      rowButton([icon('flag'), 'Finish Workout'], () => confirmFinish(w), 'accent bold'),
      rowButton([icon('trash'), 'Discard Workout'], () => confirmDiscard(w), 'destructive')),
    h('div', { id: 'banner', class: 'banner', role: 'timer', 'aria-live': 'off' }));
}

function exerciseCard(w, ex, last) {
  let working = 0;
  const rows = ex.sets.map((set) => {
    if (set.warmup) return setRow(w, ex, set, 'W', null);
    const prev = last?.sets[working] ?? null;
    working += 1;
    return setRow(w, ex, set, String(working), prev);
  });
  return h('section', { class: 'card exercise', 'aria-label': ex.name },
    h('div', { class: 'ex-head' },
      h('h3', {}, ex.name),
      h('button', { class: 'icon-btn accent', 'aria-label': `${ex.name} options`, onclick: () => openExerciseOptions(w, ex) }, icon('ellipsis'))),
    coachRow(ex, last),
    h('div', { class: 'set-grid head', 'aria-hidden': 'true' },
      h('span', {}, 'Set'), h('span', {}, 'Previous'), h('span', { class: 'c' }, unit()), h('span', { class: 'c' }, 'Reps'), h('span', { class: 'c' }, '✓')),
    rows,
    rowButton([icon('plus'), 'Add Set'], () => {
      const lastSet = ex.sets.at(-1);
      ex.sets.push(newSet(lastSet?.reps ?? ex.repLow, lastSet?.weight ?? 0));
      saveWorkout(w);
      render();
    }, 'accent small'));
}

function adviceText(ex, adv) {
  const u = unit();
  switch (adv.kind) {
    case 'increase':
      return { icon: 'up', color: 'green', title: `Add weight → ${F.weight(adv.weight)} ${u}`,
        detail: `You hit ${ex.repHigh}+ reps on every set. Start at ${ex.repLow} reps and build back up.` };
    case 'reduce':
      return { icon: 'down', color: 'orange', title: `Drop to ${F.weight(adv.weight)} ${u}`,
        detail: `Most sets fell below ${ex.repLow} reps last time. Lighten up and own the range.` };
    case 'harder':
      return { icon: 'bolt', color: 'purple', title: 'Push closer to failure',
        detail: `Last session averaged ${F.sets(adv.average)} RIR vs a target of ${ex.targetRIR}. Add reps or weight.` };
    case 'beat':
      return { icon: 'right', color: 'blue', title: 'Beat last time',
        detail: `Same weight, aim for +1 rep per set until you hit ${ex.repHigh}.` };
    default:
      return { icon: 'sparkles', color: 'muted', title: 'New movement',
        detail: `Pick a weight you can lift for ${ex.repLow}–${ex.repHigh} reps with about ${ex.targetRIR} left in the tank.` };
  }
}

function coachRow(ex, last) {
  const t = adviceText(ex, advice(ex, last));
  return h('div', { class: 'coach' },
    h('div', { class: 'coach-meta' }, `${ex.repLow}–${ex.repHigh} reps · RIR ${ex.targetRIR} · Rest ${F.rest(ex.rest)}`),
    h('div', { class: 'coach-advice' },
      h('span', { class: `advice-icon ${t.color}` }, icon(t.icon)),
      h('div', {}, h('div', { class: 'advice-title' }, t.title), h('div', { class: 'advice-detail' }, t.detail))),
    last ? h('div', { class: 'coach-last' }, `Last: ${F.dayShort(last.date)} · ${last.sets.map(F.previous).join(', ')}`) : null);
}

function timingText(set) {
  const parts = [];
  if (set.workSec != null && set.workSec >= 1) parts.push(`Set ${F.clock(set.workSec)}`);
  if (set.restSec != null) parts.push(`Rested ${F.clock(set.restSec)}`);
  return parts.join(' · ');
}

function setRow(w, ex, set, label, prev) {
  const timing = set.done ? timingText(set) : '';
  return h('div', { class: 'set-row' + (set.done ? ' done' : '') },
    h('div', { class: 'set-grid' },
      h('button', {
        class: 'set-label' + (set.warmup ? ' warm' : ''),
        'aria-label': set.warmup ? 'Warm-up set options' : `Set ${label} options`,
        onclick: () => openSetActions(w, ex, set, label),
      }, label),
      h('button', {
        class: 'prev', disabled: !prev || set.done, 'aria-label': prev ? `Previous: ${F.previous(prev)}. Tap to copy.` : 'No previous set',
        onclick: () => { set.weight = prev.weight; set.reps = prev.reps; saveWorkout(w); render(); },
      }, prev ? F.previous(prev) : '—'),
      numInput(set.weight, (v) => { set.weight = v; saveWorkoutSoon(w); }, { decimal: true, label: `Set ${label} weight (${unit()})` }),
      numInput(set.reps, (v) => { set.reps = Math.round(v); saveWorkoutSoon(w); }, { decimal: false, label: `Set ${label} reps` }),
      h('button', {
        class: 'check' + (set.done ? ' on' : ''),
        'aria-label': set.done ? `Mark set ${label} not done` : `Complete set ${label}`,
        'aria-pressed': String(set.done),
        onclick: () => toggleSet(w, ex, set),
      }, icon(set.done ? 'checkFill' : 'circle', 'icon check-icon'))),
    set.done && !set.warmup ? rirRow(w, ex, set) : null,
    timing ? h('div', { class: 'timing mono' }, timing) : null);
}

function rirRow(w, ex, set) {
  return h('div', { class: 'rir-row', role: 'group', 'aria-label': 'Reps in reserve' },
    h('span', { class: 'rir-label' }, 'RIR'),
    [0, 1, 2, 3, 4].map((v) => {
      const selected = set.rir === v;
      const tone = v > ex.targetRIR + 1 ? 'easy' : 'good';
      return h('button', {
        class: 'chip' + (selected ? ` selected ${tone}` : ''),
        'aria-pressed': String(selected),
        'aria-label': `${F.rir(v)} reps in reserve`,
        onclick: () => { set.rir = selected ? null : v; saveWorkout(w); render(); },
      }, F.rir(v));
    }),
    set.rir == null ? h('span', { class: 'hint' }, 'Reps left?')
      : set.rir >= 4 ? h('span', { class: 'hint warn' }, icon('alert', 'icon inline'), 'Too easy') : null);
}

function toggleSet(w, ex, set) {
  if (set.done) {
    T.uncomplete(set);
  } else {
    document.activeElement?.blur?.();
    unlockAudio();
    T.complete(w, ex, set);
    navigator.vibrate?.(15);
  }
  saveWorkout(w);
  render();
}

function openSetActions(w, ex, set, label) {
  actionSheet(set.warmup ? 'Warm-up set' : `Set ${label}`, [
    {
      label: set.warmup ? 'Make Working Set' : 'Mark as Warm-up',
      onClick: () => { set.warmup = !set.warmup; if (set.warmup) set.rir = null; saveWorkout(w); render(); },
    },
    {
      label: 'Delete Set', destructive: true,
      onClick: () => { ex.sets = ex.sets.filter((s) => s !== set); saveWorkout(w); render(); },
    },
  ]);
}

function openExerciseOptions(w, ex) {
  const u = unit();
  openSheet((close) => h('div', {},
    sheetHeader(ex.name, close),
    card(
      selectRow('Rest timer', F.restOptions(ex.rest).map((v) => [v, F.rest(v)]), ex.rest, (v) => { ex.rest = Number(v); }),
      selectRow('Rep range', F.repRangeOptions(ex.repLow, ex.repHigh).map((k) => [k, `${k.replace('-', '–')} reps`]),
        `${ex.repLow}-${ex.repHigh}`, (v) => { [ex.repLow, ex.repHigh] = v.split('-').map(Number); }),
      selectRow('Target RIR', [0, 1, 2, 3, 4].map((v) => [v, v === 0 ? '0 (failure)' : String(v)]), ex.targetRIR, (v) => { ex.targetRIR = Number(v); }),
      selectRow('Weight jump', F.incrementOptions(ex.increment).map((v) => [v, `+${F.weight(v)} ${u}`]), ex.increment, (v) => { ex.increment = Number(v); })),
    footer('Rep range, target RIR and weight jump drive the progression advice. Rest is the countdown after each working set.'),
    card(rowButton('Remove Exercise', async () => {
      close();
      const ok = await confirmSheet({ title: `Remove ${ex.name}?`, message: 'Its sets in this workout will be deleted.', confirm: 'Remove', destructive: true });
      if (!ok) return;
      w.exercises = w.exercises.filter((e) => e !== ex);
      saveWorkout(w);
      render();
    }, 'destructive'))),
  { onClose: () => { saveWorkout(w); render(); }, label: `${ex.name} options` });
}

function addExerciseToWorkout(w, name) {
  const ex = newExercise(name, defaultsFor(resolver().info(name), state.settings.defaultRest));
  w.exercises.push(ex);
  const last = buildHistory(state.workouts).get(name.toLowerCase());
  fillSets(ex, last?.sets.length ?? 3, last, 0);
  saveWorkout(w);
  render();
  requestAnimationFrame(() => document.querySelector('.exercise:last-of-type')?.scrollIntoView({ behavior: 'smooth', block: 'start' }));
}

async function confirmFinish(w) {
  const ok = await confirmSheet({ title: 'Finish this workout?', message: 'Sets you haven’t checked off will be removed.', confirm: 'Finish Workout' });
  if (!ok) return;
  T.finish(w);
  saveWorkout(w);
  ui.stacks.workout = [];
  ui.tab = 'history';
  ui.stacks.history = [{ name: 'workout', id: w.id }];
  render({ resetScroll: true });
  toast('Workout saved');
}

async function confirmDiscard(w) {
  const ok = await confirmSheet({ title: 'Discard this workout?', message: 'Nothing from this session will be saved.', confirm: 'Discard Workout', destructive: true });
  if (!ok) return;
  deleteWorkout(w);
  render({ resetScroll: true });
}

// ---------------------------------------------------------------------------
// Timer banner + tick loop. Display only: all values are derived from Date.now().
// ---------------------------------------------------------------------------

let alertedFor = null;

function renderBanner(el, w, now) {
  const resting = T.isResting(w, now);
  el.dataset.mode = resting ? 'rest' : 'work';
  el.dataset.key = String(w.restEndsAt);
  const next = T.nextUpText(w, unit());
  if (resting) {
    el.replaceChildren(
      h('div', { class: 'banner-top' },
        h('span', { class: 'banner-label rest' }, icon('pause'), 'Rest'),
        h('span', { class: 'big-time', 'data-tick': 'rest' })),
      h('div', { class: 'progress', role: 'progressbar', 'aria-label': 'Rest progress' }, h('div', { 'data-tick': 'rest-progress' })),
      h('div', { class: 'banner-actions' },
        h('button', { class: 'pill', onclick: () => { T.adjustRest(w, -15); saveWorkout(w); tick(true); } }, '−15s'),
        h('button', { class: 'pill', onclick: () => { T.adjustRest(w, 15); saveWorkout(w); tick(true); } }, '+15s'),
        h('span', { class: 'grow' }),
        h('button', { class: 'pill strong', onclick: () => { T.skipRest(w); saveWorkout(w); tick(true); } }, 'Skip Rest')),
      next ? h('div', { class: 'banner-next' }, `Next: ${next}`) : null);
  } else {
    el.replaceChildren(h('div', { class: 'banner-top' },
      h('div', { class: 'grow min0' },
        h('div', { class: 'banner-label work' }, icon('dumbbell'), w.restEndsAt != null ? 'Rest over — lift!' : 'Set timer'),
        h('div', { class: 'banner-next' }, next ?? 'Add an exercise to get started')),
      h('span', { class: 'big-time', 'data-tick': 'work' })));
  }
}

function setText(sel, text) {
  const el = document.querySelector(sel);
  if (el && el.textContent !== text) el.textContent = text;
}

function tick(force = false) {
  const w = activeWorkout();
  const banner = document.getElementById('banner');
  if (!w || !banner) return;
  const now = Date.now();
  const mode = T.isResting(w, now) ? 'rest' : 'work';
  if (force || banner.dataset.mode !== mode || banner.dataset.key !== String(w.restEndsAt)) renderBanner(banner, w, now);

  setText('[data-tick="elapsed"]', F.clock(duration(w, now)));
  if (mode === 'rest') {
    const remaining = T.restRemaining(w, now);
    const total = T.plannedRest(w);
    setText('[data-tick="rest"]', F.clock(Math.ceil(remaining)));
    const bar = document.querySelector('[data-tick="rest-progress"]');
    if (bar) bar.style.width = `${total > 0 ? Math.min(100, ((total - remaining) / total) * 100) : 100}%`;
  } else {
    const start = T.workPhaseStart(w, now) ?? now;
    setText('[data-tick="work"]', F.clock((now - start) / 1000));
  }

  // Rest just ran out while the app is on screen: beep + flash (once per rest).
  if (w.restEndsAt != null && now >= w.restEndsAt && alertedFor !== w.restEndsAt) {
    alertedFor = w.restEndsAt;
    if (now - w.restEndsAt < 5000 && document.visibilityState === 'visible') {
      beep();
      banner.classList.remove('flash');
      void banner.offsetWidth;
      banner.classList.add('flash');
    }
  }
}

setInterval(tick, 250);

// ---------------------------------------------------------------------------
// Sound (Web Audio; needs one user tap to unlock on iOS) and wake lock
// ---------------------------------------------------------------------------

let audioCtx = null;

function unlockAudio() {
  const AC = window.AudioContext || window.webkitAudioContext;
  if (!AC) return;
  audioCtx ??= new AC();
  if (audioCtx.state !== 'running') audioCtx.resume().catch(() => {});
}

function beep() {
  navigator.vibrate?.([200, 100, 200]);
  if (!state.settings.sound || !audioCtx) return;
  if (audioCtx.state !== 'running') audioCtx.resume().catch(() => {});
  const t0 = audioCtx.currentTime + 0.02;
  [0, 0.22, 0.44].forEach((offset, i) => {
    const osc = audioCtx.createOscillator();
    const gain = audioCtx.createGain();
    osc.type = 'sine';
    osc.frequency.value = i === 2 ? 1320 : 880;
    gain.gain.setValueAtTime(0.0001, t0 + offset);
    gain.gain.exponentialRampToValueAtTime(0.5, t0 + offset + 0.01);
    gain.gain.exponentialRampToValueAtTime(0.0001, t0 + offset + 0.18);
    osc.connect(gain).connect(audioCtx.destination);
    osc.start(t0 + offset);
    osc.stop(t0 + offset + 0.2);
  });
}

document.addEventListener('pointerdown', unlockAudio, { passive: true });

const wakeLockSupported = 'wakeLock' in navigator;
let wakeLock = null;
let wakeLockPending = false;

async function syncWakeLock() {
  if (!wakeLockSupported) return;
  const want = !!activeWorkout() && state.settings.keepAwake && document.visibilityState === 'visible';
  if (want && !wakeLock && !wakeLockPending) {
    wakeLockPending = true;
    try {
      wakeLock = await navigator.wakeLock.request('screen');
      wakeLock.addEventListener('release', () => { wakeLock = null; });
    } catch {
      // Denied (e.g. low power mode) — nothing to do.
    } finally {
      wakeLockPending = false;
    }
  } else if (!want && wakeLock) {
    const lock = wakeLock;
    wakeLock = null;
    lock.release().catch(() => {});
  }
}

document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'hidden') {
    flushPending();
  } else {
    tick(true);
  }
  syncWakeLock();
});
window.addEventListener('pagehide', flushPending);

async function requestPersistentStorage() {
  try {
    if (navigator.storage?.persist && !(await navigator.storage.persisted())) await navigator.storage.persist();
  } catch {
    // Not supported.
  }
}

// ---------------------------------------------------------------------------
// Exercise picker + muscle tagging
// ---------------------------------------------------------------------------

function allMovementNames() {
  const seen = new Set();
  const names = [];
  const sources = [
    ...state.movements.map((m) => m.name),
    ...state.workouts.flatMap((w) => w.exercises.map((e) => e.name)),
    ...state.routines.flatMap((r) => r.exercises.map((e) => e.name)),
    ...MOVEMENTS.map((m) => m.name),
  ];
  for (const name of sources) {
    const key = name.trim().toLowerCase();
    if (key && !seen.has(key)) { seen.add(key); names.push(name.trim()); }
  }
  return names.sort((a, b) => a.localeCompare(b, undefined, { sensitivity: 'base' }));
}

function muscleSummary(info) {
  if (!info) return 'Untagged — won’t count toward volume';
  return [info.primary, ...info.secondary].map((k) => MUSCLES[k].name).join(' · ');
}

function openPicker(onPick) {
  openSheet((close) => {
    const names = allMovementNames();
    const resolve = resolver();
    const addArea = h('div', {});
    const list = h('div', { class: 'card' });
    const search = h('input', {
      class: 'search', type: 'search', placeholder: 'Search movement or muscle', 'aria-label': 'Search movements',
      autocomplete: 'off', autocapitalize: 'words', enterkeyhint: 'search', oninput: refresh,
    });

    function refresh() {
      const q = search.value.trim();
      const ql = q.toLowerCase();
      const matches = q
        ? names.filter((n) => n.toLowerCase().includes(ql) || muscleSummary(resolve.info(n)).toLowerCase().includes(ql))
        : names;
      const canAdd = q && !names.some((n) => n.toLowerCase() === ql);
      addArea.replaceChildren(canAdd
        ? card(rowButton([icon('plusCircle'), `Add “${q}”`], () => { close(); openTagSheet(q, () => onPick(q)); }, 'accent'))
        : '');
      list.replaceChildren(...(matches.length
        ? matches.map((n) => rowButton(h('div', { class: 'grow' },
          h('div', { class: 'row-title normal' }, n),
          h('div', { class: 'row-sub' }, muscleSummary(resolve.info(n)))), () => { close(); onPick(n); }))
        : [h('div', { class: 'row muted' }, canAdd ? 'No matches — add it as a new movement above.' : 'No matches')]));
    }

    refresh();
    return h('div', {}, sheetHeader('Add Exercise', close), search, addArea, list);
  }, { tall: true, label: 'Add exercise' });
}

function openTagSheet(name, onSaved) {
  const existing = state.movements.find((m) => m.key === name.toLowerCase()) ?? builtInMovement(name);
  let primary = existing?.primary ?? 'chest';
  let compound = existing?.compound ?? false;
  const secondary = new Set(existing?.secondary ?? []);

  openSheet((close) => {
    const secList = h('div', { class: 'card' });
    const drawSecondary = () => secList.replaceChildren(...Object.keys(MUSCLES).filter((k) => k !== primary).map((k) =>
      h('button', {
        class: 'row row-btn', 'aria-pressed': String(secondary.has(k)),
        onclick: () => { if (secondary.has(k)) secondary.delete(k); else secondary.add(k); drawSecondary(); },
      }, h('span', { class: 'grow normal' }, MUSCLES[k].name), secondary.has(k) ? h('span', { class: 'accent' }, icon('check')) : null)));
    drawSecondary();

    const save = () => {
      saveMovement({ key: name.toLowerCase(), name, primary, secondary: [...secondary].filter((k) => k !== primary), compound });
      close();
      onSaved?.();
      render();
    };

    return h('div', {},
      sheetHeader(name, close, h('button', { class: 'nav-btn bold', onclick: save }, 'Save')),
      card(
        h('div', { class: 'row' },
          h('label', { class: 'grow', for: 'primary-muscle' }, 'Main muscle'),
          h('select', {
            id: 'primary-muscle', class: 'select', value: primary,
            onchange: (e) => { primary = e.target.value; secondary.delete(primary); drawSecondary(); },
          }, GROUPS.map((g) => h('optgroup', { label: g }, musclesIn(g).map((k) => h('option', { value: k }, MUSCLES[k].name)))))),
        toggleRow('Compound (multi-joint)', compound, (v) => { compound = v; })),
      footer('Compound movements default to 6–10 reps and longer rest. Isolation movements default to 10–15 reps.'),
      sectionTitle('Also works'),
      secList,
      footer('Each set counts as 1 set for the main muscle and ½ set for these.'));
  }, { tall: true, label: `Tag ${name}` });
}

// ---------------------------------------------------------------------------
// Routines tab
// ---------------------------------------------------------------------------

function newRoutineFlow() {
  const r = newRoutine('New Routine');
  state.routines.push(r);
  saveRoutine(r);
  push({ name: 'routine', id: r.id });
}

function screenRoutines() {
  const routines = sortedRoutines();
  return h('div', { class: 'screen' },
    header({
      title: 'Routines',
      trailing: h('button', {
        class: 'icon-btn', 'aria-label': 'Add routine',
        onclick: () => actionSheet('Add Routine', [
          { label: 'New Routine', onClick: newRoutineFlow },
          { label: 'Add Push / Pull / Legs', onClick: addPPL },
        ]),
      }, icon('plus')),
    }),
    routines.length
      ? card(routines.map((r) => rowButton([
        h('div', { class: 'grow' }, h('div', { class: 'row-title' }, r.name || 'Untitled'), h('div', { class: 'row-sub' }, routineSummary(r))),
        icon('chevronRight', 'icon chevron'),
      ], () => push({ name: 'routine', id: r.id }))))
      : emptyState({
        iconName: 'list', title: 'No Routines',
        text: 'Plan a workout with movements, rep ranges, effort and rest times.',
        actions: [['Add Push / Pull / Legs', addPPL, true], ['Create Empty Routine', newRoutineFlow]],
      }));
}

function screenRoutineEditor(r) {
  const u = unit();
  const change = (fn) => (v) => { fn(v); saveRoutine(r); render(); };
  return h('div', { class: 'screen' },
    header({ title: r.name || 'Routine', back: 'Routines', large: false }),
    sectionTitle('Routine name'),
    card(h('div', { class: 'row' }, h('input', {
      class: 'plain-input', value: r.name, placeholder: 'Name', 'aria-label': 'Routine name',
      oninput: (e) => { r.name = e.target.value; saveRoutine(r); },
    }))),
    r.exercises.map((ex, i) => [
      h('div', { class: 'section-title with-actions' },
        h('span', {}, ex.name),
        h('span', { class: 'reorder' },
          h('button', { class: 'nav-btn', 'aria-label': `Move ${ex.name} up`, disabled: i === 0,
            onclick: () => { r.exercises.splice(i - 1, 0, r.exercises.splice(i, 1)[0]); saveRoutine(r); render(); } }, '↑'),
          h('button', { class: 'nav-btn', 'aria-label': `Move ${ex.name} down`, disabled: i === r.exercises.length - 1,
            onclick: () => { r.exercises.splice(i + 1, 0, r.exercises.splice(i, 1)[0]); saveRoutine(r); render(); } }, '↓'))),
      card(
        stepperRow('Sets', ex.sets, 1, 20, change((v) => { ex.sets = v; })),
        stepperRow('Rep range low', ex.repLow, 1, ex.repHigh, change((v) => { ex.repLow = v; })),
        stepperRow('Rep range high', ex.repHigh, ex.repLow, 50, change((v) => { ex.repHigh = v; })),
        selectRow('Target RIR', [0, 1, 2, 3, 4].map((v) => [v, v === 0 ? '0 (failure)' : String(v)]), ex.targetRIR, change((v) => { ex.targetRIR = Number(v); })),
        selectRow('Weight jump', F.incrementOptions(ex.increment).map((v) => [v, `+${F.weight(v)} ${u}`]), ex.increment, change((v) => { ex.increment = Number(v); })),
        h('div', { class: 'row' },
          h('span', { class: 'grow' }, `Starting weight (${u})`),
          numInput(ex.startWeight, (v) => { ex.startWeight = v; saveRoutine(r); }, { decimal: true, label: `${ex.name} starting weight` })),
        selectRow('Rest timer', F.restOptions(ex.rest).map((v) => [v, F.rest(v)]), ex.rest, change((v) => { ex.rest = Number(v); })),
        rowButton('Remove Exercise', () => { r.exercises.splice(i, 1); saveRoutine(r); render(); }, 'destructive')),
    ]),
    card(rowButton([icon('plusCircle'), 'Add Exercise'], () => openPicker((name) => {
      r.exercises.push(newRoutineExercise(name, defaultsFor(resolver().info(name), state.settings.defaultRest)));
      saveRoutine(r);
      render();
    }), 'accent')),
    footer('Starting weight is only used the first time. After that, weights come from your last session and progress automatically.'),
    card(rowButton('Delete Routine', async () => {
      const ok = await confirmSheet({ title: `Delete “${r.name}”?`, message: 'Past workouts are kept.', confirm: 'Delete Routine', destructive: true });
      if (!ok) return;
      deleteRoutine(r);
      pop();
    }, 'destructive')));
}

// ---------------------------------------------------------------------------
// Volume tab
// ---------------------------------------------------------------------------

const TARGET_LOW = 10;
const TARGET_HIGH = 20;

function volumeStatus(sets) {
  if (sets < TARGET_LOW) return { key: 'under', label: 'Under', icon: 'down' };
  if (sets > TARGET_HIGH) return { key: 'high', label: 'High', icon: 'up' };
  return { key: 'on', label: 'On target', icon: 'checkFill' };
}

function tallyVolume(workouts) {
  const resolve = resolver();
  const perMuscle = {};
  const untagged = new Set();
  let hardSets = 0;
  for (const w of workouts) {
    for (const ex of w.exercises) {
      const hard = ex.sets.filter(isHardSet).length;
      if (!hard) continue;
      hardSets += hard;
      const info = resolve.info(ex.name);
      if (!info) { untagged.add(ex.name); continue; }
      perMuscle[info.primary] = (perMuscle[info.primary] ?? 0) + hard;
      for (const m of info.secondary) perMuscle[m] = (perMuscle[m] ?? 0) + hard * 0.5;
    }
  }
  return { perMuscle, untagged, hardSets, sessions: workouts.length };
}

function weekTitle(offset, range) {
  if (offset === 0) return 'This Week';
  if (offset === -1) return 'Last Week';
  return `${F.dayShort(range.start)} – ${F.dayShort(range.end - 1)}`;
}

function meter(sets, statusKey) {
  const scale = Math.max(25, sets);
  const pct = (v) => `${(v / scale) * 100}%`;
  return h('div', { class: 'meter', 'aria-hidden': 'true' },
    statusKey ? h('div', { class: 'meter-band', style: { left: pct(TARGET_LOW), width: `calc(${pct(TARGET_HIGH)} - ${pct(TARGET_LOW)})` } }) : null,
    sets > 0 ? h('div', { class: `meter-fill ${statusKey ?? 'neutral'}`, style: { width: `max(8px, ${pct(sets)})` } }) : null);
}

function screenVolume() {
  const range = weekRange(ui.weekOffset);
  const tally = tallyVolume(state.workouts.filter((w) => w.startedAt >= range.start && w.startedAt < range.end));
  const graded = Object.keys(MUSCLES).filter((k) => MUSCLES[k].target);
  const onTarget = graded.filter((k) => volumeStatus(tally.perMuscle[k] ?? 0).key === 'on').length;

  return h('div', { class: 'screen' },
    header({ title: 'Weekly Volume' }),
    card(
      h('div', { class: 'row week-nav' },
        h('button', { class: 'icon-btn accent', 'aria-label': 'Previous week', onclick: () => { ui.weekOffset -= 1; render(); } }, icon('chevronLeft')),
        h('span', { class: 'grow center bold' }, weekTitle(ui.weekOffset, range)),
        h('button', { class: 'icon-btn accent', 'aria-label': 'Next week', disabled: ui.weekOffset >= 0, onclick: () => { ui.weekOffset += 1; render(); } }, icon('chevronRight'))),
      h('div', { class: 'stats' },
        stat(`${onTarget}/${graded.length}`, 'Muscles on target'),
        stat(String(tally.hardSets), 'Hard sets'),
        stat(String(tally.sessions), 'Workouts'))),
    GROUPS.map((g) => [
      sectionTitle(g),
      card(musclesIn(g).map((k) => {
        const sets = tally.perMuscle[k] ?? 0;
        const status = MUSCLES[k].target ? volumeStatus(sets) : null;
        return h('div', {
          class: 'row muscle-row',
          'aria-label': `${MUSCLES[k].name}: ${F.setCount(sets, 'hard set')}${status ? `, ${status.label}` : ''}`,
          role: 'group',
        },
        h('div', { class: 'muscle-line', 'aria-hidden': 'true' },
          h('span', { class: 'grow' }, MUSCLES[k].name),
          h('span', { class: 'bold mono' }, F.setCount(sets)),
          status
            ? h('span', { class: `status ${status.key}` }, icon(status.icon, 'icon inline'), status.label)
            : h('span', { class: 'status neutral' }, 'Indirect')),
        meter(sets, status?.key));
      })),
    ]),
    tally.untagged.size ? [
      sectionTitle('Untagged movements'),
      card([...tally.untagged].sort().map((name) => rowButton([
        h('span', { class: 'grow normal' }, name), h('span', { class: 'accent small-text' }, 'Tag muscles'),
      ], () => openTagSheet(name)))),
      footer('These sets aren’t counted yet. Tag them so they count toward the right muscles.'),
    ] : null,
    footer('A hard set is a completed working set within 3 reps of failure (RIR 0–3). Warm-ups don’t count; sets with no RIR logged are counted. A movement’s main muscle gets 1 set and the other muscles it works get ½. Most people grow best with about 10–20 hard sets per muscle per week, spread over 2 or more sessions. Weeks start on Monday.'));
}

function stat(value, label) {
  return h('div', { class: 'stat' }, h('div', { class: 'stat-value mono' }, value), h('div', { class: 'stat-label' }, label));
}

// ---------------------------------------------------------------------------
// History tab
// ---------------------------------------------------------------------------

function screenHistory() {
  const finished = state.workouts.filter((w) => w.endedAt).sort((a, b) => b.startedAt - a.startedAt);
  const range = weekRange(0);
  const week = finished.filter((w) => w.startedAt >= range.start && w.startedAt < range.end);
  const u = unit();
  return h('div', { class: 'screen' },
    header({ title: 'History' }),
    finished.length ? [
      sectionTitle('This week'),
      card(h('div', { class: 'stats' },
        stat(String(week.length), 'Workouts'),
        stat(F.clock(week.reduce((n, w) => n + duration(w), 0)), 'Time'),
        stat(String(week.reduce((n, w) => n + hardSetCount(w), 0)), 'Hard sets'))),
      card(finished.map((w) => rowButton([
        h('div', { class: 'grow' },
          h('div', { class: 'row-title' }, w.name),
          h('div', { class: 'row-sub' }, F.dateTime(w.startedAt)),
          h('div', { class: 'row-sub mono' }, [
            F.clock(duration(w)), F.setCount(hardSetCount(w), 'hard set'),
            totalVolume(w) > 0 ? `${F.weight(totalVolume(w))} ${u}` : null,
          ].filter(Boolean).join(' · '))),
        icon('chevronRight', 'icon chevron'),
      ], () => push({ name: 'workout', id: w.id })))),
    ] : emptyState({
      iconName: 'history', title: 'No Workouts Yet',
      text: 'Finished workouts show up here with their times, sets and volume.',
    }));
}

function screenWorkoutDetail(w) {
  const u = unit();
  return h('div', { class: 'screen' },
    header({ title: w.name, back: 'History', large: false }),
    sectionTitle('Summary'),
    card(
      valueRow('Date', F.dateTime(w.startedAt)),
      valueRow('Duration', F.clock(duration(w))),
      valueRow('Working sets', String(workingSets(w).length)),
      valueRow('Hard sets (RIR ≤ 3)', String(hardSetCount(w))),
      valueRow('Reps', String(totalReps(w))),
      totalVolume(w) > 0 ? valueRow('Volume', `${F.weight(totalVolume(w))} ${u}`) : null,
      valueRow('Time in sets', F.clock(totalWork(w))),
      valueRow('Time resting', F.clock(totalRest(w)))),
    w.exercises.map((ex) => {
      let n = 0;
      return [
        sectionTitle(ex.name),
        card(ex.sets.map((s) => {
          const label = s.warmup ? 'W' : String(++n);
          return h('div', { class: 'row detail-set' },
            h('span', { class: 'set-num' + (s.warmup ? ' warm' : '') }, label),
            h('div', { class: 'grow' },
              h('div', {}, F.setSummary(s.reps, s.weight, u)),
              s.rir != null && !s.warmup ? h('div', { class: 'row-sub' }, `RIR ${F.rir(s.rir)}`) : null),
            h('div', { class: 'right muted small-text mono' },
              s.workSec != null && s.workSec >= 1 ? h('div', {}, `Set ${F.clock(s.workSec)}`) : null,
              s.restSec != null ? h('div', {}, `Rest ${F.clock(s.restSec)}`) : null));
        })),
      ];
    }),
    sectionTitle('Notes'),
    card(h('div', { class: 'row' }, h('textarea', {
      class: 'plain-input notes', placeholder: 'How did it feel?', rows: 3, value: w.notes, 'aria-label': 'Notes',
      oninput: (e) => { w.notes = e.target.value; saveWorkoutSoon(w); },
    }))),
    card(
      rowButton([icon('download'), 'Save as Routine'], () => saveAsRoutine(w), 'accent'),
      rowButton([icon('trash'), 'Delete Workout'], async () => {
        const ok = await confirmSheet({ title: 'Delete this workout?', message: 'It will be removed from history and weekly volume.', confirm: 'Delete Workout', destructive: true });
        if (!ok) return;
        deleteWorkout(w);
        pop();
      }, 'destructive')));
}

function saveAsRoutine(w) {
  const r = newRoutine(w.name);
  for (const ex of w.exercises) {
    const sets = ex.sets.filter((s) => !s.warmup);
    const re = newRoutineExercise(ex.name, ex, Math.max(1, sets.length));
    re.startWeight = sets.length ? Math.max(...sets.map((s) => s.weight)) : 0;
    r.exercises.push(re);
  }
  state.routines.push(r);
  saveRoutine(r);
  toast(`Saved “${w.name}” to Routines`);
}

// ---------------------------------------------------------------------------
// Settings, backup & restore
// ---------------------------------------------------------------------------

function openSettings() {
  openSheet((close) => {
    const s = state.settings;
    const storageRow = valueRow('Persistent storage', '…');
    updateStorageRow(storageRow);
    const fileInput = h('input', {
      type: 'file', accept: '.json,.csv,application/json,text/csv,text/plain', class: 'visually-hidden', 'aria-hidden': 'true', tabindex: -1,
      onchange: async (e) => {
        const file = e.target.files?.[0];
        e.target.value = '';
        if (file) { close(); await importFile(file); }
      },
    });
    return h('div', {},
      sheetHeader('Settings', close),
      sectionTitle('Units'),
      card(h('div', { class: 'row' },
        h('span', { class: 'grow' }, 'Weight'),
        h('div', { class: 'segmented', role: 'radiogroup', 'aria-label': 'Weight unit' },
          ['kg', 'lb'].map((u) => h('button', {
            role: 'radio', 'aria-checked': String(s.unit === u), class: s.unit === u ? 'on' : '',
            onclick: (e) => {
              s.unit = u;
              saveSettings();
              e.currentTarget.parentElement.querySelectorAll('button').forEach((b) => {
                const on = b === e.currentTarget;
                b.classList.toggle('on', on);
                b.setAttribute('aria-checked', String(on));
              });
            },
          }, u))))),
      footer('Changing the unit only changes labels — numbers aren’t converted.'),
      sectionTitle('Timer'),
      card(
        selectRow('Default rest', F.restOptions(s.defaultRest).map((v) => [v, F.rest(v)]), s.defaultRest, (v) => { s.defaultRest = Number(v); saveSettings(); }),
        toggleRow('Keep screen awake', s.keepAwake, (v) => { s.keepAwake = v; saveSettings(); syncWakeLock(); }),
        toggleRow('Beep when rest ends', s.sound, (v) => { s.sound = v; saveSettings(); if (v) { unlockAudio(); beep(); } })),
      footer([
        'Built-in movements get hypertrophy rest defaults (about 2½ min for compounds, 90 s for isolation); default rest applies to other movements.',
        wakeLockSupported ? '' : ' Keeping the screen awake isn’t supported on this device.',
        ' The beep only plays while the app is open and can be muted by the silent switch.',
      ].join('')),
      sectionTitle('Backup'),
      card(
        rowButton([icon('upload'), 'Export Full Backup (JSON)'], exportBackupJSON, 'accent'),
        rowButton([icon('upload'), 'Export History (CSV)'], exportHistoryCSV, 'accent'),
        rowButton([icon('download'), 'Import from File…'], () => fileInput.click(), 'accent'),
        fileInput),
      footer('Your data lives only on this device, inside the installed app — deleting the app deletes it. Export a JSON backup regularly and save it to Files or iCloud Drive. CSV has one row per set and opens in Numbers, Excel or Google Sheets.'),
      sectionTitle('Storage'),
      card(storageRow,
        valueRow('Installed to Home Screen', isStandalone() ? 'Yes' : 'No'),
        valueRow('Version', BUILD === '__BUILD__' ? 'dev' : BUILD)));
  }, { tall: true, onClose: () => render(), label: 'Settings' });
}

async function updateStorageRow(row) {
  const value = row.querySelector('.muted');
  try {
    const persisted = await navigator.storage?.persisted?.();
    value.textContent = persisted == null ? 'Unknown' : persisted ? 'Granted' : 'Best effort';
  } catch {
    value.textContent = 'Unknown';
  }
}

async function exportBackupJSON() {
  flushPending();
  const result = await saveFile(`workout-timer-backup-${stamp()}.json`, toJSON(state), 'application/json');
  if (result === 'downloaded') toast('Backup downloaded');
}

async function exportHistoryCSV() {
  flushPending();
  const finished = state.workouts.filter((w) => w.endedAt);
  if (!finished.length) { toast('No finished workouts to export yet'); return; }
  const result = await saveFile(`workout-history-${stamp()}.csv`, toCSV(state.workouts, unit()), 'text/csv');
  if (result === 'downloaded') toast('CSV downloaded');
}

async function importFile(file) {
  let text;
  try {
    text = await file.text();
  } catch {
    toast('Couldn’t read that file.');
    return;
  }
  const looksJSON = file.name.toLowerCase().endsWith('.json') || /^\s*\{/.test(text);
  try {
    if (looksJSON) {
      const data = fromJSON(text);
      const counts = `${data.workouts.length} workouts, ${data.routines.length} routines`;
      actionSheet(`Import backup (${counts})`, [
        {
          label: 'Merge with my data',
          onClick: async () => { await mergeIn(data); afterImport(`Merged ${counts}`); },
        },
        {
          label: 'Replace all my data', destructive: true,
          onClick: async () => {
            const ok = await confirmSheet({ title: 'Replace all data?', message: 'Everything currently in the app, including any workout in progress, will be replaced by this backup.', confirm: 'Replace', destructive: true });
            if (!ok) return;
            await replaceEverything(data);
            afterImport(`Restored ${counts}`);
          },
        },
      ]);
    } else {
      const workouts = fromCSV(text);
      if (!workouts.length) throw new Error('No workouts found in that CSV.');
      const ok = await confirmSheet({
        title: `Import ${workouts.length} workouts?`,
        message: 'They’ll be added to your history. Workouts already in the app with the same ID are updated.',
        confirm: 'Import',
      });
      if (!ok) return;
      await mergeIn({ workouts });
      afterImport(`Imported ${workouts.length} workouts`);
    }
  } catch (err) {
    toast(err.message || 'Import failed.', { duration: 6000 });
  }
}

function afterImport(message) {
  ui.stacks = { workout: [], routines: [], volume: [], history: [] };
  render({ resetScroll: true });
  toast(message);
}

// ---------------------------------------------------------------------------
// Service worker (offline + updates)
// ---------------------------------------------------------------------------

function registerServiceWorker() {
  if (!('serviceWorker' in navigator)) return;
  let reloading = false;
  navigator.serviceWorker.addEventListener('controllerchange', () => {
    if (reloading) return;
    reloading = true;
    flushPending();
    window.location.reload();
  });
  navigator.serviceWorker.register('./sw.js').then((reg) => {
    const offerUpdate = (worker) => toast('A new version is available.', {
      action: 'Update', duration: 0, onAction: () => worker.postMessage({ type: 'SKIP_WAITING' }),
    });
    if (reg.waiting && navigator.serviceWorker.controller) offerUpdate(reg.waiting);
    reg.addEventListener('updatefound', () => {
      const worker = reg.installing;
      worker?.addEventListener('statechange', () => {
        if (worker.state === 'installed' && navigator.serviceWorker.controller) offerUpdate(worker);
      });
    });
    // Check for updates when the app comes back to the foreground.
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'visible') reg.update().catch(() => {});
    });
  }).catch((err) => console.warn('Service worker registration failed', err));
}

// ---------------------------------------------------------------------------
// Boot
// ---------------------------------------------------------------------------

async function boot() {
  setErrorHandler((err) => {
    console.error(err);
    toast(`Couldn’t save: ${err?.message ?? err}`, { duration: 6000 });
  });
  try {
    await loadAll();
  } catch (err) {
    root.replaceChildren(h('div', { class: 'screen' },
      h('h1', { class: 'large-title' }, 'Workout Timer'),
      h('p', {}, 'Your browser blocked local storage (IndexedDB), so the app can’t save anything. In Safari, make sure you’re not in Private Browsing.'),
      h('p', { class: 'muted' }, String(err?.message ?? err))));
    return;
  }
  if (activeWorkout()) {
    const w = activeWorkout();
    // Don't beep for a rest that ended while the app was closed.
    if (w.restEndsAt != null && Date.now() >= w.restEndsAt) alertedFor = w.restEndsAt;
  }
  render({ resetScroll: true });
  registerServiceWorker();
  if (isStandalone()) requestPersistentStorage();
}

boot();
