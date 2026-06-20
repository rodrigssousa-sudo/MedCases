// ─────────────────────────────────────────────────────────────────────────────
// SoapCopilotService — Build 160 — Motor IA do Copiloto Medcases
//
// Arquitetura:
//   • Chama Gemini generateContent (sync) com responseSchema estrito
//   • Suporta multimodal: texto + imagens (base64 inlineData)
//   • Retorna SoapDraftResult — modelo intermediário pre-review
//   • NUNCA injeta dados diretamente: resultado passa pelo RevisionSheet
//   • Usa GeminiService.apiKeyForLab para acessar a chave configurada
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

// ── Resultado do draft da IA — todos os campos são nullable ──────────────────
// Nullable = a IA pode não ter encontrado informação suficiente para preencher
class SoapDraftResult {
  // S — Subjetivo
  final String? notePasaNoche;
  final int? dolorEscala;
  final bool? fiebre;
  final bool? disnea;
  final bool? nauseas;
  final bool? tos;
  final String? alimentacion;   // 'Bien' | 'Regular' | 'Mal' | null
  final String? diuresis;       // 'Normal' | 'Oliguria' | 'Anuria' | null
  final String? evacuacion;     // 'Normal' | 'Constipado' | 'Diarrea' | null
  final bool? suenoRestado;
  final String? notasLibresSubjetivo;

  // O — Objetivo / Signos vitales
  final String? pa;
  final String? fc;
  final String? fr;
  final String? satO2;
  final String? temperatura;

  // O — Examen físico
  final String? estadoGeneral;
  final String? acv;
  final String? ar;
  final String? abdomen;
  final String? extremidades;

  // O — Exámenes complementarios
  final String? laboratorio;
  final String? imagenes;
  final String? culturas;
  final String? ecg;
  final String? tratamientoActual;

  // A — Evaluación
  final String? estadoClinical; // 'mejorando' | 'estable' | 'empeorando'
  final List<String>? problemasActivos;
  final String? notasEvaluacion;

  // P — Plan
  final String? planTerapeutico;
  final String? criteriosAlta;

  const SoapDraftResult({
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
  });

  /// Conta quantos campos não-nulos foram extraídos pela IA
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
    return n;
  }

  /// Parseia JSON retornado pela API Gemini com responseSchema
  factory SoapDraftResult.fromJson(Map<String, dynamic> json) {
    final s = json['subjetivo'] as Map<String, dynamic>? ?? {};
    final o = json['objetivo'] as Map<String, dynamic>? ?? {};
    final sv = o['signosVitales'] as Map<String, dynamic>? ?? {};
    final ef = o['examenFisico'] as Map<String, dynamic>? ?? {};
    final ex = o['examenes'] as Map<String, dynamic>? ?? {};
    final a = json['evaluacion'] as Map<String, dynamic>? ?? {};
    final p = json['plan'] as Map<String, dynamic>? ?? {};

    List<String>? problemas;
    final raw = a['problemasActivos'];
    if (raw is List) problemas = raw.map((e) => e.toString()).toList();

    return SoapDraftResult(
      // S
      notePasaNoche:         _str(s['notePasaNoche']),
      dolorEscala:           _int(s['dolorEscala']),
      fiebre:                _bool(s['fiebre']),
      disnea:                _bool(s['disnea']),
      nauseas:               _bool(s['nauseas']),
      tos:                   _bool(s['tos']),
      alimentacion:          _str(s['alimentacion']),
      diuresis:              _str(s['diuresis']),
      evacuacion:            _str(s['evacuacion']),
      suenoRestado:          _bool(s['suenoRestado']),
      notasLibresSubjetivo:  _str(s['notasLibres']),
      // O vitals
      pa:                    _str(sv['pa']),
      fc:                    _str(sv['fc']),
      fr:                    _str(sv['fr']),
      satO2:                 _str(sv['satO2']),
      temperatura:           _str(sv['temperatura']),
      // O examen
      estadoGeneral:         _str(ef['estadoGeneral']),
      acv:                   _str(ef['acv']),
      ar:                    _str(ef['ar']),
      abdomen:               _str(ef['abdomen']),
      extremidades:          _str(ef['extremidades']),
      // O exams
      laboratorio:           _str(ex['laboratorio']),
      imagenes:              _str(ex['imagenes']),
      culturas:              _str(ex['culturas']),
      ecg:                   _str(ex['ecg']),
      tratamientoActual:     _str(o['tratamientoActual']),
      // A
      estadoClinical:        _str(a['estado']),
      problemasActivos:      problemas,
      notasEvaluacion:       _str(a['notasEvaluacion']),
      // P
      planTerapeutico:       _str(p['planTerapeutico']),
      criteriosAlta:         _str(p['criteriosAlta']),
    );
  }

  static String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int? _int(dynamic v) {
    if (v == null) return null;
    if (v is int) return v.clamp(0, 10);
    final i = int.tryParse(v.toString());
    return i?.clamp(0, 10);
  }

  static bool? _bool(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v;
    final s = v.toString().toLowerCase();
    if (s == 'true') return true;
    if (s == 'false') return false;
    return null;
  }
}

// ── Serviço principal ─────────────────────────────────────────────────────────
class SoapCopilotService {
  static const _endpointSync =
      'https://generativelanguage.googleapis.com/v1beta/models/'
      'gemini-2.5-flash-lite:generateContent';

  // ── Schema JSON para forçar saída estruturada do Gemini ──────────────────
  static const Map<String, dynamic> _responseSchema = {
    'type': 'object',
    'properties': {
      'subjetivo': {
        'type': 'object',
        'properties': {
          'notePasaNoche': {'type': 'string'},
          'dolorEscala': {'type': 'integer', 'minimum': 0, 'maximum': 10},
          'fiebre': {'type': 'boolean'},
          'disnea': {'type': 'boolean'},
          'nauseas': {'type': 'boolean'},
          'tos': {'type': 'boolean'},
          'alimentacion': {
            'type': 'string',
            'enum': ['Bien', 'Regular', 'Mal', '']
          },
          'diuresis': {
            'type': 'string',
            'enum': ['Normal', 'Oliguria', 'Anuria', '']
          },
          'evacuacion': {
            'type': 'string',
            'enum': ['Normal', 'Constipado', 'Diarrea', '']
          },
          'suenoRestado': {'type': 'boolean'},
          'notasLibres': {'type': 'string'},
        },
      },
      'objetivo': {
        'type': 'object',
        'properties': {
          'signosVitales': {
            'type': 'object',
            'properties': {
              'pa': {'type': 'string'},
              'fc': {'type': 'string'},
              'fr': {'type': 'string'},
              'satO2': {'type': 'string'},
              'temperatura': {'type': 'string'},
            },
          },
          'examenFisico': {
            'type': 'object',
            'properties': {
              'estadoGeneral': {'type': 'string'},
              'acv': {'type': 'string'},
              'ar': {'type': 'string'},
              'abdomen': {'type': 'string'},
              'extremidades': {'type': 'string'},
            },
          },
          'examenes': {
            'type': 'object',
            'properties': {
              'laboratorio': {'type': 'string'},
              'imagenes': {'type': 'string'},
              'culturas': {'type': 'string'},
              'ecg': {'type': 'string'},
            },
          },
          'tratamientoActual': {'type': 'string'},
        },
      },
      'evaluacion': {
        'type': 'object',
        'properties': {
          'estado': {
            'type': 'string',
            'enum': ['mejorando', 'estable', 'empeorando', '']
          },
          'problemasActivos': {
            'type': 'array',
            'items': {'type': 'string'},
          },
          'notasEvaluacion': {'type': 'string'},
        },
      },
      'plan': {
        'type': 'object',
        'properties': {
          'planTerapeutico': {'type': 'string'},
          'criteriosAlta': {'type': 'string'},
        },
      },
    },
  };

  static const String _systemPrompt =
      'Eres un asistente clínico especializado en evoluciones médicas en formato SOAP. '
      'Tu tarea es analizar el input del médico (texto rápido, notas de guardia, '
      'valores de monitor, resultados de laboratorio o imágenes) y extraer/organizar '
      'la información en el JSON SOAP estructurado.\n\n'
      'REGLAS CRÍTICAS:\n'
      '1. Extrae SOLO información EXPLÍCITA en el input. NO inventes datos.\n'
      '2. Para campos sin información, usa string vacío "" o false/null.\n'
      '3. Redacta los textos libres (notePasaNoche, estadoGeneral, planTerapeutico) '
      'en español médico profesional, limpio y conciso — convierte abreviaturas médicas '
      'en texto legible (ej: "pa 120/80" → PA: 120/80 mmHg).\n'
      '4. Para signos vitales: extrae cada valor en su campo específico. '
      'PA en pa (formato "120/80"), FC en fc (solo número), etc.\n'
      '5. Para dolorEscala: convierte frases como "sin dolor", "leve", "moderado", '
      '"intenso" en número 0-10 (sin dolor=0, leve=1-3, moderado=4-6, intenso=7-10).\n'
      '6. Para estado clínico: infiere de contexto general (bien/mejora→mejorando, '
      'sin cambios→estable, empeora/crítico→empeorando). Default: estable.\n'
      '7. problemasActivos: lista de diagnósticos/problemas activos mencionados.\n'
      '8. Si hay imágenes de monitores/labs, extrae los valores visibles.\n'
      '9. planTerapeutico: consolida todas las indicaciones/cambios de tratamiento.\n'
      '10. Responde SIEMPRE con JSON válido según el schema. NUNCA texto libre.';

  /// Extrai SOAP a partir de texto e/ou imagens
  /// [text] — texto livre do médico (nota de guardia, etc.)
  /// [images] — bytes de imagens (fotos de monitor, resultado de exame)
  /// [imagesMimeType] — tipo MIME de cada imagem ('image/jpeg', 'image/png', 'application/pdf')
  /// [apiKey] — chave Gemini (de GeminiService.apiKeyForLab)
  static Future<SoapDraftResult> extractSoap({
    required String text,
    List<Uint8List>? images,
    List<String>? imagesMimeType,
    required String apiKey,
  }) async {
    if (apiKey.isEmpty) {
      throw Exception('API Key do Gemini não configurada. '
          'Acesse Configurações e insira sua chave Gemini.');
    }

    // ── Monta partes do conteúdo ──────────────────────────────────────────
    final parts = <Map<String, dynamic>>[];

    // Texto principal
    if (text.trim().isNotEmpty) {
      parts.add({'text': text.trim()});
    }

    // Imagens em base64 (inlineData)
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
        'temperature': 0.1,        // muito baixo: máxima precisão na extração
        'maxOutputTokens': 2048,
      },
    });

    // ── Faz a chamada HTTP síncrona ───────────────────────────────────────
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
        final err = jsonDecode(response.body) as Map;
        detail = (err['error']?['message'] ?? '').toString();
      } catch (_) {}
      throw Exception(
          'API Gemini retornou ${response.statusCode}. '
          '${detail.isNotEmpty ? detail : response.body}');
    }

    // ── Extrai o JSON do response ─────────────────────────────────────────
    late Map<String, dynamic> soapJson;
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw Exception('Gemini retornou resposta vazia.');
      }
      final content = candidates[0]['content'] as Map<String, dynamic>?;
      final parts2 = content?['parts'] as List?;
      if (parts2 == null || parts2.isEmpty) {
        throw Exception('Nenhuma parte de conteúdo na resposta Gemini.');
      }
      final rawText = parts2[0]['text']?.toString() ?? '';
      soapJson = jsonDecode(rawText) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Erro ao parsear resposta da IA: $e');
    }

    return SoapDraftResult.fromJson(soapJson);
  }
}
