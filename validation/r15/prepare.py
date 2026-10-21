import pathlib,json,hashlib,tarfile,urllib.request,concurrent.futures
R=pathlib.Path.cwd(); W=R/'validation-data';W.mkdir(exist_ok=True)
h=lambda b:hashlib.sha256(b).hexdigest()
b=json.loads((R/'maintenance/desktop-premium-final/evidence/pin-aware-build-binding.json').read_text())
assert h((R/'release-web-r15.tar.gz').read_bytes())==b['artifactSHA256']
with tarfile.open(R/'release-web-r15.tar.gz') as t:t.extractall(W/'new',filter='data')
old={'main.dart.js':'2f7e9e3dc94c60f74d0658584c190af3edee0d7d367a28278d53a84f24f4c2b4','flutter_bootstrap.js':'e9f18e532a836188056c52be4cbbbf5b0530e71a975e265993ef23cb47f8b134','pwa-sw.js':'5a793fdb1c88e083201c7d894f228e8c64854d635d2fd21ceaec85819977c24a','flutter_service_worker.js':'64a6f6e096933097ed790e4e3c163dcc56d6fac5d49350396fb6f03206e13e11'}
# Fixed public static paths only. No cookies, login, APIs or clinical requests.
paths=set(b['files'])|{'index.html','deploy_meta.json'}
def get(p):
 assert '..' not in p and not p.startswith('/') and not p.startswith('api/')
 try:
  data=urllib.request.urlopen('https://medcasespro.com/'+urllib.parse.quote(p),timeout=60).read()
 except urllib.error.HTTPError as e:
  if p in old or p in ['index.html','deploy_meta.json']:raise
  return p,None
 if p in old:assert h(data)==old[p], 'OLD_BASELINE_CHANGED:'+p
 if p=='deploy_meta.json':assert json.loads(data)['deployCommit']=='48368c001df277cb8b3bd44f050b809545a840c8'
 f=W/'old'/p;f.parent.mkdir(parents=True,exist_ok=True);f.write_bytes(data)
 return p,h(data)
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:observed=dict(pool.map(get,sorted(paths)))
(W/'old-readback.json').write_text(json.dumps(observed,indent=2))
for version in ['10.12.0','11.9.1','10.14.1']:
 for module in ['app','auth','firestore','storage','functions','analytics','messaging','app-check','app-compat','auth-compat','firestore-compat']:
  p=f'firebasejs/{version}/firebase-{module}.js'
  data=urllib.request.urlopen('https://www.gstatic.com/'+p,timeout=40).read()
  f=W/'vendor'/p;f.parent.mkdir(parents=True,exist_ok=True);f.write_bytes(data)
(W/'binding.json').write_text(json.dumps({'base':'6d0ac951fe5368d2b5a116e5c8fc18c850bc75f9','bundle':b,'old':old},indent=2))
print('PUBLIC_STATIC_SNAPSHOT=VERIFIED')
