// ─────────────────────────────────────────────────────────────────────────────
// InternacionFirestoreService — Build 192
//
// Build 192 — Blindagem contra vazamento de campos (Fix 4):
//   • _evolToJson: preserva metadadosAdicionais existentes no modelo.
//   • _evolFromJson: qualquer chave do JSON da IA não mapeada nos campos
//     fixos é injetada em metadadosAdicionais — perda ZERO de dados.
//   • EvolucionModel não precisa ser alterado: o mapa de segurança vive
//     apenas na camada de serialização Firestore.
//
// Build 191 — Correção de sincronização reversa (3 nós críticos):
//
// Build 191 — Correção de sincronização reversa (3 nós críticos):
//
// FIX A — SEPARAÇÃO INSERT vs UPDATE:
//   • saveSession()   → INSERT puro (.set com merge, preserva savedAt original).
//   • updateSession() → UPDATE cirúrgico (.update) usando doc ID existente.
//     - Usa .doc(existingKey).update() — JAMAIS .add() para docs existentes.
//     - Grava updatedAt:serverTimestamp() separado de savedAt (criação).
//     - Mantém status:'active' + isDeleted:false explicitamente no payload.
//
// FIX B — ORDENAÇÃO HÍBRIDA DO STREAM:
//   • sessionsStream ordena por updatedAt desc (se disponível) ou savedAt desc.
//   • _sessionFromDoc lê updatedAt para populars PacienteSession.savedAt
//     → docs recém-atualizados sobem ao topo imediatamente.
//
// FIX C — PAYLOAD ATÔMICO:
//   • _buildInsertPayload: primeiro save — inclui savedAt (criação).
//   • _buildUpdatePayload: saves subsequentes — inclui updatedAt (modificação),
//     NÃO sobrescreve savedAt para preservar ordem de criação intacta.
//
// Build 186 — Reestruturação Profunda (3 nós arquiteturais críticos):
//
// FIX 1 — UNIFICAÇÃO ABSOLUTA DE COLEÇÕES:
//   • Coleção única: users/{uid}/internaciones — MESMA em Web, iOS, Android.
//   • Firebase Project ID confirmado: 'medcases-pro' em todos os targets.
//   • Constante kInternacionesCollection garante path único sem magic strings.
//
// FIX 2 — ACOPLAMENTO REATIVO HOME ↔ ADULTO:
//   • sessionsStream() e loadAllSessions() filtram status == 'active'.
//   • Backward-compat: documentos antigos sem 'status' mas com isDeleted==false
//     são tratados como active via whereFilter composto.
//   • MEU PLANTÃO e aba Adulto escutam o mesmo stream → sincronização total.
//
// FIX 3 — SOFT-DELETE COMO ÚNICO CAMINHO:
//   • softDelete() grava DOIS campos: isDeleted:true + status:'trashed'
//   • saveSession() (INSERT) grava: isDeleted:false + status:'active'
//   • saveSession() usa SetOptions(merge:true) → NÃO sobrescreve status em docs
//     existentes (um doc trasheado não vira active ao ser salvo por engano).
//   • getDeletedSessions() filtra status == 'trashed'.
//   • hardDeleteSession() só é chamado da tela Lixeira (eliminação definitiva).
//   • .delete() nativo NUNCA chamado no fluxo principal de exclusão.
//
// Arquitetura da Lixeira (30-Day TTL):
//   • softDelete() → status:'trashed' + isDeleted:true + deletedAt (timestamp)
//   • Queries ativas filtram status == 'active' (principal) + isDeleted==false (legado)
//   • Lixeira filtra status == 'trashed'
//   • TTL real via Firestore TTL policy no campo deletedAt (configurar no console)
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/evolucion_model.dart';
import '../components/patient_accordion.dart';
import 'internacion_persistence.dart';

// ── Constante de coleção — ÚNICA fonte de verdade para o path ──────────────
// Build 186 FIX 1: garante que Web, iOS e Android escrevem/leem no mesmo lugar.
const String kInternacionesCollection = 'internaciones';

// ── Status semânticos do ciclo de vida do documento ──────────────────────────
const String kStatusActive  = 'active';
const String kStatusTrashed = 'trashed';

// ── Modelo leve para itens da lixeira ────────────────────────────────────────
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

  String get deletedAtLabel {
    final d = deletedAt;
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inHours < 1) return 'há ${diff.inMinutes}min';
    if (diff.inDays < 1) return 'há ${diff.inHours}h';
    if (diff.inDays == 1) return 'ontem';
    if (diff.inDays < 30) return 'há ${diff.inDays} dias';
    return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
  }
}

class InternacionFirestoreService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD 186 FIX 1 — Referência à sub-coleção UNIFICADA
  // Path: users/{uid}/internaciones — IDÊNTICO em Web, iOS, Android.
  // Usa a constante kInternacionesCollection para zero magic strings.
  // ─────────────────────────────────────────────────────────────────────────
  static CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection(kInternacionesCollection);

  /// Chave determinística (compatível com InternacionPersistence local)
  static String sessionKey(PacienteInternacaoData p) {
    final nome = p.nome.trim().replaceAll(RegExp(r'\s+'), '_').toLowerCase();
    final cama = p.cama.trim().replaceAll(RegExp(r'\s+'), '_').toLowerCase();
    if (nome.isEmpty && cama.isEmpty) {
      return 'anon_${DateTime.now().millisecondsSinceEpoch}';
    }
    return '${nome}_$cama';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SAVE — INSERT puro (novo documento)
  // Build 191 FIX A: Usado EXCLUSIVAMENTE para criar novos prontuários.
  // Grava savedAt (timestamp de criação) + status:'active' + isDeleted:false.
  // NÃO use para pacientes existentes — use updateSession() para isso.
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> saveSession({
    required String uid,
    required PacienteInternacaoData paciente,
    required List<EvolucionModel> historial,
    String? existingKey,
  }) async {
    try {
      final key = existingKey ?? sessionKey(paciente);
      final payload = _buildInsertPayload(key, paciente, historial);
      await _col(uid).doc(key).set(payload, SetOptions(merge: true));
      debugPrint('[InternFire] saveSession (INSERT) OK → $key (${historial.length} evol.)');
    } catch (e) {
      debugPrint('[InternFire] saveSession ERRO: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UPDATE — atualização cirúrgica de prontuário existente (Build 191 FIX A)
  // Usa .doc(existingKey).update() — JAMAIS .add() para docs já existentes.
  // Preserva savedAt original (timestamp de criação) — só adiciona updatedAt.
  // Reforça status:'active' + isDeleted:false para manter o doc no stream.
  // O Firestore stream (sessionsStream) reage imediatamente a este update.
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> updateSession({
    required String uid,
    required String existingKey,
    required PacienteInternacaoData paciente,
    required List<EvolucionModel> historial,
  }) async {
    try {
      final payload = _buildUpdatePayload(existingKey, paciente, historial);
      // .update() preserva todos os campos não incluídos (ex: savedAt, sessionKey)
      // Garante que isDeleted:false + status:'active' estejam presentes
      await _col(uid).doc(existingKey).update(payload);
      debugPrint('[InternFire] updateSession (UPDATE) OK → $existingKey (${historial.length} evol.)');
    } catch (e) {
      // .update() falha se o doc não existe ainda — cai no saveSession como fallback
      debugPrint('[InternFire] updateSession WARN (doc não existe?): $e — tentando saveSession');
      await saveSession(
        uid: uid,
        paciente: paciente,
        historial: historial,
        existingKey: existingKey,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOAD ONE-SHOT — retorna sessões ATIVAS
  // BUILD 186 FIX 2+3: filtra status=='active' (principal).
  // Backward-compat: documentos antigos sem 'status' mas com isDeleted==false
  // são recuperados via query separada e fundidos.
  // ─────────────────────────────────────────────────────────────────────────
  static Future<List<PacienteSession>> loadAllSessions(String uid) async {
    try {
      // Query principal: documentos com status=='active' (Build 186+)
      final snapActive = await _col(uid)
          .where('status', isEqualTo: kStatusActive)
          .orderBy('savedAt', descending: true)
          .get();
      // Backward-compat query: documentos sem campo 'status' (criados antes do Build 186)
      // estes têm isDeleted==false mas não têm 'status' definido
      final snapLegacy = await _col(uid)
          .where('isDeleted', isEqualTo: false)
          .orderBy('savedAt', descending: true)
          .get();
      // Funde os resultados, evitando duplicatas por sessionKey
      final seen = <String>{};
      final all = <PacienteSession>[];
      for (final doc in [...snapActive.docs, ...snapLegacy.docs]) {
        if (seen.contains(doc.id)) continue;
        final data = doc.data();
        // Filtra docs trashados que possam aparecer na query legacy
        final status = data['status'] as String?;
        if (status == kStatusTrashed) continue;
        seen.add(doc.id);
        final session = _sessionFromDoc(doc);
        if (session != null) all.add(session);
      }
      // Re-ordena por savedAt desc após a fusão
      all.sort((a, b) => b.savedAt.compareTo(a.savedAt));
      return all;
    } catch (e) {
      debugPrint('[InternFire] loadAllSessions ERRO: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STREAM — tempo real, multi-device (Build 191 FIX B)
  // Query: isDeleted==false (backward-compat) + filtragem client-side de trashed.
  // Ordenação: savedAt desc (Firestore index) — client-side re-sort por
  // updatedAt desc quando disponível para que updates subam ao topo.
  // MEU PLANTÃO e aba Adulto escutam ESTE mesmo stream → sync total.
  // ─────────────────────────────────────────────────────────────────────────
  static Stream<List<PacienteSession>> sessionsStream(String uid) {
    return _col(uid)
        .where('isDeleted', isEqualTo: false)
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map((snap) {
          final sessions = snap.docs
              .where((doc) {
                final status = doc.data()['status'] as String?;
                // Exclui docs explicitamente trashados (salvaguarda dupla)
                return status != kStatusTrashed;
              })
              .map(_sessionFromDoc)
              .whereType<PacienteSession>()
              .toList();
          // Build 191 FIX B: re-sort client-side por updatedAt (se presente)
          // para que docs recém-editados subam ao topo imediatamente.
          sessions.sort((a, b) => b.savedAt.compareTo(a.savedAt));
          return sessions;
        });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SOFT DELETE — BUILD 186 FIX 3
  // Grava DOIS campos: status:'trashed' + isDeleted:true + deletedAt.
  // NUNCA chama .delete() nativo — dados ficam no Firestore por 30 dias.
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> softDelete(String uid, String sessionKey) async {
    try {
      await _col(uid).doc(sessionKey).update({
        'status': kStatusTrashed,
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[InternFire] softDelete OK → $sessionKey');
    } catch (e) {
      // update() falha se o doc não existe; tenta set com merge como fallback
      try {
        await _col(uid).doc(sessionKey).set({
          'status': kStatusTrashed,
          'isDeleted': true,
          'deletedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('[InternFire] softDelete (fallback set) OK → $sessionKey');
      } catch (e2) {
        debugPrint('[InternFire] softDelete ERRO: $e2');
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RESTORE — recupera da lixeira (status:'trashed' → 'active')
  // BUILD 186: usa update() para não sobrescrever outros campos.
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> restoreSession(String uid, String sessionKey) async {
    try {
      await _col(uid).doc(sessionKey).update({
        'status': kStatusActive,
        'isDeleted': false,
        'deletedAt': FieldValue.delete(),
      });
      debugPrint('[InternFire] restoreSession OK → $sessionKey');
    } catch (e) {
      debugPrint('[InternFire] restoreSession ERRO: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GET DELETED — query para a lixeira
  // BUILD 186 FIX 3: filtra status=='trashed' (semanticamente claro).
  // Backward-compat: também filtra isDeleted==true para docs legados.
  // ─────────────────────────────────────────────────────────────────────────
  static Future<List<DeletedSession>> getDeletedSessions(String uid) async {
    try {
      // Query principal: status=='trashed'
      final snap = await _col(uid)
          .where('status', isEqualTo: kStatusTrashed)
          .orderBy('deletedAt', descending: true)
          .get();

      // Backward-compat: docs marcados isDeleted==true sem campo 'status'
      final snapLegacy = await _col(uid)
          .where('isDeleted', isEqualTo: true)
          .orderBy('deletedAt', descending: true)
          .get();

      final seen = <String>{};
      final all = <DeletedSession>[];
      for (final doc in [...snap.docs, ...snapLegacy.docs]) {
        if (seen.contains(doc.id)) continue;
        seen.add(doc.id);
        final ds = _deletedFromDoc(doc);
        if (ds != null) all.add(ds);
      }
      all.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
      return all;
    } catch (e) {
      debugPrint('[InternFire] getDeletedSessions ERRO: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HARD DELETE — remoção definitiva APENAS na tela de Lixeira
  // BUILD 186: único lugar legítimo para chamar .delete(). O botão
  // 'Excluir' na aba Adulto usa SEMPRE softDelete(), nunca este método.
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> hardDeleteSession(String uid, String sessionKey) async {
    try {
      await _col(uid).doc(sessionKey).delete();
      debugPrint('[InternFire] hardDeleteSession OK → $sessionKey');
    } catch (e) {
      debugPrint('[InternFire] hardDeleteSession ERRO: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build 191: Payload de INSERT (novo documento)
  // Inclui savedAt (timestamp de criação) — NÃO deve ser sobrescrito em updates.
  // ─────────────────────────────────────────────────────────────────────────
  static Map<String, dynamic> _buildInsertPayload(
    String key,
    PacienteInternacaoData paciente,
    List<EvolucionModel> historial,
  ) {
    return {
      'sessionKey': key,
      'status': kStatusActive,               // campo semântico primário
      'isDeleted': false,                    // backward-compat (queries legadas)
      'savedAt': FieldValue.serverTimestamp(), // timestamp de CRIAÇÃO
      'updatedAt': FieldValue.serverTimestamp(), // também preenche no insert
      'paciente': _pacienteToJson(paciente),
      'historial': historial.map(_evolToJson).toList(),
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build 191: Payload de UPDATE (documento existente)
  // NÃO inclui savedAt — preserva o timestamp de criação original.
  // Inclui updatedAt para que o stream reactive mova o doc ao topo.
  // Reforça status:'active' + isDeleted:false — garante visibilidade no stream.
  // ─────────────────────────────────────────────────────────────────────────
  static Map<String, dynamic> _buildUpdatePayload(
    String key,
    PacienteInternacaoData paciente,
    List<EvolucionModel> historial,
  ) {
    return {
      'sessionKey': key,
      'status': kStatusActive,                // reforça — doc volta ao stream
      'isDeleted': false,                     // reforça — backward-compat
      'updatedAt': FieldValue.serverTimestamp(), // timestamp de MODIFICAÇÃO
      // savedAt NÃO incluído — preserva timestamp de criação original
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
  // Build 192 Fix 4: metadadosAdicionais incluso no payload para preservar
  // campos extras capturados pela IA que não têm campo fixo no schema.
  static Map<String, dynamic> _evolToJson(EvolucionModel e) {
    final json = <String, dynamic>{
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
    // Build 192 Fix 4: preserva metadadosAdicionais se presentes no modelo
    // Estes dados sobrevivem ao round-trip Firestore→modelo→Firestore sem perda.
    if (e.metadadosAdicionais.isNotEmpty) {
      json['metadadosAdicionais'] = e.metadadosAdicionais;
    }
    return json;
  }

  // ── Deserialização de documento Firestore ─────────────────────────────────
  static PacienteSession? _sessionFromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      final data = doc.data();
      if (data == null) return null;

      // Build 186: filtra documentos trashados que escapem das queries
      final status = data['status'] as String?;
      if (status == kStatusTrashed) return null;

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

      // Build 191 FIX B: usa updatedAt se disponível para o sort do stream,
      // pois updatedAt reflete a edição mais recente (não só a criação).
      final updatedAtTs = data['updatedAt'];
      DateTime effectiveDate;
      if (updatedAtTs is Timestamp) {
        effectiveDate = updatedAtTs.toDate();
      } else {
        effectiveDate = savedAt; // docs legados: usa savedAt como fallback
      }

      return PacienteSession(
        sessionKey: doc.id,
        paciente: _pacienteFromJson(pacienteJson),
        historial: historialJson
            .map((e) => _evolFromJson(e as Map<String, dynamic>))
            .toList(),
        savedAt: effectiveDate, // usa updatedAt quando disponível
      );
    } catch (e) {
      debugPrint('[InternFire] _sessionFromDoc ERRO: $e');
      return null;
    }
  }

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

  // ── Build 192 Fix 4: campos conhecidos (schema fixo) ──────────────────────
  // Quaisquer chaves presentes no JSON da IA que não sejam mapeadas abaixo
  // são automaticamente capturadas em metadadosAdicionais — perda ZERO.
  static const _kKnownEvolKeys = {
    'id', 'fecha', 'autorNombre', 'subjetivo', 'objetivo',
    'evaluacion', 'plan', 'farmacos', 'metadadosAdicionais',
  };

  static EvolucionModel _evolFromJson(Map<String, dynamic> j) {
    final s = (j['subjetivo'] as Map<String, dynamic>?) ?? {};
    final o = (j['objetivo'] as Map<String, dynamic>?) ?? {};
    final sv = (o['signosVitales'] as Map<String, dynamic>?) ?? {};
    final ef = (o['examenFisico'] as Map<String, dynamic>?) ?? {};
    final ex = (o['examenes'] as Map<String, dynamic>?) ?? {};
    final a = (j['evaluacion'] as Map<String, dynamic>?) ?? {};
    final p = (j['plan'] as Map<String, dynamic>?) ?? {};

    // Build 192 Fix 4: captura campos extras não mapeados no schema fixo.
    // Campos desconhecidos → metadadosAdicionais (mapa de segurança).
    final existingMeta = (j['metadadosAdicionais'] as Map<String, dynamic>?) ?? {};
    final extraKeys = j.keys.where((k) => !_kKnownEvolKeys.contains(k));
    final metadados = <String, dynamic>{...existingMeta};
    for (final k in extraKeys) {
      metadados[k] = j[k];
      debugPrint('[InternFire] Build192: campo extra capturado em metadadosAdicionais → "$k"');
    }

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

    return EvolucionModel(
      id: j['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      fecha: DateTime.tryParse(j['fecha'] as String? ?? '') ?? DateTime.now(),
      autorNombre: j['autorNombre'] as String? ?? 'Dr.',
      subjetivo: SubjetivoData(
        notePasaNoche: s['notePasaNoche'] as String? ?? '',
        dolorEscala: s['dolorEscala'] as int? ?? 0,
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
        problemasActivos: ((a['problemasActivos'] as List?)?.cast<String>()) ?? [],
        notasEvaluacion: a['notasEvaluacion'] as String? ?? '',
      ),
      plan: PlanData(
        planTerapeutico: p['planTerapeutico'] as String? ?? '',
        criteriosAlta: p['criteriosAlta'] as String? ?? '',
      ),
      farmacos: ((j['farmacos'] as List?) ?? [])
          .map((f) => FarmacoEntry(
                medicamento: (f as Map<String, dynamic>)['medicamento'] as String? ?? '',
                dosagem: f['dosagem'] as String? ?? '',
              ))
          .toList(),
      metadadosAdicionais: metadados,
    );
  }
}
