'use strict';
const PROFILES = Object.freeze({
  clinicalHistory: {diarization:false, clinical:true},
  consultation: {diarization:true, clinical:true},
  lecture: {diarization:true, clinical:false},
  studyRecording: {diarization:false, clinical:false},
  quickSummary: {diarization:false, clinical:false},
  generalDictation: {diarization:false, clinical:false},
});
const KEYTERMS = Object.freeze(['ceftriaxona','metoprolol','noradrenalina','hipercalemia',
  'encefalopatia hepática','tromboembolismo pulmonar','troponina','creatinina','microgramas','miligramos']);
function profileOptions({mode, locale='pt', conversation=false, speakersExpected}={}) {
  const profile=PROFILES[mode];
  if (!profile) throw Error('TRANSCRIPTION_PROFILE_INVALID');
  if (!['pt','es','mixed'].includes(locale)) throw Error('TRANSCRIPTION_LANGUAGE_INVALID');
  const speakerLabels=profile.diarization || (mode==='clinicalHistory' && conversation) || (mode==='studyRecording' && conversation);
  const request={speech_models:['universal-3-5-pro'], language_detection:true,
    speaker_labels:speakerLabels, punctuate:true, format_text:true,
    prompt:locale==='mixed' ? 'Medical and educational conversations in Portuguese and Spanish, including English medical terminology.'
      : locale==='es' ? 'Spanish medical and educational speech, including English medical terminology.'
      : 'Portuguese medical and educational speech, including English medical terminology.',
    keyterms_prompt:[...KEYTERMS]};
  if (profile.clinical && locale==='es') request.domain='medical-v1';
  if (speakersExpected !== undefined) {
    if (!speakerLabels || !Number.isInteger(speakersExpected) || speakersExpected<1 || speakersExpected>10) throw Error('SPEAKER_COUNT_INVALID');
    request.speakers_expected=speakersExpected;
  }
  return request;
}
function selectedProvider(env, uid) {
  if (env.ASSEMBLYAI_TRANSCRIPTION_ENABLED !== 'true') return 'legacy';
  // Server-controlled gate. A client cannot self-declare audio as synthetic.
  if (env.ASSEMBLYAI_CLINICAL_PHI_APPROVED !== 'true') {
    const syntheticOwners=String(env.ASSEMBLYAI_SYNTHETIC_OWNER_UIDS || '').split(',').map(v=>v.trim()).filter(Boolean);
    if (!syntheticOwners.includes(uid)) throw Error('ASSEMBLYAI_PHI_PRODUCTION_BLOCKED');
  }
  if (!env.ASSEMBLYAI_API_KEY) throw Error('ASSEMBLYAI_NOT_CONFIGURED');
  return 'assemblyai';
}
module.exports={PROFILES, profileOptions, selectedProvider};
