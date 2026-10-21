#!/usr/bin/env python3
"""Exact-manifest operational binding of existing release operations; no clinical code."""
import os,sys,json,time,pathlib,hashlib,subprocess,urllib.request,urllib.error,importlib.util,fcntl,signal,datetime
W=pathlib.Path(__file__).resolve().parent; O=W.parent
P=pathlib.Path('/Users/brunorodrigues/Documents/Codex/MEDCASES-R15-COMMERCIAL-PATCH')
R=pathlib.Path('/Users/brunorodrigues/Developer/MedCases-Cleanup-20261020')
APP='c081f195-18aa-4e3e-b1f7-2a643b9a9f6b'; OLD='plantaoproxystream-00012-dak'; INITIAL='plantaoproxystream-00026-bum'
COMMIT=json.loads((O/'RELEASE-MANIFEST.json').read_text())['webCommit'] if (O/'RELEASE-MANIFEST.json').is_file() else 'NOT_BOUND'; BRANCH='codex/landing-prelogin-refinement-r1'; REMOTE='https://github.com/rodrigssousa-sudo/MedCases.git'
MANIFEST=(O/'RELEASE-MANIFEST.sha256').read_text().split()[0] if (O/'RELEASE-MANIFEST.sha256').is_file() else 'NOT_AUTHORIZABLE'; BASEWEB='41bdc80a-62cc-4241-aff3-5df8d81d4136'; RESTOREWEB='cdb527e2-1b68-4e5a-acca-8a1b677b363b'; GATEWAY='d703544e8e69dee9556902c2a25dacf5fa6ec586'
spec=importlib.util.spec_from_file_location('frozen',P/'release-r15-plantao-only/release.py'); f=importlib.util.module_from_spec(spec);spec.loader.exec_module(f)
sha=f.digest; canon=f.canonical; require=f.require
load=lambda n:json.loads((O/n).read_text())
def command(a,cwd=None,timeout=120):
 x=subprocess.run(a,cwd=cwd,capture_output=True,timeout=timeout);require(x.returncode==0,'COMMAND_FAILED_'+pathlib.Path(a[0]).name);return x.stdout.decode().strip()
def state():return json.loads((W/'state.json').read_text())if(W/'state.json').exists()else{}
def save(s):
 p=W/'state.tmp';p.write_text(json.dumps(s,indent=2));p.replace(W/'state.json')
def event(name,**kw):
 row={'atUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),'event':name,**kw}
 with(W/'events.jsonl').open('a')as h:h.write(json.dumps(row)+'\n')
 print(json.dumps(row),flush=True)
def runtime(x):
 d=f.config(x);d['service'].pop('allTrafficOnLatestRevision',None);return sha(canon(d))
def services(d):return {c['name']:c.get('source_commit_hash')for c in d.get('services',[])}
def traffic(x,rev):
 rows=x.get('trafficStatuses',[])
 return len(rows)==1 and rows[0].get('revision')==rev and rows[0].get('percent')==100 and not rows[0].get('tag')
class Bound(f.Release):
 def __init__(self):
  super().__init__(W/'backend-journal');self.old=OLD;self.dt=None
 def do(self,method,path,body=None):
  if self.dt is None:self.dt=command(['/opt/homebrew/bin/doctl','auth','token'])
  q=urllib.request.Request('https://api.digitalocean.com/v2'+path,data=json.dumps(body).encode()if body is not None else None,method=method,headers={'Authorization':'Bearer '+self.dt,'Content-Type':'application/json'})
  try:
   with urllib.request.urlopen(q,timeout=60)as r:
    body=r.read();return json.loads(body)if body.strip()else{}
  except urllib.error.HTTPError as e:raise RuntimeError('DO_HTTP_'+str(e.code))from None
 def current(self):return self.api(f.CF+f.NAME),self.api(f.RUN+self.service)
 def iam(self):return {kind:sha(canon(f.policy(self.api(url+':getIamPolicy'))))for kind,url in [('run',f.RUN+self.service),('function',f.CF+f.NAME)]}
 def pointers(self):return {n:sha(canon(self.doc('app_config/'+n)))for n in f.load('production-config-pointers.json')}
 def guard(self,reserve=600):
  s=state();require(s.get('started')and time.time()<s['deadline']-reserve,'INSUFFICIENT_WINDOW_RESERVE')
 def local(self):
  require(MANIFEST!='NOT_AUTHORIZABLE','FINAL_MANIFEST_REQUIRED')
  require(sha((O/'RELEASE-MANIFEST.json').read_bytes())==MANIFEST,'MANIFEST_DRIFT')
  linux=load('evidence/linux-image.json')
  require(linux.get('status')=='PASS' and linux.get('restart')=='PASS','REAL_LINUX_IMAGE_REQUIRED')
  require(linux.get('commit')==COMMIT,'LINUX_IMAGE_COMMIT_DRIFT')
  for n in ['.dockerignore','Dockerfile','nginx/nginx.conf','docker/40-generate-deploy-meta.sh','release-web-r15.tar.gz']:
   require(linux.get('inputHashes',{}).get(n)==sha((R/n).read_bytes()),'LINUX_IMAGE_INPUT_DRIFT')
  for n,h in load('RELEASE-MANIFEST.json')['files'].items():require(sha((O/n).read_bytes())==h,'ARTIFACT_DRIFT_'+n)
  for n,h in load('RELEASE-MANIFEST.json')['externalExecutorFiles'].items():require(sha(pathlib.Path(n).read_bytes())==h,'EXECUTOR_DEPENDENCY_DRIFT')
  require(command(['git','rev-parse','HEAD'],R)==COMMIT,'WEB_COMMIT_DRIFT');require(not command(['git','status','--porcelain'],R),'WEB_DIRTY')
 def pin_contract(self,app):
  plan=load('pin-plan.json');pin=(app.get('pinned_deployment')or{}).get('id')
  require(pin==plan['expectedPin'],'PIN_BASELINE_DRIFT')
  require(not app.get('in_progress_deployment'),'CONCURRENT_WEB_DEPLOYMENT')
  require(sha(canon(app['spec']))==plan['specSHA256'],'WEB_SPEC_DRIFT')
  web=next(c for c in app['spec']['services'] if c['name']=='medcases')
  require(web.get('http_port')==8080 and web.get('dockerfile_path')=='/Dockerfile' and web.get('source_dir')=='/','WEB_CONTAINER_CONTRACT')
  require(not web.get('run_command') and not web.get('build_command'),'WEB_COMMAND_OVERRIDE')
  health=web.get('health_check') or {}
  require(not health.get('http_path') or health['http_path']=='/health','WEB_HEALTH_PATH')
  gh=web.get('github',{})
  require(gh.get('repo')=='rodrigssousa-sudo/MedCases' and gh.get('branch')==BRANCH,'WEB_REPOSITORY_DRIFT')
  require(bool(gh.get('deploy_on_push'))==plan['autoDeploy'],'AUTO_DEPLOY_DRIFT')
  require(plan['strategy']=='COMMIT_ROLLBACK_THEN_EXPLICIT_DEPLOY','WEB_STRATEGY_MISSING')
  return pin
 def preflight(self):
  self.local();a,run=self.current();expected=load('function-control-plane.json')
  require(a['state']=='ACTIVE'and a['serviceConfig']['revision']==INITIAL and a['updateTime']==expected['updateTime'],'FUNCTION_DRIFT')
  require(sha(canon(f.config(a)))==expected['configSHA256'],'FUNCTION_CONFIG_DRIFT');require(sha(self.source(a))==load(INITIAL+'.json')['sourceSHA256'],'INITIAL_SOURCE_DRIFT')
  require(traffic(run,OLD),'TRAFFIC_BASELINE_DRIFT')
  rev=self.api(f.RUN+self.service+'/revisions/'+OLD);require(any(c.get('type')=='Ready'and c.get('state')=='CONDITION_SUCCEEDED'for c in rev.get('conditions',[])),'ROLLBACK_BACKEND_NOT_READY')
  app=self.do('GET','/apps/'+APP);self.pin_contract(app['app']);d=app['app']['active_deployment'];require(not app['app'].get('in_progress_deployment'),'CONCURRENT_WEB_DEPLOYMENT')
  require(d['id']==BASEWEB and d['phase']=='ACTIVE','WEB_BASELINE_DRIFT')
  prior=self.do('GET',f'/apps/{APP}/deployments/{RESTOREWEB}')['deployment'];require(prior['spec']==d['spec']and services(prior)==services(d)and prior['phase']in['ACTIVE','SUPERSEDED'],'ROLLBACK_WEB_DRIFT')
  require(services(d)=={'medcases':'48368c001df277cb8b3bd44f050b809545a840c8','ai-gateway':GATEWAY},'COMPONENT_DRIFT')
  require(command(['git','ls-remote',REMOTE,'refs/heads/'+BRANCH]).split()[0]==load('pin-plan.json')['remoteBranchBaseline'],'REMOTE_BRANCH_DRIFT')
  self.public(False)
  s={'stage':'PREFLIGHT_PASS','manifest':MANIFEST,'runtimeSHA256':runtime(a),'IAM':self.iam(),'pointers':self.pointers(),'webSpecSHA256':sha(canon(d['spec'])),'backendOperation':None,'webPushed':False,'webTouched':False,'initialPin':load('pin-plan.json')['expectedPin'],'backendMutated':False,'started':None,'deadline':None,'controllerSHA256':sha(pathlib.Path(__file__).read_bytes())};save(s);event('PREFLIGHT_PASS',backend=OLD,webDeployment=BASEWEB)
 def web_health(self):
  with urllib.request.urlopen('https://medcasespro.com/health',timeout=15)as r:
   require(r.status==200,'WEB_HEALTH_HTTP')
   require(json.load(r).get('status')=='ok','WEB_HEALTH_BODY')
 def public(self,new):
  expected=load('commercial-web-build-binding.json')['files']if new else {n:v['sha256']for n,v in load('web-served.json').items()if'sha256'in v}
  receipts={}
  for n in ['main.dart.js','flutter_bootstrap.js','pwa-sw.js','flutter_service_worker.js']:
   with urllib.request.urlopen('https://medcasespro.com/'+n,timeout=45)as r:b=r.read();require(r.status==200,'PUBLIC_HTTP')
   receipts[n]=sha(b);require(receipts[n]==expected[n],'PUBLIC_HASH_'+n)
  with urllib.request.urlopen('https://medcasespro.com/deploy_meta.json',timeout=30)as r:meta=json.load(r)
  require(meta.get('deployCommit')==(COMMIT if new else'48368c001df277cb8b3bd44f050b809545a840c8'),'PUBLIC_COMMIT')
  self.web_health()
  (W/('public-new.json'if new else'public-baseline.json')).write_text(json.dumps({'atUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),'hashes':receipts,'commit':meta['deployCommit']},indent=2))
 def start(self):
  require(os.environ.get('MEDCASES_AUTHORIZED_MANIFEST')==MANIFEST,'EXACT_MANIFEST_AUTHORIZATION_REQUIRED')
  require(state().get('stage')=='PREFLIGHT_PASS','PREFLIGHT_REQUIRED');self.preflight()
  s=state();s.update(started=time.time(),deadline=time.time()+3600,stage='WINDOW_OPEN');save(s)
  log=(W/'watchdog.log').open('ab');proc=subprocess.Popen([sys.executable,str(pathlib.Path(__file__).resolve()),'watchdog'],stdout=log,stderr=log,start_new_session=True);s['watchdogPid']=proc.pid;save(s)
  event('WINDOW_OPEN',deadlineUTC=datetime.datetime.fromtimestamp(s['deadline'],datetime.timezone.utc).isoformat(),watchdogPid=proc.pid)
 def deploy_backend(self):
  self.guard(2400);s=state();require(s['stage']=='WINDOW_OPEN','BACKEND_ALREADY_ATTEMPTED');s['stage']='BACKEND_UPLOAD';save(s)
  up=self.api(f.CF+'projects/medcases-pro/locations/us-central1/functions:generateUploadUrl','POST',{})
  # Existing diagnosed v2 upload fix: no v1 x-goog-content-length-range header.
  req=urllib.request.Request(up['uploadUrl'],data=(O/'backend-candidate-source.zip').read_bytes(),method='PUT',headers={'Content-Type':'application/zip'})
  try:
   with urllib.request.urlopen(req,timeout=120)as response:require(response.status in[200,201],'SOURCE_UPLOAD_FAILED')
  except urllib.error.HTTPError as e:raise RuntimeError('SOURCE_UPLOAD_HTTP_'+str(e.code))from None
  self.guard(2100);s=state();s['backendMutated']=True;s['stage']='BACKEND_BUILD';save(s)
  op=self.api(f.CF+f.NAME+'?updateMask=buildConfig.source','PATCH',{'name':f.NAME,'buildConfig':{'source':{'storageSource':up['storageSource']}}})
  s=state();s['backendOperation']=op['name'];save(s);event('BACKEND_BUILD_STARTED',operation=op['name'])
  while True:
   self.guard(1500);op=self.api(f.CF+s['backendOperation'])
   if op.get('done'):require('error'not in op,'BACKEND_BUILD_FAILED');break
   time.sleep(10)
  a,run=self.current();rev=a['serviceConfig']['revision'];require(rev not in[OLD,INITIAL]and a['state']=='ACTIVE','NEW_REVISION_MISSING')
  require(f.zipmap(self.source(a))==f.zipmap((O/'backend-candidate-source.zip').read_bytes()),'DEPLOYED_SOURCE_MISMATCH');require(runtime(a)==s['runtimeSHA256'],'RUNTIME_CONFIG_CHANGED');require(self.iam()==s['IAM'],'IAM_CHANGED');require(self.pointers()==s['pointers'],'CLINICAL_POINTER_CHANGED')
  rr=self.api(f.RUN+self.service+'/revisions/'+rev);require(any(c.get('type')=='Ready'and c.get('state')=='CONDITION_SUCCEEDED'for c in rr.get('conditions',[])),'NEW_REVISION_NOT_READY')
  s=state();s['newRevision']=rev;save(s)
  if not traffic(run,rev):
   require(traffic(run,OLD),'UNEXPECTED_TRAFFIC');command(['gcloud','run','services','update-traffic','plantaoproxystream','--project=medcases-pro','--region=us-central1','--to-revisions='+rev+'=100','--quiet'])
  require(traffic(self.current()[1],rev),'TRAFFIC_READBACK_FAILED');s=state();s['stage']='BACKEND_PASS';save(s);event('BACKEND_PASS',revision=rev,trafficPercent=100,sourceFiles=220)
 def deploy_web(self):
  self.guard(1500);s=state();require(s['stage']=='BACKEND_PASS','BACKEND_REQUIRED');self.local()
  app=self.do('GET','/apps/'+APP)['app'];self.pin_contract(app)
  require(command(['git','ls-remote',REMOTE,'refs/heads/'+BRANCH]).split()[0]==load('pin-plan.json')['remoteBranchBaseline'],'REMOTE_BRANCH_DRIFT')
  s['webPushed']=True;s['stage']='WEB_PUSH';save(s)
  command(['git','push',REMOTE,COMMIT+':refs/heads/'+BRANCH],R,180)
  require(command(['git','ls-remote',REMOTE,'refs/heads/'+BRANCH]).split()[0]==COMMIT,'PUSH_READBACK_FAILED')
  event('WEB_PUSHED',commit=COMMIT)
  self.prepare_web_deployment()
  while True:
   self.guard(900);app=self.do('GET','/apps/'+APP)['app'];d=app['active_deployment']
   if services(d).get('medcases')==COMMIT and d['phase']=='ACTIVE':break
   expected=state().get('webDeploymentId')
   if expected:
    candidate=self.do('GET',f'/apps/{APP}/deployments/{expected}')['deployment']
    require(candidate['phase']not in['ERROR','CANCELED','SUPERSEDED'],'WEB_BUILD_FAILED')
   time.sleep(10)
  require(services(d).get('ai-gateway')==GATEWAY and sha(canon(d['spec']))==s['webSpecSHA256'],'WEB_GATEWAY_CONFIG_CHANGED')
  require(not app.get('pinned_deployment'),'UNEXPECTED_PIN_AFTER_DEPLOY')
  self.public(True);require(traffic(self.current()[1],s['newRevision']),'BACKEND_TRAFFIC_CHANGED')
  s=state();s['stage']='PAIR_PASS_AWAITING_INDIVIDUAL_SMOKES';s['newWebDeployment']=d['id'];save(s);event('PAIR_PASS_AWAITING_INDIVIDUAL_SMOKES',revision=s['newRevision'],deployment=d['id'],commit=COMMIT)
 def prepare_web_deployment(self):
  self.guard(1200)
  require(os.environ.get('MEDCASES_AUTHORIZED_MANIFEST')==MANIFEST,'EXACT_MANIFEST_AUTHORIZATION_REQUIRED')
  require(command(['git','ls-remote',REMOTE,'refs/heads/'+BRANCH]).split()[0]==COMMIT,'REMOTE_BRANCH_DRIFT')
  require(command(['git','ls-remote',REMOTE,'refs/heads/codex/admin-control-phase2']).split()[0]==GATEWAY,'GATEWAY_REMOTE_DRIFT')
  app=self.do('GET','/apps/'+APP)['app'];pin=(app.get('pinned_deployment')or{}).get('id')
  require(pin==state()['initialPin'],'PIN_BASELINE_DRIFT')
  if pin:
   require(not app.get('in_progress_deployment'),'CONCURRENT_WEB_DEPLOYMENT')
   s=state();s['webTouched']=True;s['stage']='WEB_UNPIN';save(s)
   # Official endpoint: retain current rollback content and allow new deployments.
   # Do NOT use rollback/revert (which can restore a different pre-rollback spec).
   self.do('POST',f'/apps/{APP}/rollback/commit',{})
   app=self.do('GET','/apps/'+APP)['app']
   require(not app.get('pinned_deployment'),'UNPIN_READBACK_FAILED')
   require(app['active_deployment']['id']==BASEWEB,'UNPIN_CHANGED_ACTIVE_DEPLOYMENT')
  require(sha(canon(app['spec']))==state()['webSpecSHA256'],'WEB_SPEC_DRIFT')
  validation=self.do('POST',f'/apps/{APP}/rollback/validate',{'deployment_id':RESTOREWEB,'skip_pin':not bool(state()['initialPin'])})
  require(not validation.get('error'),'ROLLBACK_VALIDATION_FAILED')
  event('ROLLBACK_VALIDATION_PASS')
  # If an unpinned auto-deploy already started, adopt that exact deployment;
  # otherwise issue one official manual deployment. Never retry POST blindly.
  pending=app.get('in_progress_deployment');active=app['active_deployment']
  if services(active).get('medcases')==COMMIT and active['phase']=='ACTIVE':candidate=active
  elif pending:
   require(services(pending).get('medcases')in[None,COMMIT],'CONCURRENT_UNKNOWN_WEB_DEPLOYMENT');candidate=pending
  else:
   s=state();s['webTouched']=True;s['stage']='WEB_MANUAL_DEPLOY';save(s)
   candidate=self.do('POST',f'/apps/{APP}/deployments',{'force_build':False})['deployment']
  s=state();s['webTouched']=True;s['webDeploymentId']=candidate['id'];s['stage']='WEB_BUILD';save(s)
  for _ in range(24):
   if all(services(candidate).get(n)for n in ['medcases','ai-gateway']):break
   self.guard(900);require(candidate['phase']not in['ERROR','CANCELED','SUPERSEDED'],'WEB_BUILD_FAILED');time.sleep(5)
   candidate=self.do('GET',f'/apps/{APP}/deployments/{candidate["id"]}')['deployment']
  require(services(candidate).get('medcases')==COMMIT,'MANUAL_DEPLOY_COMMIT_MISMATCH')
  require(services(candidate).get('ai-gateway')==GATEWAY,'MANUAL_DEPLOY_GATEWAY_MISMATCH')
  require(sha(canon(candidate['spec']))==s['webSpecSHA256'],'MANUAL_DEPLOY_SPEC_MISMATCH')
  event('WEB_DEPLOYMENT_SELECTED',deployment=candidate['id'])
 def restore_web(self):
  s=state();app=self.do('GET','/apps/'+APP)['app'];active=app['active_deployment'];pending=app.get('in_progress_deployment')
  if s.get('webTouched') or s.get('webPushed'):
   if pending:
    require(pending['id']==s.get('webDeploymentId') or services(pending).get('medcases')==COMMIT,'UNKNOWN_PENDING_DEPLOYMENT')
    self.do('POST',f'/apps/{APP}/deployments/{pending["id"]}/cancel',{})
    for _ in range(30):
     app=self.do('GET','/apps/'+APP)['app']
     if not app.get('in_progress_deployment'):break
     time.sleep(5)
    else:raise RuntimeError('WEB_CANCEL_TIMEOUT')
    active=app['active_deployment']
   require(services(active).get('medcases')in[COMMIT,'48368c001df277cb8b3bd44f050b809545a840c8'],'UNKNOWN_WEB_DO_NOT_OVERWRITE')
   pin=(app.get('pinned_deployment')or{}).get('id')
   expected_pin=bool(s.get('initialPin'))
   already_restored=services(active)=={'medcases':'48368c001df277cb8b3bd44f050b809545a840c8','ai-gateway':GATEWAY} and sha(canon(active['spec']))==s['webSpecSHA256'] and bool(pin)==expected_pin and (not pin or pin==active['id'])
   if not already_restored:
    prior=self.do('GET',f'/apps/{APP}/deployments/{RESTOREWEB}')['deployment'];require(sha(canon(prior['spec']))==s['webSpecSHA256'],'ROLLBACK_SPEC_DRIFT')
    d=self.do('POST',f'/apps/{APP}/rollback',{'deployment_id':RESTOREWEB,'skip_pin':not expected_pin})['deployment']
    for _ in range(45):
     d=self.do('GET',f'/apps/{APP}/deployments/{d["id"]}')['deployment']
     if d['phase']=='ACTIVE':break
     require(d['phase']not in['ERROR','CANCELED','SUPERSEDED'],'WEB_ROLLBACK_FAILED');time.sleep(5)
    else:raise RuntimeError('WEB_ROLLBACK_TIMEOUT')
   app=self.do('GET','/apps/'+APP)['app'];active=app['active_deployment'];pin=(app.get('pinned_deployment')or{}).get('id')
   require(services(active)=={'medcases':'48368c001df277cb8b3bd44f050b809545a840c8','ai-gateway':GATEWAY},'WEB_ROLLBACK_SOURCE_FAILED')
   require(sha(canon(active['spec']))==s['webSpecSHA256'],'WEB_ROLLBACK_SPEC_FAILED')
   require(bool(pin)==expected_pin and (not pin or pin==active['id']),'WEB_ROLLBACK_PIN_FAILED')
   require(not app.get('in_progress_deployment'),'WEB_ROLLBACK_PENDING')
  self.public(False)
 def rollback(self):
  s=state();event('ROLLBACK_BEGIN');errors=[]
  # Settle pending build before final traffic readback; never a second deploy.
  if s.get('backendOperation'):
   for _ in range(30):
    op=self.api(f.CF+s['backendOperation'])
    if op.get('done'):break
    time.sleep(5)
   else:errors.append('BACKEND_OPERATION_STILL_PENDING')
  try:
   self.restore_web()
  except Exception as e:errors.append('WEB_'+type(e).__name__+(':'+str(e)if isinstance(e,RuntimeError)else''))
  try:
   if s.get('backendMutated'):command(['gcloud','run','services','update-traffic','plantaoproxystream','--project=medcases-pro','--region=us-central1','--to-revisions='+OLD+'=100','--quiet'])
   require(traffic(self.current()[1],OLD),'BACKEND_ROLLBACK_TRAFFIC');require(self.iam()==s['IAM'],'IAM_CHANGED');require(self.pointers()==s['pointers'],'POINTERS_CHANGED')
  except Exception as e:errors.append('BACKEND_'+type(e).__name__+(':'+str(e)if isinstance(e,RuntimeError)else''))
  s=state();s['stage']='ROLLBACK_FAILED'if errors else'ROLLED_BACK';s['rollbackErrors']=errors;s['closedUTC']=datetime.datetime.now(datetime.timezone.utc).isoformat();save(s);event(s['stage'],errors=errors)
 def final_readback(self):
  s=state();require(s['stage']=='PAIR_PASS_AWAITING_INDIVIDUAL_SMOKES','PAIR_NOT_READY');self.public(True);a,run=self.current();require(traffic(run,s['newRevision']),'TRAFFIC_DRIFT');require(runtime(a)==s['runtimeSHA256']and self.iam()==s['IAM']and self.pointers()==s['pointers'],'PRESERVATION_DRIFT');event('FINAL_READBACK_PASS')

 def complete(self):
  self.guard(600)
  require(os.environ.get('MEDCASES_AUTHORIZED_MANIFEST')==MANIFEST,'EXACT_MANIFEST_AUTHORIZATION_REQUIRED')
  receipt=json.loads((W/'smoke-acceptance.json').read_text());s=state()
  require(receipt.get('manifest')==MANIFEST and receipt.get('revision')==s.get('newRevision') and receipt.get('deployment')==s.get('newWebDeployment'),'SMOKE_RECEIPT_SCOPE')
  require(receipt.get('operatorAccepted')is True,'OPERATOR_ACCEPTANCE_REQUIRED')
  items=receipt.get('smokes',[])
  require(len(items)==4 and {i.get('id')for i in items}=={'FREE_PARACETAMOL','PREMIUM_TOXICOLOGY','PREMIUM_NORADRENALINE','HISTORY_COPY_AUDIO'},'SMOKE_SET_INCOMPLETE')
  for item in items:
   require(item.get('status')=='PASS' and item.get('individuallyAuthorized')is True,'SMOKE_NOT_ACCEPTED')
   evidence=(W/item.get('evidence','')).resolve();require(evidence.is_relative_to(W.resolve()) and evidence.is_file(),'SMOKE_EVIDENCE_REQUIRED')
   require(sha(evidence.read_bytes())==item.get('sha256'),'SMOKE_EVIDENCE_DRIFT')
  self.final_readback();s=state();s.update(stage='COMMITTED',closedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),acceptanceSHA256=sha((W/'smoke-acceptance.json').read_bytes()));save(s);event('COMMITTED')

def main():
 action=sys.argv[1];x=Bound()
 if action=='watchdog':
  while True:
   s=state()
   if s.get('stage')in['COMMITTED','ROLLED_BACK','ROLLBACK_FAILED','SAFE_STOP_NO_MUTATION']:return
   if time.time()>=s['deadline']-600:break
   time.sleep(10)
  action='rollback'
 with(W/'transaction.lock').open('a')as lock:
  fcntl.flock(lock,fcntl.LOCK_EX)
  try:
   if action=='preflight':require(not state().get('started'),'TRANSACTION_ALREADY_STARTED');x.preflight()
   elif action=='publish':x.start();x.deploy_backend();x.deploy_web()
   elif action=='rollback':x.rollback()
   elif action=='readback':x.final_readback()
   elif action=='complete':x.complete()
   elif action=='status':print(json.dumps(state(),indent=2))
   else:raise RuntimeError('UNKNOWN_ACTION')
  except BaseException as e:
   event('ACTION_FAILED',action=action,errorClass=type(e).__name__,code=str(e)if isinstance(e,RuntimeError)else'WITHHELD')
   if action in['publish','readback','complete']and state().get('started'):
    try:x.rollback()
    except BaseException:event('ROLLBACK_UNCONFIRMED')
   raise SystemExit(1)
if __name__=='__main__':main()
