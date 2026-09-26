'use strict';
const {Timestamp} = require('firebase-admin/firestore');
const {SpeakerRoleResolver} = require('./speaker_role_resolver');
const at=()=>Timestamp.now();
const pause=ms=>new Promise(r=>setTimeout(r,ms));
class MedCasesTranscriptionService {
  constructor({providers,roleResolver=new SpeakerRoleResolver()}) {Object.assign(this,{providers,roleResolver});}
  provider(job) {
    const provider=this.providers[job.provider || 'legacy'];
    if (!provider) throw Error('TRANSCRIPTION_PROVIDER_UNAVAILABLE');
    return provider;
  }
  async persist(ref,value) {
    for(let i=0;i<5;i++) {
      try {await ref.set(value,{merge:true});return;} catch(error) {if(i===4)throw error;await pause(200*2**i);}
    }
  }
  async advance({job,ref,readAudio}) {
    if (job.provider!=='assemblyai') throw Error('ASYNC_PROVIDER_REQUIRED');
    const provider=this.provider(job);
    let state=(await ref.get()).data();
    if (state.state==='done') return state;
    const startedAt=state.providerSubmittedAt?.toMillis?.() || state.createdAt?.toMillis?.() || Date.now();
    if (Date.now()-startedAt>8*60*60*1000) {
      await this.persist(ref,{state:'terminal_error',errorCategory:'PROVIDER_DEADLINE_EXCEEDED',retryable:false,updatedAt:at()});
      return (await ref.get()).data();
    }
    if (!state.providerTranscriptId) {
      // Intent survives process death. An unknown POST outcome is never replayed.
      if (state.submissionIntent && state.submissionOutcome!=='not_accepted') {
        await this.persist(ref,{state:'terminal_error',errorCategory:'PROVIDER_SUBMISSION_UNCERTAIN',retryable:false,updatedAt:at()});
        return (await ref.get()).data();
      }
      if (!state.providerAudioUrl) {
        const bytes=await readAudio();
        let url;
        try {url=await provider.upload(bytes);} finally {
          if(Buffer.isBuffer(bytes))bytes.fill(0);else bytes.destroy?.();
        }
        await this.persist(ref,{providerAudioUrl:url,providerUploadCompletedAt:at(),updatedAt:at()});
        state=(await ref.get()).data();
      }
      await this.persist(ref,{submissionIntent:true,submissionOutcome:'unknown',providerCallStart:at(),updatedAt:at()});
      let submitted;
      try {
        submitted=await provider.submit({audioUrl:state.providerAudioUrl,mode:job.mode,
          locale:job.locale,conversation:job.conversation===true,
          ...(Number.isInteger(job.speakersExpected)?{speakersExpected:job.speakersExpected}:{})});
      } catch(error) {
        const knownRejection=Number.isInteger(error.httpStatus)&&error.httpStatus>=400&&error.httpStatus<500;
        await this.persist(ref,{state:knownRejection&&error.retryable?'retryable_error':'terminal_error',
          submissionOutcome:knownRejection?'not_accepted':'unknown',errorCategory:error.code || 'PROVIDER_SUBMISSION_UNCERTAIN',
          retryable:knownRejection&&error.retryable===true,updatedAt:at()});
        return (await ref.get()).data();
      }
      await this.persist(ref,{providerTranscriptId:submitted.providerTranscriptId,provider:'assemblyai',
        submissionOutcome:'accepted',state:'submitted',providerSubmittedAt:at(),lastProgressAt:at(),updatedAt:at()});
      return (await ref.get()).data();
    }
    let result;
    try {result=await provider.poll(state.providerTranscriptId);} catch(error) {
      // Transient polling failures keep the SAME provider ID and remain recoverable.
      await this.persist(ref,{state:error.retryable?'processing':'terminal_error',
        errorCategory:error.code || 'PROVIDER_STATUS_FAILED',retryable:error.retryable===true,updatedAt:at()});
      return (await ref.get()).data();
    }
    if (result.status==='error') {
      await this.persist(ref,{state:'terminal_error',errorCategory:'ASSEMBLYAI_TRANSCRIPTION_ERROR',retryable:false,updatedAt:at()});
    } else if (result.status!=='completed') {
      await this.persist(ref,{state:result.status==='queued'?'submitted':'processing',updatedAt:at(),
        ...(state.providerStatus!==result.status?{lastProgressAt:at()} : {}),providerStatus:result.status});
    } else {
      // Raw utterances are independent of display aliases/semantic roles.
      const utterances=result.utterances || [];
      const roleMap=await this.roleResolver.resolve({mode:job.mode,utterances});
      let page=[],size=0,pageCount=0;
      const save=async()=>{await ref.collection('utterances').doc(String(pageCount++)).set({items:page});page=[];size=0;};
      for (const utterance of utterances) {
        const bytes=Buffer.byteLength(JSON.stringify(utterance));
        if (bytes>400000) throw Error('PROVIDER_UTTERANCE_TOO_LARGE');
        if (size+bytes>400000) await save();
        page.push(utterance);size+=bytes;
      }
      if(page.length)await save();
      let wordPages=0,wordPage=[],wordSize=0;
      for(const word of result.words||[]){
        const bytes=Buffer.byteLength(JSON.stringify(word));
        if(bytes>400000)throw Error('PROVIDER_WORD_TOO_LARGE');
        if(wordSize+bytes>400000){await ref.collection('words').doc(String(wordPages++)).set({items:wordPage});wordPage=[];wordSize=0;}
        wordPage.push(word);wordSize+=bytes;
      }
      if(wordPage.length)await ref.collection('words').doc(String(wordPages++)).set({items:wordPage});
      if(Buffer.byteLength(result.text)>700000)throw Error('TRANSCRIPT_REQUIRES_PAGINATION');
      // Result and completed state are committed together, after all utterance pages.
      await this.persist(ref,{transcript:result.text,rawTranscript:result.text,utterancePages:pageCount,
        utteranceCount:utterances.length,wordPages,speakerRoleMap:roleMap,speakerAliases:{},
        state:'done',canonicalState:'completed',completedAt:at(),updatedAt:at(),lastProgressAt:at(),
        providerStatus:'completed',resultPersistedAt:at(),retryable:false,errorCategory:null,leaseUntil:null});
    }
    return (await ref.get()).data();
  }
}
module.exports={MedCasesTranscriptionService};
