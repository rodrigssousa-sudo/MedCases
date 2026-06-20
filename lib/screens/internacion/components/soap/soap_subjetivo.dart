// ─────────────────────────────────────────────────────────────────────────────
// S — SUBJETIVO
// Entradas rápidas sobre queixas e evolução noturna do paciente.
// Usa estado local via ValueNotifier/setState isolado — zero rebuild global.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../../models/evolucion_model.dart';
import '../internacion_theme.dart';

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
    _nocheCtrl = TextEditingController(text: widget.data.notePasaNoche);
    _notasCtrl = TextEditingController(text: widget.data.notasLibres);
  }

  @override
  void dispose() {
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
        const SizedBox(height: 14),

        // ── Dolor (EVA) ──────────────────────────────────────────────────────
        _SoapLabel(isEs ? 'Dolor (EVA 0–10)' : 'Dor (EVA 0–10)', theme),
        const SizedBox(height: 8),
        _DolorSlider(
          value: d.dolorEscala,
          dark: dark,
          onChanged: (v) => _emit(d.copyWith(dolorEscala: v)),
        ),
        const SizedBox(height: 14),

        // ── Síntomas rápidos (chips) ─────────────────────────────────────────
        _SoapLabel(isEs ? 'Síntomas referidos' : 'Sintomas referidos', theme),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
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
        const SizedBox(height: 14),

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
        const SizedBox(height: 14),

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
  final int? value;
  final bool dark;
  final ValueChanged<int?> onChanged;

  const _DolorSlider({
    required this.value, required this.dark, required this.onChanged,
  });

  Color _colorForVal(int v) {
    if (v <= 3) return const Color(0xFF22C55E);
    if (v <= 6) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final current = value ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(11, (i) {
            final active = i == current && value != null;
            final col = _colorForVal(i);
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(value == i ? null : i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  height: 28,
                  decoration: BoxDecoration(
                    color: active
                        ? col
                        : (dark
                            ? col.withValues(alpha: 0.18)
                            : col.withValues(alpha: 0.12)),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: active ? col : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$i',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w400,
                        color: active
                            ? Colors.white
                            : (dark ? Colors.white54 : Colors.black45),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Sin dolor', style: TextStyle(
              fontSize: 9, color: dark ? Colors.white38 : Colors.black38)),
            Text('Máximo', style: TextStyle(
              fontSize: 9, color: dark ? Colors.white38 : Colors.black38)),
          ],
        ),
      ],
    );
  }
}

// ── Chip de síntoma ───────────────────────────────────────────────────────────
class _SymptomChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final bool dark;
  final VoidCallback onTap;

  const _SymptomChip({
    required this.label, required this.icon,
    required this.active, required this.dark, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const cyan = Color(0xFF059669);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? cyan.withValues(alpha: dark ? 0.18 : 0.12)
              : (dark ? const Color(0xFF1E2330) : const Color(0xFFF3F4F6)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? cyan : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13,
                color: active ? cyan : (dark ? Colors.white38 : Colors.black38)),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(
              fontSize: 11.5,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active ? cyan : (dark ? Colors.white54 : Colors.black54),
            )),
          ],
        ),
      ),
    );
  }
}

// ── Quick 3-opções selector ───────────────────────────────────────────────────
class _QuickSelector extends StatelessWidget {
  final String label;
  final List<String> options;
  final String selected;
  final bool dark;
  final ValueChanged<String> onSelected;

  const _QuickSelector({
    required this.label, required this.options, required this.selected,
    required this.dark, required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w600,
          color: dark ? Colors.white38 : Colors.black38,
          letterSpacing: 0.3,
        )),
        const SizedBox(height: 5),
        ...options.map((opt) {
          final isSelected = selected == opt;
          return GestureDetector(
            onTap: () => onSelected(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF059669).withValues(alpha: dark ? 0.15 : 0.10)
                    : (dark ? const Color(0xFF1E2330) : const Color(0xFFF3F4F6)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF059669)
                      : Colors.transparent,
                  width: 1.2,
                ),
              ),
              child: Text(opt, style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected
                    ? const Color(0xFF059669)
                    : (dark ? Colors.white60 : Colors.black54),
              )),
            ),
          );
        }),
      ],
    );
  }
}

// ── Shared subwidgets ─────────────────────────────────────────────────────────
class _SoapLabel extends StatelessWidget {
  final String text;
  final InternacionTheme theme;
  const _SoapLabel(this.text, this.theme);

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      color: theme.labelColor,
    ),
  );
}

class _SoapTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool dark;
  final int maxLines;
  final ValueChanged<String> onChanged;

  const _SoapTextField({
    required this.controller, required this.hint,
    required this.dark, required this.maxLines, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1A1D23) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: dark ? const Color(0xFF2D3340) : const Color(0xFFDDE1E6),
          width: 0.8,
        ),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        minLines: 1,
        onChanged: onChanged,
        style: TextStyle(
          fontSize: 13,
          color: dark ? Colors.white : const Color(0xFF1A1D23),
          height: 1.5,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 13,
            color: dark ? Colors.white24 : Colors.black26,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }
}
