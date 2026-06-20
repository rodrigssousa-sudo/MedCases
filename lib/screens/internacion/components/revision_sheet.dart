// ─────────────────────────────────────────────────────────────────────────────
// RevisionSheet — Build 160 — Human-in-the-Loop Review Modal
//
// Exibe os dados extraídos pela IA campo a campo, visualmente.
// O médico decide: [Descartar] ou [Aprovar e Rellenar].
// NENHUM dado é injetado sem aprovação explícita.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../services/soap_copilot_service.dart';
import 'internacion_theme.dart';

class RevisionSheet extends StatelessWidget {
  final SoapDraftResult draft;
  final bool dark;
  final String lang;
  final VoidCallback onDiscard;
  final VoidCallback onApprove;

  const RevisionSheet({
    super.key,
    required this.draft,
    required this.dark,
    required this.lang,
    required this.onDiscard,
    required this.onApprove,
  });

  bool get isEs => lang == 'es';

  // ── Abre como bottom sheet modal ──────────────────────────────────────────
  static Future<void> show({
    required BuildContext context,
    required SoapDraftResult draft,
    required bool dark,
    required String lang,
    required VoidCallback onDiscard,
    required VoidCallback onApprove,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RevisionSheet(
        draft: draft,
        dark: dark,
        lang: lang,
        onDiscard: onDiscard,
        onApprove: onApprove,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = InternacionTheme(dark);
    final bg = dark ? const Color(0xFF0F1116) : Colors.white;
    // Conta SOAP + demográficos + fármacos extraídos
    int filled = draft.filledCount; // já inclui farmacos via filledCount
    if (draft.pacienteNome?.isNotEmpty == true) filled++;
    if (draft.pacienteCama?.isNotEmpty == true) filled++;
    if (draft.pacienteIdade?.isNotEmpty == true) filled++;
    if (draft.pacienteSexo?.isNotEmpty == true) filled++;
    if (draft.pacienteDiagnostico?.isNotEmpty == true) filled++;
    if (draft.pacienteDiaInternacion != null) filled++;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: InternacionTheme.cyan.withValues(alpha: 0.30),
            width: 1.2,
          ),
        ),
        child: Column(
          children: [
            // ── Handle drag ──────────────────────────────────────────────
            const SizedBox(height: 10),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: theme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // ── Header ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF059669), Color(0xFF047857)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded,
                        size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEs ? 'Revisión Inteligente' : 'Revisão Inteligente',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: theme.textPrimary,
                          ),
                        ),
                        Text(
                          isEs
                              ? '$filled campo${filled != 1 ? 's' : ''} extraído${filled != 1 ? 's' : ''} por la IA'
                              : '$filled campo${filled != 1 ? 's' : ''} extraído${filled != 1 ? 's' : ''} pela IA',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: InternacionTheme.cyan,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: InternacionTheme.amber.withValues(alpha: dark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: InternacionTheme.amber.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 14, color: InternacionTheme.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isEs
                            ? 'Revisa los datos antes de aprobar. Solo tú decides qué se rellena.'
                            : 'Revise os dados antes de aprovar. Só você decide o que é preenchido.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: InternacionTheme.amber,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            Divider(color: theme.border, height: 1, thickness: 0.8),

            // ── Lista de campos extraídos ─────────────────────────────────
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                children: _buildAllFields(theme),
              ),
            ),

            // ── Botões ───────────────────────────────────────────────────
            Divider(color: theme.border, height: 1, thickness: 0.8),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20, 14, 20,
                14 + MediaQuery.of(context).viewPadding.bottom,
              ),
              child: Row(
                children: [
                  // Descartar
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        onDiscard();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: theme.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.border, width: 0.9),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.close_rounded,
                                size: 16, color: theme.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              isEs ? 'Descartar' : 'Descartar',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: theme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Aprobar y Rellenar
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        onApprove();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF059669), Color(0xFF047857)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: InternacionTheme.cyan.withValues(alpha: 0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              isEs ? 'Aprobar y Rellenar' : 'Aprovar e Preencher',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Constrói todas as cards de dados extraídos ────────────────────────────
  List<Widget> _buildAllFields(InternacionTheme theme) {
    final widgets = <Widget>[];

    // ─── DEMOGRÁFICO DO PACIENTE (Build 161) ─────────────────────────────
    final hasDemog = draft.hasPatientData;
    if (hasDemog) {
      widgets.add(_demogSectionHeader(theme));
      if (draft.pacienteNome?.isNotEmpty == true)
        widgets.add(_fieldCard(
          icon: Icons.person_rounded,
          label: isEs ? 'Nombre del paciente' : 'Nome do paciente',
          value: draft.pacienteNome!,
          theme: theme, section: SoapSection.s,
        ));
      if (draft.pacienteCama?.isNotEmpty == true)
        widgets.add(_fieldCard(
          icon: Icons.bed_rounded,
          label: isEs ? 'Cama / Leito' : 'Leito / Cama',
          value: draft.pacienteCama!,
          theme: theme, section: SoapSection.s,
        ));
      if (draft.pacienteIdade?.isNotEmpty == true)
        widgets.add(_fieldCard(
          icon: Icons.cake_rounded,
          label: isEs ? 'Edad' : 'Idade',
          value: draft.pacienteIdade!,
          theme: theme, section: SoapSection.s,
        ));
      if (draft.pacienteSexo?.isNotEmpty == true)
        widgets.add(_fieldCard(
          icon: Icons.wc_rounded,
          label: isEs ? 'Sexo' : 'Sexo',
          value: draft.pacienteSexo == 'M'
              ? (isEs ? 'Masculino' : 'Masculino')
              : (isEs ? 'Femenino' : 'Feminino'),
          theme: theme, section: SoapSection.s,
        ));
      if (draft.pacienteDiagnostico?.isNotEmpty == true)
        widgets.add(_fieldCard(
          icon: Icons.local_hospital_rounded,
          label: isEs ? 'Diagnóstico principal' : 'Diagnóstico principal',
          value: draft.pacienteDiagnostico!,
          theme: theme, section: SoapSection.s,
        ));
      if (draft.pacienteDiaInternacion != null)
        widgets.add(_fieldCard(
          icon: Icons.calendar_today_rounded,
          label: isEs ? 'Día de internación' : 'Dia de internação',
          value: '${isEs ? 'Día' : 'Dia'} ${draft.pacienteDiaInternacion}',
          theme: theme, section: SoapSection.s,
        ));
      widgets.add(const SizedBox(height: 8));
    }

    // ─── S — SUBJETIVO ────────────────────────────────────────────────────
    widgets.add(_sectionHeader(
      'S — ${isEs ? 'Subjetivo' : 'Subjetivo'}',
      SoapSection.s, theme,
    ));

    if (draft.notePasaNoche?.isNotEmpty == true)
      widgets.add(_fieldCard(
        icon: Icons.nightlight_round,
        label: isEs ? 'Cómo pasó la noche' : 'Como passou a noite',
        value: draft.notePasaNoche!,
        theme: theme, section: SoapSection.s,
      ));

    if (draft.dolorEscala != null)
      widgets.add(_fieldCard(
        icon: Icons.personal_injury_rounded,
        label: 'EVA — ${isEs ? 'Dolor' : 'Dor'}',
        value: '${draft.dolorEscala}/10',
        theme: theme, section: SoapSection.s,
        chip: _evaChip(draft.dolorEscala!, theme),
      ));

    final symptoms = <String>[];
    if (draft.fiebre == true) symptoms.add(isEs ? 'Fiebre' : 'Febre');
    if (draft.disnea == true) symptoms.add(isEs ? 'Disnea' : 'Dispneia');
    if (draft.nauseas == true) symptoms.add(isEs ? 'Náuseas' : 'Náuseas');
    if (draft.tos == true) symptoms.add(isEs ? 'Tos' : 'Tosse');
    if (draft.suenoRestado == true) symptoms.add(isEs ? 'Sueño ↓' : 'Sono ↓');
    if (symptoms.isNotEmpty)
      widgets.add(_chipsCard(
        icon: Icons.warning_amber_rounded,
        label: isEs ? 'Síntomas detectados' : 'Sintomas detectados',
        chips: symptoms, theme: theme, section: SoapSection.s,
      ));

    if (draft.alimentacion?.isNotEmpty == true)
      widgets.add(_fieldCard(
        icon: Icons.restaurant_rounded,
        label: isEs ? 'Alimentación' : 'Alimentação',
        value: draft.alimentacion!,
        theme: theme, section: SoapSection.s,
      ));
    if (draft.diuresis?.isNotEmpty == true)
      widgets.add(_fieldCard(
        icon: Icons.water_drop_rounded,
        label: isEs ? 'Diuresis' : 'Diurese',
        value: draft.diuresis!,
        theme: theme, section: SoapSection.s,
      ));
    if (draft.evacuacion?.isNotEmpty == true)
      widgets.add(_fieldCard(
        icon: Icons.swap_vert_rounded,
        label: isEs ? 'Evacuación' : 'Evacuação',
        value: draft.evacuacion!,
        theme: theme, section: SoapSection.s,
      ));
    if (draft.notasLibresSubjetivo?.isNotEmpty == true)
      widgets.add(_fieldCard(
        icon: Icons.notes_rounded,
        label: isEs ? 'Notas libres' : 'Notas livres',
        value: draft.notasLibresSubjetivo!,
        theme: theme, section: SoapSection.s,
      ));

    // ─── O — OBJETIVO ─────────────────────────────────────────────────────
    final hasVitals = [draft.pa, draft.fc, draft.fr, draft.satO2, draft.temperatura]
        .any((v) => v?.isNotEmpty == true);
    if (hasVitals) {
      widgets.add(const SizedBox(height: 8));
      widgets.add(_sectionHeader(
        'O — ${isEs ? 'Objetivo' : 'Objetivo'} · ${isEs ? 'Signos Vitales' : 'Sinais Vitais'}',
        SoapSection.o, theme,
      ));
      widgets.add(_vitalsCard(theme));
    }

    final hasExamen = [draft.estadoGeneral, draft.acv, draft.ar, draft.abdomen, draft.extremidades]
        .any((v) => v?.isNotEmpty == true);
    if (hasExamen) {
      widgets.add(const SizedBox(height: 8));
      widgets.add(_sectionHeader(
        'O · ${isEs ? 'Examen Físico' : 'Exame Físico'}',
        SoapSection.o, theme,
      ));
      if (draft.estadoGeneral?.isNotEmpty == true)
        widgets.add(_fieldCard(icon: Icons.person_rounded, label: isEs ? 'Estado general' : 'Estado geral', value: draft.estadoGeneral!, theme: theme, section: SoapSection.o));
      if (draft.acv?.isNotEmpty == true)
        widgets.add(_fieldCard(icon: Icons.favorite_rounded, label: 'ACV', value: draft.acv!, theme: theme, section: SoapSection.o));
      if (draft.ar?.isNotEmpty == true)
        widgets.add(_fieldCard(icon: Icons.air_rounded, label: 'AR', value: draft.ar!, theme: theme, section: SoapSection.o));
      if (draft.abdomen?.isNotEmpty == true)
        widgets.add(_fieldCard(icon: Icons.crop_square_rounded, label: isEs ? 'Abdomen' : 'Abdome', value: draft.abdomen!, theme: theme, section: SoapSection.o));
      if (draft.extremidades?.isNotEmpty == true)
        widgets.add(_fieldCard(icon: Icons.accessibility_rounded, label: isEs ? 'Extremidades' : 'Extremidades', value: draft.extremidades!, theme: theme, section: SoapSection.o));
    }

    final hasExams = [draft.laboratorio, draft.imagenes, draft.culturas, draft.ecg]
        .any((v) => v?.isNotEmpty == true);
    if (hasExams) {
      widgets.add(const SizedBox(height: 8));
      widgets.add(_sectionHeader('O · ${isEs ? 'Exámenes' : 'Exames'}', SoapSection.o, theme));
      if (draft.laboratorio?.isNotEmpty == true)
        widgets.add(_fieldCard(icon: Icons.biotech_rounded, label: isEs ? 'Laboratorio' : 'Laboratório', value: draft.laboratorio!, theme: theme, section: SoapSection.o));
      if (draft.imagenes?.isNotEmpty == true)
        widgets.add(_fieldCard(icon: Icons.image_rounded, label: isEs ? 'Imágenes' : 'Imagens', value: draft.imagenes!, theme: theme, section: SoapSection.o));
      if (draft.culturas?.isNotEmpty == true)
        widgets.add(_fieldCard(icon: Icons.science_rounded, label: isEs ? 'Culturas' : 'Culturas', value: draft.culturas!, theme: theme, section: SoapSection.o));
      if (draft.ecg?.isNotEmpty == true)
        widgets.add(_fieldCard(icon: Icons.monitor_heart_outlined, label: 'ECG', value: draft.ecg!, theme: theme, section: SoapSection.o));
    }

    if (draft.tratamientoActual?.isNotEmpty == true) {
      widgets.add(_fieldCard(
        icon: Icons.medication_rounded,
        label: isEs ? 'Tratamiento actual' : 'Tratamento atual',
        value: draft.tratamientoActual!,
        theme: theme, section: SoapSection.o,
      ));
    }

    // ─── A — EVALUACIÓN ───────────────────────────────────────────────────
    final hasEval = draft.estadoClinical?.isNotEmpty == true ||
        (draft.problemasActivos?.isNotEmpty == true) ||
        draft.notasEvaluacion?.isNotEmpty == true;
    if (hasEval) {
      widgets.add(const SizedBox(height: 8));
      widgets.add(_sectionHeader('A — ${isEs ? 'Evaluación' : 'Avaliação'}', SoapSection.a, theme));
      if (draft.estadoClinical?.isNotEmpty == true)
        widgets.add(_fieldCard(
          icon: Icons.trending_up_rounded,
          label: isEs ? 'Estado clínico' : 'Estado clínico',
          value: _translateEstado(draft.estadoClinical!),
          theme: theme, section: SoapSection.a,
        ));
      if (draft.problemasActivos?.isNotEmpty == true)
        widgets.add(_chipsCard(
          icon: Icons.list_alt_rounded,
          label: isEs ? 'Problemas activos' : 'Problemas ativos',
          chips: draft.problemasActivos!,
          theme: theme, section: SoapSection.a,
        ));
      if (draft.notasEvaluacion?.isNotEmpty == true)
        widgets.add(_fieldCard(
          icon: Icons.notes_rounded,
          label: isEs ? 'Notas de evaluación' : 'Notas de avaliação',
          value: draft.notasEvaluacion!,
          theme: theme, section: SoapSection.a,
        ));
    }

    // ─── P — PLAN ─────────────────────────────────────────────────────────
    final hasPlan = draft.planTerapeutico?.isNotEmpty == true ||
        draft.criteriosAlta?.isNotEmpty == true;
    if (hasPlan) {
      widgets.add(const SizedBox(height: 8));
      widgets.add(_sectionHeader('P — Plan', SoapSection.p, theme));
      if (draft.planTerapeutico?.isNotEmpty == true)
        widgets.add(_fieldCard(
          icon: Icons.assignment_rounded,
          label: isEs ? 'Plan terapéutico' : 'Plano terapêutico',
          value: draft.planTerapeutico!,
          theme: theme, section: SoapSection.p,
        ));
      if (draft.criteriosAlta?.isNotEmpty == true)
        widgets.add(_fieldCard(
          icon: Icons.exit_to_app_rounded,
          label: isEs ? 'Criterios de alta' : 'Critérios de alta',
          value: draft.criteriosAlta!,
          theme: theme, section: SoapSection.p,
        ));
    }

    // ─── FÁRMACOS (Build 162) ──────────────────────────────────────────────
    if (draft.farmacos?.isNotEmpty == true) {
      widgets.add(const SizedBox(height: 8));
      widgets.add(_sectionHeader(
        isEs ? '💊 Fármacos detectados' : '💊 Fármacos detectados',
        SoapSection.o, theme,
      ));
      for (final f in draft.farmacos!) {
        final med = f['medicamento'] ?? '';
        final dos = f['dosagem']     ?? '';
        if (med.isEmpty) continue;
        widgets.add(_fieldCard(
          icon: Icons.medication_outlined,
          label: med,
          value: dos.isNotEmpty ? dos : (isEs ? '(sin dosificación)' : '(sem dosagem)'),
          theme: theme,
          section: SoapSection.o,
        ));
      }
    }

    if (widgets.isEmpty || (widgets.length == 1)) {
      widgets.add(_emptyState(theme));
    }

    widgets.add(const SizedBox(height: 16));
    return widgets;
  }

  // ── Header de seção DEMOGRÁFICO (Build 161) ───────────────────────────────
  Widget _demogSectionHeader(InternacionTheme theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: InternacionTheme.cyan.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_pin_rounded,
                    size: 12, color: InternacionTheme.cyan),
                const SizedBox(width: 5),
                Text(
                  isEs ? 'DATOS DEL PACIENTE' : 'DADOS DO PACIENTE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: InternacionTheme.cyan,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: InternacionTheme.cyan.withValues(alpha: 0.25),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header de seção SOAP ──────────────────────────────────────────────────
  Widget _sectionHeader(String label, SoapSection section, InternacionTheme theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: theme.soapTagBg(section),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: theme.soapTagFg(section),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Card de campo individual ──────────────────────────────────────────────
  Widget _fieldCard({
    required IconData icon,
    required String label,
    required String value,
    required InternacionTheme theme,
    required SoapSection section,
    Widget? chip,
  }) {
    final fg = theme.soapTagFg(section);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.border, width: 0.8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: fg.withValues(alpha: 0.8)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(
                    fontSize: 10.5, fontWeight: FontWeight.w600,
                    color: theme.textSecondary,
                  )),
                  const SizedBox(height: 3),
                  Text(value, style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500,
                    color: theme.textPrimary, height: 1.4,
                  )),
                ],
              ),
            ),
            if (chip != null) ...[const SizedBox(width: 8), chip],
          ],
        ),
      ),
    );
  }

  // ── Card de chips (lista de sintomas/problemas) ───────────────────────────
  Widget _chipsCard({
    required IconData icon,
    required String label,
    required List<String> chips,
    required InternacionTheme theme,
    required SoapSection section,
  }) {
    final fg = theme.soapTagFg(section);
    final bg = theme.soapTagBg(section);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.border, width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 16, color: fg.withValues(alpha: 0.8)),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w600,
                color: theme.textSecondary,
              )),
            ]),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: chips.map((c) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(c, style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w600, color: fg,
                )),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Card de sinais vitais (grid 2x3) ─────────────────────────────────────
  Widget _vitalsCard(InternacionTheme theme) {
    final vitals = <String, String>{};
    if (draft.pa?.isNotEmpty == true) vitals['PA'] = draft.pa!;
    if (draft.fc?.isNotEmpty == true) vitals['FC'] = draft.fc!;
    if (draft.fr?.isNotEmpty == true) vitals['FR'] = draft.fr!;
    if (draft.satO2?.isNotEmpty == true) vitals['SpO₂'] = draft.satO2!;
    if (draft.temperatura?.isNotEmpty == true) vitals['T°'] = draft.temperatura!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.soapTagFg(SoapSection.o).withValues(alpha: 0.30),
            width: 0.9,
          ),
        ),
        child: Wrap(
          spacing: 8, runSpacing: 8,
          children: vitals.entries.map((e) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.soapTagBg(SoapSection.o),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e.key, style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: theme.soapTagFg(SoapSection.o),
                )),
                const SizedBox(height: 2),
                Text(e.value, style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800,
                  color: theme.textPrimary,
                )),
              ],
            ),
          )).toList(),
        ),
      ),
    );
  }

  // ── Chip visual para EVA ──────────────────────────────────────────────────
  Widget _evaChip(int eva, InternacionTheme theme) {
    final color = eva <= 3
        ? InternacionTheme.green
        : eva <= 6
            ? InternacionTheme.amber
            : InternacionTheme.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text('$eva/10', style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w800, color: color,
      )),
    );
  }

  // ── Estado vazio (IA não extraiu nada) ───────────────────────────────────
  Widget _emptyState(InternacionTheme theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: theme.textSecondary),
            const SizedBox(height: 12),
            Text(
              isEs
                  ? 'La IA no encontró datos suficientes.\nIntenta con más información.'
                  : 'A IA não encontrou dados suficientes.\nTente com mais informações.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: theme.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  String _translateEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'mejorando': return isEs ? 'Mejorando ↑' : 'Melhorando ↑';
      case 'estable':   return isEs ? 'Estable →' : 'Estável →';
      case 'empeorando': return isEs ? 'Empeorando ↓' : 'Piorando ↓';
      default: return estado;
    }
  }
}
