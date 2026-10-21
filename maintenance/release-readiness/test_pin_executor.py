import unittest,importlib.util,copy,os,json,io,tempfile
from unittest.mock import patch
from pathlib import Path
O=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('tx',O/'execution/transaction.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class PinTests(unittest.TestCase):
 def setUp(self):
  self.spec={'services':[{'name':'medcases','http_port':8080,'dockerfile_path':'/Dockerfile','source_dir':'/','github':{'repo':'rodrigssousa-sudo/MedCases','branch':m.BRANCH,'deploy_on_push':True}}]}
  self.old={'id':m.BASEWEB,'phase':'ACTIVE','spec':self.spec,'services':[{'name':'medcases','source_commit_hash':'48368c001df277cb8b3bd44f050b809545a840c8'},{'name':'ai-gateway','source_commit_hash':m.GATEWAY}]}
  self.app={'spec':self.spec,'active_deployment':self.old,'pinned_deployment':{'id':m.BASEWEB}}
  self.plan={'expectedPin':m.BASEWEB,'autoDeploy':True,'specSHA256':m.sha(m.canon(self.spec)),'strategy':'COMMIT_ROLLBACK_THEN_EXPLICIT_DEPLOY','remoteBranchBaseline':'oldhead'}
  self.s={'stage':'BACKEND_PASS','initialPin':m.BASEWEB,'webSpecSHA256':self.plan['specSHA256'],'newRevision':'new-backend','webPushed':False,'webTouched':False}
  self.remote=m.COMMIT;self.calls=[];self.build_fail=False;self.candidate=None
  self.x=m.Bound.__new__(m.Bound);self.x.do=self.do;self.x.guard=lambda *a:None;self.x.local=lambda:None;self.x.public=lambda *a:None;self.x.current=lambda:({}, {'trafficStatuses':[{'revision':'new-backend','percent':100}]})
  self.patches=[patch.object(m,'state',lambda:copy.deepcopy(self.s)),patch.object(m,'save',lambda s:self.s.update(copy.deepcopy(s))),patch.object(m,'load',lambda n:self.plan),patch.object(m,'command',self.command),patch.object(m,'event',lambda *a,**k:None),patch.dict(os.environ,{'MEDCASES_AUTHORIZED_MANIFEST':m.MANIFEST})]
  for p in self.patches:p.start()
  self.addCleanup(lambda:[p.stop() for p in reversed(self.patches)])
 def command(self,args,*a):
  if args[1]=='push':self.remote=m.COMMIT;return ''
  return (m.GATEWAY if 'admin-control-phase2' in args[-1] else self.remote)+' refs/heads/test'
 def do(self,method,path,body=None):
  self.calls.append((method,path,body))
  if method=='GET' and path=='/apps/'+m.APP:return {'app':copy.deepcopy(self.app)}
  if path.endswith('/rollback/validate'):return {}
  if path.endswith('/rollback/commit'):self.app.pop('pinned_deployment',None);return None
  if method=='POST' and path.endswith('/deployments'):
   assert not self.app.get('pinned_deployment')
   self.candidate=copy.deepcopy(self.old);self.candidate.update(id='candidate',phase='ERROR' if self.build_fail else 'ACTIVE');self.candidate['services'][0]['source_commit_hash']=m.COMMIT
   if not self.build_fail:self.app['active_deployment']=self.candidate
   return {'deployment':copy.deepcopy(self.candidate)}
  if path.endswith('/rollback'):
   d=copy.deepcopy(self.old);d['id']='restored';self.app['active_deployment']=d
   if not body['skip_pin']:self.app['pinned_deployment']={'id':'restored'}
   else:self.app.pop('pinned_deployment',None)
   return {'deployment':copy.deepcopy(d)}
  if method=='GET' and '/deployments/' in path:
   if path.endswith(m.RESTOREWEB):return {'deployment':copy.deepcopy(self.old)}
   if path.endswith('candidate'):return {'deployment':copy.deepcopy(self.candidate)}
   return {'deployment':copy.deepcopy(self.app['active_deployment'])}
  raise AssertionError((method,path))
 def test_pin_preflight(self):self.assertEqual(self.x.pin_contract(self.app),m.BASEWEB);self.assertFalse(self.calls)
 def test_no_pin_preflight(self):self.app.pop('pinned_deployment');self.plan['expectedPin']=None;self.assertIsNone(self.x.pin_contract(self.app))
 def test_auto_disabled_manual(self):
  self.spec['services'][0]['github']['deploy_on_push']=False;self.plan['autoDeploy']=False;self.plan['specSHA256']=m.sha(m.canon(self.spec));self.s['webSpecSHA256']=self.plan['specSHA256'];self.x.pin_contract(self.app);self.x.prepare_web_deployment();self.assertEqual(self.s['webDeploymentId'],'candidate')
 def test_push_no_deployment_manual(self):self.x.prepare_web_deployment();self.assertEqual(sum(c[0]=='POST' and c[1].endswith('/deployments') for c in self.calls),1)
 def test_unpin_before_manual(self):
  self.x.prepare_web_deployment();posts=[p for verb,p,b in self.calls if verb=='POST'];self.assertEqual(posts,[f'/apps/{m.APP}/rollback/commit',f'/apps/{m.APP}/rollback/validate',f'/apps/{m.APP}/deployments'])
 def test_active_expected_commit(self):self.remote='oldhead';self.x.deploy_web();self.assertEqual(self.s['stage'],'PAIR_PASS_AWAITING_INDIVIDUAL_SMOKES')
 def test_wrong_remote(self):
  self.remote='wrong';
  with self.assertRaisesRegex(RuntimeError,'REMOTE_BRANCH_DRIFT'):self.x.prepare_web_deployment()
  self.assertFalse(any(c[0]=='POST' for c in self.calls))
 def test_no_authorization(self):
  with patch.dict(os.environ,{'MEDCASES_AUTHORIZED_MANIFEST':''}):
   with self.assertRaisesRegex(RuntimeError,'AUTHORIZATION_REQUIRED'):self.x.prepare_web_deployment()
  self.assertFalse(self.calls)
 def test_web_failure(self):
  self.remote='oldhead';self.build_fail=True
  with self.assertRaisesRegex(RuntimeError,'WEB_BUILD_FAILED'):self.x.deploy_web()
 def test_restore_pin_after_unpin_only(self):
  self.app.pop('pinned_deployment');self.s['webTouched']=True;self.x.restore_web();self.assertEqual(self.app['pinned_deployment']['id'],self.app['active_deployment']['id']);self.assertEqual(m.services(self.app['active_deployment'])['medcases'],'48368c001df277cb8b3bd44f050b809545a840c8')
 def test_restore_after_deploy(self):self.x.prepare_web_deployment();self.x.restore_web();self.assertEqual(self.app['active_deployment']['id'],'restored')
 def test_restore_original_unpinned(self):
  self.app.pop('pinned_deployment');self.s['initialPin']=None;self.x.prepare_web_deployment();self.x.restore_web();self.assertFalse(self.app.get('pinned_deployment'))
 def test_wrong_public_hash(self):
  class Response(io.BytesIO):status=200
  with patch.object(m,'load',lambda n:{'files':{'main.dart.js':'wrong'}}),patch.object(m.urllib.request,'urlopen',lambda *a,**k:Response(b'actual')):
   with self.assertRaisesRegex(RuntimeError,'PUBLIC_HASH_main.dart.js'):m.Bound.public(self.x,True)
 def test_pin_drift(self):
  self.app['pinned_deployment']['id']='foreign'
  with self.assertRaisesRegex(RuntimeError,'PIN_BASELINE_DRIFT'):self.x.pin_contract(self.app)
 def test_empty_official_response(self):
  x=m.Bound.__new__(m.Bound);x.dt='test-only'
  with patch.object(m.urllib.request,'urlopen',lambda *a,**k:io.BytesIO(b'')):
   self.assertEqual(x.do('POST','/test',{}),{})
 def test_rollback_validation_failure_stops_deploy(self):
  base=self.do
  def response(method,path,body=None):
   if path.endswith('/rollback/validate'):return {'error':{'code':'unavailable'}}
   return base(method,path,body)
  self.x.do=response
  with self.assertRaisesRegex(RuntimeError,'ROLLBACK_VALIDATION_FAILED'):self.x.prepare_web_deployment()
  self.assertFalse(any(c[0]=='POST'and c[1].endswith('/deployments')for c in self.calls))
 def test_source_commit_pending_resolution(self):
  base=self.do
  def response(method,path,body=None):
   result=base(method,path,body)
   if method=='POST'and path.endswith('/deployments'):result['deployment']['services']=[]
   return result
  self.x.do=response
  with patch.object(m.time,'sleep',lambda _:None):self.x.prepare_web_deployment()
  self.assertEqual(sum(c[0]=='POST'and c[1].endswith('/deployments')for c in self.calls),1)
 def test_complete_requires_real_acceptance(self):
  with tempfile.TemporaryDirectory()as tmp,patch.object(m,'W',Path(tmp)):
   (Path(tmp)/'smoke-acceptance.json').write_text(json.dumps({'manifest':m.MANIFEST,'revision':'new-backend','deployment':None,'operatorAccepted':False}))
   with self.assertRaisesRegex(RuntimeError,'OPERATOR_ACCEPTANCE_REQUIRED'):self.x.complete()
   self.assertNotEqual(self.s['stage'],'COMMITTED')
 def test_complete_verified_receipts(self):
  with tempfile.TemporaryDirectory()as tmp,patch.object(m,'W',Path(tmp)):
   root=Path(tmp);(root/'evidence.json').write_text('synthetic executor unit-test only')
   receipt={'manifest':m.MANIFEST,'revision':'new-backend','deployment':None,'operatorAccepted':True,'smokes':[{'id':n,'status':'PASS','individuallyAuthorized':True,'evidence':'evidence.json','sha256':m.sha((root/'evidence.json').read_bytes())}for n in ['FREE_PARACETAMOL','PREMIUM_TOXICOLOGY','PREMIUM_NORADRENALINE','HISTORY_COPY_AUDIO']]}
   (root/'smoke-acceptance.json').write_text(json.dumps(receipt));self.x.final_readback=lambda:None;self.x.complete();self.assertEqual(self.s['stage'],'COMMITTED')
 def test_route_mismatch_rejected(self):
  source=(m.R/'lib/services/provider_router_service.dart').read_text()
  contract="endpointUrl: mode == 'plantao' ? GptSseClient.kPlantaoEndpoint : _gptSseUrl"
  self.assertIn(contract,source)
  self.assertNotIn(contract,source.replace(contract,"endpointUrl: _gptSseUrl"))

 def test_container_port_fail_closed(self):
  self.spec['services'][0]['http_port']=80;self.plan['specSHA256']=m.sha(m.canon(self.spec))
  with self.assertRaisesRegex(RuntimeError,'WEB_CONTAINER_CONTRACT'):self.x.pin_contract(self.app)
 def test_runtime_override_fail_closed(self):
  self.spec['services'][0]['run_command']='sleep 999';self.plan['specSHA256']=m.sha(m.canon(self.spec))
  with self.assertRaisesRegex(RuntimeError,'WEB_COMMAND_OVERRIDE'):self.x.pin_contract(self.app)
 def test_missing_linux_receipt_blocks_local(self):
  with patch.object(m,'MANIFEST','NOT_AUTHORIZABLE'):
   with self.assertRaisesRegex(RuntimeError,'FINAL_MANIFEST_REQUIRED'):m.Bound.local(self.x)
 def test_unpin_error_never_deploys(self):
  original=self.x.do
  def fail(method,path,body=None):
   if path.endswith('/rollback/commit'):raise RuntimeError('UNPIN_ERROR')
   return original(method,path,body)
  self.x.do=fail
  with self.assertRaisesRegex(RuntimeError,'UNPIN_ERROR'):self.x.prepare_web_deployment()
  self.assertFalse(any(c[0]=='POST'and c[1].endswith('/deployments')for c in self.calls))
 def test_manual_timeout_not_retried(self):
  original=self.x.do;attempts=[]
  def fail(method,path,body=None):
   if method=='POST'and path.endswith('/deployments'):attempts.append(path);raise TimeoutError()
   return original(method,path,body)
  self.x.do=fail
  with self.assertRaises(TimeoutError):self.x.prepare_web_deployment()
  self.assertEqual(len(attempts),1)
 def test_startup_health_failure_never_second_deployment(self):
  self.remote='oldhead';self.build_fail=True
  with self.assertRaisesRegex(RuntimeError,'WEB_BUILD_FAILED'):self.x.deploy_web()
  self.x.restore_web()
  self.assertEqual(sum(c[0]=='POST'and c[1].endswith('/deployments')for c in self.calls),1)
 def test_stale_cache_cannot_commit(self):
  self.remote='oldhead'
  self.x.public=lambda *a: (_ for _ in ()).throw(RuntimeError('PUBLIC_HASH_main.dart.js'))
  with self.assertRaisesRegex(RuntimeError,'PUBLIC_HASH'):self.x.deploy_web()
  self.assertNotEqual(self.s['stage'],'PAIR_PASS_AWAITING_INDIVIDUAL_SMOKES')
 def test_rollback_partial_still_restores_backend(self):
  self.s.update(backendMutated=True,IAM={},pointers={});commands=[]
  self.x.restore_web=lambda: (_ for _ in ()).throw(RuntimeError('WEB_UNAVAILABLE'))
  self.x.iam=lambda:{};self.x.pointers=lambda:{}
  self.x.current=lambda:({}, {'trafficStatuses':[{'revision':m.OLD,'percent':100}]})
  with patch.object(m,'command',lambda args,*a:commands.append(args)):
   self.x.rollback()
  self.assertEqual(self.s['stage'],'ROLLBACK_FAILED');self.assertTrue(any('update-traffic'in c for c in commands))
 def test_timeout_reserve(self):
  self.s.update(started=1,deadline=100)
  with patch.object(m.time,'time',lambda:101):
   with self.assertRaisesRegex(RuntimeError,'INSUFFICIENT_WINDOW'):m.Bound.guard(self.x)
 def test_interruption_runs_rollback_without_retry(self):
  for failure in [KeyboardInterrupt(),RuntimeError('BACKEND_FAILURE')]:
   calls=[]
   class Fake:
    def start(x):self.s['started']=1
    def deploy_backend(x):calls.append('backend');raise failure
    def deploy_web(x):calls.append('web')
    def rollback(x):calls.append('rollback')
   with tempfile.TemporaryDirectory() as tmp,patch.object(m,'W',Path(tmp)),patch.object(m,'Bound',Fake),patch.object(m.sys,'argv',['tx','publish']):
    with self.assertRaises(SystemExit):m.main()
   self.assertEqual(calls,['backend','rollback'])

 def test_health_bad_body_rejected(self):
  class Response(io.BytesIO):status=200
  with patch.object(m.urllib.request,'urlopen',lambda *a,**k:Response(b'{"status":"error"}')):
   with self.assertRaisesRegex(RuntimeError,'WEB_HEALTH_BODY'):m.Bound.web_health(self.x)
 def test_health_real_response_contract(self):
  class Response(io.BytesIO):status=200
  with patch.object(m.urllib.request,'urlopen',lambda *a,**k:Response(b'{"status":"ok"}')):m.Bound.web_health(self.x)
 def test_watchdog_deadline_triggers_rollback_only(self):
  self.s.update(started=1,deadline=100);calls=[]
  class Fake:
   def rollback(x):calls.append('rollback')
  with tempfile.TemporaryDirectory()as tmp,patch.object(m,'W',Path(tmp)),patch.object(m,'Bound',Fake),patch.object(m.sys,'argv',['tx','watchdog']),patch.object(m.time,'time',lambda:100):m.main()
  self.assertEqual(calls,['rollback'])
if __name__=='__main__':unittest.main(verbosity=2)
