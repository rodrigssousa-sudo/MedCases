// ─────────────────────────────────────────────────────────────────────────────
// InternacionScreen — Internación y Evolución (Build 159)
//
// Arquitetura:
//   - Estado gerenciado localmente via _InternacionState (sem Provider global)
//   - Sub-widgets em components/ e components/soap/ (Separation of Concerns)
//   - Nenhum arquivo supera 500 linhas (Clean Architecture)
//   - Rebuilds granulares: cada seção SOAP usa seu próprio ChangeNotifier
//
// Pivot from: CockpitScreen (painel de emergência)
// Pivot to:   Gerenciador clínico baseado em SOAP
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import 'models/evolucion_model.dart';
import 'components/resumen_header.dart';
import 'components/historial_section.dart';
import 'components/patient_accordion.dart';
import 'components/internacion_theme.dart';
import 'components/soap/soap_section.dart';

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

  // Accordion interações aberto/fechado
  bool _interaccionesOpen = false;

  @override
  void initState() {
    super.initState();
    _draftEvolucion = _newDraft();
  }

  EvolucionModel _newDraft() => EvolucionModel(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    fecha: DateTime.now(),
    autorNombre: 'Dr.',
  );

  void _onSaveEvolucion(EvolucionModel ev) {
    setState(() {
      _historial = [..._historial, ev];
      _draftEvolucion = _newDraft();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(_isEs ? 'Evolución guardada' : 'Evolução salva'),
        ]),
        backgroundColor: const Color(0xFF22C55E),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    final p    = context.watch<AppProvider>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final lang = p.lang;
    final theme = InternacionTheme(dark);
    final isEs = lang == 'es';

    return Scaffold(
      backgroundColor: theme.surface,
      // ── AppBar ultra-thin premium ──────────────────────────────────────────
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: Container(
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF0F1116) : Colors.white,
            border: Border(
              bottom: BorderSide(color: theme.border, width: 0.8),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // Ícone e título
                  Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: InternacionTheme.cyan.withValues(alpha: dark ? 0.15 : 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.local_hospital_rounded,
                        size: 16, color: InternacionTheme.cyan),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isEs ? 'INTERNACIÓN Y EVOLUCIÓN' : 'INTERNAÇÃO E EVOLUÇÃO',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: theme.textPrimary,
                        ),
                      ),
                      Text(
                        isEs ? 'Modelo SOAP · MedCases Pro' : 'Modelo SOAP · MedCases Pro',
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Badge de evoluções salvas
                  if (_historial.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: InternacionTheme.cyan.withValues(alpha: dark ? 0.15 : 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_historial.length} ${isEs ? 'evoluciones' : 'evoluções'}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: InternacionTheme.cyan,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── 1. RESUMEN CLÍNICO ──────────────────────────────────────────
            ResumenHeader(
              pacienteId:     _paciente.nome,
              cama:           _paciente.cama,
              diagnostico:    _paciente.diagnostico,
              diadeInternacion: _paciente.diaInternacao,
              dark: dark,
              lang: lang,
            ),
            const SizedBox(height: 12),

            // ── 2. HISTORIAL — zero espaço se vazio (sênior pattern) ────────
            HistorialSection(
              evoluciones: _historial,
              dark: dark,
              lang: lang,
            ),
            // Espaçamento CONDICIONAL — só aparece se houver histórico
            if (_historial.isNotEmpty) const SizedBox(height: 12),

            // ── 3. DATOS DEL PACIENTE (colapsável) ─────────────────────────
            PatientAccordion(
              data: _paciente,
              dark: dark,
              lang: lang,
              onChanged: (d) => setState(() => _paciente = d),
            ),
            const SizedBox(height: 10),

            // ── 4. INTERACCIONES DEL PACIENTE (colapsável) ─────────────────
            _InteraccionesAccordion(
              isOpen: _interaccionesOpen,
              dark: dark,
              lang: lang,
              onToggle: () => setState(() =>
                  _interaccionesOpen = !_interaccionesOpen),
              p: p,
            ),
            const SizedBox(height: 16),

            // ── 5. DIVISOR — "Nueva Evolución" ─────────────────────────────
            _SectionDivider(
              label: isEs ? 'NUEVA EVOLUCIÓN MÉDICA' : 'NOVA EVOLUÇÃO MÉDICA',
              sublabel: isEs ? 'Modelo SOAP' : 'Modelo SOAP',
              dark: dark,
              theme: theme,
            ),
            const SizedBox(height: 12),

            // ── 6. MOTOR SOAP ───────────────────────────────────────────────
            SoapSectionWidget(
              key: ValueKey(_draftEvolucion.id),
              evolucion: _draftEvolucion,
              dark: dark,
              lang: lang,
              onSave: _onSaveEvolucion,
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
              letterSpacing: 0.8, color: InternacionTheme.cyan,
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

// ── Interações do Paciente — accordion de segurança farmacológica ─────────────
class _InteraccionesAccordion extends StatelessWidget {
  final bool isOpen;
  final bool dark;
  final String lang;
  final VoidCallback onToggle;
  final AppProvider p;

  const _InteraccionesAccordion({
    required this.isOpen, required this.dark, required this.lang,
    required this.onToggle, required this.p,
  });

  @override
  Widget build(BuildContext context) {
    final theme = InternacionTheme(dark);
    final isEs  = lang == 'es';

    final drugCount = p.selectedDrugs.length;
    final subtitle  = drugCount == 0
        ? (isEs ? 'Sin fármacos registrados' : 'Sem fármacos registrados')
        : '$drugCount ${isEs ? 'fármaco${drugCount > 1 ? 's' : ''} activo${drugCount > 1 ? 's' : ''}' : 'fármaco${drugCount > 1 ? 's' : ''} ativo${drugCount > 1 ? 's' : ''}'}';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOpen
              ? InternacionTheme.amber.withValues(alpha: 0.40)
              : theme.border,
          width: 0.8,
        ),
        boxShadow: [theme.softShadow],
      ),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: InternacionTheme.amber.withValues(alpha: dark ? 0.12 : 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.compare_arrows_rounded,
                        size: 18, color: InternacionTheme.amber),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEs ? 'Interacciones del Paciente' : 'Interações do Paciente',
                          style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: theme.textPrimary,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(fontSize: 11, color: theme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (drugCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: InternacionTheme.amber.withValues(alpha: dark ? 0.15 : 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('$drugCount', style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: InternacionTheme.amber,
                      )),
                    ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        size: 20, color: theme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOut,
            child: isOpen
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(color: theme.divider, height: 1, thickness: 0.8),
                        const SizedBox(height: 12),
                        if (p.selectedDrugs.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                isEs
                                    ? 'Agregar fármacos en la calculadora de dosis'
                                    : 'Adicione fármacos na calculadora de doses',
                                style: TextStyle(
                                  fontSize: 13, color: theme.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        else
                          ...p.selectedDrugs.map((drug) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: dark
                                  ? const Color(0xFF1E2330)
                                  : const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: theme.border, width: 0.8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.medication_rounded,
                                    size: 16, color: InternacionTheme.amber),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    drug.nameL10n(lang),
                                    style: TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w600,
                                      color: theme.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
