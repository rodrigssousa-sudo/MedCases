// ─────────────────────────────────────────────────────────────────────────────
// InternacionPersistence — Build 207 — Anti-Type-Erasure na deserialização local
//
// Build 207: Todos os 'as Map<String, dynamic>?' no _evolFromJson e
// _sessionFromJson substituídos por pattern 'is Map' + Map.from() imune
// à minificação dart2js. Mesmo fix do internacion_firestore_service.dart.
// Todos os 'as String?' / 'as bool?' / 'as int?' em campos primitivos
// do sub-mapa substituídos por helpers _toStr/_toBool/_toInt seguros.
//
// InternacionPersistence — Build 165 — Chave única anti-default-bleed
//
// Build 163: clearActiveSession() — apaga a sessão "default" (paciente ativo)
//   Usado pelo Protocolo Clean Slate ao iniciar nova evolução.
//
// Persiste sessões de pacientes em internação entre aberturas do app.
// Cada sessão = (PacienteInternacaoData + List<EvolucionModel>).
// Key: "paciente_<nome>_<cama>" — permite múltiplos pacientes simultâneos.
//
// Next-day pattern:
//   nextDayDraft() cria nova evolução do "Dia 2" reaproveitando:
//     ✅ nome, cama, idade, sexo, diagnóstico
//     🔄 diaInternacao += 1
//     ❌ vitais, labs, notas — todos resetados (novos valores do dia)
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/evolucion_model.dart';
import '../components/patient_accordion.dart';

// ── Sessão completa de um paciente ────────────────────────────────────────────
class PacienteSession {
  final String sessionKey;
  final PacienteInternacaoData paciente;
  final List<EvolucionModel> historial;
  final DateTime savedAt;

  const PacienteSession({
    required this.sessionKey,
    required this.paciente,
    required this.historial,
    required this.savedAt,
  });

  /// Cria um novo draft para o dia seguinte, reaproveitando dados demográficos
  EvolucionModel nextDayDraft() {
    return EvolucionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fecha: DateTime.now(),
      autorNombre: historial.isNotEmpty
          ? historial.last.autorNombre
          : 'Dr.',
      // S/O/A/P zerados: cada dia começa limpo
      subjetivo: const SubjetivoData(),
      objetivo: const ObjetivoData(),
      evaluacion: const EvaluacionData(),
      plan: const PlanData(),
    );
  }

  PacienteInternacaoData get nextDayPaciente => paciente.copyWith(
    diaInternacao: paciente.diaInternacao + 1,
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Serviço de persistência
// ═════════════════════════════════════════════════════════════════════════════
class InternacionPersistence {
  static const _prefix = 'internacion_session_';
  static const _keysListKey = 'internacion_session_keys';

  /// Gera chave única a partir de nome+cama (sanitizado).
  /// FIX 165-C: Quando nome+cama estão vazios, usa timestamp para evitar que
  /// sessões "default" se sobreponham entre pacientes diferentes.
  /// Isso impede que paciente B ressuscite ao sobrescrever a chave do paciente A.
  static String _sessionKey(PacienteInternacaoData p) {
    final nome = p.nome.trim().replaceAll(RegExp(r'\s+'), '_').toLowerCase();
    final cama = p.cama.trim().replaceAll(RegExp(r'\s+'), '_').toLowerCase();
    if (nome.isEmpty && cama.isEmpty) {
      // Chave única por timestamp — nunca mais colisão entre sessões anônimas
      return '${_prefix}anon_${DateTime.now().millisecondsSinceEpoch}';
    }
    return '$_prefix${nome}_${cama}';
  }

  // ── Salva (ou atualiza) a sessão do paciente ─────────────────────────────
  static Future<void> saveSession({
    required PacienteInternacaoData paciente,
    required List<EvolucionModel> historial,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _sessionKey(paciente);

      // Serializa paciente
      final pacienteJson = _pacienteToJson(paciente);

      // Serializa historial
      final historialJson = historial.map(_evolToJson).toList();

      final session = {
        'sessionKey': key,
        'paciente': pacienteJson,
        'historial': historialJson,
        'savedAt': DateTime.now().toIso8601String(),
      };

      await prefs.setString(key, jsonEncode(session));

      // Atualiza lista de chaves conhecidas
      final keysList = prefs.getStringList(_keysListKey) ?? [];
      if (!keysList.contains(key)) {
        keysList.add(key);
        await prefs.setStringList(_keysListKey, keysList);
      }
    } catch (e) {
      // Falha silenciosa na persistência — não quebra o fluxo clínico
    }
  }

  // ── Carrega todas as sessões salvas ──────────────────────────────────────
  static Future<List<PacienteSession>> loadAllSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keysList = prefs.getStringList(_keysListKey) ?? [];
      final sessions = <PacienteSession>[];

      for (final key in keysList) {
        final raw = prefs.getString(key);
        if (raw == null) continue;
        try {
          final json = jsonDecode(raw) as Map<String, dynamic>;
          final session = _sessionFromJson(json, key);
          if (session != null) sessions.add(session);
        } catch (_) {
          // Dado corrompido — ignora sessão
        }
      }

      // Ordena por data mais recente primeiro
      sessions.sort((a, b) => b.savedAt.compareTo(a.savedAt));
      return sessions;
    } catch (_) {
      return [];
    }
  }

  // ── Carrega sessão específica por nome+cama ───────────────────────────────
  static Future<PacienteSession?> loadSession(PacienteInternacaoData p) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _sessionKey(p);
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return _sessionFromJson(json, key);
    } catch (_) {
      return null;
    }
  }

  // ── Deleta sessão ─────────────────────────────────────────────────────────
  static Future<void> deleteSession(String sessionKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(sessionKey);
      final keysList = prefs.getStringList(_keysListKey) ?? [];
      keysList.remove(sessionKey);
      await prefs.setStringList(_keysListKey, keysList);
    } catch (_) {}
  }

  // ── Build 163: Protocolo Clean Slate ─────────────────────────────────────
  // Apaga a sessão ativa do paciente atual (chave derivada de nome+cama).
  // Garante que ao reabrir o app, o paciente anterior NÃO é recarregado.
  // Chame ANTES de resetar o estado local da InternacionScreen.
  static Future<void> clearActiveSession(PacienteInternacaoData paciente) async {
    try {
      final key = _sessionKey(paciente);
      await deleteSession(key);
    } catch (_) {}
  }

  // Apaga TODAS as sessões persistidas (uso futuro / testes).
  static Future<void> clearAllSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keysList = prefs.getStringList(_keysListKey) ?? [];
      for (final key in keysList) {
        await prefs.remove(key);
      }
      await prefs.remove(_keysListKey);
    } catch (_) {}
  }

  // ── Serialização ─────────────────────────────────────────────────────────
  static Map<String, dynamic> _pacienteToJson(PacienteInternacaoData p) => {
    'nome': p.nome,
    'cama': p.cama,
    'idade': p.idade,
    'sexo': p.sexo,
    'diagnostico': p.diagnostico,
    'diaInternacao': p.diaInternacao,
  };

  // Build 207: usa _str/_int imunes a type erasure dart2js.
  static PacienteInternacaoData _pacienteFromJson(Map<String, dynamic> j) =>
      PacienteInternacaoData(
        nome:         _str(j['nome']),
        cama:         _str(j['cama']),
        idade:        _str(j['idade']),
        sexo:         _str(j['sexo']),
        diagnostico:  _str(j['diagnostico']),
        diaInternacao: _int(j['diaInternacao'], 1),
      );

  static Map<String, dynamic> _evolToJson(EvolucionModel e) => {
    'id': e.id,
    'fecha': e.fecha.toIso8601String(),
    'autorNombre': e.autorNombre,
    'subjetivo': {
      'notePasaNoche': e.subjetivo.notePasaNoche,
      'dolorEscala': e.subjetivo.dolorEscala,
      'fiebre': e.subjetivo.fiebre,
      'disnea': e.subjetivo.disnea,
      'nauseas': e.subjetivo.nauseas,
      'tos': e.subjetivo.tos,
      'alimentacion': e.subjetivo.alimentacion,
      'diuresis': e.subjetivo.diuresis,
      'evacuacion': e.subjetivo.evacuacion,
      'suenoRestado': e.subjetivo.suenoRestado,
      'notasLibres': e.subjetivo.notasLibres,
    },
    'objetivo': {
      'signosVitales': {
        'pa': e.objetivo.signosVitales.pa,
        'fc': e.objetivo.signosVitales.fc,
        'fr': e.objetivo.signosVitales.fr,
        'satO2': e.objetivo.signosVitales.satO2,
        'temperatura': e.objetivo.signosVitales.temperatura,
      },
      'examenFisico': {
        'estadoGeneral': e.objetivo.examenFisico.estadoGeneral,
        'acv': e.objetivo.examenFisico.acv,
        'ar': e.objetivo.examenFisico.ar,
        'abdomen': e.objetivo.examenFisico.abdomen,
        'extremidades': e.objetivo.examenFisico.extremidades,
      },
      'examenes': {
        'laboratorio': e.objetivo.examenes.laboratorio,
        'imagenes': e.objetivo.examenes.imagenes,
        'culturas': e.objetivo.examenes.culturas,
        'ecg': e.objetivo.examenes.ecg,
      },
      'tratamientoActual': e.objetivo.tratamientoActual,
    },
    'evaluacion': {
      'estado': e.evaluacion.estado?.name,
      'problemasActivos': e.evaluacion.problemasActivos,
      'notasEvaluacion': e.evaluacion.notasEvaluacion,
    },
    'plan': {
      'planTerapeutico': e.plan.planTerapeutico,
      'criteriosAlta': e.plan.criteriosAlta,
    },
  };

  // Build 207: helpers locais imunes à minificação dart2js.
  // Nenhum 'as Map<String, dynamic>' — usa 'is Map' estrutural.
  static Map<String, dynamic> _safe(dynamic v) =>
      (v is Map) ? Map<String, dynamic>.from(v as Map) : {};

  static String _str(dynamic v, [String fallback = '']) {
    if (v == null) return fallback;
    if (v is String) return v;
    return v.toString();
  }

  static bool _bool(dynamic v, [bool fallback = false]) {
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v is int) return v != 0;
    if (v is String) return v == 'true' || v == '1';
    return fallback;
  }

  static int? _intOrNull(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static int _int(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static EvolucionModel _evolFromJson(Map<String, dynamic> j) {
    // Build 207: usa _safe() (is Map + Map.from()) — imune a type erasure dart2js.
    // Todos os casts 'as Map<String, dynamic>?' eliminados.
    final s  = _safe(j['subjetivo']);
    final o  = _safe(j['objetivo']);
    final sv = _safe(o['signosVitales']);
    final ef = _safe(o['examenFisico']);
    final ex = _safe(o['examenes']);
    final a  = _safe(j['evaluacion']);
    final p  = _safe(j['plan']);

    EstadoClinical? estado;
    final estadoStr = a['estado'];
    if (estadoStr is String) {
      for (final e in EstadoClinical.values) {
        if (e.name == estadoStr) { estado = e; break; }
      }
    }

    List<String> problemas = [];
    final rawProblemas = a['problemasActivos'];
    if (rawProblemas is List) {
      problemas = rawProblemas.map((e) => e.toString()).toList();
    }

    // Build 207: todos 'as String?/bool?/int?' substituídos por _str/_bool/_intOrNull.
    return EvolucionModel(
      id: _str(j['id'], DateTime.now().millisecondsSinceEpoch.toString()),
      fecha: j['fecha'] != null
          ? DateTime.tryParse(j['fecha'].toString()) ?? DateTime.now()
          : DateTime.now(),
      autorNombre: _str(j['autorNombre'], 'Dr.'),
      subjetivo: SubjetivoData(
        notePasaNoche: _str(s['notePasaNoche']),
        dolorEscala:  _intOrNull(s['dolorEscala']),
        fiebre:       _bool(s['fiebre']),
        disnea:       _bool(s['disnea']),
        nauseas:      _bool(s['nauseas']),
        tos:          _bool(s['tos']),
        alimentacion: _str(s['alimentacion']),
        diuresis:     _str(s['diuresis']),
        evacuacion:   _str(s['evacuacion']),
        suenoRestado: _bool(s['suenoRestado']),
        notasLibres:  _str(s['notasLibres']),
      ),
      objetivo: ObjetivoData(
        signosVitales: SignosVitales(
          pa:          _str(sv['pa']),
          fc:          _str(sv['fc']),
          fr:          _str(sv['fr']),
          satO2:       _str(sv['satO2']),
          temperatura: _str(sv['temperatura']),
        ),
        examenFisico: ExamenFisico(
          estadoGeneral: _str(ef['estadoGeneral']),
          acv:           _str(ef['acv']),
          ar:            _str(ef['ar']),
          abdomen:       _str(ef['abdomen']),
          extremidades:  _str(ef['extremidades']),
        ),
        examenes: ExamenesComplementarios(
          laboratorio: _str(ex['laboratorio']),
          imagenes:    _str(ex['imagenes']),
          culturas:    _str(ex['culturas']),
          ecg:         _str(ex['ecg']),
        ),
        tratamientoActual: _str(o['tratamientoActual']),
      ),
      evaluacion: EvaluacionData(
        estado: estado,
        problemasActivos: problemas,
        notasEvaluacion: _str(a['notasEvaluacion']),
      ),
      plan: PlanData(
        planTerapeutico: _str(p['planTerapeutico']),
        criteriosAlta:   _str(p['criteriosAlta']),
      ),
    );
  }

  static PacienteSession? _sessionFromJson(
      Map<String, dynamic> json, String key) {
    try {
      // Build 207: usa _safe() e 'is Map' sem genéricos — imune a type erasure.
      final pacienteJson = _safe(json['paciente']);
      final rawHistorial = json['historial'];
      final historialList = (rawHistorial is List) ? rawHistorial : <dynamic>[];
      final savedAtStr = json['savedAt'];
      final savedAtParsed = savedAtStr is String
          ? DateTime.tryParse(savedAtStr)
          : null;
      final savedAt = savedAtParsed ?? DateTime.now();

      return PacienteSession(
        sessionKey: key,
        paciente: _pacienteFromJson(pacienteJson),
        // Build 207: 'e as Map<String, dynamic>' substituído por 'is Map' + Map.from()
        historial: historialList
            .map((e) {
              if (e is Map) {
                return _evolFromJson(Map<String, dynamic>.from(e as Map));
              }
              return null;
            })
            .whereType<EvolucionModel>()
            .toList(),
        savedAt: savedAt,
      );
    } catch (_) {
      return null;
    }
  }
}
