#!/usr/bin/env python3
import argparse
import hashlib
import json
import re
from collections import Counter, defaultdict
from pathlib import Path


class ParseError(Exception):
    pass


def sha_text(value):
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


class Lexer:
    def __init__(self, text):
        self.text = text
        self.i = 0
        self.n = len(text)

    def skip_ws(self):
        while self.i < self.n:
            if self.text[self.i].isspace():
                self.i += 1
                continue
            if self.text.startswith("//", self.i):
                end = self.text.find("\n", self.i + 2)
                self.i = self.n if end < 0 else end + 1
                continue
            if self.text.startswith("/*", self.i):
                end = self.text.find("*/", self.i + 2)
                if end < 0:
                    raise ParseError("unterminated_block_comment")
                self.i = end + 2
                continue
            break

    def peek(self, value=None):
        self.skip_ws()
        if value is None:
            return self.text[self.i:self.i + 1]
        return self.text.startswith(value, self.i)

    def consume(self, value):
        self.skip_ws()
        if not self.text.startswith(value, self.i):
            raise ParseError(f"expected:{value}@{self.i}")
        self.i += len(value)

    def identifier(self):
        self.skip_ws()
        m = re.match(r"[A-Za-z_][A-Za-z0-9_]*", self.text[self.i:])
        if not m:
            raise ParseError(f"identifier_expected@{self.i}")
        value = m.group(0)
        self.i += len(value)
        return value

    def string(self):
        self.skip_ws()
        raw = False
        if self.i < self.n and self.text[self.i] in ("r", "R"):
            if self.i + 1 < self.n and self.text[self.i + 1] in ("'", '"'):
                raw = True
                self.i += 1
        if self.i >= self.n or self.text[self.i] not in ("'", '"'):
            raise ParseError(f"string_expected@{self.i}")
        quote = self.text[self.i]
        self.i += 1
        out = []
        while self.i < self.n:
            ch = self.text[self.i]
            if ch == quote:
                self.i += 1
                return "".join(out)
            if ch == "$":
                raise ParseError("string_interpolation_forbidden")
            if ch == "\\" and not raw:
                if self.i + 1 >= self.n:
                    raise ParseError("dangling_escape")
                nxt = self.text[self.i + 1]
                mapping = {
                    "n": "\n", "r": "\r", "t": "\t",
                    "\\": "\\", "'": "'", '"': '"',
                }
                out.append(mapping.get(nxt, nxt))
                self.i += 2
                continue
            out.append(ch)
            self.i += 1
        raise ParseError("unterminated_string")


class Parser:
    def __init__(self, text):
        self.lx = Lexer(text)

    def parse(self):
        value = self.value()
        self.lx.skip_ws()
        if self.lx.i != self.lx.n:
            raise ParseError(f"trailing_tokens@{self.lx.i}")
        return value

    def strip_prefixes(self):
        while True:
            self.lx.skip_ws()
            save = self.lx.i
            try:
                ident = self.lx.identifier()
            except ParseError:
                self.lx.i = save
                break
            if ident in ("const",):
                continue
            self.lx.i = save
            break

        self.lx.skip_ws()
        if self.lx.peek("<"):
            self.skip_generic_type()

    def skip_generic_type(self):
        self.lx.skip_ws()
        if not self.lx.peek("<"):
            return
        depth = 0
        i = self.lx.i
        quote = None
        while i < self.lx.n:
            ch = self.lx.text[i]
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
            elif ch == "<":
                depth += 1
            elif ch == ">":
                depth -= 1
                if depth == 0:
                    self.lx.i = i + 1
                    return
            i += 1
        raise ParseError("unbalanced_generic_type")

    def value(self):
        self.strip_prefixes()
        self.lx.skip_ws()

        if self.lx.peek("..."):
            raise ParseError("spread_forbidden")

        ch = self.lx.peek()
        if ch in ("'", '"') or (
            ch in ("r", "R")
            and self.lx.i + 1 < self.lx.n
            and self.lx.text[self.lx.i + 1] in ("'", '"')
        ):
            return self.lx.string()

        if ch == "[":
            return self.list_value()
        if ch == "{":
            return self.map_or_set_value()

        rest = self.lx.text[self.lx.i:]
        m = re.match(r"(true|false|null)\b", rest)
        if m:
            token = m.group(1)
            self.lx.i += len(token)
            return {"true": True, "false": False, "null": None}[token]

        m = re.match(r"-?(?:\d+\.\d+|\d+)(?:[eE][+-]?\d+)?", rest)
        if m:
            token = m.group(0)
            self.lx.i += len(token)
            return float(token) if any(c in token for c in ".eE") else int(token)

        if re.match(r"[A-Za-z_]", rest):
            ident = self.lx.identifier()
            raise ParseError(f"identifier_forbidden:{ident}")

        raise ParseError(f"unsupported_value@{self.lx.i}")

    def list_value(self):
        self.lx.consume("[")
        out = []
        self.lx.skip_ws()
        if self.lx.peek("]"):
            self.lx.consume("]")
            return out
        while True:
            if self.lx.peek("..."):
                raise ParseError("spread_forbidden")
            out.append(self.value())
            self.lx.skip_ws()
            if self.lx.peek(","):
                self.lx.consume(",")
                self.lx.skip_ws()
                if self.lx.peek("]"):
                    self.lx.consume("]")
                    return out
                continue
            self.lx.consume("]")
            return out

    def map_or_set_value(self):
        self.lx.consume("{")
        self.lx.skip_ws()
        if self.lx.peek("}"):
            self.lx.consume("}")
            return {}

        first = self.value()
        self.lx.skip_ws()

        if not self.lx.peek(":"):
            raise ParseError("set_literal_not_supported")

        self.lx.consume(":")
        first_value = self.value()
        out = {self.map_key(first): first_value}

        while True:
            self.lx.skip_ws()
            if self.lx.peek(","):
                self.lx.consume(",")
                self.lx.skip_ws()
                if self.lx.peek("}"):
                    self.lx.consume("}")
                    return out
                if self.lx.peek("..."):
                    raise ParseError("spread_forbidden")
                key = self.value()
                self.lx.consume(":")
                value = self.value()
                out[self.map_key(key)] = value
                continue
            self.lx.consume("}")
            return out

    @staticmethod
    def map_key(value):
        if isinstance(value, (str, int, float, bool)) or value is None:
            return str(value)
        raise ParseError("complex_map_key_forbidden")


def normalize_expression(expr):
    try:
        value = Parser(expr).parse()
        return {
            "ok": True,
            "value": value,
            "error": None,
        }
    except ParseError as error:
        return {
            "ok": False,
            "value": None,
            "error": str(error),
        }


def owner_scan(path):
    text = Path(path).read_text(encoding="utf-8", errors="ignore")

    names = Counter()
    structured = []
    patterns = [
        r"\b(classification|classificacao|clasificacion|score|stage|staging|"
        r"management|treatment|tratamento|tratamiento|manejo|conduta|conducta|"
        r"nextAction|nextActions|continuation|primaryAction|classificationAction|"
        r"contentRef|classificationTable|scoreTable|stageTable)\b"
        r"\s*[:=]\s*",
    ]

    rx = re.compile("|".join(patterns), re.I)

    for match in rx.finditer(text):
        field = match.group(1)
        names[field] += 1
        start = match.end()
        tail = text[start:start + 120]
        shape = "other"
        stripped = tail.lstrip()
        if stripped.startswith("[") or re.match(r"^const\s+(?:<[^>]+>\s*)?\[", stripped):
            shape = "list_literal_signal"
        elif stripped.startswith("{") or re.match(r"^const\s+(?:<[^>]+>\s*)?\{", stripped):
            shape = "map_literal_signal"
        elif stripped.startswith(("'", '"', "r'", 'r"')):
            shape = "string_signal"

        structured.append(
            {
                "field": field,
                "line": text.count("\n", 0, match.start()) + 1,
                "shapeSignal": shape,
            }
        )

    return {
        "file": path,
        "fieldSignalCounts": dict(sorted(names.items())),
        "structuredSignals": structured,
        "structuredSignalCount": sum(
            item["shapeSignal"] in ("list_literal_signal", "map_literal_signal")
            for item in structured
        ),
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--proofs")
    parser.add_argument("--phase2")
    parser.add_argument("--candidates")
    parser.add_argument("--owner-audit")
    parser.add_argument("--phase3")
    parser.add_argument("--owners", nargs="+")
    args = parser.parse_args()

    proofs = json.loads(Path(args.proofs).read_text(encoding="utf-8"))
    phase2 = json.loads(Path(args.phase2).read_text(encoding="utf-8"))

    field_names = Counter()
    group_total = Counter()
    group_parsed = Counter()
    group_rejected = Counter()
    rejection_reasons = Counter()
    candidates = []

    for record in proofs["records"]:
        for field in record["clinicalFieldCandidates"]:
            field_names[field["name"]] += 1

            if not field["structuredLiteralProven"]:
                continue

            result = normalize_expression(field["sourceExpression"])

            for group in field["groups"]:
                group_total[group] += 1
                if result["ok"]:
                    group_parsed[group] += 1
                else:
                    group_rejected[group] += 1

            if not result["ok"]:
                rejection_reasons[result["error"]] += 1

            candidates.append(
                {
                    "canonicalPathologyKey": record["canonicalPathologyKey"],
                    "protocolKey": record["protocolKey"],
                    "sourceKey": record["sourceKey"],
                    "blockSha256": record["blockSha256"],
                    "fieldName": field["name"],
                    "groups": field["groups"],
                    "sourceExpressionSha256": field["exprSha256"],
                    "literalParseOk": result["ok"],
                    "literalParseError": result["error"],
                    "normalizedLiteral": result["value"],
                    "clinicalSemanticMappingPerformed": False,
                    "finalRegistryDocument": False,
                }
            )

    owner_audits = [owner_scan(path) for path in args.owners]

    bundle = {
        "schemaVersion": "clinical_registry_normalized_candidates_v1",
        "sourceSha256": proofs["sourceSha256"],
        "cutoverReady": False,
        "finalRegistryDocuments": False,
        "clinicalSemanticMappingPerformed": False,
        "fieldNameCounts": dict(sorted(field_names.items())),
        "groupStructuredProofCounts": dict(sorted(group_total.items())),
        "groupLiteralParseSuccessCounts": dict(sorted(group_parsed.items())),
        "groupLiteralParseRejectedCounts": dict(sorted(group_rejected.items())),
        "literalParseRejectionReasons": dict(sorted(rejection_reasons.items())),
        "candidateCount": len(candidates),
        "literalParseSuccessCount": sum(x["literalParseOk"] for x in candidates),
        "literalParseRejectedCount": sum(not x["literalParseOk"] for x in candidates),
        "candidates": candidates,
    }

    audit = {
        "schemaVersion": "clinical_registry_additional_owner_inventory_v1",
        "cutoverReady": False,
        "sourceWritePerformed": False,
        "owners": owner_audits,
        "totalStructuredSignalCount": sum(
            owner["structuredSignalCount"] for owner in owner_audits
        ),
    }

    phase3 = dict(phase2)
    phase3["schemaVersion"] = "clinical_registry_seed_phase3_normalized_candidates_v1"
    phase3["phase"] = "identity_protocol_plus_normalized_candidate_metadata"
    phase3["cutoverReady"] = False
    phase3["normalizedCandidateBundle"] = {
        "schemaVersion": bundle["schemaVersion"],
        "candidateCount": bundle["candidateCount"],
        "literalParseSuccessCount": bundle["literalParseSuccessCount"],
        "literalParseRejectedCount": bundle["literalParseRejectedCount"],
        "clinicalSemanticMappingPerformed": False,
        "finalRegistryDocuments": False,
    }

    Path(args.candidates).write_text(
        json.dumps(bundle, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    Path(args.owner_audit).write_text(
        json.dumps(audit, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    Path(args.phase3).write_text(
        json.dumps(phase3, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    print("BUILD10_FIELD_DISTRIBUTION_BEGIN")
    for name, count in sorted(field_names.items()):
        print(f"FIELD|{name}|count={count}")
    print("BUILD10_FIELD_DISTRIBUTION_END")

    for group in ("classification", "management", "action", "content"):
        print(
            "GROUP_"+group.upper()+"_STRUCTURED_PROOF_COUNT="+
            str(group_total.get(group, 0))
        )
        print(
            "GROUP_"+group.upper()+"_LITERAL_PARSE_SUCCESS_COUNT="+
            str(group_parsed.get(group, 0))
        )
        print(
            "GROUP_"+group.upper()+"_LITERAL_PARSE_REJECTED_COUNT="+
            str(group_rejected.get(group, 0))
        )

    print("NORMALIZED_CANDIDATE_COUNT="+str(bundle["candidateCount"]))
    print("LITERAL_PARSE_SUCCESS_COUNT="+str(bundle["literalParseSuccessCount"]))
    print("LITERAL_PARSE_REJECTED_COUNT="+str(bundle["literalParseRejectedCount"]))

    print("ADDITIONAL_OWNER_AUDIT_BEGIN")
    for owner in owner_audits:
        print(
            "OWNER|"+owner["file"]+
            "|structuredSignals="+str(owner["structuredSignalCount"])+
            "|fieldSignals="+str(sum(owner["fieldSignalCounts"].values()))
        )
    print("ADDITIONAL_OWNER_AUDIT_END")
    print("ADDITIONAL_OWNER_TOTAL_STRUCTURED_SIGNAL_COUNT="+str(audit["totalStructuredSignalCount"]))

    print("CLINICAL_SEMANTIC_MAPPING_PERFORMED=NO")
    print("FINAL_REGISTRY_DOCUMENTS_CREATED=NO")
    print("PHASE3_CUTOVER_READY=NO")


if __name__ == "__main__":
    main()
