'use strict';
const {createClinicalContentRepository, ContentRepositoryError, validateLogicalPath, MAX_BYTES} = require('./clinical_content_repository');
const {resolveMedCasesTier} = require('./calculator_entitlement_session');

// Read-only publication transport. No upload or implicit content publication.
function registerClinicalContentRoutes({app,authenticate,limiter,db,root=process.env.MEDCASES_CLINICAL_CONTENT_ROOT, repository=createClinicalContentRepository({...process.env, MEDCASES_CLINICAL_CONTENT_ROOT: root})}) {
  app.get('/api/clinical-content/*',authenticate,limiter,async(req,res)=>{
    res.setHeader('Cache-Control','private, no-store');
    const uid=req.auth?.uid;
    if(!uid)return res.status(401).json({error:'AUTH_REQUIRED'});
    try {
      const doc=await db.collection('users').doc(uid).get();
      if(!doc.exists||resolveMedCasesTier(doc.data()).tier!=='premium')return res.status(403).json({error:'ENTITLEMENT_REQUIRED'});
      const relative=req.params[0];
      validateLogicalPath(relative);
      const controller = new AbortController();
      const cancel = () => controller.abort();
      res.once?.('close', cancel);
      let bytes;
      try { bytes = await repository.readObject(relative, {signal: controller.signal}); }
      finally { res.removeListener?.('close', cancel); }
      if (!Buffer.isBuffer(bytes)) throw new ContentRepositoryError();
      if (bytes.length > MAX_BYTES) throw new ContentRepositoryError('PAYLOAD_LIMIT');
      JSON.parse(bytes.toString('utf8'));
      return res.type('application/json').send(bytes);
    }catch(error){
      const codes = {INVALID_PATH: 400, PAYLOAD_LIMIT: 413, NOT_CONFIGURED: 500};
      const code = error instanceof ContentRepositoryError && Object.hasOwn(codes, error.code)
        ? error.code : 'CONTENT_UNAVAILABLE';
      return res.status(codes[code] || 500).json({error: code});
    }
  });
}
module.exports={registerClinicalContentRoutes};
