/** Minimal promise wrapper around IndexedDB. */
const DB_NAME = 'workout-timer';
const DB_VERSION = 1;
export const STORES = ['routines', 'workouts', 'movements', 'meta'];

let dbPromise;

function open() {
  dbPromise ??= new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VERSION);
    req.onupgradeneeded = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains('routines')) db.createObjectStore('routines', { keyPath: 'id' });
      if (!db.objectStoreNames.contains('workouts')) db.createObjectStore('workouts', { keyPath: 'id' });
      if (!db.objectStoreNames.contains('movements')) db.createObjectStore('movements', { keyPath: 'key' });
      if (!db.objectStoreNames.contains('meta')) db.createObjectStore('meta', { keyPath: 'key' });
    };
    req.onsuccess = () => {
      const db = req.result;
      // Another tab upgraded the schema: close so it can proceed.
      db.onversionchange = () => db.close();
      resolve(db);
    };
    req.onerror = () => reject(req.error);
    req.onblocked = () => reject(new Error('Database is blocked by another open copy of the app.'));
  });
  return dbPromise;
}

function done(tx) {
  return new Promise((resolve, reject) => {
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
    tx.onabort = () => reject(tx.error ?? new Error('Transaction aborted'));
  });
}

export async function getAll(store) {
  const db = await open();
  return new Promise((resolve, reject) => {
    const req = db.transaction(store).objectStore(store).getAll();
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

export async function put(store, value) {
  const db = await open();
  const tx = db.transaction(store, 'readwrite');
  tx.objectStore(store).put(value);
  return done(tx);
}

export async function putMany(store, values) {
  const db = await open();
  const tx = db.transaction(store, 'readwrite');
  const os = tx.objectStore(store);
  for (const v of values) os.put(v);
  return done(tx);
}

export async function remove(store, key) {
  const db = await open();
  const tx = db.transaction(store, 'readwrite');
  tx.objectStore(store).delete(key);
  return done(tx);
}

/** Atomically replaces every store's contents (used by "Replace all data" import). */
export async function replaceAll(data) {
  const db = await open();
  const tx = db.transaction(STORES, 'readwrite');
  for (const store of STORES) {
    const os = tx.objectStore(store);
    os.clear();
    for (const v of data[store] ?? []) os.put(v);
  }
  return done(tx);
}
