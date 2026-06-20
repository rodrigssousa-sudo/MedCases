// ─────────────────────────────────────────────────────────────────────────────
// SoapSection — orquestrador da evolução SOAP completa.
// Renderiza os 4 blocos S/O/A/P como AccordionCards colapsáveis e independentes.
// Estado local via InternacionNotifier — ZERO rebuild da árvore pai.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../../models/evolucion_model.dart';
import '../internacion_theme.dart';
import 'soap_subjetivo.dart';
import 'soap_objetivo.dart';
import 'soap_evaluacion.dart';
import 'soap_plan.dart';

// ── State notifier local — isola rebuilds do SOAP da tela pai ────────────────
class SoapNotifier extends ChangeNotifier {
  EvolucionModel _evolucion;

  SoapNotifier(this._evolucion);

  EvolucionModel get evolucion => _evolucion;

  void updateSubjetivo(SubjetivoData d) {
    _evolucion = _evolucion.copyWith(subjetivo: d);
    notifyListeners();
  }

  void updateObjetivo(ObjetivoData d) {
    _evolucion = _evolucion.copyWith(objetivo: d);
    notifyListeners();
  }

  void updateEvaluacion(EvaluacionData d) {
    _evolucion = _evolucion.copyWith(evaluacion: d);
    notifyListeners();
  }

  void updatePlan(PlanData d) {
    _evolucion = _evolucion.copyWith(plan: d);
    notifyListeners();
  }
}

class SoapSectionWidget extends StatefulWidget {
  final EvolucionModel evolucion;
  final bool dark;
  final String lang;
  /// Callback chamado quando o médico confirma o save da evolução
  final ValueChanged<EvolucionModel> onSave;

  const SoapSectionWidget({
    super.key,
    required this.evolucion,
    required this.dark,
    required this.lang,
    required this.onSave,
  });

  @override
  State<SoapSectionWidget> createState() => _SoapSectionWidgetState();
}

class _SoapSectionWidgetState extends State<SoapSectionWidget> {
  late final SoapNotifier _notifier;
  // Qual accordion está aberto: 0=S 1=O 2=A 3=P null=nenhum
  int? _openIdx = 0;

  @override
  void initState() {
    super.initState();
    _notifier = SoapNotifier(widget.evolucion);
    // Rebuild local apenas quando o notifier muda
    _notifier.addListener(_onNotifierChanged);
  }

  void _onNotifierChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _notifier.removeListener(_onNotifierChanged);
    _notifier.dispose();
    super.dispose();
  }

  bool get isEs => widget.lang == 'es';

  @override
  Widget build(BuildContext context) {
    final ev = _notifier.evolucion;
    final dark = widget.dark;
    final theme = InternacionTheme(dark);

    final sections = [
      _SoapAccordion(
        section: SoapSection.s,
        isOpen: _openIdx == 0,
        dark: dark,
        lang: widget.lang,
        theme: theme,
        onToggle: () => setState(() => _openIdx = _openIdx == 0 ? null : 0),
        child: SoapSubjetivo(
          data: ev.subjetivo,
          onChanged: _notifier.updateSubjetivo,
          dark: dark,
          lang: widget.lang,
        ),
      ),
      _SoapAccordion(
        section: SoapSection.o,
        isOpen: _openIdx == 1,
        dark: dark,
        lang: widget.lang,
        theme: theme,
        onToggle: () => setState(() => _openIdx = _openIdx == 1 ? null : 1),
        child: SoapObjetivo(
          data: ev.objetivo,
          onChanged: _notifier.updateObjetivo,
          dark: dark,
          lang: widget.lang,
        ),
      ),
      _SoapAccordion(
        section: SoapSection.a,
        isOpen: _openIdx == 2,
        dark: dark,
        lang: widget.lang,
        theme: theme,
        onToggle: () => setState(() => _openIdx = _openIdx == 2 ? null : 2),
        child: SoapEvaluacion(
          data: ev.evaluacion,
          onChanged: _notifier.updateEvaluacion,
          dark: dark,
          lang: widget.lang,
        ),
      ),
      _SoapAccordion(
        section: SoapSection.p,
        isOpen: _openIdx == 3,
        dark: dark,
        lang: widget.lang,
        theme: theme,
        onToggle: () => setState(() => _openIdx = _openIdx == 3 ? null : 3),
        child: SoapPlan(
          data: ev.plan,
          onChanged: _notifier.updatePlan,
          dark: dark,
          lang: widget.lang,
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Progress bar dos 4 blocos SOAP ──────────────────────────────────
        _SoapProgressBar(openIdx: _openIdx, dark: dark),
        const SizedBox(height: 12),

        // ── Accordions ───────────────────────────────────────────────────────
        ...sections.map((s) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: s,
        )),

        // ── Botão salvar evolução ─────────────────────────────────────────────
        const SizedBox(height: 4),
        _SaveButton(
          dark: dark,
          lang: widget.lang,
          onSave: () => widget.onSave(_notifier.evolucion),
        ),
      ],
    );
  }
}

// ── Progress bar 4 etapas ─────────────────────────────────────────────────────
class _SoapProgressBar extends StatelessWidget {
  final int? openIdx;
  final bool dark;

  const _SoapProgressBar({required this.openIdx, required this.dark});

  @override
  Widget build(BuildContext context) {
    final sections = [SoapSection.s, SoapSection.o, SoapSection.a, SoapSection.p];
    return Row(
      children: sections.asMap().entries.map((e) {
        final isActive = openIdx == e.key;
        final color = InternacionTheme(dark).soapTagFg(e.value);
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: EdgeInsets.only(right: e.key < 3 ? 4 : 0),
            height: 3,
            decoration: BoxDecoration(
              color: isActive
                  ? color
                  : color.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Accordion card individual ─────────────────────────────────────────────────
class _SoapAccordion extends StatelessWidget {
  final SoapSection section;
  final bool isOpen;
  final bool dark;
  final String lang;
  final InternacionTheme theme;
  final VoidCallback onToggle;
  final Widget child;

  const _SoapAccordion({
    required this.section, required this.isOpen, required this.dark,
    required this.lang, required this.theme, required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final tagFg = theme.soapTagFg(section);
    final tagBg = theme.soapTagBg(section);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOpen ? tagFg.withValues(alpha: 0.40) : theme.border,
          width: isOpen ? 1.2 : 0.8,
        ),
        boxShadow: [theme.softShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Header do accordion ──────────────────────────────────────────
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Tag SOAP colorida
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: tagBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(section.tag, style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800,
                        color: tagFg,
                      )),
                    ),
                  ),
                  const SizedBox(width: 10),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(section.title(lang), style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: theme.textPrimary,
                        )),
                        Text(section.subtitle(lang), style: TextStyle(
                          fontSize: 11, color: theme.textSecondary,
                          height: 1.3,
                        )),
                      ],
                    ),
                  ),

                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20, color: theme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Conteúdo colapsável ───────────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            child: isOpen
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(color: theme.divider, height: 1, thickness: 0.8),
                        const SizedBox(height: 12),
                        child,
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

// ── Botão Salvar Evolução ─────────────────────────────────────────────────────
class _SaveButton extends StatelessWidget {
  final bool dark;
  final String lang;
  final VoidCallback onSave;

  const _SaveButton({required this.dark, required this.lang, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final isEs = lang == 'es';
    return GestureDetector(
      onTap: onSave,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF008CA4), Color(0xFF005566)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.save_alt_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              isEs ? 'Guardar Evolución' : 'Salvar Evolução',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
