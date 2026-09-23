'use strict';

// Profile notifications accept one simple mailbox, never RFC groups/lists or
// display names. Bound the raw value before trim/regex to bound parser work.
function singleProfileEmail(value) {
  if (typeof value !== 'string' || value.length > 320 || /[\x00-\x1f\x7f]/.test(value)) return null;
  const email = value.trim();
  if (email.length > 254) return null;
  const parts = email.split('@');
  if (parts.length !== 2) return null;
  const [local, domain] = parts;
  if (!local || local.length > 64 || local.startsWith('.') || local.endsWith('.') || local.includes('..')) return null;
  if (!/^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+$/.test(local)) return null;
  const labels = domain.split('.');
  if (labels.length < 2 || labels.some(label => !/^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?$/.test(label))) return null;
  return email;
}

module.exports = { singleProfileEmail };
