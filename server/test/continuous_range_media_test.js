'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {structure}=require('../audio_media_structure'),{longAac}=require('./long_recording_fixture');
const {inspectAudio,storedProof}=require('../audio_media_budget');
const {inspectSingleRecording}=require('../single_recording_audio');
const {Readable}=require('node:stream'),crypto=require('node:crypto');
function adts(seconds){const mp4=longAac(seconds),s=structure(mp4,{longRecording:true,continuousRange:true});const rates=[96000,88200,64000,48000,44100,32000,24000,22050,16000,12000,11025,8000,7350],index=rates.indexOf(s.rate);
 const frames=s.frames.map(([off,n])=>{const length=n+7,h=Buffer.from([255,241,(1<<6)|(index<<2)|(s.channels>>2),(s.channels&3)<<6|length>>11,length>>3,(length&7)<<5|31,252]);return Buffer.concat([h,mp4.subarray(off,off+n)]);});
 return {bytes:Buffer.concat(frames),frames:s.frames.length,rate:s.rate};}
test('continuous authorized audio above legacy 90 minutes remains one media proof',async()=>{
 const a=adts(91*60),sha256=crypto.createHash('sha256').update(a.bytes).digest('hex'),duration=Math.ceil(a.frames*1024*1000/a.rate);
 assert.throws(()=>structure(a.bytes,{longRecording:true}),/MEDIA_INVALID/);
 const range={startFrame:0,endFrame:a.frames,totalFrames:a.frames,sampleRate:a.rate,originalSha256:sha256};
 const result=await inspectSingleRecording({storage:{getStream:async()=>({contentLength:a.bytes.length,body:Readable.from([Buffer.from(a.bytes)])})},segment:{index:0,objectKey:'qa',bodyHash:sha256},maximumMs:duration,transcriptionRange:range});
 assert.equal(result.totalDurationMs,duration);assert.equal(result.physicalSegments.length,1);
 assert.throws(()=>storedProof(result.physicalSegments[0],{longRecording:true}),/BINDING_REQUIRED/);
 assert.doesNotThrow(()=>storedProof(result.physicalSegments[0],{longRecording:true,continuousRange:true}));
});
test('forged range cannot replace decoded media duration',async()=>{
 const a=adts(20),sha256=crypto.createHash('sha256').update(a.bytes).digest('hex');
 await assert.rejects(inspectSingleRecording({storage:{getStream:async()=>({contentLength:a.bytes.length,body:Readable.from([Buffer.from(a.bytes)])})},segment:{index:0,objectKey:'qa',bodyHash:sha256},maximumMs:60000,transcriptionRange:{startFrame:0,endFrame:a.frames-1,totalFrames:a.frames,sampleRate:a.rate,originalSha256:sha256}}),/RANGE_MEDIA_MISMATCH/);
});
