// Loopback-only fixture host. No Firebase, Google, quota or history remote calls.
const {createServer}=require('node:http');const fs=require('node:fs');
const {createEngine3Gateway,PROJECT,AUDIENCE,GATEWAY_IDENTITY}=require('../engine3_gateway');
const fixture=JSON.parse(fs.readFileSync(process.argv[2],'utf8'));
const token='fixture.'+Buffer.from(JSON.stringify({aud:AUDIENCE,iss:'https://accounts.google.com',email:GATEWAY_IDENTITY,exp:Math.floor(Date.now()/1000)+3600})).toString('base64url')+'.signature';
const frame=(event,data)=>`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
const handler=createEngine3Gateway({env:{ENGINE3_GATEWAY_ENABLED:'true',FIREBASE_PROJECT_ID:PROJECT,ENGINE3_HML_ORIGINS:'http://127.0.0.1:8895'},
 verifyFirebase:async value=>{if(value!=='LOCAL_ONLY')throw Error('auth');return{uid:'fixture-user',aud:PROJECT,iss:`https://securetoken.google.com/${PROJECT}`};},
 getInvokerToken:async()=>token,
 fetchUpstream:async(_url,options)=>{
  const req=JSON.parse(options.body);const d=structuredClone(fixture);d.requestId=req.requestId;
  if(req.question==='LOCAL_BLOCKED')return Response.json({error:'UNVALIDATED_FINAL'},{status:422});
  if(req.question==='LOCAL_LIMITED'){d.validationStatus='LIMITED';d.validation.state='LIMITED';d.validation.omittedClaims=1;d.limitations.push('LOCAL_FIXTURE_OMISSION');}
  const terminal=frame('transport_done',{requestId:req.requestId,validationStatus:d.validationStatus,validation:d.validation,evidenceClass:d.evidenceClass});
  const output=frame('started',{requestId:req.requestId})+frame('external_evidence',d)+(req.question==='LOCAL_INCOMPLETE'?'':terminal+terminal);
  return new Response(output,{headers:{'content-type':'text/event-stream'}});
 }});
const server=createServer(handler);server.listen(0,'127.0.0.1',()=>console.log(JSON.stringify({port:server.address().port})));
process.on('SIGTERM',()=>{server.closeAllConnections();server.close();});
