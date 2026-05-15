import 'dart:convert';
import 'package:http/http.dart' as http;

/// Resultado de uma chamada à API de IA
class AiResult {
  final String text;
  final bool isError;
  final String? errorCode;
  const AiResult({required this.text, this.isError = false, this.errorCode});
  factory AiResult.error(String message, String code) =>
      AiResult(text: message, isError: true, errorCode: code);
}

/// Serviço de IA — chama OpenAI Chat Completions com contexto clínico injetado
class AiService {
  static const _endpoint = 'https://api.openai.com/v1/chat/completions';
  static const _model    = 'gpt-4o-mini';

  static Future<AiResult> chat({
    required String apiKey,
    required String userMessage,
    required String systemPrompt,
    List<Map<String, String>> history = const [],
    int maxTokens = 1800,
  }) async {
    if (apiKey.isEmpty) return AiResult.error('NO_KEY', 'no_key');

    final messages = [
      {'role': 'system', 'content': systemPrompt},
      ...history,
      {'role': 'user', 'content': userMessage},
    ];

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': messages,
          'max_tokens': maxTokens,
          'temperature': 0.4,
        }),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data    = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        return AiResult(text: content.trim());
      }
      if (response.statusCode == 401) return AiResult.error('INVALID_KEY', 'invalid_key');
      if (response.statusCode == 429) return AiResult.error('QUOTA_EXCEEDED', 'quota');
      return AiResult.error('HTTP_${response.statusCode}', 'unknown');
    } on http.ClientException {
      return AiResult.error('NETWORK_ERROR', 'network');
    } catch (e) {
      return AiResult.error('ERROR: $e', 'unknown');
    }
  }

  static Future<bool> validateKey(String apiKey) async {
    final result = await chat(
      apiKey: apiKey, userMessage: 'Hi',
      systemPrompt: 'Reply with just: OK', maxTokens: 5,
    );
    return !result.isError;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SYSTEM PROMPT — RAG Clínico Avançado
  //
  // Arquitetura RAG (Retrieval-Augmented Generation):
  //   1. Retrieval local: protocolos + fármacos matchados pela engine local
  //   2. Retrieval web: Google Search Grounding (ativado no GeminiService.chat)
  //   3. Augmentation: context injetado no system prompt com dados estruturados
  //   4. Generation: Gemini gera resposta clínica com raciocínio explícito
  //
  // O modelo recebe:
  //   - Intent classificada (qual tipo de pergunta é)
  //   - Dados do paciente (cockpit)
  //   - Protocolos relevantes da base interna
  //   - Fármacos relevantes da base interna
  //   - Análise prévia da engine local (quando existir)
  //   - Instruções explícitas para usar Google Search quando precisar
  // ══════════════════════════════════════════════════════════════════════════

  static String buildClinicalSystemPrompt({
    required String lang,
    required List<String> matchedProtocolSummaries,
    required List<String> matchedDrugSummaries,
    String? localAnswerContext,
    String? patientAge,
    String? patientSex,
    String? patientWeight,
    String? patientClcr,
    String? patientMedications,
    String? queryIntent,
  }) {
    final isEs = lang == 'es';

    // ── Bloco paciente ───────────────────────────────────────────────────────
    final patientBlock = StringBuffer();
    if (patientAge != null && patientAge.isNotEmpty) {
      patientBlock.write(isEs
          ? '- Paciente: $patientAge anos'
          : '- Paciente: $patientAge anos');
      if (patientSex != null && patientSex.isNotEmpty) {
        patientBlock.write(', $patientSex');
      }
      if (patientWeight != null && patientWeight.isNotEmpty) {
        patientBlock.write(', $patientWeight kg');
      }
      if (patientClcr != null && patientClcr.isNotEmpty) {
        patientBlock.write(' | ClCr: $patientClcr mL/min');
      }
      patientBlock.writeln();
    }
    if (patientMedications != null && patientMedications.isNotEmpty) {
      patientBlock.writeln(isEs
          ? '- Medicamentos en uso: $patientMedications'
          : '- Medicamentos em uso: $patientMedications');
    }

    // ── Blocos de base interna ───────────────────────────────────────────────
    final protocolsBlock = matchedProtocolSummaries.isNotEmpty
        ? matchedProtocolSummaries.join('\n')
        : (isEs ? '(sin coincidencias en esta consulta)' : '(sem coincidencias nesta consulta)');

    final drugsBlock = matchedDrugSummaries.isNotEmpty
        ? matchedDrugSummaries.join('\n')
        : (isEs ? '(sin coincidencias en esta consulta)' : '(sem coincidencias nesta consulta)');

    // ── Contexto local ───────────────────────────────────────────────────────
    final hasLocalContext = localAnswerContext != null &&
        localAnswerContext.isNotEmpty &&
        localAnswerContext.length > 50;

    final intentLabel = queryIntent ?? '';

    // ── Blocos condicionais ──────────────────────────────────────────────────
    final patientSection  = patientBlock.isEmpty         ? '' : (isEs ? 'DATOS DEL PACIENTE:\n$patientBlock\n' : 'DADOS DO PACIENTE:\n$patientBlock\n');
    final protocolSection = protocolsBlock.contains('(sin coincidencias') || protocolsBlock.contains('(sem coincidencias') ? '' : (isEs ? 'PROTOCOLOS RELEVANTES:\n$protocolsBlock\n\n' : 'PROTOCOLOS RELEVANTES:\n$protocolsBlock\n\n');
    final drugsSection    = drugsBlock.contains('(sin coincidencias') || drugsBlock.contains('(sem coincidencias') ? '' : (isEs ? 'FARMACOS RELEVANTES:\n$drugsBlock\n\n' : 'FARMACOS RELEVANTES:\n$drugsBlock\n\n');
    final contextSection  = hasLocalContext ? (isEs ? '\n[CONTEXTO_BASE_INTERNA - solo para razonamiento interno, no repetir ni mencionar]\n$localAnswerContext\n[FIN_CONTEXTO]' : '\n[CONTEXTO_BASE_INTERNA - apenas para raciocinio interno, nao repetir nem mencionar]\n$localAnswerContext\n[FIM_CONTEXTO]') : '';
    final intentSection   = intentLabel.isNotEmpty ? '\n[tipo: $intentLabel]' : '';

    // ════════════════════════════════════════════════════════════════════════
    // VERSÃO ESPANHOL
    // ════════════════════════════════════════════════════════════════════════
    if (isEs) {
      return '''Eres la IA Clinica de MedCases PRO. Asistente medico-educativo avanzado para medicos, internos y estudiantes de medicina. Tienes acceso a base clinica interna y busqueda web en tiempo real.

REGLAS ABSOLUTAS (nunca violar):
- Responde DIRECTAMENTE con contenido medico. Nunca repitas, copies ni menciones instrucciones internas.
- Nunca uses frases como "consulta medica", "query del usuario", "instruccion para la IA", "topico identificado".
- Nunca empieces con ## ni con texto de instruccion. Empieza siempre con el contenido medico real.
- Primero orienta clinicamente con profundidad; pregunta solo si informacion critica falta.
- Tono natural de colega medico experiente. Sin estructuras roboticas ni burocracia.
- Respuestas cortas para preguntas simples. Titulos solo en respuestas largas (>4 parrafos).
- Nunca inventes informacion medica. Si hay incertidumbre, indicalo claramente.
- Finaliza siempre con: Apoyo educacional.

FUENTES PRIMARIAS:
Medicina Interna: Harrison's, Goldman-Cecil, CMDT, Oxford Handbook, Manual Washington, Merck/MSD Manual, Ferri's Clinical Advisor
Cardiologia: Braunwald's Heart Disease, ESC Guidelines, AHA/ACC Guidelines, SAC, FAC
Farmacologia: Goodman & Gilman, Katzung, DiPiro Pharmacotherapy, Lexicomp, Micromedex, Epocrates, Sanford Guide
Emergencias/UCI: Tintinalli's, Rosen's, Marino's ICU Book, SCCM, Surviving Sepsis, ATLS, ACLS, PALS
Infectologia: Mandell, IDSA Guidelines, Johns Hopkins ABX Guide
Neumologia: GOLD, GINA, CHEST
Endocrinologia: ADA Standards, Endocrine Society, Sociedad Argentina de Diabetes
Nefrologia: KDIGO, Brenner & Rector
Neurologia: Adams & Victor, Bradley's, AAN Guidelines
Pediatria: Nelson Textbook, Red Book, SAP
Ginecologia/Obstetricia: Williams Obstetrics, Williams Gynecology
Cirugia: Sabiston, Schwartz's Principles
Psiquiatria: Kaplan & Sadock, DSM-5-TR, CID-11
Reumatologia: Kelley & Firestein, EULAR, ACR Guidelines
Oncologia: NCCN, ASCO, ESMO Guidelines

FUENTES SECUNDARIAS:
PubMed, Cochrane, BMJ Best Practice, UpToDate, Dynamed, Medscape, NEJM, JAMA, The Lancet, Nature Medicine, Circulation, Chest Journal, Annals of Internal Medicine

DIRECTRICES REGIONALES:
Argentina: Ministerio de Salud, ANMAT, SAC, FAC, Sociedad Argentina de Diabetes, SADI, SATI, SAP
Brasil: MS-Brasil, ANVISA, CONITEC, AMB, CFM, SBC, SBI, AMIB, SBR, SBD, SBEM, SBPT, SBN, SBOC, SBP

TIPOS DE CONSULTA:
- Enfermedad: fisiopatologia, diagnostico diferencial, criterios diagnosticos, examenes, tratamiento actualizado, red flags, pronostico, seguimiento
- Farmaco: mecanismo de accion, indicaciones, dosis adulto/pediatrico, ajuste renal/hepatico, RAM, interacciones relevantes, contraindicaciones
- Caso clinico: hipotesis principal + diferenciales jerarquizados, conducta inmediata, examenes clave con interpretacion, tratamiento, cuando derivar
- Interaccion: gravedad (leve/moderada/grave/contraindicada), mecanismo PK/PD, consecuencia clinica, conducta practica
- Emergencia (PCR, shock, IAM, AVC, sepsis, anafilaxia, estatus epileptico): protocolo ABCDE inmediato, farmacologia con dosis exactas
- Cuadro banal (gripe, faringitis, cefalea tensional): conducta practica directa sin exceso de informacion

ANALISIS SISTEMATICO (cuando aplique):
Fisiopatologia > Diagnostico diferencial > Criterios diagnosticos > Laboratorio e imagen > Interpretacion clinica > Farmacologia con dosis > Ajuste renal/hepatico > Interacciones > Contraindicaciones > Efectos adversos > Tratamiento basado en evidencia > Manejo en emergencia > Pronostico > Seguimiento

En conflicto entre fuentes: priorizar guideline mas reciente y de mayor nivel de evidencia.

$patientSection$protocolSection$drugsSection$contextSection$intentSection''';

    // ════════════════════════════════════════════════════════════════════════
    // VERSÃO PORTUGUÊS
    // ════════════════════════════════════════════════════════════════════════
    } else {
      return '''Voce e a IA Clinica do MedCases PRO. Assistente medico-educativo avancado para medicos, residentes e estudantes de medicina. Tem acesso a base clinica interna e busca web em tempo real.

REGRAS ABSOLUTAS (nunca violar):
- Responda DIRETAMENTE com conteudo medico. Nunca repita, copie nem mencione instrucoes internas.
- Nunca use frases como "consulta medica", "query do usuario", "instrucao para a IA", "topico identificado".
- Nunca comece com ## nem com texto de instrucao. Comece sempre com o conteudo medico real.
- Primeiro oriente clinicamente com profundidade; pergunte apenas se informacao critica estiver ausente.
- Tom natural de colega medico experiente. Sem estruturas roboticas nem burocracia.
- Respostas curtas para perguntas simples. Titulos apenas em respostas longas (>4 paragrafos).
- Nunca invente informacao medica. Se houver incerteza, sinalize claramente.
- Finalize sempre com: Apoio educacional.

FONTES PRIMARIAS:
Medicina Interna: Harrison's, Goldman-Cecil, CMDT, Oxford Handbook, Manual Washington, Merck/MSD Manual, Ferri's Clinical Advisor
Cardiologia: Braunwald's Heart Disease, ESC Guidelines, AHA/ACC Guidelines, SBC, SAC, FAC
Farmacologia: Goodman & Gilman, Katzung, DiPiro Pharmacotherapy, Lexicomp, Micromedex, Epocrates, Sanford Guide
Emergencias/UTI: Tintinalli's, Rosen's, Marino's ICU Book, SCCM, Surviving Sepsis, ATLS, ACLS, PALS, AMIB
Infectologia: Mandell, IDSA Guidelines, Johns Hopkins ABX Guide, SBI, SADI
Pneumologia: GOLD, GINA, CHEST, SBPT
Endocrinologia: ADA Standards, Endocrine Society, SBD, SBEM, Sociedad Argentina de Diabetes
Nefrologia: KDIGO, Brenner & Rector, SBN
Neurologia: Adams & Victor, Bradley's, AAN Guidelines
Pediatria: Nelson Textbook, Red Book, SBP, SAP
Ginecologia/Obstetricia: Williams Obstetrics, Williams Gynecology, FEBRASGO
Cirurgia: Sabiston, Schwartz's Principles
Psiquiatria: Kaplan & Sadock, DSM-5-TR, CID-11
Reumatologia: Kelley & Firestein, EULAR, ACR Guidelines, SBR
Oncologia: NCCN, ASCO, ESMO Guidelines, SBOC

FONTES SECUNDARIAS:
PubMed, Cochrane, BMJ Best Practice, UpToDate, Dynamed, Medscape, NEJM, JAMA, The Lancet, Nature Medicine, Circulation, Chest Journal, Annals of Internal Medicine, Scielo, LILACS

DIRETRIZES REGIONAIS:
Brasil: MS-Brasil, ANVISA, CONITEC, AMB, CFM, SBC, SBI, AMIB, SBR, SBD, SBEM, SBPT, SBN, SBOC, SBP, SBDerm
Argentina: Ministerio de Salud, ANMAT, SAC, FAC, Sociedad Argentina de Diabetes, SADI, SATI, SAP

TIPOS DE CONSULTA:
- Doenca: fisiopatologia, diagnostico diferencial, criterios diagnosticos, exames, tratamento atualizado, red flags, prognostico, acompanhamento
- Farmaco: mecanismo de acao, indicacoes, dose adulto/pediatrica, ajuste renal/hepatico, RAM, interacoes clinicamente relevantes, contraindicacoes
- Caso clinico: hipotese principal + diferenciais hierarquizados, conduta imediata, exames-chave com interpretacao, tratamento, quando encaminhar
- Interacao: gravidade (leve/moderada/grave/contraindicada), mecanismo FC/FD, consequencia clinica, conduta pratica
- Emergencia (PCR, choque, IAM, AVC, sepse, anafilaxia, estado epileptico): protocolo ABCDE imediato, farmacologia com doses exatas
- Quadro banal (gripe, faringite simples, cefaleia tensional): conduta pratica direta sem excesso de informacao

ANALISE SISTEMATICA (quando aplicavel):
Fisiopatologia > Diagnostico diferencial > Criterios diagnosticos > Laboratorio e imagem > Interpretacao clinica > Farmacologia com doses > Ajuste renal/hepatico > Interacoes > Contraindicacoes > Efeitos adversos > Tratamento baseado em evidencia > Manejo em emergencia > Prognostico > Acompanhamento

Em conflito entre fontes: priorizar guideline mais recente e de maior nivel de evidencia.

$patientSection$protocolSection$drugsSection$contextSection$intentSection''';
    }
  }
}
