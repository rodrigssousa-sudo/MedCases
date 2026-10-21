"""Assemble the existing commercial handler in a temporary local directory.

No deployment, credentials, remote writes or dependency installation. Both the
original release package and clinical source samples remain untouched.
"""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parent
manifest = json.loads((root / 'backend-delta-manifest.json').read_text())
base = Path(manifest['base'])
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
for entry in manifest['files']:
    assert sha(base / entry['path']) == entry['before'], 'BASELINE_CHANGED'
    assert sha(root / 'backend-delta' / entry['path']) == entry['after'], 'DELTA_CHANGED'
harness = Path(manifest['harness']['path'])
assert sha(harness) == manifest['harness']['sha256'], 'HARNESS_CHANGED'
for drug, expected in manifest['sampleHashes'].items():
    assert sha(Path(manifest['sampleSourceDirectory']) / (drug + '.json')) == expected, 'SOURCE_CHANGED'

target = Path(tempfile.mkdtemp(prefix='medcases-existing-commercial-integration-'))
shutil.copytree(base, target / 'functions', ignore=shutil.ignore_patterns('node_modules', '.git'))
if (base / 'node_modules').exists():
    (target / 'functions/node_modules').symlink_to(base / 'node_modules', target_is_directory=True)
for entry in manifest['files']:
    shutil.copy2(root / 'backend-delta' / entry['path'], target / 'functions' / entry['path'])
shutil.copytree(harness.parent, target / 'tests', ignore=shutil.ignore_patterns('*.log', 'node_modules'))
subprocess.run(['patch', '-p1', '--batch', '-i', str(root / 'commercial-harness.patch')], cwd=target, check=True, capture_output=True)
assert sha(target / 'tests' / harness.name) == manifest['harness']['after'], 'HARNESS_PATCH_MISMATCH'
(root / 'evidence/integration-candidate-path.txt').write_text(str(target / 'functions') + '\n')
(root / 'evidence/integration-test-path.txt').write_text(str(target / 'tests' / harness.name) + '\n')
print('EXISTING_HANDLER_PREPARED_LOCALLY=YES')
print('REMOTE_MUTATIONS=0')
