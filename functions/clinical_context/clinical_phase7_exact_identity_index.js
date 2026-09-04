"use strict";

function normalizeExactIdentityText(value) {
  return String(value ?? "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, " ");
}

function collectAliasStrings(value, keyHint = "", out = []) {
  if (value == null) {
    return out;
  }

  if (typeof value === "string") {
    if (/alias/i.test(keyHint) && value.trim()) {
      out.push(value.trim());
    }
    return out;
  }

  if (Array.isArray(value)) {
    for (const item of value) {
      if (typeof item === "string") {
        if (/alias/i.test(keyHint) && item.trim()) {
          out.push(item.trim());
        }
      } else {
        collectAliasStrings(item, keyHint, out);
      }
    }
    return out;
  }

  if (typeof value === "object") {
    for (const [key, child] of Object.entries(value)) {
      collectAliasStrings(child, key, out);
    }
  }

  return out;
}

function canonicalIdentityKey(identity) {
  if (!identity || typeof identity !== "object") {
    return null;
  }

  for (const key of [
    "canonicalPathologyKey",
    "canonicalKey",
    "pathologyKey",
    "identityKey",
    "key",
  ]) {
    const value = identity[key];
    if (typeof value === "string" && value.trim()) {
      return value.trim();
    }
  }

  return null;
}

function buildPhase7ExactIdentityIndex(seed) {
  const identities = Array.isArray(seed?.identities)
    ? seed.identities
    : [];

  const protocols = Array.isArray(seed?.protocols)
    ? seed.protocols
    : [];

  const protocolsByPathology = new Map();
  const protocolsByProtocolKey = new Map();

  for (const protocol of protocols) {
    if (!protocol || typeof protocol !== "object") {
      continue;
    }

    if (
      typeof protocol.canonicalPathologyKey === "string" &&
      protocol.canonicalPathologyKey
    ) {
      protocolsByPathology.set(
        protocol.canonicalPathologyKey,
        protocol,
      );
    }

    if (
      typeof protocol.protocolKey === "string" &&
      protocol.protocolKey
    ) {
      protocolsByProtocolKey.set(
        protocol.protocolKey,
        protocol,
      );
    }
  }

  const aliases = new Map();
  let aliasValueCount = 0;

  for (const identity of identities) {
    const identityKey = canonicalIdentityKey(identity);
    const values = Array.from(
      new Set(collectAliasStrings(identity)),
    );

    if (!identityKey || values.length === 0) {
      continue;
    }

    for (const alias of values) {
      const normalized = normalizeExactIdentityText(alias);
      if (!normalized) {
        continue;
      }

      aliasValueCount += 1;

      if (!aliases.has(normalized)) {
        aliases.set(normalized, []);
      }

      aliases.get(normalized).push({
        identityKey,
        identity,
      });
    }
  }

  function resolveExactAlias(alias) {
    const normalized = normalizeExactIdentityText(alias);

    if (!normalized) {
      return Object.freeze({
        resolved: false,
        reason: "empty_alias",
      });
    }

    const matches = aliases.get(normalized) || [];

    const uniqueKeys = Array.from(
      new Set(matches.map((match) => match.identityKey)),
    );

    if (uniqueKeys.length === 0) {
      return Object.freeze({
        resolved: false,
        reason: "alias_not_found",
        normalizedAlias: normalized,
      });
    }

    if (uniqueKeys.length !== 1) {
      return Object.freeze({
        resolved: false,
        reason: "alias_ambiguous",
        normalizedAlias: normalized,
        candidateKeys: Object.freeze(uniqueKeys.slice().sort()),
      });
    }

    const identityKey = uniqueKeys[0];

    const protocol =
      protocolsByPathology.get(identityKey) ||
      protocolsByProtocolKey.get(identityKey) ||
      null;

    if (!protocol) {
      return Object.freeze({
        resolved: false,
        reason: "identity_has_no_protocol_mapping",
        normalizedAlias: normalized,
        identityKey,
      });
    }

    return deepFreeze({
      resolved: true,
      reason: "exact_phase7_alias_match",
      normalizedAlias: normalized,
      identityKey,
      canonicalPathologyKey:
        protocol.canonicalPathologyKey || null,
      protocolKey: protocol.protocolKey || null,
    });
  }

  return Object.freeze({
    schemaVersion: "clinical_phase7_exact_identity_index_v1",
    identityCount: identities.length,
    protocolCount: protocols.length,
    aliasValueCount,
    resolveExactAlias,
  });
}

function deepFreeze(value) {
  if (!value || typeof value !== "object" || Object.isFrozen(value)) {
    return value;
  }

  Object.freeze(value);

  for (const child of Object.values(value)) {
    deepFreeze(child);
  }

  return value;
}

module.exports = {
  normalizeExactIdentityText,
  collectAliasStrings,
  canonicalIdentityKey,
  buildPhase7ExactIdentityIndex,
};
