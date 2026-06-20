// ─────────────────────────────────────────────────────────────────────────────
// InternacionScreen — Build 165 — Bugs Críticos Classe 1 Corrigidos
//
// FIX 165-A: "Apagão O-A-P" — schema flat no soap_copilot_service.dart
// FIX 165-B: Botão ✕ faz HARD DELETE no SharedPreferences antes de setState
//            (sem isso, o paciente ressuscitava ao salvar nova sessão)
// FIX 165-C: Chave de persistência única — nunca mais colisão 'default'
//            Sessões sem nome+cama recebem timestamp único na chave
// FIX 165-D: FloatingActionButton estendido "Nueva Evolución" proeminente
//            Remove botão miniaturizado do AppBar — FAB impossível de não ver
//
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

  // ── Retoma sessão salva (dia seguinte) ────────────────────────────────────
  void _resumeSession(PacienteSession session) {
    setState(() {
      _paciente = session.nextDayPaciente;
      _historial = session.historial;
      _draftEvolucion = session.nextDayDraft();
      _savedSessions = _savedSessions
          .where((s) => s.sessionKey != session.sessionKey)
          .toList();
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.history_rounded, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(_isEs
              ? 'Día ${session.nextDayPaciente.diaInternacao} — Sesión de ${session.paciente.nome.isNotEmpty ? session.paciente.nome : "Paciente"} cargada'
              : 'Dia ${session.nextDayPaciente.diaInternacao} — Sessão de ${session.paciente.nome.isNotEmpty ? session.paciente.nome : "Paciente"} carregada'),
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
      // ── AppBar premium — sem neon (Build 162) ────────────────────────────
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
                  // ── Build 162: Botão VOLTAR explícito ───────────────────
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
                        '${_historial.length} ${isEs ? 'evoluciones' : 'evoluções'}',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: theme.accent,
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),

                  // FIX 165-D: Botão "Nueva Evolución" REMOVIDO do AppBar
                  // → Substituído por FAB estendido (ver floatingActionButton abaixo)
                ],
              ),
            ),
          ),
        ),
      ),

      // ── FIX 165-D: FAB estendido "Nueva Evolución" — impossível não ver ──────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _confirmAndReset,
        backgroundColor: InternacionTheme.accentLight,
        foregroundColor: Colors.white,
        elevation: 6,
        icon: const Icon(Icons.cleaning_services_rounded, size: 20),
        label: Text(
          isEs ? 'Nueva Evolución' : 'Nova Evolução',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13.5,
            letterSpacing: 0.3,
          ),
        ),
        tooltip: isEs
            ? 'Limpiar pizarrón e iniciar nueva evolución'
            : 'Limpar pizarrão e iniciar nova evolução',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
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

            // ── 3. HISTORIAL — zero espaço se vazio ─────────────────────────
            HistorialSection(
              evoluciones: _historial,
              dark: dark,
              lang: lang,
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
    final dia  = isEs
        ? 'Día ${p.diaInternacao}→${session.nextDayPaciente.diaInternacao}'
        : 'Dia ${p.diaInternacao}→${session.nextDayPaciente.diaInternacao}';
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
