// ─────────────────────────────────────────────────────────────────────────────
// InternacionScreen — Build 176
//
// 168-1: Firestore Sync — sessions stream em tempo real (multi-device)
// 168-2: Lixeira 30d — softDelete (isDeleted:true) em vez de hard delete
// 168-3: _SessionCard redesenhado — severity border + [Editar][Excluir] + [Evoluir]
// 168-4: Card body tap → _SessionPreviewDialog (read-only + ações)
// 168-5: PatientAccordion tap → _DocumentPreviewModal (paper-style viewer)
// 168-6: Auto-save on Nueva — salva silencioso se dirty, skip se vazio
// 168-R: R1(FAB→AppBar) R2(S fechado) R3(Auditoria) R4(Retomar same-day)
// 171:   Anti-empty save, Edit vs Evolve separation, post-save resetAll
// 173:   _TrashModal — Papelera de Reciclaje (30d) com Restaurar + Hard Delete
// 176:   Dashboard Clínico — AppBar compacta, Row 60/40, SOAP 2×2,
//        Action Bar 25/50/25, Grid responsivo MaxCrossAxisExtent
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import 'models/evolucion_model.dart';
import 'components/resumen_header.dart';
import 'components/patient_accordion.dart';
import 'components/internacion_theme.dart';
import 'components/copilot_button.dart';
import 'components/farmacos_accordion.dart';
import 'components/soap/soap_section.dart';
import 'services/internacion_persistence.dart';
import 'services/internacion_firestore_service.dart';
import 'services/soap_copilot_service.dart';
import 'services/drug_interaction_service.dart';

class InternacionScreen extends StatefulWidget {
  // Build 195: sessão pré-selecionada ao abrir via card Mi Guardia
  final PacienteSession? initialSession;

  const InternacionScreen({super.key, this.initialSession});

  @override
  State<InternacionScreen> createState() => _InternacionScreenState();
}

class _InternacionScreenState extends State<InternacionScreen> {
  PacienteInternacaoData _paciente =
      const PacienteInternacaoData(diaInternacao: 1);
  List<EvolucionModel> _historial = [];
  late EvolucionModel _draftEvolucion;

  final _soapKey = GlobalKey<SoapSectionWidgetState>();

  // 168-1: Firestore stream
  List<PacienteSession> _savedSessions = [];
  bool _sessionsLoaded = false;
  StreamSubscription<List<PacienteSession>>? _sessionsSub;
  String? _currentSessionKey; // chave da sessão ativa em edição

  // ── Build 171: Edit vs Evolve mode ───────────────────────────────────────
  bool _isEditMode = false;        // true → Guardar sobrescreve; false → append
  String? _editingEvolucionId;     // id do EvolucionModel sendo editado
  // Build 192 Fix 2: contador incremental que força recriação do PatientAccordion
  // ao chamar _editSession() ou _evolveSession() com a mesma sessionKey.
  // Sem isso, os TextEditingControllers do accordion ficam estáticos quando
  // _currentSessionKey não muda (ex: evoluir o mesmo paciente consecutivamente).
  int _accordionGeneration = 0;

  @override
  void initState() {
    super.initState();
    // Build 208: _newDraft() sem argumento aqui pois o context/provider
    // ainda não está disponível em initState. O doctorName será injetado
    // no first build via _ensureDoctorName().
    _draftEvolucion = _newDraft();
    DrugInteractionService.instance.init();
    // Aguarda o primeiro frame para ter acesso ao provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSessions();
      // Build 195: pré-carrega a sessão passada pelo Mi Guardia card
      // Usa _evolveSession para colocar o paciente em modo de nova evolução
      // com o histórico completo carregado no painel lateral.
      final initial = widget.initialSession;
      if (initial != null) {
        _evolveSession(initial);
      }
    });
  }

  @override
  void dispose() {
    _sessionsSub?.cancel();
    super.dispose();
  }

  // ── 168-1: Inicia stream Firestore (com fallback local) ──────────────────
  void _initSessions() {
    final uid = _uid;
    if (uid != null && uid.isNotEmpty) {
      _sessionsSub = InternacionFirestoreService.sessionsStream(uid)
          .listen((sessions) {
        if (mounted) {
          setState(() {
            _savedSessions = sessions;
            _sessionsLoaded = true;
          });
        }
      }, onError: (_) => _loadSessionsLocal());
    } else {
      _loadSessionsLocal();
    }
  }

  Future<void> _loadSessionsLocal() async {
    final sessions = await InternacionPersistence.loadAllSessions();
    if (mounted) {
      setState(() {
        _savedSessions = sessions;
        _sessionsLoaded = true;
      });
    }
  }

  String? get _uid {
    try {
      return context.read<AppProvider>().currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  String _doctorName(AppProvider p) {
    final name = p.userName.trim();
    if (name.isEmpty) return 'Dr.';
    if (name.toLowerCase().startsWith('dr')) return name;
    return 'Dr. $name';
  }

  // Build 208: getter seguro que lê o nome do médico do provider sem watch.
  // Usado em métodos que não têm acesso ao BuildContext do build() (ex: após callbacks).
  String get _safeDoctorName {
    try {
      return _doctorName(context.read<AppProvider>());
    } catch (_) {
      return 'Dr.';
    }
  }

  // Build 209: helper de validação de conteúdo profundo.
  // Retorna true se o texto não for nulo e tiver caracteres além de espaço.
  bool _hasText(String? text) => text != null && text.trim().isNotEmpty;

  // Build 208: _newDraft aceita doctorName para que 'autorNombre' nunca
  // seja o fallback hardcoded 'Dr.' quando o médico está logado.
  // Chamadas sem argumento continuam funcionando (param opcional).
  EvolucionModel _newDraft([String? doctorName]) => EvolucionModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fecha: DateTime.now(),
        autorNombre: (doctorName != null && doctorName.trim().isNotEmpty)
            ? doctorName
            : 'Dr.',
      );

  // ── 168-1: Salva na nuvem (com fallback local) ───────────────────────────
  // Build 191 FIX A+C: distingue INSERT (novo) de UPDATE (existente).
  // - UPDATE usa .update() preservando savedAt + gravando updatedAt.
  // - INSERT usa .set(merge:true) com savedAt (novo doc).
  // Ambos garantem isDeleted:false + status:'active' no payload.
  Future<void> _persistSession() async {
    final uid = _uid;
    if (uid != null && uid.isNotEmpty) {
      if (_currentSessionKey != null) {
        // Prontuário existente — UPDATE cirúrgico (preserva savedAt, grava updatedAt)
        await InternacionFirestoreService.updateSession(
          uid: uid,
          existingKey: _currentSessionKey!,
          paciente: _paciente,
          historial: _historial,
        );
      } else {
        // Novo prontuário — INSERT
        await InternacionFirestoreService.saveSession(
          uid: uid,
          paciente: _paciente,
          historial: _historial,
          existingKey: null,
        );
        _currentSessionKey = InternacionFirestoreService.sessionKey(_paciente);
      }
    }
    // Fallback local sempre (offline resilience)
    await InternacionPersistence.saveSession(
      paciente: _paciente,
      historial: _historial,
    );
  }

  void _onSaveEvolucion(EvolucionModel ev) async {
    // ── Build 209: Sovereign Parent re-merge ────────────────────────────
    // O _draftEvolucion (Pai) é a fonte de verdade absoluta para metadados.
    // O widget filho só substitui seções SOAP se tiver conteúdo textual real.
    // Mapeia campos reais do modelo — sem phantom fields do pseudocódigo.
    {
      final medicoLogado = _safeDoctorName; // via AppProvider.userName — sem hardcode
      final child = _soapKey.currentState?.currentEvolucion;
      final parent = _draftEvolucion;

      final evolucionToSave = parent.copyWith(
        autorNombre: medicoLogado,
        // Subjetivo: filho substitui apenas se tem nota de passagem ou notas livres
        subjetivo: (child != null &&
                (_hasText(child.subjetivo.notePasaNoche) ||
                 _hasText(child.subjetivo.notasLibres)))
            ? child.subjetivo
            : parent.subjetivo,
        // Objetivo: filho substitui apenas se tem sinais vitais OU exame físico
        objetivo: (child != null &&
                (!child.objetivo.signosVitales.isEmpty ||
                 _hasText(child.objetivo.examenFisico.estadoGeneral)))
            ? child.objetivo
            : parent.objetivo,
        // Avaliação: filho substitui apenas se tem notas de avaliação
        evaluacion: (child != null &&
                _hasText(child.evaluacion.notasEvaluacion))
            ? child.evaluacion
            : parent.evaluacion,
        // Plano: filho substitui apenas se tem plano terapêutico
        plan: (child != null && _hasText(child.plan.planTerapeutico))
            ? child.plan
            : parent.plan,
        // farmacos: pai é sempre a fonte (já mantido pelo Save button do Build 208)
        farmacos: parent.farmacos,
        // id e fecha: imutáveis — sempre do pai
        id: parent.id,
        fecha: parent.fecha,
      );

      // Logs de diagnóstico (removidos em release por tree-shaking de debugPrint)
      debugPrint('[SAVE_209] medico=${evolucionToSave.autorNombre}');
      debugPrint('[SAVE_209] S_pasaNoche=${evolucionToSave.subjetivo.notePasaNoche}');
      debugPrint('[SAVE_209] S_notasLibres=${evolucionToSave.subjetivo.notasLibres}');
      debugPrint('[SAVE_209] O_signosVitalesEmpty=${evolucionToSave.objetivo.signosVitales.isEmpty}');
      debugPrint('[SAVE_209] O_estadoGeral=${evolucionToSave.objetivo.examenFisico.estadoGeneral}');
      debugPrint('[SAVE_209] A_notas=${evolucionToSave.evaluacion.notasEvaluacion}');
      debugPrint('[SAVE_209] P_plan=${evolucionToSave.plan.planTerapeutico}');

      // Guard anti-regressão: nunca salva evolução com autorNombre genérico
      // (stripped em release — safe em produção, ativo apenas em debug/test)
      assert(
        _hasText(evolucionToSave.autorNombre) &&
            evolucionToSave.autorNombre != 'Dr.',
        '[Build 209] autorNombre genérico interceptado: "${evolucionToSave.autorNombre}"',
      );

      // Substitui ev pelo payload blindado antes de qualquer lógica downstream
      ev = evolucionToSave;
    }

    // ── Build 180: Admit First, Evolve Later ────────────────────────────
    // Exige apenas nome OU cama preenchidos; SOAP pode estar em branco.
    if (_paciente.nome.trim().isEmpty && _paciente.cama.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_isEs
                ? 'Ingresa al menos el nombre o la cama del paciente.'
                : 'Informe ao menos o nome ou o leito do paciente.'),
          ),
        ]),
        backgroundColor: InternacionTheme.amber,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }

    // ── Build 171: Edit mode → overwrite; else → append ──────────────────
    // Build 203 FIX DT-006: Captura snapshots PRÉ-modificação para rollback.
    // Se _persistSession() lançar, restauramos o estado exato pré-clique
    // e exibimos SnackBar de erro — o formulário NUNCA é resetado em falha.
    final preClickHistorial      = List<EvolucionModel>.unmodifiable(_historial);
    final preClickIsEditMode     = _isEditMode;
    final preClickEvolucionId    = _editingEvolucionId;
    final preClickSessionKey     = _currentSessionKey;

    final List<EvolucionModel> updatedHistorial;
    if (_isEditMode && _editingEvolucionId != null) {
      updatedHistorial = [
        for (final e in _historial)
          if (e.id == _editingEvolucionId) ev.copyWith(id: _editingEvolucionId) else e,
      ];
    } else {
      updatedHistorial = [..._historial, ev];
    }

    setState(() {
      _historial = updatedHistorial;
      // Build 208: usa _safeDoctorName para que o próximo draft já tenha
      // o nome real do médico, sem depender do addPostFrameCallback.
      _draftEvolucion = _newDraft(_safeDoctorName);
      _isEditMode = false;
      _editingEvolucionId = null;
    });

    // ── Build 197: Captura snapshot ANTES do reset para injeção otimista ──
    // Constrói o PacienteSession que acabará de ser gravado no Firestore,
    // usando os dados que ainda estão vivos no estado antes do reset.
    // Isso evita esperar o round-trip do Firestore para atualizar o grid.
    final savedPaciente = _paciente;
    final savedHistorial = List<EvolucionModel>.unmodifiable(updatedHistorial);
    final sessionKeyForNew = _currentSessionKey ??
        InternacionFirestoreService.sessionKey(savedPaciente);
    final optimisticSession = PacienteSession(
      sessionKey: sessionKeyForNew,
      paciente: savedPaciente,
      historial: savedHistorial,
      savedAt: DateTime.now(),
    );

    // Build 203 FIX DT-006: try/catch robusto com rollback visual em falha.
    // Caminho feliz: persiste → injeta otimisticamente → reseta workspace.
    // Caminho de erro: restaura _historial e modo de edição, exibe erro vermelho.
    try {
      await _persistSession();
    } catch (e) {
      // Falha de rede ou Firestore — restaura estado pré-clique sem perda de dado.
      if (!mounted) return;
      setState(() {
        _historial          = preClickHistorial;
        _isEditMode         = preClickIsEditMode;
        _editingEvolucionId = preClickEvolucionId;
        _currentSessionKey  = preClickSessionKey;
        // Devolve o rascunho ao SOAP para que o médico não perca o que digitou
        _draftEvolucion     = ev;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_isEs
                ? 'Error de conexión — evolución NO guardada. Intente de nuevo.'
                : 'Erro de conexão — evolução NÃO salva. Tente novamente.'),
          ),
        ]),
        backgroundColor: InternacionTheme.red,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }

    // Build 191 FIX C + Build 197: Inject optimistic session immediately.
    // Injeta a sessão recém-salva diretamente em _savedSessions SEM esperar
    // o round-trip do Firestore. O stream confirmará e substituirá depois.
    // Estratégia: remove a versão antiga (se existia) e insere a nova no topo.
    if (!mounted) return;
    // Build 208: _safeDoctorName disponível aqui (context mounted e provider ativo).
    final freshDraft = _newDraft(_safeDoctorName);
    setState(() {
      // Workspace reset — só acontece após _persistSession() bem-sucedido
      _paciente = const PacienteInternacaoData(diaInternacao: 1);
      _historial = [];
      _draftEvolucion = freshDraft;
      _currentSessionKey = null;
      _isEditMode = false;
      _editingEvolucionId = null;
      // Injeção otimista: insere sessão no topo de _savedSessions
      // Remove versão antiga (mesma chave) + insere versão nova atualizada
      final otherSessions = _savedSessions
          .where((s) => s.sessionKey != sessionKeyForNew)
          .toList();
      _savedSessions = [optimisticSession, ...otherSessions];
    });
    _soapKey.currentState?.resetSoap(freshDraft);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(_isEs
              ? 'Evolución guardada y sincronizada'
              : 'Evolução salva e sincronizada'),
        ]),
        backgroundColor: InternacionTheme.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  void _onAiApproved(SoapDraftResult draft) {
    _soapKey.currentState?.applyAiDraft(draft);
    if (draft.hasPatientData) {
      setState(() {
        _paciente = _paciente.copyWith(
          nome: draft.pacienteNome?.isNotEmpty == true
              ? draft.pacienteNome!
              : _paciente.nome,
          cama: draft.pacienteCama?.isNotEmpty == true
              ? draft.pacienteCama!
              : _paciente.cama,
          idade: draft.pacienteIdade?.isNotEmpty == true
              ? draft.pacienteIdade!
              : _paciente.idade,
          sexo: draft.pacienteSexo?.isNotEmpty == true
              ? draft.pacienteSexo!
              : _paciente.sexo,
          diagnostico: draft.pacienteDiagnostico?.isNotEmpty == true
              ? draft.pacienteDiagnostico!
              : _paciente.diagnostico,
          diaInternacao: draft.pacienteDiaInternacion != null
              ? draft.pacienteDiaInternacion!
              : _paciente.diaInternacao,
        );
      });
    }
  }

  // Build 196: Agrupa sessões por paciente (nome normalizado) e retorna apenas
  // a mais recente por paciente — elimina duplicidade de cards no grid.
  // Null-safe: usa ?. para blindar contra edge cases do Firestore.
  List<PacienteSession> _deduplicatedSessions() {
    try {
      final Map<String, PacienteSession> byPatient = {};
      for (final s in _savedSessions) {
        final nome = s.paciente.nome.trim().toLowerCase();
        final key = nome.isNotEmpty ? nome : s.sessionKey;
        final existing = byPatient[key];
        if (existing == null || s.savedAt.isAfter(existing.savedAt)) {
          byPatient[key] = s;
        }
      }
      final result = byPatient.values.toList()
        ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
      return result;
    } catch (e) {
      debugPrint('[InternacionScreen] _deduplicatedSessions error: $e');
      return _savedSessions; // fallback: retorna lista sem deduplicar
    }
  }

  // ── 168-2: Soft Delete (Lixeira 30d) ─────────────────────────────────────
  Future<void> _deleteSession(PacienteSession session) async {
    final uid = _uid;
    if (uid != null && uid.isNotEmpty) {
      await InternacionFirestoreService.softDelete(uid, session.sessionKey);
    }
    // Também remove do local para consistência offline
    await InternacionPersistence.deleteSession(session.sessionKey);
    if (mounted) {
      setState(() {
        _savedSessions = _savedSessions
            .where((s) => s.sessionKey != session.sessionKey)
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_isEs
                ? 'Paciente movido a la papelera (30 días)'
                : 'Paciente movido para a lixeira (30 dias)'),
          ),
        ]),
        backgroundColor: InternacionTheme.amber,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  // ── Build 171: EDITAR — carrega última evolução para sobrescrita ──────────
  void _editSession(PacienteSession session) {
    if (session.historial.isEmpty) {
      // Sem evolução prévia: cai em _evolveSession por segurança
      _evolveSession(session);
      return;
    }
    final lastEv = session.historial.last;
    final editDraft = lastEv.copyWith(
      // Mantém o mesmo id para sobrescrever depois
      fecha: DateTime.now(),
    );
    setState(() {
      _paciente = session.paciente; // preserva diaInternacao original
      _historial = session.historial;
      _draftEvolucion = editDraft;
      _currentSessionKey = session.sessionKey;
      _isEditMode = true;
      _editingEvolucionId = lastEv.id;
      // Build 192 Fix 2: incrementa generation para forçar recriação
      // do PatientAccordion e hidratar seus TextEditingControllers
      // com os dados corretos da sessão sendo editada.
      _accordionGeneration++;
      _savedSessions = _savedSessions
          .where((s) => s.sessionKey != session.sessionKey)
          .toList();
    });
    _soapKey.currentState?.resetSoap(editDraft);

    final isEs = _isEs;
    final nome = session.paciente.nome.isNotEmpty
        ? session.paciente.nome
        : (isEs ? 'Paciente' : 'Paciente');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(isEs
              ? 'Modo EDITAR — Día ${session.paciente.diaInternacao} de $nome'
              : 'Modo EDITAR — Dia ${session.paciente.diaInternacao} de $nome'),
        ),
      ]),
      backgroundColor: InternacionTheme.amber,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Build 171: EVOLUIR — nova folha em branco, dia + 1 ───────────────────
  void _evolveSession(PacienteSession session) {
    final nextPaciente = session.paciente.copyWith(
      diaInternacao: session.paciente.diaInternacao + 1,
    );
    // Build 208: usa autorNombre do último historial OU o médico logado agora.
    // Nunca usa o fallback hardcoded 'Dr.' se o médico está disponível.
    final evolveAutor = session.historial.isNotEmpty
        ? session.historial.last.autorNombre
        : _safeDoctorName;
    final blankDraft = EvolucionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fecha: DateTime.now(),
      autorNombre: evolveAutor,
      subjetivo: const SubjetivoData(),
      objetivo: const ObjetivoData(),
      evaluacion: const EvaluacionData(),
      plan: const PlanData(),
    );
    setState(() {
      _paciente = nextPaciente; // dia + 1; nome/cama/diag preservados
      _historial = session.historial;
      _draftEvolucion = blankDraft;
      _currentSessionKey = session.sessionKey;
      _isEditMode = false;
      _editingEvolucionId = null;
      // Build 192 Fix 2: incrementa generation para forçar recriação
      // do PatientAccordion com carry-over correto de nome/cama/diag.
      _accordionGeneration++;
      _savedSessions = _savedSessions
          .where((s) => s.sessionKey != session.sessionKey)
          .toList();
    });
    _soapKey.currentState?.resetSoap(blankDraft);

    final isEs = _isEs;
    final nome = session.paciente.nome.isNotEmpty
        ? session.paciente.nome
        : (isEs ? 'Paciente' : 'Paciente');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.add_circle_outline_rounded,
            color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(isEs
              ? 'Nova folha — Día ${nextPaciente.diaInternacao} de $nome'
              : 'Nova folha — Dia ${nextPaciente.diaInternacao} de $nome'),
        ),
      ]),
      backgroundColor: InternacionTheme.accentLight,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── 168-6: Auto-save preventivo + Reset ──────────────────────────────────
  // Se há dados preenchidos → salva silenciosamente antes de limpar.
  // Se tela está vazia → apenas limpa (sem criar registro fantasma).
  bool get _isDirty {
    final s = _draftEvolucion.subjetivo;
    final o = _draftEvolucion.objetivo;
    final a = _draftEvolucion.evaluacion;
    final p = _draftEvolucion.plan;
    return s.notePasaNoche.isNotEmpty ||
        s.dolorEscala != null ||
        s.fiebre || s.disnea || s.nauseas || s.tos || s.suenoRestado ||
        s.alimentacion.isNotEmpty || s.diuresis.isNotEmpty ||
        s.evacuacion.isNotEmpty || s.notasLibres.isNotEmpty ||
        !o.signosVitales.isEmpty ||
        o.examenFisico.estadoGeneral.isNotEmpty ||
        o.examenFisico.acv.isNotEmpty || o.examenFisico.ar.isNotEmpty ||
        o.examenFisico.abdomen.isNotEmpty ||
        o.examenFisico.extremidades.isNotEmpty ||
        o.examenes.laboratorio.isNotEmpty ||
        a.notasEvaluacion.isNotEmpty || a.problemasActivos.isNotEmpty ||
        p.planTerapeutico.isNotEmpty || p.criteriosAlta.isNotEmpty ||
        _paciente.nome.isNotEmpty || _paciente.cama.isNotEmpty ||
        _historial.isNotEmpty;
  }

  Future<void> _confirmAndReset() async {
    final isEs = _isEs;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Theme.of(ctx).brightness == Brightness.dark
            ? const Color(0xFF0D1117)
            : Colors.white,
        title: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: InternacionTheme.accentLight.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.cleaning_services_rounded,
                size: 18, color: InternacionTheme.accentLight),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isEs ? '¿Iniciar Nueva Evolución?' : 'Iniciar Nova Evolução?',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Theme.of(ctx).brightness == Brightness.dark
                    ? Colors.white
                    : const Color(0xFF111827),
              ),
            ),
          ),
        ]),
        content: Text(
          isEs
              ? 'Si hay datos, se guardarán automáticamente antes de limpiar.'
              : 'Se houver dados, serão salvos automaticamente antes de limpar.',
          style: TextStyle(
            fontSize: 13.5,
            height: 1.5,
            color: Theme.of(ctx).brightness == Brightness.dark
                ? Colors.white70
                : const Color(0xFF374151),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).brightness == Brightness.dark
                  ? Colors.white54
                  : const Color(0xFF6B7280),
            ),
            child: Text(isEs ? 'Cancelar' : 'Cancelar',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: InternacionTheme.accentLight,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(isEs ? 'Confirmar' : 'Confirmar',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // 168-6: Auto-save silencioso se dirty
    // Build 197: captura snapshot pré-reset para injeção otimista (igual ao _onSaveEvolucion)
    PacienteSession? autoSaveOptimistic;
    if (_isDirty && _historial.isNotEmpty) {
      final autoKeyForNew = _currentSessionKey ??
          InternacionFirestoreService.sessionKey(_paciente);
      autoSaveOptimistic = PacienteSession(
        sessionKey: autoKeyForNew,
        paciente: _paciente,
        historial: List<EvolucionModel>.unmodifiable(_historial),
        savedAt: DateTime.now(),
      );
      await _persistSession();
    }

    await InternacionPersistence.clearActiveSession(_paciente);
    // Build 208: usa _safeDoctorName para preservar nome do médico no próximo draft.
    final freshDraft = _newDraft(_safeDoctorName);
    setState(() {
      _paciente = const PacienteInternacaoData(diaInternacao: 1);
      _historial = [];
      _draftEvolucion = freshDraft;
      _currentSessionKey = null;
      // Build 197: injeta sessão auto-salva otimisticamente no grid
      if (autoSaveOptimistic != null) {
        final snap = autoSaveOptimistic;
        final otherSessions = _savedSessions
            .where((s) => s.sessionKey != snap.sessionKey)
            .toList();
        _savedSessions = [snap, ...otherSessions];
      }
    });
    _soapKey.currentState?.resetSoap(freshDraft);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(isEs
              ? 'Pizarrón limpio. Listo para el próximo paciente.'
              : 'Slate limpo. Pronto para o próximo paciente.'),
        ]),
        backgroundColor: InternacionTheme.accentLight,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  // ── R3: Auditoria clínica — acessível via _SessionPreviewDialog ──────────
  void _showAuditoriaModal(
      BuildContext ctx, EvolucionModel ev, bool dark, String lang) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AuditoriaViewer(ev: ev, dark: dark, lang: lang),
    );
  }

  // ── 168-5: Document Preview Modal (paper-style) ──────────────────────────
  void _showDocumentPreview(BuildContext ctx, bool dark, String lang) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DocumentPreviewModal(
        paciente: _paciente,
        historial: _historial,
        draftEvolucion: _draftEvolucion,
        dark: dark,
        lang: lang,
      ),
    );
  }

  bool get _isEs {
    try {
      return context.read<AppProvider>().lang == 'es';
    } catch (_) {
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final lang = p.lang;
    final theme = InternacionTheme(dark);
    final isEs = lang == 'es';
    final doctorName = _doctorName(p);

    // Build 208: injeta doctorName no _draftEvolucion na primeira oportunidade
    // em que o provider está disponível (build). Se o draft ainda tem o fallback
    // 'Dr.' e o médico está logado, atualiza sem reconstruir o SOAP do filho.
    // Usa addPostFrameCallback para não chamar setState dentro do build.
    if (_draftEvolucion.autorNombre == 'Dr.' &&
        doctorName.isNotEmpty &&
        doctorName != 'Dr.') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _draftEvolucion.autorNombre == 'Dr.') {
          setState(() {
            _draftEvolucion = _draftEvolucion.copyWith(autorNombre: doctorName);
          });
        }
      });
    }

    // ── Build 176: Dashboard Clínico compacto ─────────────────────────────
    return Scaffold(
      backgroundColor: theme.surface,

      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // TOPBAR — AppBar customizada
      // Esquerda: back + Title Column ("INTERNACIÓN Y EVOLUCIÓN" / "MedCases Pro")
      // Direita (actions): botão compacto [Nueva] (vassourinha)
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: Container(
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF0D0F14) : Colors.white,
            border: Border(bottom: BorderSide(color: theme.border, width: 0.8)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  // Back
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: theme.accent),
                    tooltip: isEs ? 'Volver' : 'Voltar',
                    onPressed: () => Navigator.maybePop(context),
                    padding: const EdgeInsets.all(8),
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                  // Title Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isEs
                              ? 'INTERNACIÓN Y EVOLUCIÓN'
                              : 'INTERNAÇÃO E EVOLUÇÃO',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: theme.textPrimary,
                          ),
                        ),
                        Text(
                          'MedCases Pro',
                          style: TextStyle(
                              fontSize: 10,
                              color: theme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  // Actions: botão [Nueva]
                  GestureDetector(
                    onTap: _confirmAndReset,
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: InternacionTheme.accentLight
                            .withValues(alpha: dark ? 0.18 : 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: InternacionTheme.accentLight
                              .withValues(alpha: 0.40),
                          width: 0.9,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cleaning_services_rounded,
                              size: 13,
                              color: InternacionTheme.accentLight),
                          const SizedBox(width: 5),
                          Text(
                            isEs ? 'Nueva' : 'Nova',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: InternacionTheme.accentLight,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ),
      ),

      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // BODY — SingleChildScrollView → Column linear
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ── ELEMENTO 1 (100%): Card do Paciente Ativo ─────────────────
            ResumenHeader(
              pacienteId: _paciente.nome,
              cama: _paciente.cama,
              diagnostico: _paciente.diagnostico,
              diadeInternacion: _paciente.diaInternacao,
              dark: dark,
              lang: lang,
            ),
            const SizedBox(height: 12),

            // ── ELEMENTO 2 (100%): MedCases Inteligente IA card ───────────
            CopilotButton(dark: dark, lang: lang, onApproved: _onAiApproved),
            const SizedBox(height: 12),

            // ── ELEMENTO 3 (Build 180 — Vertical Stack 100%): Dados del Paciente + Fármacos ─
            // Row 60/40 removida — ambos os cards ocupam 100% da largura no mobile.
            GestureDetector(
              onLongPress: () => _showDocumentPreview(context, dark, lang),
              // Build 183 FIX 3: ValueKey(_currentSessionKey) forces PatientAccordion
              // to fully rebuild (fresh TextEditingControllers) when _editSession()
              // changes the active session. Without this, controllers stay stale
              // from the previous session and Copy sends empty text.
              child: PatientAccordion(
                // Build 192 Fix 2: inclui _accordionGeneration na key para
                // garantir recriação dos TextEditingControllers sempre que
                // _editSession() ou _evolveSession() forem chamados,
                // mesmo que _currentSessionKey permaneça igual.
                key: ValueKey('${_currentSessionKey ?? 'new'}_$_accordionGeneration'),
                data: _paciente,
                dark: dark,
                lang: lang,
                onChanged: (d) => setState(() => _paciente = d),
              ),
            ),
            const SizedBox(height: 8),
            FarmacosAccordion(
              farmacos: _draftEvolucion.farmacos,
              dark: dark,
              lang: lang,
              onChanged: (list) => setState(() {
                _draftEvolucion = _draftEvolucion.copyWith(farmacos: list);
              }),
            ),
            const SizedBox(height: 16),

            // ── SEÇÃO CENTRAL: Divisor textual discreto ───────────────────
            _SectionDivider(
              label: isEs
                  ? 'NUEVA EVOLUCIÓN MÉDICA'
                  : 'NOVA EVOLUÇÃO MÉDICA',
              sublabel: 'SOAP',
              dark: dark,
              theme: theme,
            ),
            const SizedBox(height: 12),

            // ── SOAP 2×2: Motor SOAP completo ─────────────────────────────
            // SoapSectionWidget gerencia internamente S/O/A/P como accordion.
            // O frame 2×2 visual é o próprio widget responsivo do motor SOAP.
            SoapSectionWidget(
              key: _soapKey,
              evolucion: _draftEvolucion,
              dark: dark,
              lang: lang,
              autorNombre: doctorName,
              paciente: _paciente,
              onSave: _onSaveEvolucion,
            ),
            const SizedBox(height: 14),

            // ── BARRA DE AÇÕES (25% Copiar | 50% Guardar | 25% Papelera) ──
            Row(
              children: [
                // 25% — Copiar (abre ModalBottomSheet duplo Completo/Diário)
                Expanded(
                  flex: 25,
                  child: _ActionButton(
                    label: isEs ? 'Copiar' : 'Copiar',
                    icon: Icons.copy_rounded,
                    color: dark
                        ? const Color(0xFF374151)
                        : const Color(0xFFE5E7EB),
                    textColor: theme.textPrimary,
                    dark: dark,
                    onTap: () =>
                        _soapKey.currentState?.showCopyMenu(context),
                  ),
                ),
                const SizedBox(width: 8),
                // 50% — Guardar (botão principal)
                Expanded(
                  flex: 50,
                  child: _ActionButton(
                    label: isEs ? 'Guardar' : 'Salvar',
                    icon: Icons.save_rounded,
                    color: InternacionTheme.accentLight,
                    textColor: Colors.white,
                    dark: dark,
                    isPrimary: true,
                    onTap: () {
                      // Build 208 FIX INVERSÃO DE FONTE DE VERDADE:
                      // O PAI (_draftEvolucion) é a fonte absoluta de metadados:
                      //   id, fecha, autorNombre, farmacos.
                      // O FILHO (currentEvolucion) é a fonte dos blocos SOAP
                      //   (subjetivo, objetivo, evaluacion, plan) — que foram
                      //   sincronizados via addListener+didUpdateWidget (Build 205).
                      // copyWith do PAI sobrescreve apenas SOAP com dados do filho,
                      // preservando autorNombre, id, fecha e farmacos do pai.
                      final childEv = _soapKey.currentState?.currentEvolucion;
                      final ev = _draftEvolucion.copyWith(
                        subjetivo:  childEv?.subjetivo  ?? _draftEvolucion.subjetivo,
                        objetivo:   childEv?.objetivo   ?? _draftEvolucion.objetivo,
                        evaluacion: childEv?.evaluacion ?? _draftEvolucion.evaluacion,
                        plan:       childEv?.plan       ?? _draftEvolucion.plan,
                        // farmacos: mantido do pai (_draftEvolucion) — não sobrescrever
                        // autorNombre, id, fecha: NUNCA sobrescrevidos pelo filho
                      );
                      _onSaveEvolucion(ev);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // 25% — Papelera
                Expanded(
                  flex: 25,
                  child: _ActionButton(
                    label: isEs ? 'Papelera' : 'Lixeira',
                    icon: Icons.restore_from_trash_rounded,
                    color: InternacionTheme.red
                        .withValues(alpha: dark ? 0.18 : 0.10),
                    textColor: InternacionTheme.red,
                    dark: dark,
                    onTap: () => _showTrashModal(context, dark, lang),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── SEÇÃO DE PACIENTES GUARDADOS ───────────────────────────────
            if (_sessionsLoaded && _savedSessions.isNotEmpty) ...[
              // Build 196: deduplication antes de renderizar o grid
              Builder(builder: (context) {
                final deduped = _deduplicatedSessions();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionDivider(
                      label: isEs
                          ? 'PACIENTES INTERNADOS GUARDADOS'
                          : 'PACIENTES INTERNADOS SALVOS',
                      sublabel: isEs
                          ? '${deduped.length} paciente${deduped.length > 1 ? 's' : ''}'
                          : '${deduped.length} paciente${deduped.length > 1 ? 's' : ''}',
                      dark: dark,
                      theme: theme,
                    ),
                    const SizedBox(height: 12),
                    // Grid responsivo: centrado, maxWidth 600, cards maxWidth 280
                    _SessionsGrid(
                      sessions: deduped,
                      dark: dark,
                      lang: lang,
                      theme: theme,
                      onEdit: _editSession,
                      onEvolve: _evolveSession,
                      onDelete: _deleteSession,
                      onPreview: (session) =>
                          _showSessionPreview(context, session, dark, lang),
                    ),
                  ],
                );
              }),
            ],

            // Papelera: agora exclusivamente no botão de 25% da Action Bar acima.
          ],
        ),
      ),
    );
  }

  // ── 168-4: Session Preview Dialog ────────────────────────────────────────
  void _showSessionPreview(
    BuildContext ctx,
    PacienteSession session,
    bool dark,
    String lang,
  ) {
    showDialog(
      context: ctx,
      builder: (_) => _SessionPreviewDialog(
        session: session,
        dark: dark,
        lang: lang,
        onEvolve: () {
          Navigator.of(ctx).pop();
          _evolveSession(session);
        },
        onEdit: () {
          Navigator.of(ctx).pop();
          _editSession(session);
        },
        onDelete: () {
          Navigator.of(ctx).pop();
          _deleteSession(session);
        },
        onCopy: (text) {
          Clipboard.setData(ClipboardData(text: text));
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.copy_rounded, color: Colors.white, size: 15),
              const SizedBox(width: 8),
              Text(lang == 'es'
                  ? 'Ficha copiada al portapapeles'
                  : 'Ficha copiada para a área de transferência'),
            ]),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        },
        onAuditoria: (ev) => _showAuditoriaModal(ctx, ev, dark, lang),
      ),
    );
  }

  // ── Build 173: Abre a Papelera de Reciclaje ───────────────────────────────
  void _showTrashModal(BuildContext ctx, bool dark, String lang) {
    final uid = _uid;
    if (uid == null || uid.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(lang == 'es'
            ? 'Inicia sesión para acceder a la papelera.'
            : 'Faça login para acessar a lixeira.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TrashModal(
        uid: uid,
        dark: dark,
        lang: lang,
        onRestored: () {
          // Atualiza o grid principal após restauração
          _loadSessionsLocal();
        },
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Build 176: Grid responsivo — MaxCrossAxisExtent + ConstrainedBox(maxWidth:600)
// Previne cards gigantes em Web/Tablet; centraliza em telas largas.
// ═════════════════════════════════════════════════════════════════════════════
class _SessionsGrid extends StatelessWidget {
  final List<PacienteSession> sessions;
  final bool dark;
  final String lang;
  final InternacionTheme theme;
  final ValueChanged<PacienteSession> onEdit;
  final ValueChanged<PacienteSession> onEvolve;
  final Future<void> Function(PacienteSession) onDelete;
  final ValueChanged<PacienteSession> onPreview;

  const _SessionsGrid({
    required this.sessions,
    required this.dark,
    required this.lang,
    required this.theme,
    required this.onEdit,
    required this.onEvolve,
    required this.onDelete,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 280,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.05,
          ),
          itemCount: sessions.length,
          itemBuilder: (_, i) {
            final s = sessions[i];
            return _SessionCard168(
              session: s,
              dark: dark,
              lang: lang,
              theme: theme,
              onEdit: () => onEdit(s),
              onEvolve: () => onEvolve(s),
              onDelete: () => onDelete(s),
              onTapBody: () => onPreview(s),
            );
          },
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Build 176: Botão de ação da barra 25/50/25
// ═════════════════════════════════════════════════════════════════════════════
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;
  final bool dark;
  final bool isPrimary;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.textColor,
    required this.dark,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: isPrimary
              ? null
              : Border.all(
                  color: textColor.withValues(alpha: 0.25),
                  width: 0.8,
                ),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: textColor),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: textColor,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Build 183 FIX 2: Triage color mapping based on diagnosis keywords
// RED = critical/emergency, YELLOW = urgent/intermediate, GREEN = stable
// ─────────────────────────────────────────────────────────────────────────────
Color _triageColorFromDiagnosis(String diag) {
  final d = diag.toLowerCase();
  // RED — critical / emergency
  const redTerms = [
    'shock', 'choque', 'sca', 'síndrome coronario agudo', 'síndrome coronariano agudo',
    'infarto', 'iamcsst', 'iamssst', 'parada', 'pcrce', 'sepsis severa',
    'falla orgánica', 'falla organica', 'falha orgânica', 'falha organica',
    'iam', 'tep instável', 'tep instavel', 'edema agudo', 'insuficiencia respiratoria aguda',
    'insuficiência respiratória aguda', 'status epileptico', 'status epilético',
    'coma', 'stroke', 'avc isquemico', 'avc hemorragico', 'hemorragia',
    'hemorragia cerebral', 'iam com supra', 'emergencia hipertensiva',
    'emergencia hipertensíva', 'anafilaxia', 'anafilaxis',
    'tamponamento', 'pericardico', 'pericardi', 'eap', 'insuficiencia cardíaca aguda',
  ];
  // YELLOW — urgent / intermediate
  const yellowTerms = [
    'sepsis', 'sepse', 'pneumonia', 'neumonía', 'neumonia', 'pielonefritis',
    'pielonefrite', 'celulitis', 'celulite', 'ictericia', 'ictericia obstructiva',
    'icterícia', 'colangitis', 'colangite', 'sdra', 'ards', 'irc descompensada',
    'dra', 'irc', 'insuficiencia renal', 'insuficiência renal',
    'epoc', 'epoc agudizado', 'dpoc', 'dpoc agudizado', 'crisis asmatica',
    'crise asmática', 'hta', 'hipertension urgencia', 'hipertensão urgencia',
    'disritmia', 'fibrilação atrial', 'fibrilacion auricular', 'icpp', 'icc',
    'diabetes descompensada', 'cetoacidose', 'cetoacidosis',
    'meningitis', 'meningite', 'encefalitis', 'encefalite',
    'trombosis', 'tvp', 'tep', 'embolismo pulmonar', 'embolia pulmonar',
  ];
  for (final term in redTerms) {
    if (d.contains(term)) return const Color(0xFFEF4444);
  }
  for (final term in yellowTerms) {
    if (d.contains(term)) return const Color(0xFFF59E0B);
  }
  return InternacionTheme.accentLight; // green = stable
}

// ── 168-3: Card redesenhado com severity border ───────────────────────────────
class _SessionCard168 extends StatelessWidget {
  final PacienteSession session;
  final bool dark;
  final String lang;
  final InternacionTheme theme;
  final VoidCallback onEdit;
  final VoidCallback onEvolve;
  final VoidCallback onDelete;
  final VoidCallback onTapBody;

  const _SessionCard168({
    required this.session,
    required this.dark,
    required this.lang,
    required this.theme,
    required this.onEdit,
    required this.onEvolve,
    required this.onDelete,
    required this.onTapBody,
  });

  bool get isEs => lang == 'es';

  // Cor de severidade: estado clínico da última evolução OU triage por diagnóstico
  // Build 183 FIX 2: fallback to keyword-based triage when estado is null
  Color _severityColor() {
    // Priority 1: explicit clinical state from SOAP evolution
    if (session.historial.isNotEmpty) {
      final last = session.historial.last;
      final estado = last.evaluacion.estado;
      if (estado != null) return Color(estado.colorValue);
    }
    // Priority 2: keyword-based triage from diagnosis string
    final diag = session.paciente.diagnostico;
    if (diag.isNotEmpty) return _triageColorFromDiagnosis(diag);
    // Fallback: green (stable)
    return InternacionTheme.accentLight;
  }

  @override
  Widget build(BuildContext context) {
    final p = session.paciente;
    final nome =
        p.nome.isNotEmpty ? p.nome : (isEs ? 'Paciente' : 'Paciente');
    final cama = p.cama.isNotEmpty
        ? (isEs ? 'Cama ${p.cama}' : 'Leito ${p.cama}')
        : '';
    final evol = session.historial.length;
    final severityColor = _severityColor();

    return Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF0E1420) : const Color(0xFFF8FFFE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: severityColor, width: 2.0),
        boxShadow: [
          BoxShadow(
            color: severityColor.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Topbar: [Editar] [Excluir] ──────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: severityColor.withValues(alpha: dark ? 0.12 : 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Row(
              children: [
                Icon(Icons.circle, size: 8, color: severityColor),
                const Spacer(),
                // Editar
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: severityColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isEs ? 'Editar' : 'Editar',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: severityColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Excluir
                GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: InternacionTheme.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isEs ? 'Excluir' : 'Excluir',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: InternacionTheme.red,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Corpo (clicável → preview) ────────────────────────────────
          Expanded(
            child: GestureDetector(
              onTap: onTapBody,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nome
                    Text(
                      nome,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: theme.textPrimary,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (cama.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(cama,
                          style: TextStyle(
                              fontSize: 10.5, color: theme.textSecondary)),
                    ],
                    if (p.diagnostico.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        p.diagnostico,
                        style: TextStyle(
                            fontSize: 10,
                            color: theme.labelColor,
                            height: 1.3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const Spacer(),
                    // Día · Evoluciones
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 9, color: severityColor),
                        const SizedBox(width: 3),
                        Text(
                          isEs
                              ? 'Día ${p.diaInternacao} · $evol evol.'
                              : 'Dia ${p.diaInternacao} · $evol evol.',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: severityColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Bottom: [Evoluir] ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: GestureDetector(
              onTap: onEvolve,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: severityColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isEs ? 'Evolucionar' : 'Evoluir',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 168-4: Session Preview Dialog — Build 192 Fix 1 + Fix 3
// Convertido para StatefulWidget com seletor de histórico reativo.
// Prévia SOAP completa com TODOS os campos (S/O/A/P) exibidos e copiáveis.
// ═════════════════════════════════════════════════════════════════════════════
class _SessionPreviewDialog extends StatefulWidget {
  final PacienteSession session;
  final bool dark;
  final String lang;
  final VoidCallback onEvolve;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<String> onCopy;
  final ValueChanged<EvolucionModel>? onAuditoria;

  const _SessionPreviewDialog({
    required this.session,
    required this.dark,
    required this.lang,
    required this.onEvolve,
    required this.onEdit,
    required this.onDelete,
    required this.onCopy,
    this.onAuditoria,
  });

  @override
  State<_SessionPreviewDialog> createState() => _SessionPreviewDialogState();
}

class _SessionPreviewDialogState extends State<_SessionPreviewDialog> {
  late int _selectedEvolIndex;

  @override
  void initState() {
    super.initState();
    // Build 192 Fix 3: inicia na evolução mais recente
    _selectedEvolIndex = widget.session.historial.isNotEmpty
        ? widget.session.historial.length - 1
        : -1;
  }

  bool get isEs => widget.lang == 'es';
  bool get dark => widget.dark;
  PacienteSession get session => widget.session;

  // Build 192 Fix 1: _buildPreviewText inclui TODOS os campos SOAP
  // (não apenas notasEvaluacion e planTerapeutico como antes).
  // Cobre: subjetivo, signos vitales, examen físico, exámenes, avaliação, plan.
  String _buildPreviewText() {
    final p = session.paciente;
    final buf = StringBuffer();
    final header = isEs ? 'FICHA DE INTERNACIÓN — MedCases Pro' : 'FICHA DE INTERNAÇÃO — MedCases Pro';
    buf.writeln(header);
    buf.writeln('');
    if (p.nome.isNotEmpty) buf.writeln('${isEs ? 'Paciente' : 'Paciente'}: ${p.nome}');
    if (p.cama.isNotEmpty) buf.writeln('${isEs ? 'Cama' : 'Leito'}: ${p.cama}');
    if (p.idade.isNotEmpty) buf.writeln('${isEs ? 'Edad' : 'Idade'}: ${p.idade}');
    if (p.sexo.isNotEmpty) buf.writeln('${isEs ? 'Sexo' : 'Sexo'}: ${p.sexo}');
    if (p.diagnostico.isNotEmpty) buf.writeln('${isEs ? 'Diagnóstico' : 'Diagnóstico'}: ${p.diagnostico}');
    buf.writeln('${isEs ? 'Día de internación' : 'Dia de internação'}: ${p.diaInternacao}');
    buf.writeln('${isEs ? 'Evoluciones' : 'Evoluções'}: ${session.historial.length}');
    buf.writeln('');
    for (final ev in session.historial) {
      buf.writeln('━━ ${ev.fechaFormatada} ━━');
      final s = ev.subjetivo;
      final o = ev.objetivo;
      final sv = o.signosVitales;
      final ef = o.examenFisico;
      final ex = o.examenes;
      final a = ev.evaluacion;
      final plan = ev.plan;

      // S — Subjetivo
      if (s.notePasaNoche.isNotEmpty)
        buf.writeln('${isEs ? 'Evolución' : 'Evolução'}: ${s.notePasaNoche}');
      final syms = <String>[];
      if (s.fiebre) syms.add(isEs ? 'Fiebre' : 'Febre');
      if (s.disnea) syms.add(isEs ? 'Disnea' : 'Dispneia');
      if (s.nauseas) syms.add(isEs ? 'Náuseas' : 'Náuseas');
      if (s.tos) syms.add(isEs ? 'Tos' : 'Tosse');
      if (syms.isNotEmpty)
        buf.writeln('${isEs ? 'Síntomas' : 'Sintomas'}: ${syms.join(', ')}');
      if (s.dolorEscala != null && s.dolorEscala! > 0)
        buf.writeln('EVA: ${s.dolorEscala}/10');
      if (s.alimentacion.isNotEmpty)
        buf.writeln('${isEs ? 'Alimentación' : 'Alimentação'}: ${s.alimentacion}');
      if (s.diuresis.isNotEmpty) buf.writeln('${isEs ? 'Diuresis' : 'Diurese'}: ${s.diuresis}');
      if (s.notasLibres.isNotEmpty) buf.writeln(s.notasLibres);

      // O — Signos Vitales
      if (!sv.isEmpty) {
        final parts = <String>[];
        if (sv.pa.isNotEmpty) parts.add('PA: ${sv.pa}');
        if (sv.fc.isNotEmpty) parts.add('FC: ${sv.fc}');
        if (sv.fr.isNotEmpty) parts.add('FR: ${sv.fr}');
        if (sv.satO2.isNotEmpty) parts.add('SatO₂: ${sv.satO2}%');
        if (sv.temperatura.isNotEmpty) parts.add('T: ${sv.temperatura}°C');
        buf.writeln('SV: ${parts.join('  ')}');
      }
      // O — Examen Físico
      if (ef.estadoGeneral.isNotEmpty) buf.writeln('EG: ${ef.estadoGeneral}');
      if (ef.acv.isNotEmpty) buf.writeln('CV: ${ef.acv}');
      if (ef.ar.isNotEmpty) buf.writeln('Resp: ${ef.ar}');
      if (ef.abdomen.isNotEmpty) buf.writeln('Abd: ${ef.abdomen}');
      if (ef.extremidades.isNotEmpty) buf.writeln('MMII: ${ef.extremidades}');
      // O — Exámenes Complementarios
      if (ex.laboratorio.isNotEmpty)
        buf.writeln('${isEs ? 'Lab' : 'Lab'}: ${ex.laboratorio}');
      if (ex.imagenes.isNotEmpty)
        buf.writeln('${isEs ? 'Imágenes' : 'Imagens'}: ${ex.imagenes}');
      if (ex.culturas.isNotEmpty) buf.writeln('Culturas: ${ex.culturas}');
      if (ex.ecg.isNotEmpty) buf.writeln('ECG: ${ex.ecg}');
      if (o.tratamientoActual.isNotEmpty)
        buf.writeln('${isEs ? 'Tto. actual' : 'Tto. atual'}: ${o.tratamientoActual}');
      // A — Evaluación
      if (a.problemasActivos.isNotEmpty)
        buf.writeln('${isEs ? 'Problemas activos' : 'Problemas ativos'}: ${a.problemasActivos.join(', ')}');
      if (a.notasEvaluacion.isNotEmpty)
        buf.writeln('${isEs ? 'Impresión' : 'Impressão'}: ${a.notasEvaluacion}');
      if (a.estado != null) buf.writeln(a.estado!.label(isEs ? 'es' : 'pt'));
      // P — Plan
      if (plan.planTerapeutico.isNotEmpty)
        buf.writeln('${isEs ? 'Conducta' : 'Conduta'}: ${plan.planTerapeutico}');
      if (plan.criteriosAlta.isNotEmpty)
        buf.writeln('${isEs ? 'Criterios de alta' : 'Critérios de alta'}: ${plan.criteriosAlta}');
      // Fármacos
      if (ev.farmacos.isNotEmpty) {
        buf.writeln(isEs ? 'Medicamentos:' : 'Medicamentos:');
        for (final f in ev.farmacos) {
          buf.writeln('  • ${f.medicamento}${f.dosagem.isNotEmpty ? ' — ${f.dosagem}' : ''}');
        }
      }
      buf.writeln('');
    }
    return buf.toString().trimRight();
  }

  // Build 198: abre ModalBottomSheet tri-formato para a evolução selecionada.
  // Usa as funções públicas de soap_section.dart (soapCompletoString, etc.)
  // que já têm fallbacks "• (Sem dados)" para cada bloco vazio — nunca
  // produzem texto esqueleto.
  void _showCopySheet(BuildContext context, EvolucionModel ev) {
    final p       = session.paciente;
    final isEsVal = isEs;
    final darkVal = dark;
    final autor   = ev.autorNombre.isNotEmpty ? ev.autorNombre : 'Dr.';

    void doCopy(String text) {
      Navigator.of(context).pop(); // fecha o sheet
      Clipboard.setData(ClipboardData(text: text));
      widget.onCopy(text); // notifica o host (SnackBar)
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CopyFormatSheet(
        dark: darkVal,
        lang: isEsVal ? 'es' : 'pt',
        onCopyFull:     () => doCopy(soapCompletoString(ev, isEsVal, autor, p)),
        onCopyResumida: () => doCopy(soapResumidoString(ev, isEsVal, autor, p)),
        onCopyPasaje:   () => doCopy(soapPassagemString(ev, isEsVal, p)),
      ),
    );
  }

  // Build 192 Fix 3: label para o DropdownButton de histórico
  String _evolLabel(int index) {
    final ev = session.historial[index];
    final d = ev.fecha;
    final dateStr =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return isEs ? 'Día $dateStr' : 'Dia $dateStr';
  }

  @override
  Widget build(BuildContext context) {
    final theme = InternacionTheme(dark);
    final p = session.paciente;
    final bg = dark ? const Color(0xFF0F1116) : Colors.white;
    final hasHistorial = session.historial.isNotEmpty;
    final selectedEv =
        hasHistorial && _selectedEvolIndex >= 0 && _selectedEvolIndex < session.historial.length
            ? session.historial[_selectedEvolIndex]
            : null;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 28),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 560, maxWidth: 520),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: InternacionTheme.accentLight.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              decoration: BoxDecoration(
                color: InternacionTheme.accentLight
                    .withValues(alpha: dark ? 0.12 : 0.07),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(19)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: InternacionTheme.accentLight
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_rounded,
                        size: 18, color: InternacionTheme.accentLight),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.nome.isNotEmpty
                              ? p.nome
                              : (isEs ? 'Paciente' : 'Paciente'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: theme.textPrimary,
                          ),
                        ),
                        Text(
                          [
                            if (p.cama.isNotEmpty)
                              isEs ? 'Cama ${p.cama}' : 'Leito ${p.cama}',
                            if (p.idade.isNotEmpty) p.idade,
                            if (p.sexo.isNotEmpty) p.sexo,
                            isEs
                                ? 'Día ${p.diaInternacao}'
                                : 'Dia ${p.diaInternacao}',
                            '${session.historial.length} evol.',
                          ].join('  ·  '),
                          style: TextStyle(
                              fontSize: 11.5,
                              color: InternacionTheme.accentLight),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        size: 20, color: theme.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),

            // ── Build 192 Fix 3: Seletor de histórico (DropdownButton) ────
            if (hasHistorial && session.historial.length > 1)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                decoration: BoxDecoration(
                  color: theme.card,
                  border: Border(
                      bottom: BorderSide(color: theme.border, width: 0.8)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.history_rounded,
                        size: 13, color: InternacionTheme.accentLight),
                    const SizedBox(width: 6),
                    Text(
                      isEs ? 'Evolución:' : 'Evolução:',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: theme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<int>(
                        value: _selectedEvolIndex,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        dropdownColor: bg,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.textPrimary,
                        ),
                        icon: Icon(Icons.expand_more_rounded,
                            size: 16,
                            color: InternacionTheme.accentLight),
                        items: List.generate(session.historial.length, (i) {
                          final label = _evolLabel(i);
                          final isLatest = i == session.historial.length - 1;
                          return DropdownMenuItem<int>(
                            value: i,
                            child: Text(
                              isLatest
                                  ? '$label  ${isEs ? '(más reciente)' : '(mais recente)'}'
                                  : label,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.textPrimary,
                                fontWeight: isLatest
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          );
                        }),
                        onChanged: (idx) {
                          if (idx != null) {
                            setState(() => _selectedEvolIndex = idx);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),

            // ── Corpo scrollável — SOAP completo da evolução selecionada ──
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (p.diagnostico.isNotEmpty)
                      _previewRow(
                          theme,
                          Icons.local_hospital_rounded,
                          isEs ? 'Diagnóstico' : 'Diagnóstico',
                          p.diagnostico),
                    if (selectedEv != null) ...[
                      const SizedBox(height: 10),
                      // ── Data da evolução selecionada
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 12,
                              color: InternacionTheme.accentLight),
                          const SizedBox(width: 4),
                          Text(
                            selectedEv.fechaFormatada,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: InternacionTheme.accentLight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // S — Subjetivo
                      _soapSectionHeader(isEs ? 'S — SUBJETIVO' : 'S — SUBJETIVO', theme),
                      if (selectedEv.subjetivo.notePasaNoche.isNotEmpty)
                        _soapField(isEs ? 'Evolución' : 'Evolução',
                            selectedEv.subjetivo.notePasaNoche, theme),
                      if (selectedEv.subjetivo.notasLibres.isNotEmpty)
                        _soapField(isEs ? 'Notas' : 'Notas',
                            selectedEv.subjetivo.notasLibres, theme),
                      if (selectedEv.subjetivo.dolorEscala != null &&
                          selectedEv.subjetivo.dolorEscala! > 0)
                        _soapField('EVA',
                            '${selectedEv.subjetivo.dolorEscala}/10', theme),
                      () {
                        final s = selectedEv.subjetivo;
                        final syms = <String>[];
                        if (s.fiebre) syms.add(isEs ? 'Fiebre' : 'Febre');
                        if (s.disnea) syms.add(isEs ? 'Disnea' : 'Dispneia');
                        if (s.nauseas) syms.add(isEs ? 'Náuseas' : 'Náuseas');
                        if (s.tos) syms.add(isEs ? 'Tos' : 'Tosse');
                        if (syms.isEmpty) return const SizedBox.shrink();
                        return _soapField(
                            isEs ? 'Síntomas' : 'Sintomas', syms.join(', '), theme);
                      }(),
                      // O — Objetivo
                      const SizedBox(height: 6),
                      _soapSectionHeader(isEs ? 'O — OBJETIVO' : 'O — OBJETIVO', theme),
                      if (!selectedEv.objetivo.signosVitales.isEmpty) ...[
                        () {
                          final sv = selectedEv.objetivo.signosVitales;
                          final parts = <String>[];
                          if (sv.pa.isNotEmpty) parts.add('PA: ${sv.pa}');
                          if (sv.fc.isNotEmpty) parts.add('FC: ${sv.fc}');
                          if (sv.fr.isNotEmpty) parts.add('FR: ${sv.fr}');
                          if (sv.satO2.isNotEmpty)
                            parts.add('SatO₂: ${sv.satO2}%');
                          if (sv.temperatura.isNotEmpty)
                            parts.add('T: ${sv.temperatura}°C');
                          return _soapField('SV', parts.join('  '), theme);
                        }(),
                      ],
                      if (selectedEv.objetivo.examenFisico.estadoGeneral.isNotEmpty)
                        _soapField('EG',
                            selectedEv.objetivo.examenFisico.estadoGeneral, theme),
                      if (selectedEv.objetivo.examenFisico.acv.isNotEmpty)
                        _soapField('CV', selectedEv.objetivo.examenFisico.acv, theme),
                      if (selectedEv.objetivo.examenFisico.ar.isNotEmpty)
                        _soapField('Resp', selectedEv.objetivo.examenFisico.ar, theme),
                      if (selectedEv.objetivo.examenFisico.abdomen.isNotEmpty)
                        _soapField('Abd',
                            selectedEv.objetivo.examenFisico.abdomen, theme),
                      if (selectedEv.objetivo.examenFisico.extremidades.isNotEmpty)
                        _soapField('MMII',
                            selectedEv.objetivo.examenFisico.extremidades, theme),
                      if (selectedEv.objetivo.examenes.laboratorio.isNotEmpty)
                        _soapField(isEs ? 'Lab' : 'Lab',
                            selectedEv.objetivo.examenes.laboratorio, theme),
                      if (selectedEv.objetivo.examenes.imagenes.isNotEmpty)
                        _soapField(isEs ? 'Imágenes' : 'Imagens',
                            selectedEv.objetivo.examenes.imagenes, theme),
                      if (selectedEv.objetivo.examenes.culturas.isNotEmpty)
                        _soapField('Culturas',
                            selectedEv.objetivo.examenes.culturas, theme),
                      if (selectedEv.objetivo.examenes.ecg.isNotEmpty)
                        _soapField('ECG',
                            selectedEv.objetivo.examenes.ecg, theme),
                      if (selectedEv.objetivo.tratamientoActual.isNotEmpty)
                        _soapField(isEs ? 'Tto. actual' : 'Tto. atual',
                            selectedEv.objetivo.tratamientoActual, theme),
                      // A — Avaliação
                      const SizedBox(height: 6),
                      _soapSectionHeader(isEs ? 'A — EVALUACIÓN' : 'A — AVALIAÇÃO', theme),
                      if (selectedEv.evaluacion.problemasActivos.isNotEmpty)
                        _soapField(
                            isEs ? 'Problemas' : 'Problemas',
                            selectedEv.evaluacion.problemasActivos.join(', '),
                            theme),
                      if (selectedEv.evaluacion.notasEvaluacion.isNotEmpty)
                        _soapField(isEs ? 'Impresión' : 'Impressão',
                            selectedEv.evaluacion.notasEvaluacion, theme),
                      if (selectedEv.evaluacion.estado != null)
                        _soapField(isEs ? 'Estado' : 'Estado',
                            selectedEv.evaluacion.estado!.label(isEs ? 'es' : 'pt'), theme),
                      // P — Plan
                      const SizedBox(height: 6),
                      _soapSectionHeader(isEs ? 'P — PLAN' : 'P — PLANO', theme),
                      if (selectedEv.plan.planTerapeutico.isNotEmpty)
                        _soapField(isEs ? 'Conducta' : 'Conduta',
                            selectedEv.plan.planTerapeutico, theme),
                      if (selectedEv.plan.criteriosAlta.isNotEmpty)
                        _soapField(
                            isEs ? 'Criterios de alta' : 'Critérios de alta',
                            selectedEv.plan.criteriosAlta,
                            theme),
                      // Fármacos
                      if (selectedEv.farmacos.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _soapSectionHeader(
                            isEs ? 'MEDICAMENTOS' : 'MEDICAMENTOS', theme),
                        ...selectedEv.farmacos.map((f) => _soapField(
                            '•',
                            '${f.medicamento}${f.dosagem.isNotEmpty ? ' — ${f.dosagem}' : ''}',
                            theme)),
                      ],
                      // metadadosAdicionais (Build 192 Fix 4)
                      if (selectedEv.metadadosAdicionais.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _soapSectionHeader(
                            isEs ? 'DADOS ADICIONAIS' : 'DADOS ADICIONAIS', theme),
                        ...selectedEv.metadadosAdicionais.entries.map((e) =>
                            _soapField(e.key, e.value.toString(), theme)),
                      ],
                    ] else if (!hasHistorial)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          isEs
                              ? 'Sin evoluciones registradas.'
                              : 'Sem evoluções registradas.',
                          style: TextStyle(
                              fontSize: 13, color: theme.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // ── Ações: [Copiar] [Excluir] | [Editar] [Evolucionar] ───────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                children: [
                  // Linha 1: [Copiar] [Excluir]
                  Row(
                    children: [
                      // Build 198: copia via tri-formato ModalBottomSheet
                      _actionBtn(
                        icon: Icons.copy_all_rounded,
                        label: isEs ? 'Copiar' : 'Copiar',
                        color: InternacionTheme.cyan,
                        dark: dark,
                        theme: theme,
                        onTap: selectedEv != null
                            ? () => _showCopySheet(context, selectedEv)
                            : () => widget.onCopy(_buildPreviewText()),
                      ),
                      const SizedBox(width: 6),
                      // Excluir
                      _actionBtn(
                        icon: Icons.delete_outline_rounded,
                        label: isEs ? 'Excluir' : 'Excluir',
                        color: InternacionTheme.red,
                        dark: dark,
                        theme: theme,
                        onTap: widget.onDelete,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Linha 2: [Editar última] [Evolucionar →]
                  Row(
                    children: [
                      // Editar última evolução
                      Expanded(
                        child: GestureDetector(
                          onTap: widget.onEdit,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: InternacionTheme.amber
                                  .withValues(alpha: dark ? 0.18 : 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: InternacionTheme.amber
                                    .withValues(alpha: 0.45),
                                width: 0.9,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.edit_note_rounded,
                                    size: 14,
                                    color: InternacionTheme.amber),
                                const SizedBox(width: 5),
                                Text(
                                  isEs ? 'Editar' : 'Editar',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: InternacionTheme.amber,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Evolucionar (primário)
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: widget.onEvolve,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF059669),
                                  Color(0xFF047857),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_circle_outline_rounded,
                                    size: 14, color: Colors.white),
                                const SizedBox(width: 5),
                                Text(
                                  isEs ? 'Evolucionar' : 'Evoluir',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build 192 Fix 1: helper para campos SOAP na prévia
  Widget _soapSectionHeader(String label, InternacionTheme theme) => Container(
    margin: const EdgeInsets.only(bottom: 4),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: InternacionTheme.accentLight.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 9.5,
        fontWeight: FontWeight.w800,
        color: InternacionTheme.accentLight,
        letterSpacing: 0.5,
      ),
    ),
  );

  Widget _soapField(String label, String value, InternacionTheme theme) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: theme.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              color: theme.textPrimary,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _previewRow(
      InternacionTheme theme, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: theme.labelColor),
          const SizedBox(width: 6),
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: theme.textSecondary,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(fontSize: 12, color: theme.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required bool dark,
    required InternacionTheme theme,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: dark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.30), width: 0.9),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Build 198: _CopyFormatSheet — tri-formato de cópia para _SessionPreviewDialog
// ─────────────────────────────────────────────────────────────────────────────
class _CopyFormatSheet extends StatelessWidget {
  final bool dark;
  final String lang;
  final VoidCallback onCopyFull;
  final VoidCallback onCopyResumida;
  final VoidCallback onCopyPasaje;

  const _CopyFormatSheet({
    required this.dark,
    required this.lang,
    required this.onCopyFull,
    required this.onCopyResumida,
    required this.onCopyPasaje,
  });

  bool get isEs => lang == 'es';

  @override
  Widget build(BuildContext context) {
    final bg           = dark ? const Color(0xFF0F1116) : Colors.white;
    final textPrimary  = dark ? Colors.white : const Color(0xFF0D1117);
    final textSecondary= dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final cardBg       = dark ? const Color(0xFF1A1F2E) : const Color(0xFFF8F9FA);
    final borderColor  = dark ? const Color(0xFF2D3748) : const Color(0xFFE5E7EB);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.25)),
      ),
      padding: EdgeInsets.fromLTRB(
        20, 12, 20,
        20 + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ──────────────────────────────────────────────────────────
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // ── Título ──────────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF059669), Color(0xFF047857)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.copy_all_rounded, size: 17, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEs ? 'Exportar Evolución' : 'Exportar Evolução',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      isEs
                          ? 'Selecciona el formato de exportación'
                          : 'Selecione o formato de exportação',
                      style: TextStyle(fontSize: 11.5, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Opção 1: Completa ────────────────────────────────────────────────
          _CopyFormatTile(
            dark: dark,
            icon: Icons.description_rounded,
            iconColor: const Color(0xFF3B82F6),
            cardBg: cardBg,
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            title: isEs ? 'Evolucion Completa' : 'Evolução Completa',
            subtitle: isEs
                ? 'Encabezado hospitalar + S/O/A/P jerárquico + firma'
                : 'Cabeçalho hospitalar + S/O/A/P hierárquico + assinatura',
            badgeLabel: 'SOAP',
            badgeColor: const Color(0xFF3B82F6),
            onTap: onCopyFull,
          ),
          const SizedBox(height: 8),

          // ── Opção 2: Resumida ────────────────────────────────────────────────
          _CopyFormatTile(
            dark: dark,
            icon: Icons.compress_rounded,
            iconColor: const Color(0xFF059669),
            cardBg: cardBg,
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            title: isEs ? 'Evolucion Resumida' : 'Evolução Resumida',
            subtitle: isEs
                ? 'Formato horizontal denso — ideal para sistemas legados'
                : 'Formato horizontal denso — ideal para sistemas legados',
            badgeLabel: 'INLINE',
            badgeColor: const Color(0xFF059669),
            onTap: onCopyResumida,
          ),
          const SizedBox(height: 8),

          // ── Opção 3: Passagem de Plantão ─────────────────────────────────────
          _CopyFormatTile(
            dark: dark,
            icon: Icons.transfer_within_a_station_rounded,
            iconColor: const Color(0xFFF59E0B),
            cardBg: cardBg,
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            title: isEs ? 'Pasaje de Guardia' : 'Passagem de Plantão',
            subtitle: isEs
                ? 'Ultra-objetivo para transición de turno en menos de 30s'
                : 'Ultra-objetivo para passagem de plantão em menos de 30s',
            badgeLabel: '30s',
            badgeColor: const Color(0xFFF59E0B),
            onTap: onCopyPasaje,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Build 198: _CopyFormatTile — item de lista reutilizável para _CopyFormatSheet
// ─────────────────────────────────────────────────────────────────────────────
class _CopyFormatTile extends StatelessWidget {
  final bool dark;
  final IconData icon;
  final Color iconColor;
  final Color cardBg;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;
  final String title;
  final String subtitle;
  final String badgeLabel;
  final Color badgeColor;
  final VoidCallback onTap;

  const _CopyFormatTile({
    required this.dark,
    required this.icon,
    required this.iconColor,
    required this.cardBg,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    required this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 0.9),
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: dark ? 0.15 : 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeLabel,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: badgeColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, size: 18, color: textSecondary),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 168-5: Document Preview Modal — paper-style viewer
// ═════════════════════════════════════════════════════════════════════════════
class _DocumentPreviewModal extends StatelessWidget {
  final PacienteInternacaoData paciente;
  final List<EvolucionModel> historial;
  final EvolucionModel draftEvolucion;
  final bool dark;
  final String lang;

  const _DocumentPreviewModal({
    required this.paciente,
    required this.historial,
    required this.draftEvolucion,
    required this.dark,
    required this.lang,
  });

  bool get isEs => lang == 'es';

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF0F1116) : Colors.white;
    final paperBg = dark ? const Color(0xFF161B24) : const Color(0xFFFAFAFA);
    final theme = InternacionTheme(dark);

    // Todas as evoluções + draft atual se tiver dados
    final allEvols = [
      ...historial,
      if (_draftHasData()) draftEvolucion,
    ];

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: InternacionTheme.cyan.withValues(alpha: 0.20),
            width: 1.0,
          ),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: InternacionTheme.cyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.description_rounded,
                        size: 17, color: InternacionTheme.cyan),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEs
                              ? 'Vista Previa del Documento'
                              : 'Prévia do Documento',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: theme.textPrimary,
                          ),
                        ),
                        Text(
                          isEs
                              ? 'Formato hospitalar argentino'
                              : 'Formato hospitalar argentino',
                          style: TextStyle(
                              fontSize: 11, color: theme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        size: 20, color: theme.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Divider(color: theme.border, height: 1, thickness: 0.8),

            // ── Folha de papel ─────────────────────────────────────────────
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: paperBg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: dark
                              ? const Color(0xFF2D3340)
                              : const Color(0xFFE0E0E0),
                          width: 0.8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                              alpha: dark ? 0.30 : 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Cabeçalho do documento ─────────────────────────
                        Center(
                          child: Text(
                            'HISTORIA CLÍNICA DE INTERNACIÓN',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: theme.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Center(
                          child: Text(
                            'MedCases Pro · ${_today()}',
                            style: TextStyle(
                                fontSize: 10, color: theme.textSecondary),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _docDivider(theme),
                        const SizedBox(height: 12),

                        // ── Dados do paciente ──────────────────────────────
                        _docSection(
                            isEs ? 'DATOS DEL PACIENTE' : 'DADOS DO PACIENTE',
                            theme),
                        _docField(
                            isEs ? 'Paciente' : 'Paciente',
                            paciente.nome.isNotEmpty
                                ? paciente.nome
                                : '—',
                            theme),
                        if (paciente.cama.isNotEmpty)
                          _docField('Cama', paciente.cama, theme),
                        if (paciente.idade.isNotEmpty)
                          _docField(isEs ? 'Edad' : 'Idade', paciente.idade,
                              theme),
                        if (paciente.diagnostico.isNotEmpty)
                          _docField(
                              isEs ? 'Diagnóstico' : 'Diagnóstico',
                              paciente.diagnostico,
                              theme),
                        _docField(
                            isEs ? 'Día internación' : 'Dia internação',
                            '${paciente.diaInternacao}',
                            theme),
                        const SizedBox(height: 16),

                        // ── Evoluciones ────────────────────────────────────
                        if (allEvols.isNotEmpty) ...[
                          _docSection(
                              isEs
                                  ? 'EVOLUCIONES MÉDICAS'
                                  : 'EVOLUÇÕES MÉDICAS',
                              theme),
                          ...allEvols.asMap().entries.map((e) =>
                              _buildEvolBlock(e.value, e.key + 1, theme)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _draftHasData() {
    final s = draftEvolucion.subjetivo;
    final o = draftEvolucion.objetivo;
    return s.notePasaNoche.isNotEmpty ||
        s.dolorEscala != null ||
        !o.signosVitales.isEmpty ||
        o.examenFisico.estadoGeneral.isNotEmpty ||
        draftEvolucion.evaluacion.notasEvaluacion.isNotEmpty ||
        draftEvolucion.plan.planTerapeutico.isNotEmpty;
  }

  Widget _buildEvolBlock(
      EvolucionModel ev, int num, InternacionTheme theme) {
    final s = ev.subjetivo;
    final sv = ev.objetivo.signosVitales;
    final ef = ev.objetivo.examenFisico;
    final ex = ev.objetivo.examenes;
    final a = ev.evaluacion;
    final p = ev.plan;

    // Compute symptoms before building children list (Dart syntax requirement)
    final syms = _symptoms(s, isEs);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fecha / Número
          Row(
            children: [
              Text(
                'EVOLUCIÓN $num',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: InternacionTheme.accentLight,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Text(ev.fechaFormatada,
                  style: TextStyle(
                      fontSize: 10.5, color: theme.textSecondary)),
            ],
          ),
          _docDivider(theme),
          const SizedBox(height: 8),

          // Evolución (subjetivo)
          if (s.notePasaNoche.isNotEmpty)
            _docParagraph(
                isEs ? 'Evolución:' : 'Evolução:', s.notePasaNoche, theme),

          // Síntomas
          if (syms.isNotEmpty)
            _docParagraph(
                isEs ? 'Síntomas:' : 'Sintomas:', syms, theme),

          // SV
          if (!sv.isEmpty)
            _docParagraph('SV:', _formatSv(sv), theme),

          // EF
          if (ef.estadoGeneral.isNotEmpty)
            _docParagraph('EG:', ef.estadoGeneral, theme),
          if (ef.acv.isNotEmpty) _docParagraph('CV:', ef.acv, theme),
          if (ef.ar.isNotEmpty) _docParagraph('Resp:', ef.ar, theme),
          if (ef.abdomen.isNotEmpty)
            _docParagraph('Abd:', ef.abdomen, theme),
          if (ef.extremidades.isNotEmpty)
            _docParagraph('MMII:', ef.extremidades, theme),

          // Lab
          if (ex.laboratorio.isNotEmpty)
            _docParagraph(
                isEs ? 'Laboratorio:' : 'Laboratório:',
                ex.laboratorio,
                theme),

          // Impresión
          if (a.notasEvaluacion.isNotEmpty)
            _docParagraph(
                isEs ? 'Impresión:' : 'Impressão:', a.notasEvaluacion, theme),

          // Conducta
          if (p.planTerapeutico.isNotEmpty)
            _docParagraph(
                isEs ? 'Conducta:' : 'Conduta:', p.planTerapeutico, theme),

          // Firma
          const SizedBox(height: 6),
          Text(
            'Dr/Dra. ${ev.autorNombre}',
            style: TextStyle(
              fontSize: 11.5,
              fontStyle: FontStyle.italic,
              color: theme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _symptoms(SubjetivoData s, bool isEs) {
    final syms = <String>[];
    if (s.fiebre) syms.add(isEs ? 'Fiebre' : 'Febre');
    if (s.disnea) syms.add(isEs ? 'Disnea' : 'Dispneia');
    if (s.nauseas) syms.add(isEs ? 'Náuseas' : 'Náuseas');
    if (s.tos) syms.add(isEs ? 'Tos' : 'Tosse');
    if (s.suenoRestado) syms.add(isEs ? 'Sueño alterado' : 'Sono alterado');
    return syms.join(', ');
  }

  String _formatSv(SignosVitales sv) {
    final parts = <String>[];
    if (sv.pa.isNotEmpty) parts.add('TA: ${sv.pa} mmHg');
    if (sv.fc.isNotEmpty) parts.add('FC: ${sv.fc} lpm');
    if (sv.fr.isNotEmpty) parts.add('FR: ${sv.fr} rpm');
    if (sv.satO2.isNotEmpty) parts.add('SatO₂: ${sv.satO2}%');
    if (sv.temperatura.isNotEmpty) parts.add('T: ${sv.temperatura}°C');
    return parts.join('  ');
  }

  String _today() {
    final n = DateTime.now();
    return '${n.day.toString().padLeft(2, '0')}/${n.month.toString().padLeft(2, '0')}/${n.year}';
  }

  Widget _docSection(String label, InternacionTheme theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: InternacionTheme.accentLight,
        ),
      ),
    );
  }

  Widget _docField(String label, String value, InternacionTheme theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: theme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12, color: theme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _docParagraph(String label, String value, InternacionTheme theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: theme.textSecondary,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 12,
                color: theme.textPrimary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _docDivider(InternacionTheme theme) {
    return Container(
      height: 0.8,
      color: theme.border,
      margin: const EdgeInsets.symmetric(vertical: 6),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// R3: Auditoria Clínica — read-only viewer
// ═════════════════════════════════════════════════════════════════════════════
class _AuditoriaViewer extends StatelessWidget {
  final EvolucionModel ev;
  final bool dark;
  final String lang;

  const _AuditoriaViewer(
      {required this.ev, required this.dark, required this.lang});

  bool get isEs => lang == 'es';

  @override
  Widget build(BuildContext context) {
    final theme = InternacionTheme(dark);
    final bg = dark ? const Color(0xFF0F1116) : Colors.white;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
              color: InternacionTheme.amber.withValues(alpha: 0.35),
              width: 1.2),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color:
                          InternacionTheme.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.lock_clock_rounded,
                        size: 18, color: InternacionTheme.amber),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEs ? 'Auditoría Clínica' : 'Auditoria Clínica',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: theme.textPrimary),
                        ),
                        Text(ev.fechaFormatada,
                            style: TextStyle(
                                fontSize: 11.5,
                                color: InternacionTheme.amber,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color:
                          InternacionTheme.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: InternacionTheme.amber
                              .withValues(alpha: 0.40),
                          width: 0.8),
                    ),
                    child: Text('READ-ONLY',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: InternacionTheme.amber,
                            letterSpacing: 0.5)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: InternacionTheme.amber
                      .withValues(alpha: dark ? 0.10 : 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: InternacionTheme.amber.withValues(alpha: 0.30),
                      width: 0.8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield_rounded,
                        size: 13, color: InternacionTheme.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isEs
                            ? 'Registro histórico protegido. Visualización de solo lectura.'
                            : 'Registro histórico protegido. Visualização somente leitura.',
                        style: TextStyle(
                            fontSize: 11.5,
                            color: InternacionTheme.amber,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Divider(color: theme.border, height: 1, thickness: 0.8),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                children: _buildFields(theme),
              ),
            ),
            Divider(color: theme.border, height: 1, thickness: 0.8),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 12, 20, 12 + MediaQuery.of(context).viewPadding.bottom),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: theme.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.border, width: 0.9),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.close_rounded,
                          size: 16, color: theme.textSecondary),
                      const SizedBox(width: 6),
                      Text(isEs ? 'Cerrar' : 'Fechar',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build 194: verifica se TODOS os campos SOAP estão vazios
  bool _isSoapEmpty() {
    final s = ev.subjetivo;
    final sv = ev.objetivo.signosVitales;
    final ef = ev.objetivo.examenFisico;
    final ex = ev.objetivo.examenes;
    final a = ev.evaluacion;
    final p = ev.plan;
    final hasSubjetivo = s.notePasaNoche.isNotEmpty ||
        s.notasLibres.isNotEmpty ||
        s.alimentacion.isNotEmpty ||
        s.diuresis.isNotEmpty ||
        s.evacuacion.isNotEmpty ||
        s.fiebre || s.disnea || s.nauseas || s.tos || s.suenoRestado ||
        (s.dolorEscala != null && s.dolorEscala! > 0);
    final hasObjetivo = !sv.isEmpty ||
        ef.estadoGeneral.isNotEmpty || ef.acv.isNotEmpty ||
        ef.ar.isNotEmpty || ef.abdomen.isNotEmpty || ef.extremidades.isNotEmpty ||
        ex.laboratorio.isNotEmpty || ex.imagenes.isNotEmpty ||
        ex.culturas.isNotEmpty || ex.ecg.isNotEmpty ||
        ev.objetivo.tratamientoActual.isNotEmpty;
    final hasAvaliacao = a.notasEvaluacion.isNotEmpty ||
        a.estado != null || a.problemasActivos.isNotEmpty;
    final hasPlano = p.planTerapeutico.isNotEmpty || p.criteriosAlta.isNotEmpty;
    final hasFarmacos = ev.farmacos.isNotEmpty;
    return !hasSubjetivo && !hasObjetivo && !hasAvaliacao && !hasPlano && !hasFarmacos;
  }

  List<Widget> _buildFields(InternacionTheme theme) {
    final widgets = <Widget>[];
    final s = ev.subjetivo;
    final sv = ev.objetivo.signosVitales;
    final ef = ev.objetivo.examenFisico;
    final ex = ev.objetivo.examenes;
    final a = ev.evaluacion;
    final p = ev.plan;

    // Build 194: Fallback — nunca exibe bloco vazio
    if (_isSoapEmpty()) {
      widgets.add(Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: InternacionTheme.amber.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: InternacionTheme.amber.withValues(alpha: 0.30),
            width: 0.9,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded,
                size: 16, color: InternacionTheme.amber),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isEs
                    ? 'Contenido de la evolucion no disponible o en procesamiento.\nEs posible que el registro sea de una version anterior del sistema.'
                    : 'Conteudo da evolucao indisponivel ou em processamento.\nO registro pode ser de uma versao anterior do sistema.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: InternacionTheme.amber,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ));
      return widgets;
    }

    void addSection(String label, IconData icon, Color color) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 11, color: color),
                  const SizedBox(width: 5),
                  Text(label.toUpperCase(),
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: color,
                          letterSpacing: 0.4)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                  height: 1, color: color.withValues(alpha: 0.20)),
            ),
          ],
        ),
      ));
    }

    void addField(String label, String value) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: theme.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.border, width: 0.8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 80,
                child: Text(label,
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: theme.textSecondary)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(value,
                    style: TextStyle(
                        fontSize: 13,
                        color: theme.textPrimary,
                        height: 1.4)),
              ),
            ],
          ),
        ),
      ));
    }

    // Subjetivo
    addSection(isEs ? 'Evolución' : 'Evolução',
        Icons.chat_bubble_outline_rounded, InternacionTheme.cyan);
    if (s.notePasaNoche.isNotEmpty) {
      addField(isEs ? 'Noche' : 'Noite', s.notePasaNoche);
    }
    if (s.dolorEscala != null && s.dolorEscala! > 0) addField('EVA', '${s.dolorEscala}/10');
    final syms = <String>[];
    if (s.fiebre) syms.add(isEs ? 'Fiebre' : 'Febre');
    if (s.disnea) syms.add(isEs ? 'Disnea' : 'Dispneia');
    if (s.nauseas) syms.add('Náuseas');
    if (s.tos) syms.add(isEs ? 'Tos' : 'Tosse');
    if (s.suenoRestado) syms.add(isEs ? 'Sueño alt.' : 'Sono alt.');
    if (syms.isNotEmpty) {
      addField(isEs ? 'Síntomas' : 'Sintomas', syms.join(', '));
    }
    if (s.alimentacion.isNotEmpty) {
      addField(isEs ? 'Alimentación' : 'Alimentação', s.alimentacion);
    }
    if (s.diuresis.isNotEmpty) addField('Diuresis', s.diuresis);
    if (s.evacuacion.isNotEmpty) {
      addField(isEs ? 'Evacuación' : 'Evacuação', s.evacuacion);
    }
    if (s.notasLibres.isNotEmpty) {
      addField(isEs ? 'Notas' : 'Notas', s.notasLibres);
    }

    // SV
    if (!sv.isEmpty) {
      widgets.add(const SizedBox(height: 8));
      addSection(isEs ? 'Signos Vitales' : 'Sinais Vitais',
          Icons.monitor_heart_rounded, const Color(0xFFEF4444));
      final svParts = <String>[];
      if (sv.pa.isNotEmpty) svParts.add('TA: ${sv.pa} mmHg');
      if (sv.fc.isNotEmpty) svParts.add('FC: ${sv.fc} lpm');
      if (sv.fr.isNotEmpty) svParts.add('FR: ${sv.fr} rpm');
      if (sv.satO2.isNotEmpty) svParts.add('SatO₂: ${sv.satO2}%');
      if (sv.temperatura.isNotEmpty) svParts.add('T: ${sv.temperatura}°C');
      addField('SV', svParts.join('   '));
    }

    // EF
    final hasEf = ef.estadoGeneral.isNotEmpty ||
        ef.acv.isNotEmpty ||
        ef.ar.isNotEmpty ||
        ef.abdomen.isNotEmpty ||
        ef.extremidades.isNotEmpty;
    if (hasEf) {
      widgets.add(const SizedBox(height: 8));
      addSection(isEs ? 'Examen Físico' : 'Exame Físico',
          Icons.accessibility_rounded, const Color(0xFF60A5FA));
      if (ef.estadoGeneral.isNotEmpty) addField('EG', ef.estadoGeneral);
      if (ef.acv.isNotEmpty) addField('CV', ef.acv);
      if (ef.ar.isNotEmpty) addField('Resp', ef.ar);
      if (ef.abdomen.isNotEmpty) addField('Abd', ef.abdomen);
      if (ef.extremidades.isNotEmpty) addField('MMII', ef.extremidades);
    }

    // Exames
    final hasEx = ex.laboratorio.isNotEmpty ||
        ex.imagenes.isNotEmpty ||
        ex.culturas.isNotEmpty ||
        ex.ecg.isNotEmpty;
    if (hasEx) {
      widgets.add(const SizedBox(height: 8));
      addSection(isEs ? 'Laboratorio' : 'Laboratório',
          Icons.biotech_rounded, const Color(0xFF4ADE80));
      if (ex.laboratorio.isNotEmpty) addField('Lab', ex.laboratorio);
      if (ex.imagenes.isNotEmpty) {
        addField(isEs ? 'Imágenes' : 'Imagens', ex.imagenes);
      }
      if (ex.culturas.isNotEmpty) addField('Culturas', ex.culturas);
      if (ex.ecg.isNotEmpty) addField('ECG', ex.ecg);
    }

    // Impresión
    final hasA = a.notasEvaluacion.isNotEmpty ||
        a.estado != null ||
        a.problemasActivos.isNotEmpty;
    if (hasA) {
      widgets.add(const SizedBox(height: 8));
      addSection(isEs ? 'Impresión Clínica' : 'Impressão Clínica',
          Icons.trending_up_rounded, const Color(0xFFF59E0B));
      if (a.estado != null) {
        addField(isEs ? 'Estado' : 'Estado', a.estado!.label(lang));
      }
      if (a.problemasActivos.isNotEmpty) {
        addField(isEs ? 'Problemas' : 'Problemas',
            a.problemasActivos.join('\n'));
      }
      if (a.notasEvaluacion.isNotEmpty) addField('Notas', a.notasEvaluacion);
    }

    // Plan
    final hasP =
        p.planTerapeutico.isNotEmpty || p.criteriosAlta.isNotEmpty;
    if (hasP) {
      widgets.add(const SizedBox(height: 8));
      addSection(isEs ? 'Conducta / Plan' : 'Conduta / Plano',
          Icons.assignment_rounded, const Color(0xFFA78BFA));
      if (p.planTerapeutico.isNotEmpty) {
        addField(isEs ? 'Plan' : 'Plano', p.planTerapeutico);
      }
      if (p.criteriosAlta.isNotEmpty) {
        addField(isEs ? 'Alta' : 'Alta', p.criteriosAlta);
      }
    }

    // Fármacos
    if (ev.farmacos.isNotEmpty) {
      widgets.add(const SizedBox(height: 8));
      addSection('Fármacos', Icons.medication_rounded,
          const Color(0xFF059669));
      for (final f in ev.farmacos) {
        final dos = f.dosagem.isNotEmpty ? f.dosagem : '—';
        addField(f.medicamento, dos);
      }
    }

    // Autor
    widgets.add(const SizedBox(height: 12));
    widgets.add(Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.border, width: 0.8),
      ),
      child: Row(
        children: [
          Icon(Icons.person_rounded, size: 14, color: theme.labelColor),
          const SizedBox(width: 8),
          Text(
            '${isEs ? 'Firma' : 'Assinatura'}: ${ev.autorNombre}',
            style: TextStyle(
                fontSize: 12,
                color: theme.textSecondary,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    ));

    return widgets;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Divisor de seção com título
// ═════════════════════════════════════════════════════════════════════════════
class _SectionDivider extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool dark;
  final InternacionTheme theme;

  const _SectionDivider({
    required this.label,
    required this.sublabel,
    required this.dark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child:
                Divider(color: theme.border, height: 1, thickness: 0.8)),
        const SizedBox(width: 10),
        Column(
          children: [
            Text(label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: InternacionTheme(dark).accent,
                )),
            Text(sublabel,
                style: TextStyle(fontSize: 9, color: theme.labelColor)),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
            child:
                Divider(color: theme.border, height: 1, thickness: 0.8)),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Build 173: _TrashModal — Papelera de Reciclaje (30 días)
// StatefulWidget para estado reativo interno (sem depender do pai)
// ═════════════════════════════════════════════════════════════════════════════
class _TrashModal extends StatefulWidget {
  final String uid;
  final bool dark;
  final String lang;
  final VoidCallback onRestored; // callback para refresh do grid principal

  const _TrashModal({
    required this.uid,
    required this.dark,
    required this.lang,
    required this.onRestored,
  });

  @override
  State<_TrashModal> createState() => _TrashModalState();
}

class _TrashModalState extends State<_TrashModal> {
  // Build 202: Stream reativo — substitui FutureBuilder one-shot.
  // O card sai da lixeira INSTANTANEAMENTE quando Firestore confirma o update,
  // sem depender de setState manual nem de widget.onRestored() para a lixeira.
  late final Stream<List<DeletedSession>> _stream;
  String? _processingKey; // chave do item em operação (spinner local)

  bool get isEs => widget.lang == 'es';

  @override
  void initState() {
    super.initState();
    _stream = InternacionFirestoreService.deletedSessionsStream(widget.uid);
  }

  Future<void> _restore(DeletedSession item) async {
    if (_processingKey != null) return; // evita duplo clique
    setState(() => _processingKey = item.sessionKey);
    await InternacionFirestoreService.restoreSession(
        widget.uid, item.sessionKey);
    // O StreamBuilder detecta a mudança automaticamente — não precisa
    // remover o item via setState. O card some quando o Firestore confirma.
    // Chamamos onRestored() para que o grid do painel pai também reaja.
    if (mounted) {
      setState(() => _processingKey = null);
      widget.onRestored();
      final nomePac = item.paciente.nome.isNotEmpty
          ? item.paciente.nome
          : (isEs ? 'Paciente' : 'Paciente');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.restore_rounded, color: Colors.white, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isEs
                  ? '$nomePac restaurado(a) — aparece em MI GUARDIA'
                  : '$nomePac restaurado(a) — aparece em MI GUARDIA',
            ),
          ),
        ]),
        backgroundColor: InternacionTheme.accentLight,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  Future<void> _hardDelete(DeletedSession item) async {
    // Confirmação antes do hard delete
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.dark ? const Color(0xFF0F1116) : Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: InternacionTheme.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.delete_forever_rounded,
                size: 17, color: InternacionTheme.red),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isEs ? 'Eliminar Definitivamente' : 'Eliminar Definitivamente',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: widget.dark ? Colors.white : const Color(0xFF111827),
              ),
            ),
          ),
        ]),
        content: Text(
          isEs
              ? 'Esta acción es irreversible. El registro será eliminado permanentemente del sistema.'
              : 'Esta ação é irreversível. O registro será eliminado permanentemente do sistema.',
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: widget.dark ? Colors.white70 : const Color(0xFF374151),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: widget.dark ? Colors.white54 : Colors.grey,
            ),
            child: Text(isEs ? 'Cancelar' : 'Cancelar',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: InternacionTheme.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(isEs ? 'Eliminar' : 'Eliminar',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _processingKey = item.sessionKey);
    await InternacionFirestoreService.hardDeleteSession(
        widget.uid, item.sessionKey);
    // StreamBuilder detecta a remoção automaticamente via Firestore.
    // Não precisamos manipular _items manualmente.
    if (mounted) {
      setState(() => _processingKey = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.delete_forever_rounded,
              color: Colors.white, size: 15),
          const SizedBox(width: 8),
          Text(isEs
              ? 'Registro eliminado definitivamente'
              : 'Registro eliminado definitivamente'),
        ]),
        backgroundColor: InternacionTheme.red,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = InternacionTheme(widget.dark);
    final bg = widget.dark ? const Color(0xFF0F1116) : Colors.white;

    return DraggableScrollableSheet(
      initialChildSize: 0.70,
      minChildSize: 0.40,
      maxChildSize: 0.94,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: InternacionTheme.red.withValues(alpha: 0.25),
            width: 1.0,
          ),
        ),
        child: Column(
          children: [
            // ── Handle ──────────────────────────────────────────────────────
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── Header ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color:
                          InternacionTheme.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.restore_from_trash_rounded,
                        size: 18, color: InternacionTheme.red),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEs
                              ? 'Papelera de Reciclaje'
                              : 'Lixeira de Reciclagem',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: theme.textPrimary,
                          ),
                        ),
                        Text(
                          isEs
                              ? 'Últimos 30 días · restaurar o eliminar'
                              : 'Últimos 30 dias · restaurar ou eliminar',
                          style: TextStyle(
                              fontSize: 11, color: theme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  // Indicador de stream ativo (Build 202: refresh automático via Firestore)
                  Tooltip(
                    message: isEs
                        ? 'Actualización automática en tiempo real'
                        : 'Atualização automática em tempo real',
                    child: Icon(Icons.wifi_rounded,
                        size: 16,
                        color: InternacionTheme.accentLight.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        size: 19, color: theme.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Divider(color: theme.border, height: 1, thickness: 0.8),

            // ── Corpo — StreamBuilder reativo (Build 202) ─────────────────
            // O StreamBuilder escuta deletedSessionsStream() em tempo real.
            // Quando restoreSession() altera status→active no Firestore, o
            // snapshot muda imediatamente e o card desaparece sem setState.
            Expanded(
              child: StreamBuilder<List<DeletedSession>>(
                stream: _stream,
                builder: (context, snapshot) {
                  // ── Loading (primeiro frame ainda sem dados) ──────────────
                  if (snapshot.connectionState == ConnectionState.waiting
                      && !snapshot.hasData) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                InternacionTheme.red),
                            strokeWidth: 2.5,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isEs ? 'Buscando...' : 'Buscando...',
                            style: TextStyle(
                                fontSize: 12, color: theme.textSecondary),
                          ),
                        ],
                      ),
                    );
                  }

                  final items = snapshot.data ?? [];

                  // ── Lixeira vazia ─────────────────────────────────────────
                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_outline_rounded,
                              size: 48, color: theme.border),
                          const SizedBox(height: 12),
                          Text(
                            isEs ? 'Papelera vacía' : 'Lixeira vazia',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: theme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isEs
                                ? 'No hay registros eliminados en los últimos 30 días.'
                                : 'Nenhum registro excluído nos últimos 30 dias.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 11.5,
                                color: theme.labelColor,
                                height: 1.4),
                          ),
                        ],
                      ),
                    );
                  }

                  // ── Lista de itens ────────────────────────────────────────
                  return ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final item = items[i];
                      final isProcessing = _processingKey == item.sessionKey;
                      final nome = item.paciente.nome.isNotEmpty
                          ? item.paciente.nome
                          : (isEs ? 'Paciente' : 'Paciente');
                      final cama = item.paciente.cama.isNotEmpty
                          ? (isEs
                              ? 'Cama ${item.paciente.cama}'
                              : 'Leito ${item.paciente.cama}')
                          : '';
                      final diag = item.paciente.diagnostico;

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: InternacionTheme.red.withValues(alpha: 0.18),
                            width: 0.9,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Linha superior: ícone + info ────────────────
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Ícone
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: InternacionTheme.red
                                        .withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.person_off_rounded,
                                      size: 18, color: InternacionTheme.red),
                                ),
                                const SizedBox(width: 12),

                                // Info textual
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nome,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: theme.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        [
                                          if (cama.isNotEmpty) cama,
                                          '${item.historialCount} evol.',
                                        ].join('  ·  '),
                                        style: TextStyle(
                                            fontSize: 10.5,
                                            color: theme.textSecondary),
                                      ),
                                      if (diag.isNotEmpty) ...[
                                        const SizedBox(height: 1),
                                        Text(
                                          diag,
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: theme.labelColor,
                                              height: 1.3),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Row(children: [
                                        Icon(Icons.schedule_rounded,
                                            size: 10,
                                            color: InternacionTheme.red
                                                .withValues(alpha: 0.7)),
                                        const SizedBox(width: 3),
                                        Text(
                                          item.deletedAtLabel,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: InternacionTheme.red
                                                .withValues(alpha: 0.7),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ]),
                                    ],
                                  ),
                                ),

                                // Spinner quando processando
                                if (isProcessing)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 8),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          InternacionTheme.accentLight,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // ── Linha inferior: botões visíveis ─────────────
                            Row(
                              children: [
                                // ── Botão RESTAURAR (principal, visível) ──
                                Expanded(
                                  child: GestureDetector(
                                    onTap: isProcessing
                                        ? null
                                        : () => _restore(item),
                                    child: Container(
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: InternacionTheme.accentLight
                                            .withValues(
                                                alpha: widget.dark ? 0.15 : 0.10),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        border: Border.all(
                                          color: InternacionTheme.accentLight
                                              .withValues(alpha: 0.45),
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.restore_rounded,
                                            size: 15,
                                            color: InternacionTheme.accentLight,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            isEs ? 'Restaurar' : 'Restaurar',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color:
                                                  InternacionTheme.accentLight,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // ── Botão ELIMINAR (secundário, ícone apenas)
                                GestureDetector(
                                  onTap: isProcessing
                                      ? null
                                      : () => _hardDelete(item),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: InternacionTheme.red.withValues(
                                          alpha: widget.dark ? 0.15 : 0.09),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: InternacionTheme.red
                                            .withValues(alpha: 0.35),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.delete_forever_rounded,
                                      size: 16,
                                      color: InternacionTheme.red,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
