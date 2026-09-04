"use strict";

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

function nonEmptyString(value) {
  return typeof value === "string" && value.trim()
    ? value.trim()
    : null;
}

function createPhase7ProtocolLoader(seed) {
  const protocols = Array.isArray(seed?.protocols)
    ? seed.protocols
    : [];

  const byProtocolKey = new Map();
  const byPathologyKey = new Map();

  for (const raw of protocols) {
    if (!raw || typeof raw !== "object") {
      continue;
    }

    const protocol = deepFreeze({ ...raw });
    const protocolKey = nonEmptyString(protocol.protocolKey);
    const pathologyKey =
      nonEmptyString(protocol.canonicalPathologyKey);

    if (protocolKey) {
      if (byProtocolKey.has(protocolKey)) {
        throw new Error(
          `duplicate_protocol_key:${protocolKey}`,
        );
      }
      byProtocolKey.set(protocolKey, protocol);
    }

    if (pathologyKey) {
      if (byPathologyKey.has(pathologyKey)) {
        throw new Error(
          `duplicate_pathology_key:${pathologyKey}`,
        );
      }
      byPathologyKey.set(pathologyKey, protocol);
    }
  }

  function load({
    protocolKey = null,
    canonicalPathologyKey = null,
  } = {}) {
    const pKey = nonEmptyString(protocolKey);
    const cKey = nonEmptyString(canonicalPathologyKey);

    const byP = pKey ? byProtocolKey.get(pKey) || null : null;
    const byC = cKey ? byPathologyKey.get(cKey) || null : null;

    if (!pKey && !cKey) {
      return deepFreeze({
        resolved: false,
        reason: "protocol_lookup_key_missing",
      });
    }

    if (pKey && !byP) {
      return deepFreeze({
        resolved: false,
        reason: "protocol_key_not_found",
        protocolKey: pKey,
      });
    }

    if (cKey && !byC) {
      return deepFreeze({
        resolved: false,
        reason: "pathology_key_not_found",
        canonicalPathologyKey: cKey,
      });
    }

    if (byP && byC && byP !== byC) {
      return deepFreeze({
        resolved: false,
        reason: "protocol_pathology_key_mismatch",
        protocolKey: pKey,
        canonicalPathologyKey: cKey,
      });
    }

    const protocol = byP || byC;

    return deepFreeze({
      resolved: true,
      reason: "phase7_protocol_resolved",
      protocolKey:
        nonEmptyString(protocol.protocolKey),
      canonicalPathologyKey:
        nonEmptyString(protocol.canonicalPathologyKey),
      protocol,
    });
  }

  return Object.freeze({
    schemaVersion: "clinical_phase7_protocol_loader_v1",
    protocolCount: protocols.length,
    protocolKeyCount: byProtocolKey.size,
    canonicalPathologyKeyCount: byPathologyKey.size,
    load,
  });
}

module.exports = {
  createPhase7ProtocolLoader,
};
