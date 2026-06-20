// ─────────────────────────────────────────────────────────────────────────────
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

  static PacienteInternacaoData _pacienteFromJson(Map<String, dynamic> j) =>
      PacienteInternacaoData(
        nome: j['nome'] as String? ?? '',
        cama: j['cama'] as String? ?? '',
        idade: j['idade'] as String? ?? '',
        sexo: j['sexo'] as String? ?? '',
        diagnostico: j['diagnostico'] as String? ?? '',
        diaInternacao: (j['diaInternacao'] as int?) ?? 1,
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

  static EvolucionModel _evolFromJson(Map<String, dynamic> j) {
    final s = (j['subjetivo'] as Map<String, dynamic>?) ?? {};
    final o = (j['objetivo'] as Map<String, dynamic>?) ?? {};
    final sv = (o['signosVitales'] as Map<String, dynamic>?) ?? {};
    final ef = (o['examenFisico'] as Map<String, dynamic>?) ?? {};
    final ex = (o['examenes'] as Map<String, dynamic>?) ?? {};
    final a = (j['evaluacion'] as Map<String, dynamic>?) ?? {};
    final p = (j['plan'] as Map<String, dynamic>?) ?? {};

    EstadoClinical? estado;
    final estadoStr = a['estado'] as String?;
    if (estadoStr != null) {
      for (final e in EstadoClinical.values) {
        if (e.name == estadoStr) { estado = e; break; }
      }
    }

    List<String> problemas = [];
    final rawProblemas = a['problemasActivos'];
    if (rawProblemas is List) {
      problemas = rawProblemas.map((e) => e.toString()).toList();
    }

    return EvolucionModel(
      id: j['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      fecha: j['fecha'] != null
          ? DateTime.tryParse(j['fecha'].toString()) ?? DateTime.now()
          : DateTime.now(),
      autorNombre: j['autorNombre'] as String? ?? 'Dr.',
      subjetivo: SubjetivoData(
        notePasaNoche: s['notePasaNoche'] as String? ?? '',
        dolorEscala: s['dolorEscala'] as int?,
        fiebre: s['fiebre'] as bool? ?? false,
        disnea: s['disnea'] as bool? ?? false,
        nauseas: s['nauseas'] as bool? ?? false,
        tos: s['tos'] as bool? ?? false,
        alimentacion: s['alimentacion'] as String? ?? '',
        diuresis: s['diuresis'] as String? ?? '',
        evacuacion: s['evacuacion'] as String? ?? '',
        suenoRestado: s['suenoRestado'] as bool? ?? false,
        notasLibres: s['notasLibres'] as String? ?? '',
      ),
      objetivo: ObjetivoData(
        signosVitales: SignosVitales(
          pa: sv['pa'] as String? ?? '',
          fc: sv['fc'] as String? ?? '',
          fr: sv['fr'] as String? ?? '',
          satO2: sv['satO2'] as String? ?? '',
          temperatura: sv['temperatura'] as String? ?? '',
        ),
        examenFisico: ExamenFisico(
          estadoGeneral: ef['estadoGeneral'] as String? ?? '',
          acv: ef['acv'] as String? ?? '',
          ar: ef['ar'] as String? ?? '',
          abdomen: ef['abdomen'] as String? ?? '',
          extremidades: ef['extremidades'] as String? ?? '',
        ),
        examenes: ExamenesComplementarios(
          laboratorio: ex['laboratorio'] as String? ?? '',
          imagenes: ex['imagenes'] as String? ?? '',
          culturas: ex['culturas'] as String? ?? '',
          ecg: ex['ecg'] as String? ?? '',
        ),
        tratamientoActual: o['tratamientoActual'] as String? ?? '',
      ),
      evaluacion: EvaluacionData(
        estado: estado,
        problemasActivos: problemas,
        notasEvaluacion: a['notasEvaluacion'] as String? ?? '',
      ),
      plan: PlanData(
        planTerapeutico: p['planTerapeutico'] as String? ?? '',
        criteriosAlta: p['criteriosAlta'] as String? ?? '',
      ),
    );
  }

  static PacienteSession? _sessionFromJson(
      Map<String, dynamic> json, String key) {
    try {
      final pacienteJson =
          json['paciente'] as Map<String, dynamic>? ?? {};
      final historialJson = json['historial'] as List? ?? [];
      final savedAtStr = json['savedAt'] as String?;
      final savedAt = savedAtStr != null
          ? DateTime.tryParse(savedAtStr) ?? DateTime.now()
          : DateTime.now();

      return PacienteSession(
        sessionKey: key,
        paciente: _pacienteFromJson(pacienteJson),
        historial: historialJson
            .map((e) => _evolFromJson(e as Map<String, dynamic>))
            .toList(),
        savedAt: savedAt,
      );
    } catch (_) {
      return null;
    }
  }
}
