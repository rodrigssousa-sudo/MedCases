'use strict';

const {isIP} = require('node:net');

// express-rate-limit 7.x has no ipKeyGenerator export. Use Node's strict IP
// validation and WHATWG IPv6 serialization without changing dependencies.
function normalizeIp(value) {
  if (typeof value !== 'string' || value.length === 0 || value.length > 45 ||
      value.trim() !== value || /[\s,%]/.test(value)) return null;
  const family = isIP(value);
  if (family === 4) return value;
  if (family !== 6) return null;
  const canonical = new URL(`http://[${value}]/`).hostname.slice(1, -1);
  // Collapse mapped IPv4 and native IPv4 into one identity/key.
  const mapped = /^::ffff:([\da-f]+):([\da-f]+)$/.exec(canonical);
  if (mapped) {
    const high = parseInt(mapped[1], 16), low = parseInt(mapped[2], 16);
    return [high >>> 8, high & 255, low >>> 8, low & 255].join('.');
  }
  return canonical;
}

function isPrivateProxy(peer) {
  if (!peer) return false;
  if (isIP(peer) === 4) {
    const [a, b] = peer.split('.').map(Number);
    // The isolated App Platform canary also observed RFC6598 shared ingress.
    return (a === 100 && b >= 64 && b <= 127) || a === 10 || (a === 172 && b >= 16 && b <= 31) ||
      (a === 192 && b === 168);
  }
  return /^f[cd][\da-f]{2}:/.test(peer);
}

function resolveRateLimitClientKey(req) {
  const peer = normalizeIp(req?.socket?.remoteAddress);
  const local = normalizeIp(req?.socket?.localAddress);
  // do-connecting-ip é confiável somente na fronteira de ingresso da
  // DigitalOcean App Platform. A private peer is a deployment boundary, not
  // header authentication: untrusted internal callers must not reach this path.
  // Loopback, self-addressed internal traffic and other peers use the socket.
  if (isPrivateProxy(peer) && peer !== local) {
    const raw = req?.rawHeaders;
    let count = 0;
    if (Array.isArray(raw)) {
      for (let i = 0; i < raw.length; i += 2) {
        if (typeof raw[i] === 'string' && raw[i].toLowerCase() === 'do-connecting-ip') count++;
      }
    }
    const client = count > 1 ? null : normalizeIp(req?.headers?.['do-connecting-ip']);
    if (client) return client;
  }
  // Malformed/missing socket data shares a bounded fallback, never an
  // attacker-controlled header. This does not modify req.ip or trust proxy.
  return peer || 'unresolved-socket';
}

module.exports = {resolveRateLimitClientKey};
