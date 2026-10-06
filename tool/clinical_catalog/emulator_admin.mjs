// Synthetic canary only. Hard guard prevents use against production.
import {createRequire} from 'node:module';
import {fixture} from '../../test/clinical_catalog_rules/fixture.mjs';
import {writeDraft,activate,rollback} from './publication.mjs';
if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8791')throw new Error('EMULATOR_REQUIRED');
const require=createRequire(import.meta.url);const admin=require('../../functions/node_modules/firebase-admin');
admin.initializeApp({projectId:'demo-clinical-canary'});const db=admin.firestore();
const command=process.argv[2];
if(command==='A'){await writeDraft(db,fixture('A'));await activate(db,'A',null);}
else if(command==='draftB')await writeDraft(db,fixture('B'));
else if(command==='B')await activate(db,'B','A');
else if(command==='rollback')await rollback(db,'B');
else throw new Error('COMMAND');
console.log(command+'=PASS');await admin.app().delete();
