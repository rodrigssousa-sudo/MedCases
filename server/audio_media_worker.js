'use strict';
const {parentPort,workerData}=require('node:worker_threads');
const {structure}=require('./audio_media_structure');
// The pinned decoder embeds WASM; there is no fetch or user-selected file path.
// Bound WASM growth in addition to the worker's V8 heap/stack limits. The exact
// pinned WASM uses the JS grow import; package upgrades require renewed review.
const grow=WebAssembly.Memory.prototype.grow;
WebAssembly.Memory.prototype.grow=function(pages){if(!Number.isSafeInteger(pages)||pages<0||this.buffer.byteLength+pages*65536>64*1024*1024)throw Error('MEDIA_MEMORY_LIMIT');return grow.call(this,pages);};
globalThis.fetch=()=>{throw Error('MEDIA_NETWORK_FORBIDDEN');};
(async()=>{const bytes=Buffer.from(workerData),s=structure(bytes);if(s.kind==='wav'){parentPort.postMessage({durationMs:s.durationMs});return;}
 const {decoder}=await import('@audio/decode-aac');const dec=await decoder({asc:s.asc});
 try{let samples=0,hasOutput=false;for(const [off,len]of s.frames){const result=dec.decode(bytes.subarray(off,off+len));if(dec.m._aac_error()!==0||dec.m._aac_consumed()!==len||result.errors||!result.channelData||result.channelData.length>s.channels)throw Error('MEDIA_DECODE_INVALID');const n=result.channelData[0]?.length||0;
  // AAC priming can yield no output for the initial access unit; reserve its
  // full frame conservatively. Other discarded/corrupt frames are rejected.
  if(!n&&samples!==0||n>1024||n&&result.sampleRate!==s.rate||result.channelData.some(x=>x.length!==n))throw Error('MEDIA_DECODE_INVALID');hasOutput ||= n>0;samples+=Math.max(n,1024);
 }if(!hasOutput)throw Error('MEDIA_DECODE_INVALID');parentPort.postMessage({durationMs:Math.ceil(samples/s.rate*1000)});
 }finally{dec.free();bytes.fill(0);}
})().catch(()=>parentPort.postMessage({error:'MEDIA_INVALID_OR_UNSUPPORTED'}));
