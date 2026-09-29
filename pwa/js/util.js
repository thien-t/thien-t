export function uid() {
  if (globalThis.crypto?.randomUUID) return crypto.randomUUID();
  return 'id-' + Date.now().toString(36) + '-' + Math.random().toString(36).slice(2, 10);
}

/** Parses user-typed numbers, accepting "," as the decimal separator. Returns null if invalid. */
export function parseNumber(text) {
  const s = String(text ?? '').trim().replace(',', '.');
  if (s === '') return 0;
  const n = Number(s);
  return Number.isFinite(n) && n >= 0 ? n : null;
}

export const clamp = (n, min, max) => Math.min(max, Math.max(min, n));

/** Monday-based week containing today, shifted by `offset` weeks. Returns ms timestamps. */
export function weekRange(offset = 0) {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  const sinceMonday = (d.getDay() + 6) % 7;
  d.setDate(d.getDate() - sinceMonday + offset * 7);
  const start = d.getTime();
  d.setDate(d.getDate() + 7);
  return { start, end: d.getTime() };
}
