"use strict";
const schema = require("./study_canonical_schema_v2.json");
const localizationSchema = require("./study_canonical_localization_v2.json");
const VERSION = "study_paid_snapshot_v2";
const MARKER = "STUDY PAID CANONICAL v2";

// Only the paid/sync fallback opts in. Primary Study SSE keeps its own contract.
// Models, routing, safety, auth, quotas and synchronous timeouts are unchanged.
function studyCanonicalTransport(body) {
  if (body?.mode !== "estudo" || body?.provider === "openai" ||
      body?.studyCanonicalVersion !== VERSION ||
      !["pt", "es"].includes(body?.lang) ||
      typeof body?.systemPrompt !== "string" ||
      !body.systemPrompt.trimStart().startsWith(MARKER)) return null;
  const localize = body.studyCanonicalOperation === "localize";
  if (body.studyCanonicalOperation && !["generate", "localize"].includes(body.studyCanonicalOperation)) return null;
  return {
    version: VERSION,
    maxOutputTokens: localize ? 4096 : 12288,
    generationConfig: {responseMimeType: "application/json", responseJsonSchema: localize ? localizationSchema : schema},
  };
}

// Native schema validation is repeated at the trust boundary: STOP alone is
// insufficient when a transport closes with a missing/invalid canonical record.
function studyCanonicalCompletion(text, finishReason, localize = false) {
  if (finishReason !== "STOP") return "canonical_incomplete_termination";
  try {
    const d = JSON.parse(text);
    const exact = (v, keys) => v && !Array.isArray(v) && typeof v === "object" &&
      Object.keys(v).length === keys.length && keys.every(k => Object.hasOwn(v, k));
    const valid = (value, spec) => {
      if (spec.anyOf) return spec.anyOf.some(s => valid(value, s));
      const type = value === null ? "null" : Array.isArray(value) ? "array" : typeof value;
      if (!(Array.isArray(spec.type) ? spec.type.includes(type) : spec.type === type)) return false;
      if (spec.enum && !spec.enum.includes(value)) return false;
      if (spec.pattern && !(new RegExp(spec.pattern)).test(value)) return false;
      if (type === "number" && !Number.isFinite(value)) return false;
      if (type === "object") return exact(value, Object.keys(spec.properties)) &&
        Object.entries(spec.properties).every(([k, s]) => valid(value[k], s));
      if (type === "array") return value.every(v => valid(v, spec.items));
      return true;
    };
    if (!valid(d, localize ? localizationSchema : schema)) return "canonical_invalid_schema";
    const p = localize ? d : d.presentation;
    const labelOK = t => typeof t === "string" && t.trim() &&
      !/\d|https?:\/\/|\bdoi:|\bPMID|\b(?:NaN|Infinity)\b|\{\{/i.test(t);
    if (!labelOK(p.title) || !p.labels.length) return "canonical_invalid_presentation";
    const labels = new Set();
    for (const l of p.labels) {
      if (!/^[a-z][a-z0-9_]{0,159}$/.test(l.id)) return "canonical_invalid_label_id";
      if (labels.has(l.id)) return "canonical_duplicate_label_id";
      if (!labelOK(l.text)) return "canonical_unbound_numeric_or_reference_label";
      labels.add(l.id);
    }
    if (localize) return null; // Exact source-ID equality is checked against the immutable client snapshot.
    if (!d.clinical.length) return "canonical_empty_snapshot";
    const ids = new Set(["topic"]), consumed = new Set();
    for (const f of d.clinical) {
      if (!/^[a-z][a-z0-9_]{0,159}$/.test(f.id) || ids.has(f.id) || !f.items.length) return "canonical_fact_binding";
      ids.add(f.id);
      for (const i of f.items) {
        if (!/^[a-z][a-z0-9_]{0,159}$/.test(i.id) || ids.has(i.id)) return "canonical_item_binding";
        ids.add(i.id);
        if (i.k === "quantity" || i.k === "frequency") {
          if (i.hi !== null && i.hi < i.n) return "canonical_invalid_quantity";
        } else if (!["route", "neutral"].includes(i.k)) {
          if (!labels.has(i.id)) return "canonical_missing_label";
          consumed.add(i.id);
        }
      }
      if (!f.when.every(id => f.items.some(i => i.id === id && i.k === "condition"))) return "canonical_condition_binding";
    }
    if (consumed.size !== labels.size) return "canonical_orphan_label";
    return null;
  } catch { return "canonical_invalid_schema"; }
}

module.exports = {studyCanonicalTransport, studyCanonicalCompletion, VERSION};
