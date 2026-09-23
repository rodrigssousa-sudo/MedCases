'use strict';
// Strict, bounded subset used by the app: PCM WAV and one AAC-LC MP4 track.
// No container duration is billing authority. Samples are decoded in an isolated
// worker; tables are checked here before allocations by a third-party decoder.
const {scanMp4}=require('./iso_bmff_boxes');
const MAX_BYTES=25*1024*1024, MAX_DURATION_MS=15*60*1000, MAX_FRAMES=50000;
function fail(){throw Error('MEDIA_INVALID_OR_UNSUPPORTED');}
function structure(bytes){
 const b=Buffer.from(bytes.buffer,bytes.byteOffset,bytes.byteLength);
 if(!b.length||b.length>MAX_BYTES)fail();
 if(b.toString('ascii',0,4)==='RIFF'){
  if(b.length<44||b.readUInt32LE(4)+8!==b.length||b.toString('ascii',8,12)!=='WAVE')fail();
  let fmt=null,data=null;
  for(let p=12;p<b.length;){if(p+8>b.length)fail();const n=b.readUInt32LE(p+4),end=p+8+n;if(end>b.length)fail();const t=b.toString('ascii',p,p+4);
   if(t==='fmt '){if(fmt||n!==16)fail();fmt=p+8;}if(t==='data'){if(data)fail();data={offset:p+8,length:n};}p=end+(n%2);if(p>b.length)fail();}
  if(fmt===null||!data||!data.length)fail();const channels=b.readUInt16LE(fmt+2),rate=b.readUInt32LE(fmt+4),bits=b.readUInt16LE(fmt+14),align=b.readUInt16LE(fmt+12);
  if(b.readUInt16LE(fmt)!==1||![1,2].includes(channels)||rate<8000||rate>48000||![8,16,24,32].includes(bits)||align!==channels*bits/8||b.readUInt32LE(fmt+8)!==rate*align||data.length%align)fail();
  const durationMs=Math.ceil(data.length/align/rate*1000);if(durationMs<=0||durationMs>MAX_DURATION_MS)fail();return {kind:'wav',durationMs};
 }
 scanMp4(b);
 const found=new Map(),mdats=[];let tracks=0,boxes=0;
 function walk(start,end,depth=0){if(depth>10)fail();for(let p=start;p<end;){if(++boxes>1000||p+8>end)fail();let n=b.readUInt32BE(p),h=8;const t=b.toString('ascii',p+4,p+8);if(n===1){if(p+16>end)fail();const big=b.readBigUInt64BE(p+8);if(big>BigInt(MAX_BYTES))fail();n=Number(big);h=16;}if(n===0){if(depth!==0||t!=='mdat')fail();n=end-p;}if(n<h||p+n>end)fail();const a=p+h,z=p+n;
  if(t==='mdat')mdats.push([a,z]);if(t==='trak'&&++tracks>1)fail();
  if(['ftyp','mdhd','hdlr','stsz','stco','co64','stsc','stts','esds','stsd'].includes(t)){if(found.has(t))fail();found.set(t,{a,z});}
  if(['moov','trak','mdia','minf','stbl'].includes(t))walk(a,z,depth+1);
  if(t==='stsd'){if(a+8>z||b.readUInt32BE(a+4)!==1)fail();const q=a+8;if(q+36>z||b.toString('ascii',q+4,q+8)!=='mp4a'||b.readUInt16BE(q+16)!==0||q+b.readUInt32BE(q)!==z)fail();walk(q+36,z,depth+1);}
  p=z;
 }}walk(0,b.length);
 const get=t=>{const x=found.get(t);if(!x)fail();return x;};get('ftyp');if(tracks!==1||!mdats.length||found.has('co64')&&found.has('stco'))fail();
 const h=get('hdlr');if(h.a+12>h.z||b.toString('ascii',h.a+8,h.a+12)!=='soun')fail();
 const e=get('esds');if(e.a+4>=e.z)fail();let asc=null;
 function descriptors(a,z){while(a<z){const tag=b[a++];let n=0,c=0,v;do{if(a>=z||++c>4)fail();v=b[a++];n=n*128+(v&127);}while(v&128);const end=a+n;if(end>z)fail();
  if(tag===3){if(a+3>end)fail();let p=a+3,flags=b[a+2];if(flags&128)p+=2;if(flags&64){if(p>=end)fail();p+=1+b[p];}if(flags&32)p+=2;if(p>end)fail();descriptors(p,end);}
  else if(tag===4){if(a+13>end||b[a]!==0x40)fail();descriptors(a+13,end);}
  else if(tag===5){if(asc||n!==2)fail();asc=Buffer.from(b.subarray(a,end));}a=end;
 }}descriptors(e.a+4,e.z);
 if(!asc)fail();const object=asc[0]>>3,index=((asc[0]&7)<<1)|(asc[1]>>7),channels=(asc[1]>>3)&15,rate=[96000,88200,64000,48000,44100,32000,24000,22050,16000,12000,11025,8000,7350][index];
 if(object!==2||![1,2].includes(channels)||!rate||rate<8000||rate>48000||(asc[1]&7)!==0)fail();
 const sz=get('stsz');if(sz.a+12>sz.z)fail();const fixed=b.readUInt32BE(sz.a+4),count=b.readUInt32BE(sz.a+8);if(!count||count>MAX_FRAMES||sz.a+12+(fixed?0:count*4)!==sz.z)fail();
 const sizes=Array.from({length:count},(_,i)=>fixed||b.readUInt32BE(sz.a+12+i*4));if(sizes.some(n=>!n||n>65536))fail();
 const sc=get('stsc');if(sc.a+8>sc.z)fail();const scn=b.readUInt32BE(sc.a+4);if(!scn||scn>count||sc.a+8+scn*12!==sc.z)fail();const map=[];for(let i=0;i<scn;i++){const p=sc.a+8+i*12,first=b.readUInt32BE(p),per=b.readUInt32BE(p+4),desc=b.readUInt32BE(p+8);if(!first||!per||per>count||desc!==1||(i===0?first!==1:first<=map[i-1].first))fail();map.push({first,per});}
 const co=found.get('stco')||get('co64'),wide=found.has('co64'),step=wide?8:4;if(co.a+8>co.z)fail();const cn=b.readUInt32BE(co.a+4);if(!cn||cn>count||co.a+8+cn*step!==co.z)fail();const frames=[];let si=0,mi=0,last=0;
 for(let c=1;c<=cn;c++){while(mi+1<map.length&&map[mi+1].first<=c)mi++;const v=wide?b.readBigUInt64BE(co.a+8+(c-1)*8):BigInt(b.readUInt32BE(co.a+8+(c-1)*4));if(v>BigInt(b.length))fail();let off=Number(v);for(let j=0;j<map[mi].per;j++){if(si>=count)fail();const size=sizes[si++];if(off<last||!mdats.some(([a,z])=>off>=a&&off+size<=z))fail();frames.push([off,size]);off+=size;last=off;}}
 if(si!==count||map[map.length-1].first>cn)fail();
 // Reject time-table stretching/understatement. AAC LC has 1024 decoded samples
 // per access unit. Movie header/edit-list duration is never used for quota.
 const md=get('mdhd'),ver=b[md.a],tp=md.a+(ver===1?20:ver===0?12:NaN);if(!Number.isFinite(tp)||tp+4>md.z||b.readUInt32BE(tp)!==rate)fail();
 const st=get('stts');if(st.a+8>st.z)fail();const sn=b.readUInt32BE(st.a+4);if(!sn||sn>count||st.a+8+sn*8!==st.z)fail();let total=0;for(let i=0;i<sn;i++){const p=st.a+8+i*8,n=b.readUInt32BE(p),delta=b.readUInt32BE(p+4);if(!n||delta<1||delta>1024)fail();total+=n;}if(total!==count)fail();
 const upperMs=Math.ceil(count*1024/rate*1000);if(upperMs>MAX_DURATION_MS)fail();return {kind:'aac',asc,frames,rate,channels,upperMs};
}
module.exports={structure,MAX_BYTES,MAX_DURATION_MS};
