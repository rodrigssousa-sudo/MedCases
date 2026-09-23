'use strict';
const MAX_DISCOVERY_BYTES = 25 * 1024 * 1024;
const MAX_TOP_LEVEL_BOXES = 256;
const MAX_PARSE_OPERATIONS = 2048;
const BRANDS = new Set(['M4A ', 'isom', 'iso2', 'mp41', 'mp42']);
function invalid() { throw Error('INVALID_BINARY_STRUCTURE'); }
function scanMp4(bytes) {
  if (!Buffer.isBuffer(bytes) || !bytes.length || bytes.length > MAX_DISCOVERY_BYTES) invalid();
  const boxes = []; let offset = 0, operations = 0;
  while (offset < bytes.length) {
    if (++operations > MAX_PARSE_OPERATIONS || boxes.length >= MAX_TOP_LEVEL_BOXES || offset + 8 > bytes.length) invalid();
    let size = bytes.readUInt32BE(offset), header = 8;
    const type = bytes.toString('latin1', offset + 4, offset + 8);
    if (!/^[\x20-\x7e]{4}$/.test(type)) invalid();
    if (size === 1) {
      if (offset + 16 > bytes.length) invalid();
      const extended = bytes.readBigUInt64BE(offset + 8);
      if (extended > BigInt(MAX_DISCOVERY_BYTES)) invalid();
      size = Number(extended); header = 16;
    } else if (size === 0) {
      // Only a terminal mdat extending to EOF is accepted in this subset.
      if (type !== 'mdat') invalid();
      size = bytes.length - offset;
    }
    if (size < header || size > bytes.length - offset) invalid();
    boxes.push({type, start: offset, body: offset + header, end: offset + size});
    offset += size;
  }
  const ftyp = boxes.filter(b => b.type === 'ftyp');
  if (ftyp.length > 1) throw Error('AMBIGUOUS_CONTAINER');
  if (ftyp.length !== 1 || boxes.filter(b => b.type === 'moov').length !== 1 || !boxes.some(b => b.type === 'mdat')) invalid();
  const f = ftyp[0];
  if (f.end - f.body < 8 || (f.end - f.body) % 4) invalid();
  let supported = BRANDS.has(bytes.toString('latin1', f.body, f.body + 4));
  for (let p = f.body + 8; p < f.end; p += 4) {
    if (++operations > MAX_PARSE_OPERATIONS) invalid();
    supported ||= BRANDS.has(bytes.toString('latin1', p, p + 4));
  }
  if (!supported) throw Error('UNSUPPORTED_CONTAINER_BRAND');
  // Unknown well-framed top-level boxes are skipped, never string-searched.
  // Their presence grants no codec authority; the audio inspector must pass.
  return boxes;
}
module.exports = {scanMp4, MAX_DISCOVERY_BYTES, MAX_TOP_LEVEL_BOXES, MAX_PARSE_OPERATIONS};
