'use strict';
const crypto=require('node:crypto');
const {usageReceipt}=require('./usage_reservation_guard');
const hash=x=>crypto.createHash('sha256').update(x).digest('hex');
async function assertNewLogicalPipeline(tx,db,usage,count){
 const receipt=usageReceipt(usage);
 const prior=await Promise.all(Array.from({length:count},(_,index)=>tx.get(db.collection('usageExecutions').doc(hash(`${receipt.id}:${receipt.attempt}:${index}`)))));
 if(prior.some(s=>s.exists))throw Error('TRANSCRIPTION_PIPELINE_CONFLICT');
}
module.exports={assertNewLogicalPipeline};
