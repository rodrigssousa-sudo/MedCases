// ─────────────────────────────────────────────────────────────────────────────
// PatientAccordion — dados clínicos do paciente internado (colapsável).
// Campos: Nome/ID, Cama, Idade, Sexo, Diagnóstico Principal, Dia Internação.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'internacion_theme.dart';

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
    String? nome, String? cama, String? idade, String? sexo,
    String? diagnostico, int? diaInternacao,
  }) => PacienteInternacaoData(
    nome:          nome ?? this.nome,
    cama:          cama ?? this.cama,
    idade:         idade ?? this.idade,
    sexo:          sexo ?? this.sexo,
    diagnostico:   diagnostico ?? this.diagnostico,
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
    _nomeCtrl  = TextEditingController(text: d.nome);
    _camaCtrl  = TextEditingController(text: d.cama);
    _idadeCtrl = TextEditingController(text: d.idade);
    _diagCtrl  = TextEditingController(text: d.diagnostico);
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
    nome:        _nomeCtrl.text,
    cama:        _camaCtrl.text,
    idade:       _idadeCtrl.text,
    diagnostico: _diagCtrl.text,
  ));

  @override
  Widget build(BuildContext context) {
    final theme  = InternacionTheme(widget.dark);
    final dark   = widget.dark;
    final d      = widget.data;

    final subtitle = [
      if (d.nome.isNotEmpty) d.nome,
      if (d.idade.isNotEmpty) '${d.idade} ${isEs ? 'años' : 'anos'}',
      if (d.cama.isNotEmpty) '${isEs ? 'Cama' : 'Leito'} ${d.cama}',
    ].join(' · ');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _open
              ? InternacionTheme.cyan.withValues(alpha: 0.35)
              : theme.border,
          width: 0.8,
        ),
        boxShadow: [theme.softShadow],
      ),
      child: Column(
        children: [
          // ── Header colapsável ──────────────────────────────────────────
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: InternacionTheme.cyan.withValues(alpha: dark ? 0.12 : 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_outline_rounded,
                        size: 18, color: InternacionTheme.cyan),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEs ? 'Datos del Paciente' : 'Dados do Paciente',
                          style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: theme.textPrimary,
                          ),
                        ),
                        Text(
                          subtitle.isEmpty
                              ? (isEs ? 'Toca para completar' : 'Toque para preencher')
                              : subtitle,
                          style: TextStyle(
                            fontSize: 11, color: theme.textSecondary,
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
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        size: 20, color: theme.textSecondary),
                  ),
                ],
              ),
            ),
          ),

          // ── Body ────────────────────────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOut,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(color: theme.divider, height: 1, thickness: 0.8),
                        const SizedBox(height: 12),

                        // Nome / ID
                        _Row(
                          label: isEs ? 'Paciente / ID' : 'Paciente / ID',
                          ctrl: _nomeCtrl,
                          hint: isEs ? 'García López, Juan' : 'Silva, João',
                          dark: dark,
                          onChanged: (_) => _emit(),
                        ),
                        const SizedBox(height: 8),

                        // Cama + Idade
                        Row(children: [
                          Expanded(
                            child: _Row(
                              label: isEs ? 'Cama' : 'Leito',
                              ctrl: _camaCtrl,
                              hint: '12-A',
                              dark: dark,
                              onChanged: (_) => _emit(),
                            ),
                          ),
                          const SizedBox(width: 10),
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
                        ]),
                        const SizedBox(height: 8),

                        // Sexo
                        Text(isEs ? 'Sexo' : 'Sexo', style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w600,
                          color: theme.labelColor,
                        )),
                        const SizedBox(height: 5),
                        Row(children: [
                          _SexChip(
                            label: isEs ? 'Masculino' : 'Masculino',
                            value: 'M',
                            selected: d.sexo,
                            dark: dark,
                            onTap: () => widget.onChanged(d.copyWith(sexo: 'M')),
                          ),
                          const SizedBox(width: 8),
                          _SexChip(
                            label: isEs ? 'Femenino' : 'Feminino',
                            value: 'F',
                            selected: d.sexo,
                            dark: dark,
                            onTap: () => widget.onChanged(d.copyWith(sexo: 'F')),
                          ),
                        ]),
                        const SizedBox(height: 8),

                        // Diagnóstico Principal
                        _Row(
                          label: isEs ? 'Diagnóstico Principal' : 'Diagnóstico Principal',
                          ctrl: _diagCtrl,
                          hint: isEs ? 'ICC Descompensada CF-III (CID I50.0)' : 'ICC Descompensada CF-III (CID I50.0)',
                          dark: dark,
                          onChanged: (_) => _emit(),
                        ),
                        const SizedBox(height: 8),

                        // Dia de Internação
                        Text(isEs ? 'Día de Internación' : 'Dia de Internação',
                            style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w600,
                              color: theme.labelColor,
                            )),
                        const SizedBox(height: 6),
                        Row(children: List.generate(7, (i) {
                          final dia = i + 1;
                          final isSel = d.diaInternacao == dia;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => widget.onChanged(d.copyWith(diaInternacao: dia)),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 130),
                                margin: EdgeInsets.only(right: i < 6 ? 4 : 0),
                                height: 32,
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? InternacionTheme.cyan.withValues(alpha: dark ? 0.20 : 0.12)
                                      : (dark ? const Color(0xFF1E2330) : const Color(0xFFF3F4F6)),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSel ? InternacionTheme.cyan : Colors.transparent,
                                    width: 1.2,
                                  ),
                                ),
                                child: Center(
                                  child: Text('$dia°', style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w400,
                                    color: isSel
                                        ? InternacionTheme.cyan
                                        : theme.textSecondary,
                                  )),
                                ),
                              ),
                            ),
                          );
                        })),
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
    required this.label, required this.ctrl, required this.hint,
    required this.dark, required this.onChanged,
    this.keyboard = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = InternacionTheme(dark);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w600, color: theme.labelColor,
        )),
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
            keyboardType: keyboard,
            style: TextStyle(
              fontSize: 13,
              color: dark ? Colors.white : const Color(0xFF1A1D23),
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
      ],
    );
  }
}

// ── Chip de sexo ──────────────────────────────────────────────────────────────
class _SexChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final bool dark;
  final VoidCallback onTap;

  const _SexChip({
    required this.label, required this.value, required this.selected,
    required this.dark, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? InternacionTheme.cyan.withValues(alpha: InternacionTheme(dark).dark ? 0.18 : 0.10)
              : (dark ? const Color(0xFF1E2330) : const Color(0xFFF3F4F6)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? InternacionTheme.cyan : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
          color: isSelected
              ? InternacionTheme.cyan
              : InternacionTheme(dark).textSecondary,
        )),
      ),
    );
  }
}
