import subprocess,pathlib,hashlib,json
BASE='6d0ac951fe5368d2b5a116e5c8fc18c850bc75f9'
BUNDLE='f924db5f77a336fb906f22fd985c117bb990fc3e9ca0962c1566947ce747617a'
def allowed_dockerfile(before,after):
    return before.count('http://localhost:8080/health')==1 and after==before.replace('http://localhost:8080/health','http://127.0.0.1:8080/health')
def verify(root):
    git=lambda *a:subprocess.check_output(['git','-C',str(root),*a]).decode().strip()
    git('merge-base','--is-ancestor',BASE,'HEAD')
    for file in git('diff','--name-only',BASE,'HEAD').splitlines():
        if file!='Dockerfile' and file!='.github/workflows/r15-b1-b2-validation.yml' and not file.startswith('validation/r15/'):
            raise RuntimeError('UNAPPROVED_DIFF:'+file)
    before=subprocess.check_output(['git','-C',str(root),'show',BASE+':Dockerfile']).decode()
    assert allowed_dockerfile(before,(root/'Dockerfile').read_text()),'DOCKERFILE_DELTA_NOT_EXACT'
    assert hashlib.sha256((root/'release-web-r15.tar.gz').read_bytes()).hexdigest()==BUNDLE
    return {'commercialBase':BASE,'validationCommit':git('rev-parse','HEAD'),'bundleSHA256':BUNDLE,'dockerfileDelta':'HEALTHCHECK localhost -> 127.0.0.1 only'}
if __name__=='__main__':
    root=pathlib.Path.cwd();out=root/'receipts';out.mkdir(exist_ok=True)
    (out/'frozen-inputs.json').write_text(json.dumps(verify(root),indent=2))
