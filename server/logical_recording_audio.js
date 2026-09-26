'use strict';
const fs=require('node:fs'),fsp=fs.promises,path=require('node:path'),os=require('node:os'),crypto=require('node:crypto');
const {pipeline}=require('node:stream/promises');
const {Transform}=require('node:stream');
const {spawn}=require('node:child_process');
const {classifyBinary}=require('./binary_media_classifier');
const MAX_PHYSICAL_BYTES=25*1024*1024,MAX_PCM_BYTES=5400*24000*2;
function header(size){const b=Buffer.alloc(44);b.write('RIFF');b.writeUInt32LE(size+36,4);b.write('WAVEfmt ',8);b.writeUInt32LE(16,16);b.writeUInt16LE(1,20);b.writeUInt16LE(1,22);b.writeUInt32LE(24000,24);b.writeUInt32LE(48000,28);b.writeUInt16LE(2,32);b.writeUInt16LE(16,34);b.write('data',36);b.writeUInt32LE(size,40);return b;}
// One bounded physical file is inspected at a time. Whole-session audio is
// streamed through disk; it is never materialized as a Node Buffer.
async function assembleLogicalAudio({storage,segments,maximumMs,ffmpeg=process.env.TRANSCRIPTION_FFMPEG_PATH||'ffmpeg'}){
 const dir=await fsp.mkdtemp(path.join(os.tmpdir(),'medcases-logical-'));await fsp.chmod(dir,0o700);
 const pcm=path.join(dir,'logical.wav');await fsp.writeFile(pcm,Buffer.alloc(44),{mode:0o600});
 let totalDurationMs=0,totalBytes=0,pcmBytes=0;const manifest=[];
 try{
  for(let i=0;i<segments.length;i++){
   const segment=segments[i];if(segment.index!==i)throw Error('PHYSICAL_SEQUENCE_INVALID');
   const input=path.join(dir,'physical-'+i),hash=crypto.createHash('sha256');let size=0;
   const object=await storage.getStream(segment.objectKey);
   const guard=new Transform({transform(chunk,_encoding,done){size+=chunk.length;if(size>MAX_PHYSICAL_BYTES)return done(Error('PHYSICAL_TRANSPORT_TOO_LARGE'));hash.update(chunk);done(null,chunk);}});
   await pipeline(object.body,guard,fs.createWriteStream(input,{mode:0o600}));
   if(hash.digest('hex')!==segment.bodyHash)throw Error('AUDIO_BINDING_INVALID');
   const bytes=await fsp.readFile(input);let classification;
   try{classification=await classifyBinary(bytes);}finally{bytes.fill(0);}
   if(classification.classification!=='SUPPORTED_AUDIO')throw Error('AUDIO_TYPE_INVALID');
   const proof=classification.audioProof;totalDurationMs+=proof.durationMs;totalBytes+=size;
   if(totalDurationMs>maximumMs||totalDurationMs>5400000)throw Error('MEDIA_EXCEEDS_RESERVED_BUDGET');
   manifest.push({index:i,durationMs:proof.durationMs,sha256:proof.sha256,byteLength:size,objectKey:segment.objectKey});
   const child=spawn(ffmpeg,['-nostdin','-v','error','-protocol_whitelist','file,pipe','-i',input,'-map','0:a:0','-vn','-ac','1','-ar','24000','-f','s16le','pipe:1'],{stdio:['ignore','pipe','ignore']});
   const exit=new Promise((resolve,reject)=>{child.once('error',()=>reject(Error('AUDIO_ASSEMBLER_UNAVAILABLE')));child.once('exit',code=>code===0?resolve():reject(Error('AUDIO_ASSEMBLY_FAILED')));});
   const timer=setTimeout(()=>child.kill('SIGKILL'),120000);
   const bound=new Transform({transform(chunk,_encoding,done){pcmBytes+=chunk.length;if(pcmBytes>MAX_PCM_BYTES)return done(Error('LOGICAL_AUDIO_TOO_LONG'));done(null,chunk);}});
   try{await Promise.all([exit,pipeline(child.stdout,bound,fs.createWriteStream(pcm,{flags:'a'}))]);}finally{clearTimeout(timer);child.kill();}
   await fsp.unlink(input);
  }
  if(!pcmBytes||pcmBytes%2)throw Error('LOGICAL_AUDIO_EMPTY');
  const file=await fsp.open(pcm,'r+');try{await file.write(header(pcmBytes),0,44,0);}finally{await file.close();}
  return {path:pcm,byteLength:pcmBytes+44,totalDurationMs,totalBytes,physicalSegments:manifest,cleanup:()=>fsp.rm(dir,{recursive:true,force:true})};
 }catch(error){await fsp.rm(dir,{recursive:true,force:true});throw error;}
}
module.exports={assembleLogicalAudio,header};
