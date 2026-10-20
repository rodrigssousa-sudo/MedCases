import unittest,tempfile,json,copy,importlib.util,hashlib
from pathlib import Path
path=Path(__file__).with_name('validar_decisoes.py');s=importlib.util.spec_from_file_location('validator',path);v=importlib.util.module_from_spec(s);s.loader.exec_module(v)
class Tests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.p=Path(self.tmp.name);(self.p/'00_CONTROLE_E_FONTES').mkdir();(self.p/'artifact.txt').write_text('SYNTHETIC NONCLINICAL FIXTURE');(self.p/'signature.txt').write_text('SYNTHETIC SIGNATURE EVIDENCE; NOT A REAL APPROVAL')
  h=v.digest(self.p/'artifact.txt');sh=v.digest(self.p/'signature.txt');self.m={'synthetic':True};self.ptr={'activeVersion':'SYNTHETIC_V1','manifestSha256':v.canonical(self.m)};self.aid='synthetic:FULL:pt';self.idx={self.aid:{'locale':'pt','sourceVersion':'SYNTHETIC_V1','path':'artifact.txt','sha256':h,'available':True}};(self.p/'artefatos_revisaveis.json').write_text(json.dumps(self.idx));(self.p/'00_CONTROLE_E_FONTES/ponteiro_produtivo.json').write_text(json.dumps(self.ptr));self.d=[{'manifestSha256':self.ptr['manifestSha256'],'catalogVersion':'SYNTHETIC_V1','identity':'synthetic','sourceVersion':'SYNTHETIC_V1','reviewer':{'name':'SYNTHETIC_REVIEWER','professionalRegistration':'TEST_ONLY','jurisdiction':'TEST_ONLY'},'decidedAt':'2026-10-14T00:00:00+00:00','decisions':[{'artifactId':self.aid,'locale':'pt','artifactSha256':h,'decision':'APPROVED','signatureEvidence':{'path':'signature.txt','sha256':sh}}]}];self.a=[{'artifactId':self.aid,'artifactSha256':h,'signatureEvidenceSha256':sh,'signatureReviewed':True,'decisionTranscriptionVerified':True,'reviewerName':'SYNTHETIC_REVIEWER','decision':'APPROVED','acceptedBy':'SYNTHETIC_ADMIN','acceptedAt':'2026-10-14','policyVersion':'SYNTHETIC_TEST','method':'TEST_ONLY','verificationLimitations':'Synthetic fixture only'}]
 def tearDown(self):self.tmp.cleanup()
 def runcheck(self):return v.validate(self.p,self.d,self.m,self.ptr,self.a,self.p)
 def test_valid_fixture_never_publishes(self):self.assertFalse(self.runcheck()['validatedDecisions'][0]['publicationReady'])
 def test_changed_artifact(self):
  (self.p/'artifact.txt').write_text('tampered')
  with self.assertRaisesRegex(ValueError,'ARTIFACT_HASH'):self.runcheck()
 def test_pending_not_approval(self):
  self.d[0]['decisions'][0]['decision']='PENDING'
  with self.assertRaisesRegex(ValueError,'NO_EFFECTIVE'):self.runcheck()
 def test_missing_signature_acceptance(self):
  self.a=[]
  with self.assertRaisesRegex(ValueError,'HUMAN_SIGNATURE'):self.runcheck()
 def test_changed_catalog(self):
  self.m={'synthetic':'changed'};self.ptr['manifestSha256']=v.canonical(self.m)
  with self.assertRaisesRegex(ValueError,'CONCURRENT'):self.runcheck()
 def test_wrong_language(self):
  self.d[0]['decisions'][0]['locale']='es'
  with self.assertRaisesRegex(ValueError,'IDENTITY_LOCALE'):self.runcheck()
 def test_missing_reviewer(self):
  self.d[0]['reviewer']['name']=''
  with self.assertRaisesRegex(ValueError,'REVIEWER'):self.runcheck()
 def test_path_traversal(self):
  self.d[0]['decisions'][0]['signatureEvidence']['path']='../outside'
  with self.assertRaisesRegex(ValueError,'PATH_OUTSIDE'):self.runcheck()
 def test_duplicate(self):
  self.d*=2
  with self.assertRaisesRegex(ValueError,'DUPLICATE'):self.runcheck()
 def test_signature_changed(self):
  (self.p/'signature.txt').write_text('changed')
  with self.assertRaisesRegex(ValueError,'SIGNED_EVIDENCE'):self.runcheck()
if __name__=='__main__':unittest.main()
