"use strict";

/**
 * Generic remote-rule resolver.
 *
 * Supported modes:
 * - "categorical": ordered categories with criteria;
 * - "score": remote components produce points, then remote bands classify score;
 * - "stage": same rule model as categorical, semantically a stage.
 *
 * No disease names or treatment logic live here. The registry supplies data.
 */
class ClinicalClassificationResolver {
  resolve({
    pathologyKey,
    descriptors,
    patientFacts = {},
  }) {
    const candidates = (descriptors || [])
      .filter((x) =>
        x &&
        x.enabled !== false &&
        String(x.canonicalPathologyKey || "") === String(pathologyKey || "")
      )
      .slice()
      .sort(comparePriority);

    if (!pathologyKey) {
      return unresolved("pathology_key_missing");
    }

    if (!candidates.length) {
      return unresolved("classification_not_registered");
    }

    const topPriority = Number(candidates[0].priority || 0);
    const tied = candidates.filter(
      (x) => Number(x.priority || 0) === topPriority,
    );

    if (tied.length > 1) {
      return {
        ...unresolved("classification_priority_tie"),
        ambiguous: true,
      };
    }

    const descriptor = candidates[0];
    const mode = String(descriptor.mode || "categorical").toLowerCase();

    if (mode === "score") {
      return resolveScore(descriptor, patientFacts);
    }

    if (mode === "categorical" || mode === "stage") {
      return resolveCategorical(descriptor, patientFacts, mode);
    }

    return unresolved("classification_mode_unsupported");
  }
}

function resolveCategorical(descriptor, patientFacts, mode) {
  const requiredFacts = uniqueStrings(descriptor.requiredFacts || []);
  const missingRequiredFacts = requiredFacts.filter(
    (fact) => !hasFact(patientFacts, fact),
  );

  const categories = (descriptor.categories || [])
    .filter((x) => x && x.enabled !== false)
    .slice()
    .sort(comparePriority);

  const matched = [];

  for (const category of categories) {
    const evaluation = evaluateCriteria(category.criteria || {}, patientFacts);
    if (evaluation.matched) {
      matched.push({
        category,
        missingFacts: evaluation.missingFacts,
      });
    }
  }

  const completeMatches = matched.filter((x) => x.missingFacts.length === 0);

  if (completeMatches.length > 1) {
    const topPriority = Number(completeMatches[0].category.priority || 0);
    const topMatches = completeMatches.filter(
      (x) => Number(x.category.priority || 0) === topPriority,
    );

    if (topMatches.length > 1) {
      return {
        ...baseResult(descriptor, mode),
        reason: "classification_category_tie",
        ambiguous: true,
      };
    }
  }

  if (completeMatches.length) {
    const selected = completeMatches[0].category;
    return {
      ...baseResult(descriptor, mode),
      resolved: true,
      categoryKey: String(selected.key || ""),
      categoryLabel: String(selected.label || ""),
      categoryPayload: plainObject(selected.payload),
      managementRuleKey: String(selected.managementRuleKey || ""),
      missingFacts: [],
      reason: "classification_resolved",
    };
  }

  const criteriaMissing = uniqueStrings(
    matched.flatMap((x) => x.missingFacts),
  );
  const missingFacts = uniqueStrings([
    ...missingRequiredFacts,
    ...criteriaMissing,
  ]);

  return {
    ...baseResult(descriptor, mode),
    resolved: false,
    categoryKey: "",
    categoryLabel: "",
    categoryPayload: {},
    managementRuleKey: "",
    missingFacts,
    reason: missingFacts.length
      ? "classification_missing_facts"
      : "classification_no_category_match",
  };
}

function resolveScore(descriptor, patientFacts) {
  const components = (descriptor.components || [])
    .filter((x) => x && x.enabled !== false);

  let score = 0;
  const missingFacts = [];
  const componentResults = [];

  for (const component of components) {
    const evaluation = evaluateCriteria(component.criteria || {}, patientFacts);

    if (evaluation.missingFacts.length) {
      missingFacts.push(...evaluation.missingFacts);
      componentResults.push({
        key: String(component.key || ""),
        status: "missing",
        points: 0,
      });
      continue;
    }

    const points = evaluation.matched ? Number(component.points || 0) : 0;
    score += Number.isFinite(points) ? points : 0;
    componentResults.push({
      key: String(component.key || ""),
      status: evaluation.matched ? "matched" : "not_matched",
      points: Number.isFinite(points) ? points : 0,
    });
  }

  const requiredFacts = uniqueStrings(descriptor.requiredFacts || []);
  for (const fact of requiredFacts) {
    if (!hasFact(patientFacts, fact)) missingFacts.push(fact);
  }

  const uniqueMissing = uniqueStrings(missingFacts);
  if (uniqueMissing.length) {
    return {
      ...baseResult(descriptor, "score"),
      resolved: false,
      score: null,
      categoryKey: "",
      categoryLabel: "",
      categoryPayload: {},
      componentResults,
      missingFacts: uniqueMissing,
      reason: "score_missing_facts",
    };
  }

  const bands = (descriptor.bands || [])
    .filter((x) => x && x.enabled !== false)
    .slice()
    .sort((a, b) => Number(a.min ?? -Infinity) - Number(b.min ?? -Infinity));

  const matchingBands = bands.filter(
    (band) =>
      (band.min == null || score >= Number(band.min)) &&
      (band.max == null || score <= Number(band.max)),
  );

  if (matchingBands.length !== 1) {
    return {
      ...baseResult(descriptor, "score"),
      resolved: false,
      score,
      categoryKey: "",
      categoryLabel: "",
      categoryPayload: {},
      componentResults,
      missingFacts: [],
      ambiguous: matchingBands.length > 1,
      reason: matchingBands.length > 1
        ? "score_band_overlap"
        : "score_band_not_found",
    };
  }

  const band = matchingBands[0];
  return {
    ...baseResult(descriptor, "score"),
    resolved: true,
    score,
    categoryKey: String(band.key || ""),
    categoryLabel: String(band.label || ""),
    categoryPayload: plainObject(band.payload),
    managementRuleKey: String(band.managementRuleKey || ""),
    componentResults,
    missingFacts: [],
    reason: "score_resolved",
  };
}

function evaluateCriteria(criteria, patientFacts) {
  const all = Array.isArray(criteria.all) ? criteria.all : [];
  const any = Array.isArray(criteria.any) ? criteria.any : [];
  const none = Array.isArray(criteria.none) ? criteria.none : [];

  const evaluations = {
    all: all.map((condition) => evaluateCondition(condition, patientFacts)),
    any: any.map((condition) => evaluateCondition(condition, patientFacts)),
    none: none.map((condition) => evaluateCondition(condition, patientFacts)),
  };

  const missingFacts = uniqueStrings([
    ...evaluations.all.flatMap((x) => x.missingFacts),
    ...evaluations.any.flatMap((x) => x.missingFacts),
    ...evaluations.none.flatMap((x) => x.missingFacts),
  ]);

  const allOk = evaluations.all.every((x) => x.value === true);
  const anyOk = evaluations.any.length === 0 ||
    evaluations.any.some((x) => x.value === true);
  const noneOk = evaluations.none.every((x) => x.value !== true);

  return {
    matched: allOk && anyOk && noneOk,
    missingFacts,
  };
}

function evaluateCondition(condition, patientFacts) {
  const fact = String(condition?.fact || "");
  const op = String(condition?.op || "eq").toLowerCase();

  if (!fact) return { value: false, missingFacts: [] };

  const present = hasFact(patientFacts, fact);
  if (op === "present") {
    return { value: present, missingFacts: [] };
  }
  if (!present) {
    return { value: false, missingFacts: [fact] };
  }

  const actual = getFact(patientFacts, fact);
  const expected = condition?.value;

  switch (op) {
    case "eq":
      return bool(actual === expected);
    case "neq":
      return bool(actual !== expected);
    case "gt":
      return bool(Number(actual) > Number(expected));
    case "gte":
      return bool(Number(actual) >= Number(expected));
    case "lt":
      return bool(Number(actual) < Number(expected));
    case "lte":
      return bool(Number(actual) <= Number(expected));
    case "in":
      return bool(Array.isArray(expected) && expected.includes(actual));
    case "contains":
      return bool(
        Array.isArray(actual)
          ? actual.includes(expected)
          : String(actual).includes(String(expected)),
      );
    case "truthy":
      return bool(Boolean(actual));
    case "falsy":
      return bool(!actual);
    default:
      return { value: false, missingFacts: [] };
  }
}

function hasFact(facts, path) {
  const sentinel = Symbol("missing");
  return getFact(facts, path, sentinel) !== sentinel;
}

function getFact(facts, path, fallback) {
  let cursor = facts;
  for (const part of String(path || "").split(".").filter(Boolean)) {
    if (
      cursor == null ||
      typeof cursor !== "object" ||
      !Object.prototype.hasOwnProperty.call(cursor, part)
    ) {
      return fallback;
    }
    cursor = cursor[part];
  }
  return cursor;
}

function bool(value) {
  return { value: Boolean(value), missingFacts: [] };
}

function baseResult(descriptor, mode) {
  return {
    classificationKey: String(descriptor.classificationKey || descriptor.id || ""),
    classificationLabel: String(descriptor.label || ""),
    mode,
    sourceVersion: String(descriptor.version || ""),
    resolved: false,
    ambiguous: false,
  };
}

function unresolved(reason) {
  return {
    classificationKey: "",
    classificationLabel: "",
    mode: "",
    sourceVersion: "",
    resolved: false,
    ambiguous: false,
    categoryKey: "",
    categoryLabel: "",
    categoryPayload: {},
    managementRuleKey: "",
    missingFacts: [],
    reason,
  };
}

function comparePriority(a, b) {
  const delta = Number(b.priority || 0) - Number(a.priority || 0);
  if (delta !== 0) return delta;
  return String(a.id || a.classificationKey || "").localeCompare(
    String(b.id || b.classificationKey || ""),
  );
}

function uniqueStrings(values) {
  return [...new Set(values.map((x) => String(x || "")).filter(Boolean))];
}

function plainObject(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return { ...value };
}

module.exports = {
  ClinicalClassificationResolver,
  evaluateClinicalCriteria: evaluateCriteria,
};
