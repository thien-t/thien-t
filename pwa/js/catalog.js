export const GROUPS = ['Push', 'Pull', 'Legs', 'Core'];

/**
 * `target`: held to the 10–20 hard sets/week hypertrophy target. The others get plenty
 * of indirect work from compounds, so they're shown but not graded.
 */
export const MUSCLES = {
  chest: { name: 'Chest', group: 'Push', target: true },
  frontDelts: { name: 'Front Delts', group: 'Push', target: false },
  sideDelts: { name: 'Side Delts', group: 'Push', target: true },
  triceps: { name: 'Triceps', group: 'Push', target: true },
  lats: { name: 'Lats', group: 'Pull', target: true },
  upperBack: { name: 'Upper Back', group: 'Pull', target: true },
  rearDelts: { name: 'Rear Delts', group: 'Pull', target: true },
  traps: { name: 'Traps', group: 'Pull', target: false },
  biceps: { name: 'Biceps', group: 'Pull', target: true },
  forearms: { name: 'Forearms', group: 'Pull', target: false },
  quads: { name: 'Quads', group: 'Legs', target: true },
  hamstrings: { name: 'Hamstrings', group: 'Legs', target: true },
  glutes: { name: 'Glutes', group: 'Legs', target: true },
  calves: { name: 'Calves', group: 'Legs', target: true },
  abs: { name: 'Abs', group: 'Core', target: false },
  lowerBack: { name: 'Lower Back', group: 'Core', target: false },
};

export const musclesIn = (group) => Object.keys(MUSCLES).filter((k) => MUSCLES[k].group === group);

const M = (name, primary, secondary, compound) => ({ name, primary, secondary, compound });

export const MOVEMENTS = [
  // Chest
  M('Bench Press', 'chest', ['triceps', 'frontDelts'], true),
  M('Incline Bench Press', 'chest', ['frontDelts', 'triceps'], true),
  M('Dumbbell Bench Press', 'chest', ['triceps', 'frontDelts'], true),
  M('Incline Dumbbell Press', 'chest', ['frontDelts', 'triceps'], true),
  M('Machine Chest Press', 'chest', ['triceps', 'frontDelts'], true),
  M('Push-Up', 'chest', ['triceps', 'frontDelts'], true),
  M('Dip', 'chest', ['triceps', 'frontDelts'], true),
  M('Chest Fly', 'chest', [], false),
  M('Cable Crossover', 'chest', [], false),
  // Shoulders
  M('Overhead Press', 'frontDelts', ['sideDelts', 'triceps'], true),
  M('Dumbbell Shoulder Press', 'frontDelts', ['sideDelts', 'triceps'], true),
  M('Lateral Raise', 'sideDelts', [], false),
  M('Cable Lateral Raise', 'sideDelts', [], false),
  M('Rear Delt Fly', 'rearDelts', [], false),
  M('Face Pull', 'rearDelts', ['upperBack'], false),
  // Triceps
  M('Close-Grip Bench Press', 'triceps', ['chest', 'frontDelts'], true),
  M('Tricep Pushdown', 'triceps', [], false),
  M('Skull Crusher', 'triceps', [], false),
  M('Overhead Tricep Extension', 'triceps', [], false),
  // Back
  M('Pull-Up', 'lats', ['biceps', 'upperBack'], true),
  M('Chin-Up', 'lats', ['biceps'], true),
  M('Lat Pulldown', 'lats', ['biceps', 'upperBack'], true),
  M('Straight-Arm Pulldown', 'lats', [], false),
  M('Barbell Row', 'upperBack', ['lats', 'biceps', 'rearDelts'], true),
  M('Dumbbell Row', 'lats', ['upperBack', 'biceps'], true),
  M('Seated Cable Row', 'upperBack', ['lats', 'biceps', 'rearDelts'], true),
  M('Chest-Supported Row', 'upperBack', ['lats', 'rearDelts', 'biceps'], true),
  M('Shrug', 'traps', [], false),
  // Biceps & forearms
  M('Bicep Curl', 'biceps', ['forearms'], false),
  M('Hammer Curl', 'biceps', ['forearms'], false),
  M('Incline Dumbbell Curl', 'biceps', [], false),
  M('Preacher Curl', 'biceps', [], false),
  M('Wrist Curl', 'forearms', [], false),
  // Quads & glutes
  M('Squat', 'quads', ['glutes'], true),
  M('Front Squat', 'quads', ['glutes'], true),
  M('Hack Squat', 'quads', ['glutes'], true),
  M('Goblet Squat', 'quads', ['glutes'], true),
  M('Leg Press', 'quads', ['glutes'], true),
  M('Lunge', 'quads', ['glutes'], true),
  M('Bulgarian Split Squat', 'quads', ['glutes'], true),
  M('Leg Extension', 'quads', [], false),
  M('Hip Thrust', 'glutes', ['hamstrings'], true),
  // Hamstrings & posterior chain
  M('Deadlift', 'hamstrings', ['glutes', 'lowerBack', 'traps'], true),
  M('Romanian Deadlift', 'hamstrings', ['glutes', 'lowerBack'], true),
  M('Sumo Deadlift', 'glutes', ['quads', 'hamstrings', 'lowerBack'], true),
  M('Good Morning', 'hamstrings', ['glutes', 'lowerBack'], true),
  M('Leg Curl', 'hamstrings', [], false),
  M('Seated Leg Curl', 'hamstrings', [], false),
  M('Back Extension', 'lowerBack', ['glutes', 'hamstrings'], false),
  M('Kettlebell Swing', 'glutes', ['hamstrings'], true),
  // Calves & core
  M('Calf Raise', 'calves', [], false),
  M('Seated Calf Raise', 'calves', [], false),
  M('Plank', 'abs', [], false),
  M('Hanging Leg Raise', 'abs', [], false),
  M('Cable Crunch', 'abs', [], false),
  M('Russian Twist', 'abs', [], false),
];

const builtIn = new Map(MOVEMENTS.map((m) => [m.name.toLowerCase(), m]));
export const builtInMovement = (name) => builtIn.get(name.toLowerCase()) ?? null;

/** Looks up a movement's muscles: your own tags first, then the built-in catalog. */
export function makeResolver(customMovements) {
  const custom = new Map(customMovements.map((m) => [m.key, m]));
  return { info: (name) => custom.get(name.toLowerCase()) ?? builtInMovement(name) };
}

/** Hypertrophy defaults: rep range, effort, rest (s) and weight jump. */
export function defaultsFor(info, fallbackRest = 120) {
  if (!info) return { repLow: 8, repHigh: 12, targetRIR: 2, rest: fallbackRest, increment: 2.5 };
  if (info.compound) return { repLow: 6, repHigh: 10, targetRIR: 2, rest: 150, increment: 2.5 };
  if (['sideDelts', 'rearDelts', 'calves', 'abs', 'forearms'].includes(info.primary)) {
    return { repLow: 12, repHigh: 20, targetRIR: 1, rest: 90, increment: 2.5 };
  }
  return { repLow: 10, repHigh: 15, targetRIR: 1, rest: 90, increment: 2.5 };
}

/** Hypertrophy Push / Pull / Legs. Run each day twice a week. [name, sets, low, high, RIR, rest] */
export const PPL = [
  ['Push', [
    ['Bench Press', 3, 6, 10, 2, 180],
    ['Incline Dumbbell Press', 3, 8, 12, 2, 150],
    ['Dumbbell Shoulder Press', 3, 8, 12, 2, 150],
    ['Lateral Raise', 4, 12, 20, 1, 90],
    ['Tricep Pushdown', 3, 10, 15, 1, 90],
    ['Overhead Tricep Extension', 2, 10, 15, 1, 90],
  ]],
  ['Pull', [
    ['Lat Pulldown', 3, 8, 12, 2, 150],
    ['Barbell Row', 3, 6, 10, 2, 180],
    ['Seated Cable Row', 3, 10, 15, 1, 120],
    ['Face Pull', 3, 12, 20, 1, 90],
    ['Bicep Curl', 3, 8, 12, 1, 90],
    ['Hammer Curl', 2, 10, 15, 1, 90],
  ]],
  ['Legs', [
    ['Squat', 3, 6, 10, 2, 180],
    ['Romanian Deadlift', 3, 8, 12, 2, 180],
    ['Leg Press', 3, 10, 15, 2, 150],
    ['Leg Curl', 3, 10, 15, 1, 90],
    ['Leg Extension', 3, 10, 15, 1, 90],
    ['Calf Raise', 4, 12, 20, 1, 90],
  ]],
];
