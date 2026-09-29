/** Tiny DOM helpers: element builder, bottom sheets, confirm/action sheets, toasts, icons. */

export function h(tag, props, ...children) {
  const el = document.createElement(tag);
  append(el, children);
  // Props after children so <select value> can match an option.
  for (const [key, value] of Object.entries(props ?? {})) {
    if (value == null || value === false && !(key in el)) continue;
    if (key.startsWith('on') && typeof value === 'function') el.addEventListener(key.slice(2), value);
    else if (key === 'class') el.className = value;
    else if (key === 'style' && typeof value === 'object') Object.assign(el.style, value);
    else if (key.startsWith('aria-') || key.startsWith('data-') || key === 'role' || key === 'for' || !(key in el)) {
      el.setAttribute(key, value === true ? '' : String(value));
    } else el[key] = value;
  }
  return el;
}

function append(el, children) {
  for (const c of children) {
    if (c == null || c === false) continue;
    if (Array.isArray(c)) append(el, c);
    else el.append(c instanceof Node ? c : document.createTextNode(String(c)));
  }
}

const ICONS = {
  stopwatch: '<circle cx="12" cy="14" r="8"/><path d="M12 14V10M9 2h6M12 2v4M19 7l1.5-1.5"/>',
  list: '<path d="M9 6h12M9 12h12M9 18h12"/><path d="M4 6h.01M4 12h.01M4 18h.01" stroke-width="3"/>',
  chart: '<path d="M5 21V11M12 21V4M19 21v-7" stroke-width="3.2"/>',
  history: '<path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5M12 7v5l3 2"/>',
  settings: '<path d="M4 21v-7M4 10V3M12 21v-9M12 8V3M20 21v-5M20 12V3M1 14h6M9 8h6M17 16h6"/>',
  ellipsis: '<circle cx="12" cy="12" r="10"/><path d="M8 12h.01M12 12h.01M16 12h.01" stroke-width="3"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  plusCircle: '<circle cx="12" cy="12" r="10" fill="currentColor" stroke="none"/><path d="M12 7.5v9M7.5 12h9" stroke="var(--on-accent)"/>',
  chevronLeft: '<path d="M15 18l-6-6 6-6" stroke-width="2.6"/>',
  chevronRight: '<path d="M9 18l6-6-6-6"/>',
  check: '<path d="M20 6L9 17l-5-5" stroke-width="2.6"/>',
  circle: '<circle cx="12" cy="12" r="10" stroke-width="1.8"/>',
  checkFill: '<circle cx="12" cy="12" r="11" fill="currentColor" stroke="none"/><path d="M7 12.5l3.2 3.2L17 9" stroke="#fff" stroke-width="2.6"/>',
  play: '<path d="M7 4.5v15l12.5-7.5z" fill="currentColor" stroke="none"/>',
  playCircle: '<circle cx="12" cy="12" r="11" fill="currentColor" stroke="none"/><path d="M10 8v8l6-4z" fill="var(--on-accent)" stroke="none"/>',
  pause: '<circle cx="12" cy="12" r="11" fill="currentColor" stroke="none"/><path d="M10 8.5v7M14 8.5v7" stroke="var(--card)" stroke-width="2.4"/>',
  dumbbell: '<path d="M6.5 6.5v11M17.5 6.5v11M3.5 9.5v5M20.5 9.5v5M6.5 12h11" stroke-width="2.4"/>',
  flag: '<path d="M5 22V4M5 4h12l-2.5 4L17 12H5"/>',
  trash: '<path d="M3 6h18M8 6V4h8v2M6 6l1 15h10l1-15"/>',
  stack: '<path d="M12 3l9 5-9 5-9-5z"/><path d="M3 13l9 5 9-5"/>',
  up: '<circle cx="12" cy="12" r="11" fill="currentColor" stroke="none"/><path d="M12 17V7M7.5 11.5L12 7l4.5 4.5" stroke="#fff" stroke-width="2.4"/>',
  down: '<circle cx="12" cy="12" r="11" fill="currentColor" stroke="none"/><path d="M12 7v10M7.5 12.5L12 17l4.5-4.5" stroke="#fff" stroke-width="2.4"/>',
  right: '<circle cx="12" cy="12" r="11" fill="currentColor" stroke="none"/><path d="M7 12h10M12.5 7.5L17 12l-4.5 4.5" stroke="#fff" stroke-width="2.4"/>',
  bolt: '<circle cx="12" cy="12" r="11" fill="currentColor" stroke="none"/><path d="M13 5l-5.5 8H12l-1 6 5.5-8H12z" fill="#fff" stroke="none"/>',
  sparkles: '<path d="M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8zM19 16l.8 2.2L22 19l-2.2.8L19 22l-.8-2.2L16 19l2.2-.8z" fill="currentColor" stroke="none"/>',
  alert: '<path d="M12 3l10 18H2z"/><path d="M12 10v4M12 17.5h.01"/>',
  download: '<path d="M12 3v12M7 10l5 5 5-5M5 21h14"/>',
  upload: '<path d="M12 15V3M7 8l5-5 5 5M5 21h14"/>',
  share: '<path d="M12 3v12M8 7l4-4 4 4M6 11H5v10h14V11h-1"/>',
  lock: '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>',
};

export function icon(name, cls = 'icon') {
  const t = document.createElement('template');
  t.innerHTML = `<svg class="${cls}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${ICONS[name] ?? ''}</svg>`;
  return t.content.firstElementChild;
}

// ---------- sheets ----------

const openSheets = [];

/**
 * Opens a bottom sheet. `build(close)` returns its content.
 * Returns `close`. `onClose` runs after it closes (any way).
 */
export function openSheet(build, { tall = false, onClose, label } = {}) {
  let closed = false;
  const previousFocus = document.activeElement;
  const backdrop = h('div', { class: 'sheet-backdrop' });
  const sheet = h('div', { class: 'sheet' + (tall ? ' tall' : ''), role: 'dialog', 'aria-modal': 'true', 'aria-label': label });
  const close = () => {
    if (closed) return;
    closed = true;
    openSheets.splice(openSheets.indexOf(close), 1);
    document.activeElement?.blur?.();
    backdrop.classList.add('closing');
    setTimeout(() => backdrop.remove(), 180);
    if (!openSheets.length) document.documentElement.classList.remove('sheet-open');
    if (previousFocus?.tagName === 'BUTTON' && previousFocus.isConnected) previousFocus.focus({ preventScroll: true });
    onClose?.();
  };
  backdrop.addEventListener('click', (e) => { if (e.target === backdrop) close(); });
  sheet.append(build(close));
  backdrop.append(sheet);
  document.body.append(backdrop);
  document.documentElement.classList.add('sheet-open');
  openSheets.push(close);
  return close;
}

document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' && openSheets.length) openSheets.at(-1)();
});

export function sheetHeader(title, close, trailing) {
  return h('div', { class: 'sheet-header' },
    h('button', { class: 'nav-btn', onclick: close }, trailing ? 'Cancel' : 'Done'),
    h('div', { class: 'sheet-title' }, title),
    h('div', { class: 'sheet-trailing' }, trailing ?? null));
}

export function confirmSheet({ title, message, confirm = 'OK', destructive = false }) {
  return new Promise((resolve) => {
    let result = false;
    openSheet((close) => h('div', { class: 'action-sheet' },
      h('div', { class: 'card' },
        h('div', { class: 'action-head' }, h('div', { class: 'action-title' }, title), message ? h('div', { class: 'action-msg' }, message) : null),
        h('button', { class: 'action-btn' + (destructive ? ' destructive' : ' bold'), onclick: () => { result = true; close(); } }, confirm)),
      h('div', { class: 'card' }, h('button', { class: 'action-btn bold', onclick: close }, 'Cancel'))),
    { onClose: () => resolve(result), label: title });
  });
}

/** items: [{ label, destructive?, onClick }] */
export function actionSheet(title, items) {
  let chosen = null;
  openSheet((close) => h('div', { class: 'action-sheet' },
    h('div', { class: 'card' },
      title ? h('div', { class: 'action-head' }, h('div', { class: 'action-title' }, title)) : null,
      items.map((item) => h('button', {
        class: 'action-btn' + (item.destructive ? ' destructive' : ''),
        onclick: () => { chosen = item; close(); },
      }, item.label))),
    h('div', { class: 'card' }, h('button', { class: 'action-btn bold', onclick: close }, 'Cancel'))),
  { onClose: () => chosen?.onClick(), label: title });
}

// ---------- toast ----------

export function toast(message, { action, onAction, duration = 3500 } = {}) {
  document.querySelector('.toast')?.remove();
  const el = h('div', { class: 'toast', role: 'status' },
    h('span', {}, message),
    action ? h('button', { class: 'toast-action', onclick: () => { el.remove(); onAction?.(); } }, action) : null);
  document.body.append(el);
  if (duration) setTimeout(() => el.remove(), duration);
  return el;
}
