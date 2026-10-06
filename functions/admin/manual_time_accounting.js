'use strict';
// Pure accounting policy. Transaction owners must atomically persist the returned
// patches alongside the reservation and immutable ledger entries.
function validCredit(c) {
  for (const key of ['amountSeconds', 'remainingSeconds', 'reservedSeconds']) {
    if (!Number.isSafeInteger(c[key]) || c[key] < 0) throw Error('CORRUPT_CREDIT');
  }
  if (c.remainingSeconds > c.amountSeconds || c.reservedSeconds > c.remainingSeconds) throw Error('CORRUPT_CREDIT');
  if (c.expiresAt != null && !Number.isSafeInteger(c.expiresAt)) throw Error('CORRUPT_CREDIT');
}
function available(c, now) {
  validCredit(c);
  return c.status === 'ACTIVE' && (c.expiresAt == null || c.expiresAt > now)
    ? c.remainingSeconds - c.reservedSeconds : 0;
}
function allocate(credits, seconds, now) {
  if (!Number.isSafeInteger(seconds) || seconds < 0) throw Error('INVALID_TIME');
  const ids = new Set();
  for (const c of credits) {
    validCredit(c);
    if (typeof c.id !== 'string' || !c.id || ids.has(c.id)) throw Error('INVALID_CREDIT_ID');
    ids.add(c.id);
  }
  const ordered = [...credits].sort((a,b) => (a.expiresAt ?? Number.MAX_SAFE_INTEGER) - (b.expiresAt ?? Number.MAX_SAFE_INTEGER) || a.id.localeCompare(b.id));
  let remaining = seconds;
  const allocations = [];
  for (const c of ordered) {
    const take = Math.min(remaining, available(c,now));
    if (take) allocations.push({creditId:c.id, seconds:take, reservedSeconds:c.reservedSeconds+take});
    remaining -= take;
  }
  if (remaining) throw Error('INSUFFICIENT_MANUAL_TIME');
  return allocations;
}
function settle(c, reserved, consumed, now) {
  validCredit(c);
  if (!Number.isSafeInteger(reserved) || reserved < 0 || reserved > c.reservedSeconds || !Number.isSafeInteger(consumed) || consumed < 0 || consumed > reserved) throw Error('INVALID_SETTLEMENT');
  const released = reserved-consumed;
  const inactive = c.status !== 'ACTIVE' || (c.expiresAt != null && c.expiresAt <= now);
  const forfeited = inactive ? released : 0;
  return {remainingSeconds:c.remainingSeconds-consumed-forfeited,
    reservedSeconds:c.reservedSeconds-reserved, consumedSeconds:consumed,
    releasedSeconds:released-forfeited, forfeitedSeconds:forfeited};
}
function expire(c, now) {
  validCredit(c);
  if (c.status !== 'ACTIVE' || c.expiresAt == null || c.expiresAt > now) return null;
  return {remainingSeconds:c.reservedSeconds, reservedSeconds:c.reservedSeconds,
    expiredSeconds:c.remainingSeconds-c.reservedSeconds,
    status:c.reservedSeconds ? 'EXPIRED_RESERVED' : 'EXPIRED'};
}
module.exports={available,allocate,settle,expire};
