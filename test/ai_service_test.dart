// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/ai_service.dart';
import 'package:flutter_app/services/clinical_session_memory.dart';

void main() {

  // ════════════════════════════════════════════════════════════════
  // T1 — Build: ClinicalSessionMemory + buildMemoryBlock
  // ════════════════════════════════════════════════════════════════
  group('T1 — Build & ClinicalSessionMemory', () {

    test('instanciação e estado inicial vazio', () {
      final mem = ClinicalSessionMemory();
      expect(mem.buildMemoryBlock(false), isEmpty);
      expect(mem.buildMemoryBlock(true), isEmpty);
    });

    test('buildMemoryBlock PT — dados clínicos serializados', () {
      final mem = ClinicalSessionMemory();
      mem.addProblem('Sepse');
      mem.addMedication('Noradrenalina');
      mem.updateHemodynamics('PA 80/50 mmHg');
      mem.updateRiskLevel('critical');
      mem.updateEvolution('deteriorating');

      final block = mem.buildMemoryBlock(false);
      expect(block, contains('Sepse'));
      expect(block, contains('Noradrenalina'));
      expect(block, contains('PA 80/50 mmHg'));
      expect(block, contains('CRITICO'));
      expect(block, contains('deteriorando'));
      expect(block, contains('CONTEXTO_CLINICO_SESSAO'));
      expect(block, contains('FIM_CONTEXTO_SESSAO'));
      print('  [OK] buildMemoryBlock PT (${block.length} chars)');
    });

    test('buildMemoryBlock ES — labels em espanhol', () {
      final mem = ClinicalSessionMemory();
      mem.addProblem('Sepsis');
      mem.updateRiskLevel('critical');
      mem.updateEvolution('deteriorating');

      final block = mem.buildMemoryBlock(true);
      expect(block, contains('CONTEXTO_CLINICO_SESION'));
      expect(block, contains('deteriorando'));
      expect(block, contains('CRITICO'));
      print('  [OK] buildMemoryBlock ES (${block.length} chars)');
    });

    test('deduplicação — addProblem/addMedication não duplica', () {
      final mem = ClinicalSessionMemory();
      mem.addProblem('IAM');
      mem.addProblem('iam'); // normalizado para lowercase → duplicata
      mem.addMedication('Aspirina');
      mem.addMedication('aspirina'); // duplicata

      expect(mem.activeProblems.length, equals(1));
      expect(mem.previousMeds.length, equals(1));
      print('  [OK] Deduplicação');
    });

    test('reset() limpa todo o estado', () {
      final mem = ClinicalSessionMemory();
      mem.addProblem('IAM');
      mem.addMedication('Heparina');
      mem.updateRiskLevel('critical');
      mem.reset();

      expect(mem.buildMemoryBlock(false), isEmpty);
      expect(mem.activeProblems, isEmpty);
      expect(mem.currentRiskLevel, equals('low'));
      print('  [OK] reset()');
    });

    test('resetIfTopicChanged — mesmo tema não reseta', () {
      final mem = ClinicalSessionMemory();
      mem.addProblem('Sepse grave');
      mem.resetIfTopicChanged('paciente com sepse e febre');
      mem.resetIfTopicChanged('sepse e choque');
      expect(mem.activeProblems, isNotEmpty);
      print('  [OK] resetIfTopicChanged — mesmo tema preserva estado');
    });

    test('resetIfTopicChanged — tema diferente reseta após 2 turnos', () {
      final mem = ClinicalSessionMemory();
      mem.addProblem('Sepse');
      // Estabelece tema "sepse" com 2 turnos
      mem.resetIfTopicChanged('sepse e febre alta');
      mem.resetIfTopicChanged('sepse e lactato');
      // Agora muda para asma (tema diferente, tema anterior consolidado)
      final reset = mem.resetIfTopicChanged('explique asma bronquica');
      expect(reset, isTrue);
      expect(mem.activeProblems, isEmpty);
      print('  [OK] resetIfTopicChanged — mudança de tema reseta');
    });
  });

  // ════════════════════════════════════════════════════════════════
  // T2 — PT/ES: idioma da resposta acompanha query
  // ════════════════════════════════════════════════════════════════
  group('T2 — PT/ES branching', () {

    test('PT: prompt contém módulos em português', () {
      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'pt',
        matchedProtocolSummaries: [],
        matchedDrugSummaries: [],
      );
      expect(prompt, contains('PRECEPTOR MEDICO SENIOR'));
      expect(prompt, contains('RACIOCINIO CLINICO OBRIGATORIO'));
      expect(prompt, contains('ADAPTACAO POR ESPECIALIDADE'));
      expect(prompt, contains('GRADUACAO DE EVIDENCIA'));
      expect(prompt, contains('REGRAS DE SEGURANCA'));
      expect(prompt, contains('FORMATO MANDATORIO'));
      expect(prompt, contains('REVISAO_INTERNA'));
      print('  [OK] Prompt PT — todos os módulos em português');
    });

    test('ES: prompt contém módulos em espanhol', () {
      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'es',
        matchedProtocolSummaries: [],
        matchedDrugSummaries: [],
      );
      expect(prompt, contains('PRECEPTOR MEDICO SENIOR'));
      expect(prompt, contains('RAZONAMIENTO CLINICO OBLIGATORIO'));
      expect(prompt, contains('ADAPTACION POR ESPECIALIDAD'));
      expect(prompt, contains('GRADUACION DE EVIDENCIA'));
      expect(prompt, contains('REGLAS DE SEGURIDAD'));
      expect(prompt, contains('FORMATO MANDATORIO'));
      expect(prompt, contains('REVISION_INTERNA'));
      print('  [OK] Prompt ES — todos os módulos em espanhol');
    });

    test('PT: sem contaminação ES nos módulos PT', () {
      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: []);
      expect(prompt, isNot(contains('RAZONAMIENTO CLINICO OBLIGATORIO')));
      expect(prompt, isNot(contains('REGLAS DE SEGURIDAD')));
      expect(prompt, isNot(contains('REVISION_INTERNA\n[FIN')));
      print('  [OK] PT sem contaminação ES');
    });

    test('ES: sem contaminação PT nos módulos ES', () {
      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'es', matchedProtocolSummaries: [], matchedDrugSummaries: []);
      expect(prompt, isNot(contains('RACIOCINIO CLINICO OBRIGATORIO')));
      expect(prompt, isNot(contains('REGRAS DE SEGURANCA')));
      print('  [OK] ES sem contaminação PT');
    });
  });

  // ════════════════════════════════════════════════════════════════
  // T3 — Intent routing: escopo correto por intent
  // ════════════════════════════════════════════════════════════════
  group('T3 — Intent routing', () {

    test('intent tratamento — escopo somente tratamento', () {
      final pt = AiService.buildClinicalSystemPrompt(
        lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
        queryIntent: 'tratamento');
      expect(pt, contains('Responda APENAS o tratamento'));
      expect(pt, contains('NAO inclua fisiopatologia'));
      print('  [OK] intent=tratamento PT');

      final es = AiService.buildClinicalSystemPrompt(
        lang: 'es', matchedProtocolSummaries: [], matchedDrugSummaries: [],
        queryIntent: 'tratamento');
      expect(es, contains('Responde SOLO el tratamiento'));
      expect(es, contains('NO incluyas fisiopatologia'));
      print('  [OK] intent=tratamento ES');
    });

    test('intent fisiopatologia — escopo somente mecanismo', () {
      final pt = AiService.buildClinicalSystemPrompt(
        lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
        queryIntent: 'fisiopatologia');
      expect(pt, contains('APENAS o mecanismo fisiopatologico'));
      expect(pt, contains('NAO inclua tratamento'));
      print('  [OK] intent=fisiopatologia PT');
    });

    test('intent causas — escopo somente etiologia', () {
      final pt = AiService.buildClinicalSystemPrompt(
        lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
        queryIntent: 'causas');
      expect(pt, contains('APENAS etiologia e fatores de risco'));
      print('  [OK] intent=causas PT');
    });

    test('intent referencias — escopo somente referências', () {
      final pt = AiService.buildClinicalSystemPrompt(
        lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
        queryIntent: 'referencias');
      expect(pt, contains('Sem conteudo clinico adicional'));
      print('  [OK] intent=referencias PT');
    });

    test('intent psicofarmaco — escopo psiquiátrico específico', () {
      final pt = AiService.buildClinicalSystemPrompt(
        lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
        queryIntent: 'psicofarmaco');
      expect(pt, contains('ESPECIFICAMENTE sobre o psicofarmaco'));
      expect(pt, contains('NAO desvie para outros sistemas'));
      print('  [OK] intent=psicofarmaco PT');
    });

    test('intent vazio — escopo abrangente (fallback)', () {
      final pt = AiService.buildClinicalSystemPrompt(
        lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
        queryIntent: '');
      expect(pt, contains('Responda de forma abrangente'));
      print('  [OK] intent vazio → fallback abrangente');
    });
  });

  // ════════════════════════════════════════════════════════════════
  // T4 — Modo emergência
  // ════════════════════════════════════════════════════════════════
  group('T4 — Modo emergência', () {

    test('PT: intent emergencia ativa MODO PLANTAO CRITICO', () {
      final pt = AiService.buildClinicalSystemPrompt(
        lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
        queryIntent: 'emergencia',
        userQuery: 'paciente hipotenso febril lactato alto');
      expect(pt, contains('MODO PLANTAO CRITICO ATIVO'));
      expect(pt, contains('Bullets acionaveis'));
      expect(pt, contains('Direto a estabilizacao'));
      expect(pt, contains('doses usuais baseadas em guidelines'));
      // Não contém "doses exatas" (refinamento anterior)
      expect(pt, isNot(contains('doses exatas')));
      print('  [OK] PT emergencia: MODO PLANTAO CRITICO ativo, sem doses exatas');
    });

    test('ES: intent emergencia ativa MODO GUARDIA CRÍTICA', () {
      final es = AiService.buildClinicalSystemPrompt(
        lang: 'es', matchedProtocolSummaries: [], matchedDrugSummaries: [],
        queryIntent: 'emergencia',
        userQuery: 'paciente hipotension fiebre lactato alto');
      expect(es, contains('MODO GUARDIA CRÍTICA ACTIVO'));
      expect(es, contains('Bullets accionables'));
      expect(es, contains('Directo a estabilizacion'));
      expect(es, contains('dosis habituales basadas en guidelines'));
      expect(es, isNot(contains('dosis exactas')));
      print('  [OK] ES emergencia: MODO GUARDIA CRÍTICA ativo, sem dosis exactas');
    });

    test('Modo emergência: selfCheck presente e após dados RAG', () {
      final pt = AiService.buildClinicalSystemPrompt(
        lang: 'pt', matchedProtocolSummaries: ['prot1'], matchedDrugSummaries: ['drug1'],
        queryIntent: 'emergencia');
      final idxSelf = pt.lastIndexOf('REVISAO_INTERNA');
      final idxProt = pt.lastIndexOf('prot1');
      final idxDrug = pt.lastIndexOf('drug1');
      expect(idxSelf, greaterThan(idxProt));
      expect(idxSelf, greaterThan(idxDrug));
      print('  [OK] selfCheck posicionado após protocolos e fármacos');
    });
  });

  // ════════════════════════════════════════════════════════════════
  // T5 — Differential Engine
  // ════════════════════════════════════════════════════════════════
  group('T5 — Differential Engine', () {

    test('caso_clinico ativa differentialEngine PT', () {
      final pt = AiService.buildClinicalSystemPrompt(
        lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
        queryIntent: 'caso_clinico',
        userQuery: 'paciente com dor toracica e troponina elevada');
      expect(pt, contains('MOTOR DE DIFERENCIAIS'));
      expect(pt, contains('Hipotese PRINCIPAL'));
      expect(pt, contains('Hipotese PERIGOSA'));
      expect(pt, contains('Hipoteses PROVAVEIS'));
      expect(pt, contains('FAVORECE'));
      print('  [OK] caso_clinico PT → differential ativo');
    });

    test('caso_clinico ativa differentialEngine ES', () {
      final es = AiService.buildClinicalSystemPrompt(
        lang: 'es', matchedProtocolSummaries: [], matchedDrugSummaries: [],
        queryIntent: 'caso_clinico',
        userQuery: 'caso clinico dolor toracico troponina elevada');
      expect(es, contains('MOTOR DE DIFERENCIALES'));
      expect(es, contains('Hipotesis PRINCIPAL'));
      expect(es, contains('Hipotesis PELIGROSA'));
      expect(es, contains('FAVORECE'));
      print('  [OK] caso_clinico ES → differential ativo');
    });

    test('emergencia ativa differentialEngine', () {
      final pt = AiService.buildClinicalSystemPrompt(
        lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
        queryIntent: 'emergencia');
      expect(pt, contains('MOTOR DE DIFERENCIAIS'));
      print('  [OK] emergencia PT → differential ativo');
    });

    test('diagnostico ativa differentialEngine', () {
      final pt = AiService.buildClinicalSystemPrompt(
        lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
        queryIntent: 'diagnostico');
      expect(pt, contains('MOTOR DE DIFERENCIAIS'));
      print('  [OK] diagnostico PT → differential ativo');
    });

    test('farmaco NÃO ativa differentialEngine', () {
      final pt = AiService.buildClinicalSystemPrompt(
        lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
        queryIntent: 'farmaco');
      expect(pt, isNot(contains('MOTOR DE DIFERENCIAIS')));
      print('  [OK] farmaco PT → differential NÃO ativo');
    });

    test('tratamento NÃO ativa differentialEngine', () {
      final pt = AiService.buildClinicalSystemPrompt(
        lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
        queryIntent: 'tratamento');
      expect(pt, isNot(contains('MOTOR DE DIFERENCIAIS')));
      print('  [OK] tratamento PT → differential NÃO ativo');
    });

    test('interacao NÃO ativa differentialEngine', () {
      final pt = AiService.buildClinicalSystemPrompt(
        lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
        queryIntent: 'interacao');
      expect(pt, isNot(contains('MOTOR DE DIFERENCIAIS')));
      print('  [OK] interacao PT → differential NÃO ativo');
    });

    test('fisiopatologia NÃO ativa differentialEngine', () {
      final pt = AiService.buildClinicalSystemPrompt(
        lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
        queryIntent: 'fisiopatologia');
      expect(pt, isNot(contains('MOTOR DE DIFERENCIAIS')));
      print('  [OK] fisiopatologia PT → differential NÃO ativo');
    });
  });

  // ════════════════════════════════════════════════════════════════
  // T6 — Tool Calling Engine
  // ════════════════════════════════════════════════════════════════
  group('T6 — Tool Calling Engine', () {

    test('FA 78a HAS AVC → CHA₂DS₂-VASc/HAS-BLED PT', () {
      final tool = AiService.buildToolsBlock(
        'paciente com fibrilacao atrial, 78 anos, HAS e AVC previo', false);
      expect(tool, contains('CHA'));
      expect(tool, contains('HAS-BLED'));
      expect(tool, contains('FERRAMENTA ATIVA'));
      print('  [OK] FA → CHA₂DS₂-VASc/HAS-BLED detectado (PT)');
    });

    test('FA ES → CHA₂DS₂-VASc/HAS-BLED ES', () {
      final tool = AiService.buildToolsBlock(
        'paciente con fibrilacion atrial, 78 años, AVC previo', true);
      expect(tool, contains('CHA'));
      expect(tool, contains('HERRAMIENTA ACTIVA'));
      print('  [OK] FA → CHA₂DS₂-VASc/HAS-BLED detectado (ES)');
    });

    test('Pneumonia idoso confusão ureia alta → CURB-65 PT', () {
      final tool = AiService.buildToolsBlock(
        'pneumonia em idoso com confusao mental e ureia alta', false);
      expect(tool, contains('CURB-65'));
      expect(tool, contains('FERRAMENTA ATIVA'));
      print('  [OK] Pneumonia → CURB-65 detectado (PT)');
    });

    test('CURB-65 ES', () {
      final tool = AiService.buildToolsBlock('pneumonia comunidade gravedad', true);
      expect(tool, contains('CURB-65'));
      print('  [OK] Pneumonia → CURB-65 detectado (ES)');
    });

    test('Sepse lactato → qSOFA/SOFA PT', () {
      final tool = AiService.buildToolsBlock(
        'paciente com sepse, lactato 4.2, foco pulmonar', false);
      expect(tool, contains('qSOFA'));
      expect(tool, contains('SOFA'));
      print('  [OK] Sepse → qSOFA/SOFA detectado (PT)');
    });

    test('Cockcroft-Gault → ajuste renal PT', () {
      final tool = AiService.buildToolsBlock(
        'calcular clearance de creatinina para ajuste de dose', false);
      expect(tool, contains('Cockcroft'));
      print('  [OK] Clearance → Cockcroft-Gault detectado');
    });

    test('Ânion Gap → acidose PT', () {
      final tool = AiService.buildToolsBlock(
        'paciente com acidose metabolica e anion gap elevado', false);
      expect(tool, contains('Anion Gap'));
      print('  [OK] Acidose → Ânion Gap detectado');
    });

    test('VM → ARDSNet PT', () {
      final tool = AiService.buildToolsBlock(
        'paciente em ventilacao mecanica com SDRA, PEEP alto', false);
      expect(tool, contains('ARDSNet'));
      expect(tool, contains('PEEP'));
      print('  [OK] VM → ARDSNet/PEEP detectado');
    });

    test('TEP/Wells → detectado PT', () {
      final tool = AiService.buildToolsBlock(
        'suspeita de tromboembolismo pulmonar, score wells tep', false);
      expect(tool, contains('Wells'));
      print('  [OK] TEP → Wells detectado');
    });

    test('Child-Pugh/MELD → cirrose PT', () {
      final tool = AiService.buildToolsBlock(
        'paciente com cirrose hepatica e ascite', false);
      expect(tool, contains('Child-Pugh'));
      expect(tool, contains('MELD'));
      print('  [OK] Cirrose → Child-Pugh/MELD detectado');
    });

    test('KDIGO → LRA PT', () {
      final tool = AiService.buildToolsBlock(
        'lesao renal aguda, oliguria, kdigo estadiamento', false);
      expect(tool, contains('KDIGO'));
      print('  [OK] LRA → KDIGO detectado');
    });

    test('Pergunta sem contexto de cálculo → toolsBlock vazio', () {
      final t1 = AiService.buildToolsBlock('o que e a sinapse neuromuscular', false);
      final t2 = AiService.buildToolsBlock('mecanismo de acao do captopril', false);
      final t3 = AiService.buildToolsBlock('fisiopatologia do alzheimer', false);
      expect(t1, isEmpty);
      expect(t2, isEmpty);
      expect(t3, isEmpty);
      print('  [OK] Sinapse/captopril/alzheimer → toolsBlock vazio (sem overhead)');
    });

    test('Tool injetada no prompt completo', () {
      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'pt',
        matchedProtocolSummaries: [],
        matchedDrugSummaries: [],
        queryIntent: 'caso_clinico',
        userQuery: 'paciente com fibrilacao atrial cronica, 78 anos, AVC previo');
      expect(prompt, contains('FERRAMENTA ATIVA'));
      expect(prompt, contains('CHA'));
      print('  [OK] Tool injetada corretamente no prompt completo');
    });
  });

  // ════════════════════════════════════════════════════════════════
  // T7 — Memory Block: continuidade + isolamento de tema
  // ════════════════════════════════════════════════════════════════
  group('T7 — Memory Block', () {

    test('memoryBlock injetado quando há dados clínicos', () {
      final mem = ClinicalSessionMemory();
      mem.addProblem('Febre e leucocitose');
      mem.updateRiskLevel('moderate');

      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'pt',
        matchedProtocolSummaries: [],
        matchedDrugSummaries: [],
        memory: mem,
        userQuery: 'paciente ficou hipotenso');
      expect(prompt, contains('CONTEXTO_CLINICO_SESSAO'));
      expect(prompt, contains('Febre e leucocitose'));
      print('  [OK] memoryBlock injetado com problema ativo');
    });

    test('memoryBlock NÃO injetado quando memória está vazia', () {
      final mem = ClinicalSessionMemory(); // vazia

      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'pt',
        matchedProtocolSummaries: [],
        matchedDrugSummaries: [],
        memory: mem);
      expect(prompt, isNot(contains('CONTEXTO_CLINICO_SESSAO')));
      print('  [OK] memoryBlock ausente quando estado vazio');
    });

    test('memoryBlock NÃO injetado quando memory=null (backward compat)', () {
      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'pt',
        matchedProtocolSummaries: [],
        matchedDrugSummaries: []);
      expect(prompt, isNot(contains('CONTEXTO_CLINICO_SESSAO')));
      print('  [OK] memoryBlock ausente com memory=null');
    });

    test('memoryBlock posicionado antes do selfCheck', () {
      final mem = ClinicalSessionMemory();
      mem.addProblem('Sepse');

      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'pt',
        matchedProtocolSummaries: [],
        matchedDrugSummaries: [],
        memory: mem);
      final idxMem  = prompt.indexOf('CONTEXTO_CLINICO_SESSAO');
      final idxSelf = prompt.indexOf('REVISAO_INTERNA');
      expect(idxMem, greaterThan(0));
      expect(idxSelf, greaterThan(idxMem));
      print('  [OK] memoryBlock antes do selfCheck');
    });

    test('reset após mudança de tema — asma não mistura com sepse', () {
      final mem = ClinicalSessionMemory();
      mem.addProblem('Sepse');
      mem.addMedication('Meropenem');
      // Estabelece 2 turnos no tema sepse
      mem.resetIfTopicChanged('sepse e choque');
      mem.resetIfTopicChanged('sepse e lactato alto');
      // Muda para asma
      mem.resetIfTopicChanged('explique asma bronquica patogenese');

      final block = mem.buildMemoryBlock(false);
      expect(block, isEmpty); // estado resetado
      expect(block, isNot(contains('Sepse')));
      expect(block, isNot(contains('Meropenem')));
      print('  [OK] reset após tema asma — sepse não persiste');
    });
  });

  // ════════════════════════════════════════════════════════════════
  // T8 — RAG: protocolsBlock, drugsBlock, contextSection intactos
  // ════════════════════════════════════════════════════════════════
  group('T8 — RAG intacto', () {

    test('protocolsBlock injetado quando não vazio', () {
      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'pt',
        matchedProtocolSummaries: ['Protocolo Sepse — AMIB 2023', 'Bundle 1h'],
        matchedDrugSummaries: []);
      expect(prompt, contains('PROTOCOLOS RELEVANTES'));
      expect(prompt, contains('Protocolo Sepse — AMIB 2023'));
      expect(prompt, contains('Bundle 1h'));
      print('  [OK] protocolsBlock injetado');
    });

    test('drugsBlock injetado quando não vazio', () {
      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'pt',
        matchedProtocolSummaries: [],
        matchedDrugSummaries: ['Noradrenalina — vasopressor de 1ª linha']);
      expect(prompt, contains('FARMACOS RELEVANTES'));
      expect(prompt, contains('Noradrenalina'));
      print('  [OK] drugsBlock injetado');
    });

    test('contextSection injetada quando >50 chars', () {
      const ctx = 'Este contexto local tem mais de cinquenta caracteres para ativar a secao';
      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'pt',
        matchedProtocolSummaries: [],
        matchedDrugSummaries: [],
        localAnswerContext: ctx);
      expect(prompt, contains('CONTEXTO_BASE_INTERNA'));
      expect(prompt, contains(ctx));
      expect(prompt, contains('FIM_CONTEXTO'));
      print('  [OK] contextSection injetada (>50 chars)');
    });

    test('contextSection NÃO injetada quando <50 chars', () {
      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'pt',
        matchedProtocolSummaries: [],
        matchedDrugSummaries: [],
        localAnswerContext: 'curto');
      expect(prompt, isNot(contains('CONTEXTO_BASE_INTERNA')));
      print('  [OK] contextSection ausente para texto curto');
    });

    test('ES: labels RAG em espanhol', () {
      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'es',
        matchedProtocolSummaries: ['Protocolo Sepsis'],
        matchedDrugSummaries: ['Norepinefrina'],
        localAnswerContext: 'contexto con mas de cincuenta caracteres para activar la seccion local');
      expect(prompt, contains('PROTOCOLOS RELEVANTES'));
      expect(prompt, contains('FARMACOS RELEVANTES'));
      expect(prompt, contains('CONTEXTO_BASE_INTERNA'));
      expect(prompt, contains('FIN_CONTEXTO'));
      print('  [OK] RAG ES — labels corretos');
    });

    test('patientBlock injetado com dados do paciente', () {
      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'pt',
        matchedProtocolSummaries: [],
        matchedDrugSummaries: [],
        patientAge: '72',
        patientSex: 'F',
        patientWeight: '65',
        patientClcr: '28');
      expect(prompt, contains('Paciente: 72 anos'));
      expect(prompt, contains('ClCr: 28 mL/min'));
      print('  [OK] patientBlock injetado com idade/sexo/peso/ClCr');
    });

    test('RAG e memoryBlock coexistem no mesmo prompt', () {
      final mem = ClinicalSessionMemory();
      mem.addProblem('IAM');

      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'pt',
        matchedProtocolSummaries: ['protocolo_iam'],
        matchedDrugSummaries: ['aspirina_entry'],
        memory: mem,
        queryIntent: 'emergencia');
      expect(prompt, contains('CONTEXTO_CLINICO_SESSAO'));
      expect(prompt, contains('PROTOCOLOS RELEVANTES'));
      expect(prompt, contains('FARMACOS RELEVANTES'));
      expect(prompt, contains('REVISAO_INTERNA'));
      print('  [OK] RAG + memoryBlock + selfCheck coexistem');
    });
  });

  // ════════════════════════════════════════════════════════════════
  // T9 — Self-Check Loop
  // ════════════════════════════════════════════════════════════════
  group('T9 — Self-Check Loop', () {

    test('selfCheck PT presente em todos os intents', () {
      for (final intent in ['tratamento', 'farmaco', 'emergencia', 'caso_clinico',
                            'diagnostico', 'interacao', 'causas', '']) {
        final pt = AiService.buildClinicalSystemPrompt(
          lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
          queryIntent: intent);
        expect(pt, contains('REVISAO_INTERNA'),
          reason: 'selfCheck ausente para intent=$intent');
        expect(pt, contains('FIM_REVISAO_INTERNA'),
          reason: 'selfCheck FIM ausente para intent=$intent');
      }
      print('  [OK] selfCheck PT presente em todos os intents');
    });

    test('selfCheck ES presente em todos os intents', () {
      for (final intent in ['tratamento', 'farmaco', 'emergencia', 'caso_clinico', '']) {
        final es = AiService.buildClinicalSystemPrompt(
          lang: 'es', matchedProtocolSummaries: [], matchedDrugSummaries: [],
          queryIntent: intent);
        expect(es, contains('REVISION_INTERNA'),
          reason: 'selfCheck ES ausente para intent=$intent');
      }
      print('  [OK] selfCheck ES presente em todos os intents');
    });

    test('selfCheck contém as 5 dimensões de revisão PT', () {
      final pt = AiService.buildClinicalSystemPrompt(
        lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
        patientWeight: '70', patientClcr: '25');
      expect(pt, contains('DOSES'));
      expect(pt, contains('CONTRAINDICACOES'));
      expect(pt, contains('INTERACOES'));
      expect(pt, contains('COERENCIA'));
      expect(pt, contains('CERTEZA'));
      print('  [OK] selfCheck PT — 5 dimensões presentes');
    });

    test('selfCheck é a ÚLTIMA instrução significativa (após todos RAG)', () {
      final mem = ClinicalSessionMemory();
      mem.addProblem('IAM');

      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'pt',
        matchedProtocolSummaries: ['prot_teste'],
        matchedDrugSummaries: ['drug_teste'],
        localAnswerContext: 'contexto local com mais de cinquenta caracteres para ativar injecao',
        memory: mem,
        queryIntent: 'emergencia',
        userQuery: 'paciente com IAM e choque cardiogenico');

      final idxSelf    = prompt.lastIndexOf('REVISAO_INTERNA');
      final idxProt    = prompt.lastIndexOf('prot_teste');
      final idxDrug    = prompt.lastIndexOf('drug_teste');
      final idxContext = prompt.lastIndexOf('CONTEXTO_BASE_INTERNA');
      final idxMem     = prompt.lastIndexOf('CONTEXTO_CLINICO_SESSAO');

      expect(idxSelf, greaterThan(idxProt),    reason: 'selfCheck deve ser após protocolos');
      expect(idxSelf, greaterThan(idxDrug),    reason: 'selfCheck deve ser após fármacos');
      expect(idxSelf, greaterThan(idxContext), reason: 'selfCheck deve ser após contextSection');
      expect(idxSelf, greaterThan(idxMem),     reason: 'selfCheck deve ser após memoryBlock');
      print('  [OK] selfCheck é o último bloco — após prot/drug/context/memory');
    });
  });

  // ════════════════════════════════════════════════════════════════
  // T10 — Velocidade: sem overhead para perguntas simples
  // ════════════════════════════════════════════════════════════════
  group('T10 — Controle de tamanho de prompt', () {

    test('prompt mínimo (sem RAG, sem memory, sem tools, sem differential)', () {
      final sw = Stopwatch()..start();
      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'pt',
        matchedProtocolSummaries: [],
        matchedDrugSummaries: [],
        queryIntent: 'farmaco',
        userQuery: 'o que e o IAM');
      sw.stop();

      // Sem differential (farmaco), sem tools (IAM simples), sem memory
      expect(prompt, isNot(contains('MOTOR DE DIFERENCIAIS')));
      expect(prompt, isNot(contains('FERRAMENTA ATIVA')));
      expect(prompt, isNot(contains('CONTEXTO_CLINICO_SESSAO')));
      // Deve ter os módulos base
      expect(prompt, contains('REVISAO_INTERNA'));
      expect(prompt, contains('GRADUACAO DE EVIDENCIA'));
      // Construção deve ser < 5ms (pura string concatenation)
      expect(sw.elapsedMilliseconds, lessThan(5));
      print('  [OK] Prompt mínimo: ${prompt.length} chars, '
            'construído em ${sw.elapsedMilliseconds}ms');
    });

    test('prompt máximo (RAG + memory + tools + differential)', () {
      final mem = ClinicalSessionMemory();
      mem.addProblem('IAM');
      mem.addMedication('Heparina');
      mem.updateRiskLevel('critical');

      final sw = Stopwatch()..start();
      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'pt',
        matchedProtocolSummaries: List.generate(5, (i) => 'protocolo_$i'),
        matchedDrugSummaries: List.generate(5, (i) => 'farmaco_$i'),
        localAnswerContext: 'contexto local extenso com mais de cinquenta caracteres para ativar a secao',
        queryIntent: 'caso_clinico',
        memory: mem,
        userQuery: 'paciente com fibrilacao atrial e sepse concomitante',
        patientAge: '72', patientSex: 'M', patientWeight: '75', patientClcr: '35');
      sw.stop();

      // Deve ter TODOS os blocos
      expect(prompt, contains('MOTOR DE DIFERENCIAIS'));
      expect(prompt, contains('FERRAMENTA ATIVA'));
      expect(prompt, contains('CONTEXTO_CLINICO_SESSAO'));
      expect(prompt, contains('PROTOCOLOS RELEVANTES'));
      expect(prompt, contains('FARMACOS RELEVANTES'));
      expect(prompt, contains('REVISAO_INTERNA'));
      // Construção deve ser < 10ms mesmo com tudo ativo
      expect(sw.elapsedMilliseconds, lessThan(10));
      print('  [OK] Prompt máximo: ${prompt.length} chars, '
            'construído em ${sw.elapsedMilliseconds}ms');
    });

    test('differential NÃO injetado em perguntas simples de dose', () {
      for (final intent in ['farmaco', 'tratamento', 'interacao',
                            'fisiopatologia', 'causas', 'prognostico']) {
        final p = AiService.buildClinicalSystemPrompt(
          lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
          queryIntent: intent);
        expect(p, isNot(contains('MOTOR DE DIFERENCIAIS')),
          reason: 'Differential injetado em intent=$intent (não deveria)');
      }
      print('  [OK] Differential ausente em todos intents não-diagnósticos');
    });

    test('Evidence Ranking sempre presente — módulo leve', () {
      final p = AiService.buildClinicalSystemPrompt(
        lang: 'pt', matchedProtocolSummaries: [], matchedDrugSummaries: [],
        queryIntent: 'farmaco');
      expect(p, contains('GRADUACAO DE EVIDENCIA'));
      // Apenas 4 linhas — deve ser compacto
      final evLines = 'GRADUACAO DE EVIDENCIA'.allMatches(p).length;
      expect(evLines, equals(1)); // aparece exatamente 1 vez
      print('  [OK] Evidence Ranking presente e único (1 ocorrência)');
    });
  });
}
