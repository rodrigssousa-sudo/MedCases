// ─────────────────────────────────────────────────────────────────────────────
// SoapSection — orquestrador da evolução SOAP completa.
// Renderiza os 4 blocos S/O/A/P como AccordionCards colapsáveis e independentes.
// Estado local via SoapNotifier — ZERO rebuild da árvore pai.
//
// Build 160: applyAiDraft, _draftVersion, _CopyButton
// Build 161: State Bleed fix — problemasActivos LIMPA antes de injetar draft IA
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/evolucion_model.dart';
import '../internacion_theme.dart';
import '../../services/soap_copilot_service.dart';
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

  // ── Build 160: Injeta draft da IA no modelo ─────────────────────────────
  // Chamado somente após aprovação explícita no RevisionSheet.
  // Campos nulos no draft NÃO sobrescrevem o que já foi digitado.
  void applyAiDraft(SoapDraftResult draft) {
    final s = _evolucion.subjetivo;
    final o = _evolucion.objetivo;
    final a = _evolucion.evaluacion;
    final p = _evolucion.plan;

    // S — usa draft se não-nulo, mantém existente se já preenchido
    final newSubjetivo = s.copyWith(
      notePasaNoche: draft.notePasaNoche?.isNotEmpty == true
          ? draft.notePasaNoche : (s.notePasaNoche.isEmpty ? '' : s.notePasaNoche),
      dolorEscala: draft.dolorEscala ?? s.dolorEscala,
      fiebre: draft.fiebre ?? s.fiebre,
      disnea: draft.disnea ?? s.disnea,
      nauseas: draft.nauseas ?? s.nauseas,
      tos: draft.tos ?? s.tos,
      alimentacion: _mapAiAlimentacion(draft.alimentacion) ?? s.alimentacion,
      diuresis: _mapAiDiuresis(draft.diuresis) ?? s.diuresis,
      evacuacion: _mapAiEvacuacion(draft.evacuacion) ?? s.evacuacion,
      suenoRestado: draft.suenoRestado ?? s.suenoRestado,
      notasLibres: draft.notasLibresSubjetivo?.isNotEmpty == true
          ? draft.notasLibresSubjetivo : (s.notasLibres.isEmpty ? '' : s.notasLibres),
    );

    // O — Signos vitales
    final sv = o.signosVitales;
    final newSv = sv.copyWith(
      pa: draft.pa?.isNotEmpty == true ? draft.pa : (sv.pa.isEmpty ? '' : sv.pa),
      fc: draft.fc?.isNotEmpty == true ? draft.fc : (sv.fc.isEmpty ? '' : sv.fc),
      fr: draft.fr?.isNotEmpty == true ? draft.fr : (sv.fr.isEmpty ? '' : sv.fr),
      satO2: draft.satO2?.isNotEmpty == true ? draft.satO2 : (sv.satO2.isEmpty ? '' : sv.satO2),
      temperatura: draft.temperatura?.isNotEmpty == true
          ? draft.temperatura : (sv.temperatura.isEmpty ? '' : sv.temperatura),
    );

    // O — Examen físico
    final ef = o.examenFisico;
    final newEf = ef.copyWith(
      estadoGeneral: draft.estadoGeneral?.isNotEmpty == true
          ? draft.estadoGeneral : (ef.estadoGeneral.isEmpty ? '' : ef.estadoGeneral),
      acv: draft.acv?.isNotEmpty == true ? draft.acv : (ef.acv.isEmpty ? '' : ef.acv),
      ar: draft.ar?.isNotEmpty == true ? draft.ar : (ef.ar.isEmpty ? '' : ef.ar),
      abdomen: draft.abdomen?.isNotEmpty == true
          ? draft.abdomen : (ef.abdomen.isEmpty ? '' : ef.abdomen),
      extremidades: draft.extremidades?.isNotEmpty == true
          ? draft.extremidades : (ef.extremidades.isEmpty ? '' : ef.extremidades),
    );

    // O — Exámenes complementarios
    final ex = o.examenes;
    final newEx = ex.copyWith(
      laboratorio: draft.laboratorio?.isNotEmpty == true
          ? draft.laboratorio : (ex.laboratorio.isEmpty ? '' : ex.laboratorio),
      imagenes: draft.imagenes?.isNotEmpty == true
          ? draft.imagenes : (ex.imagenes.isEmpty ? '' : ex.imagenes),
      culturas: draft.culturas?.isNotEmpty == true
          ? draft.culturas : (ex.culturas.isEmpty ? '' : ex.culturas),
      ecg: draft.ecg?.isNotEmpty == true ? draft.ecg : (ex.ecg.isEmpty ? '' : ex.ecg),
    );

    final newObjetivo = o.copyWith(
      signosVitales: newSv,
      examenFisico: newEf,
      examenes: newEx,
      tratamientoActual: draft.tratamientoActual?.isNotEmpty == true
          ? draft.tratamientoActual : (o.tratamientoActual.isEmpty ? '' : o.tratamientoActual),
    );

    // A — Evaluación
    EstadoClinical? newEstado = a.estado;
    if (draft.estadoClinical?.isNotEmpty == true) {
      for (final e in EstadoClinical.values) {
        if (e.name == draft.estadoClinical!.toLowerCase()) {
          newEstado = e;
          break;
        }
      }
    }

    // ── BUILD 161: ANTI-STATE-BLEED ────────────────────────────────────
    // A lista de problemas é COMPLETAMENTE SUBSTITUÍDA pelo draft da IA.
    // Nunca fazemos merge: isso eliminaria diagnósticos de pacientes
    // anteriores que pudessem ter persistido erroneamente na sessão.
    // Se a IA não trouxer problemas, mantemos apenas os que o médico
    // já digitou manualmente (preservados em a.problemasActivos).
    List<String> newProblemas;
    if (draft.problemasActivos != null) {
      // IA forneceu lista → SUBSTITUI completamente (zero bleed)
      newProblemas = List<String>.from(draft.problemasActivos!);
    } else {
      // IA não forneceu → preserva o que o médico digitou
      newProblemas = List<String>.from(a.problemasActivos);
    }

    final newEvaluacion = a.copyWith(
      estado: newEstado,
      problemasActivos: newProblemas,
      notasEvaluacion: draft.notasEvaluacion?.isNotEmpty == true
          ? draft.notasEvaluacion : (a.notasEvaluacion.isEmpty ? '' : a.notasEvaluacion),
    );

    // P — Plan
    final newPlan = p.copyWith(
      planTerapeutico: draft.planTerapeutico?.isNotEmpty == true
          ? draft.planTerapeutico : (p.planTerapeutico.isEmpty ? '' : p.planTerapeutico),
      criteriosAlta: draft.criteriosAlta?.isNotEmpty == true
          ? draft.criteriosAlta : (p.criteriosAlta.isEmpty ? '' : p.criteriosAlta),
    );

    _evolucion = _evolucion.copyWith(
      subjetivo: newSubjetivo,
      objetivo: newObjetivo,
      evaluacion: newEvaluacion,
      plan: newPlan,
    );

    notifyListeners();
  }

  // ── Mapeadores: IA usa "Bien/Boa" → modelo usa "Bien/Boa" conforme idioma ─
  String? _mapAiAlimentacion(String? v) {
    if (v == null || v.isEmpty) return null;
    final lower = v.toLowerCase();
    if (lower.contains('bien') || lower.contains('boa') || lower.contains('buen')) return v;
    if (lower.contains('mal') || lower.contains('ruim')) return v;
    if (lower.contains('regular')) return v;
    return v; // passa como está
  }

  String? _mapAiDiuresis(String? v) {
    if (v == null || v.isEmpty) return null;
    return v;
  }

  String? _mapAiEvacuacion(String? v) {
    if (v == null || v.isEmpty) return null;
    return v;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SoapSectionWidget — orquestra os 4 acordeões SOAP
// ═════════════════════════════════════════════════════════════════════════════
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
  State<SoapSectionWidget> createState() => SoapSectionWidgetState();
}

class SoapSectionWidgetState extends State<SoapSectionWidget> {
  late final SoapNotifier _notifier;
  // Qual accordion está aberto: 0=S 1=O 2=A 3=P null=nenhum
  int? _openIdx = 0;

  // Build 160: versão do draft — incrementada ao aplicar IA para forçar
  // reconstrução dos sub-widgets (e portanto seus TextEditingControllers)
  int _draftVersion = 0;

  @override
  void initState() {
    super.initState();
    _notifier = SoapNotifier(widget.evolucion);
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

  // ── Build 160: chamado pelo InternacionScreen após aprovação do RevisionSheet
  void applyAiDraft(SoapDraftResult draft) {
    _notifier.applyAiDraft(draft);
    setState(() {
      _draftVersion++;
      _openIdx = 0; // abre S para o médico verificar
    });
  }

  @override
  Widget build(BuildContext context) {
    final ev = _notifier.evolucion;
    final dark = widget.dark;
    final theme = InternacionTheme(dark);

    final sections = [
      _SoapAccordion(
        key: ValueKey('s_$_draftVersion'),
        section: SoapSection.s,
        isOpen: _openIdx == 0,
        dark: dark,
        lang: widget.lang,
        theme: theme,
        onToggle: () => setState(() => _openIdx = _openIdx == 0 ? null : 0),
        child: SoapSubjetivo(
          key: ValueKey('subj_$_draftVersion'),
          data: ev.subjetivo,
          onChanged: _notifier.updateSubjetivo,
          dark: dark,
          lang: widget.lang,
        ),
      ),
      _SoapAccordion(
        key: ValueKey('o_$_draftVersion'),
        section: SoapSection.o,
        isOpen: _openIdx == 1,
        dark: dark,
        lang: widget.lang,
        theme: theme,
        onToggle: () => setState(() => _openIdx = _openIdx == 1 ? null : 1),
        child: SoapObjetivo(
          key: ValueKey('obj_$_draftVersion'),
          data: ev.objetivo,
          onChanged: _notifier.updateObjetivo,
          dark: dark,
          lang: widget.lang,
        ),
      ),
      _SoapAccordion(
        key: ValueKey('a_$_draftVersion'),
        section: SoapSection.a,
        isOpen: _openIdx == 2,
        dark: dark,
        lang: widget.lang,
        theme: theme,
        onToggle: () => setState(() => _openIdx = _openIdx == 2 ? null : 2),
        child: SoapEvaluacion(
          key: ValueKey('eval_$_draftVersion'),
          data: ev.evaluacion,
          onChanged: _notifier.updateEvaluacion,
          dark: dark,
          lang: widget.lang,
        ),
      ),
      _SoapAccordion(
        key: ValueKey('p_$_draftVersion'),
        section: SoapSection.p,
        isOpen: _openIdx == 3,
        dark: dark,
        lang: widget.lang,
        theme: theme,
        onToggle: () => setState(() => _openIdx = _openIdx == 3 ? null : 3),
        child: SoapPlan(
          key: ValueKey('plan_$_draftVersion'),
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

        // ── Botão Copiar Evolución Completa ───────────────────────────────────
        const SizedBox(height: 4),
        _CopyButton(
          dark: dark,
          lang: widget.lang,
          getEvolucion: () => _notifier.evolucion,
        ),
        const SizedBox(height: 8),

        // ── Botão salvar evolução ─────────────────────────────────────────────
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
    super.key,
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

// ── Build 160: Botão Copiar Evolución Completa ────────────────────────────────
class _CopyButton extends StatefulWidget {
  final bool dark;
  final String lang;
  final EvolucionModel Function() getEvolucion;

  const _CopyButton({
    required this.dark,
    required this.lang,
    required this.getEvolucion,
  });

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  bool get isEs => widget.lang == 'es';

  Future<void> _copy() async {
    final ev = widget.getEvolucion();
    final text = _compileSoapText(ev, isEs);

    await Clipboard.setData(ClipboardData(text: text));

    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.copy_rounded, color: Colors.white, size: 15),
          const SizedBox(width: 8),
          Text(isEs
              ? 'Evolución copiada al portapapeles'
              : 'Evolução copiada para a área de transferência'),
        ]),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  /// Compila todos os campos SOAP em texto formatado para clipboard
  static String _compileSoapText(EvolucionModel ev, bool isEs) {
    final buf = StringBuffer();
    final sep = '─' * 40;

    buf.writeln(isEs
        ? '📋 EVOLUCIÓN MÉDICA · ${ev.fechaFormatada}'
        : '📋 EVOLUÇÃO MÉDICA · ${ev.fechaFormatada}');
    buf.writeln(isEs ? 'Responsable: ${ev.autorNombre}' : 'Responsável: ${ev.autorNombre}');
    buf.writeln(sep);

    // S
    buf.writeln(isEs
        ? '\n🔵 S — SUBJETIVO'
        : '\n🔵 S — SUBJETIVO');
    final s = ev.subjetivo;
    if (s.notePasaNoche.isNotEmpty)
      buf.writeln(isEs ? '• Noche: ${s.notePasaNoche}' : '• Noite: ${s.notePasaNoche}');
    if (s.dolorEscala != null)
      buf.writeln('• EVA: ${s.dolorEscala}/10');

    final syms = <String>[];
    if (s.fiebre) syms.add(isEs ? 'Fiebre' : 'Febre');
    if (s.disnea) syms.add(isEs ? 'Disnea' : 'Dispneia');
    if (s.nauseas) syms.add(isEs ? 'Náuseas' : 'Náuseas');
    if (s.tos) syms.add(isEs ? 'Tos' : 'Tosse');
    if (s.suenoRestado) syms.add(isEs ? 'Sueño alterado' : 'Sono alterado');
    if (syms.isNotEmpty)
      buf.writeln(isEs ? '• Síntomas: ${syms.join(', ')}' : '• Sintomas: ${syms.join(', ')}');

    if (s.alimentacion.isNotEmpty)
      buf.writeln(isEs ? '• Alimentación: ${s.alimentacion}' : '• Alimentação: ${s.alimentacion}');
    if (s.diuresis.isNotEmpty) buf.writeln('• Diuresis: ${s.diuresis}');
    if (s.evacuacion.isNotEmpty)
      buf.writeln(isEs ? '• Evacuación: ${s.evacuacion}' : '• Evacuação: ${s.evacuacion}');
    if (s.notasLibres.isNotEmpty)
      buf.writeln(isEs ? '• Notas: ${s.notasLibres}' : '• Notas: ${s.notasLibres}');

    // O
    buf.writeln(isEs ? '\n🟢 O — OBJETIVO' : '\n🟢 O — OBJETIVO');
    final sv = ev.objetivo.signosVitales;
    if (!sv.isEmpty) {
      buf.write(isEs ? '• Signos vitales: ' : '• Sinais vitais: ');
      final parts = <String>[];
      if (sv.pa.isNotEmpty) parts.add('PA: ${sv.pa}');
      if (sv.fc.isNotEmpty) parts.add('FC: ${sv.fc}');
      if (sv.fr.isNotEmpty) parts.add('FR: ${sv.fr}');
      if (sv.satO2.isNotEmpty) parts.add('SpO₂: ${sv.satO2}');
      if (sv.temperatura.isNotEmpty) parts.add('T°: ${sv.temperatura}');
      buf.writeln(parts.join(' | '));
    }

    final ef = ev.objetivo.examenFisico;
    if (ef.estadoGeneral.isNotEmpty)
      buf.writeln(isEs ? '• Estado general: ${ef.estadoGeneral}' : '• Estado geral: ${ef.estadoGeneral}');
    if (ef.acv.isNotEmpty) buf.writeln('• ACV: ${ef.acv}');
    if (ef.ar.isNotEmpty) buf.writeln('• AR: ${ef.ar}');
    if (ef.abdomen.isNotEmpty) buf.writeln(isEs ? '• Abdomen: ${ef.abdomen}' : '• Abdome: ${ef.abdomen}');
    if (ef.extremidades.isNotEmpty) buf.writeln('• MMII: ${ef.extremidades}');

    final ex = ev.objetivo.examenes;
    if (ex.laboratorio.isNotEmpty)
      buf.writeln(isEs ? '• Laboratorio: ${ex.laboratorio}' : '• Laboratório: ${ex.laboratorio}');
    if (ex.imagenes.isNotEmpty)
      buf.writeln(isEs ? '• Imágenes: ${ex.imagenes}' : '• Imagens: ${ex.imagenes}');
    if (ex.culturas.isNotEmpty) buf.writeln('• Culturas: ${ex.culturas}');
    if (ex.ecg.isNotEmpty) buf.writeln('• ECG: ${ex.ecg}');
    if (ev.objetivo.tratamientoActual.isNotEmpty)
      buf.writeln(isEs ? '• Tratamiento: ${ev.objetivo.tratamientoActual}' : '• Tratamento: ${ev.objetivo.tratamientoActual}');

    // A
    buf.writeln(isEs ? '\n🟡 A — EVALUACIÓN' : '\n🟡 A — AVALIAÇÃO');
    final a = ev.evaluacion;
    if (a.estado != null) buf.writeln('• Estado: ${a.estado!.label(isEs ? 'es' : 'pt')}');
    if (a.problemasActivos.isNotEmpty)
      buf.writeln(isEs
          ? '• Problemas activos:\n  - ${a.problemasActivos.join('\n  - ')}'
          : '• Problemas ativos:\n  - ${a.problemasActivos.join('\n  - ')}');
    if (a.notasEvaluacion.isNotEmpty) buf.writeln('• ${a.notasEvaluacion}');

    // P
    buf.writeln('\n🟣 P — PLAN');
    final p = ev.plan;
    if (p.planTerapeutico.isNotEmpty)
      buf.writeln(isEs ? '• Plan terapéutico:\n${p.planTerapeutico}' : '• Plano terapêutico:\n${p.planTerapeutico}');
    if (p.criteriosAlta.isNotEmpty)
      buf.writeln(isEs ? '• Criterios de alta:\n${p.criteriosAlta}' : '• Critérios de alta:\n${p.criteriosAlta}');

    buf.writeln('\n$sep');
    buf.writeln('MedCases Pro · Generado ${DateTime.now().toIso8601String().substring(0, 16)}');

    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;

    return GestureDetector(
      onTap: _copy,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _copied
              ? InternacionTheme.green.withValues(alpha: dark ? 0.15 : 0.10)
              : (dark ? const Color(0xFF1A1E28) : const Color(0xFFF0F2F5)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _copied
                ? InternacionTheme.green.withValues(alpha: 0.50)
                : (dark ? const Color(0xFF2D3340) : const Color(0xFFDDE1E6)),
            width: 0.9,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _copied
                    ? Icons.check_circle_rounded
                    : Icons.copy_rounded,
                key: ValueKey(_copied),
                size: 16,
                color: _copied
                    ? InternacionTheme.green
                    : (dark ? Colors.white54 : Colors.black45),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _copied
                  ? (isEs ? '¡Copiado!' : 'Copiado!')
                  : (isEs ? 'Copiar Evolución Completa' : 'Copiar Evolução Completa'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _copied
                    ? InternacionTheme.green
                    : (dark ? Colors.white54 : Colors.black45),
              ),
            ),
          ],
        ),
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
