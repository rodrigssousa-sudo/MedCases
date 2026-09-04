"use strict";

/**
 * Global, language-tolerant clinical identity resolver.
 *
 * Server-side only. It resolves the active pathology/case key but never
 * chooses treatment, classification, score or management.
 *
 * Descriptors are data supplied by a remote registry/adapter in later builds.
 */
class ClinicalCaseIdentityResolver {
  resolve({ input, descriptors, activeCaseAnchor = "" }) {
    const query = normalize([input || "", activeCaseAnchor || ""].join(" "));
    if (!query) return unresolved();

    const scored = [];

    for (const descriptor of descriptors || []) {
      if (!descriptor || !String(descriptor.canonicalKey || "").trim()) continue;

      const exclusions = (descriptor.exclusions || []).map(normalize);
      if (exclusions.some((x) => x && containsPhrase(query, x))) continue;

      const aliases = new Set([
        descriptor.displayLabel || "",
        ...(descriptor.aliases || []),
      ].map(normalize).filter(Boolean));

      const strongAliases = new Set(
        (descriptor.strongAliases || []).map(normalize).filter(Boolean),
      );

      let best = 0;
      const matchedAliases = new Set();

      for (const alias of aliases) {
        const score = aliasScore(query, alias);
        if (score > 0) {
          matchedAliases.add(alias);
          best = Math.max(best, score);
        }
      }

      for (const alias of strongAliases) {
        if (containsPhrase(query, alias)) {
          matchedAliases.add(alias);
          best = Math.max(best, 0.98);
        }
      }

      if (best > 0) {
        scored.push({
          descriptor,
          score: best,
          matchedAliases: [...matchedAliases],
        });
      }
    }

    if (!scored.length) return unresolved();

    scored.sort((a, b) => b.score - a.score);
    const top = scored[0];
    const runnerUp = scored[1] || null;

    const ambiguous = Boolean(
      runnerUp &&
      top.score >= 0.55 &&
      runnerUp.score >= 0.55 &&
      Math.abs(top.score - runnerUp.score) < 0.08
    );

    if (ambiguous) {
      return {
        canonicalKey: "",
        displayLabel: "",
        confidence: top.score,
        matchedAliases: top.matchedAliases,
        ambiguous: true,
        isHighConfidence: false,
      };
    }

    return {
      canonicalKey: String(top.descriptor.canonicalKey),
      displayLabel: String(top.descriptor.displayLabel || ""),
      confidence: top.score,
      matchedAliases: top.matchedAliases,
      ambiguous: false,
      isHighConfidence: top.score >= 0.72,
    };
  }
}

function unresolved() {
  return {
    canonicalKey: "",
    displayLabel: "",
    confidence: 0,
    matchedAliases: [],
    ambiguous: false,
    isHighConfidence: false,
  };
}

function aliasScore(query, alias) {
  if (!alias) return 0;

  if (containsPhrase(query, alias)) {
    const aliasTokens = tokens(alias);
    return aliasTokens.size <= 2 ? 0.94 : 0.90;
  }

  const queryTokens = tokens(query);
  const aliasTokens = tokens(alias);
  if (!queryTokens.size || !aliasTokens.size) return 0;

  let overlap = 0;
  for (const token of aliasTokens) {
    if (queryTokens.has(token)) overlap += 1;
  }
  if (!overlap) return 0;

  const recall = overlap / aliasTokens.size;
  const precision = overlap / queryTokens.size;
  const harmonic = (2 * precision * recall) / (precision + recall);

  if (recall === 1 && aliasTokens.size >= 2) return Math.max(0.78, harmonic);
  if (recall >= 0.67 && aliasTokens.size >= 3) return Math.max(0.62, harmonic);
  return 0;
}

function containsPhrase(haystack, needle) {
  return Boolean(needle) && (` ${haystack} `).includes(` ${needle} `);
}

function tokens(value) {
  return new Set(
    String(value || "")
      .split(" ")
      .filter((x) => x.length >= 2),
  );
}

function normalize(value) {
  return String(value || "")
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/ñ/g, "n")
    .replace(/[^a-z0-9]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

module.exports = {
  ClinicalCaseIdentityResolver,
  normalizeClinicalIdentityText: normalize,
};
