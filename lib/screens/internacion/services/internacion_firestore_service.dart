// ─────────────────────────────────────────────────────────────────────────────
// InternacionFirestoreService — Build 207
//
// BUILD 207 — CORRECÃO ANTI-TYPE-ERASURE NA DESERIALIZAÇÃO (LEITURA DO BANCO):
//   Flutter Web --release (dart2js --minify) apaga parâmetros genéricos de tipo.
//   Casts com genéricos como 'as Map<String, dynamic>' ou 'as Map<String, dynamic>?'
//   retornam null ou lançam TypeError em release, fazendo todos os sub-mapas
//   (subjetivo, objetivo, avaliação, plano, farmacos) chegarem vazios.
//   Resultado visível: historial copiado retornava apenas '(Sem dados)'.
//
//   FIX: Toda deserialização de mapas aninhados usa o padrão imune:
//     (v is Map) ? Map<String, dynamic>.from(v as Map) : {}
//   e iteracão de listas usa:
//     (item is Map) ? _evolFromJson(Map<String, dynamic>.from(item as Map)) : null
//   Sem nenhum cast 'as Map<String, dynamic>' direto.
//
// InternacionFirestoreService — Build 192 (historial abaixo)
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
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/evolucion_model.dart';
import '../components/patient_accordion.dart';
import 'internacion_persistence.dart';

// ── Constante de coleção — ÚNICA fonte de verdade para o path ──────────────
// Build 186 FIX 1: garante que Web, iOS e Android escrevem/leem no mesmo lugar.
const String kInternacionesCollection = 'internaciones';

// ── Status semânticos do ciclo de vida do documento ──────────────────────────
const String kStatusActive   = 'active';
const String kStatusTrashed  = 'trashed';   // legado — mantido para docs antigos
const String kStatusArchived = 'archived';  // Build 201: novo status de soft-delete

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
      // Build 203 FIX DT-002: removido .orderBy() para evitar FirebaseException
      // por índice composto ausente {status, savedAt}. A ordenação é feita
      // client-side logo abaixo, exatamente como na getDeletedSessions().
      final snapActive = await _col(uid)
          .where('status', isEqualTo: kStatusActive)
          .get();
      // Backward-compat query: documentos sem campo 'status' (criados antes do Build 186)
      // estes têm isDeleted==false mas não têm 'status' definido
      // Build 203 FIX DT-002: idem — removido .orderBy() de {isDeleted, savedAt}.
      final snapLegacy = await _col(uid)
          .where('isDeleted', isEqualTo: false)
          .get();
      // Funde os resultados, evitando duplicatas por sessionKey
      final seen = <String>{};
      final all = <PacienteSession>[];
      for (final doc in [...snapActive.docs, ...snapLegacy.docs]) {
        if (seen.contains(doc.id)) continue;
        final data = doc.data();
        // Build 207: usa _toStr() — imune a type erasure em dart2js.
        final status = _toStr(data['status']);
        if (status == kStatusTrashed) continue;
        if (status == kStatusArchived) continue;
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
  // STREAM — tempo real, multi-device (Build 199)
  // Build 199: Usa status=='active' como query primária (índice de campo único
  // — sem composite index obrigatório). Client-side filtra isDeleted==false
  // como salvaguarda adicional para docs legados sem campo 'status'.
  // Motivo da mudança: .where('isDeleted',...).orderBy('savedAt') exige composite
  // index {isDeleted ASC, savedAt DESC} que pode não existir no projeto Firestore,
  // fazendo o stream lançar silenciosamente e a Home ficar vazia para sempre.
  // Fallback: se a query status=='active' também falhar (índice ausente), o
  // onError no listener chama loadAllSessions() como one-shot de recuperação.
  // MEU PLANTÃO e aba Adulto escutam ESTE mesmo stream → sync total.
  //
  // Build 203 FIX DT-003: removido .orderBy('savedAt') para eliminar dependência
  // de índice composto {status, savedAt}. Query single-field usa auto-index.
  // Ordenação client-side no .map() abaixo — idêntico ao padrão da Lixeira.
  // ─────────────────────────────────────────────────────────────────────────
  static Stream<List<PacienteSession>> sessionsStream(String uid) {
    return _col(uid)
        .where('status', isEqualTo: kStatusActive)
        .snapshots()
        .map((snap) {
          final sessions = snap.docs
              .where((doc) {
                final data = doc.data();
                // Salvaguarda tripla: exclui archived + trashed + isDeleted==true
                // Build 207: usa _toStr() — imune a type erasure em dart2js.
                final status = _toStr(data['status']);
                if (status == kStatusArchived) return false;
                if (status == kStatusTrashed) return false;
                final isDeleted = data['isDeleted'];
                if (isDeleted == true) return false;
                return true;
              })
              .map(_sessionFromDoc)
              .whereType<PacienteSession>()
              .toList();
          // Re-sort client-side por updatedAt para que docs recém-editados
          // subam ao topo imediatamente sem depender da ordem do Firestore.
          sessions.sort((a, b) => b.savedAt.compareTo(a.savedAt));
          return sessions;
        });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SOFT DELETE — Build 201
  // Grava status:'archived' + isDeleted:true + deletedAt.
  // NUNCA chama .delete() nativo — dados ficam no Firestore por 30 dias.
  // Nota: kStatusArchived ('archived') é o novo padrão semântico (Build 201).
  //       Docs legados com status:'trashed' ainda são suportados na lixeira.
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> softDelete(String uid, String sessionKey) async {
    try {
      await _col(uid).doc(sessionKey).update({
        'status': kStatusArchived,
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[InternFire] softDelete OK → $sessionKey (archived)');
    } catch (e) {
      // update() falha se o doc não existe; tenta set com merge como fallback
      try {
        await _col(uid).doc(sessionKey).set({
          'status': kStatusArchived,
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
  // RESTORE — recupera da lixeira (status:'archived'|'trashed' → 'active')
  // Build 201: funciona com ambos kStatusArchived e kStatusTrashed (legado).
  // Usa update() para não sobrescrever outros campos.
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> restoreSession(String uid, String sessionKey) async {
    try {
      await _col(uid).doc(sessionKey).update({
        'status': kStatusActive,
        'isDeleted': false,
        'deletedAt': FieldValue.delete(), // remove o timestamp de exclusão
      });
      debugPrint('[InternFire] restoreSession OK → $sessionKey (active)');
    } catch (e) {
      debugPrint('[InternFire] restoreSession ERRO: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GET DELETED — query para a lixeira (Build 201)
  //
  // CORREÇÃO DE ÍNDICE COMPOSTO:
  //   O bug anterior usava .where(...).orderBy('deletedAt') — isso requer um
  //   índice composto {campo, deletedAt} que frequentemente não existe no
  //   projeto Firestore, fazendo a query lançar FirebaseException silenciosa
  //   (capturada pelo catch) e retornar [] — lixeira sempre vazia.
  //
  // SOLUÇÃO: Remove .orderBy() das queries Firestore (single-field queries
  // usam índices automáticos). Ordena client-side após receber os docs.
  //
  // MULTI-STATUS: Query agora inclui TRÊS queries para cobertura total:
  //   1. status=='archived'  (Build 201 — novo padrão)  ← single-field index
  //   2. status=='trashed'   (legado — docs antigos)    ← single-field index
  //   3. isDeleted==true     (backward-compat)           ← single-field index
  // ─────────────────────────────────────────────────────────────────────────
  static Future<List<DeletedSession>> getDeletedSessions(String uid) async {
    try {
      // Query 1: status=='archived' (Build 201 — novo padrão, SEM .orderBy)
      final snapArchived = await _col(uid)
          .where('status', isEqualTo: kStatusArchived)
          .get();

      // Query 2: status=='trashed' (legado — docs criados antes do Build 201)
      final snapTrashed = await _col(uid)
          .where('status', isEqualTo: kStatusTrashed)
          .get();

      // Query 3: isDeleted==true (backward-compat — docs sem campo 'status')
      final snapLegacy = await _col(uid)
          .where('isDeleted', isEqualTo: true)
          .get();

      final seen = <String>{};
      final all = <DeletedSession>[];
      // Processa archived + trashed + legacy, deduplicando por doc.id
      for (final doc in [...snapArchived.docs, ...snapTrashed.docs, ...snapLegacy.docs]) {
        if (seen.contains(doc.id)) continue;
        // Exclui docs ativos que possam aparecer na query legacy (isDeleted:true legado)
        final docData = doc.data();
        // Build 207: usa _toStr() — imune a type erasure em dart2js.
      final docStatus = _toStr(docData['status']);
        if (docStatus == kStatusActive) continue;
        seen.add(doc.id);
        final ds = _deletedFromDoc(doc);
        if (ds != null) all.add(ds);
      }
      // Ordena client-side por deletedAt desc (sem depender de índice Firestore)
      all.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
      debugPrint('[InternFire] getDeletedSessions OK → ${all.length} itens na lixeira');
      return all;
    } catch (e) {
      debugPrint('[InternFire] getDeletedSessions ERRO: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STREAM DA LIXEIRA — tempo real (Build 202)
  //
  // Problema anterior: _TrashModal usava getDeletedSessions() (one-shot Future).
  // Ao clicar em "Restaurar", o Firestore atualizava o doc (status → active),
  // mas a UI da lixeira só removia o card via setState local — não havia garantia
  // de consistência se outro dispositivo deletasse/restaurasse ao mesmo tempo.
  //
  // Solução: Stream reativo da query status=='archived' com .snapshots().
  // O Firestore empurra updates em tempo real — card desaparece da lixeira
  // INSTANTANEAMENTE após restoreSession() sem precisar de setState manual.
  //
  // Para backward-compat (docs legados com status=='trashed'), o stream
  // inclui AMBAS as queries via Streams.merge (sem rxdart: usa StreamController
  // + listeners independentes, deduplicando por doc.id no map()).
  //
  // IMPORTANTE: Cada query usa single-field index (sem composite) — garante
  // que o stream não lança FirebaseException por índice ausente.
  // ─────────────────────────────────────────────────────────────────────────
  static Stream<List<DeletedSession>> deletedSessionsStream(String uid) {
    // Combina dois streams Firestore (archived + trashed legado) via
    // StreamController broadcast — cada snap de qualquer query re-emite a lista
    // fundida e ordenada. Sem rxdart, sem composite index.
    QuerySnapshot<Map<String, dynamic>>? snapArchived;
    QuerySnapshot<Map<String, dynamic>>? snapTrashed;

    final controller = StreamController<List<DeletedSession>>.broadcast();

    void emit() {
      final seen = <String>{};
      final all  = <DeletedSession>[];
      for (final doc in [
        ...(snapArchived?.docs ?? []),
        ...(snapTrashed?.docs  ?? []),
      ]) {
        if (seen.contains(doc.id)) continue;
        // Build 207: usa _toStr() — imune a type erasure em dart2js.
        final st = _toStr((doc.data())['status']);
        if (st == kStatusActive) continue; // exclui docs ativos que escapem
        seen.add(doc.id);
        final ds = _deletedFromDoc(doc);
        if (ds != null) all.add(ds);
      }
      all.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
      if (!controller.isClosed) controller.add(all);
    }

    // Query 1 — status=='archived' (Build 201+)
    final subA = _col(uid)
        .where('status', isEqualTo: kStatusArchived)
        .snapshots()
        .listen(
          (snap) { snapArchived = snap; emit(); },
          onError: (Object e) {
            debugPrint('[InternFire] deletedStream(archived) err: $e');
          },
        );

    // Query 2 — status=='trashed' (legado)
    final subT = _col(uid)
        .where('status', isEqualTo: kStatusTrashed)
        .snapshots()
        .listen(
          (snap) { snapTrashed = snap; emit(); },
          onError: (Object e) {
            debugPrint('[InternFire] deletedStream(trashed) err: $e');
          },
        );

    controller.onCancel = () {
      subA.cancel();
      subT.cancel();
    };

    return controller.stream;
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

  // Build 207: usa _toStr() em vez de 'as String? ?? ""' — imune a type erasure.
  // O cast 'as String?' pode lancar TypeError em dart2js para valores numéricos
  // ou booleans salvos por engano em campos de texto.
  static PacienteInternacaoData _pacienteFromJson(Map<String, dynamic> j) =>
      PacienteInternacaoData(
        nome: _toStr(j['nome']),
        cama: _toStr(j['cama']),
        idade: _toStr(j['idade']),
        sexo: _toStr(j['sexo']),
        diagnostico: _toStr(j['diagnostico']),
        diaInternacao: _toInt(j['diaInternacao'], fallback: 1),
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

      // Build 186+201: filtra docs trashados ou arquivados que escapem das queries
      // Build 207: usa _toStr() em vez de 'as String?' — imune a type erasure.
      final status = _toStr(data['status']);
      if (status == kStatusTrashed) return null;
      if (status == kStatusArchived) return null;

      // Build 207 FIX TYPE-ERASURE: 'as Map<String, dynamic>?' falha em dart2js.
      // Usa 'is Map' (sem genérico) + Map.from() explícito — 100% seguro em release.
      final rawPaciente = data['paciente'];
      final pacienteJson = (rawPaciente is Map)
          ? Map<String, dynamic>.from(rawPaciente as Map)
          : <String, dynamic>{};

      // Build 207 FIX TYPE-ERASURE: 'e as Map<String, dynamic>' dentro do .map()
      // é a CAUSA RAIZ do historial vazio. Substitui por is Map + Map.from().
      final rawHistorial = data['historial'];
      final historialList = (rawHistorial is List) ? rawHistorial : <dynamic>[];

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
        // Build 207: cada item do historialList convertido com 'is Map' + Map.from()
        // sem nenhum 'as Map<String, dynamic>' — imune à minificação dart2js.
        historial: historialList
            .map((e) {
              if (e is Map) {
                return _evolFromJson(Map<String, dynamic>.from(e as Map));
              }
              return null;
            })
            .whereType<EvolucionModel>()
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
      // Build 207: usa 'is Map' + Map.from() — imune a type erasure em dart2js.
      final rawPaciente = data['paciente'];
      final pacienteJson = (rawPaciente is Map)
          ? Map<String, dynamic>.from(rawPaciente as Map)
          : <String, dynamic>{};
      final deletedAtTs = data['deletedAt'];
      DateTime? deletedAt;
      if (deletedAtTs is Timestamp) {
        deletedAt = deletedAtTs.toDate();
      } else if (deletedAtTs is String) {
        deletedAt = DateTime.tryParse(deletedAtTs);
      }
      final paciente = _pacienteFromJson(pacienteJson);
      final rawHistorial2 = data['historial'];
      final historialCount2 = (rawHistorial2 is List) ? rawHistorial2.length : 0;
      return DeletedSession(
        sessionKey: doc.id,
        paciente: paciente,
        historialCount: historialCount2,
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

  // ── Build 199: Helpers de coerção numérica/booleana ──────────────────────
  // Firestore/JavaScript não distingue int de double: um campo gravado como
  // int:0 pode voltar como double:0.0. O cast `as int?` lança TypeError nesse
  // caso, corrompendo _sessionFromDoc inteiro. Esses helpers são à prova de bala.
  static int _toInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static bool _toBool(dynamic v, {bool fallback = false}) {
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v is int) return v != 0;
    if (v is String) return v == 'true' || v == '1';
    return fallback;
  }

  static String _toStr(dynamic v, {String fallback = ''}) {
    if (v == null) return fallback;
    if (v is String) return v;
    return v.toString();
  }

  static EvolucionModel _evolFromJson(Map<String, dynamic> j) {
    // Build 199+207: helper seguro para extrair sub-mapas sem lançar exceção.
    // Build 207: usa 'is Map' (sem genérico) — imune à minificação dart2js.
    // 'is Map' é checagem estrutural que sobrevive ao --minify do dart2js.
    Map<String, dynamic> safe(dynamic v) =>
        (v is Map) ? Map<String, dynamic>.from(v as Map) : {};

    final s  = safe(j['subjetivo']);
    final o  = safe(j['objetivo']);
    final sv = safe(o['signosVitales']);
    final ef = safe(o['examenFisico']);
    final ex = safe(o['examenes']);
    final a  = safe(j['evaluacion']);
    final p  = safe(j['plan']);

    // Build 207: log de diagnóstico para confirmar leitura dos sub-mapas em release.
    debugPrint('[InternFire] _evolFromJson BUILD-207 → '
        'S=${s.keys.length}k O=${o.keys.length}k sv=${sv.keys.length}k '
        'ef=${ef.keys.length}k ex=${ex.keys.length}k '
        'A=${a.keys.length}k P=${p.keys.length}k');

    // Build 192 Fix 4: captura campos extras não mapeados no schema fixo.
    // Campos desconhecidos → metadadosAdicionais (mapa de segurança).
    final existingMeta = safe(j['metadadosAdicionais']);
    final extraKeys = j.keys.where((k) => !_kKnownEvolKeys.contains(k));
    final metadados = <String, dynamic>{...existingMeta};
    for (final k in extraKeys) {
      metadados[k] = j[k];
    }

    EstadoClinical? estado;
    final estadoStr = a['estado'];
    if (estadoStr is String) {
      for (final e in EstadoClinical.values) {
        if (e.name == estadoStr) { estado = e; break; }
      }
    }

    // Build 199: problemasActivos — Firestore pode gravar como List<dynamic>
    // ou List<String>; cast seguro via whereType.
    List<String> safeStrList(dynamic v) {
      if (v is! List) return [];
      return v.whereType<String>().toList();
    }

    // Build 199: farmacos — cada entrada parseada com try/catch individual
    // para que uma entrada corrompida não apague o historial inteiro.
    List<FarmacoEntry> parseFarmacos(dynamic raw) {
      if (raw is! List) return [];
      final result = <FarmacoEntry>[];
      for (final f in raw) {
        try {
          final fm = f is Map ? Map<String, dynamic>.from(f) : <String, dynamic>{};
          result.add(FarmacoEntry(
            medicamento: _toStr(fm['medicamento']),
            dosagem: _toStr(fm['dosagem']),
          ));
        } catch (_) { /* pula entrada corrompida sem perder as restantes */ }
      }
      return result;
    }

    return EvolucionModel(
      id: _toStr(j['id'], fallback: DateTime.now().millisecondsSinceEpoch.toString()),
      fecha: DateTime.tryParse(_toStr(j['fecha'])) ?? DateTime.now(),
      autorNombre: _toStr(j['autorNombre'], fallback: 'Dr.'),
      subjetivo: SubjetivoData(
        notePasaNoche: _toStr(s['notePasaNoche']),
        // Build 199: dolorEscala é int? — null = não informado, 0 = sem dor.
        // Firestore pode gravar int como double(0.0); convertemos e preservamos null.
        dolorEscala: s['dolorEscala'] == null ? null : _toInt(s['dolorEscala']),
        fiebre:       _toBool(s['fiebre']),
        disnea:       _toBool(s['disnea']),
        nauseas:      _toBool(s['nauseas']),
        tos:          _toBool(s['tos']),
        alimentacion: _toStr(s['alimentacion']),
        diuresis:     _toStr(s['diuresis']),
        evacuacion:   _toStr(s['evacuacion']),
        suenoRestado: _toBool(s['suenoRestado']),
        notasLibres:  _toStr(s['notasLibres']),
      ),
      objetivo: ObjetivoData(
        signosVitales: SignosVitales(
          pa:          _toStr(sv['pa']),
          fc:          _toStr(sv['fc']),
          fr:          _toStr(sv['fr']),
          satO2:       _toStr(sv['satO2']),
          temperatura: _toStr(sv['temperatura']),
        ),
        examenFisico: ExamenFisico(
          estadoGeneral: _toStr(ef['estadoGeneral']),
          acv:           _toStr(ef['acv']),
          ar:            _toStr(ef['ar']),
          abdomen:       _toStr(ef['abdomen']),
          extremidades:  _toStr(ef['extremidades']),
        ),
        examenes: ExamenesComplementarios(
          laboratorio: _toStr(ex['laboratorio']),
          imagenes:    _toStr(ex['imagenes']),
          culturas:    _toStr(ex['culturas']),
          ecg:         _toStr(ex['ecg']),
        ),
        tratamientoActual: _toStr(o['tratamientoActual']),
      ),
      evaluacion: EvaluacionData(
        estado: estado,
        problemasActivos: safeStrList(a['problemasActivos']),
        notasEvaluacion:  _toStr(a['notasEvaluacion']),
      ),
      plan: PlanData(
        planTerapeutico: _toStr(p['planTerapeutico']),
        criteriosAlta:   _toStr(p['criteriosAlta']),
      ),
      farmacos: parseFarmacos(j['farmacos']),
      metadadosAdicionais: metadados,
    );
  }
}
