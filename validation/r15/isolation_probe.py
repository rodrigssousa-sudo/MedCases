"""Controlled network canaries only. Never contacts a commercial endpoint."""
import http.server,json,subprocess,threading,urllib.request,time,re
from network_guard import run,BRIDGE

def drop_counter(chain,command=run):
    text=command(['sudo','iptables-save','-c','-t','filter'])
    pattern=r'^\[(\d+):\d+\] -A '+re.escape(chain)+r' -i '+re.escape(BRIDGE)+r' -j DROP$'
    hits=[int(m.group(1)) for line in text.splitlines() if (m:=re.match(pattern,line))]
    if len(hits)!=1:raise RuntimeError('DROP_COUNTER_NOT_UNIQUE:'+chain)
    return hits[0]

def validate_negative(control_status,exit_code,before,after):
    if control_status!=200:raise RuntimeError('CANARY_NOT_REACHABLE_FROM_HOST')
    if exit_code==0:raise RuntimeError('OUTBOUND_CONNECTION_WAS_ALLOWED')
    if after<=before:raise RuntimeError('OUTBOUND_DENIAL_NOT_ATTRIBUTED_TO_FIREWALL')

class Canary(http.server.BaseHTTPRequestHandler):
    def log_message(self,*args):pass
    def do_GET(self):
        self.send_response(200);self.end_headers();self.wfile.write(b'isolated-canary')

def prove_isolation(out):
    records=[];server=None;thread=None
    try:
        network=json.loads(run(['docker','network','inspect','r15-validation']))[0]
        gateway=network['IPAM']['Config'][0]['Gateway']
        server=http.server.ThreadingHTTPServer((gateway,0),Canary)
        thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
        host_url=f'http://{gateway}:{server.server_port}/health'
        run(['docker','network','create','--internal','r15-egress-canary-net'])
        run(['docker','run','-d','--name','r15-egress-canary','--network','r15-egress-canary-net','--dns','127.0.0.1','r15-validation'])
        inspect=json.loads(run(['docker','inspect','r15-egress-canary']))[0]
        target=inspect['NetworkSettings']['Networks']['r15-egress-canary-net']['IPAddress']
        forward_url=f'http://{target}:8080/health'
        opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
        for chain,url in [('INPUT',host_url),('DOCKER-USER',forward_url)]:
            for n in range(40):
                try:
                    with opener.open(url,timeout=2) as response:control=response.status
                    break
                except OSError:
                    if n==39:raise
                    time.sleep(1)
            before=drop_counter(chain)
            probe=subprocess.run(['docker','exec','r15-web','wget','-S','-T','2','-O','-',url],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=10)
            after=drop_counter(chain)
            record={'chain':chain,'target':'controlled-local-canary','controlHTTP':control,'containerExitCode':probe.returncode,'dropCounterBefore':before,'dropCounterAfter':after}
            records.append(record);(out/'outbound-probes.json').write_text(json.dumps(records,indent=2))
            (out/('outbound-'+chain+'.log')).write_bytes(probe.stdout)
            validate_negative(control,probe.returncode,before,after)
        return {'status':'PASS_REAL','scope':'all new IPv4 outbound flows denied by interface-wide rules; two controlled host/forward canaries; IPv6 disabled; no production calls','probes':records}
    finally:
        if server:server.shutdown();server.server_close()
        if thread:thread.join(timeout=3)
