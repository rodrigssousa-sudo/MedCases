"""Retain an existing successful B1 run; never claim this is a new Linux run."""
import pathlib,json,hashlib,shutil

def verify(root):
    source=root/'validation/r15/retained-b1';m=json.loads((source/'provenance.json').read_text())
    for f,h in m['sourceHashes'].items():
        if hashlib.sha256((root/f).read_bytes()).hexdigest()!=h:raise RuntimeError('B1_SOURCE_CHANGED:'+f)
    for f,h in m['receiptHashes'].items():
        if hashlib.sha256((source/f).read_bytes()).hexdigest()!=h:raise RuntimeError('B1_RECEIPT_CHANGED:'+f)
    b=json.loads((source/'b1.json').read_text())
    for k in ['B1_LINUX_IMAGE','B1_NGINX_STARTUP','B1_PORT_8080','B1_HTTP_HEALTH','B1_RESTART','negativeConfig']:assert b[k]=='PASS',k
    assert b['outboundIsolation']['status']=='PASS_REAL'
    assert hashlib.sha256((root/'release-web-r15.tar.gz').read_bytes()).hexdigest()==b['inputHashes']['release-web-r15.tar.gz']
    for f in ['startup-docker-health.json','restart-docker-health.json']:assert json.loads((source/f).read_text())['Health']['Status']=='healthy'
    return source,m
if __name__=='__main__':
    root=pathlib.Path.cwd();source,m=verify(root);out=root/'receipts';out.mkdir(exist_ok=True)
    shutil.copyfile(source/'startup-deploy-meta.json',out/'startup-deploy-meta.json')
    (out/'B1_RETAINED.json').write_text(json.dumps({'status':'PASS_REAL_RETAINED','newExecution':False,'run':m['run'],'commit':m['commit'],'artifactSHA256':m['artifactSHA256']},indent=2))
