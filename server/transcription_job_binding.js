'use strict';
const {createHash}=require('node:crypto');
function sourceBindingRef(db,uid,sourceId){
 if(typeof sourceId!=='string'||!/^[A-Za-z0-9_.-]{1,160}$/.test(sourceId))throw Error('SINGLE_AUDIO_BINDING_INVALID');
 return db.collection('transcriptionSourceJobs').doc(createHash('sha256').update(`${uid}\n${sourceId}`).digest('hex'));
}
function assertSameJob(value,{uid,sourceId,expectedSegments,singleAudio,attemptId}){
 if(value.deleted)throw Error('study_job_deleted');
 if(value.uid!==uid||value.sourceId!==sourceId||value.expectedSegments!==expectedSegments||(value.singleAudio===true)!==(singleAudio===true)||(value.attemptId||null)!==(attemptId||null))throw Error('study_job_binding_invalid');
}
module.exports={sourceBindingRef,assertSameJob};
