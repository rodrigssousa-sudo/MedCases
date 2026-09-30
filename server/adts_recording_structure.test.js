'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {inspectAudio}=require('./audio_media_budget');
const {adts}=require('./test/adts_fixture');
for(const name of ['silence-4s-aac.m4a','synthetic-speech-2s-22050.m4a'])test(`complete native-style ADTS frames retain decoded duration: ${name}`,async()=>{
 const mp4=fs.readFileSync(path.join(__dirname,'test/fixtures',name)),bytes=adts(mp4);
 const [a,b]=await Promise.all([inspectAudio(mp4,{longRecording:true}),inspectAudio(bytes,{longRecording:true})]);assert.equal(a.durationMs,b.durationMs);
 await assert.rejects(inspectAudio(bytes),/MEDIA_/);
 await assert.rejects(inspectAudio(bytes.subarray(0,bytes.length-1),{longRecording:true}),/MEDIA_/);
 const bad=Buffer.from(bytes);bad[2]|=0xc0;await assert.rejects(inspectAudio(bad,{longRecording:true}),/MEDIA_/);
});
module.exports={adts};
