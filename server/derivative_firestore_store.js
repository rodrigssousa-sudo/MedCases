'use strict';
const {DerivativeError} = require('./derivative_contract');

// Server-only candidate storage. No client Firestore permissions are granted.
// Collection is separate from audio, transcripts, entitlements and STT usage.
// Routing/worker activation is intentionally pending the provider quality gate.
class DerivativeFirestoreStore {
  constructor(db) { this.collection = db.collection('_derivative_engine_r2'); this.db = db; }
  ref(kind, key) {
    if (!/^[a-f0-9]{64}$/.test(key)) throw new DerivativeError('invalid_storage_key');
    return this.collection.doc(`${kind}_${key}`);
  }
  assertSize(value) {
    // Stay below Firestore's document ceiling, including field/index overhead.
    if (Buffer.byteLength(JSON.stringify(value)) > 750000) throw new DerivativeError('save_failed', true);
  }
  async transaction(key, fn) {
    const ref = this.ref('job', key);
    return this.db.runTransaction(async transaction => fn({
      read: async () => { const snapshot = await transaction.get(ref); return snapshot.exists ? snapshot.data() : undefined; },
      write: async value => { this.assertSize(value); transaction.set(ref, value); },
    }));
  }
  async getCache(key) {
    const snapshot = await this.ref('cache', key).get();
    return snapshot.exists ? snapshot.data().result : undefined;
  }
  async putCache(key, result) {
    this.assertSize({result});
    await this.ref('cache', key).set({result});
  }
  async claim(key, lease) {
    const ref = this.ref('claim', key);
    return this.db.runTransaction(async transaction => {
      if ((await transaction.get(ref)).exists) return false;
      // No expiring lease that could silently charge again after process death.
      // Unknown outcomes require explicit reconciliation using provider request ID.
      transaction.set(ref, {lease}); return true;
    });
  }
  async release(key, lease) {
    const ref = this.ref('claim', key);
    await this.db.runTransaction(async transaction => {
      const snapshot = await transaction.get(ref);
      if (snapshot.exists && snapshot.data().lease === lease) transaction.delete(ref);
    });
  }
}
module.exports = {DerivativeFirestoreStore};
