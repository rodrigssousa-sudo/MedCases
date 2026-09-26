'use strict';
const roles={consultation:['doctor','patient','companion','interpreter','other'],
  clinicalHistory:['doctor','patient','companion','interpreter','other'],
  lecture:['professor','student','participant','other']};
class SpeakerRoleResolver {
  constructor(classifyContext=null) {this.classifyContext=classifyContext;}
  async resolve({mode,utterances}) {
    // No order-based heuristic and no public/voice identity recognition.
    // Without a validated contextual classifier, neutral labels are intentional.
    const candidates=this.classifyContext ? await this.classifyContext({mode,utterances}) : [];
    const labels=new Set(utterances.map(v=>v.speakerLabel)),map={};
    for (const candidate of candidates || []) {
      if (!labels.has(candidate.speakerLabel) || !(roles[mode]||[]).includes(candidate.role) ||
        !Number.isFinite(candidate.confidence) || candidate.confidence<0.9 || candidate.confidence>1 ||
        !Array.isArray(candidate.evidenceUtteranceIndices) || !candidate.evidenceUtteranceIndices.length ||
        candidate.evidenceUtteranceIndices.some(i=>!Number.isInteger(i)||!utterances[i]||utterances[i].speakerLabel!==candidate.speakerLabel)) continue;
      map[candidate.speakerLabel]={role:candidate.role,confidence:candidate.confidence,
        evidenceUtteranceIndices:candidate.evidenceUtteranceIndices};
    }
    return map;
  }
}
function displayUtterances(raw,{roleMap={},aliases={}}={}) {
  return raw.map(v=>({...v,displayLabel:aliases[v.speakerLabel] || roleMap[v.speakerLabel]?.role || `Interlocutor ${v.speakerLabel}`}));
}
module.exports={SpeakerRoleResolver,displayUtterances};
