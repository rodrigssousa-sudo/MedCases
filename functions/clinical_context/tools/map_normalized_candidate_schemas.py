#!/usr/bin/env python3
import argparse
import hashlib
import json
import re
from collections import Counter, defaultdict
from pathlib import Path


FIELD_PATTERN = re.compile(
    r"\b(classification|classificacao|clasificacion|score|stage|staging|"
    r"management|treatment|tratamento|tratamiento|manejo|conduta|conducta|"
    r"nextAction|nextActions|continuation|primaryAction|classificationAction|"
    r"contentRef|classificationTable|scoreTable|stageTable)\b\s*[:=]\s*",
    re.I,
)


def sha_text(value):
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def scalar_type(value):
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "bool"
    if isinstance(value, int) and not isinstance(value, bool):
        return "int"
    if isinstance(value, float):
        return "double"
    if isinstance(value, str):
        return "string"
    return type(value).__name__


def structural_signature(value):
    if isinstance(value, dict):
        keys = sorted(str(k) for k in value.keys())
        child = {
            str(k): structural_signature(value[k])
            for k in keys
        }
        return {
            "type": "map",
            "keys": keys,
            "children": child,
        }
    if isinstance(value, list):
        element_sigs = [structural_signature(x) for x in value]
        unique = {}
        for sig in element_sigs:
            key = json.dumps(sig, sort_keys=True, ensure_ascii=False)
            unique[key] = sig
        return {
            "type": "list",
            "length": len(value),
            "elementSchemas": sorted(
                unique.values(),
                key=lambda x: json.dumps(x, sort_keys=True, ensure_ascii=False),
            ),
        }
    return {"type": scalar_type(value)}


def signature_id(signature):
    raw = json.dumps(signature, sort_keys=True, ensure_ascii=False)
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()[:16]


def root_summary(value):
    if isinstance(value, dict):
        return {
            "rootType": "map",
            "keyCount": len(value),
            "keys": sorted(str(k) for k in value.keys()),
        }
    if isinstance(value, list):
        element_types = Counter()
        for item in value:
            if isinstance(item, dict):
                element_types["map"] += 1
            elif isinstance(item, list):
                element_types["list"] += 1
            else:
                element_types[scalar_type(item)] += 1
        return {
            "rootType": "list",
            "length": len(value),
            "elementTypeCounts": dict(sorted(element_types.items())),
        }
    return {"rootType": scalar_type(value)}


def localization_signals(value):
    signals = Counter()

    def walk(node):
        if isinstance(node, dict):
            keys = {str(k).casefold() for k in node.keys()}
            if "pt" in keys:
                signals["pt_key"] += 1
            if "es" in keys:
                signals["es_key"] += 1
            if "en" in keys:
                signals["en_key"] += 1
            if {"pt", "es"}.issubset(keys):
                signals["pt_es_pair"] += 1
            for child in node.values():
                walk(child)
        elif isinstance(node, list):
            for child in node:
                walk(child)

    walk(value)
    return dict(sorted(signals.items()))


def build_schema_report(candidates):
    families = defaultdict(lambda: {
        "count": 0,
        "fieldNames": Counter(),
        "groups": Counter(),
        "canonicalPathologyKeys": [],
        "rootSummaries": Counter(),
        "localizationSignals": Counter(),
    })

    group_totals = Counter()
    group_family_ids = defaultdict(set)

    for item in candidates["candidates"]:
        if not item["literalParseOk"]:
            continue

        value = item["normalizedLiteral"]
        signature = structural_signature(value)
        sid = signature_id(signature)

        family = families[sid]
        family["count"] += 1
        family["fieldNames"][item["fieldName"]] += 1
        for group in item["groups"]:
            family["groups"][group] += 1
            group_totals[group] += 1
            group_family_ids[group].add(sid)

        family["canonicalPathologyKeys"].append(item["canonicalPathologyKey"])
        rs = json.dumps(root_summary(value), sort_keys=True, ensure_ascii=False)
        family["rootSummaries"][rs] += 1

        for key, count in localization_signals(value).items():
            family["localizationSignals"][key] += count

        family["signature"] = signature

    normalized = []
    for sid, family in families.items():
        normalized.append({
            "schemaFamilyId": sid,
            "count": family["count"],
            "fieldNameCounts": dict(sorted(family["fieldNames"].items())),
            "groupCounts": dict(sorted(family["groups"].items())),
            "canonicalPathologyKeys": sorted(family["canonicalPathologyKeys"]),
            "rootSummaryCounts": {
                key: value
                for key, value in sorted(family["rootSummaries"].items())
            },
            "localizationSignals": dict(sorted(family["localizationSignals"].items())),
            "signature": family["signature"],
            "clinicalSemanticMappingPerformed": False,
        })

    normalized.sort(key=lambda x: (-x["count"], x["schemaFamilyId"]))

    report = {
        "schemaVersion": "clinical_registry_candidate_schema_families_v1",
        "cutoverReady": False,
        "finalRegistryDocuments": False,
        "clinicalSemanticMappingPerformed": False,
        "candidateCount": candidates["candidateCount"],
        "literalParseSuccessCount": candidates["literalParseSuccessCount"],
        "schemaFamilyCount": len(normalized),
        "groupCandidateCounts": dict(sorted(group_totals.items())),
        "groupSchemaFamilyCounts": {
            group: len(ids)
            for group, ids in sorted(group_family_ids.items())
        },
        "schemaFamilies": normalized,
    }
    return report


def match_balanced_expression(text, start):
    i = start
    while i < len(text) and text[i].isspace():
        i += 1
    expr_start = i

    quote = None
    line_comment = False
    block_comment = False
    paren = bracket = brace = 0
    started = False

    while i < len(text):
        ch = text[i]
        nxt = text[i + 1] if i + 1 < len(text) else ""

        if line_comment:
            if ch == "\n":
                line_comment = False
                if paren == bracket == brace == 0 and started:
                    break
            i += 1
            continue

        if block_comment:
            if ch == "*" and nxt == "/":
                block_comment = False
                i += 2
            else:
                i += 1
            continue

        if quote:
            if ch == "\\":
                i += 2
                continue
            if ch == quote:
                quote = None
            i += 1
            continue

        if ch == "/" and nxt == "/":
            line_comment = True
            i += 2
            continue
        if ch == "/" and nxt == "*":
            block_comment = True
            i += 2
            continue
        if ch in ("'", '"'):
            quote = ch
            started = True
            i += 1
            continue

        if ch == "(":
            paren += 1
            started = True
        elif ch == ")":
            if paren > 0:
                paren -= 1
            elif started and bracket == brace == 0:
                break
        elif ch == "[":
            bracket += 1
            started = True
        elif ch == "]":
            if bracket > 0:
                bracket -= 1
        elif ch == "{":
            brace += 1
            started = True
        elif ch == "}":
            if brace > 0:
                brace -= 1
        elif ch in (",", ";") and paren == bracket == brace == 0 and started:
            break
        elif not ch.isspace():
            started = True

        i += 1

    return text[expr_start:i].strip(), expr_start, i


def compile_owner_proofs(owner_audit):
    proofs = []

    for owner in owner_audit["owners"]:
        path = owner["file"]
        text = Path(path).read_text(encoding="utf-8", errors="strict")

        expected_structured = [
            signal for signal in owner["structuredSignals"]
            if signal["shapeSignal"] in ("list_literal_signal", "map_literal_signal")
        ]

        discovered = []
        for match in FIELD_PATTERN.finditer(text):
            field = match.group(1)
            expr, expr_start, expr_end = match_balanced_expression(text, match.end())
            stripped = expr.lstrip()

            shape = "other"
            if stripped.startswith("[") or re.match(r"^const\s+(?:<[^>]+>\s*)?\[", stripped):
                shape = "list_literal_signal"
            elif stripped.startswith("{") or re.match(r"^const\s+(?:<[^>]+>\s*)?\{", stripped):
                shape = "map_literal_signal"
            elif stripped.startswith(("'", '"', "r'", 'r"')):
                shape = "string_signal"

            if shape in ("list_literal_signal", "map_literal_signal"):
                discovered.append({
                    "field": field,
                    "line": text.count("\n", 0, match.start()) + 1,
                    "shapeSignal": shape,
                    "expressionSha256": sha_text(expr),
                    "expressionLength": len(expr),
                    "sourceExpression": expr,
                    "sourceFileSha256": sha_text(text),
                })

        # Source proof must reconcile at least the audit's count; if the exact
        # scanner now finds more, retain all with fingerprints.
        if len(discovered) < len(expected_structured):
            raise RuntimeError(
                f"owner_structured_signal_reconciliation_failed:{path}:"
                f"expected>={len(expected_structured)}:found={len(discovered)}"
            )

        proofs.append({
            "file": path,
            "auditStructuredSignalCount": len(expected_structured),
            "proofCount": len(discovered),
            "proofs": discovered,
        })

    return {
        "schemaVersion": "clinical_registry_additional_owner_source_proofs_v1",
        "cutoverReady": False,
        "clinicalSemanticMappingPerformed": False,
        "finalRegistryDocuments": False,
        "ownerCount": len(proofs),
        "totalProofCount": sum(item["proofCount"] for item in proofs),
        "owners": proofs,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidates", required=True)
    parser.add_argument("--owner-audit", required=True)
    parser.add_argument("--phase3", required=True)
    parser.add_argument("--schema-report", required=True)
    parser.add_argument("--owner-proofs", required=True)
    parser.add_argument("--phase4", required=True)
    args = parser.parse_args()

    candidates = json.loads(Path(args.candidates).read_text(encoding="utf-8"))
    owner_audit = json.loads(Path(args.owner_audit).read_text(encoding="utf-8"))
    phase3 = json.loads(Path(args.phase3).read_text(encoding="utf-8"))

    schema_report = build_schema_report(candidates)
    owner_proofs = compile_owner_proofs(owner_audit)

    phase4 = dict(phase3)
    phase4["schemaVersion"] = "clinical_registry_seed_phase4_schema_proofs_v1"
    phase4["phase"] = "identity_protocol_plus_schema_and_owner_proofs"
    phase4["cutoverReady"] = False
    phase4["schemaProofBundle"] = {
        "schemaVersion": schema_report["schemaVersion"],
        "schemaFamilyCount": schema_report["schemaFamilyCount"],
        "groupSchemaFamilyCounts": schema_report["groupSchemaFamilyCounts"],
        "clinicalSemanticMappingPerformed": False,
        "finalRegistryDocuments": False,
    }
    phase4["additionalOwnerProofBundle"] = {
        "schemaVersion": owner_proofs["schemaVersion"],
        "ownerCount": owner_proofs["ownerCount"],
        "totalProofCount": owner_proofs["totalProofCount"],
        "clinicalSemanticMappingPerformed": False,
        "finalRegistryDocuments": False,
    }

    Path(args.schema_report).write_text(
        json.dumps(schema_report, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    Path(args.owner_proofs).write_text(
        json.dumps(owner_proofs, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    Path(args.phase4).write_text(
        json.dumps(phase4, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    print("SCHEMA_FAMILY_COUNT="+str(schema_report["schemaFamilyCount"]))
    for group in ("classification", "management", "action", "content"):
        print(
            "GROUP_"+group.upper()+"_SCHEMA_FAMILY_COUNT="+
            str(schema_report["groupSchemaFamilyCounts"].get(group, 0))
        )

    print("SCHEMA_FAMILY_TOP_BEGIN")
    for family in schema_report["schemaFamilies"][:20]:
        print(
            "SCHEMA_FAMILY|id="+family["schemaFamilyId"]+
            "|count="+str(family["count"])+
            "|fields="+",".join(sorted(family["fieldNameCounts"].keys()))+
            "|groups="+",".join(sorted(family["groupCounts"].keys()))+
            "|localization="+json.dumps(
                family["localizationSignals"],
                sort_keys=True,
                separators=(",",":"),
            )
        )
    print("SCHEMA_FAMILY_TOP_END")

    print("OWNER_SOURCE_PROOFS_BEGIN")
    for owner in owner_proofs["owners"]:
        print(
            "OWNER_PROOF|file="+owner["file"]+
            "|auditStructuredSignals="+str(owner["auditStructuredSignalCount"])+
            "|proofs="+str(owner["proofCount"])
        )
        for proof in owner["proofs"]:
            print(
                "OWNER_FIELD_PROOF|file="+owner["file"]+
                "|field="+proof["field"]+
                "|line="+str(proof["line"])+
                "|shape="+proof["shapeSignal"]+
                "|exprSha="+proof["expressionSha256"][:16]
            )
    print("OWNER_SOURCE_PROOFS_END")
    print("ADDITIONAL_OWNER_TOTAL_SOURCE_PROOF_COUNT="+str(owner_proofs["totalProofCount"]))
    print("CLINICAL_SEMANTIC_MAPPING_PERFORMED=NO")
    print("FINAL_REGISTRY_DOCUMENTS_CREATED=NO")
    print("PHASE4_CUTOVER_READY=NO")


if __name__ == "__main__":
    main()
