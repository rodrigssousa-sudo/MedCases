'use strict';
const {structure}=require('../audio_media_structure');
function adts(bytes){const s=structure(bytes,{longRecording:true});const index=[96000,88200,64000,48000,44100,32000,24000,22050,16000,12000,11025,8000,7350].indexOf(s.rate);return Buffer.concat(s.frames.map(([off,len])=>{const n=len+7;const h=Buffer.from([255,241,64|(index<<2)|(s.channels>>2),((s.channels&3)<<6)|(n>>11),(n>>3)&255,((n&7)<<5)|31,252]);return Buffer.concat([h,bytes.subarray(off,off+len)]);}));}
module.exports={adts};
