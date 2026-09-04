#!/usr/bin/env python3
import argparse
import hashlib
import json
import re
import unicodedata
from collections import defaultdict
from pathlib import Path


FIELD_NAMES = (
    "canonicalKey", "pathologyKey", "protocolKey", "id", "key",
    "title", "name", "label", "titlePt", "titleEs", "nome", "nombre",
)
FIELD_BLACKLIST = {
    "id", "key", "name", "title", "label", "description", "content",
    "pt", "es", "en", "references", "referencias", "aliases", "alias",
    "recognize", "category", "categories", "classification", "classificacao",
    "clasificacion", "score", "stage", "management", "treatment", "tratamento",
    "tratamiento", "prompt", "priority", "version", "enabled", "source",
    "url", "urls", "type", "mode", "value", "values", "payload",
}
CLASS_TERMS = (
    "classification", "classificação", "classificacao", "clasificación",
    "clasificacion", "score", "escore", "escala", "stage", "staging",
    "estadio", "estágio", "estagio", "estratificação", "estratificacao",
    "estratificación", "killip", "curb", "child-pugh", "child pugh",
    "wells", "sofa", "news2", "timi", "has-bled", "cha2ds2", "glasgow",
)
MGMT_TERMS = (
    "tratamento", "tratamiento", "treatment", "manejo", "management",
    "conduta", "conducta", "terapia", "therapy",
)
URL_RE = re.compile(r"https://[^\s\"'<>\])},]+", re.I)
QUOTED_KEY_RE = re.compile(
    r"""^\s*(?P<q>['"])(?P<key>[^'"]{2,180})(?P=q)\s*:\s*(?P<rhs>.*)$"""
)
FIELD_LITERAL_RE = re.compile(
    r"""(?:(?P<qk>['"])(?P<qfield>[A-Za-z_][A-Za-z0-9_]*)(?P=qk)|(?P<field>[A-Za-z_][A-Za-z0-9_]*))\s*:\s*(?P<qv>['"])(?P<value>[^'"\n]{1,240})(?P=qv)"""
)
GENERIC_CALL_RE = re.compile(r"\b([A-Z_][A-Za-z0-9_$.]*)\s*\(")
EXCLUDED_CALLS = {
    "Map", "List", "Set", "Object", "String", "RegExp", "DateTime",
    "Duration", "Uri", "Exception", "ArgumentError", "StateError",
}


def sha_text(value):
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def slugify(value):
    normalized = unicodedata.normalize("NFKD", value)
    ascii_value = "".join(ch for ch in normalized if not unicodedata.combining(ch))
    ascii_value = ascii_value.encode("ascii", "ignore").decode("ascii")
    value = re.sub(r"[^a-z0-9]+", "_", ascii_value.lower()).strip("_")
    return re.sub(r"_+", "_", value)[:96]


def line_no(text, pos):
    return text.count("\n", 0, pos) + 1


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


def extract_fields(block):
    out = {}
    for match in FIELD_LITERAL_RE.finditer(block):
        field = match.group("qfield") or match.group("field")
        if field and field not in out:
            out[field] = match.group("value").strip()
    return out


def pick_label(fields, fallback=""):
    for name in FIELD_NAMES:
        value = fields.get(name)
        if value and len(value.strip()) >= 2:
            return value.strip()
    return fallback.strip()


def clinical_evidence(block):
    lower = block.casefold()
    score = 0
    if "http" in lower:
        score += 2
    if "referenc" in lower or "referenc" in lower:
        score += 2
    if "pt" in lower and "es" in lower:
        score += 1
    if any(term.casefold() in lower for term in CLASS_TERMS):
        score += 1
    if any(term.casefold() in lower for term in MGMT_TERMS):
        score += 1
    return score


def map_key_records(text):
    lines = text.splitlines(keepends=True)
    candidates = []
    for idx, line in enumerate(lines):
        m = QUOTED_KEY_RE.match(line)
        if not m:
            continue
        key = m.group("key").strip()
        if key.casefold() in FIELD_BLACKLIST or key.lower().startswith("http"):
            continue
        start = sum(len(x) for x in lines[:idx])
        colon = text.find(":", start, start + len(line))
        if colon < 0:
            continue
        brace = text.find("{", colon, min(len(text), colon + 180))
        if brace < 0:
            continue
        close = matching(text, brace, "{", "}")
        if close is None:
            continue
        block = text[start:close + 1]
        if clinical_evidence(block) < 1:
            continue
        candidates.append({
            "label": key,
            "line": idx + 1,
            "block": block,
            "strategy": "quoted_map_record",
            "group": "quoted_map_record",
        })
    return candidates


def constructor_groups(text):
    groups = defaultdict(list)
    for match in GENERIC_CALL_RE.finditer(text):
        ctor = match.group(1).split(".")[-1]
        if ctor in EXCLUDED_CALLS:
            continue
        open_pos = text.find("(", match.start(), match.end() + 1)
        if open_pos < 0:
            continue
        close = matching(text, open_pos, "(", ")")
        if close is None:
            continue
        block = text[match.start():close + 1]
        if len(block) < 40 or len(block) > 120000:
            continue
        fields = extract_fields(block)
        label = pick_label(fields)
        if not label:
            # Positional first string is accepted only for large repeated
            # constructor groups and still requires clinical evidence.
            first = re.search(r"""\(\s*(?:const\s+)?(['"])([^'"\n]{2,180})\1""", block)
            label = first.group(2).strip() if first else ""
        if not label:
            continue
        if clinical_evidence(block) < 1:
            continue
        groups[ctor].append({
            "label": label,
            "line": line_no(text, match.start()),
            "block": block,
            "strategy": "generic_constructor",
            "group": ctor,
        })
    return groups


def map_object_records(text):
    candidates = []
    for match in re.finditer(r"\{", text):
        start = match.start()
        close = matching(text, start, "{", "}")
        if close is None:
            continue
        block = text[start:close + 1]
        if len(block) < 80 or len(block) > 80000:
            continue
        fields = extract_fields(block)
        label = pick_label(fields)
        if not label:
            continue
        if clinical_evidence(block) < 2:
            continue
        candidates.append({
            "label": label,
            "line": line_no(text, start),
            "block": block,
            "strategy": "map_object_record",
            "group": "map_object_record",
            "span": close - start,
        })

    # Keep minimal blocks when nested blocks identify the same label.
    by_label = {}
    for item in sorted(candidates, key=lambda x: x["span"]):
        key = item["label"].casefold()
        by_label.setdefault(key, item)
    return list(by_label.values())


def choose_strategy(text):
    strategies = []

    map_records = map_key_records(text)
    strategies.append(("quoted_map_record", "quoted_map_record", map_records))

    groups = constructor_groups(text)
    for group, rows in groups.items():
        strategies.append(("generic_constructor", group, rows))

    object_records = map_object_records(text)
    strategies.append(("map_object_record", "map_object_record", object_records))

    diagnostics = []
    qualified = []

    for strategy, group, rows in strategies:
        unique = {}
        for row in rows:
            label = re.sub(r"\s+", " ", row["label"]).strip()
            if not label:
                continue
            unique.setdefault(label.casefold(), row)
        rows = list(unique.values())
        refs = sum(len(set(URL_RE.findall(row["block"]))) for row in rows)
        evidence = sum(clinical_evidence(row["block"]) for row in rows)
        diagnostic = {
            "strategy": strategy,
            "group": group,
            "recordCount": len(rows),
            "referenceUrlSignalCount": refs,
            "evidenceScore": evidence,
        }
        diagnostics.append(diagnostic)
        if len(rows) >= 20:
            qualified.append((len(rows), refs, evidence, strategy, group, rows))

    diagnostics.sort(
        key=lambda x: (x["recordCount"], x["referenceUrlSignalCount"], x["evidenceScore"]),
        reverse=True,
    )

    if not qualified:
        return None, None, [], diagnostics

    qualified.sort(reverse=True, key=lambda x: (x[0], x[1], x[2]))
    _, _, _, strategy, group, rows = qualified[0]
    return strategy, group, rows, diagnostics


def aliases_for(label, block):
    values = [label]
    fields = extract_fields(block)
    for key in ("title", "titlePt", "titleEs", "name", "nome", "nombre", "label"):
        value = fields.get(key)
        if value:
            values.append(value)
    out = []
    seen = set()
    for value in values:
        normalized = re.sub(r"\s+", " ", value).strip()
        folded = normalized.casefold()
        if normalized and folded not in seen:
            seen.add(folded)
            out.append(normalized)
    return out[:12]


def inventory_for(label, canonical, line, block, block_sha):
    lower = block.casefold()
    class_counts = {
        term: lower.count(term.casefold())
        for term in CLASS_TERMS
        if lower.count(term.casefold())
    }
    management_counts = {
        term: lower.count(term.casefold())
        for term in MGMT_TERMS
        if lower.count(term.casefold())
    }
    refs = sorted(set(URL_RE.findall(block)))
    return {
        "sourceKey": label,
        "canonicalPathologyKey": canonical,
        "line": line,
        "blockSha256": block_sha,
        "referenceUrlCount": len(refs),
        "hasClassificationCandidate": bool(class_counts),
        "hasManagementCandidate": bool(management_counts),
        "classificationTermCounts": class_counts,
        "managementTermCounts": management_counts,
    }


def extract(source_text, source_path):
    strategy, group, rows, diagnostics = choose_strategy(source_text)

    print("DISCOVERY_TOP_CANDIDATES_BEGIN")
    for item in diagnostics[:12]:
        print(
            "DISCOVERY_CANDIDATE|"
            f"strategy={item['strategy']}|group={item['group']}|"
            f"records={item['recordCount']}|"
            f"refs={item['referenceUrlSignalCount']}|"
            f"evidence={item['evidenceScore']}"
        )
    print("DISCOVERY_TOP_CANDIDATES_END")

    if not rows:
        raise RuntimeError("no_confident_protocol_record_shape_after_multistrategy_discovery")

    source_sha = sha_text(source_text)
    identities = []
    protocols = []
    inventory = []
    seen = {}

    for row in rows:
        label = re.sub(r"\s+", " ", row["label"]).strip()
        base = slugify(label) or "clinical_record"
        canonical = base
        if canonical in seen and seen[canonical] != label:
            canonical = f"{base}_{sha_text(label)[:8]}"
        seen[canonical] = label

        block = row["block"]
        block_sha = sha_text(block)
        refs = sorted(set(URL_RE.findall(block)))

        identities.append({
            "canonicalKey": canonical,
            "displayLabel": label,
            "aliases": aliases_for(label, block),
            "strongAliases": [label],
            "enabled": True,
            "priority": 100,
            "version": source_sha[:12],
            "source": {
                "file": source_path,
                "line": row["line"],
                "strategy": strategy,
                "sourceGroup": group,
                "sourceKey": label,
                "blockSha256": block_sha,
            },
        })
        protocols.append({
            "protocolKey": f"legacy_protocol::{canonical}",
            "canonicalPathologyKey": canonical,
            "enabled": True,
            "priority": 100,
            "version": source_sha[:12],
            "referenceUrls": refs,
            "source": {
                "file": source_path,
                "line": row["line"],
                "strategy": strategy,
                "sourceGroup": group,
                "sourceKey": label,
                "blockSha256": block_sha,
            },
        })
        inventory.append(
            inventory_for(label, canonical, row["line"], block, block_sha)
        )

    identities.sort(key=lambda x: x["canonicalKey"])
    protocols.sort(key=lambda x: x["protocolKey"])
    inventory.sort(key=lambda x: x["canonicalPathologyKey"])

    return strategy, group, identities, protocols, inventory, diagnostics


def selftest():
    sample = "\n".join(
        [
            "const rows = [",
            *[
                (
                    f'  ClinicalEntry(title: "Condition {i}", '
                    f'pt: "texto tratamento classificação", '
                    f'es: "texto tratamiento clasificación", '
                    f'references: ["https://example.org/{i}"]),'
                )
                for i in range(1, 26)
            ],
            "];",
        ]
    )
    strategy, group, identities, protocols, inventory, diagnostics = extract(
        sample,
        "sample.dart",
    )
    assert strategy == "generic_constructor"
    assert len(identities) == 25
    assert len(protocols) == 25
    assert sum(x["referenceUrlCount"] for x in inventory) == 25
    print("EXTRACTOR_SELFTEST=PASS")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--selftest", action="store_true")
    parser.add_argument("--source")
    parser.add_argument("--seed")
    parser.add_argument("--inventory")
    args = parser.parse_args()

    if args.selftest:
        selftest()
        return

    if not args.source or not args.seed or not args.inventory:
        raise SystemExit("source_seed_inventory_required")

    source = Path(args.source)
    text = source.read_text(encoding="utf-8", errors="strict")
    strategy, group, identities, protocols, inventory, diagnostics = extract(
        text,
        str(source),
    )

    source_sha = sha_text(text)
    seed = {
        "schemaVersion": "clinical_registry_seed_phase1_v1",
        "phase": "identity_protocol_only",
        "sourceSha256": source_sha,
        "extractionStrategy": strategy,
        "extractionGroup": group,
        "cutoverReady": False,
        "identities": identities,
        "protocols": protocols,
        "classifications": [],
        "managementRules": [],
        "actions": [],
        "content": [],
    }

    report = {
        "schemaVersion": "clinical_registry_migration_inventory_v1",
        "sourceSha256": source_sha,
        "extractionStrategy": strategy,
        "extractionGroup": group,
        "recordCount": len(identities),
        "identityCount": len(identities),
        "protocolCount": len(protocols),
        "classificationCandidateCount": sum(
            x["hasClassificationCandidate"] for x in inventory
        ),
        "managementCandidateCount": sum(
            x["hasManagementCandidate"] for x in inventory
        ),
        "referenceUrlCount": sum(x["referenceUrlCount"] for x in inventory),
        "cutoverReady": False,
        "phase1SeedValidatedOnly": True,
        "discoveryDiagnostics": diagnostics[:20],
        "classificationCandidates": inventory,
    }

    Path(args.seed).write_text(
        json.dumps(seed, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    Path(args.inventory).write_text(
        json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    print(f"EXTRACTION_STRATEGY={strategy}")
    print(f"EXTRACTION_GROUP={group}")
    print(f"EXTRACTED_IDENTITY_COUNT={len(identities)}")
    print(f"EXTRACTED_PROTOCOL_COUNT={len(protocols)}")
    print(f"CLASSIFICATION_CANDIDATE_COUNT={report['classificationCandidateCount']}")
    print(f"MANAGEMENT_CANDIDATE_COUNT={report['managementCandidateCount']}")
    print(f"EXTRACTED_REFERENCE_URL_COUNT={report['referenceUrlCount']}")
    print("PHASE1_SEED_CUTOVER_READY=NO")
    print("STRUCTURED_CLINICAL_INFERENCE_PERFORMED=NO")


if __name__ == "__main__":
    main()
