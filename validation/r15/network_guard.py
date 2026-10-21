"""Runner-only firewall; no production addresses or credentials are used."""
import json
import subprocess
import sys
BRIDGE='br-r15-b1'
NETWORK='r15-validation'
# NEW outbound traffic (including host access) is denied. Only replies to
# host-initiated connections are accepted. No destination/IP allowlist.
RULES=[
 ('DOCKER-USER',['-i',BRIDGE,'-m','conntrack','--ctstate','ESTABLISHED,RELATED','-j','RETURN']),
 ('DOCKER-USER',['-i',BRIDGE,'-j','DROP']),
 ('INPUT',['-i',BRIDGE,'-m','conntrack','--ctstate','ESTABLISHED,RELATED','-j','ACCEPT']),
 ('INPUT',['-i',BRIDGE,'-j','DROP']),
]
def run(args):return subprocess.check_output(args,stderr=subprocess.STDOUT,timeout=30).decode()
def firewall_args(op,chain,rule):return ['sudo','iptables','-w',op,chain,*rule]
def setup(command=run):
 command(['docker','network','create','--driver','bridge','--opt','com.docker.network.bridge.name='+BRIDGE,NETWORK])
 # Insert deny first, then replies in front. No container exists until checks pass.
 for chain,rule in reversed(RULES):command(firewall_args('-I',chain,rule))
 return verify(command)
def verify(command=run):
 network=json.loads(command(['docker','network','inspect',NETWORK]))[0]
 if network['Internal'] or network['EnableIPv6'] or network['Options'].get('com.docker.network.bridge.name')!=BRIDGE:
  raise RuntimeError('UNEXPECTED_TEST_NETWORK')
 # Check presence AND order; an earlier RETURN would invalidate isolation.
 for chain in ['DOCKER-USER','INPUT']:
  lines=command(['sudo','iptables','-w','-S',chain]).splitlines()
  actual=[line for line in lines if line.startswith('-A '+chain+' ')][:2]
  expected=['-A '+chain+' '+' '.join(rule) for c,rule in RULES if c==chain]
  normalize=lambda line:line.replace('ESTABLISHED,RELATED','RELATED,ESTABLISHED')
  if list(map(normalize,actual))!=list(map(normalize,expected)):raise RuntimeError('OUTBOUND_FIREWALL_NOT_EFFECTIVE:'+chain)
 return {'bridge':BRIDGE,'ipv6':False,'outbound':'DROP','hostAccess':'DROP','replyTraffic':'ESTABLISHED_RELATED_ONLY'}
def require_mapping(inspect):
 expected={'8080/tcp':[{'HostIp':'127.0.0.1','HostPort':'18080'}]}
 if inspect.get('NetworkSettings',{}).get('Ports')!=expected:
  raise RuntimeError('PORT_MAPPING_MISSING_OR_UNSAFE')
 if inspect.get('HostConfig',{}).get('Dns')!=['127.0.0.1']:
  raise RuntimeError('EXTERNAL_DNS_NOT_DISABLED')
 return expected
def cleanup(command=run):
 # Called only after removing the test container. Remove exact owned rules.
 try:command(['docker','inspect','r15-web'])
 except subprocess.CalledProcessError:pass
 else:raise RuntimeError('REMOVE_CONTAINER_BEFORE_FIREWALL')
 failed=[]
 for chain,rule in RULES:
  try:command(firewall_args('-C',chain,rule))
  except subprocess.CalledProcessError:continue
  try:
   command(firewall_args('-D',chain,rule))
   try:command(firewall_args('-C',chain,rule))
   except subprocess.CalledProcessError:pass
   else:failed.append(chain)
  except Exception:failed.append(chain)
 if failed:raise RuntimeError('FIREWALL_CLEANUP_FAILED')
if __name__=='__main__':
 if sys.argv[1:]!=['cleanup']:raise SystemExit('Only cleanup is exposed as CLI')
 cleanup()
