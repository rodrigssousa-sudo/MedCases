'use strict';
const test=require('node:test');const assert=require('node:assert/strict');
const {assertUsageReservation,containsAudio}=require('../usage_reservation_guard');
const id='a'.repeat(64),headers={'x-medcases-usage-reservation':id,'x-medcases-usage-attempt':'one'};
test('audio execution requires live owned server receipt and cannot use completed, stale, other UID or wrong kind',async()=>{
 let value={uid:'A',state:'reserved',attempt:'one',kinds:['transcription'],maximumMs:1000};
 const db={collection:name=>{assert.equal(name,'usageReservations');return{doc:key=>{assert.equal(key,id);return{get:async()=>({exists:!!value,data:()=>value})}}}}};
 assert.deepEqual(await assertUsageReservation(db,'A',headers),headers);
 await assert.rejects(assertUsageReservation(db,'A',{}));
 await assert.rejects(assertUsageReservation(db,'B',headers));
 for(const patch of [{state:'completed'},{attempt:'two'},{kinds:['recording']},{maximumMs:0}]){
 const original=value;value={...value,...patch};await assert.rejects(assertUsageReservation(db,'A',headers));value=original;
 }
 value=null;await assert.rejects(assertUsageReservation(db,'A',headers));
});
test('nested audio MIME is identified without classifying PDF as transcription',()=>{
 assert.equal(containsAudio({contents:[{parts:[{inlineData:{mimeType:'audio/mp4'}}]}]}),true);
 assert.equal(containsAudio({contents:[{parts:[{fileData:{mime_type:'audio/mpeg'}}]}]}),true);
 assert.equal(containsAudio({mimeType:'application/pdf'}),false);
});
