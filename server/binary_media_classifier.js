'use strict';
const crypto = require('node:crypto');
const zlib = require('node:zlib');
const {inspectAudio, storedProof, MAX_BYTES} = require('./audio_media_budget');
const {scanMp4} = require('./iso_bmff_boxes');
const certificates = new WeakSet();
const MAX_PIXELS = 16000000, MAX_IMAGE_CHUNKS = 4096;
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
function deny() { throw Error('INVALID_OR_UNSUPPORTED_BINARY'); }
function dimensions(w, h) { if (!w || !h || w * h > MAX_PIXELS) deny(); }
function crc32(bytes) {
  let c = 0xffffffff;
  for (const byte of bytes) { c ^= byte; for (let i = 0; i < 8; i++) c = (c >>> 1) ^ ((c & 1) ? 0xedb88320 : 0); }
  return (c ^ 0xffffffff) >>> 0;
}
function png(b) {
  let p = 8, chunks = 0, header = false, end = false, compressed = [], rowBytes = 0, height = 0;
  while (p < b.length) {
    if (++chunks > MAX_IMAGE_CHUNKS || p + 12 > b.length) deny();
    const n = b.readUInt32BE(p), t = b.toString('ascii', p + 4, p + 8), z = p + 12 + n;
    if (z > b.length || crc32(b.subarray(p + 4, z - 4)) !== b.readUInt32BE(z - 4)) deny();
    if (!header) {
      if (t !== 'IHDR' || n !== 13) deny();
      const w = b.readUInt32BE(p + 8); height = b.readUInt32BE(p + 12); dimensions(w, height);
      const bits = b[p + 16], type = b[p + 17], channels = {0:1,2:3,3:1,4:2,6:4}[type];
      if (!channels || ![1,2,4,8,16].includes(bits) || (type !== 0 && type !== 3 && bits < 8) || (type === 3 && bits === 16) || b[p+18] || b[p+19] || b[p+20]) deny();
      rowBytes = Math.ceil(w * channels * bits / 8); header = true;
    } else if (t === 'IHDR') deny();
    if (t === 'IDAT') compressed.push(b.subarray(p + 8, z - 4));
    if (t === 'IEND') { if (n || z !== b.length) deny(); end = true; }
    if (['acTL','fcTL','fdAT'].includes(t)) deny(); // no animation amplification
    p = z;
  }
  const expected = (rowBytes + 1) * height;
  if (!end || !compressed.length || expected > 64 * 1024 * 1024) deny();
  const raw = zlib.inflateSync(Buffer.concat(compressed), {maxOutputLength: expected + 1});
  if (raw.length !== expected) deny();
  for (let p = 0; p < raw.length; p += rowBytes + 1) if (raw[p] > 4) deny();
}
function jpeg(b) {
  let p = 2, operations = 0, frame = false, scan = false;
  while (p < b.length) {
    if (++operations > MAX_IMAGE_CHUNKS || b[p++] !== 255) deny();
    while (p < b.length && b[p] === 255) p++;
    const marker = b[p++];
    if (marker === 0xd9) { if (!frame || !scan || p !== b.length) deny(); return; }
    if (!marker || marker === 0xd8 || p + 2 > b.length) deny();
    const n = b.readUInt16BE(p); if (n < 2 || p + n > b.length) deny();
    if ([0xc0,0xc1,0xc2].includes(marker)) { if (frame || n < 8) deny(); dimensions(b.readUInt16BE(p+5), b.readUInt16BE(p+3)); if (b[p+2]!==8 || n!==8+3*b[p+7]) deny(); frame = true; }
    p += n;
    if (marker === 0xda) {
      if (!frame) deny(); scan = true;
      // Entropy bytes are bounded by input size; stuffed FF and restart markers
      // cannot be mistaken for container boundaries.
      while (p < b.length) { if (b[p] !== 255) { p++; continue; } const next=b[p+1]; if (next===0 || next>=0xd0&&next<=0xd7) { p+=2; continue; } break; }
    }
  }
  deny();
}
function webp(b) {
  if (b.length < 20 || b.readUInt32LE(4) + 8 !== b.length) deny();
  let p=12, count=0, image=false;
  while(p<b.length) {
    if (++count>MAX_IMAGE_CHUNKS || p+8>b.length) deny();
    const t=b.toString('ascii',p,p+4),n=b.readUInt32LE(p+4),a=p+8,z=a+n;
    if(z>b.length)deny();
    if(t==='VP8 '){if(image||n<10||!(b[a] % 2===0)||b.toString('hex',a+3,a+6)!=='9d012a')deny();dimensions(b.readUInt16LE(a+6)&16383,b.readUInt16LE(a+8)&16383);image=true;}
    else if(t==='VP8L'){if(image||n<5||b[a]!==0x2f)deny();const bits=b.readUInt32LE(a+1);if(bits>>>29)deny();dimensions((bits&16383)+1,((bits>>>14)&16383)+1);image=true;}
    else if(t==='VP8X'){if(p!==12||n!==10||(b[a]&2))deny();dimensions(b.readUIntLE(a+4,3)+1,b.readUIntLE(a+7,3)+1);}
    else if(!['ALPH','ICCP','EXIF','XMP '].includes(t))deny();
    p=z+(n%2);if(p>b.length)deny();
  }
  if(!image)deny();
}
function pdf(b) {
  // Bounded document framing. PDF is sent under server-selected application/pdf,
  // never as audio; attachments, rich media and executable actions are excluded.
  const text=b.toString('latin1');
  if(!/^%PDF-(1\.[0-7]|2\.0)[\r\n]/.test(text))deny();
  const end=/startxref\s+(\d+)\s+%%EOF\s*$/.exec(text);
  if(!end)deny();const offset=Number(end[1]);
  if(!Number.isSafeInteger(offset)||offset<8||offset>=end.index)deny();
  const at=text.slice(offset,offset+100);
  if(/^xref[\r\n\s]/.test(at)) {
    // Conventional xref/trailer must account for the entire tail, not merely
    // precede an arbitrary appended binary and a forged final EOF marker.
    let cursor=offset+4, entries=0;
    const space=()=>{while(cursor<end.index&&/[\t\r\n \f]/.test(text[cursor]))cursor++;};
    space();
    while(!text.startsWith('trailer',cursor)) {
      const header=/^(\d{1,10})\s+(\d{1,10})[\r\n ]+/.exec(text.slice(cursor,cursor+32));
      if(!header)deny();cursor+=header[0].length;
      const first=Number(header[1]),count=Number(header[2]);
      if(!count||(entries+=count)>100000)deny();
      for(let i=0;i<count;i++) {
        const entry=/^(\d{10}) (\d{5}) ([nf])[ \r\n]+/.exec(text.slice(cursor,cursor+24));
        if(!entry)deny();cursor+=entry[0].length;
        if(entry[3]==='n') {
          const at=Number(entry[1]);if(at<=0||at>=offset)deny();
          const object=new RegExp('^'+(first+i)+'\\s+'+Number(entry[2])+'\\s+obj\\b');
          if(!object.test(text.slice(at,at+40)))deny();
        }
      }
      space();
    }
    const tail=text.slice(cursor+7,end.index).trim();
    if(tail.length>65536||!tail.startsWith('<<')||!tail.endsWith('>>'))deny();
    // A trailer has only names, numbers, references and hex-string ID arrays.
    // Unsupported literal/nested dictionaries are denied instead of guessed.
    const tokens=tail.slice(2,-2).match(/\/[A-Za-z][A-Za-z0-9]*|\d+|R|\[|\]|<[a-fA-F0-9\s]*>|\s+/g)||[];
    if(tokens.join('')!==tail.slice(2,-2)||!/\/Root\s+\d+\s+\d+\s+R\b/.test(tail))deny();
  } else {
    // Xref-stream PDFs need a stream-aware document parser. Never grant a
    // classification from a lone obj/header signature.
    deny();
  }
  const names=text.replace(/#([a-f\d]{2})/gi,(_,v)=>String.fromCharCode(parseInt(v,16)));
  if(/\/(EmbeddedFile|Filespec|RichMedia|Sound|Movie|Launch|JavaScript|JS|OpenAction|AA|Encrypt)\b/.test(names))deny();
}
async function classifyValidated(input) {
  if(!Buffer.isBuffer(input)||!input.length||input.length>MAX_BYTES)deny();
  const b=Buffer.from(input); let classification, mimeType, audioProof;
  if(b.toString('ascii',0,4)==='RIFF'&&b.toString('ascii',8,12)==='WAVE') {
    audioProof=await inspectAudio(b); classification='SUPPORTED_AUDIO';mimeType='audio/wav';
  } else if(b.subarray(0,8).equals(Buffer.from('89504e470d0a1a0a','hex'))) {
    png(b);classification='SUPPORTED_IMAGE';mimeType='image/png';
  } else if(b[0]===255&&b[1]===216) {
    jpeg(b);classification='SUPPORTED_IMAGE';mimeType='image/jpeg';
  } else if(b.toString('ascii',0,4)==='RIFF'&&b.toString('ascii',8,12)==='WEBP') {
    webp(b);classification='SUPPORTED_IMAGE';mimeType='image/webp';
  } else if(b.toString('ascii',0,5)==='%PDF-') {
    pdf(b);classification='OTHER_SUPPORTED_TYPE';mimeType='application/pdf';
  } else {
    scanMp4(b);audioProof=await inspectAudio(b);classification='SUPPORTED_AUDIO';mimeType='audio/mp4';
  }
  const proof=Object.freeze({version:1,classification,mimeType,sha256:hash(b),...(audioProof?{durationMs:audioProof.durationMs,audioProof}:{})});
  certificates.add(proof);return proof;
}
async function classifyBinary(input) {
  try { return await classifyValidated(input); } catch(error) {
    const classification=String(error.message).startsWith('UNSUPPORTED')?'UNSUPPORTED':String(error.message).startsWith('AMBIGUOUS')?'AMBIGUOUS':'INVALID';
    throw Object.assign(Error('BINARY_'+classification),{classification});
  }
}
function assertBinaryBinding(proof,bytes) { if(!certificates.has(proof)||hash(bytes)!==proof.sha256)throw Error('MEDIA_HASH_BINDING_MISMATCH'); }
function serializeClassification(p) {if(!certificates.has(p))deny();const {audioProof,...stored}=p;return stored;}
function readStoredClassification(v) {
  if(!v||v.version!==1||! /^[a-f0-9]{64}$/.test(v.sha256))deny();
  const valid={SUPPORTED_AUDIO:['audio/wav','audio/mp4'],SUPPORTED_IMAGE:['image/png','image/jpeg','image/webp'],OTHER_SUPPORTED_TYPE:['application/pdf']};
  if(!valid[v.classification]?.includes(v.mimeType))deny();
  const proof=Object.freeze({...v,...(v.classification==='SUPPORTED_AUDIO'?{audioProof:storedProof(v)}:{})});certificates.add(proof);return proof;
}
module.exports={classifyBinary,assertBinaryBinding,serializeClassification,readStoredClassification,MAX_PIXELS};
