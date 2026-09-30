'use strict';
const express=require('express');
const {TranscriptionAttemptLedger}=require('./transcription_attempt_ledger');
function registerTranscriptionAttemptRoutes(app,{authenticate,getDb}){
 // Independent from provider eligibility: pre-job failures must remain visible.
 const handle=action=>async(req,res)=>{
  try{const uid=await authenticate(req),ledger=new TranscriptionAttemptLedger({db:getDb()});
   const result=action==='create'?await ledger.create(uid,req.body):await ledger.advance(uid,req.params.attemptId,req.body,{origin:'client'});
   res.status(200).json(result);
  }catch(e){const code=String(e.message||'');const input=/^INVALID_ATTEMPT_|^CLIENT_STATE_FORBIDDEN$/.test(code);const denied=/AUTH|OWNED|BINDING|identity|auth\//i.test(code);res.status(input?400:denied?403:503).json({error:input?'INVALID_ATTEMPT_REQUEST':denied?'ATTEMPT_NOT_AUTHORIZED':'ATTEMPT_PERSISTENCE_UNAVAILABLE'});}
 };
 app.post('/api/ai/transcription/attempts',express.json({limit:'4kb'}),handle('create'));
 app.post('/api/ai/transcription/attempts/:attemptId/events',express.json({limit:'4kb'}),handle('event'));
}
module.exports={registerTranscriptionAttemptRoutes};
