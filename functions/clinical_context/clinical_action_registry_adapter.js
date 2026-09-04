"use strict";

/**
 * Read-only adapter for remote action definitions.
 *
 * The app never contains pathology-specific CTA labels/prompts/tables.
 * Remote documents provide localized labels, action kinds and content refs.
 */
class ClinicalActionRegistryAdapter {
  constructor({
    db,
    collectionName = "clinical_action_registry",
    clock = () => new Date(),
  } = {}) {
    if (!db || typeof db.collection !== "function") {
      throw new Error("clinical_action_registry_db_required");
    }
    this.db = db;
    this.collectionName = collectionName;
    this.clock = clock;
  }

  async loadActions({ asOf } = {}) {
    const now = normalizeDate(asOf || this.clock());
    const snapshot = await this.db.collection(this.collectionName).get();
    const rows = [];

    for (const doc of snapshot.docs || []) {
      const raw = typeof doc.data === "function" ? doc.data() : {};
      const row = Object.freeze({
        id: String(doc.id || raw.id || ""),
        ...toPlainData(raw),
      });

      if (row.enabled === false) continue;
      if (!isEffective(row, now)) continue;
      rows.push(row);
    }

    rows.sort(comparePriority);
    return Object.freeze(rows);
  }
}

function comparePriority(a, b) {
  const delta = Number(b.priority || 0) - Number(a.priority || 0);
  if (delta !== 0) return delta;
  return String(a.id || a.actionKey || "").localeCompare(
    String(b.id || b.actionKey || ""),
  );
}

function isEffective(row, asOf) {
  const from = dateOrNull(row.effectiveFrom);
  const until = dateOrNull(row.effectiveUntil);
  if (from && asOf < from) return false;
  if (until && asOf > until) return false;
  return true;
}

function dateOrNull(value) {
  if (!value) return null;
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value;
  if (typeof value.toDate === "function") {
    const x = value.toDate();
    return x instanceof Date && !Number.isNaN(x.getTime()) ? x : null;
  }
  const x = new Date(value);
  return Number.isNaN(x.getTime()) ? null : x;
}

function normalizeDate(value) {
  const x = dateOrNull(value);
  if (!x) throw new Error("clinical_action_registry_invalid_as_of_date");
  return x;
}

function toPlainData(value) {
  if (Array.isArray(value)) return value.map(toPlainData);
  if (!value || typeof value !== "object") return value;
  if (value instanceof Date) return value.toISOString();
  if (typeof value.toDate === "function") {
    const x = value.toDate();
    return x instanceof Date ? x.toISOString() : value;
  }
  const out = {};
  for (const [key, child] of Object.entries(value)) {
    out[key] = toPlainData(child);
  }
  return out;
}

module.exports = {
  ClinicalActionRegistryAdapter,
};
