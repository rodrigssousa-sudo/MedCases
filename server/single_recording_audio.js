'use strict';
const {inspectAudio,digest}=require('./audio_media_budget');
const {adtsRecordingStructure}=require('./adts_recording_structure');
const {assertRangeMedia}=require('./transcription_range_contract');
const MAX_UPLOAD_BYTES=64*1024*1024,MAX_DURATION_MS=90*60*1000;
async function inspectSingleRecording({storage,segment,maximumMs,transcriptionRange=null}){
 if(segment.index!==0||!segment.objectKey)throw Error('SINGLE_AUDIO_BINDING_INVALID');
 const {body,contentLength}=await storage.getStream(segment.objectKey);
 if(contentLength>MAX_UPLOAD_BYTES){body.destroy?.();throw Error('MEDIA_SIZE_INVALID');}
 const chunks=[];let length=0,bytes;
 try{
  for await(const chunk of body){length+=chunk.length;if(length>MAX_UPLOAD_BYTES)throw Error('MEDIA_SIZE_INVALID');chunks.push(chunk);}
  bytes=Buffer.concat(chunks);if(digest(bytes)!==segment.bodyHash)throw Error('AUDIO_BINDING_INVALID');
  const proof=await inspectAudio(bytes,{longRecording:true,continuousRange:!!transcriptionRange});
  if(transcriptionRange){const frames=adtsRecordingStructure(bytes,{maxFrames:1687500,maxDuration:10*60*60*1000});assertRangeMedia(transcriptionRange,{durationMs:proof.durationMs,frameCount:frames.frames.length,sampleRate:frames.rate});}
  if(proof.durationMs>maximumMs||proof.durationMs>(transcriptionRange?10*60*60*1000:MAX_DURATION_MS))throw Error('MEDIA_EXCEEDS_RESERVED_BUDGET');
  return {objectKey:segment.objectKey,totalDurationMs:proof.durationMs,totalBytes:length,assembledBytes:length,
   physicalSegments:[{index:0,durationMs:proof.durationMs,sha256:proof.sha256,byteLength:length}]};
 }finally{bytes?.fill(0);for(const c of chunks)c.fill?.(0);body.destroy?.();}
}
module.exports={inspectSingleRecording,MAX_UPLOAD_BYTES,MAX_DURATION_MS};
