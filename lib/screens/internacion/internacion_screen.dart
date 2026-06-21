// ─────────────────────────────────────────────────────────────────────────────
// InternacionScreen — Build 168
//
// 168-1: Firestore Sync — sessions stream em tempo real (multi-device)
// 168-2: Lixeira 30d — softDelete (isDeleted:true) em vez de hard delete
// 168-3: _SessionCard redesenhado — severity border + [Editar][Excluir] + [Evoluir]
// 168-4: Card body tap → _SessionPreviewDialog (read-only + ações)
// 168-5: PatientAccordion tap → _DocumentPreviewModal (paper-style viewer)
// 168-6: Auto-save on Nueva — salva silencioso se dirty, skip se vazio
// 168-R: R1(FAB→AppBar) R2(S fechado) R3(Auditoria) R4(Retomar same-day)
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import 'models/evolucion_model.dart';
import 'components/resumen_header.dart';
import 'components/historial_section.dart';
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
  const InternacionScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _draftEvolucion = _newDraft();
    DrugInteractionService.instance.init();
    // Aguarda o primeiro frame para ter acesso ao provider
    WidgetsBinding.instance.addPostFrameCallback((_) => _initSessions());
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

  EvolucionModel _newDraft() => EvolucionModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fecha: DateTime.now(),
        autorNombre: 'Dr.',
      );

  // ── 168-1: Salva na nuvem (com fallback local) ───────────────────────────
  Future<void> _persistSession() async {
    final uid = _uid;
    if (uid != null && uid.isNotEmpty) {
      await InternacionFirestoreService.saveSession(
        uid: uid,
        paciente: _paciente,
        historial: _historial,
        existingKey: _currentSessionKey,
      );
      _currentSessionKey ??= InternacionFirestoreService.sessionKey(_paciente);
    }
    // Fallback local sempre (offline resilience)
    await InternacionPersistence.saveSession(
      paciente: _paciente,
      historial: _historial,
    );
  }

  void _onSaveEvolucion(EvolucionModel ev) async {
    setState(() {
      _historial = [..._historial, ev];
      _draftEvolucion = _newDraft();
    });
    await _persistSession();
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

  // ── 168-R4: Retomar — mesmo dia, sem auto-avanço ─────────────────────────
  void _resumeSession(PacienteSession session) {
    final sameDayDraft = EvolucionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fecha: DateTime.now(),
      autorNombre: session.historial.isNotEmpty
          ? session.historial.last.autorNombre
          : 'Dr.',
      subjetivo: const SubjetivoData(),
      objetivo: const ObjetivoData(),
      evaluacion: const EvaluacionData(),
      plan: const PlanData(),
    );
    setState(() {
      _paciente = session.paciente;
      _historial = session.historial;
      _draftEvolucion = sameDayDraft;
      _currentSessionKey = session.sessionKey;
      _savedSessions = _savedSessions
          .where((s) => s.sessionKey != session.sessionKey)
          .toList();
    });
    _soapKey.currentState?.resetSoap(sameDayDraft);

    final isEs = _isEs;
    final nome = session.paciente.nome.isNotEmpty
        ? session.paciente.nome
        : (isEs ? 'Paciente' : 'Paciente');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.history_rounded, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(isEs
              ? 'Día ${session.paciente.diaInternacao} — Sesión de $nome cargada'
              : 'Dia ${session.paciente.diaInternacao} — Sessão de $nome carregada'),
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
    if (_isDirty && _historial.isNotEmpty) {
      await _persistSession();
    }

    await InternacionPersistence.clearActiveSession(_paciente);
    final freshDraft = _newDraft();
    setState(() {
      _paciente = const PacienteInternacaoData(diaInternacao: 1);
      _historial = [];
      _draftEvolucion = freshDraft;
      _currentSessionKey = null;
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

  // ── R3: Auditoria clínica ─────────────────────────────────────────────────
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

    return Scaffold(
      backgroundColor: theme.surface,
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
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: theme.accent),
                    tooltip: isEs ? 'Volver' : 'Voltar',
                    onPressed: () => Navigator.maybePop(context),
                    padding: const EdgeInsets.all(8),
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: theme.accent
                          .withValues(alpha: dark ? 0.15 : 0.09),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.local_hospital_rounded,
                        size: 15, color: theme.accent),
                  ),
                  const SizedBox(width: 8),
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
                          'SOAP · MedCases Pro',
                          style: TextStyle(
                              fontSize: 10, color: theme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (_historial.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.accent
                            .withValues(alpha: dark ? 0.15 : 0.09),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_historial.length} evol.',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: theme.accent,
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  // R1: Botão compacto "Nueva"
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. RESUMEN ──────────────────────────────────────────────────
            ResumenHeader(
              pacienteId: _paciente.nome,
              cama: _paciente.cama,
              diagnostico: _paciente.diagnostico,
              diadeInternacion: _paciente.diaInternacao,
              dark: dark,
              lang: lang,
            ),
            const SizedBox(height: 12),

            // ── 2. COPILOTO IA ─────────────────────────────────────────────
            CopilotButton(dark: dark, lang: lang, onApproved: _onAiApproved),
            const SizedBox(height: 12),

            // ── 3. HISTORIAL (R3: auditoria on tap) ────────────────────────
            HistorialSection(
              evoluciones: _historial,
              dark: dark,
              lang: lang,
              onTap: (ev) =>
                  _showAuditoriaModal(context, ev, dark, lang),
            ),
            if (_historial.isNotEmpty) const SizedBox(height: 12),

            // ── 4. DADOS DO PACIENTE (168-5: doc preview on tap) ───────────
            GestureDetector(
              onLongPress: () => _showDocumentPreview(context, dark, lang),
              child: PatientAccordion(
                data: _paciente,
                dark: dark,
                lang: lang,
                onChanged: (d) => setState(() => _paciente = d),
              ),
            ),
            const SizedBox(height: 10),

            // ── 5. FÁRMACOS ─────────────────────────────────────────────────
            FarmacosAccordion(
              farmacos: _draftEvolucion.farmacos,
              dark: dark,
              lang: lang,
              onChanged: (list) => setState(() {
                _draftEvolucion = _draftEvolucion.copyWith(farmacos: list);
              }),
            ),
            const SizedBox(height: 16),

            // ── 6. DIVISOR ─────────────────────────────────────────────────
            _SectionDivider(
              label:
                  isEs ? 'NUEVA EVOLUCIÓN MÉDICA' : 'NOVA EVOLUÇÃO MÉDICA',
              sublabel: 'SOAP',
              dark: dark,
              theme: theme,
            ),
            const SizedBox(height: 12),

            // ── 7. MOTOR SOAP ───────────────────────────────────────────────
            SoapSectionWidget(
              key: _soapKey,
              evolucion: _draftEvolucion,
              dark: dark,
              lang: lang,
              autorNombre: doctorName,
              paciente: _paciente,
              onSave: _onSaveEvolucion,
            ),

            // ── 8. GRID SESSÕES SALVAS (168-3: redesign cards) ─────────────
            if (_sessionsLoaded && _savedSessions.isNotEmpty) ...[
              const SizedBox(height: 24),
              _SectionDivider(
                label: isEs
                    ? 'PACIENTES INTERNADOS GUARDADOS'
                    : 'PACIENTES INTERNADOS SALVOS',
                sublabel: isEs
                    ? '${_savedSessions.length} sesión${_savedSessions.length > 1 ? 'es' : ''}'
                    : '${_savedSessions.length} sessão${_savedSessions.length > 1 ? 'ões' : ''}',
                dark: dark,
                theme: theme,
              ),
              const SizedBox(height: 12),
              _SessionsGrid(
                sessions: _savedSessions,
                dark: dark,
                lang: lang,
                theme: theme,
                onResume: _resumeSession,
                onDelete: _deleteSession,
                onPreview: (session) =>
                    _showSessionPreview(context, session, dark, lang),
              ),
            ],
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
        onResume: () {
          Navigator.of(ctx).pop();
          _resumeSession(session);
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
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 168-3: Grid de sessões redesenhado
// ═════════════════════════════════════════════════════════════════════════════
class _SessionsGrid extends StatelessWidget {
  final List<PacienteSession> sessions;
  final bool dark;
  final String lang;
  final InternacionTheme theme;
  final ValueChanged<PacienteSession> onResume;
  final Future<void> Function(PacienteSession) onDelete;
  final ValueChanged<PacienteSession> onPreview;

  const _SessionsGrid({
    required this.sessions,
    required this.dark,
    required this.lang,
    required this.theme,
    required this.onResume,
    required this.onDelete,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.05,
      children: sessions
          .map((s) => _SessionCard168(
                session: s,
                dark: dark,
                lang: lang,
                theme: theme,
                onResume: () => onResume(s),
                onDelete: () => onDelete(s),
                onTapBody: () => onPreview(s),
              ))
          .toList(),
    );
  }
}

// ── 168-3: Card redesenhado com severity border ───────────────────────────────
class _SessionCard168 extends StatelessWidget {
  final PacienteSession session;
  final bool dark;
  final String lang;
  final InternacionTheme theme;
  final VoidCallback onResume;
  final VoidCallback onDelete;
  final VoidCallback onTapBody;

  const _SessionCard168({
    required this.session,
    required this.dark,
    required this.lang,
    required this.theme,
    required this.onResume,
    required this.onDelete,
    required this.onTapBody,
  });

  bool get isEs => lang == 'es';

  // Cor de severidade baseada no estado clínico da última evolução
  Color _severityColor() {
    if (session.historial.isEmpty) return InternacionTheme.accentLight;
    final last = session.historial.last;
    final estado = last.evaluacion.estado;
    if (estado == null) return InternacionTheme.accentLight;
    return Color(estado.colorValue);
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
                  onTap: onResume,
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
              onTap: onResume,
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
// 168-4: Session Preview Dialog
// ═════════════════════════════════════════════════════════════════════════════
class _SessionPreviewDialog extends StatelessWidget {
  final PacienteSession session;
  final bool dark;
  final String lang;
  final VoidCallback onResume;
  final VoidCallback onDelete;
  final ValueChanged<String> onCopy;

  const _SessionPreviewDialog({
    required this.session,
    required this.dark,
    required this.lang,
    required this.onResume,
    required this.onDelete,
    required this.onCopy,
  });

  bool get isEs => lang == 'es';

  String _buildPreviewText() {
    final p = session.paciente;
    final buf = StringBuffer();
    buf.writeln('FICHA DE INTERNACIÓN — MedCases Pro');
    buf.writeln('');
    if (p.nome.isNotEmpty) buf.writeln('Paciente: ${p.nome}');
    if (p.cama.isNotEmpty) buf.writeln('Cama: ${p.cama}');
    if (p.diagnostico.isNotEmpty) buf.writeln('Diagnóstico: ${p.diagnostico}');
    buf.writeln('Día de internación: ${p.diaInternacao}');
    buf.writeln('Evoluciones: ${session.historial.length}');
    buf.writeln('');
    for (final ev in session.historial) {
      buf.writeln('── ${ev.fechaFormatada} ──');
      final sv = ev.objetivo.signosVitales;
      if (!sv.isEmpty) {
        final parts = <String>[];
        if (sv.pa.isNotEmpty) parts.add('TA: ${sv.pa}');
        if (sv.fc.isNotEmpty) parts.add('FC: ${sv.fc}');
        if (sv.satO2.isNotEmpty) parts.add('SatO₂: ${sv.satO2}%');
        if (sv.temperatura.isNotEmpty) parts.add('T: ${sv.temperatura}°C');
        buf.writeln('SV: ${parts.join('  ')}');
      }
      if (ev.evaluacion.notasEvaluacion.isNotEmpty) {
        buf.writeln('Impresión: ${ev.evaluacion.notasEvaluacion}');
      }
      if (ev.plan.planTerapeutico.isNotEmpty) {
        buf.writeln('Conducta: ${ev.plan.planTerapeutico}');
      }
    }
    return buf.toString().trimRight();
  }

  @override
  Widget build(BuildContext context) {
    final theme = InternacionTheme(dark);
    final p = session.paciente;
    final bg = dark ? const Color(0xFF0F1116) : Colors.white;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 520),
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

            // ── Corpo scrollável ─────────────────────────────────────────────
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
                    if (session.historial.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        isEs
                            ? 'ÚLTIMAS EVOLUCIONES'
                            : 'ÚLTIMAS EVOLUÇÕES',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                          color: theme.labelColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...session.historial.reversed.take(3).map((ev) {
                        final sv = ev.objetivo.signosVitales;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.card,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: theme.border, width: 0.8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ev.fechaFormatada,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: InternacionTheme.accentLight,
                                  )),
                              if (!sv.isEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  [
                                    if (sv.pa.isNotEmpty) 'TA: ${sv.pa}',
                                    if (sv.fc.isNotEmpty) 'FC: ${sv.fc}',
                                    if (sv.satO2.isNotEmpty)
                                      'SatO₂: ${sv.satO2}%',
                                    if (sv.temperatura.isNotEmpty)
                                      'T: ${sv.temperatura}°C',
                                  ].join('   '),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: theme.textSecondary),
                                ),
                              ],
                              if (ev.evaluacion.notasEvaluacion
                                  .isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  ev.evaluacion.notasEvaluacion,
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      color: theme.textPrimary,
                                      height: 1.3),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),

            // ── Ações: [Copiar] [Excluir] [Evolucionar] ──────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Row(
                children: [
                  // Copiar
                  _actionBtn(
                    icon: Icons.copy_rounded,
                    label: isEs ? 'Copiar' : 'Copiar',
                    color: InternacionTheme.cyan,
                    dark: dark,
                    theme: theme,
                    onTap: () => onCopy(_buildPreviewText()),
                  ),
                  const SizedBox(width: 6),
                  // Excluir
                  _actionBtn(
                    icon: Icons.delete_outline_rounded,
                    label: isEs ? 'Excluir' : 'Excluir',
                    color: InternacionTheme.red,
                    dark: dark,
                    theme: theme,
                    onTap: onDelete,
                  ),
                  const SizedBox(width: 6),
                  // Evolucionar (primário)
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: onResume,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 11),
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
                            const Icon(Icons.edit_rounded,
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
            ),
          ],
        ),
      ),
    );
  }

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

  List<Widget> _buildFields(InternacionTheme theme) {
    final widgets = <Widget>[];
    final s = ev.subjetivo;
    final sv = ev.objetivo.signosVitales;
    final ef = ev.objetivo.examenFisico;
    final ex = ev.objetivo.examenes;
    final a = ev.evaluacion;
    final p = ev.plan;

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
    if (s.dolorEscala != null) addField('EVA', '${s.dolorEscala}/10');
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
