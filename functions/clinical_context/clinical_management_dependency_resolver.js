"use strict";

/**
 * Converts remote classification/score/stage output into a remote management
 * rule selection. The executable code remains pathology-agnostic.
 *
 * If classification is required but unresolved, it returns only the facts
 * needed to continue. It never fabricates a category or silently falls back
 * to category-specific management.
 */
class ClinicalManagementDependencyResolver {
  resolve({
    pathologyKey,
    classificationResult,
    managementRules,
  }) {
    if (!pathologyKey) {
      return unresolved("pathology_key_missing");
    }

    const candidates = (managementRules || [])
      .filter((rule) =>
        rule &&
        rule.enabled !== false &&
        String(rule.canonicalPathologyKey || "") === String(pathologyKey)
      )
      .slice()
      .sort(comparePriority);

    if (!candidates.length) {
      return unresolved("management_rule_not_registered");
    }

    const classificationKey = String(
      classificationResult?.classificationKey || "",
    );
    const categoryKey = String(classificationResult?.categoryKey || "");
    const classificationResolved = Boolean(classificationResult?.resolved);

    const gated = candidates.filter((rule) => {
      const dependsOn = rule.dependsOn || {};
      const requiredClassificationKey = String(
        dependsOn.classificationKey || "",
      );
      const requiredCategoryKey = String(dependsOn.categoryKey || "");

      if (!requiredClassificationKey && !requiredCategoryKey) return true;

      if (!classificationResolved) return false;

      if (
        requiredClassificationKey &&
        requiredClassificationKey !== classificationKey
      ) {
        return false;
      }

      if (requiredCategoryKey && requiredCategoryKey !== categoryKey) {
        return false;
      }

      return true;
    });

    if (!classificationResolved) {
      const classificationDependent = candidates.some((rule) => {
        const dependsOn = rule.dependsOn || {};
        return Boolean(
          dependsOn.classificationKey ||
          dependsOn.categoryKey ||
          rule.requiresClassification === true
        );
      });

      if (classificationDependent) {
        return {
          ...unresolved("management_waiting_for_classification"),
          requiresClassification: true,
          missingFacts: Array.isArray(classificationResult?.missingFacts)
            ? [...classificationResult.missingFacts]
            : [],
          classificationKey,
        };
      }
    }

    if (!gated.length) {
      return unresolved("management_rule_no_match");
    }

    const topPriority = Number(gated[0].priority || 0);
    const tied = gated.filter(
      (rule) => Number(rule.priority || 0) === topPriority,
    );

    if (tied.length > 1) {
      return {
        ...unresolved("management_rule_priority_tie"),
        ambiguous: true,
      };
    }

    const rule = gated[0];
    return {
      resolved: true,
      ambiguous: false,
      managementRuleKey: String(rule.managementRuleKey || rule.id || ""),
      managementLabel: String(rule.label || ""),
      payload: plainObject(rule.payload),
      primaryActionRef: String(rule.primaryActionRef || ""),
      classificationActionRef: String(rule.classificationActionRef || ""),
      requiresClassification: Boolean(rule.requiresClassification),
      classificationKey,
      categoryKey,
      missingFacts: [],
      sourceVersion: String(rule.version || ""),
      reason: "management_rule_resolved",
    };
  }
}

function unresolved(reason) {
  return {
    resolved: false,
    ambiguous: false,
    managementRuleKey: "",
    managementLabel: "",
    payload: {},
    primaryActionRef: "",
    classificationActionRef: "",
    requiresClassification: false,
    classificationKey: "",
    categoryKey: "",
    missingFacts: [],
    sourceVersion: "",
    reason,
  };
}

function comparePriority(a, b) {
  const delta = Number(b.priority || 0) - Number(a.priority || 0);
  if (delta !== 0) return delta;
  return String(a.id || a.managementRuleKey || "").localeCompare(
    String(b.id || b.managementRuleKey || ""),
  );
}

function plainObject(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return { ...value };
}

module.exports = {
  ClinicalManagementDependencyResolver,
};
