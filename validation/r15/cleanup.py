"""Best-effort cleanup with explicit readback; never hides failure."""
import subprocess,pathlib,json
from network_guard import cleanup
out=pathlib.Path('receipts');out.mkdir(exist_ok=True)
result={};failed=False
for name in ['r15-web','r15-egress-canary']:
    exists=subprocess.run(['docker','inspect',name],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode==0
    removed=not exists or subprocess.run(['docker','rm','-f',name],stdout=subprocess.DEVNULL).returncode==0
    result[name]='REMOVED' if removed else 'FAILED';failed|=not removed
try:cleanup();result['firewall']='OWN_RULES_REMOVED'
except Exception as e:failed=True;result['firewall']=type(e).__name__
for name in ['r15-validation','r15-egress-canary-net']:
    exists=subprocess.run(['docker','network','inspect',name],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode==0
    removed=not exists or subprocess.run(['docker','network','rm',name],stdout=subprocess.DEVNULL).returncode==0
    result[name]='REMOVED' if removed else 'FAILED';failed|=not removed
for name in ['r15-validation','r15-browser']:
    subprocess.run(['docker','image','rm',name],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
(out/'cleanup.json').write_text(json.dumps(result,indent=2))
raise SystemExit(1 if failed else 0)
