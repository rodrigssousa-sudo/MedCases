'use strict';
// READ ONLY: explicit frozen source directory, no credentials or remote reads.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=process.argv[2];
if(!root)throw Error('Provide the frozen RECOVERY-R15 reference directory');
const fixture=path.join(root,'catalog-readonly-fixture.json');
const bytes=fs.readFileSync(fixture),docs=JSON.parse(bytes);
const pointer=docs['app_config/clinical_content'];
const manifest=docs['clinical_content_versions/'+pointer.activeVersion];
const descriptors=manifest.chunks.filter(c=>c.collection==='clinical_identity_registry')
  .flatMap(c=>JSON.parse(docs['clinical_content_versions/'+pointer.activeVersion+'/chunks/'+c.id].json));
const {resolveCatalogProtocolIntent}=require(path.join(root,'functions/clinical_context/clinical_case_identity_resolver.js'));
const queries=['Paracetamol','Noradrenalina','Ceftriaxona','Metformina','Hipocalemia','Hipopotasemia','Sepse',
'Intoxicação por paracetamol','Sobredosis de paracetamol','Paciente ingeriu 20 g de paracetamol',
'Paracetamol dosis','Ceftriaxona contraindicaciones','Dose de paracetamol em criança de 15 kg',
'Paracetamo','Não é intoxicação por paracetamol'];
console.log(JSON.stringify({scope:'FROZEN_CATALOG_ONLY_NOT_CURRENT_PRODUCTION',
fixtureSha256:crypto.createHash('sha256').update(bytes).digest('hex'),
results:['pt','es'].flatMap(locale=>queries.map(input=>({input,locale,
...resolveCatalogProtocolIntent({input,locale,descriptors,registry:manifest.clinicalReleaseRegistry})})))},null,2));
