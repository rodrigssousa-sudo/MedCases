// ─────────────────────────────────────────────────────────────────────────────
// SoapCopilotService — Build 165 — Parsing Blindado Anti-Apagão O-A-P
//
// BUG CRÍTICO CORRIGIDO (Build 165):
//   CAUSA RAIZ: O schema aninhado do nó 'objetivo' (signosVitales/examenFisico/
//   examenes como sub-objetos) causava colapso silencioso — o Gemini às vezes
//   emitia os campos em flat direto dentro de 'objetivo' em vez de nos sub-nós.
//   Resultado: try-catch não disparava erro (JSON válido), mas os campos ficavam
//   em nível errado → O/A/P ficavam vazios.
//
// FIX APLICADO:
//   1. Schema do 'objetivo' ACHATADO: signosVitales.pa → pa_sv, fc_sv etc.
//      Sub-objetos eliminados — campos diretos no nó 'objetivo'.
//   2. Parser dual-mode: tenta nested PRIMEIRO (backward compat) → fallback flat
//   3. Prints verbosos em CADA campo para diagnóstico no console Flutter
//   4. farmacos em try-catch TOTALMENTE isolado — nunca pode contaminar O/A/P
//   5. maxOutputTokens: 2048 → 4096 (objetivo complexo precisava de mais tokens)
//
// Mudanças Build 162.2 (mantidas):
//   catch(e, stack) em nós O/A/P/farmacos — stack trace completo
//   'dosagem' → 'dosis' no responseSchema e fromJson
//   'required' array no root do responseSchema
//   safeInt para diaInternacion clamp 1–90
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
// dart:typed_data is transitively available via flutter/foundation.dart
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ── Resultado do draft da IA — todos os campos são nullable ──────────────────
class SoapDraftResult {
  // ── DEMOGRÁFICOS DO PACIENTE ──────────────────────────────────────────────
  final String? pacienteNome;
  final String? pacienteCama;
  final String? pacienteIdade;
  final String? pacienteSexo;
  final String? pacienteDiagnostico;
  final int?    pacienteDiaInternacion;

  // ── S — Subjetivo ─────────────────────────────────────────────────────────
  final String? notePasaNoche;
  final int?    dolorEscala;
  final bool?   fiebre;
  final bool?   disnea;
  final bool?   nauseas;
  final bool?   tos;
  final String? alimentacion;
  final String? diuresis;
  final String? evacuacion;
  final bool?   suenoRestado;
  final String? notasLibresSubjetivo;

  // ── O — Signos vitales ────────────────────────────────────────────────────
  final String? pa;
  final String? fc;
  final String? fr;
  final String? satO2;
  final String? temperatura;

  // ── O — Examen físico ─────────────────────────────────────────────────────
  final String? estadoGeneral;
  final String? acv;
  final String? ar;
  final String? abdomen;
  final String? extremidades;

  // ── O — Exámenes complementarios ─────────────────────────────────────────
  final String? laboratorio;
  final String? imagenes;
  final String? culturas;
  final String? ecg;
  final String? tratamientoActual;

  // ── A — Evaluación ───────────────────────────────────────────────────────
  final String?       estadoClinical;
  final List<String>? problemasActivos;
  final String?       notasEvaluacion;

  // ── P — Plan ──────────────────────────────────────────────────────────────
  final String? planTerapeutico;
  final String? criteriosAlta;

  // ── Fármacos ──────────────────────────────────────────────────────────────
  final List<Map<String, String>>? farmacos;

  const SoapDraftResult({
    this.pacienteNome,
    this.pacienteCama,
    this.pacienteIdade,
    this.pacienteSexo,
    this.pacienteDiagnostico,
    this.pacienteDiaInternacion,
    this.notePasaNoche,
    this.dolorEscala,
    this.fiebre,
    this.disnea,
    this.nauseas,
    this.tos,
    this.alimentacion,
    this.diuresis,
    this.evacuacion,
    this.suenoRestado,
    this.notasLibresSubjetivo,
    this.pa,
    this.fc,
    this.fr,
    this.satO2,
    this.temperatura,
    this.estadoGeneral,
    this.acv,
    this.ar,
    this.abdomen,
    this.extremidades,
    this.laboratorio,
    this.imagenes,
    this.culturas,
    this.ecg,
    this.tratamientoActual,
    this.estadoClinical,
    this.problemasActivos,
    this.notasEvaluacion,
    this.planTerapeutico,
    this.criteriosAlta,
    this.farmacos,
  });

  bool get hasPatientData =>
      pacienteNome?.isNotEmpty == true ||
      pacienteCama?.isNotEmpty == true ||
      pacienteIdade?.isNotEmpty == true ||
      pacienteDiagnostico?.isNotEmpty == true;

  int get filledCount {
    int n = 0;
    if (notePasaNoche?.isNotEmpty == true) n++;
    if (dolorEscala != null) n++;
    if (fiebre == true) n++;
    if (disnea == true) n++;
    if (nauseas == true) n++;
    if (tos == true) n++;
    if (alimentacion?.isNotEmpty == true) n++;
    if (diuresis?.isNotEmpty == true) n++;
    if (evacuacion?.isNotEmpty == true) n++;
    if (pa?.isNotEmpty == true) n++;
    if (fc?.isNotEmpty == true) n++;
    if (fr?.isNotEmpty == true) n++;
    if (satO2?.isNotEmpty == true) n++;
    if (temperatura?.isNotEmpty == true) n++;
    if (estadoGeneral?.isNotEmpty == true) n++;
    if (acv?.isNotEmpty == true) n++;
    if (ar?.isNotEmpty == true) n++;
    if (abdomen?.isNotEmpty == true) n++;
    if (extremidades?.isNotEmpty == true) n++;
    if (laboratorio?.isNotEmpty == true) n++;
    if (imagenes?.isNotEmpty == true) n++;
    if (culturas?.isNotEmpty == true) n++;
    if (ecg?.isNotEmpty == true) n++;
    if (tratamientoActual?.isNotEmpty == true) n++;
    if (estadoClinical?.isNotEmpty == true) n++;
    if (problemasActivos?.isNotEmpty == true) n++;
    if (notasEvaluacion?.isNotEmpty == true) n++;
    if (planTerapeutico?.isNotEmpty == true) n++;
    if (criteriosAlta?.isNotEmpty == true) n++;
    if (farmacos?.isNotEmpty == true) n++;
    return n;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Parser blindado — try-catch TOTALMENTE independente por nó
  // Build 165: cada campo do nó O tem try-catch individual + dual-mode lookup
  // ═══════════════════════════════════════════════════════════════════════════
  factory SoapDraftResult.fromJson(Map<String, dynamic> json) {

    // ── Helpers de conversão segura ─────────────────────────────────────────
    String? safeStr(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    int? safeInt(dynamic v, {int min = 0, int max = 10}) {
      if (v == null) return null;
      if (v is num) return v.toInt().clamp(min, max);
      final parsed = int.tryParse(v.toString().trim());
      return parsed?.clamp(min, max);
    }

    bool? safeBool(dynamic v) {
      if (v == null) return null;
      if (v is bool) return v;
      switch (v.toString().toLowerCase().trim()) {
        case 'true': case '1': case 'yes': return true;
        case 'false': case '0': case 'no': return false;
        default: return null;
      }
    }

    Map<String, dynamic> safeMap(dynamic v) {
      if (v is Map<String, dynamic>) return v;
      if (v is Map) {
        try { return Map<String, dynamic>.from(v); } catch (_) {}
      }
      return {};
    }

    // Helper: lê campo tentando chave primária e fallback alternativa
    String? dualRead(Map<String, dynamic> m, String primary, [String? alt]) {
      final v = safeStr(m[primary]);
      if (v != null) return v;
      if (alt != null) return safeStr(m[alt]);
      return null;
    }

    // ── LOG: chaves root presentes no JSON ──────────────────────────────────
    debugPrint('🤖 [SoapParser] Build 165 — keys root: ${json.keys.toList()}');

    // ── Nó DEMOGRÁFICO ──────────────────────────────────────────────────────
    String? pNome, pCama, pIdade, pSexo, pDiag;
    int? pDia;
    try {
      final pac = safeMap(json['paciente']);
      debugPrint('🤖 [SoapParser] paciente keys: ${pac.keys.toList()}');
      pNome  = safeStr(pac['nome']);
      pCama  = safeStr(pac['cama']);
      pIdade = safeStr(pac['idade']);
      final sexoRaw = safeStr(pac['sexo'])?.toUpperCase();
      pSexo  = (sexoRaw == 'M' || sexoRaw == 'F') ? sexoRaw : null;
      pDiag  = safeStr(pac['diagnostico']);
      pDia   = safeInt(pac['diaInternacion'], min: 1, max: 90);
      debugPrint('🤖 [SoapParser] paciente → nome=$pNome cama=$pCama diag=$pDiag dia=$pDia');
    } catch (e, stack) {
      debugPrint('💥 [SoapParser] ERRO PARSE PACIENTE: $e\n$stack');
    }

    // ── Nó S — Subjetivo ────────────────────────────────────────────────────
    String? notePasaNoche, alimentacion, diuresis, evacuacion, notasLibres;
    int? dolorEscala;
    bool? fiebre, disnea, nauseas, tos, suenoRestado;
    try {
      final s = safeMap(json['subjetivo']);
      debugPrint('🤖 [SoapParser] subjetivo keys: ${s.keys.toList()}');
      notePasaNoche = safeStr(s['notePasaNoche']);
      dolorEscala   = safeInt(s['dolorEscala']);
      fiebre        = safeBool(s['fiebre']);
      disnea        = safeBool(s['disnea']);
      nauseas       = safeBool(s['nauseas']);
      tos           = safeBool(s['tos']);
      alimentacion  = safeStr(s['alimentacion']);
      diuresis      = safeStr(s['diuresis']);
      evacuacion    = safeStr(s['evacuacion']);
      suenoRestado  = safeBool(s['suenoRestado']);
      notasLibres   = safeStr(s['notasLibres']);
      final sPreview = notePasaNoche ?? '';
      debugPrint('🤖 [SoapParser] S → notePasaNoche=${sPreview.substring(0, sPreview.length.clamp(0, 40))} dolor=$dolorEscala fiebre=$fiebre');
    } catch (e, stack) {
      debugPrint('💥 [SoapParser] ERRO PARSE SUBJETIVO (S): $e\n$stack');
    }

    // ── Nó O — Objetivo — DUAL-MODE: flat (Build 165) + nested (legacy) ────
    // Build 165 FIX CRÍTICO: O schema agora emite os campos FLAT dentro de
    // 'objetivo'. O parser tenta nested PRIMEIRO (compatibilidade) e faz
    // fallback para flat se nested vier vazio.
    String? pa, fc, fr, satO2, temperatura;
    String? estadoGeneral, acv, ar, abdomen, extremidades;
    String? laboratorio, imagenes, culturas, ecg, tratamientoActual;
    try {
      final o = safeMap(json['objetivo']);
      debugPrint('🤖 [SoapParser] objetivo keys: ${o.keys.toList()}');

      // ── Signos Vitais: tenta sub-nó → fallback campos flat ────────────────
      try {
        final sv = safeMap(o['signosVitales']);
        pa          = safeStr(sv['pa'])          ?? safeStr(o['pa']);
        fc          = safeStr(sv['fc'])          ?? safeStr(o['fc']);
        fr          = safeStr(sv['fr'])          ?? safeStr(o['fr']);
        satO2       = safeStr(sv['satO2'])       ?? safeStr(o['satO2']);
        temperatura = safeStr(sv['temperatura']) ?? safeStr(o['temperatura']);
        debugPrint('🤖 [SoapParser] O-vitais → PA=$pa FC=$fc FR=$fr satO2=$satO2 T=$temperatura');
      } catch (e, stack) {
        debugPrint('💥 [SoapParser] ERRO PARSE O-VITAIS: $e\n$stack');
      }

      // ── Exame Físico: tenta sub-nó → fallback campos flat ────────────────
      try {
        final ef = safeMap(o['examenFisico']);
        estadoGeneral = safeStr(ef['estadoGeneral']) ?? safeStr(o['estadoGeneral']);
        acv           = safeStr(ef['acv'])           ?? safeStr(o['acv']);
        ar            = safeStr(ef['ar'])            ?? safeStr(o['ar']);
        abdomen       = safeStr(ef['abdomen'])       ?? safeStr(o['abdomen']);
        extremidades  = safeStr(ef['extremidades'])  ?? safeStr(o['extremidades']);
        final egPreview = estadoGeneral ?? '';
        debugPrint('🤖 [SoapParser] O-examen → EG=${egPreview.substring(0, egPreview.length.clamp(0, 40))} ACV=$acv AR=$ar');
      } catch (e, stack) {
        debugPrint('💥 [SoapParser] ERRO PARSE O-EXAMEN-FISICO: $e\n$stack');
      }

      // ── Exames Complementares: tenta sub-nó → fallback campos flat ────────
      try {
        final ex = safeMap(o['examenes']);
        laboratorio       = dualRead(ex, 'laboratorio') ?? safeStr(o['laboratorio']);
        imagenes          = dualRead(ex, 'imagenes')    ?? safeStr(o['imagenes']);
        culturas          = dualRead(ex, 'culturas')    ?? safeStr(o['culturas']);
        ecg               = dualRead(ex, 'ecg')         ?? safeStr(o['ecg']);
        tratamientoActual = safeStr(o['tratamientoActual']);
        final labPreview = laboratorio ?? '';
        debugPrint('🤖 [SoapParser] O-exames → lab=${labPreview.substring(0, labPreview.length.clamp(0, 40))} ecg=$ecg tto=$tratamientoActual');
      } catch (e, stack) {
        debugPrint('💥 [SoapParser] ERRO PARSE O-EXAMES-COMPL: $e\n$stack');
      }

    } catch (e, stack) {
      debugPrint('💥 [SoapParser] ERRO PARSE OBJETIVO (O) — NÓ RAIZ: $e\n$stack');
    }

    // ── Nó A — Evaluación ──────────────────────────────────────────────────
    String? estadoClinical, notasEvaluacion;
    List<String>? problemasActivos;
    try {
      final a = safeMap(json['evaluacion']);
      debugPrint('🤖 [SoapParser] evaluacion keys: ${a.keys.toList()}');
      estadoClinical  = safeStr(a['estado']);
      notasEvaluacion = safeStr(a['notasEvaluacion']);
      final rawProb = a['problemasActivos'];
      final notasPreview = notasEvaluacion ?? '';
      debugPrint('🤖 [SoapParser] A → estado=$estadoClinical rawProb=${rawProb?.runtimeType} notas=${notasPreview.substring(0, notasPreview.length.clamp(0, 40))}');
      if (rawProb is List && rawProb.isNotEmpty) {
        problemasActivos = rawProb
            .map((e) => e?.toString().trim() ?? '')
            .where((e) => e.isNotEmpty)
            .toList();
      }
    } catch (e, stack) {
      debugPrint('💥 [SoapParser] ERRO PARSE EVALUACION (A): $e\n$stack');
    }

    // ── Nó P — Plan ────────────────────────────────────────────────────────
    String? planTerapeutico, criteriosAlta;
    try {
      final p = safeMap(json['plan']);
      debugPrint('🤖 [SoapParser] plan keys: ${p.keys.toList()}');
      planTerapeutico = safeStr(p['planTerapeutico']);
      criteriosAlta   = safeStr(p['criteriosAlta']);
      final planPreview = planTerapeutico ?? '';
      debugPrint('🤖 [SoapParser] P → plan=${planPreview.substring(0, planPreview.length.clamp(0, 60))} criterios=$criteriosAlta');
    } catch (e, stack) {
      debugPrint('💥 [SoapParser] ERRO PARSE PLAN (P): $e\n$stack');
    }

    // ── Nó FÁRMACOS — COMPLETAMENTE ISOLADO (nunca contamina O/A/P) ────────
    List<Map<String, String>>? farmacos;
    try {
      final rawFarm = json['farmacos'];
      debugPrint('🤖 [SoapParser] farmacos raw type: ${rawFarm?.runtimeType}');
      if (rawFarm is List && rawFarm.isNotEmpty) {
        farmacos = rawFarm
            .map((e) {
              try {
                final m = safeMap(e);
                final med = safeStr(m['medicamento']) ?? '';
                final dos = safeStr(m['dosis']) ?? '';
                if (med.isEmpty) return null;
                return <String, String>{'medicamento': med, 'dosis': dos};
              } catch (fe) {
                debugPrint('💥 [SoapParser] ERRO PARSE FARMACO ITEM: $fe — raw: $e');
                return null;
              }
            })
            .whereType<Map<String, String>>()
            .toList();
        if (farmacos.isEmpty) farmacos = null;
        debugPrint('🤖 [SoapParser] farmacos → ${farmacos?.length ?? 0} itens');
      }
    } catch (e, stack) {
      // ISOLAMENTO TOTAL: erro de farmacos NUNCA propaga para cima
      debugPrint('💥 [SoapParser] ERRO PARSE FARMACOS (isolado, O/A/P não afetados): $e\n$stack');
    }

    // ── Sumário de diagnóstico ──────────────────────────────────────────────
    debugPrint('🤖 [SoapParser] ═══ RESULTADO FINAL ═══');
    debugPrint('🤖 [SoapParser] S preenchido: ${notePasaNoche != null || fiebre != null || pa != null}');
    debugPrint('🤖 [SoapParser] O preenchido: ${pa != null || estadoGeneral != null || laboratorio != null}');
    debugPrint('🤖 [SoapParser] A preenchido: ${estadoClinical != null || problemasActivos != null}');
    debugPrint('🤖 [SoapParser] P preenchido: ${planTerapeutico != null}');
    debugPrint('🤖 [SoapParser] Fármacos: ${farmacos?.length ?? 0}');

    return SoapDraftResult(
      pacienteNome:          pNome,
      pacienteCama:          pCama,
      pacienteIdade:         pIdade,
      pacienteSexo:          pSexo,
      pacienteDiagnostico:   pDiag,
      pacienteDiaInternacion: pDia,
      notePasaNoche:         notePasaNoche,
      dolorEscala:           dolorEscala,
      fiebre:                fiebre,
      disnea:                disnea,
      nauseas:               nauseas,
      tos:                   tos,
      alimentacion:          alimentacion,
      diuresis:              diuresis,
      evacuacion:            evacuacion,
      suenoRestado:          suenoRestado,
      notasLibresSubjetivo:  notasLibres,
      pa:                    pa,
      fc:                    fc,
      fr:                    fr,
      satO2:                 satO2,
      temperatura:           temperatura,
      estadoGeneral:         estadoGeneral,
      acv:                   acv,
      ar:                    ar,
      abdomen:               abdomen,
      extremidades:          extremidades,
      laboratorio:           laboratorio,
      imagenes:              imagenes,
      culturas:              culturas,
      ecg:                   ecg,
      tratamientoActual:     tratamientoActual,
      estadoClinical:        estadoClinical,
      problemasActivos:      problemasActivos,
      notasEvaluacion:       notasEvaluacion,
      planTerapeutico:       planTerapeutico,
      criteriosAlta:         criteriosAlta,
      farmacos:              farmacos,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SoapCopilotService — Serviço principal
// ═════════════════════════════════════════════════════════════════════════════
class SoapCopilotService {
  // Build 181: gemini-2.5-flash para OCR/NLP de maior precisão
  static const _endpointSync =
      'https://generativelanguage.googleapis.com/v1beta/models/'
      'gemini-2.5-flash:generateContent';

  // ── responseSchema Build 165 — ACHATADO para máxima confiabilidade ─────────
  // MUDANÇA CRÍTICA: nó 'objetivo' agora tem TODOS os campos FLAT (sem sub-objetos).
  // Elimina o problema de colapso de sub-objetos pelo Gemini.
  // O parser faz dual-mode: tenta nested → fallback flat.
  //
  // Mapeamento flat do 'objetivo':
  //   pa, fc, fr, satO2, temperatura       ← antigo signosVitales.*
  //   estadoGeneral, acv, ar, abdomen,
  //   extremidades                          ← antigo examenFisico.*
  //   laboratorio, imagenes, culturas, ecg  ← antigo examenes.*
  //   tratamientoActual                     ← direto
  static const Map<String, dynamic> _responseSchema = {
    'type': 'object',
    'required': ['paciente', 'subjetivo', 'objetivo', 'evaluacion', 'plan', 'farmacos'],
    'properties': {

      // ── DEMOGRÁFICO ────────────────────────────────────────────────────────
      'paciente': {
        'type': 'object',
        'required': ['nome', 'cama', 'diagnostico'],
        'properties': {
          'nome':           {'type': 'string'},
          'cama':           {'type': 'string'},
          'idade':          {'type': 'string'},
          'sexo':           {'type': 'string', 'enum': ['M', 'F']},
          'diagnostico':    {'type': 'string'},
          'diaInternacion': {'type': 'integer', 'minimum': 1, 'maximum': 90},
        },
      },

      // ── S — SUBJETIVO ──────────────────────────────────────────────────────
      'subjetivo': {
        'type': 'object',
        'required': ['notePasaNoche'],
        'properties': {
          'notePasaNoche': {'type': 'string'},
          'dolorEscala':   {'type': 'integer', 'minimum': 0, 'maximum': 10},
          'fiebre':        {'type': 'boolean'},
          'disnea':        {'type': 'boolean'},
          'nauseas':       {'type': 'boolean'},
          'tos':           {'type': 'boolean'},
          'alimentacion':  {'type': 'string', 'enum': ['Bien', 'Regular', 'Mal']},
          'diuresis':      {'type': 'string', 'enum': ['Normal', 'Oliguria', 'Anuria']},
          'evacuacion':    {'type': 'string', 'enum': ['Normal', 'Constipado', 'Diarrea']},
          'suenoRestado':  {'type': 'boolean'},
          'notasLibres':   {'type': 'string'},
        },
      },

      // ── O — OBJETIVO — FLAT (Build 165 FIX) ──────────────────────────────
      // TODOS os campos num único nível dentro de 'objetivo'.
      // Sem sub-objetos aninhados para evitar colapso de nós pelo Gemini.
      'objetivo': {
        'type': 'object',
        'required': ['pa', 'fc', 'estadoGeneral', 'planTerapeutico_ob'],
        'properties': {
          // Signos vitais (flat)
          'pa':               {'type': 'string'},
          'fc':               {'type': 'string'},
          'fr':               {'type': 'string'},
          'satO2':            {'type': 'string'},
          'temperatura':      {'type': 'string'},
          // Exame físico (flat)
          'estadoGeneral':    {'type': 'string'},
          'acv':              {'type': 'string'},
          'ar':               {'type': 'string'},
          'abdomen':          {'type': 'string'},
          'extremidades':     {'type': 'string'},
          // Exames complementares (flat)
          'laboratorio':      {'type': 'string'},
          'imagenes':         {'type': 'string'},
          'culturas':         {'type': 'string'},
          'ecg':              {'type': 'string'},
          // Tratamento atual
          'tratamientoActual':  {'type': 'string'},
          // Campo auxiliar para forçar emissão (descartado no parse)
          'planTerapeutico_ob': {'type': 'string'},
        },
      },

      // ── A — EVALUACIÓN ────────────────────────────────────────────────────
      'evaluacion': {
        'type': 'object',
        'required': ['estado', 'notasEvaluacion'],
        'properties': {
          'estado': {
            'type': 'string',
            'enum': ['mejorando', 'estable', 'empeorando'],
          },
          'problemasActivos': {
            'type': 'array',
            'items': {'type': 'string'},
          },
          'notasEvaluacion': {'type': 'string'},
        },
      },

      // ── P — PLAN ──────────────────────────────────────────────────────────
      'plan': {
        'type': 'object',
        'required': ['planTerapeutico'],
        'properties': {
          'planTerapeutico': {'type': 'string'},
          'criteriosAlta':   {'type': 'string'},
        },
      },

      // ── FÁRMACOS ──────────────────────────────────────────────────────────
      'farmacos': {
        'type': 'array',
        'items': {
          'type': 'object',
          'required': ['medicamento', 'dosis'],
          'properties': {
            'medicamento': {'type': 'string'},
            'dosis':       {'type': 'string'},
          },
        },
      },
    },
  };

  // ── Prompt de Extração Exaustiva — Build 181 ──────────────────────────────
  // Motor NLP/OCR máximo: minera TODOS os dados disponíveis em texto livre
  // ou imagem (monitor, planilha, prontuário manuscrito, tela de HIS).
  // Zero perda de dados — data-binding completo para todos os controladores.
  static const String _systemPrompt =
      'Eres un motor de extraccion clinica de precision maxima (NLP + OCR). '
      'Tu unica tarea: leer el texto libre o imagen proporcionados y mapear '
      'CADA dato encontrado al campo JSON exacto. Tolera caos: texto fragmentado, '
      'abreviaturas medicas, datos fuera de orden, imagenes de monitores o '
      'planillas manuscritas — extrae TODO sin omitir ni inventar.\n\n'

      '═══════════════════════════════════════════════════════════════\n'
      'REGLA ABSOLUTA — ESTRUCTURA FLAT DEL NODO "objetivo":\n'
      '═══════════════════════════════════════════════════════════════\n'
      'El nodo "objetivo" es PLANO. TODOS sus campos van DIRECTAMENTE '
      'dentro de "objetivo", SIN sub-objetos anidados. Ejemplo CORRECTO:\n'
      '{\n'
      '  "objetivo": {\n'
      '    "pa": "120/80", "fc": "72", "fr": "18", "satO2": "97",\n'
      '    "temperatura": "36.8", "estadoGeneral": "RADS, consciente",\n'
      '    "acv": "RsCsRs SF", "ar": "MVC bilateral",\n'
      '    "abdomen": "Blando, RHA+", "extremidades": "Sin edemas",\n'
      '    "laboratorio": "Hb 10.2 | Leucos 8500 | PCR 12",\n'
      '    "imagenes": "Rx torax sin condensaciones",\n'
      '    "culturas": "", "ecg": "RS FC 72",\n'
      '    "tratamientoActual": "Hidratacion IV + antibiotico",\n'
      '    "planTerapeutico_ob": ""\n'
      '  }\n'
      '}\n\n'

      '═══════════════════════════════════════════════════════════════\n'
      'DIRECTIVAS DE EXTRACCION EXAUSTIVA — CAMPO POR CAMPO:\n'
      '═══════════════════════════════════════════════════════════════\n'

      'PACIENTE (demografico):\n'
      '• nome: nombre completo del paciente. Busca: "Paciente:", "Nombre:", '
      '"Apellido:", etiquetas de pulsera, cabezal de planilla.\n'
      '• cama: numero de cama, habitacion o leito. Busca: "Cama", "Hab.", '
      '"Room", "Leito", "Box".\n'
      '• idade: edad en años. Busca: "años", "a.", "anos", "age", fecha de '
      'nacimiento para calcular si se muestra explicitamente.\n'
      '• sexo: "M" o "F" unicamente. Busca: "masculino", "femenino", '
      '"male", "female", "M/F" check, iniciales de genero.\n'
      '• diagnostico: diagnostico principal de ingreso o el mas relevante '
      'actual. Busca: "Dx:", "Diagnostico:", "Motivo de consulta:", '
      '"CIE-10", primera linea del cuadro clinico.\n'
      '• diaInternacion: dia de internacion/hospitalizacion (entero 1-90). '
      'Busca: "Dia X de internacion", "D+X", "HD#X", "DH".\n\n'

      'SUBJETIVO (S):\n'
      '• notePasaNoche: como paso la noche el paciente — texto libre completo '
      'del medico o enfermeria. Consolida frases como "paso noche tranquila", '
      '"durmio bien", "refiere dolor", "llama por..."\n'
      '• dolorEscala: EVA 0-10. Busca: "EVA", "dolor x/10", "NRS", '
      '"escala de dolor", "VAS score".\n'
      '• fiebre: true si menciona "fiebre", "febril", "T > 38", "pico febril".\n'
      '• disnea: true si menciona "disnea", "dificultad respiratoria", '
      '"SOB", "shortness of breath", "dispneia".\n'
      '• nauseas: true si menciona "nauseas", "vomitos", "nausea".\n'
      '• tos: true si menciona "tos", "cough", "tosse".\n'
      '• alimentacion: "Bien"/"Regular"/"Mal". Busca: "tolera dieta", '
      '"ingiere bien", "sin apetito", "NPO", "nada por boca".\n'
      '• diuresis: "Normal"/"Oliguria"/"Anuria". Busca: "diuresis", '
      '"orina bien", "anuria", "oliguria", "coluria", "hematuria".\n'
      '• evacuacion: "Normal"/"Constipado"/"Diarrea". Busca: "catarsis", '
      '"evacuacion normal", "constipacion", "diarrea", "deposiciones".\n'
      '• suenoRestado: true si menciona "insomnio", "sueno alterado", '
      '"no durmio", "sono mal", "agitado en la noche".\n'
      '• notasLibres: cualquier informacion subjetiva relevante no capturada '
      'arriba — texto medico libre, quejas del paciente, novedades.\n\n'

      'OBJETIVO — SIGNOS VITALES (campos flat en "objetivo"):\n'
      '• pa: presion arterial en formato "120/80". Busca: "PA", "TA", "BP", '
      '"tension arterial", "presion", "SBP/DBP".\n'
      '• fc: frecuencia cardiaca (solo numero). Busca: "FC", "HR", "pulso", '
      '"heart rate", "freq cardiaca".\n'
      '• fr: frecuencia respiratoria (solo numero). Busca: "FR", "RR", '
      '"resp", "respiraciones por minuto".\n'
      '• satO2: saturacion de oxigeno (solo numero sin %). Busca: "SatO2", '
      '"SpO2", "sat", "O2 sat", "oximetria", "pulsioximetria". '
      'Si hay FiO2 o litros O2, incluir en notasLibres.\n'
      '• temperatura: temperatura corporal en grados C (solo numero). '
      'Busca: "T", "Temp", "temperatura", "febril", "afebril". '
      'Si dice "afebril" estimar 36.5.\n\n'

      'OBJETIVO — EXAMEN FISICO (campos flat en "objetivo"):\n'
      '• estadoGeneral: descripcion del estado general. Busca: "EG:", '
      '"RADS", "RAEG", "estado general", "aspecto general", '
      '"consciente", "orientado", "lucido", "somnoliento".\n'
      '• acv: auscultacion cardiovascular. Busca: "ACV", "CV:", '
      '"corazon", "ruidos cardiacos", "RsCsRs", "soplo", "arritmia".\n'
      '• ar: auscultacion respiratoria / pulmonar. Busca: "AR", "AP", '
      '"torax", "pulmones", "MVC", "rales", "sibilancias", "matidez".\n'
      '• abdomen: examen abdominal. Busca: "abdomen", "abd", "blando", '
      '"depresible", "RHA", "dolor a palpacion", "hepato", "esplenomegalia".\n'
      '• extremidades: examen de extremidades. Busca: "MMII", "MMSS", '
      '"edemas", "pulsos", "relleno capilar", "cianosis", "varices".\n\n'

      'OBJETIVO — EXAMENES COMPLEMENTARIOS (campos flat en "objetivo"):\n'
      '• laboratorio: TODOS los valores de laboratorio encontrados — '
      'hemograma (Hb, leucocitos, plaquetas), bioquimica (glucosa, urea, '
      'creatinina, ionograma, bilirrubina, transaminasas), coagulacion '
      '(Quick, KPTT), marcadores (PCR, VHS, procalcitonina, troponina, '
      'BNP, dDimero, lactato), gases arteriales (pH, pCO2, pO2, BE, '
      'HCO3). Formato: "Hb 10.2 | Leucos 8500 | PCR 12.3". '
      'Si hay tabla de resultados, transcribir completa.\n'
      '• imagenes: resultados de imagenologia. Busca: "Rx", "ECO", '
      '"TAC", "TC", "RMN", "radiografia", "ecografia", "tomografia".\n'
      '• culturas: resultados de cultivos y microbiologia. Busca: '
      '"hemocultivo", "urocultivo", "cultivo", "antibiograma", '
      '"germen", "sensible", "resistente".\n'
      '• ecg: hallazgos del electrocardiograma. Busca: "ECG", "EKG", '
      '"electrocardiograma", "RS", "FA", "bloqueo", "PR", "QTc".\n'
      '• tratamientoActual: medicacion o tratamiento en curso mencionado '
      'en el objetivo. Busca: "tratamiento actual", "medicacion actual", '
      '"drogas", "infusion", "goteo".\n\n'

      'EVALUACION (A):\n'
      '• estado: "mejorando"/"estable"/"empeorando". Infiere del contexto '
      'clinico si no esta explicito.\n'
      '• problemasActivos: lista LIMPIA de diagnosticos activos. '
      'Busca: "problemas activos", "lista de problemas", "Dx:", '
      '"diagnosticos", "CIE-10". SUBSTITUYE completamente — no mezcles.\n'
      '• notasEvaluacion: impresion clinica del medico, interpretacion de '
      'resultados, razonamiento diagnostico, conclusion del pase de guardia.\n\n'

      'PLAN (P):\n'
      '• planTerapeutico: TODAS las indicaciones medicas, ordenes, cambios '
      'de tratamiento. Busca: "indicaciones", "plan:", "conducta:", '
      '"ordenes:", "continue", "iniciar", "suspender", "solicitar". '
      'Formato bullet separado por newlines.\n'
      '• criteriosAlta: criterios o condiciones para el alta hospitalaria. '
      'Busca: "alta si", "criterios de alta", "condiciones para alta", '
      '"puede irse cuando".\n\n'

      'FARMACOS:\n'
      '• farmacos[]: lista de TODOS los medicamentos. Para cada uno:\n'
      '  - medicamento: nombre generico o comercial completo.\n'
      '  - dosis: dosis + via + frecuencia completa '
      '(ej: "500mg VO c/8h", "1g EV c/12h", "20mg/h BIC IV").\n'
      'Busca en: recetas, indicaciones, hoja de medicacion, planilla de '
      'enfermeria, cualquier listado de drogas con dosis.\n\n'

      '═══════════════════════════════════════════════════════════════\n'
      'REGLAS CRITICAS FINALES:\n'
      '═══════════════════════════════════════════════════════════════\n'
      '1. NUNCA inventes datos — solo extrae lo EXPLICITO o razonablemente inferable.\n'
      '2. Campo sin datos → cadena vacia "" (NUNCA omitir la clave).\n'
      '3. Redactar en espanol medico profesional conciso.\n'
      '4. Si hay imagen de monitor: extrae TODOS los valores del display.\n'
      '5. Si hay tabla de laboratorio: transcribir CADA valor con su unidad.\n'
      '6. Frases ambiguas: registrar en notasLibres o notasEvaluacion.\n'
      '7. El nodo "objetivo" es FLAT — NO usar sub-objetos dentro de el.\n'
      '8. NUNCA omitas ningun nodo raiz del JSON.\n';

  // ── Método principal ───────────────────────────────────────────────────────
  // Alias de compatibilidade com copilot_button.dart (Build ≤ 164)
  static Future<SoapDraftResult> extractSoap({
    required String apiKey,
    String? text,
    List<Uint8List>? images,
    List<String>? imagesMimeType,
  }) => analyze(apiKey: apiKey, textInput: text, images: images);

  static Future<SoapDraftResult> analyze({
    required String apiKey,
    String? textInput,
    List<Uint8List>? images,
  }) async {
    // ── Monta partes do request ────────────────────────────────────────────
    final parts = <Map<String, dynamic>>[];

    if (textInput != null && textInput.trim().isNotEmpty) {
      parts.add({'text': textInput.trim()});
    }

    if (images != null) {
      for (var i = 0; i < images.length; i++) {
        parts.add({
          'inline_data': {
            'mime_type': 'image/jpeg',
            'data': base64Encode(images[i]),
          }
        });
      }
    }

    if (parts.isEmpty) {
      throw Exception('Nenhum conteúdo fornecido ao Copiloto.');
    }

    // ── Corpo da requisição ────────────────────────────────────────────────
    final body = jsonEncode({
      'system_instruction': {
        'parts': [{'text': _systemPrompt}],
      },
      'contents': [
        {
          'role': 'user',
          'parts': parts,
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': _responseSchema,
        'temperature': 0.1,
        'maxOutputTokens': 8192,  // Build 181: aumentado 4096→8192 para lab extenso
      },
    });

    // ── Chamada HTTP ───────────────────────────────────────────────────────
    final uri = Uri.parse('$_endpointSync?key=$apiKey');

    http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 45));
    } catch (e) {
      throw Exception('Erro de conexão com a API Gemini: $e');
    }

    if (response.statusCode != 200) {
      String detail = '';
      try {
        final errBody = jsonDecode(response.body);
        detail = errBody['error']?['message']?.toString() ?? '';
      } catch (_) {}
      throw Exception(
          'API Gemini retornou ${response.statusCode}. '
          '${detail.isNotEmpty ? detail : response.body}');
    }

    // ── Extrai rawText ─────────────────────────────────────────────────────
    String rawText = '';
    try {
      final decoded = jsonDecode(response.body);
      final candidates = decoded['candidates'];
      if (candidates is! List || candidates.isEmpty) {
        throw Exception('Gemini retornou lista de candidatos vazia.');
      }
      final content = candidates[0]['content'];
      final parts2  = content is Map ? content['parts'] : null;
      if (parts2 is! List || parts2.isEmpty) {
        throw Exception('Nenhuma parte de conteúdo na resposta Gemini.');
      }
      rawText = parts2[0]['text']?.toString() ?? '';
    } catch (e) {
      throw Exception('Erro ao extrair texto da resposta Gemini: $e');
    }

    // ── LOG AUDITORIA ──────────────────────────────────────────────────────
    debugPrint('🤖 GEMINI RAW JSON (Build 165): $rawText');

    // ── Parse JSON ─────────────────────────────────────────────────────────
    Map<String, dynamic> soapJson;
    try {
      soapJson = jsonDecode(rawText) as Map<String, dynamic>;
    } catch (e) {
      final cleaned = rawText
          .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
          .replaceAll(RegExp(r'^```\s*$', multiLine: true), '')
          .trim();
      try {
        soapJson = jsonDecode(cleaned) as Map<String, dynamic>;
      } catch (_) {
        throw Exception(
            'Erro ao parsear JSON da IA. '
            'Resposta bruta: ${rawText.length > 200 ? rawText.substring(0, 200) : rawText}');
      }
    }

    return SoapDraftResult.fromJson(soapJson);
  }
}
