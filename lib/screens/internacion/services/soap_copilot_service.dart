// ─────────────────────────────────────────────────────────────────────────────
// SoapCopilotService — Build 161 — Motor IA Blindado do Copiloto Medcases
//
// Mudanças Build 161:
//   1. responseSchema keys alinhadas 100% com fromJson (case-sensitive audit)
//   2. SoapDraftResult estendido com campos demográficos do paciente
//      (nome, cama, idade, sexo, diagnostico, diaInternacion)
//   3. Parser granular com try-catch independente por nó S/O/A/P
//   4. Todas as tipagens rígidas removidas — tudo via .toString() seguro
//   5. Log de debug: print("🤖 GEMINI RAW JSON: ...") pré-parse
//   6. Prompt reforçado: obrigatoriedade de preencher todas as chaves
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ── Resultado do draft da IA — todos os campos são nullable ──────────────────
// Nullable = a IA pode não ter encontrado informação suficiente para preencher.
// REGRA DE OURO: nenhum campo nulo sobrescreve dado já inserido pelo médico.
class SoapDraftResult {
  // ── DEMOGRÁFICOS DO PACIENTE (Build 161) ──────────────────────────────────
  final String? pacienteNome;
  final String? pacienteCama;
  final String? pacienteIdade;
  final String? pacienteSexo;      // 'M' | 'F'
  final String? pacienteDiagnostico;
  final int?    pacienteDiaInternacion;

  // ── S — Subjetivo ─────────────────────────────────────────────────────────
  final String? notePasaNoche;
  final int?    dolorEscala;
  final bool?   fiebre;
  final bool?   disnea;
  final bool?   nauseas;
  final bool?   tos;
  final String? alimentacion;   // 'Bien' | 'Regular' | 'Mal'
  final String? diuresis;       // 'Normal' | 'Oliguria' | 'Anuria'
  final String? evacuacion;     // 'Normal' | 'Constipado' | 'Diarrea'
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
  final String?       estadoClinical; // 'mejorando' | 'estable' | 'empeorando'
  final List<String>? problemasActivos;
  final String?       notasEvaluacion;

  // ── P — Plan ──────────────────────────────────────────────────────────────
  final String? planTerapeutico;
  final String? criteriosAlta;

  // ── Fármacos (Build 162) ──────────────────────────────────────────────────
  // Lista de {medicamento, dosagem} extraída pela IA do relato ou fotos de receita.
  final List<Map<String, String>>? farmacos;

  const SoapDraftResult({
    // demog
    this.pacienteNome,
    this.pacienteCama,
    this.pacienteIdade,
    this.pacienteSexo,
    this.pacienteDiagnostico,
    this.pacienteDiaInternacion,
    // S
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
    // O vitals
    this.pa,
    this.fc,
    this.fr,
    this.satO2,
    this.temperatura,
    // O examen
    this.estadoGeneral,
    this.acv,
    this.ar,
    this.abdomen,
    this.extremidades,
    // O exams
    this.laboratorio,
    this.imagenes,
    this.culturas,
    this.ecg,
    this.tratamientoActual,
    // A
    this.estadoClinical,
    this.problemasActivos,
    this.notasEvaluacion,
    // P
    this.planTerapeutico,
    this.criteriosAlta,
    // Fármacos
    this.farmacos,
  });

  /// true se a IA extraiu pelo menos um campo demográfico
  bool get hasPatientData =>
      pacienteNome?.isNotEmpty == true ||
      pacienteCama?.isNotEmpty == true ||
      pacienteIdade?.isNotEmpty == true ||
      pacienteDiagnostico?.isNotEmpty == true;

  /// Conta quantos campos SOAP (não demográficos) foram extraídos
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

  // ── Parser blindado com try-catch granular por nó ─────────────────────────
  // Cada seção (paciente, S, O, A, P) é isolada num try-catch independente.
  // Uma falha num nó NÃO invalida os demais — parse parcial sempre retorna.
  factory SoapDraftResult.fromJson(Map<String, dynamic> json) {
    // ── Helpers de conversão segura (zero tipagem rígida) ──────────────────
    String? safeStr(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    int? safeInt(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toInt().clamp(0, 10);
      final parsed = int.tryParse(v.toString().trim());
      return parsed?.clamp(0, 10);
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

    // ── Extração nó DEMOGRÁFICO ───────────────────────────────────────────
    String? pNome, pCama, pIdade, pSexo, pDiag;
    int? pDia;
    try {
      final pac = safeMap(json['paciente']);
      pNome  = safeStr(pac['nome']);
      pCama  = safeStr(pac['cama']);
      pIdade = safeStr(pac['idade']);
      final sexoRaw = safeStr(pac['sexo'])?.toUpperCase();
      pSexo  = (sexoRaw == 'M' || sexoRaw == 'F') ? sexoRaw : null;
      pDiag  = safeStr(pac['diagnostico']);
      pDia   = safeInt(pac['diaInternacion']);
    } catch (e) {
      debugPrint('🤖 [SoapParser] WARN: falha no nó paciente — $e');
    }

    // ── Extração nó S ─────────────────────────────────────────────────────
    String? notePasaNoche, alimentacion, diuresis, evacuacion, notasLibres;
    int? dolorEscala;
    bool? fiebre, disnea, nauseas, tos, suenoRestado;
    try {
      final s = safeMap(json['subjetivo']);
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
    } catch (e) {
      debugPrint('🤖 [SoapParser] WARN: falha no nó S (subjetivo) — $e');
    }

    // ── Extração nó O ─────────────────────────────────────────────────────
    String? pa, fc, fr, satO2, temperatura;
    String? estadoGeneral, acv, ar, abdomen, extremidades;
    String? laboratorio, imagenes, culturas, ecg, tratamientoActual;
    try {
      final o  = safeMap(json['objetivo']);
      final sv = safeMap(o['signosVitales']);
      pa          = safeStr(sv['pa']);
      fc          = safeStr(sv['fc']);
      fr          = safeStr(sv['fr']);
      satO2       = safeStr(sv['satO2']);
      temperatura = safeStr(sv['temperatura']);

      final ef = safeMap(o['examenFisico']);
      estadoGeneral = safeStr(ef['estadoGeneral']);
      acv           = safeStr(ef['acv']);
      ar            = safeStr(ef['ar']);
      abdomen       = safeStr(ef['abdomen']);
      extremidades  = safeStr(ef['extremidades']);

      final ex = safeMap(o['examenes']);
      laboratorio       = safeStr(ex['laboratorio']);
      imagenes          = safeStr(ex['imagenes']);
      culturas          = safeStr(ex['culturas']);
      ecg               = safeStr(ex['ecg']);
      tratamientoActual = safeStr(o['tratamientoActual']);
    } catch (e) {
      debugPrint('🤖 [SoapParser] WARN: falha no nó O (objetivo) — $e');
    }

    // ── Extração nó A ─────────────────────────────────────────────────────
    String? estadoClinical, notasEvaluacion;
    List<String>? problemasActivos;
    try {
      final a = safeMap(json['evaluacion']);
      estadoClinical  = safeStr(a['estado']);
      notasEvaluacion = safeStr(a['notasEvaluacion']);
      final rawProb = a['problemasActivos'];
      if (rawProb is List && rawProb.isNotEmpty) {
        problemasActivos = rawProb
            .map((e) => e?.toString().trim() ?? '')
            .where((e) => e.isNotEmpty)
            .toList();
      }
    } catch (e) {
      debugPrint('🤖 [SoapParser] WARN: falha no nó A (evaluacion) — $e');
    }

    // ── Extração nó P ─────────────────────────────────────────────────────
    String? planTerapeutico, criteriosAlta;
    try {
      final p = safeMap(json['plan']);
      planTerapeutico = safeStr(p['planTerapeutico']);
      criteriosAlta   = safeStr(p['criteriosAlta']);
    } catch (e) {
      debugPrint('🤖 [SoapParser] WARN: falha no nó P (plan) — $e');
    }

    // ── Extração nó FÁRMACOS (Build 162) ─────────────────────────────────
    List<Map<String, String>>? farmacos;
    try {
      final rawFarm = json['farmacos'];
      if (rawFarm is List && rawFarm.isNotEmpty) {
        farmacos = rawFarm
            .map((e) {
              final m = safeMap(e);
              final med = safeStr(m['medicamento']) ?? '';
              final dos = safeStr(m['dosagem']) ?? '';
              if (med.isEmpty) return null;
              return <String, String>{'medicamento': med, 'dosagem': dos};
            })
            .whereType<Map<String, String>>()
            .toList();
        if (farmacos.isEmpty) farmacos = null;
      }
    } catch (e) {
      debugPrint('🤖 [SoapParser] WARN: falha no nó farmacos — $e');
    }

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
  static const _endpointSync =
      'https://generativelanguage.googleapis.com/v1beta/models/'
      'gemini-2.5-flash-lite:generateContent';

  // ── responseSchema — chaves EXATAMENTE alinhadas com fromJson ────────────
  // Auditoria Build 161:
  //   json['paciente']             ✓ novo nó demográfico
  //   json['subjetivo']            ✓ nó S
  //   json['objetivo']             ✓ nó O
  //     o['signosVitales']         ✓ sub-nó vitais
  //     o['examenFisico']          ✓ sub-nó exame físico
  //     o['examenes']              ✓ sub-nó exames complementares
  //   json['evaluacion']           ✓ nó A
  //   json['plan']                 ✓ nó P
  //   Todos os enums: sem strings vazias (fix 160.1 mantido)
  static const Map<String, dynamic> _responseSchema = {
    'type': 'object',
    'properties': {

      // ── DEMOGRÁFICO ──────────────────────────────────────────────────────
      'paciente': {
        'type': 'object',
        'properties': {
          'nome':           {'type': 'string'},
          'cama':           {'type': 'string'},
          'idade':          {'type': 'string'},
          'sexo':           {'type': 'string', 'enum': ['M', 'F']},
          'diagnostico':    {'type': 'string'},
          'diaInternacion': {'type': 'integer', 'minimum': 1, 'maximum': 90},
        },
      },

      // ── S — SUBJETIVO ────────────────────────────────────────────────────
      'subjetivo': {
        'type': 'object',
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

      // ── O — OBJETIVO ─────────────────────────────────────────────────────
      'objetivo': {
        'type': 'object',
        'properties': {
          'signosVitales': {
            'type': 'object',
            'properties': {
              'pa':          {'type': 'string'},
              'fc':          {'type': 'string'},
              'fr':          {'type': 'string'},
              'satO2':       {'type': 'string'},
              'temperatura': {'type': 'string'},
            },
          },
          'examenFisico': {
            'type': 'object',
            'properties': {
              'estadoGeneral': {'type': 'string'},
              'acv':           {'type': 'string'},
              'ar':            {'type': 'string'},
              'abdomen':       {'type': 'string'},
              'extremidades':  {'type': 'string'},
            },
          },
          'examenes': {
            'type': 'object',
            'properties': {
              'laboratorio': {'type': 'string'},
              'imagenes':    {'type': 'string'},
              'culturas':    {'type': 'string'},
              'ecg':         {'type': 'string'},
            },
          },
          'tratamientoActual': {'type': 'string'},
        },
      },

      // ── A — EVALUACIÓN ───────────────────────────────────────────────────
      'evaluacion': {
        'type': 'object',
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

      // ── P — PLAN ─────────────────────────────────────────────────────────
      'plan': {
        'type': 'object',
        'properties': {
          'planTerapeutico': {'type': 'string'},
          'criteriosAlta':   {'type': 'string'},
        },
      },

      // ── FÁRMACOS ATUAIS (Build 162) ───────────────────────────────────────
      // Extrair qualquer medicamento mencionado no texto ou visível em fotos
      // de receitas, prescrições ou telas de sistemas de saúde.
      'farmacos': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'medicamento': {'type': 'string'},
            'dosagem':     {'type': 'string'},
          },
        },
      },
    },
  };

  // ── Prompt reforçado (Build 161) ──────────────────────────────────────────
  static const String _systemPrompt =
      'Eres un asistente clínico especializado en evoluciones médicas SOAP para hospitales. '
      'Analiza TODA la información disponible en el input (texto, imágenes de monitor, '
      'resultados de laboratorio, fotos de epicrisis) y extrae los datos al JSON estructurado.\n\n'
      'OBLIGATORIO — INSTRUCCIÓN CRÍTICA:\n'
      'Es OBLIGATORIO procesar y rellenar TODAS las claves estructurales del JSON. '
      'Cruza RIGUROSAMENTE el relato de texto con los datos extraídos de las imágenes. '
      'Si una clave no tiene información disponible, usa una cadena vacía "", false o '
      'el valor por defecto — pero NUNCA omitas una clave del JSON de respuesta.\n\n'
      'REGLAS ESPECÍFICAS:\n'
      '1. PACIENTE: Si el texto menciona nombre, cama/leito, edad, sexo o diagnóstico '
      'principal, extráelos al nodo "paciente". Esto actualiza el encabezado del prontuario.\n'
      '2. SOLO extrae información EXPLÍCITA. NO inventes datos clínicos.\n'
      '3. Textos libres (notePasaNoche, estadoGeneral, planTerapeutico): redactar en '
      'español médico profesional, convirtiendo abreviaturas (pa→PA, fc→FC, fr→FR, '
      'spo2/sat→satO2, t→temperatura).\n'
      '4. SIGNOS VITALES: cada valor en su campo específico exacto. '
      'PA formato "120/80", FC solo número, temperatura en °C, satO2 con o sin %.\n'
      '5. dolorEscala: sin dolor=0, leve=1-3, moderado=4-6, intenso=7-9, máximo=10.\n'
      '6. estado clínico: mejora/bien→mejorando, sin cambios→estable, empeora/crítico→empeorando.\n'
      '7. problemasActivos: lista LIMPIA de diagnósticos activos. Si el input menciona '
      'un nuevo paciente diferente, la lista debe contener SOLO sus diagnósticos, '
      'sin mezclar con casos anteriores.\n'
      '8. Si hay imágenes de monitores o resultados, extrae TODOS los valores visibles.\n'
      '9. planTerapeutico: consolida TODAS las indicaciones y cambios de tratamiento.\n'
      '10. farmacos: extrae TODOS los medicamentos mencionados en texto o visibles en '
      'imágenes de recetas, prescripciones, pantallas de sistemas hospitalarios o '
      'hojas de medicación. Para cada fármaco incluye nombre y dosagem completa '
      '(ej: "Metformina 850 mg VO 12/12h", "Omeprazol 40 mg EV 1x/día"). '
      'Si no hay fármacos, devuelve array vacío [].\n'
      '11. Responde SIEMPRE con JSON válido completo. NUNCA texto libre fuera del JSON.';

  /// Extrai SOAP + dados demográficos a partir de texto e/ou imagens.
  /// [text]           — texto livre do médico (nota de guardia, voz transcrita, etc.)
  /// [images]         — bytes de imagens (fotos de monitor, exame, epicrisis)
  /// [imagesMimeType] — MIME de cada imagem ('image/jpeg', 'image/png')
  /// [apiKey]         — GeminiService.apiKeyForLab
  static Future<SoapDraftResult> extractSoap({
    required String text,
    List<Uint8List>? images,
    List<String>? imagesMimeType,
    required String apiKey,
  }) async {
    if (apiKey.isEmpty) {
      throw Exception(
          'API Key do Gemini não configurada. '
          'Acesse Configurações e insira sua chave Gemini.');
    }

    // ── Monta partes do conteúdo multimodal ──────────────────────────────
    final parts = <Map<String, dynamic>>[];

    if (text.trim().isNotEmpty) {
      parts.add({'text': text.trim()});
    }

    if (images != null && images.isNotEmpty) {
      for (int i = 0; i < images.length; i++) {
        final mime = (imagesMimeType != null && i < imagesMimeType.length)
            ? imagesMimeType[i]
            : 'image/jpeg';
        parts.add({
          'inlineData': {
            'mimeType': mime,
            'data': base64Encode(images[i]),
          }
        });
      }
    }

    if (parts.isEmpty) {
      throw Exception('Nenhum conteúdo fornecido ao Copiloto.');
    }

    // ── Corpo da requisição com responseSchema ────────────────────────────
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
        'maxOutputTokens': 2048,
      },
    });

    // ── Chamada HTTP síncrona ─────────────────────────────────────────────
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

    // ── Extrai texto bruto do response ───────────────────────────────────
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

    // ── LOG DE AUDITORIA (Build 161) — visível no console Flutter ────────
    // ignore: avoid_print
    debugPrint('🤖 GEMINI RAW JSON: $rawText');

    // ── Parse do JSON SOAP ────────────────────────────────────────────────
    Map<String, dynamic> soapJson;
    try {
      soapJson = jsonDecode(rawText) as Map<String, dynamic>;
    } catch (e) {
      // Tentativa de limpeza: remove markdown code fences se presentes
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
