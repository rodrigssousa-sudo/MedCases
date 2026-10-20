"""Offline staging validator. No credentials, network, database writes or publication.
Signature/authorship assessment is a human prerequisite, never inferred from a PDF.
"""
import argparse,datetime,hashlib,json
from pathlib import Path

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def canonical(value):return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':'),ensure_ascii=False).encode()).hexdigest()
def contained(root,relative):
 p=(root/relative).resolve()
 if not p.is_relative_to(root.resolve()):raise ValueError('PATH_OUTSIDE_PACKAGE')
 return p

def validate(package,decisions,current_manifest,current_pointer,signature_acceptances,evidence_root):
 index=json.loads((package/'artefatos_revisaveis.json').read_text());snapshot=json.loads((package/'00_CONTROLE_E_FONTES/ponteiro_produtivo.json').read_text());accepted=[]
 if canonical(current_manifest)!=current_pointer.get('manifestSha256'):raise ValueError('CURRENT_MANIFEST_HASH_INVALID')
 if current_pointer.get('activeVersion')!=snapshot['activeVersion'] or current_pointer.get('manifestSha256')!=snapshot['manifestSha256']:raise ValueError('CONCURRENT_CATALOG_CHANGE_REVIEW_REQUIRED')
 seen=set()
 for form in decisions:
  if form.get('manifestSha256')!=snapshot['manifestSha256'] or form.get('catalogVersion')!=snapshot['activeVersion']:raise ValueError('STALE_DECISION')
  reviewer=form.get('reviewer',{})
  for field in ['name','professionalRegistration','jurisdiction']:
   if not isinstance(reviewer.get(field),str) or not reviewer[field].strip():raise ValueError('REVIEWER_INCOMPLETE')
  try:date=datetime.datetime.fromisoformat(form['decidedAt'].replace('Z','+00:00'))
  except (KeyError,ValueError):raise ValueError('DECISION_DATE_REQUIRED')
  if date.tzinfo is None:raise ValueError('DECISION_TIMEZONE_REQUIRED')
  for decision in form.get('decisions',[]):
   state=decision.get('decision')
   if state=='PENDING':continue
   if state not in ['APPROVED','CHANGES_REQUIRED','REJECTED']:raise ValueError('INVALID_DECISION')
   aid=decision.get('artifactId');a=index.get(aid)
   if not a or aid in seen:raise ValueError('UNKNOWN_OR_DUPLICATE_ARTIFACT')
   seen.add(aid)
   if aid.split(':')[0]!=form.get('identity') or a['locale']!=decision.get('locale') or a['sourceVersion']!=form.get('sourceVersion'):raise ValueError('IDENTITY_LOCALE_VERSION_MISMATCH')
   if not a.get('available'):raise ValueError('INCOMPLETE_SOURCE_NOT_APPROVABLE')
   if decision.get('artifactSha256')!=a['sha256'] or digest(contained(package,a['path']))!=a['sha256']:raise ValueError('ARTIFACT_HASH_MISMATCH')
   if decision.get('matrixSha256')!=a.get('matrixSha256'):raise ValueError('OMISSION_MATRIX_HASH_MISMATCH')
   if a.get('matrixSha256'):
    matrix=contained(package,a['path']).parent/'omission-matrix.json'
    if digest(matrix)!=a['matrixSha256']:raise ValueError('OMISSION_MATRIX_CHANGED')
   sig=decision.get('signatureEvidence',{});sp=contained(evidence_root,sig.get('path',''))
   if not sp.is_file() or digest(sp)!=sig.get('sha256'):raise ValueError('SIGNED_EVIDENCE_MISSING_OR_CHANGED')
   acceptance=next((x for x in signature_acceptances if x.get('artifactId')==aid and x.get('artifactSha256')==a['sha256'] and x.get('signatureEvidenceSha256')==sig['sha256']),None)
   if not acceptance or acceptance.get('signatureReviewed') is not True or acceptance.get('decisionTranscriptionVerified') is not True or acceptance.get('reviewerName')!=reviewer['name'] or acceptance.get('decision')!=state or not all(acceptance.get(k) for k in ['acceptedBy','acceptedAt','policyVersion','method','verificationLimitations']):raise ValueError('HUMAN_SIGNATURE_ACCEPTANCE_REQUIRED')
   accepted.append({'artifactId':aid,'decision':state,'artifactSha256':a['sha256'],'sourceVersion':a['sourceVersion'],'reviewer':reviewer,'decidedAt':form['decidedAt'],'signatureEvidenceSha256':sig['sha256'],'verificationMethod':acceptance['method'],'verificationLimitations':acceptance['verificationLimitations'],'publicationReady':False,'remainingGates':['clinical schema/medication mapping validation','current production updateTime preconditions','explicit publication authorization']})
 if not accepted:raise ValueError('NO_EFFECTIVE_SIGNED_DECISION')
 return {'validation':'PASS','validatedDecisions':accepted,'remoteWrites':0,'signatureCryptographicallyVerifiedByThisTool':False,'note':'Validation/staging only; human signature acceptance is an input, not proof independently established by this tool.'}

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--package',type=Path,required=True);p.add_argument('--decisions',type=Path,required=True);p.add_argument('--current-manifest',type=Path,required=True);p.add_argument('--current-pointer',type=Path,required=True);p.add_argument('--signature-acceptances',type=Path,required=True);p.add_argument('--evidence-root',type=Path,required=True);p.add_argument('--validate-only',action='store_true',required=True);a=p.parse_args()
 try:
  load=lambda f:json.loads(f.read_text());print(json.dumps(validate(a.package,load(a.decisions),load(a.current_manifest),load(a.current_pointer),load(a.signature_acceptances),a.evidence_root),ensure_ascii=False,indent=2))
 except (ValueError,KeyError,OSError,TypeError) as e:raise SystemExit('REJECTED: '+str(e))
