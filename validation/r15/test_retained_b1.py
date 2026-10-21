import unittest,tempfile,pathlib,json,hashlib
from verify_retained_b1 import verify
class Tests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.r=pathlib.Path(self.tmp.name);self.s=self.r/'validation/r15/retained-b1';self.s.mkdir(parents=True)
  (self.r/'Dockerfile').write_text('frozen');(self.r/'release-web-r15.tar.gz').write_bytes(b'fixture')
  b={k:'PASS' for k in ['B1_LINUX_IMAGE','B1_NGINX_STARTUP','B1_PORT_8080','B1_HTTP_HEALTH','B1_RESTART','negativeConfig']};b.update(outboundIsolation={'status':'PASS_REAL'},inputHashes={'release-web-r15.tar.gz':hashlib.sha256(b'fixture').hexdigest()})
  (self.s/'b1.json').write_text(json.dumps(b))
  for f in ['startup-docker-health.json','restart-docker-health.json']:(self.s/f).write_text(json.dumps({'Health':{'Status':'healthy'}}))
  self.m={'sourceHashes':{'Dockerfile':hashlib.sha256(b'frozen').hexdigest()},'receiptHashes':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in self.s.iterdir()}}
  (self.s/'provenance.json').write_text(json.dumps(self.m))
 def tearDown(self):self.tmp.cleanup()
 def test_valid_binding(self):verify(self.r)
 def test_source_changed_rejected(self):
  (self.r/'Dockerfile').write_text('changed')
  with self.assertRaisesRegex(RuntimeError,'SOURCE_CHANGED'):verify(self.r)
 def test_receipt_changed_rejected(self):
  (self.s/'b1.json').write_text('{}')
  with self.assertRaisesRegex(RuntimeError,'RECEIPT_CHANGED'):verify(self.r)
 def test_bundle_changed_rejected(self):
  (self.r/'release-web-r15.tar.gz').write_bytes(b'changed')
  with self.assertRaises(AssertionError):verify(self.r)
