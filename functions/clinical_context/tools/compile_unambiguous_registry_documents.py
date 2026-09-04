#!/usr/bin/env python3
import argparse
import hashlib
import json
from collections import Counter, defaultdict
from pathlib import Path


CLASS_MODES = {"categorical", "score", "stage"}
ACTION_TYPES = {"dispatch_prompt", "open_content_ref"}
ACTION_KINDS = {"primary", "classification", "score", "stage"}


def stable_id(*parts):
    raw = "::".join(str(x) for x in parts)
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()[:16]


def keyset(value):
    if isinstance(value, dict):
        return tuple(sorted(str(k) for k in value.keys()))
    return tuple()


def is_localized_object(value):
    return (
        isinstance(value, dict)
        and "pt" in value
        and "es" in value
    )


def has_machine_classification_schema(value):
    if not isinstance(value, dict):
        return False, "classification_root_not_map"

    mode = str(value.get("mode", "")).lower()
    if mode not in CLASS_MODES:
        return False, "classification_mode_missing_or_invalid"

    if mode == "categorical":
        categories = value.get("categories")
        if not isinstance(categories, list) or not categories:
            return False, "categorical_categories_missing"
        for category in categories:
            if not isinstance(category, dict):
                return False, "categorical_category_not_map"
            if not str(category.get("key", "")).strip():
                return False, "categorical_category_key_missing"
            if not (
                isinstance(category.get("criteria"), (dict, list))
                or isinstance(category.get("when"), (dict, list))
            ):
                return False, "categorical_machine_criteria_missing"

    elif mode == "score":
        components = value.get("components")
        bands = value.get("bands")
        if not isinstance(components, list) or not components:
            return False, "score_components_missing"
        if not isinstance(bands, list) or not bands:
            return False, "score_bands_missing"

    elif mode == "stage":
        stages = value.get("stages")
        if not isinstance(stages, list) or not stages:
            return False, "stage_stages_missing"
        for stage in stages:
            if not isinstance(stage, dict):
                return False, "stage_item_not_map"
            if not str(stage.get("key", "")).strip():
                return False, "stage_key_missing"
            if not (
                isinstance(stage.get("criteria"), (dict, list))
                or isinstance(stage.get("when"), (dict, list))
            ):
                return False, "stage_machine_criteria_missing"

    return True, "qualified"


def compile_classification(item):
    value = item["normalizedLiteral"]
    ok, reason = has_machine_classification_schema(value)
    if not ok:
        return None, reason

    mode = str(value["mode"]).lower()
    key = (
        str(value.get("classificationKey") or "").strip()
        or f"source::{item['canonicalPathologyKey']}::{item['fieldName']}"
    )

    document = {
        "classificationKey": key,
        "canonicalPathologyKey": item["canonicalPathologyKey"],
        "mode": mode,
        "enabled": True,
        "priority": int(value.get("priority", 100)),
        "version": str(value.get("version") or item["blockSha256"][:12]),
        "requiredFacts": value.get("requiredFacts", []),
        "categories": value.get("categories", []),
        "components": value.get("components", []),
        "bands": value.get("bands", []),
        "stages": value.get("stages", []),
        "sourceProof": {
            "protocolKey": item["protocolKey"],
            "blockSha256": item["blockSha256"],
            "sourceExpressionSha256": item["sourceExpressionSha256"],
            "fieldName": item["fieldName"],
        },
    }
    return document, "qualified"


def has_machine_action_schema(value):
    documents = value if isinstance(value, list) else [value]
    if not documents:
        return False, "action_empty"

    for raw in documents:
        if not isinstance(raw, dict):
            return False, "action_item_not_map"

        action_type = str(raw.get("actionType", ""))
        kind = str(raw.get("kind", ""))

        if action_type not in ACTION_TYPES:
            return False, "actionType_missing_or_invalid"
        if kind not in ACTION_KINDS:
            return False, "action_kind_missing_or_invalid"

        if action_type == "dispatch_prompt":
            prompts = raw.get("prompts")
            prompt = raw.get("prompt")
            if not (
                isinstance(prompts, dict)
                and any(str(prompts.get(lang, "")).strip() for lang in ("pt", "es", "en"))
            ) and not str(prompt or "").strip():
                return False, "dispatch_prompt_payload_missing"

        if action_type == "open_content_ref":
            if not str(raw.get("contentRef", "")).strip():
                return False, "contentRef_missing"

    return True, "qualified"


def compile_actions(item):
    value = item["normalizedLiteral"]
    ok, reason = has_machine_action_schema(value)
    if not ok:
        return [], reason

    raws = value if isinstance(value, list) else [value]
    documents = []

    for index, raw in enumerate(raws):
        action_key = (
            str(raw.get("actionKey") or "").strip()
            or f"source::{item['canonicalPathologyKey']}::{item['fieldName']}::{index}"
        )
        document = {
            "actionKey": action_key,
            "kind": str(raw["kind"]),
            "actionType": str(raw["actionType"]),
            "enabled": bool(raw.get("enabled", True)),
            "priority": int(raw.get("priority", 100)),
            "version": str(raw.get("version") or item["blockSha256"][:12]),
            "labels": raw.get("labels", raw.get("label", {})),
            "prompts": raw.get("prompts", {}),
            "prompt": raw.get("prompt"),
            "contentRef": raw.get("contentRef"),
            "match": raw.get("match", {
                "canonicalPathologyKey": item["canonicalPathologyKey"],
            }),
            "sourceProof": {
                "protocolKey": item["protocolKey"],
                "blockSha256": item["blockSha256"],
                "sourceExpressionSha256": item["sourceExpressionSha256"],
                "fieldName": item["fieldName"],
            },
        }
        documents.append(document)

    return documents, "qualified"


def has_renderable_content_schema(value):
    if not isinstance(value, dict):
        return False, "content_root_not_map"

    if "sections" in value:
        sections = value.get("sections")
        if not isinstance(sections, list):
            return False, "content_sections_not_list"
        for section in sections:
            if not isinstance(section, dict):
                return False, "content_section_not_map"
            if "rows" in section and not isinstance(section.get("rows"), list):
                return False, "content_rows_not_list"
        return True, "qualified"

    if is_localized_object(value):
        for lang in ("pt", "es"):
            localized = value[lang]
            if not isinstance(localized, dict):
                return False, "localized_content_not_map"
            if "sections" not in localized or not isinstance(localized["sections"], list):
                return False, "localized_content_sections_missing"
        return True, "qualified"

    return False, "renderable_content_schema_missing"


def compile_content(item):
    value = item["normalizedLiteral"]
    ok, reason = has_renderable_content_schema(value)
    if not ok:
        return None, reason

    content_key = f"source::{item['canonicalPathologyKey']}::{item['fieldName']}"
    document = {
        "contentKey": content_key,
        "enabled": True,
        "version": item["blockSha256"][:12],
        "payload": value,
        "sourceProof": {
            "protocolKey": item["protocolKey"],
            "blockSha256": item["blockSha256"],
            "sourceExpressionSha256": item["sourceExpressionSha256"],
            "fieldName": item["fieldName"],
        },
    }
    return document, "qualified"


def has_machine_management_schema(value):
    documents = value if isinstance(value, list) else [value]
    if not documents:
        return False, "management_empty"

    for raw in documents:
        if not isinstance(raw, dict):
            return False, "management_item_not_map"

        dependency = raw.get("dependsOn")
        if not isinstance(dependency, dict):
            return False, "management_dependsOn_missing"

        if not (
            str(dependency.get("classificationKey", "")).strip()
            or str(dependency.get("categoryKey", "")).strip()
            or str(dependency.get("scoreBandKey", "")).strip()
            or str(dependency.get("stageKey", "")).strip()
        ):
            return False, "management_dependency_key_missing"

        if not any(
            key in raw
            for key in ("management", "recommendations", "treatment", "actions", "payload")
        ):
            return False, "management_payload_missing"

    return True, "qualified"


def compile_management(item):
    value = item["normalizedLiteral"]
    ok, reason = has_machine_management_schema(value)
    if not ok:
        return [], reason

    raws = value if isinstance(value, list) else [value]
    documents = []

    for index, raw in enumerate(raws):
        key = (
            str(raw.get("managementRuleKey") or "").strip()
            or f"source::{item['canonicalPathologyKey']}::{item['fieldName']}::{index}"
        )
        document = {
            "managementRuleKey": key,
            "canonicalPathologyKey": item["canonicalPathologyKey"],
            "enabled": bool(raw.get("enabled", True)),
            "priority": int(raw.get("priority", 100)),
            "version": str(raw.get("version") or item["blockSha256"][:12]),
            "dependsOn": raw["dependsOn"],
            "payload": raw.get(
                "payload",
                raw.get(
                    "management",
                    raw.get(
                        "recommendations",
                        raw.get("treatment", raw.get("actions")),
                    ),
                ),
            ),
            "sourceProof": {
                "protocolKey": item["protocolKey"],
                "blockSha256": item["blockSha256"],
                "sourceExpressionSha256": item["sourceExpressionSha256"],
                "fieldName": item["fieldName"],
            },
        }
        documents.append(document)

    return documents, "qualified"


def qualify_candidates(candidates):
    compiled = {
        "classifications": [],
        "managementRules": [],
        "actions": [],
        "content": [],
    }
    decisions = []
    reason_counts = Counter()
    group_qualified = Counter()
    keyset_counts = defaultdict(Counter)

    for item in candidates["candidates"]:
        if not item["literalParseOk"]:
            decisions.append({
                "canonicalPathologyKey": item["canonicalPathologyKey"],
                "fieldName": item["fieldName"],
                "groups": item["groups"],
                "qualified": False,
                "reason": "literal_parse_failed",
            })
            reason_counts["literal_parse_failed"] += 1
            continue

        value = item["normalizedLiteral"]
        ks = ",".join(keyset(value)) if isinstance(value, dict) else f"<{type(value).__name__}>"
        for group in item["groups"]:
            keyset_counts[group][ks] += 1

        group_results = []
        any_qualified = False

        for group in item["groups"]:
            if group == "classification":
                doc, reason = compile_classification(item)
                if doc is not None:
                    compiled["classifications"].append(doc)
                    group_qualified[group] += 1
                    any_qualified = True
                group_results.append({"group": group, "qualified": doc is not None, "reason": reason})

            elif group == "action":
                docs, reason = compile_actions(item)
                if docs:
                    compiled["actions"].extend(docs)
                    group_qualified[group] += 1
                    any_qualified = True
                group_results.append({"group": group, "qualified": bool(docs), "reason": reason})

            elif group == "content":
                doc, reason = compile_content(item)
                if doc is not None:
                    compiled["content"].append(doc)
                    group_qualified[group] += 1
                    any_qualified = True
                group_results.append({"group": group, "qualified": doc is not None, "reason": reason})

            elif group == "management":
                docs, reason = compile_management(item)
                if docs:
                    compiled["managementRules"].extend(docs)
                    group_qualified[group] += 1
                    any_qualified = True
                group_results.append({"group": group, "qualified": bool(docs), "reason": reason})

        if not any_qualified:
            for result in group_results:
                reason_counts[f"{result['group']}::{result['reason']}"] += 1

        decisions.append({
            "canonicalPathologyKey": item["canonicalPathologyKey"],
            "protocolKey": item["protocolKey"],
            "fieldName": item["fieldName"],
            "groups": item["groups"],
            "qualified": any_qualified,
            "groupResults": group_results,
            "rootType": (
                "map" if isinstance(value, dict)
                else "list" if isinstance(value, list)
                else type(value).__name__
            ),
            "rootKeys": list(keyset(value)),
            "sourceExpressionSha256": item["sourceExpressionSha256"],
            "blockSha256": item["blockSha256"],
        })

    for key in compiled:
        id_field = {
            "classifications": "classificationKey",
            "managementRules": "managementRuleKey",
            "actions": "actionKey",
            "content": "contentKey",
        }[key]
        seen = set()
        unique = []
        for document in compiled[key]:
            doc_id = document[id_field]
            if doc_id in seen:
                raise RuntimeError(f"duplicate_compiled_{id_field}:{doc_id}")
            seen.add(doc_id)
            unique.append(document)
        compiled[key] = unique

    return compiled, decisions, reason_counts, group_qualified, keyset_counts


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidates", required=True)
    parser.add_argument("--schema-report", required=True)
    parser.add_argument("--owner-proofs", required=True)
    parser.add_argument("--phase4", required=True)
    parser.add_argument("--qualification", required=True)
    parser.add_argument("--compiled", required=True)
    parser.add_argument("--phase5", required=True)
    args = parser.parse_args()

    candidates = json.loads(Path(args.candidates).read_text(encoding="utf-8"))
    schema_report = json.loads(Path(args.schema_report).read_text(encoding="utf-8"))
    owner_proofs = json.loads(Path(args.owner_proofs).read_text(encoding="utf-8"))
    phase4 = json.loads(Path(args.phase4).read_text(encoding="utf-8"))

    compiled, decisions, reasons, group_qualified, keysets = qualify_candidates(candidates)

    qualification = {
        "schemaVersion": "clinical_registry_unambiguous_qualification_v1",
        "cutoverReady": False,
        "clinicalSemanticInferencePerformed": False,
        "descriptivePtEsOnlyPromotionAllowed": False,
        "candidateCount": candidates["candidateCount"],
        "qualifiedCandidateCount": sum(1 for item in decisions if item["qualified"]),
        "rejectedCandidateCount": sum(1 for item in decisions if not item["qualified"]),
        "groupQualifiedCandidateCounts": dict(sorted(group_qualified.items())),
        "rejectionReasonCounts": dict(sorted(reasons.items())),
        "groupRootKeysetCounts": {
            group: dict(sorted(counts.items()))
            for group, counts in sorted(keysets.items())
        },
        "decisions": decisions,
        "schemaFamilySource": {
            "schemaVersion": schema_report["schemaVersion"],
            "schemaFamilyCount": schema_report["schemaFamilyCount"],
        },
        "ownerProofSource": {
            "schemaVersion": owner_proofs["schemaVersion"],
            "totalProofCount": owner_proofs["totalProofCount"],
        },
    }

    compiled_bundle = {
        "schemaVersion": "clinical_registry_unambiguous_compiled_v1",
        "cutoverReady": False,
        "cloudWriteReady": False,
        "clinicalSemanticInferencePerformed": False,
        "classifications": compiled["classifications"],
        "managementRules": compiled["managementRules"],
        "actions": compiled["actions"],
        "content": compiled["content"],
    }

    phase5 = dict(phase4)
    phase5["schemaVersion"] = "clinical_registry_seed_phase5_unambiguous_v1"
    phase5["phase"] = "identity_protocol_plus_unambiguous_compiled_docs"
    phase5["cutoverReady"] = False
    phase5["classifications"] = compiled["classifications"]
    phase5["managementRules"] = compiled["managementRules"]
    phase5["actions"] = compiled["actions"]
    phase5["content"] = compiled["content"]
    phase5["unambiguousCompilation"] = {
        "qualifiedCandidateCount": qualification["qualifiedCandidateCount"],
        "rejectedCandidateCount": qualification["rejectedCandidateCount"],
        "cloudWriteReady": False,
        "clinicalSemanticInferencePerformed": False,
    }

    Path(args.qualification).write_text(
        json.dumps(qualification, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    Path(args.compiled).write_text(
        json.dumps(compiled_bundle, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    Path(args.phase5).write_text(
        json.dumps(phase5, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    print("ROOT_KEYSET_DISTRIBUTION_BEGIN")
    for group in ("classification", "management", "action", "content"):
        for ks, count in sorted(keysets.get(group, {}).items(), key=lambda x: (-x[1], x[0])):
            print(f"ROOT_KEYSET|group={group}|count={count}|keys={ks}")
    print("ROOT_KEYSET_DISTRIBUTION_END")

    print("REJECTION_REASON_DISTRIBUTION_BEGIN")
    for reason, count in sorted(reasons.items(), key=lambda x: (-x[1], x[0])):
        print(f"REJECT|count={count}|reason={reason}")
    print("REJECTION_REASON_DISTRIBUTION_END")

    print("QUALIFIED_CANDIDATE_COUNT="+str(qualification["qualifiedCandidateCount"]))
    print("REJECTED_CANDIDATE_COUNT="+str(qualification["rejectedCandidateCount"]))
    print("COMPILED_CLASSIFICATION_DOC_COUNT="+str(len(compiled["classifications"])))
    print("COMPILED_MANAGEMENT_RULE_DOC_COUNT="+str(len(compiled["managementRules"])))
    print("COMPILED_ACTION_DOC_COUNT="+str(len(compiled["actions"])))
    print("COMPILED_CONTENT_DOC_COUNT="+str(len(compiled["content"])))
    print("DESCRIPTIVE_PT_ES_ONLY_PROMOTION=FORBIDDEN")
    print("CLINICAL_SEMANTIC_INFERENCE_PERFORMED=NO")
    print("PHASE5_CLOUD_WRITE_READY=NO")
    print("PHASE5_CUTOVER_READY=NO")


if __name__ == "__main__":
    main()
