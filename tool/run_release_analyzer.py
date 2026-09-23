#!/usr/bin/env python3
"""Classify the full analyzer output; never suppress a release diagnostic.

Usage: FLUTTER_BIN=/path/to/flutter python3 tool/run_release_analyzer.py --output /path/to/evidence
Manifest inventory/hash drift fails closed. Refresh the manifest only after a
new AST reachability/provenance review, including every conditional import.
"""
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
manifest = json.loads((root / 'tool/release_analyzer_manifest.json').read_text())
entries = {x['path']: x for x in manifest['files']}
allowed = {'RELEASE_RUNTIME', 'RELEASE_TEST', 'FUTURE_NON_RUNTIME',
           'HISTORICAL_REFERENCE', 'HISTORICAL_TEST'}
if len(entries) != len(manifest['files']) or any(x['classification'] not in allowed for x in entries.values()):
    sys.exit('FAIL: duplicate or unclassified manifest entry')
for entrypoint in manifest['entrypoints']:
    if entries.get(entrypoint, {}).get('classification') != 'RELEASE_RUNTIME':
        sys.exit('FAIL: application entrypoint excluded: ' + entrypoint)
for name, entry in entries.items():
    if entry['classification'] not in ('RELEASE_RUNTIME', 'RELEASE_TEST'):
        continue
    for imported in entry['localImports']:
        target = entries.get(imported, {}).get('classification')
        allowed_target = ('RELEASE_RUNTIME',) if entry['classification'] == 'RELEASE_RUNTIME' else ('RELEASE_RUNTIME', 'RELEASE_TEST')
        if target not in allowed_target:
            sys.exit('FAIL: reachable dependency excluded or missing: ' + name + ' -> ' + imported)
actual = set(subprocess.check_output(
    ['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'],
    cwd=root).decode().split('\0'))
actual = {x for x in actual if x.endswith('.dart') and (root / x).is_file()}
drift = sorted(actual ^ entries.keys())
for name in sorted(actual & entries.keys()):
    if hashlib.sha256((root / name).read_bytes()).hexdigest() != entries[name]['sha256']:
        drift.append(name)
if drift:
    sys.exit('FAIL: source inventory changed; renewed AST review required: ' + ', '.join(drift))
flutter = Path(os.environ.get('FLUTTER_BIN') or shutil.which('flutter') or 'flutter').resolve()
dart = flutter.parent / 'cache/dart-sdk/bin/dart'
result = subprocess.run([str(dart), 'analyze', '--format', 'machine', str(root)],
                        cwd=root, capture_output=True, text=True)
(args.output / 'full-analyze-machine.txt').write_text(result.stdout + result.stderr)
if result.returncode not in (0, 1, 2, 3):
    sys.exit('FAIL: analyzer infrastructure exit ' + str(result.returncode))
issues = []
for line in (result.stdout + '\n' + result.stderr).splitlines():
    cols = line.split('|', 7)
    if len(cols) != 8 or cols[0] not in ('ERROR', 'WARNING', 'INFO'):
        continue
    severity, kind, rule, path, lineno, column, length, message = cols
    try:
        name = str(Path(path).relative_to(root))
    except ValueError:
        name = path
    classification = entries.get(name, {}).get('classification', 'UNKNOWN')
    issues.append(dict(severity=severity, rule=rule, path=name, line=int(lineno),
                       column=int(column), message=message, classification=classification))
if not issues and result.returncode:
    sys.exit('FAIL: analyzer failed without parseable diagnostics')
release = [x for x in issues if x['classification'] in ('RELEASE_RUNTIME', 'RELEASE_TEST')]
# Security-sensitive diagnostic families remain blockers even at info severity.
security_rules = {'use_build_context_synchronously', 'unawaited_futures',
                  'discarded_futures', 'cancel_subscriptions', 'close_sinks'}
security = [x for x in release if x['severity'] == 'INFO' and x['rule'].lower() in security_rules]
counts = Counter(x['severity'] for x in release)
unknown = [x for x in issues if x['classification'] == 'UNKNOWN']
summary = dict(full=dict(Counter(x['severity'] for x in issues)), release=dict(counts),
               securityRelevantInfos=len(security), unknownDiagnostics=len(unknown),
               byClassification={c: dict(Counter(x['severity'] for x in issues if x['classification'] == c))
                                 for c in sorted({x['classification'] for x in issues})})
(args.output / 'analyzer-diagnostics.json').write_text(json.dumps(issues, indent=2) + '\n')
(args.output / 'analyzer-summary.json').write_text(json.dumps(summary, indent=2) + '\n')
(args.output / 'security-relevant-infos.json').write_text(json.dumps(security, indent=2) + '\n')
(args.output / 'release-analyze.txt').write_text(json.dumps(summary, indent=2) + '\n\n' + '\n'.join(
    f"{x['severity']} {x['path']}:{x['line']} {x['rule']} {x['message']}" for x in release) + '\n')
print(json.dumps(summary, indent=2))
sys.exit(1 if counts['ERROR'] or counts['WARNING'] or security or unknown else 0)
