'use strict';
const {onSchedule}=require('firebase-functions/v2/scheduler');
const {createInventory}=require('./store');
const {loadSource}=require('./source');
module.exports=admin=>({syncAdminContentInventory:onSchedule({region:'us-central1',schedule:'every 24 hours',timeZone:'UTC',timeoutSeconds:540,memory:'512MiB',maxInstances:1,retryCount:0},async()=>{
 const inventory=createInventory({db:admin.firestore(),loadSource});
 const results=await Promise.allSettled(['drugs','pathologies'].map(kind=>inventory.sync(kind)));
 if(results.some(x=>x.status==='rejected'))throw Error('CONTENT_INVENTORY_SYNC_FAILED');
})});
