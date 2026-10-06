const {test}=require('node:test'); const assert=require('node:assert/strict');
const {authorizeStudyArtifact:check}=require('../study_artifact_access');
const types=['visualSummary','fullSummary','examSummary','mindMap','flashcards','questionsAndAnswers','multipleChoice','oralExam','keyPoints','comparisonTable','finalPdf'];
for(const type of types)test(type+' follows server entitlement',()=>{
 const free=['fullSummary','keyPoints'].includes(type);
 assert.equal(check({studyArtifactType:type,tier:'premium'},{}),free?null:'study_premium_required');
 assert.equal(check({studyArtifactType:type},{plan:'premium'}),null);
 assert.equal(check({studyArtifactType:type},{plan:'premium',billingEntitlementActive:false}),free?null:'study_premium_required');
 assert.equal(check({studyArtifactType:type},{billingEntitlementActive:true,billingEntitlementId:'medcases_pro_premium',billingEntitlementExpiresAtMs:200},100),null);
 assert.equal(check({studyArtifactType:type},{billingEntitlementActive:true,billingEntitlementId:'medcases_pro_premium',billingEntitlementExpiresAtMs:100},100),free?null:'study_premium_required');
});
test('legacy visual protected; chat unchanged; unknown format fails',()=>{
 assert.equal(check({studyArtifactFormat:'study-visual-v1'},{}),'study_premium_required');
 assert.equal(check({mode:'plantao'},{}),null);
 assert.equal(check({studyArtifactType:'unknown'},{}),'study_artifact_type_invalid');
});
