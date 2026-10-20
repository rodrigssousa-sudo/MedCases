"""Nonclinical fixtures: technical validation is never a real medical approval."""
import copy
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import stage_reviewed_protocols as stage


def registries(owner, version='TEST-V1', alias=None):
    result = {key: [] for key in stage.COLLECTIONS}
    original = json.dumps({'owner': owner, 'version': version,
                           'fixture': 'SYNTHETIC NONCLINICAL; NO MEDICAL APPROVAL'}, ensure_ascii=False)
    payload_hash = stage.text_hash(original)
    result['clinical_identity_registry'] = [{'canonicalKey': owner, 'version': version,
                                             'aliases': [alias or owner], 'enabled': True,
                                             'approvedClinicalPayloadSha256': payload_hash}]
    payload = {'approvedClinicalPayloadJson': original, 'approvedClinicalPayloadSha256': payload_hash,
               'references': [{'id': 'SYNTHETIC_REFERENCE_NOT_EVIDENCE'}]}
    for locale in ['pt', 'es']:
        payload[locale] = {}
        for mode in ['plantao', 'study']:
            text = 'SYNTHETIC NONCLINICAL FIXTURE ' + owner + ' ' + locale + ' ' + mode
            payload[locale][mode + 'Markdown'] = text
            payload[locale][mode + 'Projection'] = {
                'format': 'markdown', 'markdown': text, 'references': payload['references']}
    result['clinical_projection_registry'] = [{'canonicalPathologyKey': owner, 'version': version,
                                              'enabled': True, 'approvedClinicalPayloadSha256': payload_hash,
                                              'payload': payload}]
    return result


class StagingTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        (self.root / '00_CONTROLE_E_FONTES').mkdir()
        release = stage.schema2('prepare', version='SYNTHETIC-BASE',
                                registries=registries('baseline_owner'))['release']
        release['manifest']['status'] = 'ACTIVE'
        pointer = {'status': 'ACTIVE', 'schemaVersion': 2, 'activeVersion': 'SYNTHETIC-BASE',
                   'manifestSha256': stage.historical.canonical(release['manifest'])}
        self.current = {**release, 'pointer': pointer}
        self.write('00_CONTROLE_E_FONTES/ponteiro_produtivo.json', pointer)
        self.index, self.forms, self.acceptances = {}, [], []
        self.incoming = {'schemaVersion': 2, 'contentVersion': 'SYNTHETIC-NEXT',
                         'registries': {key: [] for key in stage.COLLECTIONS}}
        self.add('synthetic_valid')

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, relative, value):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(value, ensure_ascii=False, indent=2))
        return path

    def add(self, owner, alias=None):
        rows = registries(owner, alias=alias)
        for key in stage.COLLECTIONS:
            self.incoming['registries'][key].extend(rows[key])
        payload = rows['clinical_projection_registry'][0]['payload']
        hashes = {mode: {locale: stage.text_hash(payload[locale][mode + 'Markdown'])
                         for locale in ['pt', 'es']} for mode in ['plantao', 'study']}
        form = {'schemaVersion': 1, 'recordId': 'SYNTHETIC-REVIEW-' + owner,
                'catalogVersion': self.current['pointer']['activeVersion'],
                'manifestSha256': self.current['pointer']['manifestSha256'],
                'identity': owner, 'sourceVersion': 'TEST-V1', 'decidedAt': '2026-10-14T00:00:00+00:00',
                'reviewer': {'name': 'SYNTHETIC_REVIEWER', 'professionalRegistration': 'TEST_ONLY',
                             'jurisdiction': 'TEST_ONLY'}, 'pendingClinicalIssues': [],
                'publicationAuthorized': False,
                'approvalScope': {'canonicalId': owner, 'sourceVersion': 'TEST-V1',
                                  'level': 'FULL', 'use': 'general_protocol_reference',
                                  'languages': ['pt', 'es'], 'projectionSha256': hashes,
                                  'payloadSha256': payload['approvedClinicalPayloadSha256'],
                                  'registriesSha256': stage.historical.canonical(rows),
                                  'covers': ['clinical_text', 'medications_doses_conditions', 'translations']},
                'decisions': []}
        signature = self.root / (owner + '-signature.txt')
        signature.write_text('SYNTHETIC SIGNATURE FIXTURE; NOT REAL MEDICAL APPROVAL')
        for locale in ['pt', 'es']:
            aid = owner + ':FULL:' + locale
            text_path = self.root / (owner + '-' + locale + '.txt')
            text_path.write_text(payload[locale]['plantaoMarkdown'])
            self.index[aid] = {'locale': locale, 'sourceVersion': 'TEST-V1', 'path': text_path.name,
                               'sha256': stage.historical.digest(text_path), 'available': True}
            form['decisions'].append({'artifactId': aid, 'locale': locale, 'decision': 'APPROVED',
                                      'artifactSha256': self.index[aid]['sha256'],
                                      'signatureEvidence': {'path': signature.name,
                                                            'sha256': stage.historical.digest(signature)}})
        self.forms.append(form)
        self.accept(owner)

    def accept(self, owner):
        """Synthetic human-acceptance input, exclusively inside this fixture."""
        form = next(f for f in self.forms if f['identity'] == owner)
        self.acceptances[:] = [a for a in self.acceptances if not a['artifactId'].startswith(owner + ':')]
        for decision in form['decisions']:
            self.acceptances.append({'artifactId': decision['artifactId'],
                                     'artifactSha256': decision['artifactSha256'],
                                     'signatureEvidenceSha256': decision['signatureEvidence']['sha256'],
                                     'signatureReviewed': True, 'decisionTranscriptionVerified': True,
                                     'reviewerName': form['reviewer']['name'],
                                     'reviewerRegistration': form['reviewer']['professionalRegistration'],
                                     'reviewerJurisdiction': form['reviewer']['jurisdiction'],
                                     'decision': decision['decision'], 'decisionFormSha256': stage.historical.canonical(form),
                                     'acceptedBy': 'SYNTHETIC_ADMIN_TEST_ONLY', 'acceptedAt': '2026-10-14',
                                     'policyVersion': 'TEST_ONLY', 'method': 'TEST_ONLY',
                                     'verificationLimitations': 'SYNTHETIC; NOT REAL APPROVAL'})

    def runcheck(self):
        self.write('artefatos_revisaveis.json', self.index)
        return stage.stage(self.root, self.incoming, self.current, self.forms,
                           self.acceptances, self.root)

    def reject(self, code):
        result = self.runcheck()
        self.assertEqual(result['counts']['eligible'], 0)
        self.assertIn(code, [r['code'] for r in result['rejectedRecords']])

    def test_valid_fixture_stages_exact_bytes_without_publication(self):
        before = copy.deepcopy((self.incoming, self.current, self.forms))
        result = self.runcheck()
        self.assertEqual(result['counts'], {'eligible': 1, 'rejected': 0})
        self.assertEqual(result['eligibleRecords'][0]['registries'], self.incoming['registries'])
        self.assertEqual((self.incoming, self.current, self.forms), before)
        self.assertFalse(result['publicationAuthorized'])
        self.assertFalse(result['signatureCryptographicallyVerifiedByThisTool'])
        self.assertEqual(result['remoteWrites'], 0)

    def test_approval_flag_alone_not_accepted(self):
        self.forms = []
        self.incoming['medical_approval_status'] = 'APPROVED'
        self.reject('MISSING_OR_AMBIGUOUS_REVIEW_FORM')

    def test_missing_reviewer(self):
        self.forms[0]['reviewer']['name'] = ''
        self.accept('synthetic_valid')
        self.reject('REVIEWER_INCOMPLETE')

    def test_missing_scope(self):
        del self.forms[0]['approvalScope']
        self.reject('APPROVAL_SCOPE_REQUIRED')

    def test_scope_added_after_acceptance(self):
        self.forms[0]['recordId'] = 'ALTERED_AFTER_ACCEPTANCE'
        self.reject('HUMAN_ACCEPTANCE_SCOPE_UNBOUND')

    def test_pt_hash_changed(self):
        self.forms[0]['approvalScope']['projectionSha256']['plantao']['pt'] = '0' * 64
        self.accept('synthetic_valid')
        self.reject('FINAL_PT_ES_HASH_BINDING')

    def test_es_hash_changed(self):
        self.forms[0]['approvalScope']['projectionSha256']['plantao']['es'] = '0' * 64
        self.accept('synthetic_valid')
        self.reject('FINAL_PT_ES_HASH_BINDING')

    def test_new_dose_or_condition_after_review_rejected(self):
        p = self.incoming['registries']['clinical_projection_registry'][0]['payload']
        p['es']['plantaoProjection']['markdown'] += ' SYNTHETIC ALTERATION'
        p['es']['plantaoMarkdown'] = p['es']['plantaoProjection']['markdown']
        self.reject('FINAL_PT_ES_HASH_BINDING')

    def test_other_registry_change_after_review_rejected(self):
        self.incoming['registries']['clinical_protocols'].append({'canonicalPathologyKey': 'synthetic_valid',
                                                                'field': 'SYNTHETIC EXTRA FACT'})
        self.reject('APPROVAL_REGISTRIES_HASH_MISMATCH')

    def test_source_hash_changed(self):
        self.incoming['registries']['clinical_projection_registry'][0]['payload']['approvedClinicalPayloadJson'] += ' '
        self.reject('SOURCE_PAYLOAD_HASH_MISMATCH')

    def test_identity_hash_binding(self):
        self.incoming['registries']['clinical_identity_registry'][0]['approvedClinicalPayloadSha256'] = '0' * 64
        self.reject('SOURCE_PAYLOAD_HASH_MISMATCH')

    def test_version_mismatch(self):
        self.forms[0]['sourceVersion'] = 'OTHER'
        self.accept('synthetic_valid')
        self.reject('REVIEW_VERSION_MISMATCH')

    def test_translation_pending(self):
        self.forms[0]['approvalScope']['languages'] = ['pt']
        for mode in ['plantao', 'study']:
            del self.forms[0]['approvalScope']['projectionSha256'][mode]['es']
        self.forms[0]['decisions'] = self.forms[0]['decisions'][:1]
        self.accept('synthetic_valid')
        self.reject('TRANSLATION_APPROVAL_PENDING')

    def test_scope_list_order_does_not_change_meaning(self):
        self.forms[0]['approvalScope']['languages'].reverse()
        self.forms[0]['approvalScope']['covers'].reverse()
        self.accept('synthetic_valid')
        self.assertEqual(self.runcheck()['counts']['eligible'], 1)

    def test_separate_legitimate_pt_es_reviewers_supported(self):
        original = self.forms.pop()
        self.acceptances = []
        for locale in ['pt', 'es']:
            form = copy.deepcopy(original)
            form['recordId'] += '-' + locale
            form['reviewer']['name'] += '-' + locale
            form['approvalScope']['languages'] = [locale]
            for mode in ['plantao', 'study']:
                form['approvalScope']['projectionSha256'][mode] = {
                    locale: original['approvalScope']['projectionSha256'][mode][locale]}
            form['decisions'] = [d for d in form['decisions'] if d['locale'] == locale]
            self.forms.append(form)
            decision = form['decisions'][0]
            self.acceptances.append({'artifactId': decision['artifactId'],
                                     'artifactSha256': decision['artifactSha256'],
                                     'signatureEvidenceSha256': decision['signatureEvidence']['sha256'],
                                     'signatureReviewed': True, 'decisionTranscriptionVerified': True,
                                     'reviewerName': form['reviewer']['name'],
                                     'reviewerRegistration': form['reviewer']['professionalRegistration'],
                                     'reviewerJurisdiction': form['reviewer']['jurisdiction'],
                                     'decision': 'APPROVED', 'decisionFormSha256': stage.historical.canonical(form),
                                     'acceptedBy': 'SYNTHETIC_ADMIN_TEST_ONLY', 'acceptedAt': '2026-10-14',
                                     'policyVersion': 'TEST_ONLY', 'method': 'TEST_ONLY',
                                     'verificationLimitations': 'SYNTHETIC; NOT REAL APPROVAL'})
        self.assertEqual(self.runcheck()['counts']['eligible'], 1)

    def test_missing_es(self):
        del self.incoming['registries']['clinical_projection_registry'][0]['payload']['es']
        self.reject('MISSING_PROJECTION')

    def test_clinical_pending(self):
        self.forms[0]['pendingClinicalIssues'] = ['SYNTHETIC_PENDING']
        self.accept('synthetic_valid')
        self.reject('CLINICAL_ISSUES_PENDING_OR_UNSPECIFIED')

    def test_rejected_review(self):
        self.forms[0]['decisions'][1]['decision'] = 'REJECTED'
        self.accept('synthetic_valid')
        self.reject('MEDICAL_DECISION_NOT_APPROVED')

    def test_no_dose_scope(self):
        self.forms[0]['approvalScope']['covers'].remove('medications_doses_conditions')
        self.accept('synthetic_valid')
        self.reject('CLINICAL_SCOPE_INCOMPLETE')

    def test_missing_human_acceptance(self):
        self.acceptances = []
        self.reject('MISSING_OR_DUPLICATE_SIGNATURE_ACCEPTANCE')

    def test_signature_changed(self):
        (self.root / 'synthetic_valid-signature.txt').write_text('SYNTHETIC TAMPERING')
        self.reject('SIGNED_EVIDENCE_MISSING_OR_CHANGED')

    def test_artifact_changed(self):
        (self.root / 'synthetic_valid-pt.txt').write_text('SYNTHETIC TAMPERING')
        self.reject('ARTIFACT_HASH_MISMATCH')

    def test_alias_collision_preserves_unaffected_record(self):
        self.add('ambiguous_one', alias='shared alias')
        self.add('ambiguous_two', alias='shared alias')
        result = self.runcheck()
        self.assertEqual(result['counts'], {'eligible': 1, 'rejected': 2})
        self.assertEqual(result['eligibleRecords'][0]['identity'], 'synthetic_valid')
        self.assertTrue(all(r['code'] == 'AMBIGUOUS_CANONICAL_ALIAS' for r in result['rejectedRecords']))

    def test_invalid_record_does_not_discard_valid_record(self):
        self.add('synthetic_invalid')
        self.forms[1]['pendingClinicalIssues'] = ['PENDING']
        self.accept('synthetic_invalid')
        result = self.runcheck()
        self.assertEqual(result['counts'], {'eligible': 1, 'rejected': 1})

    def test_numeric_list_id_not_promoted(self):
        self.add('238')
        result = self.runcheck()
        self.assertEqual(result['counts']['eligible'], 1)
        self.assertEqual(result['rejectedRecords'][0]['code'], 'LIST_NUMBER_IS_NOT_CANONICAL_ID')

    def test_duplicate_owner_not_overwritten(self):
        self.incoming['registries']['clinical_identity_registry'] *= 2
        self.reject('DUPLICATE_OR_MISSING_CANONICAL_RECORD')

    def test_malformed_record_isolated(self):
        self.add('synthetic_invalid')
        self.incoming['registries']['clinical_projection_registry'][1]['payload'] = None
        result = self.runcheck()
        self.assertEqual(result['counts'], {'eligible': 1, 'rejected': 1})

    def test_active_snapshot_preserves_disabled_identity(self):
        # Active catalog may legitimately retain blocked identities for no-WEB-bypass.
        descriptor = next(d for d in self.current['manifest']['chunks']
                          if d['collection'] == 'clinical_identity_registry')
        chunk = self.current['chunks'][descriptor['id']]
        rows = json.loads(chunk['json'])
        rows[0]['enabled'] = False
        chunk['json'] = json.dumps(rows)
        descriptor['sha256'] = stage.text_hash(chunk['json'])
        self.current['pointer']['manifestSha256'] = stage.historical.canonical(self.current['manifest'])
        self.write('00_CONTROLE_E_FONTES/ponteiro_produtivo.json', self.current['pointer'])
        self.forms[0]['manifestSha256'] = self.current['pointer']['manifestSha256']
        self.accept('synthetic_valid')
        self.assertEqual(self.runcheck()['counts']['eligible'], 1)
        self.assertFalse(json.loads(chunk['json'])[0]['enabled'])

    def test_current_manifest_tampered(self):
        self.current['manifest']['contentVersion'] = 'TAMPERED'
        with self.assertRaisesRegex(stage.Rejected, 'CURRENT_CATALOG_BINDING_INVALID'):
            self.runcheck()

    def test_stale_review_snapshot(self):
        self.write('00_CONTROLE_E_FONTES/ponteiro_produtivo.json', {'activeVersion': 'OLD'})
        with self.assertRaisesRegex(stage.Rejected, 'CONCURRENT_CATALOG_CHANGE'):
            self.runcheck()

    def test_duplicate_json_keys_rejected(self):
        path = self.root / 'duplicate.json'
        path.write_text('{"schemaVersion":2,"schemaVersion":1}')
        with self.assertRaisesRegex(stage.Rejected, 'DUPLICATE_JSON_KEY'):
            stage.load(path)

    def test_cli_creates_only_new_local_staging(self):
        self.write('artefatos_revisaveis.json', self.index)
        paths = {key: self.write(key + '.json', value) for key, value in {
            'input': self.incoming, 'current-catalog': self.current,
            'decisions': self.forms, 'signature-acceptances': self.acceptances}.items()}
        before = {key: stage.historical.digest(path) for key, path in paths.items()}
        output = self.root / 'local-staging'
        args = [sys.executable, str(Path(stage.__file__)), '--package', str(self.root),
                '--evidence-root', str(self.root), '--output', str(output)]
        for key, value in paths.items():
            args.extend(['--' + key, str(value)])
        result = subprocess.run(args, capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stderr)
        saved = json.loads((output / 'staging.json').read_text())
        self.assertEqual(saved['counts']['eligible'], 1)
        self.assertEqual(saved['state'], 'LOCAL_STAGING_ONLY')
        self.assertFalse(saved['publicationAuthorized'])
        self.assertEqual(before, {key: stage.historical.digest(path) for key, path in paths.items()})
        repeated = subprocess.run(args, capture_output=True, text=True, timeout=20)
        self.assertNotEqual(repeated.returncode, 0)
        self.assertIn('OUTPUT_MUST_NOT_EXIST', repeated.stderr)


if __name__ == '__main__':
    unittest.main()
