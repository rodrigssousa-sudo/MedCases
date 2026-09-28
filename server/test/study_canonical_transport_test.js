"use strict";
const test=require("node:test"),assert=require("node:assert/strict"),fs=require("node:fs"),vm=require("node:vm"),acorn=require("acorn");
const {studyCanonicalTransport,VERSION}=require("../study_canonical_transport");
test("gateway uses same schema and isolated opt-in as paid function",()=>{
 assert.deepEqual(require("../study_canonical_schema_v2.json"),require("../../functions/lib/study_canonical_schema_v2.json"));
 assert.equal(studyCanonicalTransport({mode:"plantao",studyCanonicalVersion:VERSION,systemPrompt:"STUDY PAID CANONICAL v2"}),null);
});
test("actual syncRequest keeps model, timeout and legacy config; canonical adds only serialization",async()=>{
 const source=fs.readFileSync(require.resolve("../server"),"utf8");
 const ast=acorn.parse(source,{ecmaVersion:"latest"});
 const functions=ast.body.filter(n=>n.type==="FunctionDeclaration"&&["clampNumber","syncRequest"].includes(n.id.name));
 assert.equal(functions.length,2);
 const calls=[];const context={studyCanonicalCompletion:require("../study_canonical_transport").studyCanonicalCompletion,GEMINI_MODEL:"unchanged-model",SAFETY_SETTINGS:[],AbortSignal,fetch:async(url,opts)=>{calls.push({url,body:JSON.parse(opts.body)});return {ok:true,json:async()=>({candidates:[{finishReason:"MAX_TOKENS",content:{parts:[{text:"synthetic"}]}}]})};}};
 vm.createContext(context);vm.runInContext(functions.map(n=>source.slice(n.start,n.end)).join("\n"),context);
 await context.syncRequest("synthetic","private-test-key",{model:"preserved-model",maxTokens:50000});
 assert.equal(calls[0].body.generationConfig.maxOutputTokens,8192);
 assert.equal(calls[0].body.generationConfig.responseJsonSchema,undefined);
 const canonical=studyCanonicalTransport({mode:"estudo",lang:"es",studyCanonicalVersion:VERSION,systemPrompt:"STUDY PAID CANONICAL v2"});
 const output=await context.syncRequest("synthetic","private-test-key",{model:"preserved-model",maxTokens:50000,canonicalTransport:canonical});
 assert.equal(output.canonical.finishReason,"MAX_TOKENS");
 assert.equal(output.error,"canonical_incomplete_termination");
 assert.equal(calls[1].url,calls[0].url);
 assert.equal(calls[1].body.generationConfig.maxOutputTokens,8192);
 assert.deepEqual(calls[1].body.generationConfig.responseJsonSchema,require("../study_canonical_schema_v2.json"));
 assert.equal(calls[1].body.generationConfig.temperature,calls[0].body.generationConfig.temperature);
 assert.equal(calls[1].body.contents[0].parts[0].text,"synthetic");
});
