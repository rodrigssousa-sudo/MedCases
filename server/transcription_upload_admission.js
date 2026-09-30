'use strict';
// Reserve bounded memory only after authentication and immutable job validation.
function uploadAdmission({authorize, maxConcurrent = 2}) {
  let active = 0;
  const jobs = new Set();
  return async (req, res, next) => {
    let identity;
    try { identity = await authorize(req); }
    catch (_) { return res.status(403).json({error:'study_authorization_failed',retryable:false}); }
    if (active >= maxConcurrent || jobs.has(identity)) {
      res.setHeader('Retry-After','5');
      return res.status(429).json({error:'UPLOAD_BUSY',retryable:true});
    }
    active++;
    jobs.add(identity);
    let released = false;
    const release = () => {
      if (released) return;
      released = true;
      active--;
      jobs.delete(identity);
    };
    res.once('finish',release);
    res.once('close',release);
    req.once('aborted',release);
    next();
  };
}
module.exports={uploadAdmission};
