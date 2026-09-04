"use strict";

const {
  COLLECTIONS,
} = require("./clinical_registry_schema");

class ClinicalContentRegistryReader {
  constructor({
    db,
    collectionName = COLLECTIONS.content,
  } = {}) {
    requireDb(db);
    this.db = db;
    this.collectionName = collectionName;
  }

  async loadContentRef(contentRef) {
    const ref = String(contentRef || "").trim();
    if (!ref) return null;

    const snapshot = await this.db.collection(this.collectionName).doc(ref).get();
    if (!snapshot || snapshot.exists !== true) return null;

    const raw = typeof snapshot.data === "function" ? snapshot.data() : {};
    if (raw?.enabled === false) return null;

    return Object.freeze({
      id: String(snapshot.id || ref),
      ...toPlainData(raw),
    });
  }

  async loadAll() {
    const snapshot = await this.db.collection(this.collectionName).get();
    const rows = [];

    for (const doc of snapshot.docs || []) {
      const raw = typeof doc.data === "function" ? doc.data() : {};
      if (raw?.enabled === false) continue;

      rows.push(
        Object.freeze({
          id: String(doc.id || raw.contentKey || ""),
          ...toPlainData(raw),
        }),
      );
    }

    rows.sort((a, b) =>
      String(a.contentKey || a.id || "").localeCompare(
        String(b.contentKey || b.id || ""),
      ),
    );

    return Object.freeze(rows);
  }
}

function createReadOnlyClinicalDbFacade(db) {
  requireDb(db);

  return Object.freeze({
    collection(name) {
      const collection = db.collection(name);

      return Object.freeze({
        get: (...args) => collection.get(...args),

        doc(id) {
          const doc = collection.doc(id);

          return Object.freeze({
            get: (...args) => doc.get(...args),
          });
        },
      });
    },
  });
}

function requireDb(db) {
  if (!db || typeof db.collection !== "function") {
    throw new Error("clinical_firestore_db_required");
  }
}

function toPlainData(value) {
  if (Array.isArray(value)) return value.map(toPlainData);
  if (!value || typeof value !== "object") return value;

  if (value instanceof Date) return value.toISOString();

  if (typeof value.toDate === "function") {
    const date = value.toDate();
    return date instanceof Date ? date.toISOString() : value;
  }

  const out = {};
  for (const [key, child] of Object.entries(value)) {
    out[key] = toPlainData(child);
  }
  return out;
}

module.exports = {
  ClinicalContentRegistryReader,
  createReadOnlyClinicalDbFacade,
};
