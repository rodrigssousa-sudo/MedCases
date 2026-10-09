'use strict';
const {isDeepStrictEqual}=require('node:util');
const {hash,DerivativeError}=require('./derivative_contract');
const {TranscriptFactLedger}=require('./transcript_fact_ledger');
const {inlineBlueprints}=require('./oral_inline_templates');
const VERSION='oral_blueprint_r24_v1';
const FAMILIES=Object.freeze({EASY:['DIRECT_RECALL','DEFINITION','IDENTIFY_FEATURE','LIST_SUPPORTED','NAME_EXAMPLE'],MEDIUM:['EXPLAIN_RELATIONSHIP','COMPARE_SUPPORTED','SEQUENCE','CLASSIFY','EXPLAIN_MECHANISM_IF_EXPLICIT'],HARD:['INTEGRATE_MULTIPLE_FACTS','CONTRAST_SUPPORTED_CONCEPTS','SYNTHESIZE_SOURCE','CAUSE_EFFECT_IF_EXPLICIT','APPLY_SOURCE_RELATIONSHIP']});
const normalize=s=>s.normalize('NFD').replace(/\p{M}/gu,'').toLowerCase().replace(/[^\p{L}\p{N}]+/gu,' ').trim();
const qualifiers=s=>[...s.matchAll(/\b(?:pode|podem|poderia|alguns|algumas|sugerido|associado|possível|raramente|frequentemente|puede|pueden|podría|algunos|algunas|sugirió|posible|no|não|somente|solo|sempre|siempre)\b/giu)].map(m=>m[0]);
// Deliberately finite source grammars. Unsupported prose is omitted, never
// converted into a vague question. Whole evidence paragraphs remain answers.
function plan(fact,locale){
 const s=fact.value.trim();const es=locale==='es';let m;
 if(s.length>3000||/[«»]/u.test(s))return null;
 if((m=s.match(es?/^(.{2,100}?) (?:puede|pueden) (?:causar|aumentar|reducir) ([^.!?]+)[.!?]/u:/^(.{2,100}?) (?:pode|podem) (?:causar|aumentar|reduzir) ([^.!?]+)[.!?]/u))){
  return {family:'IDENTIFY_FEATURE',difficulty:'EASY',target:m[1],answerSpan:m[2],question:es?`¿Qué efecto posible atribuye la fuente a «${m[1]}» y con qué limitaciones? Preserve la incertidumbre.`:`Que efeito possível a fonte atribui a «${m[1]}» e com quais limitações? Preserve a incerteza.`,relation:'EXPLICIT_POSSIBLE_EFFECT'};
 }
 if((m=s.match(es?/^(.{2,100}?) contiene (?:[^:.!?]{1,35})?:\s*([^.!?]+)[.!?]/u:/^(.{2,100}?) contém (?:[^:.!?]{1,35})?:\s*([^.!?]+)[.!?]/u))){
  return {family:'LIST_SUPPORTED',difficulty:'EASY',target:m[1],answerSpan:m[2],question:es?`¿Qué elementos enumera la fuente en «${m[1]}»${/orden|prioridad/iu.test(s)?' y qué indica sobre su orden':''}?`:`Quais elementos a fonte enumera em «${m[1]}»${/ordem|prioridade/iu.test(s)?' e o que informa sobre sua ordem':''}?`,relation:'EXPLICIT_LIST'};
 }
 if((m=s.match(es?/^(.{2,100}?) se define como ([^!?]+?)(?:\.(?:\s|$))/u:/^(.{2,100}?) é definido como ([^!?]+?)(?:\.(?:\s|$))/u))){
  return {family:'DEFINITION',difficulty:'EASY',target:m[1],answerSpan:m[2],question:es?`¿Cómo define la fuente «${m[1]}»?`:`Como a fonte define «${m[1]}»?`,relation:'EXPLICIT_DEFINITION'};
 }
 if((m=s.match(es?/^((?:El|La) concepto [\p{L}\p{N}-]+) es ([^,.!?]+), mientras que ((?:el|la) concepto [\p{L}\p{N}-]+) (.+?)\.(?:\s|$)/u:/^((?:O|A) conceito [\p{L}\p{N}-]+) é ([^,.!?]+), enquanto ((?:o|a) conceito [\p{L}\p{N}-]+) (.+?)\.(?:\s|$)/u))){
  return {family:'COMPARE_SUPPORTED',difficulty:'MEDIUM',target:`${m[1]} / ${m[3]}`,answerSpan:`${m[2]} / ${m[4]}`,question:es?`¿Qué diferencia describe la fuente entre «${m[1]}» y «${m[3]}»?`:`Qual diferença a fonte descreve entre «${m[1]}» e «${m[3]}»?`,relation:'EXPLICIT_COMPARISON'};
 }
 if((m=s.match(es?/^Primero (.+?), después (.+?)(?:,? y por último (.+?))?\.(?:\s|$)/u:/^Primeiro (.+?), depois (.+?)(?:,? e por último (.+?))?\.(?:\s|$)/u))){
  return {family:'SEQUENCE',difficulty:'MEDIUM',target:es?'secuencia explícita':'sequência explícita',answerSpan:m[0].trim(),question:es?`En el proceso que comienza con «${m[1]}», ¿qué etapas siguen y en qué orden? Conserve las dependencias explícitas y no añada horarios.`:`No processo que começa com «${m[1]}», quais etapas vêm depois e em que ordem? Preserve as dependências explícitas e não acrescente horários.`,relation:'EXPLICIT_SEQUENCE'};
 }
 if((m=s.match(es?/^En el ejemplo ficticio, ([\p{L}\p{N}-]+) usa (.+?)\.(?:\s|$)/u:/^No exemplo fictício, ([\p{L}\p{N}-]+) usa (.+?)\.(?:\s|$)/u))){
  return {family:'DIRECT_RECALL',difficulty:'EASY',target:m[1],answerSpan:m[2],question:es?`¿Qué cantidad, unidad e intervalo se describen para «${m[1]}» en este ejemplo ficticio? No convierta unidades ni lo aplique a un paciente.`:`Qual quantidade, unidade e intervalo são descritos para «${m[1]}» neste exemplo fictício? Não converta unidades nem aplique a um paciente.`,relation:'EXPLICIT_EXAMPLE_PARAMETERS'};
 }
 if((m=s.match(es?/^Se sugirió que (.{1,80}?) estaba relacionado con (.{1,80}?)\. La relación no fue confirmada\.$/u:/^Foi sugerido que (.{1,80}?) estava relacionado a (.{1,80}?)\. A relação não foi confirmada\.$/u))){
  return {family:'IDENTIFY_FEATURE',difficulty:'EASY',target:`${m[1]} / ${m[2]}`,answerSpan:es?'La relación no fue confirmada':'A relação não foi confirmada',question:es?`¿Qué grado de confirmación tiene la relación propuesta entre «${m[1]}» y «${m[2]}»?`:`Qual é o grau de confirmação da relação proposta entre «${m[1]}» e «${m[2]}»?`,relation:'EXPLICIT_UNCONFIRMED_ASSOCIATION'};
 }
 if((m=s.match(es?/^Ayer (.{1,80}?) estaba ausente, hoy estaba presente\. Esta evolución no es necesariamente una contradicción\.$/u:/^Ontem (.{1,80}?) estava ausente, hoje estava presente\. Essa evolução não é necessariamente uma contradição\.$/u))){
  return {family:'DIRECT_RECALL',difficulty:'EASY',target:m[1],answerSpan:es?'no es necesariamente una contradicción':'não é necessariamente uma contradição',question:es?`¿Cómo cambió «${m[1]}» entre ayer y hoy y qué cautela expresa la fuente al interpretar ese cambio?`:`Como «${m[1]}» mudou entre ontem e hoje e que cautela a fonte expressa ao interpretar essa mudança?`,relation:'EXPLICIT_TEMPORAL_QUALIFIER'};
 }
 if((m=s.match(es?/^En el sistema ficticio, (.{1,100}?) causa (.{1,100}?), pero solo cuando (.{1,100}?)\.$/u:/^No sistema fictício, (.{1,100}?) causa (.{1,100}?), mas somente quando (.{1,100}?)\.$/u))){
  return {family:'EXPLAIN_RELATIONSHIP',difficulty:'MEDIUM',target:m[1],answerSpan:m[3],question:es?`En el sistema ficticio, explique el efecto de «${m[1]}» y la condición necesaria que limita esa relación.`:`No sistema fictício, explique o efeito de «${m[1]}» e a condição necessária que limita essa relação.`,relation:'EXPLICIT_CONDITIONAL_CAUSE'};
 }
 if((m=s.match(es?/^No se mencionaron (.{1,150}?)\. La ausencia de información no significa (.{1,150}?)\.$/u:/^Não foram mencionadas (.{1,150}?)\. Ausência de informação não significa (.{1,150}?)\.$/u))){
  return {family:'IDENTIFY_FEATURE',difficulty:'EASY',target:m[1],answerSpan:m[2],question:es?`Ante la falta de información sobre «${m[1]}», ¿qué conclusiones advierte la fuente que no deben extraerse?`:`Diante da falta de informação sobre «${m[1]}», quais conclusões a fonte alerta que não devem ser extraídas?`,relation:'EXPLICIT_INFORMATION_LIMITATION'};
 }
 return null;
}
function makeBlueprint(fact,locale,sourceHash){
 const p=plan(fact,locale);if(!p)return null;
 const conceptId=hash(JSON.stringify([VERSION,fact.factId,p.target]));
 const bp={conceptId,locale,difficulty:p.difficulty,questionFamily:p.family,targetFacts:[p.target],supportingFactIds:[fact.factId],answerFacts:[fact.value],requiredQualifiers:qualifiers(fact.value),relationType:p.relation,sourceOffsets:[{start:fact.sourceStartOffset,end:fact.sourceEndOffset}],sourceHashes:[fact.sourceQuoteHash],sourceHash,question:p.question,expectedAnswer:fact.value.trim(),answerSpan:p.answerSpan};
 return {questionId:hash(JSON.stringify([VERSION,bp])),...bp};
}
function dependencyBlueprint(first,second,locale,sourceHash){
 const es=locale==='es';
 const condition=first.value.trim().match(es?/^(?:En el escenario didáctico, )?si (.{3,100}), entonces seguir la etapa ([\p{L}\p{N}-]+)\.(?:\s|$)/iu:/^(?:No cenário didático, )?se (.{3,100}), então seguir a etapa ([\p{L}\p{N}-]+)\.(?:\s|$)/iu);
 const dependency=second.value.trim().match(es?/^La etapa ([\p{L}\p{N}-]+) depende de la finalización de ([\p{L}\p{N}-]+)[;.]/u:/^A etapa ([\p{L}\p{N}-]+) depende da conclusão de ([\p{L}\p{N}-]+)[;.]/u);
 if(!condition||!dependency||condition[2]!==dependency[2]||dependency[1]===dependency[2]||first.factId===second.factId)return null;
 const target=[condition[1],dependency[1]];
 const conceptId=hash(JSON.stringify([VERSION,first.factId,second.factId,target]));
 const bp={conceptId,locale,difficulty:'HARD',questionFamily:'APPLY_SOURCE_RELATIONSHIP',targetFacts:target,supportingFactIds:[first.factId,second.factId],answerFacts:[first.value,second.value],requiredQualifiers:qualifiers(first.value+second.value),relationType:'EXPLICIT_DEPENDENCY_CHAIN',sourceOffsets:[first,second].map(f=>({start:f.sourceStartOffset,end:f.sourceEndOffset})),sourceHashes:[first.sourceQuoteHash,second.sourceQuoteHash],sourceHash,
 question:es?`Explique la cadena de condiciones que vincula «${condition[1]}» con la etapa «${dependency[1]}». Integre ambos fragmentos citados, incluyendo las restricciones explícitas, sin añadir condiciones.`:`Explique a cadeia de condições que liga «${condition[1]}» à etapa «${dependency[1]}». Integre ambos os trechos citados, incluindo as restrições explícitas, sem acrescentar condições.`,
 expectedAnswer:[first.value.trim(),second.value.trim()].join('\n\n'),answerSpan:es?`etapa ${condition[2]}`:`etapa ${condition[2]}`};
 return {questionId:hash(JSON.stringify([VERSION,bp])),...bp};
}
function integrativeBlueprint(first,second,locale,sourceHash){
 const es=locale==='es';const a=first.value.trim(),b=second.value.trim();let m,p;
 if((m=a.match(es?/^La etapa inicial (.+?), mientras que la etapa final (.+?)\.$/u:/^A etapa inicial (.+?), enquanto a etapa final (.+?)\.$/u))&&
   (es?/^Primero registrar, después comparar\. Comparar depende de que existan registros;/u:/^Primeiro registrar, depois comparar\. Comparar depende de existirem registros;/u).test(b)){
  p={target:['etapa inicial','etapa final'],relation:'EXPLICIT_SEQUENCE_DEPENDENCY',question:es?'¿Cómo se relacionan las funciones de la etapa inicial y la etapa final con la dependencia que justifica su secuencia? Integre los dos fragmentos sin añadir pasos.':'Como as funções da etapa inicial e da etapa final se relacionam com a dependência que justifica sua sequência? Integre os dois trechos sem acrescentar etapas.'};
 }
 if((m=a.match(es?/^El modo ([\p{L}-]+) ejecuta ([^.]+)\. El modo ([\p{L}-]+) ejecuta ([^.]+)\./u:/^O modo ([\p{L}-]+) executa ([^.]+)\. O modo ([\p{L}-]+) executa ([^.]+)\./u))&&
  (es?/^Si (.+?), entonces el modo ([\p{L}-]+) vuelve a (.+?);/u:/^Se (.+?), então o modo ([\p{L}-]+) retorna a (.+?);/u).test(b)){
  const condition=b.match(es?/^Si (.+?), entonces el modo ([\p{L}-]+) vuelve a (.+?);/u:/^Se (.+?), então o modo ([\p{L}-]+) retorna a (.+?);/u);
  if(condition[2]===m[3]&&(es?/La ausencia de revisión .+ no prueba/u:/A ausência de revisão .+ não prova/u).test(b))p={target:[m[1],m[3]],relation:'EXPLICIT_CONTRAST_CONDITIONAL_RETURN',question:es?`Compare la secuencia de los modos «${m[1]}» y «${m[3]}», explique cuándo se activa el retorno descrito y preserve la cautela sobre la ausencia de revisión.`:`Compare a sequência dos modos «${m[1]}» e «${m[3]}», explique quando o retorno descrito é acionado e preserve a cautela sobre a ausência de revisão.`};
 }
 if((es?/^Cerrar (.+?) no restaura automáticamente (.+?) tras esa interrupción:/u:/^Fechar (.+?) não restaura automaticamente (.+?) após essa interrupção:/u).test(a)&&
    (es?/^El inicio y la reanudación requieren (.+?)\. La reanudación tras apertura requiere además (.+?)\./u:/^A partida inicial e a retomada exigem (.+?)\. A retomada após abertura exige também (.+?)\./u).test(b)){
  p={target:es?['inicio','reanudación tras apertura']:['partida inicial','retomada após abertura'],relation:'EXPLICIT_RESTART_CONDITION_CONTRAST',question:es?'Compare las condiciones del inicio con las de la reanudación tras apertura. Explique qué acción adicional se exige para restablecer la luz y qué condición debe mantenerse, sin inventar un mecanismo interno.':'Compare as condições da partida inicial com as da retomada após abertura. Explique qual ação adicional é exigida para restabelecer a luz e qual condição deve ser mantida, sem inventar um mecanismo interno.'};
 }
 if(!p||first.factId===second.factId)return null;
 const facts=[first,second];const bp={conceptId:hash(JSON.stringify([VERSION,...facts.map(f=>f.factId),p.target])),locale,difficulty:'HARD',questionFamily:'INTEGRATE_MULTIPLE_FACTS',targetFacts:p.target,supportingFactIds:facts.map(f=>f.factId),answerFacts:facts.map(f=>f.value),requiredQualifiers:qualifiers(a+' '+b),relationType:p.relation,sourceOffsets:facts.map(f=>({start:f.sourceStartOffset,end:f.sourceEndOffset})),sourceHashes:facts.map(f=>f.sourceQuoteHash),sourceHash,question:p.question,expectedAnswer:a+'\n\n'+b,answerSpan:a};
 return {questionId:hash(JSON.stringify([VERSION,bp])),...bp};
}

function validateBlueprint(bp,ledger){
 if(!bp||!['pt','es'].includes(bp.locale)||![1,2].includes(bp.supportingFactIds?.length))return false;
 const fact=ledger.facts.find(f=>f.factId===bp.supportingFactIds[0]);if(!fact)return false;
 const second=bp.supportingFactIds.length===2?ledger.facts.find(f=>f.factId===bp.supportingFactIds[1]):null;
 const canonical=bp.relationType==='EXPLICIT_INLINE_CHARACTERIZATION'?inlineBlueprints(fact,bp.locale,ledger.transcriptHash).find(q=>q.questionId===bp.questionId):bp.supportingFactIds.length===2?(second?(dependencyBlueprint(fact,second,bp.locale,ledger.transcriptHash)??integrativeBlueprint(fact,second,bp.locale,ledger.transcriptHash)):null):makeBlueprint(fact,bp.locale,ledger.transcriptHash);
 if(!canonical||!isDeepStrictEqual(bp,canonical))return false;
 // The answer must not be revealed in the bounded question. No reviewer can
 // approve changed facts, qualifiers, IDs, offsets, hashes or free questions.
 return !normalize(bp.question).includes(normalize(bp.answerSpan));
}
class OralBlueprintEngine {
 generate({rawTranscript,verifiedFactLedger,locale,difficultyTarget='MIXED',questionCount=10}){
  if(!['pt','es'].includes(locale)||!['MIXED','EASY','MEDIUM','HARD'].includes(difficultyTarget)||!Number.isInteger(questionCount)||questionCount<1||questionCount>20||!TranscriptFactLedger.validate(rawTranscript,verifiedFactLedger))throw new DerivativeError('invalid_oral_input');
  const questions=[];const seen=new Set();let supported=0;
  for(const fact of verifiedFactLedger.facts){
   const bp=makeBlueprint(fact,locale,verifiedFactLedger.transcriptHash);
   if(!bp||!validateBlueprint(bp,verifiedFactLedger)||difficultyTarget!=='MIXED'&&bp.difficulty!==difficultyTarget)continue;
   supported++;const key=normalize(bp.question);if(seen.has(key))continue;seen.add(key);
   if(questions.length<questionCount)questions.push(bp);
  }
  if(difficultyTarget==='MIXED'||difficultyTarget==='EASY'){
   for(const fact of verifiedFactLedger.facts)for(const bp of inlineBlueprints(fact,locale,verifiedFactLedger.transcriptHash)){
    if(!validateBlueprint(bp,verifiedFactLedger))continue;
    supported++;const key=normalize(bp.question);if(seen.has(key))continue;seen.add(key);
    if(questions.length<questionCount)questions.push(bp);
   }
  }
  if(difficultyTarget==='MIXED'||difficultyTarget==='HARD'){
   for(let i=0;i+1<verifiedFactLedger.facts.length;i++){
    const bp=dependencyBlueprint(verifiedFactLedger.facts[i],verifiedFactLedger.facts[i+1],locale,verifiedFactLedger.transcriptHash)??integrativeBlueprint(verifiedFactLedger.facts[i],verifiedFactLedger.facts[i+1],locale,verifiedFactLedger.transcriptHash);
    if(!bp||!validateBlueprint(bp,verifiedFactLedger))continue;
    supported++;const key=normalize(bp.question);if(seen.has(key))continue;seen.add(key);
    if(questions.length<questionCount)questions.push(bp);
   }
  }
  return {promptVersion:VERSION,status:questions.length?'PENDING_INDEPENDENT_REVIEW':'NO_SUPPORTED_TEMPLATE',strategy:'EXTRACTIVE_TEMPLATE',sourceHash:verifiedFactLedger.transcriptHash,locale,requested:questionCount,supported,questions,qualityOverQuantity:true,providerCalls:0};
 }
}
module.exports={OralBlueprintEngine,VERSION,FAMILIES,makeBlueprint,validateBlueprint};
