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

  // ── Build 176-R: Abre o ModalBottomSheet de cópia — chamado pelo pai ──────
  // O botão [Copiar] compacto da Action Bar (25/50/25) invoca este método.
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
          _executeCopyFull();
        },
        onCopyDaily: () {
          Navigator.of(sheetCtx).pop();
          _executeCopyDaily();
        },
      ),
    );
  }

  Future<void> _executeCopyFull() async {
    final ev = _notifier.evolucion;
    final text = _compileFullSoapRecord(
        ev, widget.lang == 'es', widget.autorNombre, widget.paciente);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.copy_rounded, color: Colors.white, size: 15),
        const SizedBox(width: 8),
        Expanded(
          child: Text(widget.lang == 'es'
              ? 'Ficha completa copiada al portapapeles'
              : 'Ficha completa copiada para a área de transferência'),
        ),
      ]),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _executeCopyDaily() async {
    final ev = _notifier.evolucion;
    final text = _compileDailySoapEvolution(
        ev, widget.lang == 'es', widget.autorNombre);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.copy_rounded, color: Colors.white, size: 15),
        const SizedBox(width: 8),
        Expanded(
          child: Text(widget.lang == 'es'
              ? 'Evolución diaria copiada al portapapeles'
              : 'Evolução diária copiada para a área de transferência'),
        ),
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

        // ── Accordions em grade 2×2 ──────────────────────────────────────────
        // Linha 1: [S] Subjetivo | [O] Objetivo
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: sections[0]),
              const SizedBox(width: 8),
              Expanded(child: sections[1]),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Linha 2: [A] Avaliação | [P] Plano
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: sections[2]),
              const SizedBox(width: 8),
              Expanded(child: sections[3]),
            ],
          ),
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


// ═══════════════════════════════════════════════════════════════════════════
// Build 176-R: Funções de compilação promovidas a top-level (antes eram
// static methods de _CopyMenuButtonState). Usadas por SoapSectionWidgetState
// (via showCopyMenu) e por _CopyMenuButtonState (via _executeCopy).
// ═══════════════════════════════════════════════════════════════════════════
// ────────────────────────────────────────────────────────────────────────────
// Build 168 — OPÇÃO 1: Ficha completa (cabeçalho + bloco clínico)
// Formato hospitalar argentino — bind completo de todos os campos do paciente:
// nome, cama, idade, sexo, diagnóstico, diaInternacao + 24 campos clínicos.
// ────────────────────────────────────────────────────────────────────────────
String _compileFullSoapRecord(
  EvolucionModel ev,
  bool isEs,
  String autorNombre,
  PacienteInternacaoData? paciente,
) {
  final buf = StringBuffer();
  final now = DateTime.now();
  final fecha = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
  final hora  = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  final nomeDisplay = autorNombre.trim().isNotEmpty ? autorNombre : ev.autorNombre;

  // ── Cabeçalho hospitalar ─────────────────────────────────────────────────
  buf.writeln('EVOLUCIÓN MÉDICA');
  buf.writeln('Fecha: $fecha  Hora: $hora');

  if (paciente != null) {
    // Linha 1: Paciente, Cama, Día
    final nomePart = paciente.nome.isNotEmpty
        ? '${isEs ? 'Paciente' : 'Paciente'}: ${paciente.nome}' : '';
    final camaPart = paciente.cama.isNotEmpty
        ? '${isEs ? 'Cama' : 'Leito'}: ${paciente.cama}' : '';
    final diaPart  = '${isEs ? 'Día de internación' : 'Dia de internação'}: ${paciente.diaInternacao}';
    final headerLine = [nomePart, camaPart, diaPart]
        .where((s) => s.isNotEmpty).join('  |  ');
    if (headerLine.isNotEmpty) buf.writeln(headerLine);

    // Linha 2: Edad + Sexo
    final idadePart = paciente.idade.isNotEmpty
        ? '${isEs ? 'Edad' : 'Idade'}: ${paciente.idade}' : '';
    final sexoPart  = paciente.sexo.isNotEmpty
        ? '${isEs ? 'Sexo' : 'Sexo'}: ${paciente.sexo}' : '';
    final demoLine  = [idadePart, sexoPart]
        .where((s) => s.isNotEmpty).join('  |  ');
    if (demoLine.isNotEmpty) buf.writeln(demoLine);

    // Diagnóstico principal
    final diag = paciente.diagnostico.isNotEmpty
        ? paciente.diagnostico
        : (ev.evaluacion.problemasActivos.isNotEmpty
            ? ev.evaluacion.problemasActivos.first
            : '');
    if (diag.isNotEmpty) {
      buf.writeln('${isEs ? 'Diagnóstico' : 'Diagnóstico'}: $diag');
    }
  }

  buf.writeln('');

  // ── Bloco clínico completo (todos os 24 campos) ──────────────────────────
  buf.write(_soapBuildClinicalBlock(ev, isEs));

  // ── Firma ────────────────────────────────────────────────────────────────
  buf.writeln('Firma:');
  buf.writeln('Dr/Dra. $nomeDisplay');

  return buf.toString().trimRight();
}

// ────────────────────────────────────────────────────────────────────────────
// Build 168 — OPÇÃO 2: Evolução diária
// Formato hospitalar argentino limpo — SEM emojis, SEM decorações.
// Apenas data/hora + bloco clínico completo + firma profissional.
// Pronto para colar diretamente no prontuário eletrônico.
// ────────────────────────────────────────────────────────────────────────────
String _compileDailySoapEvolution(
  EvolucionModel ev,
  bool isEs,
  String autorNombre,
) {
  final buf = StringBuffer();
  final now = DateTime.now();
  final fecha = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
  final hora  = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  final nomeDisplay = autorNombre.trim().isNotEmpty ? autorNombre : ev.autorNombre;

  buf.writeln('${isEs ? 'Evolución diaria' : 'Evolução diária'} — $fecha  $hora');
  buf.writeln('');
  buf.write(_soapBuildClinicalBlock(ev, isEs));
  buf.writeln('Firma:');
  buf.writeln('Dr/Dra. $nomeDisplay');

  return buf.toString().trimRight();
}

// ────────────────────────────────────────────────────────────────────────────
// Build 168 — Bloco clínico no formato hospitalar argentino (sem títulos SOAP)
// Binding completo dos 24 campos:
//   S (11): notePasaNoche, dolorEscala, fiebre, disnea, nauseas, tos,
//           suenoRestado, alimentacion, diuresis, evacuacion, notasLibres
//   O-SV (5): pa, fc, fr, satO2, temperatura
//   O-EF (5): estadoGeneral, acv, ar, abdomen, extremidades
//   O-EX (4): laboratorio, imagenes, culturas, ecg
//   O-TX (1): tratamientoActual
//   A  (3): notasEvaluacion, estado, problemasActivos
//   P  (2): planTerapeutico, criteriosAlta
//   FX (+): farmacos[medicamento, dosagem]
// Sem emojis — texto profissional puro para prontuário eletrônico.
// ────────────────────────────────────────────────────────────────────────────
String _soapBuildClinicalBlock(EvolucionModel ev, bool isEs) {
  final buf = StringBuffer();
  final s  = ev.subjetivo;
  final o  = ev.objetivo;
  final sv = o.signosVitales;
  final ef = o.examenFisico;
  final ex = o.examenes;
  final a  = ev.evaluacion;
  final p  = ev.plan;

  // ── Evolución — Subjetivo (11 campos) ────────────────────────────────────
  final evolParts = <String>[];
  if (s.notePasaNoche.isNotEmpty) evolParts.add(s.notePasaNoche);
  if (s.dolorEscala != null) evolParts.add('EVA ${s.dolorEscala}/10');

  final syms = <String>[];
  if (s.fiebre)       syms.add(isEs ? 'fiebre' : 'febre');
  if (s.disnea)       syms.add(isEs ? 'disnea' : 'dispneia');
  if (s.nauseas)      syms.add(isEs ? 'náuseas' : 'náuseas');
  if (s.tos)          syms.add(isEs ? 'tos' : 'tosse');
  if (s.suenoRestado) syms.add(isEs ? 'sueño alterado' : 'sono alterado');
  if (syms.isNotEmpty) {
    evolParts.add('${isEs ? 'Refiere' : 'Refere'}: ${syms.join(', ')}');
  }
  if (s.alimentacion.isNotEmpty) {
    evolParts.add('${isEs ? 'Alimentación' : 'Alimentação'}: ${s.alimentacion}');
  }
  if (s.diuresis.isNotEmpty) {
    evolParts.add('${isEs ? 'Diuresis' : 'Diurese'}: ${s.diuresis}');
  }
  if (s.evacuacion.isNotEmpty) {
    evolParts.add('${isEs ? 'Evacuación' : 'Evacuação'}: ${s.evacuacion}');
  }
  if (s.notasLibres.isNotEmpty) evolParts.add(s.notasLibres);

  buf.writeln('${isEs ? 'Evolución' : 'Evolução'}:');
  if (evolParts.isNotEmpty) {
    buf.writeln(evolParts.join('. '));
  } else {
    buf.writeln('Sin datos consignados.');
  }
  buf.writeln('');

  // ── SV — Signos Vitales (5 campos) ───────────────────────────────────────
  if (!sv.isEmpty) {
    buf.writeln('SV:');
    final svParts = <String>[];
    if (sv.pa.isNotEmpty)          svParts.add('TA: ${sv.pa} mmHg');
    if (sv.fc.isNotEmpty)          svParts.add('FC: ${sv.fc} lpm');
    if (sv.fr.isNotEmpty)          svParts.add('FR: ${sv.fr} rpm');
    if (sv.satO2.isNotEmpty)       svParts.add('SatO2: ${sv.satO2}%');
    if (sv.temperatura.isNotEmpty) svParts.add('Temp: ${sv.temperatura} C');
    buf.writeln(svParts.join('  '));
    buf.writeln('');
  }

  // ── EF — Examen Físico (5 campos) ────────────────────────────────────────
  final hasEf = ef.estadoGeneral.isNotEmpty || ef.acv.isNotEmpty ||
      ef.ar.isNotEmpty || ef.abdomen.isNotEmpty || ef.extremidades.isNotEmpty;
  if (hasEf) {
    buf.writeln('EF:');
    if (ef.estadoGeneral.isNotEmpty) buf.writeln('EG: ${ef.estadoGeneral}');
    if (ef.acv.isNotEmpty)           buf.writeln('CV: ${ef.acv}');
    if (ef.ar.isNotEmpty)            buf.writeln('Resp: ${ef.ar}');
    if (ef.abdomen.isNotEmpty)       buf.writeln('Abd: ${ef.abdomen}');
    if (ef.extremidades.isNotEmpty)  buf.writeln('MMII: ${ef.extremidades}');
    buf.writeln('');
  }

  // ── Tratamiento Actual (campo adicional ObjetivoData) ─────────────────────
  if (o.tratamientoActual.isNotEmpty) {
    buf.writeln('${isEs ? 'Tratamiento actual' : 'Tratamento atual'}:');
    buf.writeln(o.tratamientoActual);
    buf.writeln('');
  }

  // ── Laboratorio / Exámenes Complementarios (4 campos) ────────────────────
  final hasLab = ex.laboratorio.isNotEmpty || ex.imagenes.isNotEmpty ||
      ex.culturas.isNotEmpty || ex.ecg.isNotEmpty;
  if (hasLab) {
    buf.writeln('${isEs ? 'Laboratorio' : 'Laboratório'}:');
    if (ex.laboratorio.isNotEmpty) buf.writeln(ex.laboratorio);
    if (ex.imagenes.isNotEmpty) {
      buf.writeln('${isEs ? 'Imágenes' : 'Imagens'}: ${ex.imagenes}');
    }
    if (ex.culturas.isNotEmpty) buf.writeln('Culturas: ${ex.culturas}');
    if (ex.ecg.isNotEmpty)       buf.writeln('ECG: ${ex.ecg}');
    buf.writeln('');
  }

  // ── Impresión — Evaluación Clínica (3 campos) ────────────────────────────
  final hasImpresion = a.notasEvaluacion.isNotEmpty || a.estado != null ||
      a.problemasActivos.isNotEmpty;
  if (hasImpresion) {
    buf.writeln('${isEs ? 'Impresión' : 'Impressão'}:');
    if (a.notasEvaluacion.isNotEmpty) {
      buf.writeln(a.notasEvaluacion);
    }
    if (a.problemasActivos.isNotEmpty) {
      buf.writeln('${isEs ? 'Problemas activos' : 'Problemas ativos'}: '
          '${a.problemasActivos.join(', ')}');
    }
    if (a.estado != null) {
      buf.writeln('${isEs ? 'Estado clínico' : 'Estado clínico'}: '
          '${a.estado!.label(isEs ? 'es' : 'pt')}');
    }
    buf.writeln('');
  }

  // ── Conducta — Plan Terapéutico (2 campos) + Fármacos ────────────────────
  final hasPlan = p.planTerapeutico.isNotEmpty ||
      p.criteriosAlta.isNotEmpty ||
      ev.farmacos.isNotEmpty;
  if (hasPlan) {
    buf.writeln('${isEs ? 'Conducta' : 'Conduta'}:');
    if (p.planTerapeutico.isNotEmpty) {
      final lines = p.planTerapeutico
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty);
      for (final line in lines) {
        final bullet = line.startsWith('-') ? line : '- $line';
        buf.writeln(bullet);
      }
    }
    if (p.criteriosAlta.isNotEmpty) {
      buf.writeln('- ${isEs ? 'Criterios de alta' : 'Critérios de alta'}: '
          '${p.criteriosAlta}');
    }
    if (ev.farmacos.isNotEmpty) {
      buf.writeln(isEs
          ? 'Medicación prescripta:'
          : 'Medicação prescrita:');
      for (final f in ev.farmacos) {
        final dos = f.dosagem.isNotEmpty ? ' — ${f.dosagem}' : '';
        buf.writeln('- ${f.medicamento}$dos');
      }
    }
    buf.writeln('');
  }

  return buf.toString();
}


// ── Build 167: ModalBottomSheet premium com 2 opções de cópia ─────────────────
class _CopyOptionsSheet extends StatelessWidget {
  final bool dark;
  final String lang;
  final VoidCallback onCopyFull;
  final VoidCallback onCopyDaily;

  const _CopyOptionsSheet({
    required this.dark,
    required this.lang,
    required this.onCopyFull,
    required this.onCopyDaily,
  });

  bool get isEs => lang == 'es';

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF0F1116) : Colors.white;
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
                          ? 'Seleccioná el formato de exportación'
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
          const SizedBox(height: 20),

          // ── Opção 1: Ficha Completa ──────────────────────────────────────────
          _CopyOptionTile(
            dark: dark,
            icon: Icons.description_rounded,
            iconColor: const Color(0xFF3B82F6),
            iconBg: const Color(0xFF3B82F6),
            title: isEs
                ? 'Copiar Todo (Ingreso/Ficha Completa)'
                : 'Copiar Tudo (Internação/Ficha Completa)',
            subtitle: isEs
                ? 'Incluye datos del paciente + evolución clínica completa'
                : 'Inclui dados do paciente + evolução clínica completa',
            badgeLabel: isEs ? 'COMPLETO' : 'COMPLETO',
            badgeColor: const Color(0xFF3B82F6),
            onTap: onCopyFull,
            theme: theme,
          ),
          const SizedBox(height: 10),

          // ── Opção 2: Solo Evolución Diaria ───────────────────────────────────
          _CopyOptionTile(
            dark: dark,
            icon: Icons.event_note_rounded,
            iconColor: const Color(0xFF059669),
            iconBg: const Color(0xFF059669),
            title: isEs
                ? 'Copiar Solo Evolución Diaria'
                : 'Copiar Apenas Evolução Diária',
            subtitle: isEs
                ? 'Solo el bloque clínico del día — listo para pegar en evoluciones secuenciales'
                : 'Apenas o bloco clínico do dia — pronto para colar em evoluções sequenciais',
            badgeLabel: isEs ? 'RÁPIDO' : 'RÁPIDO',
            badgeColor: const Color(0xFF059669),
            onTap: onCopyDaily,
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
