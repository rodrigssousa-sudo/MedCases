'use strict';
// Synthetic silence only, remuxed from the checked-in four-second AAC fixture.
const fs=require('node:fs'),path=require('node:path');
const {structure}=require('../audio_media_structure');
const {scanMp4}=require('../iso_bmff_boxes');
function box(type,body){const b=Buffer.alloc(8);b.writeUInt32BE(body.length+8);b.write(type,4);return Buffer.concat([b,body]);}
function ints(...v){const b=Buffer.alloc(v.length*4);v.forEach((n,i)=>b.writeUInt32BE(n,i*4));return b;}
function longAac(seconds){
 const original=fs.readFileSync(path.join(__dirname,'fixtures/silence-4s-aac.m4a')),s=structure(original),count=Math.floor(seconds*s.rate/1024);
 const packet=original.subarray(s.frames[1][0],s.frames[1][0]+s.frames[1][1]);
 const top=scanMp4(original),ft=top.find(x=>x.type==='ftyp'),moov=top.find(x=>x.type==='moov');
 const ftyp=original.subarray(ft.start,ft.end),offset=ftyp.length+8;
 function rewrite(a,z){const items=[];for(let p=a;p<z;){const n=original.readUInt32BE(p),t=original.toString('ascii',p+4,p+8);let body=original.subarray(p+8,p+n);
  if(['moov','trak','mdia','minf','stbl'].includes(t))body=rewrite(p+8,p+n);
  if(t==='stsz')body=ints(0,packet.length,count);
  if(t==='stsc')body=ints(0,1,1,count,1);
  if(t==='stco')body=ints(0,1,offset);
  if(t==='stts')body=ints(0,1,count,1024);
  items.push(box(t,body));p+=n;}return Buffer.concat(items);}
 return Buffer.concat([ftyp,box('mdat',Buffer.concat(Array.from({length:count},()=>packet))),rewrite(moov.start,moov.end)]);
}
module.exports={longAac};
