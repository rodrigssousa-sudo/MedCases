"""Offline eligibility adapter for the existing schema-2 catalog and review forms.

Never authenticates a signature independently. Reuses the historical validator
and requires human acceptance bound to the complete form/scope. No Firestore,
credentials, network, medical generation or activation is implemented here.
"""
import argparse
import copy
import datetime
import json
import re
import subprocess
from collections import defaultdict
from pathlib import Path
import unicodedata

from medical_review import validar_decisoes as historical

COLLECTIONS = (
    'clinical_identity_registry', 'clinical_protocols',
    'clinical_classification_registry', 'clinical_management_rules',
    'clinical_action_registry', 'clinical_content_registry',
    'clinical_projection_registry', 'clinical_legacy_protocols',
)
KEY = re.compile(r'^[A-Za-z0-9][A-Za-z0-9_.-]{0,199}$')
HERE = Path(__file__).resolve().parent


class Rejected(ValueError):
    pass


def require(condition, code):
    if not condition:
        raise Rejected(code)


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, 'DUPLICATE_JSON_KEY')
        result[key] = value
    return result


def load(path):
    return json.loads(Path(path).read_text(encoding='utf-8'),
                      object_pairs_hook=unique_object,
                      parse_constant=lambda _: (_ for _ in ()).throw(Rejected('INVALID_JSON_NUMBER')))


def text_hash(text):
    import hashlib
    return hashlib.sha256(text.encode('utf-8')).hexdigest()


def schema2(action, **kwargs):
    # Input is passed on stdin; nothing is interpolated into shell commands.
    proc = subprocess.run(['node', str(HERE / 'offline_schema2.mjs')],
                          input=json.dumps({'action': action, **kwargs}, ensure_ascii=False),
                          text=True, capture_output=True, timeout=30, check=False)
    require(proc.returncode in (0, 1) and proc.stdout, 'SCHEMA_VALIDATOR_UNAVAILABLE')
    result = json.loads(proc.stdout)
    require(result.get('ok') is True, 'SCHEMA_2_' + str(result.get('code', 'INVALID')))
    return result


def owner_of(collection, row):
    if collection == 'clinical_identity_registry':
        return row.get('canonicalKey')
    if collection == 'clinical_action_registry':
        match = row.get('match') or {}
        return match.get('canonicalPathologyKey', row.get('canonicalPathologyKey')) if isinstance(match, dict) else None
    return row.get('canonicalPathologyKey')


def fold(alias):
    return re.sub(r'\s+', ' ', ''.join(c for c in unicodedata.normalize('NFD', alias)
                                     if not unicodedata.combining(c)).lower()).strip()


def nonempty(value):
    return isinstance(value, str) and bool(value.strip())


def projection_text(projection):
    require(isinstance(projection, dict), 'MISSING_PROJECTION')
    if projection.get('format') == 'markdown':
        text = projection.get('markdown')
    else:
        sections = projection.get('sections')
        require(projection.get('format') == 'structured' and nonempty(projection.get('title'))
                and isinstance(sections, list) and len(sections) == 1
                and sections[0].get('type') == 'paragraph', 'UNSUPPORTED_FULL_PROJECTION')
        text = '# ' + projection['title'] + '\n\n' + sections[0]['text']
    require(nonempty(text), 'EMPTY_PROJECTION')
    return text


def registries_from_release(release):
    result = {key: [] for key in COLLECTIONS}
    for descriptor in release['manifest']['chunks']:
        result[descriptor['collection']].extend(json.loads(release['chunks'][descriptor['id']]['json']))
    return result


def validate_review(package, forms, acceptances, evidence_root, current, owner, version,
                    payload_hash, projection_hashes, registries, index):
    require(1 <= len(forms) <= 2, 'MISSING_OR_AMBIGUOUS_REVIEW_FORM')
    covered, reviews = set(), []
    for form in forms:
        require(form.get('sourceVersion') == version, 'REVIEW_VERSION_MISMATCH')
        scope = form.get('approvalScope')
        require(isinstance(scope, dict), 'APPROVAL_SCOPE_REQUIRED')
        require(scope.get('canonicalId') == owner and scope.get('sourceVersion') == version,
                'APPROVAL_SCOPE_ID_VERSION')
        require(scope.get('level') == 'FULL' and scope.get('use') == 'general_protocol_reference',
                'APPROVAL_SCOPE_NOT_GENERAL_FULL')
        languages = scope.get('languages')
        require(isinstance(languages, list) and len(languages) in (1, 2)
                and len(set(languages)) == len(languages)
                and set(languages) <= {'pt', 'es'}, 'TRANSLATION_APPROVAL_PENDING')
        require(not covered.intersection(languages), 'DUPLICATE_APPROVED_LOCALE')
        require(scope.get('payloadSha256') == payload_hash, 'APPROVAL_PAYLOAD_HASH')
        expected_hashes = {mode: {locale: values[locale] for locale in languages}
                           for mode, values in projection_hashes.items()}
        require(scope.get('projectionSha256') == expected_hashes, 'FINAL_PT_ES_HASH_BINDING')
        require(scope.get('registriesSha256') == historical.canonical(registries),
                'APPROVAL_REGISTRIES_HASH_MISMATCH')
        covers = scope.get('covers')
        required = {'clinical_text', 'medications_doses_conditions'}
        if 'es' in languages:
            required.add('translations')
        require(isinstance(covers, list) and required <= set(covers), 'CLINICAL_SCOPE_INCOMPLETE')
        require(form.get('pendingClinicalIssues') == [], 'CLINICAL_ISSUES_PENDING_OR_UNSPECIFIED')
        require(nonempty(form.get('recordId')), 'REVIEW_RECORD_ID_REQUIRED')
        decisions = form.get('decisions', [])
        require(len(decisions) == len(languages) and {d.get('locale') for d in decisions} == set(languages),
                'EXACT_PT_ES_DECISIONS_REQUIRED')
        form_hash = historical.canonical(form)
        try:
            decided = datetime.datetime.fromisoformat(form['decidedAt'].replace('Z', '+00:00'))
            require(decided.tzinfo is not None and decided <= datetime.datetime.now(datetime.timezone.utc),
                    'DECISION_DATE_INVALID')
        except (KeyError, TypeError, ValueError):
            raise Rejected('DECISION_DATE_INVALID') from None
        for decision in decisions:
            locale = decision['locale']
            aid = owner + ':FULL:' + locale
            require(decision.get('artifactId') == aid, 'ARTIFACT_SCOPE_MISMATCH')
            require(decision.get('decision') == 'APPROVED', 'MEDICAL_DECISION_NOT_APPROVED')
            artifact = index.get(aid, {})
            # Direct final text binds byte-for-byte. An assembled historical
            # review document additionally binds the exact source payload.
            source_hashes = artifact.get('sourcePayloadHashes')
            if source_hashes is not None:
                require(payload_hash in source_hashes, 'REVIEW_SOURCE_PAYLOAD_MISMATCH')
            else:
                require(artifact.get('sha256') == projection_hashes['plantao'][locale],
                        'REVIEW_FINAL_TEXT_MISMATCH')
            matches = [a for a in acceptances if a.get('artifactId') == aid
                       and a.get('artifactSha256') == decision.get('artifactSha256')
                       and a.get('signatureEvidenceSha256') == decision.get('signatureEvidence', {}).get('sha256')]
            require(len(matches) == 1, 'MISSING_OR_DUPLICATE_SIGNATURE_ACCEPTANCE')
            acceptance = matches[0]
            require(acceptance.get('decisionFormSha256') == form_hash, 'HUMAN_ACCEPTANCE_SCOPE_UNBOUND')
            reviewer = form.get('reviewer', {})
            require(acceptance.get('reviewerRegistration') == reviewer.get('professionalRegistration')
                    and acceptance.get('reviewerJurisdiction') == reviewer.get('jurisdiction'),
                    'HUMAN_ACCEPTANCE_REVIEWER_MISMATCH')
        covered.update(languages)
        reviews.append({'recordId': form['recordId'], 'decisionFormSha256': form_hash,
                        'scope': copy.deepcopy(scope)})
    require(covered == {'pt', 'es'}, 'TRANSLATION_APPROVAL_PENDING')
    # Historical artifact/matrix/evidence hashes, reviewer/date, version and
    # concurrent-catalog checks remain mandatory for either review arrangement.
    result = historical.validate(package, forms, current['manifest'], current['pointer'],
                                 acceptances, evidence_root)
    return {'records': reviews, 'historicalValidation': result}


def stage(package, incoming, current, forms, acceptances, evidence_root):
    package, evidence_root = Path(package).resolve(), Path(evidence_root).resolve()
    require(incoming.get('schemaVersion') == 2, 'SCHEMA_2_REQUIRED')
    version = incoming.get('contentVersion')
    require(isinstance(version, str) and re.fullmatch(r'[A-Za-z0-9._-]{1,120}', version),
            'INVALID_TARGET_VERSION')
    validated = schema2('verifySnapshot', release={'manifest': current['manifest'], 'chunks': current['chunks']})
    require(current.get('pointer', {}).get('schemaVersion') == 2
            and current['pointer'].get('status') == 'ACTIVE'
            and current['manifest'].get('status') == 'ACTIVE'
            and current['pointer'].get('activeVersion') == current['manifest']['contentVersion']
            and current['pointer'].get('manifestSha256') == validated['manifestSha256'],
            'CURRENT_CATALOG_BINDING_INVALID')
    snapshot = load(package / '00_CONTROLE_E_FONTES/ponteiro_produtivo.json')
    require(snapshot.get('activeVersion') == current['pointer']['activeVersion']
            and snapshot.get('manifestSha256') == current['pointer']['manifestSha256'],
            'CONCURRENT_CATALOG_CHANGE_REVIEW_REQUIRED')
    require(version != current['pointer']['activeVersion'], 'IMMUTABLE_VERSION_REUSE')
    native = incoming.get('registries')
    require(isinstance(native, dict) and set(native) == set(COLLECTIONS)
            and all(isinstance(native[c], list) for c in COLLECTIONS), 'NATIVE_REGISTRIES_REQUIRED')
    require(isinstance(forms, list) and isinstance(acceptances, list), 'REVIEW_INPUT_INVALID')
    index = load(package / 'artefatos_revisaveis.json')
    grouped = defaultdict(lambda: {c: [] for c in COLLECTIONS})
    rejected = []
    for collection, rows in native.items():
        for position, row in enumerate(rows):
            owner = owner_of(collection, row) if isinstance(row, dict) else None
            if not isinstance(owner, str) or not KEY.fullmatch(owner):
                rejected.append({'identity': None, 'collection': collection, 'position': position,
                                 'code': 'CANONICAL_ID_REQUIRED'})
                continue
            grouped[owner][collection].append(row)
    baseline = registries_from_release(current)
    require(len({i.get('canonicalKey') for i in baseline['clinical_identity_registry']})
            == len(baseline['clinical_identity_registry']) == current['manifest']['ownerCount'],
            'CURRENT_IDENTITY_INDEX_INVALID')
    baseline_ids = {i['canonicalKey']: i for i in baseline['clinical_identity_registry']}
    aliases = defaultdict(set)
    for identity in baseline['clinical_identity_registry'] + native['clinical_identity_registry']:
        if not isinstance(identity, dict) or not isinstance(identity.get('canonicalKey'), str):
            continue
        owner = identity['canonicalKey']
        for alias in [owner, *(identity.get('aliases') if isinstance(identity.get('aliases'), list) else [])]:
            if isinstance(alias, str) and alias.strip():
                aliases[fold(alias)].add(owner)
    forms_by_owner = defaultdict(list)
    for form in forms:
        if isinstance(form, dict):
            forms_by_owner[str(form.get('identity'))].append(form)
    eligible = []
    for owner, registries in grouped.items():
        try:
            identities = registries['clinical_identity_registry']
            projections = registries['clinical_projection_registry']
            require(len(identities) == len(projections) == 1, 'DUPLICATE_OR_MISSING_CANONICAL_RECORD')
            identity, projection = identities[0], projections[0]
            require(not owner.isdecimal() or owner in baseline_ids, 'LIST_NUMBER_IS_NOT_CANONICAL_ID')
            require(isinstance(identity.get('aliases'), list)
                    and all(nonempty(a) for a in identity['aliases']), 'ALIASES_INVALID')
            require(all(len(aliases[fold(a)]) == 1 for a in [owner, *identity['aliases']]),
                    'AMBIGUOUS_CANONICAL_ALIAS')
            require(identity.get('enabled') is True and projection.get('enabled') is True,
                    'RECORD_DISABLED')
            require(owner not in baseline_ids or baseline_ids[owner].get('enabled') is not False,
                    'BASELINE_IDENTITY_DISABLED')
            source_version = identity.get('version')
            require(nonempty(source_version) and projection.get('version') == source_version,
                    'SOURCE_VERSION_MISMATCH')
            payload = projection.get('payload', {})
            require(isinstance(payload, dict), 'INVALID_PAYLOAD_SHAPE')
            raw = payload.get('approvedClinicalPayloadJson')
            require(isinstance(raw, str), 'ORIGINAL_PAYLOAD_REQUIRED')
            payload_hash = text_hash(raw)
            require(payload.get('approvedClinicalPayloadSha256') == payload_hash
                    and projection.get('approvedClinicalPayloadSha256') == payload_hash
                    and identity.get('approvedClinicalPayloadSha256') == payload_hash,
                    'SOURCE_PAYLOAD_HASH_MISMATCH')
            original = json.loads(raw, object_pairs_hook=unique_object)
            require(isinstance(original, dict), 'INVALID_ORIGINAL_PAYLOAD_SHAPE')
            require((original.get('owner') or original.get('ownerId') or original.get('ownerCandidate')) == owner
                    and original.get('version') == source_version, 'ORIGINAL_ID_VERSION_MISMATCH')
            hashes = {mode: {locale: text_hash(projection_text(payload.get(locale, {}).get(mode + 'Projection')))
                             for locale in ('pt', 'es')} for mode in ('plantao', 'study')}
            review = validate_review(package, forms_by_owner[owner], acceptances, evidence_root,
                                     current, owner, source_version, payload_hash, hashes, registries, index)
            proof = schema2('prepare', version=version, registries=registries)
            require(proof['release']['manifest']['status'] == 'DRAFT', 'DRAFT_REQUIRED')
            eligible.append({'identity': owner, 'sourceVersion': source_version,
                             'payloadSha256': payload_hash, 'projectionSha256': hashes,
                             'review': review, 'registries': copy.deepcopy(registries),
                             'eligibleForStaging': True, 'publicationAuthorized': False})
        except (ValueError, KeyError, TypeError, AttributeError, IndexError, OSError, subprocess.SubprocessError) as error:
            # Invalid records are isolated; no partial promotion of their languages.
            code = str(error) if isinstance(error, (Rejected, ValueError)) else 'INVALID_RECORD_SHAPE'
            rejected.append({'identity': owner, 'code': code})
    return {'schemaVersion': 2, 'contentVersion': version,
            'baseCatalogVersion': current['pointer']['activeVersion'],
            'baseManifestSha256': current['pointer']['manifestSha256'],
            'eligibleRecords': eligible, 'rejectedRecords': rejected,
            'counts': {'eligible': len(eligible), 'rejected': len(rejected)},
            'state': 'LOCAL_STAGING_ONLY', 'publicationAuthorized': False, 'remoteWrites': 0,
            'signatureCryptographicallyVerifiedByThisTool': False,
            'note': 'Human acceptance is an input. Staged records must be merged with the current catalog '
                    'and revalidated before any separately authorized publication.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for key in ('package', 'input', 'current-catalog', 'decisions', 'signature-acceptances', 'evidence-root', 'output'):
        parser.add_argument('--' + key, type=Path, required=True)
    args = parser.parse_args()
    # This CLI writes only a NEW local output directory, after all inputs are read.
    require(not args.output.exists(), 'OUTPUT_MUST_NOT_EXIST')
    files = {'input': args.input, 'currentCatalog': args.current_catalog,
             'decisions': args.decisions, 'signatureAcceptances': args.signature_acceptances,
             'artifactIndex': args.package / 'artefatos_revisaveis.json',
             'reviewPointer': args.package / '00_CONTROLE_E_FONTES/ponteiro_produtivo.json'}
    before = {key: historical.digest(path) for key, path in files.items()}
    result = stage(args.package, load(args.input), load(args.current_catalog), load(args.decisions),
                   load(args.signature_acceptances), args.evidence_root)
    require(before == {key: historical.digest(path) for key, path in files.items()},
            'INPUT_CHANGED_DURING_VALIDATION')
    for record in result['eligibleRecords']:
        # Recheck final artifact/matrix/evidence bytes immediately before writing
        # local staging. Publication must revalidate again against then-current data.
        historical.validate(args.package, [f for f in load(args.decisions)
                                           if f.get('identity') == record['identity']],
                            load(args.current_catalog)['manifest'], load(args.current_catalog)['pointer'],
                            load(args.signature_acceptances), args.evidence_root)
    args.output.mkdir(parents=True, exist_ok=False)
    (args.output / 'staging.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    (args.output / 'input-sha256.json').write_text(json.dumps(before, indent=2) + '\n')
    print(json.dumps({'state': result['state'], 'counts': result['counts'], 'remoteWrites': 0}))


if __name__ == '__main__':
    main()
