"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {studyCanonicalTransport, VERSION} = require("../lib/study_canonical_transport");
const request = {mode:"estudo", studyCanonicalVersion:VERSION,
 systemPrompt:"STUDY CANONICAL TRANSPORT v1\nClinical policy"};
test("Study native canonical contract is explicit, complete, and scoped", () => {
 const config=studyCanonicalTransport(request);
 assert.equal(config.maxOutputTokens,32768);
 assert.equal(config.generationConfig.responseMimeType,"application/json");
 assert.equal(config.generationConfig.responseJsonSchema.type,"array");
 assert.deepEqual(Object.keys(config).sort(),["generationConfig","maxOutputTokens","version"]);
});
for(const [name,body] of Object.entries({
 plantao:{...request,mode:"plantao"}, plainStudy:{mode:"estudo",systemPrompt:"educational"},
 wrongVersion:{...request,studyCanonicalVersion:"other"}, missingMarker:{...request,systemPrompt:"ordinary"},
 utility:{...request,studyCanonicalVersion:undefined}, legacyOpenAI:{...request,provider:"openai"}
})) test(`${name} retains existing transport`,()=>assert.equal(studyCanonicalTransport(body),null));
test("canonical helper has no authorization, routing, quota, or model fields",()=>{
 const config=studyCanonicalTransport(request);
 for(const key of ["auth","uid","role","quota","model","temperature","provider"])
  assert.equal(Object.hasOwn(config,key),false);
});
