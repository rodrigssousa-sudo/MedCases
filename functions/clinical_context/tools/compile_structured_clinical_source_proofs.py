#!/usr/bin/env python3
import argparse
import hashlib
import json
import re
from collections import Counter
from pathlib import Path


FIELD_GROUPS = {
    "classification": {
        "classification", "classifications", "classificationpt", "classificationes",
        "classificacao", "classificacoes", "classificacaopt", "classificacaoes",
        "clasificacion", "clasificaciones", "clasificacionpt", "clasificaciones",
        "score", "scores", "scorept", "scorees", "scoring", "riskclass",
        "riskclassification", "severityclass", "severityclassification",
        "stage", "stages", "stagept", "stagees", "staging", "severitystage",
        "classificationtable", "scoretable", "stagetable",
    },
    "management": {
        "management", "managementpt", "managementes", "managementrules",
        "treatment", "treatments", "treatmentpt", "treatmentes",
        "tratamento", "tratamentos", "tratamentopt", "tratamentoes",
        "tratamiento", "tratamientos", "tratamientopt", "tratamientoes",
        "manejo", "manejopt", "manejoes", "conduta", "conducta",
        "therapy", "therapies",
    },
    "action": {
        "action", "actions", "nextaction", "nextactions", "primaryaction",
        "classificationaction", "scoreaction", "stageaction", "continuation",
        "continuationpt", "continuationes", "cta", "ctas",
    },
    "content": {
        "content", "contentref", "contentrefs", "classificationcontent",
        "scorecontent", "stagecontent", "classificationtable", "scoretable",
        "stagetable", "table", "tables",
    },
}

LABEL_FIELDS = (
    "title", "name", "label", "titlePt", "titleEs", "nome", "nombre",
    "canonicalKey", "pathologyKey", "protocolKey", "id", "key",
)

PROTOCOL_RE = re.compile(r"\bProtocolModel\s*\(")


def sha_text(value):
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def matching(text, open_pos, opener="(", closer=")"):
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


def extract_protocol_blocks(text):
    blocks = []
    for match in PROTOCOL_RE.finditer(text):
        open_pos = text.find("(", match.start(), match.end() + 1)
        if open_pos < 0:
            continue
        close_pos = matching(text, open_pos)
        if close_pos is None:
            raise RuntimeError("protocolmodel_unbalanced_parenthesis")
        block = text[match.start():close_pos + 1]
        blocks.append(
            {
                "line": text.count("\n", 0, match.start()) + 1,
                "block": block,
                "blockSha256": sha_text(block),
            }
        )
    return blocks


def split_top_level_args(argument_text):
    parts = []
    start = 0
    paren = bracket = brace = 0
    quote = None
    line_comment = False
    block_comment = False
    i = 0

    while i < len(argument_text):
        ch = argument_text[i]
        nxt = argument_text[i + 1] if i + 1 < len(argument_text) else ""

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

        if ch == "(":
            paren += 1
        elif ch == ")":
            paren -= 1
        elif ch == "[":
            bracket += 1
        elif ch == "]":
            bracket -= 1
        elif ch == "{":
            brace += 1
        elif ch == "}":
            brace -= 1
        elif ch == "," and paren == bracket == brace == 0:
            part = argument_text[start:i].strip()
            if part:
                parts.append(part)
            start = i + 1
        i += 1

    tail = argument_text[start:].strip()
    if tail:
        parts.append(tail)
    return parts


def split_named_arg(part):
    paren = bracket = brace = 0
    quote = None
    i = 0
    while i < len(part):
        ch = part[i]
        if quote:
            if ch == "\\":
                i += 2
                continue
            if ch == quote:
                quote = None
            i += 1
            continue
        if ch in ("'", '"'):
            quote = ch
            i += 1
            continue
        if ch == "(":
            paren += 1
        elif ch == ")":
            paren -= 1
        elif ch == "[":
            bracket += 1
        elif ch == "]":
            bracket -= 1
        elif ch == "{":
            brace += 1
        elif ch == "{" and bracket == 0:
            brace += 1
        elif ch == ":" and paren == bracket == brace == 0:
            name = part[:i].strip()
            expr = part[i + 1:].strip()
            if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name):
                return name, expr
            return None, None
        i += 1
    return None, None


def literal_string(expr):
    expr = expr.strip()
    match = re.fullmatch(r"""(?:r)?(['"])(.*)\1""", expr, re.S)
    if not match:
        return None
    value = match.group(2)
    if "${" in value or "$" in value:
        return None
    return re.sub(r"\\([\\'\"nrt])", lambda m: {
        "\\": "\\", "'": "'", '"': '"', "n": "\n", "r": "\r", "t": "\t"
    }[m.group(1)], value)


def expression_shape(expr):
    value = expr.strip()
    if not value:
        return "empty"
    if literal_string(value) is not None:
        return "string_literal"
    if value.startswith("const "):
        value = value[6:].lstrip()
    if value.startswith("<") and ">" in value[:120]:
        value = value[value.find(">") + 1:].lstrip()
    if value.startswith("[") and value.endswith("]"):
        return "list_literal"
    if value.startswith("{") and value.endswith("}"):
        return "map_literal"
    if re.fullmatch(r"(?:true|false|null|-?\d+(?:\.\d+)?)", value):
        return "scalar_literal"
    if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_.]*", value):
        return "identifier"
    if re.match(r"[A-Za-z_][A-Za-z0-9_.<>]*\s*\(", value):
        return "call_expression"
    return "other_expression"


def structured_literal_proven(expr):
    shape = expression_shape(expr)
    if shape not in ("list_literal", "map_literal"):
        return False
    if "${" in expr:
        return False
    # Function closures/calls can make a visually literal expression dynamic.
    if re.search(r"\b(?:if|for)\s*\(", expr):
        return False
    return True


def field_group(name):
    folded = name.casefold()
    matches = [
        group for group, names in FIELD_GROUPS.items()
        if folded in names
    ]
    return matches


def parse_block(block):
    open_pos = block.find("(")
    close_pos = matching(block, open_pos)
    if open_pos < 0 or close_pos is None:
        raise RuntimeError("protocol_block_parse_failed")
    args = split_top_level_args(block[open_pos + 1:close_pos])
    parsed = []
    for part in args:
        name, expr = split_named_arg(part)
        if name:
            parsed.append(
                {
                    "name": name,
                    "expr": expr,
                    "shape": expression_shape(expr),
                    "exprSha256": sha_text(expr),
                    "groups": field_group(name),
                    "structuredLiteralProven": structured_literal_proven(expr),
                }
            )
    return parsed


def label_from_args(args):
    by_name = {item["name"]: item for item in args}
    for name in LABEL_FIELDS:
        item = by_name.get(name)
        if not item:
            continue
        value = literal_string(item["expr"])
        if value:
            return re.sub(r"\s+", " ", value).strip()
    for item in args:
        if item["shape"] == "string_literal":
            value = literal_string(item["expr"])
            if value and 2 <= len(value.strip()) <= 180:
                return re.sub(r"\s+", " ", value).strip()
    return ""


def compile_proofs(source_text, phase1):
    blocks = extract_protocol_blocks(source_text)
    if len(blocks) != 270:
        raise RuntimeError(f"protocolmodel_count_mismatch:{len(blocks)}")

    phase1_by_sha = {
        protocol["source"]["blockSha256"]: protocol
        for protocol in phase1["protocols"]
    }

    if len(phase1_by_sha) != 270:
        raise RuntimeError("phase1_protocol_block_sha_not_unique_270")

    records = []
    field_counter = Counter()
    group_candidate_counter = Counter()
    group_proven_counter = Counter()
    shape_counter = Counter()
    unmatched = []

    for block in blocks:
        protocol = phase1_by_sha.get(block["blockSha256"])
        if not protocol:
            unmatched.append(block["blockSha256"])
            continue

        args = parse_block(block["block"])
        label = label_from_args(args)

        fields = []
        for item in args:
            field_counter[item["name"]] += 1
            shape_counter[item["shape"]] += 1
            for group in item["groups"]:
                group_candidate_counter[group] += 1
                if item["structuredLiteralProven"]:
                    group_proven_counter[group] += 1

            if item["groups"]:
                fields.append(
                    {
                        "name": item["name"],
                        "shape": item["shape"],
                        "groups": item["groups"],
                        "structuredLiteralProven": item["structuredLiteralProven"],
                        "exprSha256": item["exprSha256"],
                        # The raw expression is local-only migration evidence.
                        # It is never sent to cloud by this build.
                        "sourceExpression": item["expr"],
                    }
                )

        records.append(
            {
                "canonicalPathologyKey": protocol["canonicalPathologyKey"],
                "protocolKey": protocol["protocolKey"],
                "sourceKey": protocol["source"]["sourceKey"],
                "labelFromCurrentParse": label,
                "line": block["line"],
                "blockSha256": block["blockSha256"],
                "clinicalFieldCandidates": fields,
            }
        )

    if unmatched:
        raise RuntimeError(f"source_proof_unmatched_protocol_blocks:{len(unmatched)}")

    records.sort(key=lambda item: item["canonicalPathologyKey"])

    summary = {
        "protocolModelCount": len(blocks),
        "phase1ProtocolCount": len(phase1["protocols"]),
        "sourceProofMatchedCount": len(records),
        "namedArgumentFieldCounts": dict(sorted(field_counter.items())),
        "expressionShapeCounts": dict(sorted(shape_counter.items())),
        "clinicalGroupCandidateFieldCounts": dict(sorted(group_candidate_counter.items())),
        "clinicalGroupStructuredLiteralProofCounts": dict(sorted(group_proven_counter.items())),
        "recordsWithAnyClinicalFieldCandidate": sum(
            bool(item["clinicalFieldCandidates"]) for item in records
        ),
        "recordsWithAnyStructuredLiteralProof": sum(
            any(field["structuredLiteralProven"] for field in item["clinicalFieldCandidates"])
            for item in records
        ),
    }
    return records, summary


def selftest():
    source = "\n".join(
        [
            "final rows = [",
            *[
                (
                    f'ProtocolModel(title: "Condition {i}", '
                    f'classification: {{"A": "low", "B": "high"}}, '
                    f'treatment: "narrative only"),'
                )
                for i in range(1, 4)
            ],
            "];",
        ]
    )
    blocks = extract_protocol_blocks(source)
    assert len(blocks) == 3
    args = parse_block(blocks[0]["block"])
    by_name = {x["name"]: x for x in args}
    assert by_name["classification"]["structuredLiteralProven"] is True
    assert by_name["treatment"]["structuredLiteralProven"] is False
    assert field_group("classification") == ["classification"]
    print("BUILD9_COMPILER_SELFTEST=PASS")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--selftest", action="store_true")
    parser.add_argument("--source")
    parser.add_argument("--phase1")
    parser.add_argument("--proofs")
    parser.add_argument("--phase2")
    args = parser.parse_args()

    if args.selftest:
        selftest()
        return

    source_text = Path(args.source).read_text(encoding="utf-8")
    phase1 = json.loads(Path(args.phase1).read_text(encoding="utf-8"))

    records, summary = compile_proofs(source_text, phase1)

    proofs = {
        "schemaVersion": "clinical_registry_structured_source_proofs_v1",
        "sourceSha256": sha_text(source_text),
        "phase1SeedSha256": sha_text(
            Path(args.phase1).read_text(encoding="utf-8")
        ),
        "cutoverReady": False,
        "structuredClinicalInferencePerformed": False,
        "normalizationPerformed": False,
        "summary": summary,
        "records": records,
    }

    # Phase 2 deliberately retains the valid phase 1 registries byte-for-data
    # and attaches only proof metadata. No unproven classifications,
    # management rules, actions or content are synthesized.
    phase2 = dict(phase1)
    phase2["schemaVersion"] = "clinical_registry_seed_phase2_proofs_v1"
    phase2["phase"] = "identity_protocol_plus_structured_source_proofs"
    phase2["cutoverReady"] = False
    phase2["structuredProofBundle"] = {
        "schemaVersion": proofs["schemaVersion"],
        "sourceSha256": proofs["sourceSha256"],
        "summary": summary,
    }

    Path(args.proofs).write_text(
        json.dumps(proofs, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    Path(args.phase2).write_text(
        json.dumps(phase2, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    print("PROTOCOLMODEL_REPARSE_COUNT="+str(summary["protocolModelCount"]))
    print("SOURCE_PROOF_MATCHED_COUNT="+str(summary["sourceProofMatchedCount"]))
    print(
        "RECORDS_WITH_CLINICAL_FIELD_CANDIDATE="+
        str(summary["recordsWithAnyClinicalFieldCandidate"])
    )
    print(
        "RECORDS_WITH_STRUCTURED_LITERAL_PROOF="+
        str(summary["recordsWithAnyStructuredLiteralProof"])
    )
    for group in ("classification", "management", "action", "content"):
        print(
            "GROUP_"+group.upper()+"_CANDIDATE_FIELD_COUNT="+
            str(summary["clinicalGroupCandidateFieldCounts"].get(group, 0))
        )
        print(
            "GROUP_"+group.upper()+"_STRUCTURED_LITERAL_PROOF_COUNT="+
            str(summary["clinicalGroupStructuredLiteralProofCounts"].get(group, 0))
        )
    print("STRUCTURED_CLINICAL_INFERENCE_PERFORMED=NO")
    print("STRUCTURED_REGISTRY_NORMALIZATION_PERFORMED=NO")
    print("PHASE2_CUTOVER_READY=NO")


if __name__ == "__main__":
    main()
