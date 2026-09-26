'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {AssemblyAiProvider}=require('./assemblyai_provider');
const {profileOptions,selectedProvider}=require('./transcription_profiles');
const {SpeakerRoleResolver,displayUtterances}=require('./speaker_role_resolver');
const {MedCasesTranscriptionService}=require('./medcases_transcription_service');
test('Spanish clinical medical-v1; Portuguese/mixed never medical-v1',()=>{
 assert.equal(profileOptions({mode:'consultation',locale:'es'}).domain,'medical-v1');
 for(const locale of ['pt','mixed'])assert.equal(profileOptions({mode:'consultation',locale}).domain,undefined);
});
test('lecture/consultation diarize without fixed count; single-speaker defaults lighter',()=>{
 for(const mode of ['lecture','consultation']){const r=profileOptions({mode});assert.equal(r.speaker_labels,true);assert.equal(r.speakers_expected,undefined);}
 for(const mode of ['studyRecording','quickSummary','generalDictation'])assert.equal(profileOptions({mode}).speaker_labels,false);
 assert.equal(profileOptions({mode:'clinicalHistory',conversation:true}).speaker_labels,true);
});
test('provider sends current plural model contract; never exposes API key in request body',async()=>{
 let request;const provider=new AssemblyAiProvider({apiKey:'test-only',fetchImpl:async(url,init)=>{request={url,init};return {ok:true,json:async()=>({id:'synthetic-id',status:'queued'})};}});
 await provider.submit({audioUrl:'https://synthetic.example.test/audio',mode:'lecture',locale:'pt'});
 const body=JSON.parse(request.init.body);assert.deepEqual(body.speech_models,['universal-3-5-pro']);assert.equal(body.speaker_labels,true);
 assert.equal(request.init.headers.authorization,'test-only');assert(!request.init.body.includes('test-only'));
});
test('flag disabled preserves legacy; unknown PHI blocks even with flag enabled',()=>{
 assert.equal(selectedProvider({},'owner'),'legacy');
 assert.throws(()=>selectedProvider({ASSEMBLYAI_TRANSCRIPTION_ENABLED:'true',ASSEMBLYAI_API_KEY:'test'},'owner'),/PHI_PRODUCTION_BLOCKED/);
 assert.equal(selectedProvider({ASSEMBLYAI_TRANSCRIPTION_ENABLED:'true',ASSEMBLYAI_API_KEY:'test',ASSEMBLYAI_SYNTHETIC_OWNER_UIDS:'owner'},'owner'),'assemblyai');
});
test('raw utterances ordered and timestamps retained; mismatched provider ID rejected',async()=>{
 const provider=new AssemblyAiProvider({apiKey:'test',fetchImpl:async()=>({ok:true,json:async()=>({id:'id',status:'completed',text:'Hello world',utterances:[{speaker:'B',start:200,end:300,text:'world'},{speaker:'A',start:0,end:100,text:'Hello'}]})})});
 const r=await provider.poll('id');assert.deepEqual(r.utterances.map(v=>v.speakerLabel),['A','B']);assert.equal(r.utterances[1].endMs,300);
 await assert.rejects(provider.poll('different'),/ID_MISMATCH/);
});
test('role resolution stays neutral without evidence; display alias never changes raw speaker',async()=>{
 const raw=[{speakerLabel:'A',startMs:0,endMs:100,text:'Hello'}];
 assert.deepEqual(await new SpeakerRoleResolver().resolve({mode:'consultation',utterances:raw}),{});
 const low=new SpeakerRoleResolver(async()=>[{speakerLabel:'A',role:'doctor',confidence:0.4,evidenceUtteranceIndices:[0]}]);
 assert.deepEqual(await low.resolve({mode:'consultation',utterances:raw}),{});
 assert.equal(displayUtterances(raw,{aliases:{A:'Professor'}})[0].displayLabel,'Professor');assert.equal(raw[0].speakerLabel,'A');
});
function memoryRef(initial) {
 let state={...initial};const pages={};return {pages,async get(){return {data:()=>state};},async set(v){state={...state,...v};},collection(){return {doc:id=>({async set(v){pages[id]=v;}})};}};
}
test('durable provider ID survives service recreation and polls without resubmission',async()=>{
 let uploads=0,submits=0,polls=0;
 const provider={async upload(){uploads++;return 'https://synthetic.test/file';},async submit(){submits++;return {providerTranscriptId:'id'};},async poll(){polls++;return {status:'completed',text:'Hello',utterances:[{speakerLabel:'A',startMs:0,endMs:100,text:'Hello'}]};}};
 const ref=memoryRef({state:'queued'}),job={provider:'assemblyai',mode:'lecture',locale:'pt'};
 await new MedCasesTranscriptionService({providers:{assemblyai:provider}}).advance({job,ref,readAudio:async()=>Buffer.from('synthetic')});
 assert.equal((await ref.get()).data().providerTranscriptId,'id');
 await new MedCasesTranscriptionService({providers:{assemblyai:provider}}).advance({job,ref,readAudio:async()=>{throw Error('should not upload');}});
 assert.equal((await ref.get()).data().state,'done');assert.equal(ref.pages[0].items[0].speakerLabel,'A');assert.equal(uploads,1);assert.equal(submits,1);assert.equal(polls,1);
});
test('unknown submission outcome never auto-resubmits',async()=>{
 let submits=0;const ref=memoryRef({state:'processing',submissionIntent:true,submissionOutcome:'unknown',providerAudioUrl:'https://synthetic.test/file'});
 const service=new MedCasesTranscriptionService({providers:{assemblyai:{async submit(){submits++;}}}});
 await service.advance({job:{provider:'assemblyai'},ref});assert.equal(submits,0);assert.equal((await ref.get()).data().state,'terminal_error');
});
