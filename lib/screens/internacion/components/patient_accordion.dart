// ─────────────────────────────────────────────────────────────────────────────
// PatientAccordion — dados clínicos do paciente internado (colapsável).
// Campos: Nome/ID, Cama, Idade, Sexo, Diagnóstico Principal, Dia Internação.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'internacion_theme.dart';

import '../../../design_system/foundation/med_typography.dart';
// Model local simples para os dados do paciente internado
class PacienteInternacaoData {
  final String nome;
  final String cama;
  final String idade;
  final String sexo;
  final String diagnostico;
  final int diaInternacao;

  const PacienteInternacaoData({
    this.nome = '',
    this.cama = '',
    this.idade = '',
    this.sexo = '',
    this.diagnostico = '',
    this.diaInternacao = 1,
  });

  PacienteInternacaoData copyWith({
    String? nome,
    String? cama,
    String? idade,
    String? sexo,
    String? diagnostico,
    int? diaInternacao,
  }) =>
      PacienteInternacaoData(
        nome: nome ?? this.nome,
        cama: cama ?? this.cama,
        idade: idade ?? this.idade,
        sexo: sexo ?? this.sexo,
        diagnostico: diagnostico ?? this.diagnostico,
        diaInternacao: diaInternacao ?? this.diaInternacao,
      );
}

class PatientAccordion extends StatefulWidget {
  final PacienteInternacaoData data;
  final bool dark;
  final String lang;
  final ValueChanged<PacienteInternacaoData> onChanged;

  const PatientAccordion({
    super.key,
    required this.data,
    required this.dark,
    required this.lang,
    required this.onChanged,
  });

  @override
  State<PatientAccordion> createState() => _PatientAccordionState();
}

class _PatientAccordionState extends State<PatientAccordion> {
  bool _open = false;

  late final TextEditingController _nomeCtrl;
  late final TextEditingController _camaCtrl;
  late final TextEditingController _idadeCtrl;
  late final TextEditingController _diagCtrl;

  bool get isEs => widget.lang == 'es';

  @override
  void initState() {
    super.initState();
    final d = widget.data;
    _nomeCtrl = TextEditingController(text: d.nome);
    _camaCtrl = TextEditingController(text: d.cama);
    _idadeCtrl = TextEditingController(text: d.idade);
    _diagCtrl = TextEditingController(text: d.diagnostico);
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _camaCtrl.dispose();
    _idadeCtrl.dispose();
    _diagCtrl.dispose();
    super.dispose();
  }

  void _emit() => widget.onChanged(widget.data.copyWith(
        nome: _nomeCtrl.text,
        cama: _camaCtrl.text,
        idade: _idadeCtrl.text,
        diagnostico: _diagCtrl.text,
      ));

  @override
  Widget build(BuildContext context) {
    final theme = InternacionTheme(widget.dark);
    final dark = widget.dark;
    final d = widget.data;

    final subtitle = [
      if (d.nome.isNotEmpty) d.nome,
      if (d.idade.isNotEmpty) '${d.idade} ${isEs ? 'años' : 'anos'}',
      if (d.cama.isNotEmpty) '${isEs ? 'Cama' : 'Leito'} ${d.cama}',
    ].join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12.5, 12, 12.5),
            child: Row(
              children: [
                const SizedBox(
                  width: 28,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(
                      Icons.person_outline_rounded,
                      size: 18,
                      color: InternacionTheme.cyan,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEs ? 'Datos del Paciente' : 'Dados do Paciente',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: theme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle.isEmpty
                            ? (isEs
                                ? 'Toca para completar'
                                : 'Toque para preencher')
                            : subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: theme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOut,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Divider(
                        color: theme.divider,
                        height: 1,
                        thickness: 0.7,
                      ),
                      const SizedBox(height: 8),
                      // MEDICAL_REFINEMENT_V1_PATIENT_SHEET
                      Row(
                        children: [
                          Icon(
                            Icons.badge_outlined,
                            size: 13,
                            color: theme.accent.withOpacity(0.88),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'FICHA CLÍNICA',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.85,
                              color: theme.accent.withOpacity(0.88),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _Row(
                        label: isEs ? 'Paciente / ID' : 'Paciente / ID',
                        ctrl: _nomeCtrl,
                        hint: isEs ? 'García López, Juan' : 'Silva, João',
                        dark: dark,
                        onChanged: (_) => _emit(),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _Row(
                              label: isEs ? 'Cama' : 'Leito',
                              ctrl: _camaCtrl,
                              hint: '12-A',
                              dark: dark,
                              onChanged: (_) => _emit(),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _Row(
                              label: isEs ? 'Edad' : 'Idade',
                              ctrl: _idadeCtrl,
                              hint: '58',
                              dark: dark,
                              keyboard: TextInputType.number,
                              onChanged: (_) => _emit(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _PatientSexToggle(
                        isEs: isEs,
                        selected: d.sexo,
                        onChanged: (sexo) =>
                            widget.onChanged(d.copyWith(sexo: sexo)),
                      ),
                      const SizedBox(height: 6),
                      _Row(
                        label: isEs
                            ? 'Diagnóstico Principal'
                            : 'Diagnóstico Principal',
                        ctrl: _diagCtrl,
                        hint: isEs
                            ? 'ICC Descompensada CF-III (CID I50.0)'
                            : 'ICC Descompensada CF-III (CID I50.0)',
                        dark: dark,
                        onChanged: (_) => _emit(),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isEs ? 'Día de Internación' : 'Dia de Internação',
                        style: TextStyle(
                          fontSize: MedTypography.microTextSize,
                          fontWeight: FontWeight.w600,
                          color: theme.labelColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: List.generate(7, (i) {
                          final dia = i + 1;
                          final isSel = d.diaInternacao == dia;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => widget.onChanged(
                                d.copyWith(diaInternacao: dia),
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 130),
                                margin: EdgeInsets.only(right: i < 6 ? 4 : 0),
                                height: 28,
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? InternacionTheme.cyan
                                          .withOpacity(dark ? 0.20 : 0.12)
                                      : (dark
                                          ? const Color(0xFF1E2330)
                                          : const Color(0xFFF3F4F6)),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSel
                                        ? InternacionTheme.cyan
                                        : Colors.transparent,
                                    width: 0.8,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '$dia°',
                                    style: TextStyle(
                                      fontSize: MedTypography.microTextSize,
                                      fontWeight: isSel
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: isSel
                                          ? InternacionTheme.cyan
                                          : theme.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
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

// ── Row field helper ──────────────────────────────────────────────────────────
class _Row extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String hint;
  final bool dark;
  final TextInputType keyboard;
  final ValueChanged<String> onChanged;

  const _Row({
    required this.label,
    required this.ctrl,
    required this.hint,
    required this.dark,
    required this.onChanged,
    this.keyboard = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = InternacionTheme(dark);
    final divider = dark ? const Color(0xFF3B4350) : const Color(0xFFD6DDE6);
    final valueColor = dark ? const Color(0xFFF1F5F9) : const Color(0xFF17202A);

    return Container(
      padding: const EdgeInsets.only(left: 10, right: 2, bottom: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: divider.withOpacity(0.82), width: 0.7),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 2,
            height: 34,
            margin: const EdgeInsets.only(bottom: 1),
            decoration: BoxDecoration(
              color: theme.accent.withOpacity(dark ? 0.74 : 0.62),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.55,
                    color: theme.labelColor.withOpacity(0.90),
                  ),
                ),
                const SizedBox(height: 1),
                TextField(
                  controller: ctrl,
                  onChanged: onChanged,
                  keyboardType: keyboard,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.18,
                    fontWeight: FontWeight.w600,
                    color: valueColor,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                      color: dark ? Colors.white24 : Colors.black26,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chip de sexo ──────────────────────────────────────────────────────────────
class _PatientSexToggle extends StatelessWidget {
  final bool isEs;
  final String selected;
  final ValueChanged<String> onChanged;

  const _PatientSexToggle({
    required this.isEs,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = InternacionTheme.cyan;
    final border = dark ? const Color(0xFF3A4350) : const Color(0xFFD8DEE7);
    final idleText = dark ? const Color(0xFFB9C2D0) : const Color(0xFF566273);

    Widget option({
      required String value,
      required String text,
      required IconData icon,
    }) {
      final active = selected == value;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: active
                  ? accent.withOpacity(dark ? 0.16 : 0.10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: active
                    ? accent.withOpacity(dark ? 0.74 : 0.62)
                    : Colors.transparent,
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: active ? accent : idleText.withOpacity(0.76),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? accent : idleText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Container(
          height: 34,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: dark
                ? const Color(0xFF1C2129).withOpacity(0.72)
                : const Color(0xFFF5F7F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border.withOpacity(0.72), width: 0.6),
          ),
          child: Row(
            children: [
              option(
                value: 'M',
                text: 'Masculino',
                icon: Icons.male_rounded,
              ),
              const SizedBox(width: 2),
              option(
                value: 'F',
                text: isEs ? 'Femenino' : 'Feminino',
                icon: Icons.female_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
