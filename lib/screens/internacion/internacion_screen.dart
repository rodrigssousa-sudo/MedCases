// ─────────────────────────────────────────────────────────────────────────────
// InternacionScreen — Build 167-R (Refinamento UX)
//
// R1: FAB removido — botão "Nueva" compacto de volta ao AppBar
// R2: Accordion S inicia fechado (openIdx = null)
// R3: Motor de Auditoria — HistorialSection com viewer read-only
// R4: Retomar corrigido — carrega mesmo dia, SEM auto-avanço de dia
//
// Build 165: Hard delete, key collision fix, FAB (revertido em R1)
// Build 164: Motor DDI integrado
// Build 163: Protocolo Clean Slate
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
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
import 'services/soap_copilot_service.dart';
import 'services/drug_interaction_service.dart';

class InternacionScreen extends StatefulWidget {
  const InternacionScreen({super.key});

  @override
  State<InternacionScreen> createState() => _InternacionScreenState();
}

class _InternacionScreenState extends State<InternacionScreen> {
  // ── Estado persistente na sessão ────────────────────────────────────────────
  PacienteInternacaoData _paciente = const PacienteInternacaoData(diaInternacao: 1);
  List<EvolucionModel>   _historial = [];

  // Evolução em andamento (draft)
  late EvolucionModel _draftEvolucion;

  // Key para acessar applyAiDraft() do SoapSectionWidget
  final _soapKey = GlobalKey<SoapSectionWidgetState>();

  // Sessões salvas do dia anterior (para continuidade)
  List<PacienteSession> _savedSessions = [];
  bool _sessionsLoaded = false;

  @override
  void initState() {
    super.initState();
    _draftEvolucion = _newDraft();
    _loadSessions();
    // Pre-warm DDI engine na inicialização (idempotente, TTL 24h)
    DrugInteractionService.instance.init();
  }

  Future<void> _loadSessions() async {
    final sessions = await InternacionPersistence.loadAllSessions();
    if (mounted) {
      setState(() {
        _savedSessions = sessions;
        _sessionsLoaded = true;
      });
    }
  }

  /// Build 162 — nome do médico logado via AppProvider
  String _doctorName(AppProvider p) {
    final name = p.userName.trim();
    if (name.isEmpty) return 'Dr.';
    // Garante prefixo "Dr."/"Dra." se não presente
    if (name.toLowerCase().startsWith('dr')) return name;
    return 'Dr. $name';
  }

  EvolucionModel _newDraft() => EvolucionModel(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    fecha: DateTime.now(),
    autorNombre: 'Dr.',
  );

  void _onSaveEvolucion(EvolucionModel ev) async {
    setState(() {
      _historial = [..._historial, ev];
      _draftEvolucion = _newDraft();
    });

    // Persiste automaticamente
    await InternacionPersistence.saveSession(
      paciente: _paciente,
      historial: _historial,
    );
    // Recarrega sessões para atualizar grid
    await _loadSessions();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(_isEs ? 'Evolución guardada y persistida' : 'Evolução salva e persistida'),
          ]),
          backgroundColor: InternacionTheme.green,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  // ── IA aprovada — injeta SOAP + atualiza dados demográficos (Build 161) ──
  void _onAiApproved(SoapDraftResult draft) {
    // 1. Injeta campos SOAP (S/O/A/P + fármacos) com anti-state-bleed
    _soapKey.currentState?.applyAiDraft(draft);

    // 2. Atualiza dados demográficos se a IA extraiu pelo menos um campo
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

  // ── FIX 165-B: Hard delete da sessão — apaga do SharedPreferences ────────
  // Antes: onDismiss só fazia setState → ao salvar nova sessão o paciente
  // deletado voltava (o dado permanecia no disco).
  // Agora: delete físico PRIMEIRO, depois remove da lista em memória.
  Future<void> _deleteSession(PacienteSession session) async {
    await InternacionPersistence.deleteSession(session.sessionKey);
    if (mounted) {
      setState(() {
        _savedSessions = _savedSessions
            .where((s) => s.sessionKey != session.sessionKey)
            .toList();
      });
    }
  }

  // ── R4: Retoma sessão salva — MESMO DIA, SEM avanço automático ───────────
  // Antes: usava session.nextDayPaciente (diaInternacao+1) e nextDayDraft (zerado)
  // Agora: restaura o paciente e historial exatamente como foram salvos.
  //        O médico decide manualmente quando avançar o dia.
  void _resumeSession(PacienteSession session) {
    // Cria draft do MESMO dia: herda autorNombre mas mantém S/O/A/P limpos
    // para uma nova entrada clínica, preservando o contexto do paciente.
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
      _paciente       = session.paciente;       // MESMO paciente, MESMO dia
      _historial      = session.historial;      // historial anterior preservado
      _draftEvolucion = sameDayDraft;           // novo draft do dia atual
      _savedSessions  = _savedSessions
          .where((s) => s.sessionKey != session.sessionKey)
          .toList();
    });

    // Força rebuild dos TextControllers com estado limpo
    _soapKey.currentState?.resetSoap(sameDayDraft);

    final isEs = _isEs;
    final nome = session.paciente.nome.isNotEmpty ? session.paciente.nome : (isEs ? 'Paciente' : 'Paciente');
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

  // ── Build 163: Protocolo Clean Slate ─────────────────────────────────────
  // Exibe AlertDialog de confirmação → se OK:
  //   1. clearActiveSession() — apaga o rascunho do SharedPreferences
  //   2. Reseta _paciente → estado default
  //   3. Reseta _historial → []
  //   4. Cria novo _draftEvolucion vazio
  //   5. Chama SoapSectionWidgetState.resetSoap() → _draftVersion++ → rebuilds
  //   6. Recarrega grid de sessões salvas
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
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: InternacionTheme.accentLight.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.cleaning_services_rounded,
                size: 18,
                color: InternacionTheme.accentLight,
              ),
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
          ],
        ),
        content: Text(
          isEs
              ? 'Se descartarán todos los datos no guardados del paciente actual. Esta acción no se puede deshacer.'
              : 'Todos os dados não salvos do paciente atual serão descartados. Esta ação não pode ser desfeita.',
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
          // Cancelar — neutro
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).brightness == Brightness.dark
                  ? Colors.white54
                  : const Color(0xFF6B7280),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(
              isEs ? 'Cancelar' : 'Cancelar',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 4),
          // Confirmar — verde esmeralda
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: InternacionTheme.accentLight,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              isEs ? 'Confirmar y Limpiar' : 'Confirmar e Limpar',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // 1. Apaga rascunho do SharedPreferences (anti-reload ao reabrir app)
    await InternacionPersistence.clearActiveSession(_paciente);

    // 2. Deep reset do estado local
    final freshDraft = _newDraft();
    setState(() {
      _paciente       = const PacienteInternacaoData(diaInternacao: 1);
      _historial      = [];
      _draftEvolucion = freshDraft;
    });

    // 3. Força reconstrução de todos os TextControllers via _draftVersion++
    _soapKey.currentState?.resetSoap(freshDraft);

    // 4. Recarrega grid de sessões salvas
    await _loadSessions();

    // 5. Feedback visual
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
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
        ),
      );
    }
  }

  // ── R3: Motor de Auditoria — viewer read-only de evolução histórica ─────────
  // Abre ModalBottomSheet com os dados completos e IMUTÁVEIS do registro
  // selecionado. Nenhum campo é editável: protege integridade da auditoria clínica.
  void _showAuditoriaModal(
    BuildContext ctx,
    EvolucionModel ev,
    bool dark,
    String lang,
  ) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AuditoriaViewer(ev: ev, dark: dark, lang: lang),
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
    final p    = context.watch<AppProvider>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final lang = p.lang;
    final theme = InternacionTheme(dark);
    final isEs = lang == 'es';
    final doctorName = _doctorName(p);   // Build 162: nome dinâmico

    return Scaffold(
      backgroundColor: theme.surface,
      // ── R1: AppBar premium com botão "Nueva" compacto integrado ────────────
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: Container(
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF0D0F14) : Colors.white,
            border: Border(
              bottom: BorderSide(color: theme.border, width: 0.8),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  // Botão VOLTAR
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: theme.accent,
                    ),
                    tooltip: isEs ? 'Volver' : 'Voltar',
                    onPressed: () => Navigator.maybePop(context),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),

                  // Ícone da seção
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: theme.accent.withValues(alpha: dark ? 0.15 : 0.09),
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
                          isEs ? 'INTERNACIÓN Y EVOLUCIÓN' : 'INTERNAÇÃO E EVOLUÇÃO',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: theme.textPrimary,
                          ),
                        ),
                        Text(
                          isEs ? 'Modelo SOAP · MedCases Pro' : 'Modelo SOAP · MedCases Pro',
                          style: TextStyle(fontSize: 10, color: theme.textSecondary),
                        ),
                      ],
                    ),
                  ),

                  // Badge de evoluções salvas
                  if (_historial.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.accent.withValues(alpha: dark ? 0.15 : 0.09),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_historial.length} ${isEs ? 'evol.' : 'evol.'}',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: theme.accent,
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),

                  // R1: Botão "Nueva" compacto — metade do tamanho do FAB anterior
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
                          Icon(
                            Icons.cleaning_services_rounded,
                            size: 13,
                            color: InternacionTheme.accentLight,
                          ),
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

            // ── 1. RESUMEN CLÍNICO ──────────────────────────────────────────
            ResumenHeader(
              pacienteId:       _paciente.nome,
              cama:             _paciente.cama,
              diagnostico:      _paciente.diagnostico,
              diadeInternacion: _paciente.diaInternacao,
              dark: dark,
              lang: lang,
            ),
            const SizedBox(height: 12),

            // ── 2. BOTÃO COPILOTO IA ────────────────────────────────────────
            CopilotButton(
              dark: dark,
              lang: lang,
              onApproved: _onAiApproved,
            ),
            const SizedBox(height: 12),

            // ── 3. HISTORIAL — R3: onTap abre Auditor read-only ────────────
            HistorialSection(
              evoluciones: _historial,
              dark: dark,
              lang: lang,
              onTap: (ev) => _showAuditoriaModal(context, ev, dark, lang),
            ),
            if (_historial.isNotEmpty) const SizedBox(height: 12),

            // ── 4. DADOS DO PACIENTE (colapsável) ───────────────────────────
            PatientAccordion(
              data: _paciente,
              dark: dark,
              lang: lang,
              onChanged: (d) => setState(() => _paciente = d),
            ),
            const SizedBox(height: 10),

            // ── 5. FÁRMACOS ATUAIS (Build 162 — substitui Interacciones) ────
            FarmacosAccordion(
              farmacos: _draftEvolucion.farmacos,
              dark: dark,
              lang: lang,
              onChanged: (list) => setState(() {
                _draftEvolucion = _draftEvolucion.copyWith(farmacos: list);
              }),
            ),
            const SizedBox(height: 16),

            // ── 6. DIVISOR — "Nueva Evolución" ─────────────────────────────
            _SectionDivider(
              label: isEs ? 'NUEVA EVOLUCIÓN MÉDICA' : 'NOVA EVOLUÇÃO MÉDICA',
              sublabel: isEs ? 'Modelo SOAP' : 'Modelo SOAP',
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
              autorNombre: doctorName,   // Build 162: nome dinâmico
              paciente: _paciente,       // Build 167: dados para "Copiar Todo"
              onSave: _onSaveEvolucion,
            ),

            // ── 8. GRID DE PACIENTES SALVOS (Build 162 — MOVIDO PARA BAIXO) ─
            // Posição: abaixo de TODA a evolução SOAP — UX dashboard ao final.
            if (_sessionsLoaded && _savedSessions.isNotEmpty) ...[
              const SizedBox(height: 24),
              _SectionDivider(
                label: isEs ? 'PACIENTES INTERNADOS GUARDADOS' : 'PACIENTES INTERNADOS SALVOS',
                sublabel: isEs
                    ? '${_savedSessions.length} sesión${_savedSessions.length > 1 ? 'es' : ''} activa${_savedSessions.length > 1 ? 's' : ''}'
                    : '${_savedSessions.length} sessão${_savedSessions.length > 1 ? 'ões' : ''} ativa${_savedSessions.length > 1 ? 's' : ''}',
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
                onDismiss: _deleteSession, // FIX 165-B: hard delete físico
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Build 162: Grid 2 colunas de sessões salvas ───────────────────────────────
class _SessionsGrid extends StatelessWidget {
  final List<PacienteSession> sessions;
  final bool dark;
  final String lang;
  final InternacionTheme theme;
  final ValueChanged<PacienteSession> onResume;
  final Future<void> Function(PacienteSession) onDismiss; // FIX 165-B: async

  const _SessionsGrid({
    required this.sessions, required this.dark, required this.lang,
    required this.theme, required this.onResume, required this.onDismiss,
  });

  bool get isEs => lang == 'es';

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.10,
      children: sessions.map((s) => _SessionCard(
        session: s,
        dark: dark,
        lang: lang,
        theme: theme,
        onResume: () => onResume(s),
        onDismiss: () => onDismiss(s), // delega ao _deleteSession (hard delete)
      )).toList(),
    );
  }
}

// ── Card compacto de sessão (célula do grid 2-col) ────────────────────────────
class _SessionCard extends StatelessWidget {
  final PacienteSession session;
  final bool dark;
  final String lang;
  final InternacionTheme theme;
  final VoidCallback onResume;
  final VoidCallback onDismiss;

  const _SessionCard({
    required this.session, required this.dark, required this.lang,
    required this.theme, required this.onResume, required this.onDismiss,
  });

  bool get isEs => lang == 'es';

  @override
  Widget build(BuildContext context) {
    final p    = session.paciente;
    final nome = p.nome.isNotEmpty ? p.nome : (isEs ? 'Paciente' : 'Paciente');
    final cama = p.cama.isNotEmpty ? (isEs ? 'Cama ${p.cama}' : 'Leito ${p.cama}') : '';
    // R4: mostra apenas o dia atual (sem seta "→Día X+1")
    final dia  = isEs
        ? 'Día ${p.diaInternacao}'
        : 'Dia ${p.diaInternacao}';
    final evol = '${session.historial.length} evol.';

    return Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF0E1420) : const Color(0xFFF0F7F4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: InternacionTheme(dark).accent.withValues(alpha: 0.30),
          width: 1.1,
        ),
        boxShadow: [theme.softShadow],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: ícone + dismiss ──────────────────────────────────────
          Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: InternacionTheme(dark).accent.withValues(alpha: dark ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.history_rounded,
                    size: 14, color: InternacionTheme(dark).accent),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onDismiss,
                child: Icon(Icons.close_rounded, size: 14, color: theme.labelColor),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Nome ─────────────────────────────────────────────────────────
          Text(
            nome,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: theme.textPrimary,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (cama.isNotEmpty)
            Text(cama, style: TextStyle(fontSize: 10.5, color: theme.textSecondary)),

          // ── Diagnóstico ───────────────────────────────────────────────────
          if (p.diagnostico.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                p.diagnostico,
                style: TextStyle(fontSize: 10, color: theme.labelColor, height: 1.3),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          const Spacer(),

          // ── Chips: dia + evoluções + botão Retomar ────────────────────────
          Row(
            children: [
              Flexible(
                child: Text(
                  '$dia · $evol',
                  style: TextStyle(
                    fontSize: 9.5,
                    color: InternacionTheme(dark).accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onResume,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                gradient: InternacionTheme(dark).accentGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isEs ? 'Retomar' : 'Retomar',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── R3: Auditoria Clínica — ModalBottomSheet read-only ────────────────────────
// Exibe o registro histórico completo de forma imutável.
// Nenhum TextField: todos os dados são Text() somente-leitura.
class _AuditoriaViewer extends StatelessWidget {
  final EvolucionModel ev;
  final bool dark;
  final String lang;

  const _AuditoriaViewer({
    required this.ev,
    required this.dark,
    required this.lang,
  });

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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: InternacionTheme.amber.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Column(
          children: [
            // ── Handle ────────────────────────────────────────────────────────
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: theme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── Header ────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: InternacionTheme.amber.withValues(alpha: 0.15),
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
                            color: theme.textPrimary,
                          ),
                        ),
                        Text(
                          ev.fechaFormatada,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: InternacionTheme.amber,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Badge leitura somente
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: InternacionTheme.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: InternacionTheme.amber.withValues(alpha: 0.40),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      isEs ? 'READ-ONLY' : 'READ-ONLY',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: InternacionTheme.amber,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Aviso imutabilidade
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color:
                      InternacionTheme.amber.withValues(alpha: dark ? 0.10 : 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: InternacionTheme.amber.withValues(alpha: 0.30),
                    width: 0.8,
                  ),
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
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Divider(color: theme.border, height: 1, thickness: 0.8),

            // ── Conteúdo scrollável ───────────────────────────────────────────
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                children: _buildFields(theme),
              ),
            ),

            // ── Botão fechar ─────────────────────────────────────────────────
            Divider(color: theme.border, height: 1, thickness: 0.8),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20, 12, 20,
                12 + MediaQuery.of(context).viewPadding.bottom,
              ),
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
                      Text(
                        isEs ? 'Cerrar' : 'Fechar',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.textSecondary,
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
    );
  }

  List<Widget> _buildFields(InternacionTheme theme) {
    final widgets = <Widget>[];
    final s  = ev.subjetivo;
    final sv = ev.objetivo.signosVitales;
    final ef = ev.objetivo.examenFisico;
    final ex = ev.objetivo.examenes;
    final a  = ev.evaluacion;
    final p  = ev.plan;

    // ── Evolução (Subjetivo) ─────────────────────────────────────────────────
    widgets.add(_auditSection(
      isEs ? 'Evolución' : 'Evolução',
      Icons.chat_bubble_outline_rounded,
      InternacionTheme.cyan,
      theme,
    ));
    if (s.notePasaNoche.isNotEmpty) {
      widgets.add(_auditField(
        isEs ? 'Cómo pasó la noche' : 'Como passou a noite',
        s.notePasaNoche,
        theme,
      ));
    }
    if (s.dolorEscala != null) {
      widgets.add(_auditField('EVA', '${s.dolorEscala}/10', theme));
    }
    final syms = <String>[];
    if (s.fiebre) syms.add(isEs ? 'Fiebre' : 'Febre');
    if (s.disnea) syms.add(isEs ? 'Disnea' : 'Dispneia');
    if (s.nauseas) syms.add(isEs ? 'Náuseas' : 'Náuseas');
    if (s.tos) syms.add(isEs ? 'Tos' : 'Tosse');
    if (s.suenoRestado) syms.add(isEs ? 'Sueño alterado' : 'Sono alterado');
    if (syms.isNotEmpty) {
      widgets.add(_auditField(
        isEs ? 'Síntomas' : 'Sintomas', syms.join(', '), theme));
    }
    if (s.alimentacion.isNotEmpty) {
      widgets.add(_auditField(
        isEs ? 'Alimentación' : 'Alimentação', s.alimentacion, theme));
    }
    if (s.diuresis.isNotEmpty) {
      widgets.add(_auditField('Diuresis', s.diuresis, theme));
    }
    if (s.evacuacion.isNotEmpty) {
      widgets.add(_auditField(
        isEs ? 'Evacuación' : 'Evacuação', s.evacuacion, theme));
    }
    if (s.notasLibres.isNotEmpty) {
      widgets.add(_auditField(
        isEs ? 'Notas libres' : 'Notas livres', s.notasLibres, theme));
    }

    // ── SV ───────────────────────────────────────────────────────────────────
    if (!sv.isEmpty) {
      widgets.add(const SizedBox(height: 8));
      widgets.add(_auditSection(
        isEs ? 'Signos Vitales' : 'Sinais Vitais',
        Icons.monitor_heart_rounded,
        const Color(0xFFEF4444),
        theme,
      ));
      final svParts = <String>[];
      if (sv.pa.isNotEmpty) svParts.add('TA: ${sv.pa} mmHg');
      if (sv.fc.isNotEmpty) svParts.add('FC: ${sv.fc} lpm');
      if (sv.fr.isNotEmpty) svParts.add('FR: ${sv.fr} rpm');
      if (sv.satO2.isNotEmpty) svParts.add('SatO₂: ${sv.satO2}%');
      if (sv.temperatura.isNotEmpty) svParts.add('Temp: ${sv.temperatura}°C');
      widgets.add(_auditField('SV', svParts.join('   '), theme));
    }

    // ── Examen Físico ────────────────────────────────────────────────────────
    final hasEf = ef.estadoGeneral.isNotEmpty || ef.acv.isNotEmpty ||
        ef.ar.isNotEmpty || ef.abdomen.isNotEmpty || ef.extremidades.isNotEmpty;
    if (hasEf) {
      widgets.add(const SizedBox(height: 8));
      widgets.add(_auditSection(
        isEs ? 'Examen Físico' : 'Exame Físico',
        Icons.accessibility_rounded,
        const Color(0xFF60A5FA),
        theme,
      ));
      if (ef.estadoGeneral.isNotEmpty) {
        widgets.add(_auditField('EG', ef.estadoGeneral, theme));
      }
      if (ef.acv.isNotEmpty) widgets.add(_auditField('CV/Neuro', ef.acv, theme));
      if (ef.ar.isNotEmpty) widgets.add(_auditField('Resp', ef.ar, theme));
      if (ef.abdomen.isNotEmpty) {
        widgets.add(_auditField('Abd', ef.abdomen, theme));
      }
      if (ef.extremidades.isNotEmpty) {
        widgets.add(_auditField('MMII', ef.extremidades, theme));
      }
    }

    // ── Exames Complementares ────────────────────────────────────────────────
    final hasEx = ex.laboratorio.isNotEmpty || ex.imagenes.isNotEmpty ||
        ex.culturas.isNotEmpty || ex.ecg.isNotEmpty;
    if (hasEx) {
      widgets.add(const SizedBox(height: 8));
      widgets.add(_auditSection(
        isEs ? 'Laboratorio / Exámenes' : 'Laboratório / Exames',
        Icons.biotech_rounded,
        const Color(0xFF4ADE80),
        theme,
      ));
      if (ex.laboratorio.isNotEmpty) {
        widgets.add(_auditField(isEs ? 'Lab' : 'Lab', ex.laboratorio, theme));
      }
      if (ex.imagenes.isNotEmpty) {
        widgets.add(_auditField(
          isEs ? 'Imágenes' : 'Imagens', ex.imagenes, theme));
      }
      if (ex.culturas.isNotEmpty) {
        widgets.add(_auditField('Culturas', ex.culturas, theme));
      }
      if (ex.ecg.isNotEmpty) widgets.add(_auditField('ECG', ex.ecg, theme));
    }

    // ── Impresión ────────────────────────────────────────────────────────────
    final hasA = a.notasEvaluacion.isNotEmpty || a.estado != null ||
        a.problemasActivos.isNotEmpty;
    if (hasA) {
      widgets.add(const SizedBox(height: 8));
      widgets.add(_auditSection(
        isEs ? 'Impresión Clínica' : 'Impressão Clínica',
        Icons.trending_up_rounded,
        const Color(0xFFF59E0B),
        theme,
      ));
      if (a.estado != null) {
        widgets.add(_auditField(
          isEs ? 'Estado' : 'Estado',
          a.estado!.label(lang),
          theme,
        ));
      }
      if (a.problemasActivos.isNotEmpty) {
        widgets.add(_auditField(
          isEs ? 'Problemas' : 'Problemas',
          a.problemasActivos.join('\n'),
          theme,
        ));
      }
      if (a.notasEvaluacion.isNotEmpty) {
        widgets.add(_auditField(
          isEs ? 'Notas' : 'Notas', a.notasEvaluacion, theme));
      }
    }

    // ── Plan / Conducta ───────────────────────────────────────────────────────
    final hasP = p.planTerapeutico.isNotEmpty || p.criteriosAlta.isNotEmpty;
    if (hasP) {
      widgets.add(const SizedBox(height: 8));
      widgets.add(_auditSection(
        isEs ? 'Conducta / Plan' : 'Conduta / Plano',
        Icons.assignment_rounded,
        const Color(0xFFA78BFA),
        theme,
      ));
      if (p.planTerapeutico.isNotEmpty) {
        widgets.add(_auditField(
          isEs ? 'Plan' : 'Plano', p.planTerapeutico, theme));
      }
      if (p.criteriosAlta.isNotEmpty) {
        widgets.add(_auditField(
          isEs ? 'Criterios alta' : 'Critérios alta',
          p.criteriosAlta,
          theme,
        ));
      }
    }

    // ── Fármacos ─────────────────────────────────────────────────────────────
    if (ev.farmacos.isNotEmpty) {
      widgets.add(const SizedBox(height: 8));
      widgets.add(_auditSection(
        isEs ? 'Fármacos' : 'Fármacos',
        Icons.medication_rounded,
        const Color(0xFF059669),
        theme,
      ));
      for (final f in ev.farmacos) {
        final dos = f.dosagem.isNotEmpty ? ' — ${f.dosagem}' : '';
        widgets.add(_auditField(f.medicamento, dos.isEmpty ? '—' : f.dosagem, theme));
      }
    }

    // ── Autor ─────────────────────────────────────────────────────────────────
    widgets.add(const SizedBox(height: 12));
    widgets.add(Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ));

    return widgets;
  }

  Widget _auditSection(
    String label,
    IconData icon,
    Color color,
    InternacionTheme theme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 11, color: color),
                const SizedBox(width: 5),
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: color.withValues(alpha: 0.20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _auditField(String label, String value, InternacionTheme theme) {
    return Padding(
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
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: theme.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Divisor de seção com título ───────────────────────────────────────────────
class _SectionDivider extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool dark;
  final InternacionTheme theme;

  const _SectionDivider({
    required this.label, required this.sublabel,
    required this.dark, required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: theme.border, height: 1, thickness: 0.8)),
        const SizedBox(width: 10),
        Column(
          children: [
            Text(label, style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w800,
              letterSpacing: 0.8, color: InternacionTheme(dark).accent,
            )),
            Text(sublabel, style: TextStyle(
              fontSize: 9, color: theme.labelColor,
            )),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: theme.border, height: 1, thickness: 0.8)),
      ],
    );
  }
}
