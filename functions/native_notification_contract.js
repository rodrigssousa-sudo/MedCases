'use strict';
const crypto = require('crypto');
const events = Object.freeze({
 TRANSCRIPTION_COMPLETED: ['results','transcription','Sua transcrição foi concluída','Tu transcripción está lista'],
 CONSULTATION_SUMMARY_READY: ['results','summary','Seu resumo da consulta está pronto','El resumen de tu consulta está listo'],
 ANALYSIS_COMPLETED: ['results','analysis','Sua análise foi concluída','Tu análisis está listo'],
 CONTENT_PROCESSED: ['results','content','Seu conteúdo foi processado','Tu contenido está listo'],
 IMPORTANT_APP_ALERT: ['transactional','alerts','Há um aviso importante no MedCases','Hay un aviso importante en MedCases'],
 NEW_FEATURE_AVAILABLE: ['updates','features','Tem novidade no MedCases','Hay novedades en MedCases'],
 GLOBAL_ENGAGEMENT_REMINDER: ['reminders','home','Como o MedCases pode te ajudar hoje?','¿Cómo puede ayudarte MedCases hoy?'],
 TIMER_COMPLETED: ['timers','timer','Timer concluído','Temporizador finalizado'],
});
const hash = value => crypto.createHash('sha256').update(value).digest('hex');
const locale = value => String(value || '').toLowerCase().startsWith('es') ? 'es' : 'pt';
function payload(event, device) {
 const c=events[event.eventType];
 if(!c || !/^[A-Za-z0-9_-]{1,180}$/.test(event.resourceId || '') || !event.notificationId) throw Error('INVALID_EVENT');
 const lang=locale(device.activeAppLocale || device.lastAppLocale || device.initialAppLocale);
 return {token:device.token, notification:{title:c[lang==='es'?3:2],body:'MedCases Clinical'},
  data:{eventType:event.eventType,resourceId:event.resourceId,notificationId:event.notificationId,
    deepLink:`medcases://${c[1]}/${encodeURIComponent(event.resourceId)}`},
  android:{notification:{channelId:`medcases_${c[0]}`,tag:event.notificationId}},
  apns:{headers:{'apns-collapse-id':hash(event.notificationId)},payload:{aps:{sound:'default'}}}};
}
function eligible(event, device, now=new Date()) {
 if(!device.enabled || !device.token) return false;
 const p=device.preferences || {};
 if(event.eventType==='NEW_FEATURE_AVAILABLE' && p.productUpdates!==true) return false;
 if(event.eventType!=='GLOBAL_ENGAGEMENT_REMINDER') return true;
 if(p.marketingEngagement!==true) return false;
 if(!Number.isInteger(device.utcOffsetMinutes) || Math.abs(device.utcOffsetMinutes)>840) return false;
 const local=new Date(now.getTime()+device.utcOffsetMinutes*60000),h=local.getUTCHours();
 const start=Number.isInteger(p.quietStart)?p.quietStart:21,end=Number.isInteger(p.quietEnd)?p.quietEnd:8;
 if(start===end || (start>end ? h>=start||h<end : h>=start&&h<end)) return false;
 const recent=(device.engagementSentAt || []).filter(t=>Number.isFinite(t)&&t>now.getTime()-7*86400000);
 if(recent.length>=3) return false;
 const last=device.lastActiveAt?.toMillis?.() ?? device.lastActiveAt;
 return Number.isFinite(last) && now.getTime()-last>=24*3600000;
}
module.exports={events,hash,locale,payload,eligible};
