'use strict';
const fs = require('node:fs/promises');
const path = require('node:path');
const {resolveMedCasesTier} = require('./calculator_entitlement_session');

// Read-only publication transport. No upload or implicit content publication.
function registerClinicalContentRoutes({app,authenticate,limiter,db,root=process.env.MEDCASES_CLINICAL_CONTENT_ROOT}) {
  app.get('/api/clinical-content/*',authenticate,limiter,async(req,res)=>{
    res.setHeader('Cache-Control','private, no-store');
    const uid=req.auth?.uid;
    if(!uid)return res.status(401).json({error:'AUTH_REQUIRED'});
    try {
      const doc=await db.collection('users').doc(uid).get();
      if(!doc.exists||resolveMedCasesTier(doc.data()).tier!=='premium')return res.status(403).json({error:'ENTITLEMENT_REQUIRED'});
      const relative=req.params[0];
      if(typeof relative!=='string'||!(/^(manifest\.json|snapshots\/[0-9]+\/[A-Za-z]+\/(index|[a-f0-9]{64})\.json)$/).test(relative))return res.status(400).json({error:'INVALID_PATH'});
      if(!root)return res.status(503).json({error:'NOT_CONFIGURED'});
      const base=await fs.realpath(root),file=await fs.realpath(path.join(base,relative));
      if(!file.startsWith(base+path.sep))return res.status(400).json({error:'INVALID_PATH'});
      const stat=await fs.stat(file);if(!stat.isFile()||stat.size>8*1024*1024)return res.status(413).json({error:'PAYLOAD_LIMIT'});
      const bytes=await fs.readFile(file);JSON.parse(bytes.toString('utf8'));
      return res.type('application/json').send(bytes);
    }catch(_){return res.status(503).json({error:'CONTENT_UNAVAILABLE'});}
  });
}
module.exports={registerClinicalContentRoutes};
