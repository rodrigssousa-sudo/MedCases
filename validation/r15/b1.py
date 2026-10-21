import pathlib,subprocess,json,time,hashlib,urllib.request,shutil
from health_probe import wait_health, collect_runtime
from network_guard import setup, verify as verify_network, require_mapping
from isolation_probe import prove_isolation
R=pathlib.Path.cwd();O=R/'receipts';O.mkdir(exist_ok=True)
result={k:'FAIL' for k in ['B1_LINUX_IMAGE','B1_NGINX_STARTUP','B1_PORT_8080','B1_HTTP_HEALTH','B1_RESTART']}
result.update(testedCommit='6d0ac951fe5368d2b5a116e5c8fc18c850bc75f9',productionMutations=0)
def cmd(args):return subprocess.check_output(args,stderr=subprocess.STDOUT,timeout=900).decode()
def save(): (O/'b1.json').write_text(json.dumps(result,indent=2))
try:
 assert json.loads(cmd(['docker','info','--format','{{json .}}']))['OSType']=='linux'
 (O/'build.log').write_text(cmd(['docker','build','--platform=linux/amd64','--network=none','--progress=plain','-t','r15-validation', '.']))
 (O/'docker-version.json').write_text(cmd(['docker','version','--format','{{json .}}']))
 i=json.loads(cmd(['docker','inspect','r15-validation']))[0];assert i['Architecture']=='amd64' and i['Os']=='linux'
 result['imageId']=i['Id'];result['B1_LINUX_IMAGE']='PASS'
 (O/'nginx-syntax-test.log').write_text(cmd(['docker','run','--rm','--network=none','r15-validation','nginx','-t']))
 (O/'nginx-effective-config.log').write_text(cmd(['docker','run','--rm','--network=none','r15-validation','nginx','-T']))
 assert 'pid        /var/cache/nginx/nginx.pid;' in (O/'nginx-effective-config.log').read_text() or '/var/cache/nginx/nginx.pid;' in (O/'nginx-effective-config.log').read_text()
 result['networkPolicy']=setup()
 cmd(['docker','run','-d','--name','r15-web','--network','r15-validation','--dns','127.0.0.1','-p','127.0.0.1:18080:8080','-e','DEPLOY_COMMIT='+result['testedCommit'],'r15-validation'])
 runtime=json.loads(cmd(['docker','inspect','r15-web']))[0]
 (O/'effective-port-mapping.json').write_text(json.dumps(runtime['NetworkSettings']['Ports'],indent=2))
 require_mapping(runtime)
 verify_network()
 result['network']='BRIDGE_EGRESS_DENIED_BY_FIREWALL'
 result['outboundIsolation']=prove_isolation(O)
 b=json.loads((R/'validation-data/binding.json').read_text())
 def verify(label):
  require_mapping(json.loads(cmd(['docker','inspect','r15-web']))[0])
  verify_network()
  deadline=time.monotonic()+40
  wait_health(O/(label+'-http-attempts.json'))
  while True:
   state=json.loads(cmd(['docker','inspect','r15-web']))[0]['State']
   (O/(label+'-docker-health.json')).write_text(json.dumps(state,indent=2))
   if not state['Running']:raise RuntimeError('CONTAINER_EXITED')
   health=state.get('Health',{}).get('Status')
   if health=='healthy':break
   if health=='unhealthy' or time.monotonic()>=deadline:raise RuntimeError('DOCKER_HEALTH_NOT_HEALTHY:'+str(health))
   time.sleep(1)
  internal=cmd(['docker','exec','r15-web','wget','-qO-','http://127.0.0.1:8080/health'])
  assert json.loads(internal)['status']=='ok'
  result[label+'InternalHTTP']='PASS_REAL'
  records={}
  for p in ['main.dart.js','flutter_bootstrap.js','pwa-sw.js','flutter_service_worker.js','deploy_meta.json']:
   raw=urllib.request.urlopen('http://127.0.0.1:18080/'+p,timeout=30).read()
   if p=='deploy_meta.json':
    assert json.loads(raw)['deployCommit']==result['testedCommit']
    (O/(label+'-deploy-meta.json')).write_bytes(raw)
   else:assert hashlib.sha256(raw).hexdigest()==b['bundle']['files'][p]
   records[p]=hashlib.sha256(raw).hexdigest()
  result[label]=records
 verify('startup');result.update(B1_NGINX_STARTUP='PASS',B1_PORT_8080='PASS',B1_HTTP_HEALTH='PASS')
 cmd(['docker','restart','r15-web']);verify('restart');result['B1_RESTART']='PASS'
 logs=cmd(['docker','logs','r15-web'])
 (O/'entrypoint.log').write_text(logs)
 assert not any(level in logs for level in ['[emerg]','[alert]','[crit]','[error]']), 'NGINX_RUNTIME_ERROR'
 # Test bad/missing nginx config at image construction, without changing frozen inputs.
 temp=R/'negative-context';temp.mkdir(exist_ok=True)
 for p in ['.dockerignore','Dockerfile','nginx/nginx.conf','docker/40-generate-deploy-meta.sh','release-web-r15.tar.gz']:
  dest=temp/p;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(R/p,dest)
 for case in ['invalid','missing']:
  f=temp/'nginx/nginx.conf'
  if case=='invalid':f.write_text('this_is_not_valid_nginx;\n')
  else:f.unlink()
  run=subprocess.run(['docker','build','--network=none',str(temp)],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180)
  (O/('negative-'+case+'.log')).write_bytes(run.stdout)
  assert run.returncode!=0, 'INVALID_CONFIG_ACCEPTED'
 result['negativeConfig']='PASS'
 result['inputHashes']={p:hashlib.sha256((R/p).read_bytes()).hexdigest() for p in ['Dockerfile','.dockerignore','nginx/nginx.conf','docker/40-generate-deploy-meta.sh','release-web-r15.tar.gz']}
except Exception as e:
 result['errorClass']=type(e).__name__
 result['failureReason']=str(e) if isinstance(e,RuntimeError) else type(e).__name__
 if isinstance(e,subprocess.CalledProcessError):(O/'b1-failure.log').write_bytes(e.output)
 raise
finally:
 try:collect_runtime(O)
 except Exception as diagnostic_error:result['diagnosticCollectionError']=type(diagnostic_error).__name__
 save()
