#!/usr/bin/env python3
"""Local-only real Linux container gate. Never pushes, publishes, or queries AI."""
import argparse, hashlib, json, pathlib, shutil, subprocess, tempfile, time, urllib.request, uuid
p=argparse.ArgumentParser();p.add_argument('--output',required=True);a=p.parse_args()
R=pathlib.Path(__file__).resolve().parents[2];out=pathlib.Path(a.output).resolve();out.mkdir(parents=True,exist_ok=True)
receipt={'scope':'real Linux image only','productionMutations':0,'status':'BLOCKED'}
def save(): (out/'linux-image.json').write_text(json.dumps(receipt,indent=2))
def run(args,**kw): return subprocess.check_output(args,stderr=subprocess.STDOUT,timeout=kw.pop('timeout',120),**kw).decode()
if not shutil.which('docker'):
 receipt['reason']='NO_LOCAL_DOCKER_RUNTIME';save();raise SystemExit(2)
try:
 info=json.loads(run(['docker','info','--format','{{json .}}']));assert info['OSType']=='linux'
except Exception:
 receipt['reason']='NO_AVAILABLE_LINUX_DOCKER_ENGINE';save();raise SystemExit(2)
name='medcases-readiness-'+uuid.uuid4().hex[:10];container=None;image_built=False
try:
 binding=json.loads((R/'maintenance/desktop-premium-final/evidence/pin-aware-build-binding.json').read_text())
 h=lambda b:hashlib.sha256(b).hexdigest()
 assert h((R/'release-web-r15.tar.gz').read_bytes())==binding['artifactSHA256']
 commit=run(['git','-C',str(R),'rev-parse','HEAD']).strip()
 inputs=['.dockerignore','Dockerfile','nginx/nginx.conf','docker/40-generate-deploy-meta.sh','release-web-r15.tar.gz']
 receipt['inputHashes']={n:h((R/n).read_bytes()) for n in inputs};receipt['commit']=commit
 with tempfile.TemporaryDirectory(prefix='r15-image-context-') as tmp:
  for n in inputs:
   dest=pathlib.Path(tmp)/n;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(R/n,dest)
  (out/'docker-build.txt').write_text(run(['docker','build','--platform=linux/amd64','--progress=plain','-t',name,tmp],timeout=900))
 image_built=True
 receipt['imageId']=run(['docker','image','inspect',name,'--format','{{.Id}}']).strip()
 (out/'nginx-test.txt').write_text(run(['docker','run','--rm','--network=none',name,'nginx','-t']))
 container=run(['docker','run','-d','--name',name,'-p','127.0.0.1::8080','-e','DEPLOY_COMMIT='+commit,'-e','BUNDLE_VERSION=R15-readiness',name]).strip()
 port=run(['docker','port',container,'8080/tcp']).strip().split(':')[-1];url='http://127.0.0.1:'+port
 def verify(phase):
  for _ in range(60):
   try:
    with urllib.request.urlopen(url+'/health',timeout=2)as r: assert r.status==200
    break
   except Exception: time.sleep(1)
  else: raise RuntimeError('HTTP_HEALTH_TIMEOUT')
  records=[]
  for n in ['', 'health','deploy_meta.json','main.dart.js','flutter_bootstrap.js','pwa-sw.js','flutter_service_worker.js']:
   with urllib.request.urlopen(url+'/'+n,timeout=15)as r: data=r.read();assert r.status==200;cache=r.headers.get('Cache-Control')
   if n in binding['files']:assert h(data)==binding['files'][n]
   if n=='deploy_meta.json':assert json.loads(data)['deployCommit']==commit
   records.append({'path':n,'http':200,'sha256':h(data),'cacheControl':cache})
  receipt[phase]=records
  for _ in range(90):
   s=json.loads(run(['docker','inspect',container]))[0]['State'];assert s['Running']
   if s.get('Health',{}).get('Status')=='healthy':break
   time.sleep(1)
  else: raise RuntimeError('CONTAINER_NOT_HEALTHY')
 verify('startup');run(['docker','restart',container]);verify('restart')
 (out/'entrypoint.txt').write_text(run(['docker','logs',container]))
 receipt.update(status='PASS',nginxTest='PASS',port8080='PASS',restart='PASS')
except Exception as e:
 receipt.update(status='FAIL',errorClass=type(e).__name__)
 if isinstance(e,subprocess.CalledProcessError): (out/'command-failure.txt').write_bytes(e.output)
 raise
finally:
 if container:run(['docker','rm','-f',container])
 if image_built:run(['docker','image','rm',name])
 save()
