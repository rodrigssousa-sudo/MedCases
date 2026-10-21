// Test-only loopback TLS origin. No forwarding, credentials, or upstream requests.
const fs=require('fs'),https=require('https'),crypto=require('crypto'),cp=require('child_process'),os=require('os'),path=require('path');
const {safePath,mime}=require('./b2_contract.cjs');
function selectAsset(host,pathname,root,phase){
 if(host==='www.gstatic.com'&&/^\/firebasejs\/(10\.12\.0|11\.9\.1|10\.14\.1)\/firebase-[a-z-]+\.js$/.test(pathname))return safePath(root+'/vendor',pathname);
 if(host==='www.gstatic.com'&&pathname.startsWith('/flutter-canvaskit/83675ed27633283e7fc296c8bca22e841224c096/'))return safePath(root+'/'+phase+'/canvaskit',pathname.split('/').slice(3).join('/'));
 return null;
}
async function startStaticOrigin(root,phase,observer){
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'r15-static-cert-'));const key=dir+'/key.pem',cert=dir+'/cert.pem';
 cp.execFileSync('openssl',['req','-x509','-newkey','rsa:2048','-nodes','-keyout',key,'-out',cert,'-days','1','-subj','/CN=www.gstatic.com'],{stdio:'ignore'});
 const pin=crypto.createHash('sha256').update(new crypto.X509Certificate(fs.readFileSync(cert)).publicKey.export({type:'spki',format:'der'})).digest('base64');
 const server=https.createServer({key:fs.readFileSync(key),cert:fs.readFileSync(cert)},(req,res)=>{
  const host=(req.headers.host||'').split(':')[0],p=new URL(req.url,'https://www.gstatic.com').pathname;
  let file;try{file=selectAsset(host,p,root,phase())}catch{}
  if(req.method!=='GET'||!file||!fs.existsSync(file)||!fs.statSync(file).isFile()){observer.append('static-origin-denied',{host,path:p,status:404});res.writeHead(404).end();return}
  const body=fs.readFileSync(file);observer.append('static-origin-served',{host,path:p,status:200,sha256:crypto.createHash('sha256').update(body).digest('hex')});
  res.writeHead(200,{'Content-Type':mime(file),'Access-Control-Allow-Origin':'*','Cache-Control':'public,max-age=3600'});res.end(body);
 });
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 return {args:['--host-resolver-rules=MAP www.gstatic.com 127.0.0.1:'+server.address().port+', MAP * ~NOTFOUND, EXCLUDE 127.0.0.1','--ignore-certificate-errors-spki-list='+pin,'--no-proxy-server'],close:()=>new Promise(r=>{server.close(()=>{fs.rmSync(dir,{recursive:true,force:true});r()});server.closeAllConnections()})};
}
module.exports={selectAsset,startStaticOrigin};
