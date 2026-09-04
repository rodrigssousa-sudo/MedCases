"use strict";

const DEFAULT_COLLECTIONS = Object.freeze({
  identities: "clinical_identity_registry",
  protocols: "clinical_protocols",
  classifications: "clinical_classification_registry",
  managementRules: "clinical_management_rules",
});

/**
 * Read-only adapter for the remote clinical control plane.
 *
 * The adapter accepts an injected Firestore-like database object so it can be
 * unit tested without cloud access. It only reads enabled documents and
 * applies effective-date filtering. It performs no writes.
 */
class ClinicalRegistryAdapter {
  constructor({ db, collections = {}, clock = () => new Date() } = {}) {
    if (!db || typeof db.collection !== "function") {
      throw new Error("clinical_registry_db_required");
    }

    this.db = db;
    this.collections = {
      ...DEFAULT_COLLECTIONS,
      ...collections,
    };
    this.clock = clock;
  }

  async loadSnapshot({ asOf } = {}) {
    const now = normalizeDate(asOf || this.clock());

    const [
      identities,
      protocols,
      classifications,
      managementRules,
    ] = await Promise.all([
      this._loadCollection(this.collections.identities, now),
      this._loadCollection(this.collections.protocols, now),
      this._loadCollection(this.collections.classifications, now),
      this._loadCollection(this.collections.managementRules, now),
    ]);

    return Object.freeze({
      loadedAt: now.toISOString(),
      identities,
      protocols,
      classifications,
      managementRules,
    });
  }

  async _loadCollection(name, asOf) {
    const snapshot = await this.db.collection(name).get();
    const rows = [];

    for (const doc of snapshot.docs || []) {
      const raw = typeof doc.data === "function" ? doc.data() : {};
      const row = {
        id: String(doc.id || raw.id || ""),
        ...toPlainData(raw),
      };

      if (row.enabled === false) continue;
      if (!isEffective(row, asOf)) continue;
      rows.push(Object.freeze(row));
    }

    rows.sort((a, b) => {
      const priorityDelta = Number(b.priority || 0) - Number(a.priority || 0);
      if (priorityDelta !== 0) return priorityDelta;

      const versionDelta = compareVersionLike(
        String(b.version || ""),
        String(a.version || ""),
      );
      if (versionDelta !== 0) return versionDelta;

      return String(a.id || "").localeCompare(String(b.id || ""));
    });

    return Object.freeze(rows);
  }
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
  if (!x) throw new Error("clinical_registry_invalid_as_of_date");
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

function compareVersionLike(a, b) {
  const left = tokenizeVersion(a);
  const right = tokenizeVersion(b);
  const max = Math.max(left.length, right.length);

  for (let i = 0; i < max; i += 1) {
    const l = left[i] ?? 0;
    const r = right[i] ?? 0;

    if (typeof l === "number" && typeof r === "number") {
      if (l !== r) return l - r;
      continue;
    }

    const cmp = String(l).localeCompare(String(r));
    if (cmp !== 0) return cmp;
  }

  return 0;
}

function tokenizeVersion(value) {
  return String(value || "")
    .split(/[^a-zA-Z0-9]+/)
    .filter(Boolean)
    .map((part) => (/^\d+$/.test(part) ? Number(part) : part.toLowerCase()));
}

module.exports = {
  ClinicalRegistryAdapter,
  DEFAULT_COLLECTIONS,
};
