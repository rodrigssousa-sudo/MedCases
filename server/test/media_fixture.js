'use strict';
const {inspectAudio,combineProofs,digest}=require('../audio_media_budget');
function wav(ms=4000){const rate=8000,n=ms*rate/1000,b=Buffer.alloc(44+n*2);b.write('RIFF');b.writeUInt32LE(b.length-8,4);b.write('WAVEfmt ',8);b.writeUInt32LE(16,16);b.writeUInt16LE(1,20);b.writeUInt16LE(1,22);b.writeUInt32LE(rate,24);b.writeUInt32LE(rate*2,28);b.writeUInt16LE(2,32);b.writeUInt16LE(16,34);b.write('data',36);b.writeUInt32LE(n*2,40);return b;}
async function proof(ms=4000,key='TECHNICAL_REQUEST'){return combineProofs([await inspectAudio(wav(ms))],digest(Buffer.from(key)));}
const {database}=require('./transaction_fixture');
module.exports={wav,proof,database};
