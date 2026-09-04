// ─────────────────────────────────────────────────────────────────────────────
// O — OBJETIVO
// Sinais vitais + Exame físico + Exames complementares + Tratamento atual.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../../models/evolucion_model.dart';
import '../internacion_theme.dart';

import '../../../../design_system/foundation/med_typography.dart';
class SoapObjetivo extends StatefulWidget {
  final ObjetivoData data;
  final ValueChanged<ObjetivoData> onChanged;
  final bool dark;
  final String lang;

  const SoapObjetivo({
    super.key,
    required this.data,
    required this.onChanged,
    required this.dark,
    required this.lang,
  });

  @override
  State<SoapObjetivo> createState() => _SoapObjetivoState();
}

class _SoapObjetivoState extends State<SoapObjetivo> {
  // Controllers para exame físico
  late final TextEditingController _egCtrl;
  late final TextEditingController _acvCtrl;
  late final TextEditingController _arCtrl;
  late final TextEditingController _abdCtrl;
  late final TextEditingController _extCtrl;

  // Controllers para exames complementares
  late final TextEditingController _labCtrl;
  late final TextEditingController _imgCtrl;
  late final TextEditingController _cultCtrl;
  late final TextEditingController _ecgCtrl;

  // Controller para tratamento atual
  late final TextEditingController _tratCtrl;

  // Controllers para sinais vitais
  late final TextEditingController _paCtrl;
  late final TextEditingController _fcCtrl;
  late final TextEditingController _frCtrl;
  late final TextEditingController _satCtrl;
  late final TextEditingController _tempCtrl;

  // FocusNodes canônicos do fluxo sequencial completo de OBJETIVO.
  // A ordem é fixa: sinais vitais → exame físico →
  // exames complementares → tratamento atual.
  final FocusNode _paFocus = FocusNode(debugLabel: 'objetivo_pa');
  final FocusNode _fcFocus = FocusNode(debugLabel: 'objetivo_fc');
  final FocusNode _frFocus = FocusNode(debugLabel: 'objetivo_fr');
  final FocusNode _satFocus = FocusNode(debugLabel: 'objetivo_sat');
  final FocusNode _tempFocus = FocusNode(debugLabel: 'objetivo_temp');
  final FocusNode _egFocus = FocusNode(debugLabel: 'objetivo_estado_geral');
  final FocusNode _acvFocus = FocusNode(debugLabel: 'objetivo_acv');
  final FocusNode _arFocus = FocusNode(debugLabel: 'objetivo_ar');
  final FocusNode _abdFocus = FocusNode(debugLabel: 'objetivo_abdome');
  final FocusNode _extFocus = FocusNode(debugLabel: 'objetivo_extremidades');
  final FocusNode _labFocus = FocusNode(debugLabel: 'objetivo_laboratorio');
  final FocusNode _imgFocus = FocusNode(debugLabel: 'objetivo_imagens');
  final FocusNode _cultFocus = FocusNode(debugLabel: 'objetivo_culturas');
  final FocusNode _ecgFocus = FocusNode(debugLabel: 'objetivo_ecg');
  final FocusNode _tratFocus =
      FocusNode(debugLabel: 'objetivo_tratamento_atual');

  OverlayEntry? _keyboardToolbarEntry;
  int _scrollRequestSerial = 0;

  bool get isEs => widget.lang == 'es';

  List<FocusNode> get _focusOrder => [
        _paFocus,
        _fcFocus,
        _frFocus,
        _satFocus,
        _tempFocus,
        _egFocus,
        _acvFocus,
        _arFocus,
        _abdFocus,
        _extFocus,
        _labFocus,
        _imgFocus,
        _cultFocus,
        _ecgFocus,
        _tratFocus,
      ];

  FocusNode? get _activeKeyboardFocus {
    for (final node in _focusOrder) {
      if (node.hasFocus) return node;
    }
    return null;
  }

  TextEditingController? _controllerForFocus(FocusNode node) {
    if (identical(node, _paFocus)) return _paCtrl;
    if (identical(node, _fcFocus)) return _fcCtrl;
    if (identical(node, _frFocus)) return _frCtrl;
    if (identical(node, _satFocus)) return _satCtrl;
    if (identical(node, _tempFocus)) return _tempCtrl;
    if (identical(node, _egFocus)) return _egCtrl;
    if (identical(node, _acvFocus)) return _acvCtrl;
    if (identical(node, _arFocus)) return _arCtrl;
    if (identical(node, _abdFocus)) return _abdCtrl;
    if (identical(node, _extFocus)) return _extCtrl;
    if (identical(node, _labFocus)) return _labCtrl;
    if (identical(node, _imgFocus)) return _imgCtrl;
    if (identical(node, _cultFocus)) return _cultCtrl;
    if (identical(node, _ecgFocus)) return _ecgCtrl;
    if (identical(node, _tratFocus)) return _tratCtrl;
    return null;
  }

  String? _tokenForFocus(FocusNode node) {
    if (identical(node, _paFocus)) return '/';
    if (identical(node, _satFocus)) return '%';
    return null;
  }

  void _scheduleKeyboardToolbarSync() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (_activeKeyboardFocus == null) {
        _removeKeyboardToolbar();
        return;
      }

      final overlay = Overlay.of(context, rootOverlay: true);
      final entry = _keyboardToolbarEntry ??=
          OverlayEntry(builder: _buildKeyboardToolbar);

      if (!entry.mounted) {
        overlay.insert(entry);
      }
      entry.markNeedsBuild();
    });
  }

  void _removeKeyboardToolbar() {
    final entry = _keyboardToolbarEntry;
    _keyboardToolbarEntry = null;
    if (entry == null) return;
    if (entry.mounted) {
      entry.remove();
    }
    entry.dispose();
  }

  void _handleFocusChanged() {
    _scheduleKeyboardToolbarSync();

    final active = _activeKeyboardFocus;
    if (active == null) {
      _scrollRequestSerial++;
      return;
    }

    _scheduleFocusedFieldVisibility(active);
  }

  void _scheduleFocusedFieldVisibility(FocusNode node) {
    final requestSerial = ++_scrollRequestSerial;

    void reveal() {
      if (!mounted ||
          requestSerial != _scrollRequestSerial ||
          !node.hasFocus) {
        return;
      }

      final targetContext = node.context;
      if (targetContext == null) return;

      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        alignment: 0.24,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => reveal());
    Future<void>.delayed(const Duration(milliseconds: 180), reveal);
    Future<void>.delayed(const Duration(milliseconds: 360), reveal);
  }

  void _advanceFrom(FocusNode current) {
    final index = _focusOrder.indexOf(current);
    if (index >= 0 && index < _focusOrder.length - 1) {
      _focusOrder[index + 1].requestFocus();
      return;
    }
    current.unfocus();
  }

  void _insertToken(FocusNode node, String token) {
    final controller = _controllerForFocus(node);
    if (controller == null) return;

    final text = controller.text;
    final selection = controller.selection;
    final rawStart = selection.isValid ? selection.start : text.length;
    final rawEnd = selection.isValid ? selection.end : text.length;
    final start = rawStart.clamp(0, text.length).toInt();
    final end = rawEnd.clamp(start, text.length).toInt();
    final updated = text.replaceRange(start, end, token);

    controller.value = controller.value.copyWith(
      text: updated,
      selection: TextSelection.collapsed(offset: start + token.length),
      composing: TextRange.empty,
    );
  }

  Widget _buildKeyboardToolbar(BuildContext overlayContext) {
    final keyboardHeight = MediaQuery.viewInsetsOf(overlayContext).bottom;
    final active = _activeKeyboardFocus;

    if (keyboardHeight <= 0 || active == null) {
      return const SizedBox.shrink();
    }

    final dark = widget.dark;
    final token = _tokenForFocus(active);
    final isLast = identical(active, _tratFocus);

    Widget toolbarButton({
      required String label,
      required VoidCallback onTap,
      bool primary = false,
    }) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: MedTypography.clinicalBodySize,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: primary
                    ? const Color(0xFF10B981)
                    : (dark ? Colors.white70 : const Color(0xFF4B5563)),
              ),
            ),
          ),
        ),
      );
    }

    return Positioned(
      left: 0,
      right: 0,
      bottom: keyboardHeight,
      child: TextFieldTapRegion(
        child: Material(
          color: dark ? const Color(0xFF20242D) : const Color(0xFFF8F9FA),
          elevation: 0,
          child: Container(
          height: 46,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: dark
                    ? const Color(0xFF374151)
                    : const Color(0xFFD1D5DB),
                width: 0.8,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (token != null)
                toolbarButton(
                  label: token,
                  onTap: () => _insertToken(active, token),
                ),
              toolbarButton(
                label: isLast ? 'OK' : 'PRÓXIMO',
                primary: true,
                onTap: () => _advanceFrom(active),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper: cria controller com cursor no final do texto existente.
  // Garante edição fluida ao retomar/carregar rascunho IA (Build 167-C).
  static TextEditingController _ctrl(String text) {
    return TextEditingController(text: text)
      ..selection = TextSelection.collapsed(offset: text.length);
  }

  @override
  void initState() {
    super.initState();
    for (final node in _focusOrder) {
      node.addListener(_handleFocusChanged);
    }

    final sv = widget.data.signosVitales;
    _paCtrl   = _ctrl(sv.pa);
    _fcCtrl   = _ctrl(sv.fc);
    _frCtrl   = _ctrl(sv.fr);
    _satCtrl  = _ctrl(sv.satO2);
    _tempCtrl = _ctrl(sv.temperatura);

    final ef = widget.data.examenFisico;
    _egCtrl   = _ctrl(ef.estadoGeneral);
    _acvCtrl  = _ctrl(ef.acv);
    _arCtrl   = _ctrl(ef.ar);
    _abdCtrl  = _ctrl(ef.abdomen);
    _extCtrl  = _ctrl(ef.extremidades);

    final ex = widget.data.examenes;
    _labCtrl  = _ctrl(ex.laboratorio);
    _imgCtrl  = _ctrl(ex.imagenes);
    _cultCtrl = _ctrl(ex.culturas);
    _ecgCtrl  = _ctrl(ex.ecg);

    _tratCtrl = _ctrl(widget.data.tratamientoActual);

    // Build 205 FIX: addListener em cada controller para capturar mudanças
    // programáticas (.text = valor) que NÃO disparam onChanged do TextField.
    // Garante que injeção IA (applyAiDraft → didUpdateWidget → ctrl.text=)
    // seja imediatamente refletida no SoapNotifier.
    _paCtrl.addListener(_emitSv);
    _fcCtrl.addListener(_emitSv);
    _frCtrl.addListener(_emitSv);
    _satCtrl.addListener(_emitSv);
    _tempCtrl.addListener(_emitSv);
    _egCtrl.addListener(_emitEf);
    _acvCtrl.addListener(_emitEf);
    _arCtrl.addListener(_emitEf);
    _abdCtrl.addListener(_emitEf);
    _extCtrl.addListener(_emitEf);
    _labCtrl.addListener(_emitEx);
    _imgCtrl.addListener(_emitEx);
    _cultCtrl.addListener(_emitEx);
    _ecgCtrl.addListener(_emitEx);
    _tratCtrl.addListener(_emitTrat);
  }

  void _emitTrat() {
    final v = _tratCtrl.text;
    if (v != widget.data.tratamientoActual) {
      widget.onChanged(widget.data.copyWith(tratamientoActual: v));
    }
  }

  // Build 205 FIX: sincroniza todos os controllers quando widget.data muda
  // externamente (injeção IA / resetSoap). A comparação tripla garante:
  //   1. O dado externo mudou (oldWidget → widget)
  //   2. O controller ainda não reflete o novo valor (evita loop)
  // Sem este override, settar controller.text via IA não dispara onChanged e
  // o notifier permanece com os dados antigos até o médico editar manualmente.
  @override
  void didUpdateWidget(SoapObjetivo oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sv    = widget.data.signosVitales;
    final oldSv = oldWidget.data.signosVitales;
    void _sync(TextEditingController c, String nv, String ov) {
      if (nv != ov && nv != c.text) {
        c.text = nv;
        c.selection = TextSelection.collapsed(offset: nv.length);
      }
    }
    // Sinais vitais
    _sync(_paCtrl,   sv.pa,          oldSv.pa);
    _sync(_fcCtrl,   sv.fc,          oldSv.fc);
    _sync(_frCtrl,   sv.fr,          oldSv.fr);
    _sync(_satCtrl,  sv.satO2,       oldSv.satO2);
    _sync(_tempCtrl, sv.temperatura, oldSv.temperatura);
    // Exame físico
    final ef    = widget.data.examenFisico;
    final oldEf = oldWidget.data.examenFisico;
    _sync(_egCtrl,  ef.estadoGeneral, oldEf.estadoGeneral);
    _sync(_acvCtrl, ef.acv,           oldEf.acv);
    _sync(_arCtrl,  ef.ar,            oldEf.ar);
    _sync(_abdCtrl, ef.abdomen,       oldEf.abdomen);
    _sync(_extCtrl, ef.extremidades,  oldEf.extremidades);
    // Exames complementares
    final ex    = widget.data.examenes;
    final oldEx = oldWidget.data.examenes;
    _sync(_labCtrl,  ex.laboratorio, oldEx.laboratorio);
    _sync(_imgCtrl,  ex.imagenes,    oldEx.imagenes);
    _sync(_cultCtrl, ex.culturas,    oldEx.culturas);
    _sync(_ecgCtrl,  ex.ecg,         oldEx.ecg);
    // Tratamento atual
    _sync(_tratCtrl, widget.data.tratamientoActual, oldWidget.data.tratamientoActual);
  }

  @override
  void dispose() {
    _removeKeyboardToolbar();
    for (final node in _focusOrder) {
      node.removeListener(_handleFocusChanged);
      node.dispose();
    }

    // Remove listeners antes de dispose para evitar callbacks pós-desmontagem
    _paCtrl.removeListener(_emitSv);
    _fcCtrl.removeListener(_emitSv);
    _frCtrl.removeListener(_emitSv);
    _satCtrl.removeListener(_emitSv);
    _tempCtrl.removeListener(_emitSv);
    _egCtrl.removeListener(_emitEf);
    _acvCtrl.removeListener(_emitEf);
    _arCtrl.removeListener(_emitEf);
    _abdCtrl.removeListener(_emitEf);
    _extCtrl.removeListener(_emitEf);
    _labCtrl.removeListener(_emitEx);
    _imgCtrl.removeListener(_emitEx);
    _cultCtrl.removeListener(_emitEx);
    _ecgCtrl.removeListener(_emitEx);
    _tratCtrl.removeListener(_emitTrat);
    for (final c in [
      _paCtrl, _fcCtrl, _frCtrl, _satCtrl, _tempCtrl,
      _egCtrl, _acvCtrl, _arCtrl, _abdCtrl, _extCtrl,
      _labCtrl, _imgCtrl, _cultCtrl, _ecgCtrl, _tratCtrl,
    ]) { c.dispose(); }
    super.dispose();
  }

  // _emitSv/Ef/Ex: chamados tanto pelo addListener (mudança programática via IA)
  // quanto pelo onChanged do TextField (digitação manual). A chamada dupla é
  // idempotente pois o notifier compara os dados antes de rebuildar.
  void _emitSv() {
    final sv = SignosVitales(
      pa: _paCtrl.text, fc: _fcCtrl.text, fr: _frCtrl.text,
      satO2: _satCtrl.text, temperatura: _tempCtrl.text,
    );
    // Evita loop: só emite se os dados realmente mudaram
    final cur = widget.data.signosVitales;
    if (sv.pa != cur.pa || sv.fc != cur.fc || sv.fr != cur.fr ||
        sv.satO2 != cur.satO2 || sv.temperatura != cur.temperatura) {
      widget.onChanged(widget.data.copyWith(signosVitales: sv));
    }
  }

  void _emitEf() {
    final ef = ExamenFisico(
      estadoGeneral: _egCtrl.text, acv: _acvCtrl.text, ar: _arCtrl.text,
      abdomen: _abdCtrl.text, extremidades: _extCtrl.text,
    );
    final cur = widget.data.examenFisico;
    if (ef.estadoGeneral != cur.estadoGeneral || ef.acv != cur.acv ||
        ef.ar != cur.ar || ef.abdomen != cur.abdomen ||
        ef.extremidades != cur.extremidades) {
      widget.onChanged(widget.data.copyWith(examenFisico: ef));
    }
  }

  void _emitEx() {
    final ex = ExamenesComplementarios(
      laboratorio: _labCtrl.text, imagenes: _imgCtrl.text,
      culturas: _cultCtrl.text, ecg: _ecgCtrl.text,
    );
    final cur = widget.data.examenes;
    if (ex.laboratorio != cur.laboratorio || ex.imagenes != cur.imagenes ||
        ex.culturas != cur.culturas || ex.ecg != cur.ecg) {
      widget.onChanged(widget.data.copyWith(examenes: ex));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final theme = InternacionTheme(dark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── SINAIS VITAIS ────────────────────────────────────────────────────
        _SubSection(
          label: isEs ? 'SIGNOS VITALES' : 'SINAIS VITAIS',
          icon: Icons.monitor_heart_rounded,
          dark: dark, theme: theme,
        ),
        const SizedBox(height: 8),
        _VitalsGrid(
          fields: [
            _VitalField(
              ctrl: _paCtrl, label: 'PA', hint: '120/80',
              icon: Icons.favorite_rounded, color: const Color(0xFFEF4444),
              dark: dark, onChanged: (_) => _emitSv(),
              focusNode: _paFocus,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _advanceFrom(_paFocus),
            ),
            _VitalField(
              ctrl: _fcCtrl, label: isEs ? 'FC' : 'FC', hint: '72',
              icon: Icons.monitor_heart_outlined, color: const Color(0xFFF59E0B),
              dark: dark, onChanged: (_) => _emitSv(),
              focusNode: _fcFocus,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _advanceFrom(_fcFocus),
            ),
            _VitalField(
              ctrl: _frCtrl, label: 'FR', hint: '16',
              icon: Icons.air_rounded, color: const Color(0xFF60A5FA),
              dark: dark, onChanged: (_) => _emitSv(),
              focusNode: _frFocus,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _advanceFrom(_frFocus),
            ),
            _VitalField(
              ctrl: _satCtrl, label: 'SatO₂', hint: '98%',
              icon: Icons.bloodtype_rounded, color: const Color(0xFF4ADE80),
              dark: dark, onChanged: (_) => _emitSv(),
              focusNode: _satFocus,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _advanceFrom(_satFocus),
            ),
            _VitalField(
              ctrl: _tempCtrl, label: isEs ? 'Temp.' : 'Temp.',
              hint: '36.5°C',
              icon: Icons.thermostat_rounded, color: const Color(0xFFA78BFA),
              dark: dark, onChanged: (_) => _emitSv(),
              focusNode: _tempFocus,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _advanceFrom(_tempFocus),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // ── EXAME FÍSICO ─────────────────────────────────────────────────────
        _SubSection(
          label: isEs ? 'EXAMEN FÍSICO' : 'EXAME FÍSICO',
          icon: Icons.accessibility_rounded,
          dark: dark, theme: theme,
        ),
        const SizedBox(height: 8),
        _ExamField(
          ctrl: _egCtrl, label: isEs ? 'Estado General' : 'Estado Geral',
          hint: isEs ? 'REG, consciente, orientado…' : 'REG, consciente, orientado…',
          dark: dark, onChanged: (_) => _emitEf(),
          focusNode: _egFocus,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _advanceFrom(_egFocus),
        ),
        const SizedBox(height: 6),
        _ExamField(
          ctrl: _acvCtrl, label: isEs ? 'ACV' : 'ACV',
          hint: isEs ? 'RCR 2T, sem sopros…' : 'RCR 2T, sem sopros…',
          dark: dark, onChanged: (_) => _emitEf(),
          focusNode: _acvFocus,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _advanceFrom(_acvFocus),
        ),
        const SizedBox(height: 6),
        _ExamField(
          ctrl: _arCtrl, label: 'AR',
          hint: isEs ? 'MV+, sin crepitantes…' : 'MV+, sem crepitações…',
          dark: dark, onChanged: (_) => _emitEf(),
          focusNode: _arFocus,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _advanceFrom(_arFocus),
        ),
        const SizedBox(height: 6),
        _ExamField(
          ctrl: _abdCtrl, label: isEs ? 'Abdomen' : 'Abdome',
          hint: isEs ? 'Blando, depresible, no doloroso…' : 'Flácido, indolor…',
          dark: dark, onChanged: (_) => _emitEf(),
          focusNode: _abdFocus,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _advanceFrom(_abdFocus),
        ),
        const SizedBox(height: 6),
        _ExamField(
          ctrl: _extCtrl, label: isEs ? 'Extremidades' : 'Extremidades',
          hint: isEs ? 'Sin edema, pulsos simétricos…' : 'Sem edema, pulsos simétricos…',
          dark: dark, onChanged: (_) => _emitEf(),
          focusNode: _extFocus,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _advanceFrom(_extFocus),
        ),
        const SizedBox(height: 8),

        // ── EXAMES COMPLEMENTARES ────────────────────────────────────────────
        _SubSection(
          label: isEs ? 'EXÁMENES COMPLEMENTARIOS' : 'EXAMES COMPLEMENTARES',
          icon: Icons.science_rounded,
          dark: dark, theme: theme,
        ),
        const SizedBox(height: 8),
        _ExamField(
          ctrl: _labCtrl, label: isEs ? 'Laboratorio' : 'Laboratório',
          hint: isEs ? 'Hb 12, Leuc 8.000, PCR 2…' : 'Hb 12, Leuc 8.000, PCR 2…',
          dark: dark, maxLines: 2, onChanged: (_) => _emitEx(),
          focusNode: _labFocus,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _advanceFrom(_labFocus),
        ),
        const SizedBox(height: 6),
        _ExamField(
          ctrl: _imgCtrl, label: isEs ? 'Imágenes' : 'Imagens',
          hint: isEs ? 'RX Tórax: sin condensación…' : 'RX Tórax: sem condensação…',
          dark: dark, onChanged: (_) => _emitEx(),
          focusNode: _imgFocus,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _advanceFrom(_imgFocus),
        ),
        const SizedBox(height: 6),
        _ExamField(
          ctrl: _cultCtrl, label: isEs ? 'Culturas' : 'Culturas',
          hint: isEs ? 'Hemocultivo pendiente…' : 'Hemocultura pendente…',
          dark: dark, onChanged: (_) => _emitEx(),
          focusNode: _cultFocus,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _advanceFrom(_cultFocus),
        ),
        const SizedBox(height: 6),
        _ExamField(
          ctrl: _ecgCtrl, label: 'ECG',
          hint: isEs ? 'RS, sin alteraciones…' : 'RS, sem alterações…',
          dark: dark, onChanged: (_) => _emitEx(),
          focusNode: _ecgFocus,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _advanceFrom(_ecgFocus),
        ),
        const SizedBox(height: 8),

        // ── TRATAMENTO ATUAL ─────────────────────────────────────────────────
        _SubSection(
          label: isEs ? 'TRATAMIENTO ACTUAL' : 'TRATAMENTO ATUAL',
          icon: Icons.medication_rounded,
          dark: dark, theme: theme,
        ),
        const SizedBox(height: 8),
        _ExamField(
          ctrl: _tratCtrl,
          label: isEs ? 'Medicamentos en uso' : 'Medicamentos em uso',
          hint: isEs
              ? 'AAS 100mg/d, Atorva 40mg/d, Metoprolol 25mg 12/12h…'
              : 'AAS 100mg/d, Atorva 40mg/d, Metoprolol 25mg 12/12h…',
          dark: dark,
          maxLines: 3,
          focusNode: _tratFocus,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _advanceFrom(_tratFocus),
          onChanged: (v) => widget.onChanged(
            widget.data.copyWith(tratamientoActual: v),
          ),
        ),
      ],
    );
  }
}

// ── Sub-section header ────────────────────────────────────────────────────────
class _SubSection extends StatelessWidget {
  // MEDCASES_SOAP4_TRUE_INNER_OBJECTIVE_HEADER_V1
  final String label;
  final IconData icon;
  final bool dark;
  final InternacionTheme theme;

  const _SubSection({
    required this.label,
    required this.icon,
    required this.dark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final line = dark ? const Color(0xFF3A424D) : const Color(0xFFD9DEE6);
    return Row(
      children: [
        Icon(icon, size: 13.5, color: theme.labelColor),
        const SizedBox(width: 6),
        Text(label.toUpperCase(), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.76, color: theme.labelColor)),
        const SizedBox(width: 9),
        Expanded(child: Container(height: 0.7, color: line.withOpacity(0.82))),
      ],
    );
  }
}

// ── Vital signs grid ──────────────────────────────────────────────────────────
class _VitalsGrid extends StatelessWidget {
  // MEDCASES_SOAP4_TRUE_INNER_VITAL_GRID_V1
  final List<_VitalField> fields;
  const _VitalsGrid({required this.fields});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 6) / 2;
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: fields.map((field) => SizedBox(width: width, child: field)).toList(),
        );
      },
    );
  }
}

class _VitalField extends StatelessWidget {
  // MEDCASES_SOAP4_TRUE_INNER_VITAL_METRIC_V1
  // MEDCASES_SOAP4_R1_VITALFIELD_INPUT_CONTRACT_PRESERVED
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final IconData icon;
  final Color color;
  final bool dark;
  final ValueChanged<String> onChanged;
  final FocusNode focusNode;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  const _VitalField({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.icon,
    required this.color,
    required this.dark,
    required this.onChanged,
    required this.focusNode,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final border = dark ? const Color(0xFF3A4350) : const Color(0xFFD5DCE5);
    final text = dark ? const Color(0xFFE8EDF3) : const Color(0xFF1F2937);
    final muted = dark ? const Color(0xFF9AA5B4) : const Color(0xFF667085);
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 7, 9, 5),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: border, width: 0.65),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 12.5, color: color.withOpacity(0.86)),
            const SizedBox(width: 5),
            Expanded(child: Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9.8, fontWeight: FontWeight.w800, letterSpacing: 0.55, color: muted))),
          ]),
          TextField(
            controller: ctrl,
            focusNode: focusNode,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            onChanged: onChanged,
            style: TextStyle(fontSize: 14.2, fontWeight: FontWeight.w700, color: text, height: 1.15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w400, color: muted.withOpacity(0.55)),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.only(top: 4, bottom: 1),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Exam text field ───────────────────────────────────────────────────────────
class _ExamField extends StatelessWidget {
  // MEDCASES_SOAP4_TRUE_INNER_EXAM_ROW_V1
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final bool dark;
  final int maxLines;
  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  const _ExamField({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.dark,
    this.maxLines = 1,
    required this.onChanged,
    this.focusNode,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final border = dark ? const Color(0xFF3A4350) : const Color(0xFFD5DCE5);
    final text = dark ? const Color(0xFFE8EDF3) : const Color(0xFF1F2937);
    final muted = dark ? const Color(0xFF9AA5B4) : const Color(0xFF667085);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: border.withOpacity(0.82), width: 0.6))),
      child: Row(
        crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 96,
            child: Padding(
              padding: const EdgeInsets.only(top: 7, right: 8),
              child: Text(label.toUpperCase(), maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9.8, height: 1.18, fontWeight: FontWeight.w800, letterSpacing: 0.45, color: muted)),
            ),
          ),
          Expanded(
            child: TextField(
              controller: ctrl,
              focusNode: focusNode,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              onSubmitted: onSubmitted,
              maxLines: maxLines,
              minLines: 1,
              onChanged: onChanged,
              style: TextStyle(fontSize: 13.2, height: 1.3, fontWeight: FontWeight.w500, color: text),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(fontSize: 12.2, height: 1.3, fontWeight: FontWeight.w400, color: muted.withOpacity(0.58)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
