#!/usr/bin/env python3
import argparse
import hashlib
import json
import re
from collections import Counter, defaultdict
from pathlib import Path


TARGET_FIELDS = ("classification", "actions")


def sha_text(value):
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def matching(text, open_pos, opener, closer):
    depth = 0
    quote = None
    line_comment = False
    block_comment = False
    i = open_pos

    while i < len(text):
        ch = text[i]
        nxt = text[i + 1] if i + 1 < len(text) else ""

        if line_comment:
            if ch == "\n":
                line_comment = False
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
            i += 1
            continue

        if ch == opener:
            depth += 1
        elif ch == closer:
            depth -= 1
            if depth == 0:
                return i

        i += 1

    return None


def discover_protocol_model_declaration(repo_lib):
    root = Path(repo_lib)
    matches = []

    for path in root.rglob("*.dart"):
        if ".dart_tool" in path.parts or "build" in path.parts:
            continue

        text = path.read_text(encoding="utf-8", errors="ignore")
        for match in re.finditer(r"\bclass\s+ProtocolModel\b", text):
            matches.append((path, text, match))

    if len(matches) != 1:
        candidates = [
            {
                "file": str(path),
                "line": text.count("\n", 0, match.start()) + 1,
            }
            for path, text, match in matches
        ]
        raise RuntimeError(
            "protocolmodel_declaration_owner_count:"
            + str(len(matches))
            + ":"
            + json.dumps(candidates, ensure_ascii=False, sort_keys=True)
        )

    path, text, match = matches[0]
    open_brace = text.find("{", match.end())
    if open_brace < 0:
        raise RuntimeError("protocolmodel_open_brace_missing")

    close_brace = matching(text, open_brace, "{", "}")
    if close_brace is None:
        raise RuntimeError("protocolmodel_unbalanced_brace")

    block = text[match.start():close_brace + 1]
    return {
        "file": str(path),
        "fileSha256": sha_text(text),
        "line": text.count("\n", 0, match.start()) + 1,
        "block": block,
        "blockSha256": sha_text(block),
    }


def declaration_contract(class_block):
    fields = {}
    constructors = []

    field_rx = re.compile(
        r"(?m)^\s*(?:final|late\s+final|const|var)?\s*"
        r"(?P<type>[A-Za-z_][A-Za-z0-9_<>, ?.]*)\s+"
        r"(?P<name>classification|actions)\s*;"
    )

    for match in field_rx.finditer(class_block):
        fields[match.group("name")] = {
            "declaredType": re.sub(r"\s+", " ", match.group("type")).strip(),
            "declarationSha256": sha_text(match.group(0)),
        }

    ctor_rx = re.compile(r"\bProtocolModel\s*\(")
    for match in ctor_rx.finditer(class_block):
        open_pos = class_block.find("(", match.start(), match.end() + 1)
        close_pos = matching(class_block, open_pos, "(", ")")
        if close_pos is None:
            continue
        ctor = class_block[match.start():close_pos + 1]
        constructors.append(ctor)

    ctor_info = {}
    for field in TARGET_FIELDS:
        evidence = []
        for ctor in constructors:
            for pattern in (
                rf"\brequired\s+this\.{field}\b",
                rf"\bthis\.{field}\b",
                rf"\brequired\s+[A-Za-z_][A-Za-z0-9_<>, ?.]*\s+{field}\b",
                rf"\b[A-Za-z_][A-Za-z0-9_<>, ?.]*\s+{field}\b",
            ):
                for match in re.finditer(pattern, ctor):
                    snippet = match.group(0)
                    evidence.append({
                        "snippet": snippet,
                        "sha256": sha_text(snippet),
                    })
        ctor_info[field] = evidence

    return {
        "fields": fields,
        "constructorCount": len(constructors),
        "constructorEvidence": ctor_info,
    }


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
        return {
            "type": "map",
            "keys": sorted(str(k) for k in value.keys()),
            "children": {
                str(k): structural_signature(value[k])
                for k in sorted(value.keys(), key=str)
            },
        }

    if isinstance(value, list):
        unique = {}
        for item in value:
            sig = structural_signature(item)
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


def pt_es_inner_families(candidates):
    families = defaultdict(lambda: {
        "count": 0,
        "fields": Counter(),
        "ptSignatureIds": Counter(),
        "esSignatureIds": Counter(),
        "parityCount": 0,
        "nonParityCount": 0,
        "pathologies": [],
    })

    records = []
    field_counts = Counter()
    parity_counts = Counter()

    for item in candidates["candidates"]:
        if item["fieldName"] not in TARGET_FIELDS:
            continue
        if not item["literalParseOk"]:
            raise RuntimeError("unexpected_unparsed_build10_candidate")

        root = item["normalizedLiteral"]
        if not isinstance(root, dict) or set(root.keys()) != {"pt", "es"}:
            raise RuntimeError(
                f"unexpected_root_contract:{item['fieldName']}:{sorted(root.keys()) if isinstance(root, dict) else type(root).__name__}"
            )

        pt_sig = structural_signature(root["pt"])
        es_sig = structural_signature(root["es"])
        pt_id = signature_id(pt_sig)
        es_id = signature_id(es_sig)
        parity = pt_sig == es_sig

        combined = {
            "field": item["fieldName"],
            "ptSignature": pt_sig,
            "esSignature": es_sig,
        }
        family_id = signature_id(combined)
        family = families[family_id]
        family["count"] += 1
        family["fields"][item["fieldName"]] += 1
        family["ptSignatureIds"][pt_id] += 1
        family["esSignatureIds"][es_id] += 1
        family["parityCount"] += int(parity)
        family["nonParityCount"] += int(not parity)
        family["pathologies"].append(item["canonicalPathologyKey"])

        field_counts[item["fieldName"]] += 1
        parity_counts[f"{item['fieldName']}::parity"] += int(parity)
        parity_counts[f"{item['fieldName']}::nonparity"] += int(not parity)

        records.append({
            "canonicalPathologyKey": item["canonicalPathologyKey"],
            "protocolKey": item["protocolKey"],
            "fieldName": item["fieldName"],
            "blockSha256": item["blockSha256"],
            "sourceExpressionSha256": item["sourceExpressionSha256"],
            "ptSignatureId": pt_id,
            "esSignatureId": es_id,
            "ptEsStructuralParity": parity,
            "innerFamilyId": family_id,
            "ptValue": root["pt"],
            "esValue": root["es"],
        })

    normalized_families = []
    for family_id, family in families.items():
        normalized_families.append({
            "innerFamilyId": family_id,
            "count": family["count"],
            "fieldNameCounts": dict(sorted(family["fields"].items())),
            "ptSignatureIdCounts": dict(sorted(family["ptSignatureIds"].items())),
            "esSignatureIdCounts": dict(sorted(family["esSignatureIds"].items())),
            "parityCount": family["parityCount"],
            "nonParityCount": family["nonParityCount"],
            "canonicalPathologyKeys": sorted(family["pathologies"]),
        })

    normalized_families.sort(key=lambda x: (-x["count"], x["innerFamilyId"]))
    records.sort(key=lambda x: (x["fieldName"], x["canonicalPathologyKey"]))

    return {
        "fieldCounts": dict(sorted(field_counts.items())),
        "parityCounts": dict(sorted(parity_counts.items())),
        "innerFamilyCount": len(normalized_families),
        "innerFamilies": normalized_families,
        "records": records,
    }


def scan_consumers(repo_root):
    root = Path(repo_root)
    files = [
        p for p in root.rglob("*.dart")
        if ".dart_tool" not in p.parts
        and "build" not in p.parts
    ]

    proofs = []
    operation_counts = Counter()
    target_occurrence_counts = Counter()

    patterns = {
        "classification": re.compile(r"\.classification\b"),
        "actions": re.compile(r"\.actions\b"),
    }

    for path in files:
        text = path.read_text(encoding="utf-8", errors="ignore")
        rel = str(path)

        for field, rx in patterns.items():
            for match in rx.finditer(text):
                line = text.count("\n", 0, match.start()) + 1
                before = text[max(0, match.start() - 180):match.start()]
                after = text[match.end():min(len(text), match.end() + 260)]
                context = before + "." + field + after

                operations = []
                if re.search(r"^\s*\[\s*['\"](?:pt|es)['\"]\s*\]", after):
                    operations.append("localized_literal_index")
                if re.search(r"^\s*\[[^\]]+\]", after):
                    operations.append("index_access")
                if re.search(r"^\s*\?\.\s*(?:map|where|firstWhere|any|every|fold)\s*\(", after):
                    operations.append("collection_transform")
                if re.search(r"^\s*\.\s*(?:map|where|firstWhere|any|every|fold)\s*\(", after):
                    operations.append("collection_transform")
                if re.search(r"^\s*\?\.\s*(?:join|toList|isEmpty|isNotEmpty|length)\b", after):
                    operations.append("collection_or_string_observation")
                if re.search(r"^\s*\.\s*(?:join|toList|isEmpty|isNotEmpty|length)\b", after):
                    operations.append("collection_or_string_observation")

                lower = context.casefold()
                semantic_calls = []
                for token in (
                    "sendaimessage", "sendmessage", "dispatch", "continuation",
                    "nextaction", "button", "showmodalbottomsheet", "text(",
                    "prompt", "classification", "score", "stage",
                ):
                    if token in lower:
                        semantic_calls.append(token)

                target_occurrence_counts[field] += 1
                for operation in operations:
                    operation_counts[f"{field}::{operation}"] += 1

                proofs.append({
                    "file": rel,
                    "field": field,
                    "line": line,
                    "contextSha256": sha_text(context),
                    "operations": sorted(set(operations)),
                    "nearbyTokenSignals": sorted(set(semantic_calls)),
                    "context": context,
                })

    proofs.sort(key=lambda x: (x["field"], x["file"], x["line"]))

    return {
        "dartFileCount": len(files),
        "targetOccurrenceCounts": dict(sorted(target_occurrence_counts.items())),
        "operationCounts": dict(sorted(operation_counts.items())),
        "proofCount": len(proofs),
        "proofs": proofs,
    }


def consumer_contract_decision(field, consumers):
    field_proofs = [p for p in consumers["proofs"] if p["field"] == field]
    operations = Counter(
        op
        for proof in field_proofs
        for op in proof["operations"]
    )

    literal_localized = operations["localized_literal_index"]
    any_index = operations["index_access"]
    transforms = operations["collection_transform"]

    if not field_proofs:
        return {
            "proven": False,
            "reason": "no_consumer_occurrence_found",
            "compatibilityKind": None,
        }

    if literal_localized > 0:
        return {
            "proven": True,
            "reason": "consumer_reads_pt_es_localized_payload",
            "compatibilityKind": "localized_payload",
            "evidence": {
                "localizedLiteralIndexCount": literal_localized,
                "indexAccessCount": any_index,
                "collectionTransformCount": transforms,
            },
        }

    return {
        "proven": False,
        "reason": "consumer_role_not_machine_proven",
        "compatibilityKind": None,
        "evidence": {
            "localizedLiteralIndexCount": literal_localized,
            "indexAccessCount": any_index,
            "collectionTransformCount": transforms,
        },
    }


def build_compatibility(inner, consumers, declaration):
    decisions = {
        field: consumer_contract_decision(field, consumers)
        for field in TARGET_FIELDS
    }

    records = []
    for record in inner["records"]:
        field = record["fieldName"]
        decision = decisions[field]

        compatibility = {
            "canonicalPathologyKey": record["canonicalPathologyKey"],
            "protocolKey": record["protocolKey"],
            "legacyField": field,
            "ptEsStructuralParity": record["ptEsStructuralParity"],
            "innerFamilyId": record["innerFamilyId"],
            "sourceProof": {
                "blockSha256": record["blockSha256"],
                "sourceExpressionSha256": record["sourceExpressionSha256"],
            },
            "consumerContractProven": bool(decision["proven"]),
            "consumerContractReason": decision["reason"],
            "compatibilityKind": decision.get("compatibilityKind"),
            "pt": record["ptValue"],
            "es": record["esValue"],
            "finalRegistryDocument": False,
            "remoteRegistryMappingPerformed": False,
        }
        records.append(compatibility)

    return {
        "schemaVersion": "clinical_registry_legacy_compatibility_candidates_v1",
        "cutoverReady": False,
        "cloudWriteReady": False,
        "finalRegistryDocuments": False,
        "remoteRegistryMappingPerformed": False,
        "protocolModelDeclaration": declaration,
        "fieldConsumerDecisions": decisions,
        "candidateCount": len(records),
        "consumerContractProvenCandidateCount": sum(
            item["consumerContractProven"] for item in records
        ),
        "records": records,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--candidates", required=True)
    parser.add_argument("--phase5", required=True)
    parser.add_argument("--repo-lib", required=True)
    parser.add_argument("--semantics", required=True)
    parser.add_argument("--consumers", required=True)
    parser.add_argument("--compat", required=True)
    parser.add_argument("--phase6", required=True)
    args = parser.parse_args()

    source_text = Path(args.source).read_text(encoding="utf-8")
    candidates = json.loads(Path(args.candidates).read_text(encoding="utf-8"))
    phase5 = json.loads(Path(args.phase5).read_text(encoding="utf-8"))

    declaration = discover_protocol_model_declaration(args.repo_lib)
    declaration["contract"] = declaration_contract(declaration["block"])

    inner = pt_es_inner_families(candidates)
    consumers = scan_consumers(args.repo_lib)
    compat = build_compatibility(inner, consumers, declaration)

    semantics = {
        "schemaVersion": "clinical_registry_legacy_pt_es_semantics_v1",
        "sourceSha256": sha_text(source_text),
        "cutoverReady": False,
        "remoteRegistryMappingPerformed": False,
        "protocolModelDeclaration": declaration,
        "fieldCounts": inner["fieldCounts"],
        "ptEsParityCounts": inner["parityCounts"],
        "innerFamilyCount": inner["innerFamilyCount"],
        "innerFamilies": inner["innerFamilies"],
        "records": inner["records"],
    }

    phase6 = dict(phase5)
    phase6["schemaVersion"] = "clinical_registry_seed_phase6_legacy_semantics_v1"
    phase6["phase"] = "identity_protocol_plus_legacy_contract_semantics"
    phase6["cutoverReady"] = False

    # Preserve phase 5 empty final registries: Build 13 proves semantics and
    # compatibility only; it does not fabricate the new machine contract.
    phase6["classifications"] = phase5["classifications"]
    phase6["managementRules"] = phase5["managementRules"]
    phase6["actions"] = phase5["actions"]
    phase6["content"] = phase5["content"]

    phase6["legacyContractSemantics"] = {
        "innerFamilyCount": semantics["innerFamilyCount"],
        "classificationCandidateCount": semantics["fieldCounts"].get("classification", 0),
        "actionCandidateCount": semantics["fieldCounts"].get("actions", 0),
        "consumerProofCount": consumers["proofCount"],
        "consumerContractProvenCandidateCount": compat["consumerContractProvenCandidateCount"],
        "remoteRegistryMappingPerformed": False,
        "finalRegistryDocuments": False,
    }

    Path(args.semantics).write_text(
        json.dumps(semantics, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    Path(args.consumers).write_text(
        json.dumps(consumers, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    Path(args.compat).write_text(
        json.dumps(compat, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    Path(args.phase6).write_text(
        json.dumps(phase6, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    contract = declaration["contract"]
    print("PROTOCOLMODEL_DECLARATION_OWNER="+declaration["file"])
    print("PROTOCOLMODEL_DECLARATION_OWNER_SHA="+declaration["fileSha256"])
    print("PROTOCOLMODEL_DECLARATION_LINE="+str(declaration["line"]))
    print("PROTOCOLMODEL_DECLARATION_SHA="+declaration["blockSha256"])
    print("PROTOCOLMODEL_CONSTRUCTOR_COUNT="+str(contract["constructorCount"]))

    for field in TARGET_FIELDS:
        field_decl = contract["fields"].get(field)
        print(
            "PROTOCOLMODEL_FIELD|"+field+
            "|declaredType="+(field_decl["declaredType"] if field_decl else "NOT_FOUND")+
            "|constructorEvidence="+str(len(contract["constructorEvidence"].get(field, [])))
        )

    print("LEGACY_PT_ES_INNER_FAMILY_COUNT="+str(inner["innerFamilyCount"]))
    print("LEGACY_CLASSIFICATION_COUNT="+str(inner["fieldCounts"].get("classification", 0)))
    print("LEGACY_ACTIONS_COUNT="+str(inner["fieldCounts"].get("actions", 0)))
    print("LEGACY_CLASSIFICATION_PT_ES_PARITY_COUNT="+str(inner["parityCounts"].get("classification::parity", 0)))
    print("LEGACY_CLASSIFICATION_PT_ES_NONPARITY_COUNT="+str(inner["parityCounts"].get("classification::nonparity", 0)))
    print("LEGACY_ACTIONS_PT_ES_PARITY_COUNT="+str(inner["parityCounts"].get("actions::parity", 0)))
    print("LEGACY_ACTIONS_PT_ES_NONPARITY_COUNT="+str(inner["parityCounts"].get("actions::nonparity", 0)))

    print("LEGACY_INNER_FAMILY_TOP_BEGIN")
    for family in inner["innerFamilies"][:20]:
        print(
            "INNER_FAMILY|id="+family["innerFamilyId"]+
            "|count="+str(family["count"])+
            "|fields="+",".join(sorted(family["fieldNameCounts"].keys()))+
            "|parity="+str(family["parityCount"])+
            "|nonparity="+str(family["nonParityCount"])
        )
    print("LEGACY_INNER_FAMILY_TOP_END")

    print("CONSUMER_PROOF_COUNT="+str(consumers["proofCount"]))
    for field in TARGET_FIELDS:
        print(
            "CONSUMER_OCCURRENCE_COUNT|field="+field+
            "|count="+str(consumers["targetOccurrenceCounts"].get(field, 0))
        )
        decision = compat["fieldConsumerDecisions"][field]
        print(
            "CONSUMER_CONTRACT|field="+field+
            "|proven="+("YES" if decision["proven"] else "NO")+
            "|reason="+decision["reason"]+
            "|kind="+str(decision.get("compatibilityKind"))
        )

    print("CONSUMER_OPERATION_DISTRIBUTION_BEGIN")
    for name, count in sorted(consumers["operationCounts"].items()):
        print("CONSUMER_OPERATION|"+name+"|count="+str(count))
    print("CONSUMER_OPERATION_DISTRIBUTION_END")

    print("LEGACY_COMPATIBILITY_CANDIDATE_COUNT="+str(compat["candidateCount"]))
    print("CONSUMER_CONTRACT_PROVEN_CANDIDATE_COUNT="+str(compat["consumerContractProvenCandidateCount"]))
    print("REMOTE_REGISTRY_MAPPING_PERFORMED=NO")
    print("FINAL_REGISTRY_DOCUMENTS_CREATED=NO")
    print("PHASE6_CLOUD_WRITE_READY=NO")
    print("PHASE6_CUTOVER_READY=NO")


if __name__ == "__main__":
    main()
