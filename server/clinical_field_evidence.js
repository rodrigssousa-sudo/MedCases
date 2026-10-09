'use strict';
// Only explicit field labels authorize placement. Never infer an allergy field
// from an educational mention of allergy, or infer a patient's medications.
const FIELD_LABELS=Object.freeze({
 chiefComplaint:/^\s*(?:Queixa principal|Motivo de consulta)\s*:/iu,
 historyOfPresentIllness:/^\s*(?:História|Historia|História da doença atual|Historia de la enfermedad actual)\s*:/iu,
 pastMedicalHistory:/^\s*(?:Antecedentes pessoais|Antecedentes personales)\s*:/iu,
 medications:/^\s*(?:Medicações|Medicamentos|Medicación)\s*:/iu,
 allergies:/^\s*Alergias\s*:/iu,
 familyHistory:/^\s*Antecedentes familiares\s*:/iu,
 socialHistory:/^\s*(?:História social|Historia social)\s*:/iu,
 reviewOfSystems:/^\s*(?:Revisão de sistemas|Revisión por sistemas)\s*:/iu,
});
function fieldFor(value){return Object.keys(FIELD_LABELS).find(k=>FIELD_LABELS[k].test(value))??'otherRelevantInformation';}
module.exports={FIELD_LABELS,fieldFor};
