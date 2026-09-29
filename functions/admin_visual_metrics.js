'use strict';
const {Timestamp,AggregateField}=require('firebase-admin/firestore');
const {createAdminControlCenter}=require('./admin_control_center');
const DAY=86400000;
function createAdminVisualMetrics({db,now=()=>Date.now()}) {
 const auth=createAdminControlCenter({db});let cache;
 const count=async q=>{try{return (await q.count().get()).data().count;}catch{return null;}};
 const sum=async(q,field)=>{try{return (await q.aggregate({value:AggregateField.sum(field)}).get()).data().value;}catch{return null;}};
 async function metrics(uid,{days=7,offsetMinutes=0}={}) {
  await auth.authorize(uid);
  if(![7,30].includes(days)||!Number.isInteger(offsetMinutes)||Math.abs(offsetMinutes)>840)throw Error('INVALID_WINDOW');
  const key=`${days}:${offsetMinutes}`,time=now();if(cache?.key===key&&time-cache.at<60000)return cache.value;
  const today=Math.floor((time+offsetMinutes*60000)/DAY)*DAY-offsetMinutes*60000;
  const users=db.collection('users'),ai=db.collection('admin_ai_usage_events');
  const interval=(q,start,end)=>q.where('createdAt','>=',Timestamp.fromMillis(start)).where('createdAt','<',Timestamp.fromMillis(end));
  const [total,free,premium,vip,trials,active,aiToday,incidents,jobs,content,rolling]=await Promise.all([
   count(users),count(users.where('plan','==','free')),count(users.where('plan','in',['premium','pro','paid'])),count(users.where('isPartner','==',true)),count(users.where('subscriptionStatus','in',['trial','trialing'])),count(users.where('lastSeenAt','>=',Timestamp.fromMillis(today))),count(interval(ai,today,today+DAY)),count(db.collection('admin_incidents').where('status','in',['open','acknowledged'])),count(db.collection('_study_background_transcription_jobs').where('state','in',['failed','retryable_error','terminal_error'])),Promise.all(['clinical_guides','adminContentInventoryPathologies','adminContentInventoryDrugs'].map(c=>count(db.collection(c)))),db.doc('admin_ai_metrics/realtime').get()
  ]);
  const reservation=db.collection('usageReservations').where('kinds','array-contains','transcription').where('state','==','completed');
  const consumed=(start,end)=>reservation.where('createdAt','>=',start).where('createdAt','<',end);
  const [transcriptionsToday,consumedMs,extraSeconds,errorsToday,activitySamples]=await Promise.all([count(consumed(today,today+DAY)),sum(consumed(today,today+DAY),'chargedMs'),sum(db.collection('adminManualCredits').where('grantedAt','>=',today).where('grantedAt','<',today+DAY),'amountSeconds'),count(interval(ai,today,today+DAY).where('success','==',false)),count(users.where('lastSeenAt','>=',Timestamp.fromMillis(0)))]);
  const series=[];
  // Aggregation-only queries; no clinical event payload is read or returned.
  for(let i=days-1;i>=0;i--){const start=today-i*DAY,end=start+DAY;const [growth,requests,consumedMs]=await Promise.all([count(interval(users,start,end)),count(interval(ai,start,end)),sum(consumed(start,end),'chargedMs')]);series.push({date:new Date(start+offsetMinutes*60000).toISOString().slice(0,10),growth,requests,consumedMinutes:consumedMs===null?null:consumedMs/60000});}
  const modes={};for(const mode of ['home','study','plantao'])modes[mode]=await count(interval(ai,today,today+DAY).where('mode','==',mode));
  let latency=null;try{const q=interval(ai,today,today+DAY);const a=await q.aggregate({avg:AggregateField.average('durationMs')}).get();latency=a.data().avg??null;}catch{}
  const r=rolling.data()||{},at=r.generatedAt?.toMillis?.()??0,fresh=time-at>=0&&time-at<3600000;
  const providers=fresh?Object.entries(r.providers||{}).filter(([k])=>['openai','gemini'].includes(k)).map(([provider,v])=>({provider,requests:v.requests24h??null,cost:v.costTodayUsd??null,inputTokens:v.inputTokens24h??null,outputTokens:v.outputTokens24h??null,model:v.model||null})):[];
  const value={observedAt:time,days,timezoneOffsetMinutes:offsetMinutes,total,free,premium,vip,trials,activeToday:activitySamples>0?active:null,transcriptionsToday,consumedMinutes:consumedMs===null?null:consumedMs/60000,extraMinutes:extraSeconds===null?null:extraSeconds/60,errorsToday,aiToday,aiLatencyMs:latency,modes,openIncidents:incidents,failedJobs:jobs,content:{guides:content[0],pathologies:content[1],drugs:content[2]},series,providers,rolling24h:fresh?{requests:r.requests24h??null,errors:r.errors24h??null,cost:r.costTodayUsd??null,successRate:r.requests24h>0?1-r.errors24h/r.requests24h:null}:null,activitySeries:[],transcriptionSeries:[],costSeries:[],failureSeries:[],transcriptionOutcomes:[],limitations:['activity_history_unconnected','cost_daily_aggregate_unconnected'],planBasis:'declared_plan_vip_separate'};
  cache={key,at:time,value};return value;
 }
 return {metrics};
}
module.exports={createAdminVisualMetrics};
