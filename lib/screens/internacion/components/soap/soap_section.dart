// ─────────────────────────────────────────────────────────────────────────────
// SoapSection — orquestrador da evolução SOAP completa.
// Renderiza os 4 blocos S/O/A/P como AccordionCards colapsáveis e independentes.
// Estado local via SoapNotifier — ZERO rebuild da árvore pai.
//
// Build 160: applyAiDraft, _draftVersion, _CopyButton
// Build 161: State Bleed fix — problemasActivos LIMPA antes de injetar draft IA
// Build 162: farmacos injetados via applyAiDraft; autorNombre dinâmico no CopyButton
// Build 163: resetAll() no SoapNotifier + resetSoap() no SoapSectionWidgetState (Clean Slate)
// Build 167: _CopyMenuButton (ModalBottomSheet duplo), formatação hospitalar argentina,
//            PacienteInternacaoData threading, TextEditingControllers com cursor ao final
// Build 176-R: _CopyMenuButton + _SaveButton removidos do Column interno;
//              showCopyMenu(ctx) exposto no state → acionado via botão compacto externo.
//              SOAP reorganizado em grid 2×2 pelo pai (internacion_screen.dart).
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/evolucion_model.dart';
import '../internacion_theme.dart';
import '../patient_accordion.dart';
import '../../services/soap_copilot_service.dart';
// FarmacoEntry usado no applyAiDraft (Build 162)
// ignore: unused_import (re-exportado via evolucion_model)
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

  void updateFarmacos(List<FarmacoEntry> farmacos) {
    _evolucion = _evolucion.copyWith(farmacos: farmacos);
    notifyListeners();
  }

  // ── Build 163: Protocolo Clean Slate ─────────────────────────────────────
  // Recebe o novo EvolucionModel vazio e reinicia TUDO:
  //   S, O, A, P → valores default; farmacos → []; problemasActivos → []
  // O incremento de _draftVersion no SoapSectionWidgetState garante que
  // todos os TextEditingControllers são reconstruídos com strings vazias.
  void resetAll(EvolucionModel freshDraft) {
    _evolucion = freshDraft;
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

    // Fármacos (Build 162) — substitui completamente se IA forneceu dados
    List<FarmacoEntry> newFarmacos;
    if (draft.farmacos != null && draft.farmacos!.isNotEmpty) {
      newFarmacos = draft.farmacos!
          .map((m) => FarmacoEntry(
                medicamento: m['medicamento'] ?? '',
                dosagem:     m['dosis']       ?? '',
              ))
          .where((f) => f.medicamento.isNotEmpty)
          .toList();
    } else {
      newFarmacos = List<FarmacoEntry>.from(_evolucion.farmacos);
    }

    _evolucion = _evolucion.copyWith(
      subjetivo: newSubjetivo,
      objetivo: newObjetivo,
      evaluacion: newEvaluacion,
      plan: newPlan,
      farmacos: newFarmacos,
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
  /// Nome do médico logado — preenche o cabeçalho do texto copiado (Build 162)
  final String autorNombre;
  /// Dados demográficos do paciente — necessário para "Copiar Todo" (Build 167)
  final PacienteInternacaoData? paciente;
  /// Callback chamado quando o médico confirma o save da evolução
  final ValueChanged<EvolucionModel> onSave;

  const SoapSectionWidget({
    super.key,
    required this.evolucion,
    required this.dark,
    required this.lang,
    required this.onSave,
    this.autorNombre = 'Dr.',
    this.paciente,
  });

  @override
  State<SoapSectionWidget> createState() => SoapSectionWidgetState();
}

class SoapSectionWidgetState extends State<SoapSectionWidget> {
  late final SoapNotifier _notifier;
  // R2: Todos os accordions iniciam FECHADOS — interface 100% limpa ao carregar.
  // null = nenhum aberto. O médico abre o que precisa.
  int? _openIdx;

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

  // ── Build 163: Protocolo Clean Slate ─────────────────────────────────────
  // Recebe um EvolucionModel completamente novo (todos os campos default/vazios).
  // Incrementa _draftVersion → força ValueKey a mudar → todos os sub-widgets
  // (SoapSubjetivo, SoapObjetivo, etc.) reconstruídos com controllers zerados.
  // _openIdx = 0 → painel S fica aberto para nova entrada imediata.
  void resetSoap(EvolucionModel freshDraft) {
    _notifier.resetAll(freshDraft);
    setState(() {
      _draftVersion++;
      _openIdx = 0;
    });
  }

  // ── Build 181: Abre o ModalBottomSheet Tri-Modelo — chamado pela Action Bar ──
  void showCopyMenu(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => _CopyOptionsSheet(
        dark: widget.dark,
        lang: widget.lang,
        onCopyFull: () {
          Navigator.of(sheetCtx).pop();
          _executeCopy(_CopyModel.completa);
        },
        onCopyResumida: () {
          Navigator.of(sheetCtx).pop();
          _executeCopy(_CopyModel.resumida);
        },
        onCopyPasaje: () {
          Navigator.of(sheetCtx).pop();
          _executeCopy(_CopyModel.pasaje);
        },
      ),
    );
  }

  // ── Motor de cópia unificado — Build 193 (Refatorado) ───────────────────
  Future<void> _executeCopy(_CopyModel model) async {
    final ev   = _notifier.evolucion;
    final isEs = widget.lang == 'es';
    final String text;
    final String snackLabel;

    switch (model) {
      case _CopyModel.completa:
        text      = _toCompletoString(ev, isEs, widget.autorNombre, widget.paciente);
        snackLabel = isEs
            ? '📋 Prontuario completo copiado al portapapeles'
            : '📋 Prontuário completo copiado para a área de transferência';
      case _CopyModel.resumida:
        text      = _toResumidoString(ev, isEs, widget.autorNombre, widget.paciente);
        snackLabel = isEs
            ? '⚡ Resumen ejecutivo copiado al portapapeles'
            : '⚡ Resumo executivo copiado para a área de transferência';
      case _CopyModel.pasaje:
        text      = _toPassagemString(ev, isEs, widget.paciente);
        snackLabel = isEs
            ? '🔄 Pasaje de guardia copiado al portapapeles'
            : '🔄 Passagem de plantão copiada para a área de transferência';
    }

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.copy_rounded, color: Colors.white, size: 15),
        const SizedBox(width: 8),
        Expanded(child: Text(snackLabel)),
      ]),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
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

    // Build 176-R: O SoapSectionWidget expõe APENAS os 4 accordions + progress bar.
    // Os botões [Copiar] e [Salvar] foram movidos para a Action Bar (25/50/25)
    // do pai (internacion_screen.dart). O médico usa a barra unificada inferior.
    // Os accordions S e O ficam em Row (left), A e P em Row (right) — grid 2×2
    // gerenciado pelo pai usando as `sections` lista exposta via _buildAccordions().
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Progress bar dos 4 blocos SOAP ──────────────────────────────────
        _SoapProgressBar(openIdx: _openIdx, dark: dark),
        const SizedBox(height: 12),

        // ── Build 180: Vertical Stack 100% — cada bloco SOAP ocupa 100% da largura ──
        // Grade 2×2 (IntrinsicHeight + Row) removida — subcomponentes largos
        // (escalas de dor, chips, seletores) não cabem em meia coluna mobile.
        sections[0], // [S] Subjetivo — 100% largura
        const SizedBox(height: 8),
        sections[1], // [O] Objetivo  — 100% largura
        const SizedBox(height: 8),
        sections[2], // [A] Avaliação — 100% largura
        const SizedBox(height: 8),
        sections[3], // [P] Plano     — 100% largura
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


// ── Enum de modelo de cópia ──────────────────────────────────────────────────
enum _CopyModel { completa, resumida, pasaje }

// ── Helpers de data/hora ─────────────────────────────────────────────────────
String _fmtFecha() {
  final now = DateTime.now();
  return '${now.day.toString().padLeft(2,'0')}/${now.month.toString().padLeft(2,'0')}/${now.year}';
}
String _fmtHora() {
  final now = DateTime.now();
  return '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}';
}

// ═══════════════════════════════════════════════════════════════════════════
// Build 193 — Motor Tri-Modelo de Exportação (Refatoração Completa)
// Substitui _compileFullSoapRecord / _compileResumidaInline / _compilePasajeGuardia
// por três métodos isolados e conceitualmente distintos:
//   _toCompletoString()  → SOAP Tradicional Expandida (espelho vertical completo)
//   _toResumidoString()  → Painel Clínico Compacto (1 linha por bloco)
//   _toPassagemString()  → Passagem de Plantão (ação/alerta, sem histórico longo)
//
// Regra de Ouro: _splitNumberedList() quebra "1. Foo 2. Bar" → ["Foo","Bar"]
//               _toBullets() converte qualquer bloco de texto em linhas "• …"
// ═══════════════════════════════════════════════════════════════════════════

// ── Utilitário: quebra strings com listas numeradas emendadas ────────────────
// Exemplos de entrada:
//   "1. Paracetamol 500mg 2. Omeprazol 20mg 3. Heparina SC"
//   "1. Controle glicêmico\n2. ECG de controle"
// Saída: ["Paracetamol 500mg", "Omeprazol 20mg", "Heparina SC"]
List<String> _splitNumberedList(String text) {
  if (text.trim().isEmpty) return [];
  // Captura padrões "1. ", "2. ", "1) ", "2) " em qualquer posição do texto
  final parts = text
      .split(RegExp(r'\d+[\.\)]\s+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  // Se não havia numeração, retorna o texto original como único item
  return parts.isEmpty ? [text.trim()] : parts;
}

// ── Utilitário: converte qualquer bloco de texto em linhas "• …" ─────────────
// Estratégia:
//   1. Tenta quebrar por lista numerada emendada ("1. Foo 2. Bar")
//   2. Depois quebra por "\n" para capturar listas já verticais
//   3. Strips de prefixos "- ", "• ", "* " existentes antes de recolocar "• "
String _toBullets(String text) {
  if (text.trim().isEmpty) return '';
  final buf = StringBuffer();
  // Primeiro expande listas numeradas inline se detectadas
  final hasInlineList = RegExp(r'\d+[\.\)]\s+').hasMatch(text);
  final lines = hasInlineList
      ? _splitNumberedList(text)
      : text
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
  for (final line in lines) {
    // Remove prefixos já existentes antes de normalizar
    final clean = line.replaceFirst(RegExp(r'^[-•*]\s*'), '').trim();
    if (clean.isNotEmpty) buf.writeln('• $clean');
  }
  return buf.toString().trimRight();
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELO 1 — _toCompletoString()
// SOAP Tradicional Expandida: espelho vertical e limpo de todo o prontuário.
// Emoji headers, "• " bullets, regex split de listas numeradas.
// Proibido usar barras horizontais dentro dos dados (apenas no frame de borda).
// ─────────────────────────────────────────────────────────────────────────────
String _toCompletoString(
  EvolucionModel ev,
  bool isEs,
  String autorNombre,
  PacienteInternacaoData? paciente,
) {
  final buf  = StringBuffer();
  final p    = paciente;
  final s    = ev.subjetivo;
  final o    = ev.objetivo;
  final sv   = o.signosVitales;
  final ef   = o.examenFisico;
  final ex   = o.examenes;
  final a    = ev.evaluacion;
  final plan = ev.plan;
  final nomeDoc = autorNombre.trim().isNotEmpty ? autorNombre : ev.autorNombre;
  const sep  = '=========================================';
  const dash = '-----------------------------------------';

  // ── Frame superior ──────────────────────────────────────────────────────────
  buf.writeln(sep);
  buf.writeln('📋 MEDCASES PRO - ${isEs ? 'PRONTUARIO COMPLETO' : 'PRONTUÁRIO COMPLETO'}');
  buf.writeln(sep);

  // ── Cabeçalho demográfico ───────────────────────────────────────────────────
  if (p != null) {
    final nome  = p.nome.isNotEmpty  ? p.nome  : '---';
    final cama  = p.cama.isNotEmpty  ? p.cama  : '---';
    final servico = isEs ? 'Servicio' : 'Serviço';
    buf.writeln('👤 ${isEs ? 'PACIENTE' : 'PACIENTE'}: $nome | 🆔 HC: ______ | 🛏️ LEITO: $cama');
    buf.writeln('📆 ${isEs ? 'INTERNACION' : 'INTERNAÇÃO'}: Dia ${p.diaInternacao} | 🩺 $servico: ______');
  } else {
    buf.writeln('👤 PACIENTE: --- | 🆔 HC: ______ | 🛏️ LEITO: ---');
    buf.writeln('📆 ${isEs ? 'INTERNACION' : 'INTERNAÇÃO'}: Dia --- | 🩺 ${isEs ? 'Servicio' : 'Serviço'}: ______');
  }

  buf.writeln(dash);

  // ── Diagnósticos ativos ─────────────────────────────────────────────────────
  final allDx = <String>{
    if (p != null && p.diagnostico.isNotEmpty) p.diagnostico,
    ...a.problemasActivos,
  }.toList();
  buf.writeln('🩺 ${isEs ? 'DIAGNÓSTICOS ACTIVOS' : 'DIAGNÓSTICOS ATIVOS'}:');
  if (allDx.isNotEmpty) {
    for (final dx in allDx) { buf.writeln('• $dx'); }
  } else {
    buf.writeln(isEs ? '• (Sin diagnósticos registrados)' : '• (Sem diagnósticos registrados)');
  }
  buf.writeln('');

  // ── S — SUBJETIVO ───────────────────────────────────────────────────────────
  buf.writeln('S - ${isEs ? 'SUBJETIVO' : 'SUBJETIVO'}:');
  final sBuf = StringBuffer();
  if (s.notePasaNoche.isNotEmpty)  sBuf.writeln(_toBullets(s.notePasaNoche));
  if (s.dolorEscala != null)       sBuf.writeln('• EVA ${s.dolorEscala}/10');
  final syms = <String>[];
  if (s.fiebre)       syms.add(isEs ? 'fiebre' : 'febre');
  if (s.disnea)       syms.add(isEs ? 'disnea' : 'dispneia');
  if (s.nauseas)      syms.add(isEs ? 'nauseas' : 'nauseas');
  if (s.tos)          syms.add(isEs ? 'tos' : 'tosse');
  if (s.suenoRestado) syms.add(isEs ? 'sueño alterado' : 'sono alterado');
  if (syms.isNotEmpty) sBuf.writeln('• ${isEs ? 'Refiere' : 'Refere'}: ${syms.join(', ')}');
  if (s.alimentacion.isNotEmpty) sBuf.writeln('• ${isEs ? 'Alimentación' : 'Alimentação'}: ${s.alimentacion}');
  if (s.diuresis.isNotEmpty)     sBuf.writeln('• ${isEs ? 'Diuresis' : 'Diurese'}: ${s.diuresis}');
  if (s.evacuacion.isNotEmpty)   sBuf.writeln('• ${isEs ? 'Evacuación' : 'Evacuação'}: ${s.evacuacion}');
  if (s.notasLibres.isNotEmpty)  sBuf.writeln(_toBullets(s.notasLibres));
  final sResult = sBuf.toString().trim();
  buf.writeln(sResult.isNotEmpty ? sResult : (isEs ? '• (Sin datos)' : '• (Sem dados)'));
  buf.writeln('');

  // ── O — OBJETIVO ────────────────────────────────────────────────────────────
  buf.writeln('O - ${isEs ? 'OBJETIVO' : 'OBJETIVO'}:');

  // Sinais Vitais
  if (!sv.isEmpty) {
    final svParts = <String>[];
    if (sv.pa.isNotEmpty)          svParts.add('TA ${sv.pa}');
    if (sv.fc.isNotEmpty)          svParts.add('FC ${sv.fc}');
    if (sv.fr.isNotEmpty)          svParts.add('FR ${sv.fr}');
    if (sv.temperatura.isNotEmpty) svParts.add('T ${sv.temperatura} °C');
    if (sv.satO2.isNotEmpty)       svParts.add('SatO2 ${sv.satO2}%');
    buf.writeln('• ${isEs ? 'Signos Vitales' : 'Sinais Vitais'}: ${svParts.join(' | ')}');
  }

  // Exame Físico
  final efParts = <String>[];
  if (ef.estadoGeneral.isNotEmpty) efParts.add(ef.estadoGeneral);
  if (ef.acv.isNotEmpty)           efParts.add('CV: ${ef.acv}');
  if (ef.ar.isNotEmpty)            efParts.add('Resp: ${ef.ar}');
  if (ef.abdomen.isNotEmpty)       efParts.add('Abd: ${ef.abdomen}');
  if (ef.extremidades.isNotEmpty)  efParts.add('MMII: ${ef.extremidades}');
  if (efParts.isNotEmpty) {
    buf.writeln('• ${isEs ? 'Examen Físico' : 'Exame Físico'}: ${efParts.join('. ')}');
  }

  // Laboratório / Estudos
  if (ex.laboratorio.isNotEmpty) {
    final labBullets = _toBullets(ex.laboratorio);
    if (labBullets.isNotEmpty) {
      buf.writeln('• ${isEs ? 'Laboratorio/Estudios' : 'Laboratório/Estudos'}:');
      buf.writeln(labBullets.split('\n').map((l) => '  $l').join('\n'));
    }
  }
  if (ex.imagenes.isNotEmpty) {
    buf.writeln('• ${isEs ? 'Imágenes' : 'Imagens'}: ${ex.imagenes}');
  }
  if (ex.culturas.isNotEmpty) {
    buf.writeln('• Culturas: ${ex.culturas}');
  }
  if (ex.ecg.isNotEmpty) {
    buf.writeln('• ECG: ${ex.ecg}');
  }
  if (o.tratamientoActual.isNotEmpty) {
    buf.writeln('• ${isEs ? 'Tratamiento actual' : 'Tratamento atual'}: ${o.tratamientoActual}');
  }

  // Fallback se O completamente vazio
  final hasO = !sv.isEmpty || efParts.isNotEmpty || ex.laboratorio.isNotEmpty ||
      ex.imagenes.isNotEmpty || ex.culturas.isNotEmpty || ex.ecg.isNotEmpty ||
      o.tratamientoActual.isNotEmpty;
  if (!hasO) buf.writeln(isEs ? '• (Sin datos)' : '• (Sem dados)');
  buf.writeln('');

  // ── A — AVALIAÇÃO ───────────────────────────────────────────────────────────
  buf.writeln('A - ${isEs ? 'ANÁLISIS' : 'AVALIAÇÃO'}:');
  if (a.estado != null) {
    buf.writeln('• ${isEs ? 'Estado Clínico' : 'Status Clínico'}: ${a.estado!.label(isEs ? 'es' : 'pt')}');
  }
  if (a.notasEvaluacion.isNotEmpty) {
    buf.writeln('• ${isEs ? 'Análisis' : 'Análise'}: ${a.notasEvaluacion}');
  }
  if (a.estado == null && a.notasEvaluacion.isEmpty) {
    buf.writeln(isEs ? '• (Sin datos)' : '• (Sem dados)');
  }
  buf.writeln('');

  // ── P — PLANO & MEDICAÇÃO ───────────────────────────────────────────────────
  buf.writeln('P - ${isEs ? 'PLAN & MEDICACIÓN' : 'PLANO & MEDICAÇÃO'}:');
  if (plan.planTerapeutico.isNotEmpty) {
    buf.writeln(_toBullets(plan.planTerapeutico));
  }
  if (plan.criteriosAlta.isNotEmpty) {
    buf.writeln('• ${isEs ? 'Criterios de alta' : 'Critérios de alta'}: ${plan.criteriosAlta}');
  }
  if (ev.farmacos.isNotEmpty) {
    buf.writeln('• ${isEs ? 'Medicación prescripta' : 'Medicação prescrita'}:');
    for (final f in ev.farmacos) {
      final dos = f.dosagem.isNotEmpty ? ' — ${f.dosagem}' : '';
      buf.writeln('  • ${f.medicamento}$dos');
    }
  }
  if (plan.planTerapeutico.isEmpty && plan.criteriosAlta.isEmpty && ev.farmacos.isEmpty) {
    buf.writeln(isEs ? '• (Sin datos)' : '• (Sem dados)');
  }
  buf.writeln('');

  // ── Assinatura ──────────────────────────────────────────────────────────────
  final sigLine = nomeDoc.trim().isNotEmpty ? 'Dr/Dra. $nomeDoc' : '______________________';
  buf.writeln('📅 Data: ${_fmtFecha()} — ${_fmtHora()} hs');
  buf.writeln('✍️  ${isEs ? 'Médico responsable' : 'Médico responsável'}: $sigLine');
  buf.writeln(sep);

  return buf.toString().trimRight();
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELO 2 — _toResumidoString()
// Painel Clínico Compacto: aglutinaçãocirúrgica — 1 linha por bloco SOAP.
// Omite detalhes; mantém apenas essenciais escaneáveis por colega de equipe.
// ─────────────────────────────────────────────────────────────────────────────
String _toResumidoString(
  EvolucionModel ev,
  bool isEs,
  String autorNombre,
  PacienteInternacaoData? paciente,
) {
  final buf  = StringBuffer();
  final p    = paciente;
  final s    = ev.subjetivo;
  final o    = ev.objetivo;
  final sv   = o.signosVitales;
  final ef   = o.examenFisico;
  final ex   = o.examenes;
  final a    = ev.evaluacion;
  final plan = ev.plan;
  const sep  = '=========================================';
  const dash = '-----------------------------------------';

  // ── Frame superior ──────────────────────────────────────────────────────────
  buf.writeln(sep);
  buf.writeln('⚡ MEDCASES PRO - ${isEs ? 'RESUMEN EJECUTIVO' : 'RESUMO EXECUTIVO'}');
  buf.writeln(sep);

  // ── Linha 1: Identidade compacta ───────────────────────────────────────────
  final nome  = p?.nome.isNotEmpty  == true ? p!.nome  : '---';
  final idade = p?.idade.isNotEmpty == true ? p!.idade : '---';
  final cama  = p?.cama.isNotEmpty  == true ? p!.cama  : '---';
  final dia   = p?.diaInternacao ?? 1;
  buf.writeln('👤 $nome • $idade ${isEs ? 'años' : 'anos'} • Leito: $cama • Dia $dia');

  // ── Linha 2: Diagnósticos inline com separador "•" ─────────────────────────
  final allDx = <String>{
    if (p != null && p.diagnostico.isNotEmpty) p.diagnostico,
    ...a.problemasActivos,
  }.toList();
  if (allDx.isNotEmpty) {
    buf.writeln('Dx: ${allDx.join(' • ')}');
  }

  buf.writeln(dash);

  // ── S (1 linha condensada) ──────────────────────────────────────────────────
  final sParts = <String>[];
  if (s.notePasaNoche.isNotEmpty) sParts.add(s.notePasaNoche);
  if (s.dolorEscala != null)      sParts.add('EVA ${s.dolorEscala}/10');
  final syms = <String>[];
  if (s.fiebre)       syms.add(isEs ? 'fiebre' : 'febre');
  if (s.disnea)       syms.add(isEs ? 'disnea' : 'dispneia');
  if (s.nauseas)      syms.add(isEs ? 'nauseas' : 'nauseas');
  if (s.tos)          syms.add(isEs ? 'tos' : 'tosse');
  if (s.suenoRestado) syms.add(isEs ? 'sueño alt.' : 'sono alt.');
  if (syms.isNotEmpty) sParts.add('${isEs ? 'Refiere' : 'Refere'}: ${syms.join(', ')}');
  if (s.alimentacion.isNotEmpty) sParts.add('${isEs ? 'Alim' : 'Alim'}: ${s.alimentacion}');
  if (s.diuresis.isNotEmpty)     sParts.add('${isEs ? 'Diur' : 'Diur'}: ${s.diuresis}');
  if (s.notasLibres.isNotEmpty)  sParts.add(s.notasLibres);
  buf.writeln('• S: ${sParts.isNotEmpty ? sParts.join('. ') : (isEs ? 'Sin datos' : 'Sem dados')}');

  // ── O (SV comprimido + labs críticos) ──────────────────────────────────────
  final svParts = <String>[];
  if (sv.pa.isNotEmpty)          svParts.add('TA ${sv.pa}');
  if (sv.fc.isNotEmpty)          svParts.add('FC ${sv.fc}');
  if (sv.satO2.isNotEmpty)       svParts.add('SatO2 ${sv.satO2}%');
  final svStr = svParts.isNotEmpty ? 'SV: ${svParts.join(', ')}' : '';

  // Apenas alterações críticas de exame físico
  final efCrit = <String>[];
  if (ef.estadoGeneral.isNotEmpty) efCrit.add(ef.estadoGeneral);

  // Apenas labs com valores
  final labCrit = <String>[];
  if (ex.laboratorio.isNotEmpty) labCrit.add(ex.laboratorio);
  if (ex.ecg.isNotEmpty)         labCrit.add('ECG: ${ex.ecg}');

  final oChunks = <String>[
    if (svStr.isNotEmpty) svStr,
    if (efCrit.isNotEmpty) efCrit.join(', '),
    if (labCrit.isNotEmpty) labCrit.join(' | '),
  ];
  buf.writeln('• O: ${oChunks.isNotEmpty ? oChunks.join('. ') : (isEs ? 'Sin datos' : 'Sem dados')}');

  // ── A (conclusão + status em 1 linha) ──────────────────────────────────────
  final aParts = <String>[];
  if (a.estado != null) aParts.add(a.estado!.label(isEs ? 'es' : 'pt'));
  if (a.notasEvaluacion.isNotEmpty) aParts.add(a.notasEvaluacion);
  buf.writeln('• A: ${aParts.isNotEmpty ? aParts.join('. ') : (isEs ? 'Sin datos' : 'Sem dados')}');

  // ── P (condutas por linha, cada item em bullet próprio) ────────────────────
  buf.writeln('• P:');
  if (plan.planTerapeutico.isNotEmpty) {
    final planLines = _splitNumberedList(plan.planTerapeutico.isNotEmpty
        && RegExp(r'\d+[\.\)]\s+').hasMatch(plan.planTerapeutico)
        ? plan.planTerapeutico
        : plan.planTerapeutico);
    if (planLines.length > 1) {
      // Era lista numerada → cada item em linha própria
      for (final item in planLines) {
        buf.writeln('  • $item');
      }
    } else {
      // Texto livre ou já vertical → quebra por \n
      for (final line in plan.planTerapeutico.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty)) {
        final clean = line.replaceFirst(RegExp(r'^[-•*\d+\.]\s*'), '').trim();
        buf.writeln('  • $clean');
      }
    }
  }
  if (plan.criteriosAlta.isNotEmpty) {
    buf.writeln('  • ${isEs ? 'Alta si' : 'Alta se'}: ${plan.criteriosAlta}');
  }
  if (ev.farmacos.isNotEmpty) {
    for (final f in ev.farmacos) {
      final dos = f.dosagem.isNotEmpty ? ' ${f.dosagem}' : '';
      buf.writeln('  • ${f.medicamento}$dos');
    }
  }
  if (plan.planTerapeutico.isEmpty && plan.criteriosAlta.isEmpty && ev.farmacos.isEmpty) {
    buf.writeln(isEs ? '  • (Sin datos)' : '  • (Sem dados)');
  }

  buf.writeln(sep);
  return buf.toString().trimRight();
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELO 3 — _toPassagemString()
// Passagem de Plantão: foco total em AÇÃO e ALERTA.
// OMITE histórico longo de anamnese. O médico entrante só quer saber:
//   1. Estado atual do paciente
//   2. O que ele DEVE FAZER agora (to-do list)
// ─────────────────────────────────────────────────────────────────────────────
String _toPassagemString(
  EvolucionModel ev,
  bool isEs,
  PacienteInternacaoData? paciente,
) {
  final buf  = StringBuffer();
  final p    = paciente;
  final o    = ev.objetivo;
  final sv   = o.signosVitales;
  final ex   = o.examenes;
  final a    = ev.evaluacion;
  final plan = ev.plan;
  const sep  = '=========================================';
  const dash = '-----------------------------------------';

  // ── Frame superior ──────────────────────────────────────────────────────────
  buf.writeln(sep);
  buf.writeln('🔄 MEDCASES PRO - ${isEs ? 'PASAJE DE GUARDIA' : 'PASSAGEM DE PLANTÃO'}');
  buf.writeln(sep);

  // ── Identidade ultra-compacta ───────────────────────────────────────────────
  final cama  = p?.cama.isNotEmpty  == true ? p!.cama  : '---';
  final nome  = p?.nome.isNotEmpty  == true ? p!.nome  : '---';
  final idade = p?.idade.isNotEmpty == true ? p!.idade : '---';
  final sexo  = p?.sexo.isNotEmpty  == true ? p!.sexo  : '---';
  buf.writeln('🛏️ LEITO: $cama • 👤 PACIENTE: $nome (${idade}a, $sexo)');

  // ── Diagnósticos ────────────────────────────────────────────────────────────
  final allDx = <String>{
    if (p != null && p.diagnostico.isNotEmpty) p.diagnostico,
    ...a.problemasActivos,
  }.toList();
  final dxStr = allDx.isNotEmpty
      ? allDx.join(' | ')
      : (isEs ? 'Não registrado' : 'Não registrado');
  buf.writeln('🩺 ${isEs ? 'DX PRINCIPAL' : 'DX PRINCIPAL'}: $dxStr');
  buf.writeln(dash);

  // ── Estado atual (status + SV) ──────────────────────────────────────────────
  final estadoLabel = a.estado?.label(isEs ? 'es' : 'pt')
      ?? (isEs ? 'Sem registro' : 'Sem registro');
  buf.writeln('🚨 ${isEs ? 'ESTADO ACTUAL' : 'ESTADO ATUAL'}: $estadoLabel');

  if (!sv.isEmpty) {
    final svParts = <String>[];
    if (sv.pa.isNotEmpty)          svParts.add('TA ${sv.pa}');
    if (sv.fc.isNotEmpty)          svParts.add('FC ${sv.fc}');
    if (sv.fr.isNotEmpty)          svParts.add('FR ${sv.fr}');
    if (sv.satO2.isNotEmpty)       svParts.add('SatO2 ${sv.satO2}%');
    if (sv.temperatura.isNotEmpty) svParts.add('T ${sv.temperatura} °C');
    buf.writeln('📈 ${isEs ? 'SIGNOS VITALES' : 'SINAIS VITAIS'}: ${svParts.join(', ')}');
  }

  // ── Suporte ativo (O2 / DVA / Infusões) — apenas tratamientoActual ─────────
  if (o.tratamientoActual.isNotEmpty) {
    buf.writeln('💊 ${isEs ? 'SOPORTE ACTIVO' : 'SUPORTE ATIVO'}: ${o.tratamientoActual}');
  } else {
    buf.writeln('💊 ${isEs ? 'SOPORTE ACTIVO' : 'SUPORTE ATIVO'}: ${isEs ? 'Sin suporte activo registrado' : 'Sem suporte ativo registrado'}');
  }
  buf.writeln('');

  // ── Labs críticos / Últimas alterações (OMITE anamnese longa) ───────────────
  buf.writeln('🔬 ${isEs ? 'ÚLTIMAS ALTERACIONES / LABS CRÍTICOS' : 'ÚLTIMAS ALTERAÇÕES / LABS CRÍTICOS'}:');
  final labBullets = ex.laboratorio.isNotEmpty ? _toBullets(ex.laboratorio) : '';
  final imgBullets = ex.imagenes.isNotEmpty    ? _toBullets(ex.imagenes)    : '';
  final ecgStr     = ex.ecg.isNotEmpty         ? '• ECG: ${ex.ecg}'         : '';
  final cultStr    = ex.culturas.isNotEmpty     ? '• Culturas: ${ex.culturas}' : '';
  final hasLabs    = labBullets.isNotEmpty || imgBullets.isNotEmpty
      || ecgStr.isNotEmpty || cultStr.isNotEmpty;
  if (hasLabs) {
    if (labBullets.isNotEmpty) buf.writeln(labBullets);
    if (imgBullets.isNotEmpty) buf.writeln(imgBullets);
    if (ecgStr.isNotEmpty)     buf.writeln(ecgStr);
    if (cultStr.isNotEmpty)    buf.writeln(cultStr);
  } else {
    buf.writeln(isEs ? '• (Sin alteraciones registradas)' : '• (Sem alterações registradas)');
  }
  buf.writeln('');

  // ── Pendências & Próximos Passos (TO-DO LIST) ───────────────────────────────
  buf.writeln('🛑 ${isEs ? 'PENDIENTES & PRÓXIMOS PASOS (TO-DO LIST)' : 'PENDÊNCIAS & PRÓXIMOS PASSOS (TO-DO LIST)'}:');
  bool hasPendencias = false;

  if (plan.planTerapeutico.isNotEmpty) {
    hasPendencias = true;
    buf.writeln(_toBullets(plan.planTerapeutico));
  }
  if (plan.criteriosAlta.isNotEmpty) {
    hasPendencias = true;
    buf.writeln('• ${isEs ? 'Alta si' : 'Alta se'}: ${plan.criteriosAlta}');
  }
  if (ev.farmacos.isNotEmpty) {
    hasPendencias = true;
    for (final f in ev.farmacos) {
      final dos = f.dosagem.isNotEmpty ? ' — ${f.dosagem}' : '';
      buf.writeln('• ${f.medicamento}$dos');
    }
  }
  if (!hasPendencias) {
    buf.writeln(isEs ? '• (Sin pendientes documentados)' : '• (Sem pendências documentadas)');
  }

  buf.writeln(sep);
  return buf.toString().trimRight();
}

// ── Build 181: ModalBottomSheet Tri-Modelo de Cópia ──────────────────────────
class _CopyOptionsSheet extends StatelessWidget {
  final bool dark;
  final String lang;
  final VoidCallback onCopyFull;
  final VoidCallback onCopyResumida;
  final VoidCallback onCopyPasaje;

  const _CopyOptionsSheet({
    required this.dark,
    required this.lang,
    required this.onCopyFull,
    required this.onCopyResumida,
    required this.onCopyPasaje,
  });

  bool get isEs => lang == 'es';

  @override
  Widget build(BuildContext context) {
    final bg    = dark ? const Color(0xFF0F1116) : Colors.white;
    final theme = InternacionTheme(dark);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: InternacionTheme.cyan.withValues(alpha: 0.25),
          width: 1.0,
        ),
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
                color: theme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // ── Título ───────────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF059669), Color(0xFF047857)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.copy_all_rounded,
                    size: 17, color: Colors.white),
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
                        color: theme.textPrimary,
                      ),
                    ),
                    Text(
                      isEs
                          ? 'Selecciona el formato de exportación'
                          : 'Selecione o formato de exportação',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: theme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Modelo 1: Evolución Completa ─────────────────────────────────────
          _CopyOptionTile(
            dark: dark,
            icon: Icons.description_rounded,
            iconColor: const Color(0xFF3B82F6),
            iconBg: const Color(0xFF3B82F6),
            title: isEs ? 'Evolucion Completa' : 'Evolução Completa',
            subtitle: isEs
                ? 'Encabezado hospitalar + S/O/A/P jerarquico + firma'
                : 'Cabecalho hospitalar + S/O/A/P hierarquico + assinatura',
            badgeLabel: 'SOAP',
            badgeColor: const Color(0xFF3B82F6),
            onTap: onCopyFull,
            theme: theme,
          ),
          const SizedBox(height: 8),

          // ── Modelo 2: Evolución Resumida ─────────────────────────────────────
          _CopyOptionTile(
            dark: dark,
            icon: Icons.compress_rounded,
            iconColor: const Color(0xFF059669),
            iconBg: const Color(0xFF059669),
            title: isEs ? 'Evolucion Resumida' : 'Evolução Resumida',
            subtitle: isEs
                ? 'Formato horizontal denso — ideal para sistemas legados'
                : 'Formato horizontal denso — ideal para sistemas legados',
            badgeLabel: isEs ? 'INLINE' : 'INLINE',
            badgeColor: const Color(0xFF059669),
            onTap: onCopyResumida,
            theme: theme,
          ),
          const SizedBox(height: 8),

          // ── Modelo 3: Pasaje de Guardia ──────────────────────────────────────
          _CopyOptionTile(
            dark: dark,
            icon: Icons.transfer_within_a_station_rounded,
            iconColor: const Color(0xFFF59E0B),
            iconBg: const Color(0xFFF59E0B),
            title: isEs ? 'Pasaje de Guardia' : 'Passagem de Plantão',
            subtitle: isEs
                ? 'Ultra-objetivo para transicion de turno en menos de 30s'
                : 'Ultra-objetivo para passagem de plantão em menos de 30s',
            badgeLabel: isEs ? '30s' : '30s',
            badgeColor: const Color(0xFFF59E0B),
            onTap: onCopyPasaje,
            theme: theme,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Tile de opção de cópia ────────────────────────────────────────────────────
class _CopyOptionTile extends StatelessWidget {
  final bool dark;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String badgeLabel;
  final Color badgeColor;
  final VoidCallback onTap;
  final InternacionTheme theme;

  const _CopyOptionTile({
    required this.dark,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    required this.badgeColor,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.border, width: 0.9),
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: iconBg.withValues(alpha: dark ? 0.15 : 0.10),
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
                            color: theme.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
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
                      color: theme.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: theme.textSecondary),
          ],
        ),
      ),
    );
  }
}
