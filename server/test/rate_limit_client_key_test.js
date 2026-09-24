'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {resolveRateLimitClientKey:key}=require('../rate_limit_client_key');
const request=(peer,client,extra={})=>({socket:{remoteAddress:peer},headers:{'do-connecting-ip':client,...extra}});
test('public private edge uses normalized client IPv4, independent of proxy rotation',()=>{
 for(const peer of ['100.64.0.1','100.127.255.254','::ffff:100.64.0.1','10.244.0.2','10.244.1.3','172.16.0.2','192.168.1.2','::ffff:10.244.0.2','fd00::2'])assert.equal(key(request(peer,'198.51.100.44')),'198.51.100.44');
});
test('all untrusted forwarding headers are irrelevant, including multiple XFF',()=>{
 for(const h of ['x-forwarded-for','forwarded','x-real-ip','cf-connecting-ip','true-client-ip'])for(const v of ['203.0.113.55','203.0.113.55, 2001:db8::99'])assert.equal(key(request('10.244.0.2','198.51.100.44',{[h]:v})),'198.51.100.44');
});
test('loopback, public, link-local and non-boundary sockets ignore even valid forged header',()=>{
 for(const peer of ['100.63.255.255','100.128.0.1','127.0.0.1','127.42.1.2','::1','::ffff:127.0.0.1','198.51.100.22','169.254.1.2','fe80::1','2001:db8::4'])assert.equal(key(request(peer,'203.0.113.55')),peer==='::ffff:127.0.0.1'?'127.0.0.1':peer);
});
test('self-addressed internal traffic ignores do-connecting-ip',()=>{
 const r=request('10.244.0.2','203.0.113.55');r.socket.localAddress='::ffff:10.244.0.2';assert.equal(key(r),'10.244.0.2');
});
test('invalid, excessive, lists, whitespace, ports, arrays and scopes fall back without crash',()=>{
 for(const v of [undefined,null,'',' ',' 198.51.100.44','198.51.100.44 ','198.51.100.44\t','198.51.100.44,203.0.113.55','invalid','198.051.100.44','198.51.100.44:80','[2001:db8::1]','fe80::1%eth0','x'.repeat(10000),[],['198.51.100.44'],{},42])assert.equal(key(request('10.244.0.2',v)),'10.244.0.2');
});
test('duplicate physical headers fail closed even if framework header looks valid',()=>{
 const r=request('10.244.0.2','198.51.100.44');r.rawHeaders=['Do-Connecting-IP','198.51.100.44','do-connecting-ip','203.0.113.55'];assert.equal(key(r),'10.244.0.2');
});
test('IPv6 equivalent spelling and IPv4-mapped forms share canonical keys',()=>{
 for(const ip of ['2001:DB8:0000:0000:0000:0000:0000:0099','2001:db8::99'])assert.equal(key(request('10.244.0.2',ip)),'2001:db8::99');
 for(const ip of ['::ffff:198.51.100.44','0:0:0:0:0:ffff:c633:642c','198.51.100.44'])assert.equal(key(request('10.244.0.2',ip)),'198.51.100.44');
});
test('missing/invalid sockets stay bounded and headers never rescue them',()=>{
 for(const r of [undefined,null,{},request(undefined,'198.51.100.44'),request('not-an-ip','198.51.100.44')])assert.equal(key(r),'unresolved-socket');
});
test('helper does not mutate request or global Express identity',()=>{
 const r=request('10.244.0.2','198.51.100.44');r.ip='10.244.0.2';r.app={get:()=>false};const before=JSON.stringify(r);assert.equal(key(r),'198.51.100.44');assert.equal(JSON.stringify(r),before);assert.equal(r.ip,'10.244.0.2');
});
