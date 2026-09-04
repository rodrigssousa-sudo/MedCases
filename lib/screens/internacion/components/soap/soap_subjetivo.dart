// ─────────────────────────────────────────────────────────────────────────────
// S — SUBJETIVO
// Entradas rápidas sobre queixas e evolução noturna do paciente.
// Usa estado local via ValueNotifier/setState isolado — zero rebuild global.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../../models/evolucion_model.dart';
import '../internacion_theme.dart';

import '../../../../design_system/foundation/med_typography.dart';
class SoapSubjetivo extends StatefulWidget {
  final SubjetivoData data;
  final ValueChanged<SubjetivoData> onChanged;
  final bool dark;
  final String lang;

  const SoapSubjetivo({
    super.key,
    required this.data,
    required this.onChanged,
    required this.dark,
    required this.lang,
  });

  @override
  State<SoapSubjetivo> createState() => _SoapSubjetivoState();
}

class _SoapSubjetivoState extends State<SoapSubjetivo> {
  late final TextEditingController _nocheCtrl;
  late final TextEditingController _notasCtrl;

  bool get isEs => widget.lang == 'es';

  @override
  void initState() {
    super.initState();
    _nocheCtrl = TextEditingController(text: widget.data.notePasaNoche)
      ..selection = TextSelection.collapsed(
          offset: widget.data.notePasaNoche.length);
    _notasCtrl = TextEditingController(text: widget.data.notasLibres)
      ..selection = TextSelection.collapsed(
          offset: widget.data.notasLibres.length);
    // Build 205 FIX: addListener captura mudanças programáticas (.text = valor)
    // que NÃO disparam onChanged do TextField. Isso garante que injeção IA
    // via applyAiDraft (que modifica widget.data → didUpdateWidget → ctrl.text=)
    // seja imediatamente refletida no SoapNotifier.
    _nocheCtrl.addListener(_onNocheChanged);
    _notasCtrl.addListener(_onNotasChanged);
  }

  void _onNocheChanged() {
    final v = _nocheCtrl.text;
    if (v != widget.data.notePasaNoche) {
      widget.onChanged(widget.data.copyWith(notePasaNoche: v));
    }
  }

  void _onNotasChanged() {
    final v = _notasCtrl.text;
    if (v != widget.data.notasLibres) {
      widget.onChanged(widget.data.copyWith(notasLibres: v));
    }
  }

  // Build 205 FIX: sincroniza controllers quando widget.data muda externamente
  // (injeção IA via applyAiDraft ou resetSoap). Sem este override, os
  // TextEditingControllers mantêm o valor antigo mesmo quando o notifier é
  // atualizado — causando salvamento de texto obsoleto no Firestore.
  @override
  void didUpdateWidget(SoapSubjetivo oldWidget) {
    super.didUpdateWidget(oldWidget);
    final d    = widget.data;
    final oldD = oldWidget.data;
    if (d.notePasaNoche != oldD.notePasaNoche &&
        d.notePasaNoche != _nocheCtrl.text) {
      _nocheCtrl.text = d.notePasaNoche;
      _nocheCtrl.selection = TextSelection.collapsed(offset: d.notePasaNoche.length);
    }
    if (d.notasLibres != oldD.notasLibres &&
        d.notasLibres != _notasCtrl.text) {
      _notasCtrl.text = d.notasLibres;
      _notasCtrl.selection = TextSelection.collapsed(offset: d.notasLibres.length);
    }
  }

  @override
  void dispose() {
    _nocheCtrl.removeListener(_onNocheChanged);
    _notasCtrl.removeListener(_onNotasChanged);
    _nocheCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  void _emit(SubjetivoData d) => widget.onChanged(d);

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final dark = widget.dark;
    final theme = InternacionTheme(dark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Cómo pasó la noche ───────────────────────────────────────────────
        _SoapLabel(isEs ? 'Cómo pasó la noche' : 'Como passou a noite', theme),
        const SizedBox(height: 6),
        _SoapTextField(
          controller: _nocheCtrl,
          hint: isEs ? 'Ej: Durmió bien, sin despertares nocturnos…'
                     : 'Ex: Dormiu bem, sem despertar noturno…',
          dark: dark,
          maxLines: 2,
          onChanged: (v) => _emit(d.copyWith(notePasaNoche: v)),
        ),
        const SizedBox(height: 8),

        // ── Dolor (EVA) ──────────────────────────────────────────────────────
        _SoapLabel(isEs ? 'Dolor (EVA 0–10)' : 'Dor (EVA 0–10)', theme),
        const SizedBox(height: 8),
        _DolorSlider(
          value: d.dolorEscala,
          dark: dark,
          onChanged: (v) => _emit(d.copyWith(dolorEscala: v)),
        ),
        const SizedBox(height: 8),

        // ── Síntomas rápidos (chips) ─────────────────────────────────────────
        _SoapLabel(isEs ? 'Síntomas referidos' : 'Sintomas referidos', theme),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _SymptomChip(
              label: isEs ? 'Fiebre' : 'Febre',
              icon: Icons.thermostat_rounded,
              active: d.fiebre, dark: dark,
              onTap: () => _emit(d.copyWith(fiebre: !d.fiebre)),
            ),
            _SymptomChip(
              label: isEs ? 'Disnea' : 'Dispneia',
              icon: Icons.air_rounded,
              active: d.disnea, dark: dark,
              onTap: () => _emit(d.copyWith(disnea: !d.disnea)),
            ),
            _SymptomChip(
              label: isEs ? 'Náuseas' : 'Náuseas',
              icon: Icons.sick_rounded,
              active: d.nauseas, dark: dark,
              onTap: () => _emit(d.copyWith(nauseas: !d.nauseas)),
            ),
            _SymptomChip(
              label: isEs ? 'Tos' : 'Tosse',
              icon: Icons.masks_rounded,
              active: d.tos, dark: dark,
              onTap: () => _emit(d.copyWith(tos: !d.tos)),
            ),
            _SymptomChip(
              label: isEs ? 'Sueño alterado' : 'Sono alterado',
              icon: Icons.bedtime_rounded,
              active: d.suenoRestado, dark: dark,
              onTap: () => _emit(d.copyWith(suenoRestado: !d.suenoRestado)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // ── Alimentación / Diuresis / Evacuación ─────────────────────────────
        Row(children: [
          Expanded(
            child: _QuickSelector(
              label: isEs ? 'Alimentación' : 'Alimentação',
              options: isEs
                  ? ['Buena', 'Regular', 'Mala']
                  : ['Boa', 'Regular', 'Ruim'],
              selected: d.alimentacion,
              dark: dark,
              onSelected: (v) => _emit(d.copyWith(alimentacion: v)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QuickSelector(
              label: 'Diuresis',
              options: isEs
                  ? ['Normal', 'Oliguria', 'Anuria']
                  : ['Normal', 'Oligúria', 'Anúria'],
              selected: d.diuresis,
              dark: dark,
              onSelected: (v) => _emit(d.copyWith(diuresis: v)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QuickSelector(
              label: isEs ? 'Evacuación' : 'Evacuação',
              options: isEs
                  ? ['Normal', 'Constipado', 'Diarrea']
                  : ['Normal', 'Constipado', 'Diarreia'],
              selected: d.evacuacion,
              dark: dark,
              onSelected: (v) => _emit(d.copyWith(evacuacion: v)),
            ),
          ),
        ]),
        const SizedBox(height: 8),

        // ── Notas libres ─────────────────────────────────────────────────────
        _SoapLabel(isEs ? 'Notas adicionales' : 'Notas adicionais', theme),
        const SizedBox(height: 6),
        _SoapTextField(
          controller: _notasCtrl,
          hint: isEs ? 'Otras quejas o comentarios del paciente…'
                     : 'Outras queixas ou comentários do paciente…',
          dark: dark,
          maxLines: 3,
          onChanged: (v) => _emit(d.copyWith(notasLibres: v)),
        ),
      ],
    );
  }
}

// ── Dolor Slider ──────────────────────────────────────────────────────────────
class _DolorSlider extends StatelessWidget {
  // MEDCASES_SOAP4_TRUE_INNER_EVA_RAIL_V1
  final int? value;
  final bool dark;
  final ValueChanged<int?> onChanged;

  const _DolorSlider({
    required this.value,
    required this.dark,
    required this.onChanged,
  });

  Color _colorForVal(int v) {
    if (v <= 3) return const Color(0xFF10B981);
    if (v <= 6) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final border = dark ? const Color(0xFF3B4350) : const Color(0xFFD6DDE6);
    final idle = dark ? const Color(0xFF9AA5B4) : const Color(0xFF667085);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 30,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: border, width: 0.7),
          ),
          child: Row(
            children: List.generate(21, (index) {
              if (index.isOdd) {
                return Container(width: 0.55, color: border.withOpacity(0.78));
              }
              final v = index ~/ 2;
              final active = value == v;
              final color = _colorForVal(v);
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(active ? null : v),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 130),
                    alignment: Alignment.center,
                    color: active ? color.withOpacity(dark ? 0.28 : 0.14) : Colors.transparent,
                    child: Text(
                      '$v',
                      style: TextStyle(
                        fontSize: 11.2,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                        color: active ? color : idle,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Sin dolor', style: TextStyle(fontSize: 9.5, color: idle.withOpacity(0.72))),
            Text('Máximo', style: TextStyle(fontSize: 9.5, color: idle.withOpacity(0.72))),
          ],
        ),
      ],
    );
  }
}

// ── Chip de síntoma ───────────────────────────────────────────────────────────
class _SymptomChip extends StatelessWidget {
  // MEDCASES_SOAP4_TRUE_INNER_OUTLINE_SYMPTOM_V1
  final String label;
  final IconData icon;
  final bool active;
  final bool dark;
  final VoidCallback onTap;

  const _SymptomChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF0D6B57);
    final border = dark ? const Color(0xFF3A4350) : const Color(0xFFD5DCE5);
    final idle = dark ? const Color(0xFFAEB7C4) : const Color(0xFF5F6B7A);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: active ? accent.withOpacity(dark ? 0.13 : 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: active ? accent.withOpacity(0.78) : border, width: 0.7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: active ? accent : idle.withOpacity(0.72)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(fontSize: 11.5, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? accent : idle),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick 3-opções selector ───────────────────────────────────────────────────
class _QuickSelector extends StatelessWidget {
  // MEDCASES_SOAP4_TRUE_INNER_CONTIGUOUS_SELECTOR_V1
  final String label;
  final List<String> options;
  final String selected;
  final bool dark;
  final ValueChanged<String> onSelected;

  const _QuickSelector({
    required this.label,
    required this.options,
    required this.selected,
    required this.dark,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF0D6B57);
    final border = dark ? const Color(0xFF3A4350) : const Color(0xFFD5DCE5);
    final idle = dark ? const Color(0xFFAEB7C4) : const Color(0xFF5F6B7A);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10.3, fontWeight: FontWeight.w700, color: idle.withOpacity(0.88))),
        const SizedBox(height: 5),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: border, width: 0.7),
          ),
          child: Column(
            children: List.generate(options.length * 2 - 1, (index) {
              if (index.isOdd) return Container(height: 0.55, color: border.withOpacity(0.82));
              final option = options[index ~/ 2];
              final active = selected == option;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelected(option),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 130),
                  height: 31,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  color: active ? accent.withOpacity(dark ? 0.13 : 0.08) : Colors.transparent,
                  child: Text(option,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? accent : idle)),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

// ── Shared subwidgets ─────────────────────────────────────────────────────────
class _SoapLabel extends StatelessWidget {
  // MEDCASES_SOAP4_TRUE_INNER_EDITORIAL_LABEL_V1
  final String text;
  final InternacionTheme theme;

  const _SoapLabel(this.text, this.theme);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final line = dark ? const Color(0xFF3A424D) : const Color(0xFFD9DEE6);
    return Row(
      children: [
        Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.78,
            color: theme.labelColor,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(child: Container(height: 0.7, color: line.withOpacity(0.82))),
      ],
    );
  }
}

class _SoapTextField extends StatelessWidget {
  // MEDCASES_SOAP4_TRUE_INNER_FLAT_TEXT_V1
  final TextEditingController controller;
  final String hint;
  final bool dark;
  final int maxLines;
  final ValueChanged<String> onChanged;

  const _SoapTextField({
    required this.controller,
    required this.hint,
    required this.dark,
    required this.maxLines,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final divider = dark ? const Color(0xFF3B4350) : const Color(0xFFD6DDE6);
    final value = dark ? const Color(0xFFE8EDF3) : const Color(0xFF1F2937);
    final hintColor = dark ? const Color(0xFF7D8795) : const Color(0xFF7B8491);
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 1, 2, 2),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: divider.withOpacity(0.82), width: 0.7)),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        minLines: 1,
        onChanged: onChanged,
        style: TextStyle(fontSize: 13.5, height: 1.34, fontWeight: FontWeight.w500, color: value),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 12.6, height: 1.3, fontWeight: FontWeight.w400, color: hintColor),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 7),
        ),
      ),
    );
  }
}
