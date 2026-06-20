// ─────────────────────────────────────────────────────────────────────────────
// O — OBJETIVO
// Sinais vitais + Exame físico + Exames complementares + Tratamento atual.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../../models/evolucion_model.dart';
import '../internacion_theme.dart';

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

  bool get isEs => widget.lang == 'es';

  @override
  void initState() {
    super.initState();
    final sv = widget.data.signosVitales;
    _paCtrl   = TextEditingController(text: sv.pa);
    _fcCtrl   = TextEditingController(text: sv.fc);
    _frCtrl   = TextEditingController(text: sv.fr);
    _satCtrl  = TextEditingController(text: sv.satO2);
    _tempCtrl = TextEditingController(text: sv.temperatura);

    final ef = widget.data.examenFisico;
    _egCtrl   = TextEditingController(text: ef.estadoGeneral);
    _acvCtrl  = TextEditingController(text: ef.acv);
    _arCtrl   = TextEditingController(text: ef.ar);
    _abdCtrl  = TextEditingController(text: ef.abdomen);
    _extCtrl  = TextEditingController(text: ef.extremidades);

    final ex = widget.data.examenes;
    _labCtrl  = TextEditingController(text: ex.laboratorio);
    _imgCtrl  = TextEditingController(text: ex.imagenes);
    _cultCtrl = TextEditingController(text: ex.culturas);
    _ecgCtrl  = TextEditingController(text: ex.ecg);

    _tratCtrl = TextEditingController(text: widget.data.tratamientoActual);
  }

  @override
  void dispose() {
    for (final c in [
      _paCtrl, _fcCtrl, _frCtrl, _satCtrl, _tempCtrl,
      _egCtrl, _acvCtrl, _arCtrl, _abdCtrl, _extCtrl,
      _labCtrl, _imgCtrl, _cultCtrl, _ecgCtrl, _tratCtrl,
    ]) { c.dispose(); }
    super.dispose();
  }

  void _emitSv() => widget.onChanged(widget.data.copyWith(
    signosVitales: SignosVitales(
      pa: _paCtrl.text, fc: _fcCtrl.text, fr: _frCtrl.text,
      satO2: _satCtrl.text, temperatura: _tempCtrl.text,
    ),
  ));

  void _emitEf() => widget.onChanged(widget.data.copyWith(
    examenFisico: ExamenFisico(
      estadoGeneral: _egCtrl.text, acv: _acvCtrl.text, ar: _arCtrl.text,
      abdomen: _abdCtrl.text, extremidades: _extCtrl.text,
    ),
  ));

  void _emitEx() => widget.onChanged(widget.data.copyWith(
    examenes: ExamenesComplementarios(
      laboratorio: _labCtrl.text, imagenes: _imgCtrl.text,
      culturas: _cultCtrl.text, ecg: _ecgCtrl.text,
    ),
  ));

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
            ),
            _VitalField(
              ctrl: _fcCtrl, label: isEs ? 'FC' : 'FC', hint: '72',
              icon: Icons.monitor_heart_outlined, color: const Color(0xFFF59E0B),
              dark: dark, onChanged: (_) => _emitSv(),
            ),
            _VitalField(
              ctrl: _frCtrl, label: 'FR', hint: '16',
              icon: Icons.air_rounded, color: const Color(0xFF60A5FA),
              dark: dark, onChanged: (_) => _emitSv(),
            ),
            _VitalField(
              ctrl: _satCtrl, label: 'SatO₂', hint: '98%',
              icon: Icons.bloodtype_rounded, color: const Color(0xFF4ADE80),
              dark: dark, onChanged: (_) => _emitSv(),
            ),
            _VitalField(
              ctrl: _tempCtrl, label: isEs ? 'Temp.' : 'Temp.',
              hint: '36.5°C',
              icon: Icons.thermostat_rounded, color: const Color(0xFFA78BFA),
              dark: dark, onChanged: (_) => _emitSv(),
            ),
          ],
        ),
        const SizedBox(height: 16),

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
        ),
        const SizedBox(height: 6),
        _ExamField(
          ctrl: _acvCtrl, label: isEs ? 'ACV' : 'ACV',
          hint: isEs ? 'RCR 2T, sem sopros…' : 'RCR 2T, sem sopros…',
          dark: dark, onChanged: (_) => _emitEf(),
        ),
        const SizedBox(height: 6),
        _ExamField(
          ctrl: _arCtrl, label: 'AR',
          hint: isEs ? 'MV+, sin crepitantes…' : 'MV+, sem crepitações…',
          dark: dark, onChanged: (_) => _emitEf(),
        ),
        const SizedBox(height: 6),
        _ExamField(
          ctrl: _abdCtrl, label: isEs ? 'Abdomen' : 'Abdome',
          hint: isEs ? 'Blando, depresible, no doloroso…' : 'Flácido, indolor…',
          dark: dark, onChanged: (_) => _emitEf(),
        ),
        const SizedBox(height: 6),
        _ExamField(
          ctrl: _extCtrl, label: isEs ? 'Extremidades' : 'Extremidades',
          hint: isEs ? 'Sin edema, pulsos simétricos…' : 'Sem edema, pulsos simétricos…',
          dark: dark, onChanged: (_) => _emitEf(),
        ),
        const SizedBox(height: 16),

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
        ),
        const SizedBox(height: 6),
        _ExamField(
          ctrl: _imgCtrl, label: isEs ? 'Imágenes' : 'Imagens',
          hint: isEs ? 'RX Tórax: sin condensación…' : 'RX Tórax: sem condensação…',
          dark: dark, onChanged: (_) => _emitEx(),
        ),
        const SizedBox(height: 6),
        _ExamField(
          ctrl: _cultCtrl, label: isEs ? 'Culturas' : 'Culturas',
          hint: isEs ? 'Hemocultivo pendiente…' : 'Hemocultura pendente…',
          dark: dark, onChanged: (_) => _emitEx(),
        ),
        const SizedBox(height: 6),
        _ExamField(
          ctrl: _ecgCtrl, label: 'ECG',
          hint: isEs ? 'RS, sin alteraciones…' : 'RS, sem alterações…',
          dark: dark, onChanged: (_) => _emitEx(),
        ),
        const SizedBox(height: 16),

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
  final String label;
  final IconData icon;
  final bool dark;
  final InternacionTheme theme;

  const _SubSection({
    required this.label, required this.icon,
    required this.dark, required this.theme,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 13, color: theme.labelColor),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(
        fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.7,
        color: theme.labelColor,
      )),
    ],
  );
}

// ── Vital signs grid ──────────────────────────────────────────────────────────
class _VitalsGrid extends StatelessWidget {
  final List<_VitalField> fields;
  const _VitalsGrid({required this.fields});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: fields,
    );
  }
}

class _VitalField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final IconData icon;
  final Color color;
  final bool dark;
  final ValueChanged<String> onChanged;

  const _VitalField({
    required this.ctrl, required this.label, required this.hint,
    required this.icon, required this.color,
    required this.dark, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final w = (MediaQuery.of(context).size.width - 32 - 32) / 3;
    return SizedBox(
      width: w.clamp(90, 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: color,
            )),
          ]),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF1A1D23) : const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: dark ? const Color(0xFF2D3340) : const Color(0xFFDDE1E6),
                width: 0.8,
              ),
            ),
            child: TextField(
              controller: ctrl,
              onChanged: onChanged,
              keyboardType: TextInputType.text,
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: dark ? Colors.white : const Color(0xFF1A1D23),
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: dark ? Colors.white24 : Colors.black26,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Exam text field ───────────────────────────────────────────────────────────
class _ExamField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final bool dark;
  final int maxLines;
  final ValueChanged<String> onChanged;

  const _ExamField({
    required this.ctrl, required this.label, required this.hint,
    required this.dark, this.maxLines = 1, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(label, style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: dark ? Colors.white54 : Colors.black54,
            )),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF1A1D23) : const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: dark ? const Color(0xFF2D3340) : const Color(0xFFDDE1E6),
                width: 0.8,
              ),
            ),
            child: TextField(
              controller: ctrl,
              onChanged: onChanged,
              maxLines: maxLines,
              minLines: 1,
              style: TextStyle(
                fontSize: 13,
                color: dark ? Colors.white : const Color(0xFF1A1D23),
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: dark ? Colors.white24 : Colors.black26,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
