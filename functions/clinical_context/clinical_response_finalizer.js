"use strict";

/**
 * Provider-agnostic finalization barrier.
 *
 * Input may arrive from a streaming provider internally, but nothing becomes
 * presentable until generation has completed, validation has succeeded and the
 * final text has been frozen into a committed object.
 */
class ClinicalResponseFinalizer {
  constructor({
    validator,
    repairer = null,
  } = {}) {
    if (typeof validator !== "function") {
      throw new Error("clinical_response_validator_required");
    }
    if (repairer != null && typeof repairer !== "function") {
      throw new Error("clinical_response_repairer_must_be_function");
    }
    this.validator = validator;
    this.repairer = repairer;
  }

  async finalize({
    generatedText,
    context = {},
  }) {
    const original = normalizeText(generatedText);
    if (!original) {
      return {
        ok: false,
        committed: false,
        text: "",
        validation: { ok: false, reason: "empty_generation" },
        repaired: false,
        reason: "empty_generation",
      };
    }

    let candidate = original;
    let validation = await this.validator({
      text: candidate,
      context,
    });

    if (!validation || validation.ok !== true) {
      if (!this.repairer) {
        return {
          ok: false,
          committed: false,
          text: "",
          validation: sanitizeValidation(validation),
          repaired: false,
          reason: String(validation?.reason || "validation_failed"),
        };
      }

      const repaired = normalizeText(
        await this.repairer({
          text: candidate,
          context,
          validation,
        }),
      );

      if (!repaired) {
        return {
          ok: false,
          committed: false,
          text: "",
          validation: sanitizeValidation(validation),
          repaired: true,
          reason: "repair_empty",
        };
      }

      candidate = repaired;
      validation = await this.validator({
        text: candidate,
        context,
      });

      if (!validation || validation.ok !== true) {
        return {
          ok: false,
          committed: false,
          text: "",
          validation: sanitizeValidation(validation),
          repaired: true,
          reason: String(validation?.reason || "validation_failed_after_repair"),
        };
      }

      return commit(candidate, validation, true);
    }

    return commit(candidate, validation, false);
  }
}

function commit(text, validation, repaired) {
  return Object.freeze({
    ok: true,
    committed: true,
    text,
    validation: Object.freeze(sanitizeValidation(validation)),
    repaired,
    reason: "validated_and_committed",
    presentationBarrier: Object.freeze({
      providerOutputVisibleBeforeCommit: false,
      visibleTextMutableAfterCommit: false,
      localProgressiveRevealAllowed: true,
    }),
  });
}

function sanitizeValidation(value) {
  if (!value || typeof value !== "object") return { ok: false };
  const out = {
    ok: value.ok === true,
    reason: String(value.reason || ""),
  };
  if (Array.isArray(value.issues)) {
    out.issues = value.issues.map((x) => String(x || "")).filter(Boolean);
  }
  return out;
}

function normalizeText(value) {
  return String(value || "").replace(/\r\n/g, "\n").trim();
}

module.exports = {
  ClinicalResponseFinalizer,
};
