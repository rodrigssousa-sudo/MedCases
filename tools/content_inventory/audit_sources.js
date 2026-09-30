'use strict';
const fs=require('node:fs');
const {loadSource}=require('../../functions/content_inventory/source');
const {classify,summary}=require('../../functions/content_inventory/model');
(async()=>{for(const kind of ['drugs','pathologies']){const loaded=await loadSource(kind);const rows=classify(loaded.rows);const report={kind,source:loaded.source,sourceVersion:loaded.sourceVersion,sourceMode:loaded.sourceMode,counts:summary(rows),rows};fs.writeFileSync(process.argv[2]+'/'+kind+'.json',JSON.stringify(report,null,2));console.log(JSON.stringify({kind,source:loaded.source,counts:report.counts}));}})().catch(e=>{console.error(e.message);process.exitCode=1;});
