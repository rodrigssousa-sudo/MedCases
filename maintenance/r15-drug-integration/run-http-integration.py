from pathlib import Path
import os,subprocess,socket,time,urllib.request,json,sys
root=Path(__file__).resolve().parent
with socket.socket() as s:
 if s.connect_ex(('127.0.0.1',8187))==0:raise SystemExit('PORT_8187_ALREADY_IN_USE; not touched')
java='/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/java'
jar='/Users/brunorodrigues/.cache/firebase/emulators/cloud-firestore-emulator-v1.21.0.jar'
tests=Path((root/'evidence/integration-test-path.txt').read_text().strip())
source=Path((root/'evidence/integration-candidate-path.txt').read_text().strip())
env={**os.environ,'FIRESTORE_EMULATOR_HOST':'127.0.0.1:8187','R23_FUNCTION_SOURCE':str(source/'index.js')}
with (root/'evidence/emulator-local.log').open('w') as log:
 server=subprocess.Popen([java,'-jar',jar,'--host=127.0.0.1','--port=8187','--rules='+str(tests.parent/'firestore.rules')],stdout=log,stderr=subprocess.STDOUT)
 try:
  for i in range(30):
   if server.poll() is not None:raise RuntimeError('EMULATOR_START_FAILED')
   try:
    urllib.request.urlopen('http://127.0.0.1:8187/',timeout=1);break
   except Exception:time.sleep(1)
  else:raise RuntimeError('EMULATOR_NOT_READY')
  with (root/('evidence/commercial-drug-followup-http-sse.log' if len(sys.argv)>1 else 'evidence/commercial-drug-http-sse.log')).open('w') as out:
   r=subprocess.run(['node','--test','--test-name-pattern',sys.argv[1] if len(sys.argv)>1 else 'CATALOG|R15 drug|R15 compiler drug|R15 real compiler drug|R15 pharmacological|R15 explicitly absent|R15 authorized nominal|R15 load unchanged',str(tests)],env=env,stdout=out,stderr=subprocess.STDOUT,timeout=300)
  print('LOCAL_HTTP_SSE_EXIT='+str(r.returncode))
  raise SystemExit(r.returncode)
 finally:
  server.terminate()
  try:server.wait(timeout=10)
  except subprocess.TimeoutExpired:server.kill();server.wait()
