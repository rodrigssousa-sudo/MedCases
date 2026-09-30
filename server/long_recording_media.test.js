'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {inspectAudio,combineProofs,validProof,digest}=require('./audio_media_budget');
const {longAac}=require('./test/long_recording_fixture');
for(const seconds of [20,300,1080,1800,3600])test(`one AAC file: ${seconds}s decoded server-side, no segmentation`,async()=>{
 const bytes=longAac(seconds),start=Date.now(),proof=await inspectAudio(bytes,{longRecording:true});
 assert(Math.abs(proof.durationMs-seconds*1000)<50);assert(validProof(combineProofs([proof],digest('synthetic'))));
 console.log(JSON.stringify({syntheticSeconds:seconds,bytes:bytes.length,inspectionMs:Date.now()-start}));
});
test('legacy inspector still rejects 18 minutes',async()=>{await assert.rejects(inspectAudio(longAac(1080)),/MEDIA_/);});
test('long recording rejects duration over bounded 90 minutes',async()=>{await assert.rejects(inspectAudio(longAac(5402),{longRecording:true}),/MEDIA_/);});
test('synthetic speech with implicit AAC upsampling preserves duration, in both compatible profiles',async()=>{
 const fs=require('node:fs'),path=require('node:path'),{structure}=require('./audio_media_structure');
 const bytes=fs.readFileSync(path.join(__dirname,'test/fixtures/synthetic-speech-2s-22050.m4a'));
 const parsed=structure(bytes),proof=await inspectAudio(bytes,{longRecording:true});
 assert.equal(proof.durationMs,Math.ceil(parsed.frames.length*1024/parsed.rate*1000));
 assert(proof.durationMs>=2000&&proof.durationMs<2200);
 const legacy=await inspectAudio(bytes);assert.equal(legacy.durationMs,proof.durationMs);
 const truncated=bytes.subarray(0,bytes.length-3);
 await assert.rejects(inspectAudio(truncated,{longRecording:true}),/MEDIA_/);
});
