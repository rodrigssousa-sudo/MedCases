// ─────────────────────────────────────────────────────────────────────────────
// InternacionFirestoreService — Build 173
//
// Sincronização em tempo real via Cloud Firestore para sessões de internação.
// Coleção: users/{uid}/internaciones/{sessionKey}
//
// Funcionalidades:
//  • saveSession()      — upsert com merge (cria ou atualiza)
//  • loadAllSessions()  — one-shot query (isDeleted == false)
//  • sessionsStream()   — stream em tempo real (multi-device sync)
//  • softDelete()       — isDeleted:true + deletedAt (Lixeira 30d)
//  • restoreSession()   — isDeleted:false (recuperação de emergência)
//
// Arquitetura da Lixeira (30-Day TTL):
//  • softDelete() NÃO apaga fisicamente — marca isDeleted:true
//  • A query principal filtra isDeleted == false
//  • TTL real via Firestore TTL policy no campo deletedAt (configurar no console)
//  • Dados ficam disponíveis para recuperação por 30 dias
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/evolucion_model.dart';
import '../components/patient_accordion.dart';
import 'internacion_persistence.dart';

// ── Build 173: modelo leve para itens da lixeira ──────────────────────────
class DeletedSession {
  final String sessionKey;
  final PacienteInternacaoData paciente;
  final int historialCount;
  final DateTime deletedAt;

  const DeletedSession({
    required this.sessionKey,
    required this.paciente,
    required this.historialCount,
    required this.deletedAt,
  });

  /// Formata a data de exclusão de forma legível
  String get deletedAtLabel {
    final d = deletedAt;
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inHours < 1) return 'há ${diff.inMinutes}min';
    if (diff.inDays < 1) return 'há ${diff.inHours}h';
    if (diff.inDays == 1) return 'ontem';
    if (diff.inDays < 30) return 'há ${diff.inDays} dias';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}

class InternacionFirestoreService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Referência à sub-coleção do usuário
  static CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('internaciones');

  // ── Chave determinística (igual ao InternacionPersistence para compatibilidade)
  static String sessionKey(PacienteInternacaoData p) {
    final nome = p.nome.trim().replaceAll(RegExp(r'\s+'), '_').toLowerCase();
    final cama = p.cama.trim().replaceAll(RegExp(r'\s+'), '_').toLowerCase();
    if (nome.isEmpty && cama.isEmpty) {
      return 'anon_${DateTime.now().millisecondsSinceEpoch}';
    }
    return '${nome}_$cama';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SAVE — upsert (merge: true para não sobrescrever campos não enviados)
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> saveSession({
    required String uid,
    required PacienteInternacaoData paciente,
    required List<EvolucionModel> historial,
    String? existingKey,
  }) async {
    try {
      final key = existingKey ?? sessionKey(paciente);
      final payload = _buildPayload(key, paciente, historial);
      await _col(uid).doc(key).set(payload, SetOptions(merge: true));
      debugPrint('[InternFire] saveSession OK → $key (${historial.length} evol.)');
    } catch (e) {
      debugPrint('[InternFire] saveSession ERRO: $e');
      // Não propaga — persistência local é o fallback
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOAD ONE-SHOT — retorna sessões ativas (isDeleted == false)
  // ─────────────────────────────────────────────────────────────────────────
  static Future<List<PacienteSession>> loadAllSessions(String uid) async {
    try {
      final snap = await _col(uid)
          .where('isDeleted', isEqualTo: false)
          .orderBy('savedAt', descending: true)
          .get();
      return snap.docs
          .map((d) => _sessionFromDoc(d))
          .whereType<PacienteSession>()
          .toList();
    } catch (e) {
      debugPrint('[InternFire] loadAllSessions ERRO: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STREAM — tempo real (multi-device sync)
  // ─────────────────────────────────────────────────────────────────────────
  static Stream<List<PacienteSession>> sessionsStream(String uid) {
    return _col(uid)
        .where('isDeleted', isEqualTo: false)
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => _sessionFromDoc(d))
            .whereType<PacienteSession>()
            .toList());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SOFT DELETE — Lixeira 30 dias (isDeleted:true + deletedAt)
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> softDelete(String uid, String sessionKey) async {
    try {
      await _col(uid).doc(sessionKey).set({
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('[InternFire] softDelete OK → $sessionKey');
    } catch (e) {
      debugPrint('[InternFire] softDelete ERRO: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RESTORE — recupera da lixeira (isDeleted → false)
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> restoreSession(String uid, String sessionKey) async {
    try {
      await _col(uid).doc(sessionKey).set({
        'isDeleted': false,
        'deletedAt': null,
      }, SetOptions(merge: true));
      debugPrint('[InternFire] restoreSession OK → $sessionKey');
    } catch (e) {
      debugPrint('[InternFire] restoreSession ERRO: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GET DELETED — query para a lixeira (isDeleted == true), Build 173
  // ─────────────────────────────────────────────────────────────────────────
  static Future<List<DeletedSession>> getDeletedSessions(String uid) async {
    try {
      final snap = await _col(uid)
          .where('isDeleted', isEqualTo: true)
          .orderBy('deletedAt', descending: true)
          .get();
      return snap.docs.map((d) => _deletedFromDoc(d)).whereType<DeletedSession>().toList();
    } catch (e) {
      debugPrint('[InternFire] getDeletedSessions ERRO: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HARD DELETE — remoção definitiva do Firestore, Build 173
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> hardDeleteSession(String uid, String sessionKey) async {
    try {
      await _col(uid).doc(sessionKey).delete();
      debugPrint('[InternFire] hardDeleteSession OK → $sessionKey');
    } catch (e) {
      debugPrint('[InternFire] hardDeleteSession ERRO: $e');
    }
  }

  // ── Deserializa documento da lixeira ─────────────────────────────────────
  static DeletedSession? _deletedFromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      final data = doc.data();
      if (data == null) return null;
      final pacienteJson = (data['paciente'] as Map<String, dynamic>?) ?? {};
      final deletedAtTs = data['deletedAt'];
      DateTime? deletedAt;
      if (deletedAtTs is Timestamp) {
        deletedAt = deletedAtTs.toDate();
      } else if (deletedAtTs is String) {
        deletedAt = DateTime.tryParse(deletedAtTs);
      }
      final paciente = _pacienteFromJson(pacienteJson);
      final historialJson = (data['historial'] as List?) ?? [];
      return DeletedSession(
        sessionKey: doc.id,
        paciente: paciente,
        historialCount: historialJson.length,
        deletedAt: deletedAt ?? DateTime.now(),
      );
    } catch (e) {
      debugPrint('[InternFire] _deletedFromDoc ERRO: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Constrói payload completo para Firestore
  // ─────────────────────────────────────────────────────────────────────────
  static Map<String, dynamic> _buildPayload(
    String key,
    PacienteInternacaoData paciente,
    List<EvolucionModel> historial,
  ) {
    return {
      'sessionKey': key,
      'isDeleted': false,
      'savedAt': FieldValue.serverTimestamp(),
      'paciente': _pacienteToJson(paciente),
      'historial': historial.map(_evolToJson).toList(),
    };
  }

  // ── Serialização paciente ────────────────────────────────────────────────
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

  // ── Serialização evolução ─────────────────────────────────────────────────
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
        'farmacos': e.farmacos
            .map((f) => {'medicamento': f.medicamento, 'dosagem': f.dosagem})
            .toList(),
      };

  // ── Deserialização de documento Firestore ─────────────────────────────────
  static PacienteSession? _sessionFromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      final data = doc.data();
      if (data == null) return null;

      final pacienteJson = (data['paciente'] as Map<String, dynamic>?) ?? {};
      final historialJson = (data['historial'] as List?) ?? [];
      final savedAtTs = data['savedAt'];
      DateTime savedAt;
      if (savedAtTs is Timestamp) {
        savedAt = savedAtTs.toDate();
      } else if (savedAtTs is String) {
        savedAt = DateTime.tryParse(savedAtTs) ?? DateTime.now();
      } else {
        savedAt = DateTime.now();
      }

      return PacienteSession(
        sessionKey: doc.id,
        paciente: _pacienteFromJson(pacienteJson),
        historial: historialJson
            .map((e) => _evolFromJson(e as Map<String, dynamic>))
            .toList(),
        savedAt: savedAt,
      );
    } catch (e) {
      debugPrint('[InternFire] _sessionFromDoc ERRO: $e');
      return null;
    }
  }

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
        if (e.name == estadoStr) {
          estado = e;
          break;
        }
      }
    }

    List<String> problemas = [];
    final rawProblemas = a['problemasActivos'];
    if (rawProblemas is List) {
      problemas = rawProblemas.map((e) => e.toString()).toList();
    }

    // Fármacos (Build 162+)
    List<FarmacoEntry> farmacos = [];
    final rawFarmacos = j['farmacos'];
    if (rawFarmacos is List) {
      for (final f in rawFarmacos) {
        if (f is Map<String, dynamic>) {
          farmacos.add(FarmacoEntry(
            medicamento: f['medicamento'] as String? ?? '',
            dosagem: f['dosagem'] as String? ?? '',
          ));
        }
      }
    }

    return EvolucionModel(
      id: j['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
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
      farmacos: farmacos,
    );
  }
}
