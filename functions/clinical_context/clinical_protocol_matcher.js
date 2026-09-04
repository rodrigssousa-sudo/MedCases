"use strict";

const {
  ClinicalCaseIdentityResolver,
} = require("./clinical_case_identity_resolver");

/**
 * Global protocol selector.
 *
 * It consumes remote-registry descriptors and fails closed on ambiguity.
 * It contains no treatment-specific logic and no pathology-specific branches.
 */
class ClinicalProtocolMatcher {
  constructor({ identityResolver } = {}) {
    this.identityResolver =
      identityResolver || new ClinicalCaseIdentityResolver();
  }

  match({
    input,
    identities,
    protocols,
    activeCaseAnchor = "",
  }) {
    const identity = this.identityResolver.resolve({
      input,
      descriptors: identities,
      activeCaseAnchor,
    });

    if (identity.ambiguous) {
      return result(identity, null, identity.confidence, true, "identity_ambiguous");
    }

    if (!identity.canonicalKey) {
      return result(identity, null, 0, false, "identity_unresolved");
    }

    const candidates = (protocols || [])
      .filter((protocol) =>
        protocol &&
        protocol.enabled !== false &&
        String(protocol.canonicalPathologyKey || "") === identity.canonicalKey
      )
      .slice()
      .sort((a, b) => {
        const priorityDelta = Number(b.priority || 0) - Number(a.priority || 0);
        if (priorityDelta !== 0) return priorityDelta;
        return String(a.protocolKey || "").localeCompare(String(b.protocolKey || ""));
      });

    if (!candidates.length) {
      return result(
        identity,
        null,
        identity.confidence,
        false,
        "protocol_not_found_for_identity",
      );
    }

    const top = candidates[0];
    const topPriority = Number(top.priority || 0);
    const ties = candidates.filter(
      (protocol) => Number(protocol.priority || 0) === topPriority,
    );

    if (ties.length > 1) {
      return result(
        identity,
        null,
        identity.confidence,
        true,
        "protocol_priority_tie",
      );
    }

    return result(
      identity,
      top,
      identity.confidence,
      false,
      "canonical_identity_protocol_match",
    );
  }
}

function result(identity, protocol, confidence, ambiguous, reason) {
  return {
    identity,
    protocol,
    confidence,
    ambiguous,
    reason,
    found: Boolean(protocol && !ambiguous),
  };
}

module.exports = {
  ClinicalProtocolMatcher,
};
