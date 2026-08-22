import 'package:flutter/material.dart';
import 'package:medcases/home_v2/theme/home_v2_palette.dart';
import 'package:medcases/models/clinical_structured_output.dart';
import 'package:medcases/screens/ai/widgets/clinical_treatment_presentation_shadow_view.dart';

/// PHASE3I-J2F10B: controlled productive visual integration.
const bool _typedTreatmentVisualEnabledByDefault = bool.fromEnvironment(
  'MEDCASES_TYPED_TREATMENT_VISUAL',
  defaultValue: true,
);

class GuardiaClinicalResponseView extends StatefulWidget {
  final String rawText;
  final String userText;
  final bool userInitiatedByAction;
  final ClinicalStructuredOutput? output;
  final bool dark;
  final String languageCode;
  final VoidCallback onCopy;
  final VoidCallback? onTts;
  final bool ttsPlaying;
  final bool ttsReady;
  final bool isStreaming;
  final ValueNotifier<String>? streamingTextNotifier;
  final int scrollGeneration;
  final void Function(int generation)? onTextRevealed;
  final bool typedTreatmentVisualEnabled;

  const GuardiaClinicalResponseView({
    super.key,
    required this.rawText,
    this.userText = '',
    this.userInitiatedByAction = false,
    required this.dark,
    required this.languageCode,
    required this.onCopy,
    this.output,
    this.onTts,
    this.ttsPlaying = false,
    this.ttsReady = false,
    this.isStreaming = false,
    this.streamingTextNotifier,
    this.scrollGeneration = 0,
    this.onTextRevealed,
    this.typedTreatmentVisualEnabled = _typedTreatmentVisualEnabledByDefault,
  });

  @override
  State<GuardiaClinicalResponseView> createState() =>
      _GuardiaClinicalResponseViewState();
}

class _GuardiaClinicalResponseViewState
    extends State<GuardiaClinicalResponseView> {
  late String _displayText;
  ValueNotifier<String>? _attachedNotifier;
  bool _scrollNotificationScheduled = false;

  bool get _isSpanish =>
      widget.languageCode.trim().toLowerCase().startsWith('es');

  @override
  void initState() {
    super.initState();
    _displayText = _initialText();
    _attachNotifier(widget.streamingTextNotifier);
  }

  @override
  void didUpdateWidget(GuardiaClinicalResponseView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.streamingTextNotifier != widget.streamingTextNotifier) {
      _detachNotifier();
      _attachNotifier(widget.streamingTextNotifier);
    }

    final notifierText = widget.streamingTextNotifier?.value.trim() ?? '';

    if (!widget.isStreaming && widget.rawText.trim().isNotEmpty) {
      _displayText = widget.rawText;
    } else if (notifierText.isNotEmpty) {
      _displayText = notifierText;
    } else if (oldWidget.rawText != widget.rawText ||
        oldWidget.isStreaming != widget.isStreaming) {
      _displayText = widget.rawText;
    }
  }

  @override
  void dispose() {
    _detachNotifier();
    super.dispose();
  }

  String _initialText() {
    final notifierText = widget.streamingTextNotifier?.value.trim() ?? '';

    if (!widget.isStreaming && widget.rawText.trim().isNotEmpty) {
      return widget.rawText;
    }

    return notifierText.isNotEmpty ? notifierText : widget.rawText;
  }

  void _attachNotifier(ValueNotifier<String>? notifier) {
    _attachedNotifier = notifier;
    notifier?.addListener(_handleStreamingSnapshot);

    final snapshot = notifier?.value ?? '';

    if (snapshot.trim().isNotEmpty) {
      _displayText = snapshot;
    }
  }

  void _detachNotifier() {
    _attachedNotifier?.removeListener(_handleStreamingSnapshot);
    _attachedNotifier = null;
  }

  void _handleStreamingSnapshot() {
    if (!mounted) return;

    final snapshot = _attachedNotifier?.value ?? '';

    assert(() {
      if (widget.isStreaming) {
        debugPrint(
          '[GUARDIA_TRACE] stage=I5_renderer_snapshot_in '
          'snapshotLen=${snapshot.length} '
          'displayBefore=${_displayText.length}',
        );
      }
      return true;
    }());

    if (snapshot.isEmpty || snapshot == _displayText) {
      return;
    }

    if (snapshot.length < _displayText.length &&
        _displayText.startsWith(snapshot)) {
      return;
    }

    setState(() {
      _displayText = snapshot;
    });

    assert(() {
      if (widget.isStreaming) {
        debugPrint(
          '[GUARDIA_TRACE] stage=I5_renderer_snapshot_out '
          'snapshotLen=${snapshot.length} '
          'displayAfter=${_displayText.length}',
        );
      }
      return true;
    }());

    _scheduleScrollNotification();
  }

  void _scheduleScrollNotification() {
    if (_scrollNotificationScheduled) return;

    _scrollNotificationScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollNotificationScheduled = false;

      if (!mounted) return;

      widget.onTextRevealed?.call(widget.scrollGeneration);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = HomeV2Palette.resolve(widget.dark);
    final effectiveText =
        !widget.isStreaming && widget.rawText.trim().isNotEmpty
        ? widget.rawText
        : (_displayText.trim().isNotEmpty ? _displayText : widget.rawText);
    final stablePresentationText =
        GuardiaStreamingPresentation.stableBeforeHardStop(
          rawText: effectiveText,
          isStreaming: widget.isStreaming,
        );
    final content = _GuardiaDisplayContent.from(
      rawText: stablePresentationText,
      output: widget.output,
    );
    final titleProjection = _GuardiaTitleProjection.resolve(
      diagnosis: content.diagnosis,
      userText: widget.userText,
      isContinuation: widget.userInitiatedByAction,
      isSpanish: _isSpanish,
    );
    final keyPointsAreHypotheses =
        titleProjection.demoteDiagnosisToHypothesis &&
        _guardiaKeyPointsContainHypothesis(content.keyPoints);
    final hasUserCertaintyContext = widget.userText.trim().isNotEmpty;
    final allowMedicationPresentation =
        !content.isDifferential &&
        (!hasUserCertaintyContext ||
            !titleProjection.demoteDiagnosisToHypothesis);
    final usesRedFlagsLabel = RegExp(
      r'^[ \t]*(?:[-*•][ \t]*)?(?:🚩[ \t]*)?'
      r'(?:[*_`#]+[ \t]*)*red[ \t]+flags?[ \t]*(?::|$)',
      caseSensitive: false,
      multiLine: true,
    ).hasMatch(stablePresentationText);

    final output = widget.output;
    final useTypedTreatmentVisual =
        widget.typedTreatmentVisualEnabled &&
        output != null &&
        output.treatmentPresentation.items.isNotEmpty &&
        output.primeiraLinha.isEmpty &&
        output.segundaLinha.isEmpty;

    assert(() {
      if (!widget.isStreaming) {
        final normalizedRaw = effectiveText
            .replaceAll(RegExp(r'[*_`#]+'), '')
            .replaceAll(RegExp(r'\\s+'), ' ')
            .trim()
            .toLowerCase();

        final rawReassessmentOccurrences = RegExp(
          r'reavalia(?:ção|cao)[^.!?\\n]{0,80}48.?72h',
        ).allMatches(normalizedRaw).length;

        debugPrint(
          '[GUARDIA_PROVENANCE] '
          'rawReassessmentOccurrences=$rawReassessmentOccurrences '
          'alerts=${content.alerts.length} '
          'hardStops=${content.hardStops.length} '
          'notes=${content.notes.length} '
          'keyPoints=${content.keyPoints.length} '
          'typed=$useTypedTreatmentVisual '
          'alertsPayload=${content.alerts.join(" || ")} '
          'hardStopsPayload=${content.hardStops.join(" || ")} '
          'notesPayload=${content.notes.join(" || ")} '
          'keyPointsPayload=${content.keyPoints.join(" || ")}',
        );
      }
      return true;
    }());

    assert(() {
      if (!widget.isStreaming) {
        debugPrint(
          '[GUARDIA_TRACE] stage=I5_renderer_final '
          'tsUs=${DateTime.now().microsecondsSinceEpoch} '
          'rawTextLen=${widget.rawText.length} '
          'displayTextLen=${_displayText.length} '
          'effectiveTextLen=${effectiveText.length} '
          'dto=${widget.output != null} '
          'rx=${widget.output?.prescricao.length ?? 0} '
          'first=${widget.output?.primeiraLinha.length ?? 0} '
          'second=${widget.output?.segundaLinha.length ?? 0} '
          'keys=${widget.output?.pontosChave.length ?? 0} '
          'hard=${widget.output?.hardStops.length ?? 0} '
          'structured=${content.hasStructuredContent}',
        );
      }
      return true;
    }());

    return Padding(
      padding: const EdgeInsets.fromLTRB(17, 14, 17, 8),
      child: Column(
        key: const ValueKey('guardia_clinical_response'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (content.diagnosis.isNotEmpty) ...[
            _DiagnosisHeader(
              diagnosis: titleProjection.headerTitle,
              palette: palette,
            ),
          ],
          if (content.immediate.isNotEmpty) ...[
            if (content.diagnosis.isNotEmpty)
              _GuardiaSectionDivider(
                key: const ValueKey('guardia_divider_before_immediate'),
                palette: palette,
              ),
            if (content.isDifferential ||
                titleProjection.demoteDiagnosisToHypothesis) ...[
              _SectionTitle(
                key: const ValueKey('guardia_initial_evaluation_section'),
                title: _isSpanish ? 'Evaluación inicial' : 'Avaliação inicial',
                palette: palette,
              ),
              const SizedBox(height: 5),
            ] else ...[
              _SectionTitle(
                key: const ValueKey('guardia_immediate_conduct_section'),
                title: _isSpanish ? 'Conducta inmediata' : 'Conduta imediata',
                palette: palette,
              ),
              const SizedBox(height: 5),
            ],
            for (final item in content.immediate)
              _BulletLine(text: item, palette: palette),
          ],
          if (allowMedicationPresentation && useTypedTreatmentVisual) ...[
            if (content.hasContentBeforeMedication)
              _GuardiaSectionDivider(
                key: const ValueKey('guardia_divider_before_medication'),
                palette: palette,
              ),
            ClinicalTreatmentPresentationShadowView(
              key: const ValueKey('guardia_typed_treatment_section'),
              presentation: output.treatmentPresentation,
              dark: widget.dark,
              languageCode: widget.languageCode,
            ),
          ],
          if (allowMedicationPresentation &&
              !useTypedTreatmentVisual &&
              content.hasMedication) ...[
            if (content.hasContentBeforeMedication)
              _GuardiaSectionDivider(
                key: const ValueKey('guardia_divider_before_medication'),
                palette: palette,
              ),
            _SectionTitle(
              key: const ValueKey('guardia_pharmacologic_section'),
              title: _isSpanish
                  ? 'Tratamiento farmacológico'
                  : 'Tratamento farmacológico',
              palette: palette,
            ),
            if (content.firstLine.isNotEmpty) ...[
              const SizedBox(height: 7),
              _SubsectionTitle(
                key: const ValueKey('guardia_first_line_section'),
                title: _isSpanish ? '1ª línea' : '1ª linha',
                palette: palette,
              ),
              for (final item in content.firstLine)
                _MedicationLine(text: item, palette: palette),
            ],
            if (content.secondLine.isNotEmpty) ...[
              const SizedBox(height: 10),
              _SubsectionTitle(
                key: const ValueKey('guardia_second_line_section'),
                title: _isSpanish ? '2ª línea' : '2ª linha',
                palette: palette,
              ),
              for (final item in content.secondLine)
                _MedicationLine(text: item, palette: palette),
            ],
            if (content.unclassified.isNotEmpty) ...[
              const SizedBox(height: 5),
              for (final item in content.unclassified)
                _MedicationLine(text: item, palette: palette),
            ],
          ],
          if (content.exams.isNotEmpty) ...[
            if (content.hasContentBeforeExams)
              _GuardiaSectionDivider(
                key: const ValueKey('guardia_divider_before_exams'),
                palette: palette,
              ),
            _SectionTitle(
              key: const ValueKey('guardia_exams_section'),
              title: _isSpanish
                  ? 'Exámenes complementarios'
                  : 'Exames complementares',
              palette: palette,
            ),
            const SizedBox(height: 5),
            for (final item in content.exams)
              _BulletLine(text: item, palette: palette),
          ],
          if (content.evolution.isNotEmpty) ...[
            if (content.hasContentBeforeEvolution)
              _GuardiaSectionDivider(
                key: const ValueKey('guardia_divider_before_evolution'),
                palette: palette,
              ),
            _SectionTitle(
              key: const ValueKey('guardia_evolution_section'),
              title: _isSpanish
                  ? 'Monitorización de la evolución'
                  : 'Monitorização da evolução',
              palette: palette,
            ),
            const SizedBox(height: 5),
            for (final item in content.evolution)
              _BulletLine(text: item, palette: palette),
          ],
          if (content.questions.isNotEmpty) ...[
            if (content.hasContentBeforeQuestions)
              _GuardiaSectionDivider(
                key: const ValueKey('guardia_divider_before_questions'),
                palette: palette,
              ),
            _SectionTitle(
              key: const ValueKey('guardia_questions_section'),
              title: _isSpanish ? 'Preguntas clave' : 'Perguntas-chave',
              palette: palette,
            ),
            const SizedBox(height: 5),
            for (final item in content.questions)
              _BulletLine(text: item, palette: palette),
          ],
          if (content.keyPoints.isNotEmpty) ...[
            if (content.hasContentBeforeKeyPoints)
              _GuardiaSectionDivider(
                key: const ValueKey('guardia_divider_before_key_points'),
                palette: palette,
              ),
            _SectionTitle(
              key: const ValueKey('guardia_key_points_section'),
              title: keyPointsAreHypotheses
                  ? (_isSpanish
                        ? 'Posibilidades clínicas prioritarias'
                        : 'Possibilidades clínicas prioritárias')
                  : (_isSpanish ? 'Puntos clave' : 'Pontos-chave'),
              palette: palette,
            ),
            const SizedBox(height: 5),
            for (final item in content.keyPoints)
              _BulletLine(text: item, palette: palette),
          ],
          if (!useTypedTreatmentVisual && content.alerts.isNotEmpty) ...[
            if (content.hasContentBeforeAlerts)
              _GuardiaSectionDivider(
                key: const ValueKey('guardia_divider_before_alert'),
                palette: palette,
              ),
            _SectionTitle(
              key: const ValueKey('guardia_alert_section'),
              title: _isSpanish ? 'Alerta clínica' : 'Alerta clínico',
              palette: palette,
              warning: true,
            ),
            const SizedBox(height: 5),
            for (final item in content.alerts)
              _BulletLine(text: item, palette: palette, warning: true),
          ],
          if (!useTypedTreatmentVisual && content.hardStops.isNotEmpty) ...[
            if (content.hasContentBeforeHardStops)
              _GuardiaSectionDivider(
                key: const ValueKey('guardia_divider_before_hard_stop'),
                palette: palette,
              ),
            if (usesRedFlagsLabel)
              _SectionTitle(
                key: const ValueKey('guardia_hard_stop_section'),
                title: _isSpanish ? 'Red flags' : 'Sinais de alerta',
                palette: palette,
                warning: true,
              )
            else
              _SectionTitle(
                key: const ValueKey('guardia_hard_stop_section'),
                title: _isSpanish ? 'Red flags' : 'Sinais de alerta',
                palette: palette,
                warning: true,
              ),
            const SizedBox(height: 5),
            for (final item in content.hardStops)
              _BulletLine(text: item, palette: palette, warning: true),
          ],
          if (content.notes.isNotEmpty) ...[
            if (content.hasContentBeforeNotes) const SizedBox(height: 12),
            for (final item in content.notes)
              _PinnedLine(text: item, palette: palette),
          ],
          if (content.fallbackLines.isNotEmpty &&
              (widget.isStreaming || !content.hasStructuredContent)) ...[
            if (content.hasStructuredContent) const SizedBox(height: 5),
            for (final item in content.fallbackLines)
              _PartialLine(text: item, palette: palette),
          ],
          if (widget.isStreaming) ...[
            const SizedBox(height: 2),
            _StreamingCursor(palette: palette),
          ] else ...[
            const SizedBox(height: 7),
            _FooterActions(
              palette: palette,
              isSpanish: _isSpanish,
              onCopy: widget.onCopy,
              onTts: widget.onTts,
              ttsPlaying: widget.ttsPlaying,
              ttsReady: widget.ttsReady,
            ),
          ],
        ],
      ),
    );
  }
}

class _GuardiaTitleProjection {
  final String headerTitle;
  final String diagnosisCore;
  final bool demoteDiagnosisToHypothesis;

  const _GuardiaTitleProjection({
    required this.headerTitle,
    required this.diagnosisCore,
    required this.demoteDiagnosisToHypothesis,
  });

  static _GuardiaTitleProjection resolve({
    required String diagnosis,
    required String userText,
    required bool isContinuation,
    required bool isSpanish,
  }) {
    final core = _guardiaDiagnosisCore(diagnosis);
    final diagnosisNorm = _normalizeClinicalText(core);
    final diagnosisBaseNorm = _guardiaDiagnosisBaseNorm(core);
    final userNorm = _normalizeClinicalText(userText);
    final directTopicTitle = _guardiaExplicitDirectTopicTitle(
      userText: userText,
      userNorm: userNorm,
      isSpanish: isSpanish,
    );
    final differential =
        diagnosisNorm.contains('diferenciales prioritarios') ||
        diagnosisNorm.contains('diferenciais prioritarios');
    final explicit = _guardiaUserExplicitlySupportsDiagnosis(
      userNorm: userNorm,
      diagnosisNorm: diagnosisNorm,
      diagnosisBaseNorm: diagnosisBaseNorm,
    );
    final directTopicOverride = !explicit ? directTopicTitle : null;
    final hasUserCertaintyContext = userNorm.isNotEmpty;
    final keep =
        core.isNotEmpty &&
        (isContinuation ||
            !hasUserCertaintyContext ||
            (!differential && explicit));
    return _GuardiaTitleProjection(
      headerTitle: directTopicOverride ??
          (keep
              ? core
              : (isSpanish ? 'Orientación clínica' : 'Orientação clínica')),
      diagnosisCore: core.isEmpty ? diagnosis.trim() : core,
      demoteDiagnosisToHypothesis:
          directTopicOverride == null && core.isNotEmpty && !keep,
    );
  }
}

String _guardiaDiagnosisCore(String diagnosis) {
  var value = diagnosis
      .replaceFirst(RegExp(r'^[\s📖🔑📌⚠️🟥🔴💊🔄⛔🚨🚩]+', unicode: true), '')
      .trim();
  value = value
      .replaceFirst(
        RegExp(
          r'\s*[—–-]\s*(?:(?:conducta|conduta)\s+(?:cl[ií]nica\s+)?(?:inmediata|imediata)|manejo\s+(?:inmediato|imediato))\s*$',
          caseSensitive: false,
          unicode: true,
        ),
        '',
      )
      .trim();
  return value;
}

bool _guardiaUserExplicitlySupportsDiagnosis({
  required String userNorm,
  required String diagnosisNorm,
  required String diagnosisBaseNorm,
}) {
  if (userNorm.isEmpty || diagnosisNorm.isEmpty) return false;
  if (_guardiaCrossLanguageDiverticulitisIdentityMatch(
    userNorm: userNorm,
    diagnosisNorm: diagnosisNorm,
  )) {
    return true;
  }
  if (userNorm.contains(diagnosisNorm)) return true;
  if (diagnosisBaseNorm.isNotEmpty) {
    if (userNorm == diagnosisBaseNorm) return true;
    if (_guardiaSingleEditTopicMatch(userNorm, diagnosisBaseNorm)) return true;
  }
  final diagnosisCompact = diagnosisNorm.replaceAll(' ', '');
  final userCompact = userNorm.replaceAll(' ', '');
  if (diagnosisCompact.length >= 2 &&
      diagnosisCompact.length <= 8 &&
      userCompact == diagnosisCompact) {
    return true;
  }
  const aliases = <String, List<String>>{
    'iam': <String>[
      'infarto agudo de miocardio',
      'infarto agudo do miocardio',
      'infarto agudo de myocardio',
      'infarto agudo do myocardio',
    ],
    'sca': <String>['sindrome coronaria aguda', 'sindrome coronariana aguda'],
    'tep': <String>['tromboembolismo pulmonar', 'embolia pulmonar'],
    'avc': <String>['acidente vascular cerebral'],
    'acv': <String>['accidente cerebrovascular'],
    'pcr': <String>['parada cardiorrespiratoria', 'paro cardiorrespiratorio'],
  };
  for (final entry in aliases.entries) {
    final diagnosisAlias =
        diagnosisCompact == entry.key ||
        entry.value.any((value) => diagnosisNorm.contains(value));
    if (!diagnosisAlias) continue;
    if (userCompact == entry.key || entry.value.any(userNorm.contains))
      return true;
  }
  return false;
}

bool _guardiaCrossLanguageDiverticulitisIdentityMatch({
  required String userNorm,
  required String diagnosisNorm,
}) {
  final userHas =
      userNorm.contains('diverticulite') || userNorm.contains('diverticulitis');
  final diagnosisHas = diagnosisNorm.contains('diverticulitis') ||
      diagnosisNorm.contains('diverticulite');
  if (!userHas || !diagnosisHas) return false;

  int phenotype(String value) {
    final uncomplicated = <String>[
      'nao complicada',
      'no complicada',
      'sem complicacao',
      'sin complicacion',
      'uncomplicated',
    ].any(value.contains);
    if (uncomplicated) return -1;

    final complicated = <String>[
      'complicada',
      'absceso',
      'abscesso',
      'abscess',
      'perfor',
      'periton',
      'fistul',
      'obstruccion',
      'obstrucao',
      'obstruction',
      'sepsis',
      'sepse',
    ].any(value.contains);
    if (complicated) return 1;

    return 0;
  }

  final userPhenotype = phenotype(userNorm);
  final diagnosisPhenotype = phenotype(diagnosisNorm);

  if (userPhenotype != 0 &&
      diagnosisPhenotype != 0 &&
      userPhenotype != diagnosisPhenotype) {
    return false;
  }

  return true;
}

String? _guardiaExplicitDirectTopicTitle({
  required String userText,
  required String userNorm,
  required bool isSpanish,
}) {
  if (userNorm.isEmpty) return null;

  var raw = userText.trim();
  if (raw.isEmpty || raw.length > 100) return null;
  if (raw.contains('?') || raw.contains('¿')) return null;

  var normalized = userNorm;
  const taskPrefixes = <String>[
    'manejo de ',
    'manejo ',
    'tratamiento de ',
    'tratamiento ',
    'conducta en ',
    'conducta de ',
    'conduta em ',
    'conduta de ',
    'conduta ',
    'diagnostico de ',
    'diagnostico ',
    'diagnostico diferencial de ',
    'protocolo de ',
    'protocolo ',
    'orientacion sobre ',
    'orientacao sobre ',
  ];
  for (final prefix in taskPrefixes) {
    if (normalized.startsWith(prefix)) {
      normalized = normalized.substring(prefix.length).trim();
      final split = raw.split(RegExp(r'\s+'));
      final prefixWords = prefix.trim().split(' ').length;
      if (split.length > prefixWords) {
        raw = split.skip(prefixWords).join(' ').trim();
      }
      break;
    }
  }

  final tokenCount =
      normalized.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).length;
  if (tokenCount == 0 || tokenCount > 7) return null;

  const symptomSignals = <String>[
    'dolor',
    'dor abdominal',
    'dor toracica',
    'dor de',
    'fiebre',
    'febre',
    'disnea',
    'dispneia',
    'tos',
    'nausea',
    'vomito',
    'mareo',
    'tontura',
    'cefalea',
    'palpitacao',
    'palpitacion',
  ];
  if (symptomSignals.any(normalized.contains)) return null;

  const canonicalEs = <String, String>{
    'coleducolitiasis': 'COLEDOCOLITIASIS',
    'coledocolitiasis': 'COLEDOCOLITIASIS',
    'choledocholithiasis': 'COLEDOCOLITIASIS',
    'sindrome coledociano': 'SÍNDROME COLEDOCIANO',
  };
  const canonicalPt = <String, String>{
    'coledocolitiase': 'COLEDOCOLITÍASE',
    'coleducolitiase': 'COLEDOCOLITÍASE',
    'choledocholithiasis': 'COLEDOCOLITÍASE',
    'sindrome coledociano': 'SÍNDROME COLEDOCIANO',
  };

  final canonical = (isSpanish ? canonicalEs : canonicalPt)[normalized];
  if (canonical != null) return canonical;

  const pathologySignals = <String>[
    'sindrome',
    'litiasis',
    'litiase',
    'itiase',
    'itis',
    'osis',
    'emia',
    'patia',
    'infarto',
    'cancer',
    'carcinoma',
    'shock',
    'choque',
    'sepsis',
    'asma',
    'epoc',
    'dpoc',
    'diabetes',
    'pneumotorax',
    'neumotorax',
    'hemotorax',
    'trombosis',
    'trombose',
    'embolia',
    'aneurisma',
    'diseccion',
    'disseccao',
    'cirrosis',
    'cirrose',
    'fibrilacion',
    'fibrilacao',
    'taquicardia',
    'bradicardia',
    'meningitis',
    'meningite',
  ];
  if (!pathologySignals.any(normalized.contains)) return null;

  return raw
      .replaceAll(RegExp(r'^[\s¿¡]+', unicode: true), '')
      .replaceAll(RegExp(r'[\s?!.,;:]+$', unicode: true), '')
      .trim();
}

String _guardiaDiagnosisBaseNorm(String diagnosis) {
  final base = diagnosis
      .split(RegExp(r'\s*[—–]\s*', unicode: true))
      .first
      .trim();
  return _normalizeClinicalText(base);
}

bool _guardiaSingleEditTopicMatch(String left, String right) {
  if (left == right) return true;
  if (left.length < 6 || right.length < 6) return false;
  if ((left.length - right.length).abs() > 1) return false;

  var i = 0;
  var j = 0;
  var edits = 0;

  while (i < left.length && j < right.length) {
    if (left.codeUnitAt(i) == right.codeUnitAt(j)) {
      i++;
      j++;
      continue;
    }

    edits++;
    if (edits > 1) return false;

    if (left.length > right.length) {
      i++;
    } else if (right.length > left.length) {
      j++;
    } else {
      i++;
      j++;
    }
  }

  if (i < left.length || j < right.length) edits++;
  return edits <= 1;
}

bool _guardiaKeyPointsContainHypothesis(List<String> items) {
  for (final item in items) {
    final normalized = _normalizeClinicalText(item);
    if (normalized.startsWith('hipotesis principal') ||
        normalized.startsWith('hipotese principal') ||
        normalized.startsWith('diferenciales prioritarios') ||
        normalized.startsWith('diferenciais prioritarios') ||
        normalized.startsWith('posibilidad 1') ||
        normalized.startsWith('posibilidad 2') ||
        normalized.startsWith('posibilidad 3') ||
        normalized.startsWith('possibilidade 1') ||
        normalized.startsWith('possibilidade 2') ||
        normalized.startsWith('possibilidade 3') ||
        normalized.startsWith('posibilidades clinicas prioritarias') ||
        normalized.startsWith('possibilidades clinicas prioritarias')) {
      return true;
    }
  }
  return false;
}

String _normalizeGuardiaNoteLabel(String text) {
  var value = text.trim();
  value = value.replaceFirst(
    RegExp(r'^\s*Cierre\s*:\s*', caseSensitive: false),
    'Próximo paso: ',
  );
  value = value.replaceFirst(
    RegExp(r'^\s*Fechamento\s*:\s*', caseSensitive: false),
    'Próximo passo: ',
  );
  return value;
}

class _GuardiaSectionDivider extends StatelessWidget {
  final HomeV2Palette palette;

  const _GuardiaSectionDivider({super.key, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 9, 0, 12),
      child: Container(
        height: 0.5,
        color: palette.textMuted.withValues(alpha: 0.255),
      ),
    );
  }
}

class _DiagnosisHeader extends StatelessWidget {
  final String diagnosis;
  final HomeV2Palette palette;

  const _DiagnosisHeader({required this.diagnosis, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Text(
      diagnosis,
      style: TextStyle(
        color: palette.textPrimary,
        fontSize: 17.0,
        height: 1.18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final HomeV2Palette palette;
  final bool warning;

  const _SectionTitle({
    super.key,
    required this.title,
    required this.palette,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: warning
            ? Theme.of(context).colorScheme.error
            : palette.textPrimary,
        fontSize: 14.0,
        height: 1.20,
        fontWeight: warning ? FontWeight.w700 : FontWeight.w600,
      ),
    );
  }
}

class _SubsectionTitle extends StatelessWidget {
  final String title;
  final HomeV2Palette palette;

  const _SubsectionTitle({
    super.key,
    required this.title,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      '$title:',
      style: TextStyle(
        color: palette.textSecondary,
        fontSize: 12.4,
        height: 1.20,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _MedicationLine extends StatelessWidget {
  final String text;
  final HomeV2Palette palette;

  const _MedicationLine({required this.text, required this.palette});

  @override
  Widget build(BuildContext context) {
    final parts = _MedicationTextParts.from(text);

    return Padding(
      key: ValueKey('guardia_medication_${text.hashCode}'),
      padding: const EdgeInsets.only(top: 3, left: 8),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '• ',
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 14.4,
                height: 1.24,
                fontWeight: FontWeight.w400,
              ),
            ),
            if (parts.drug.isNotEmpty)
              TextSpan(
                text: parts.drug,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 14.4,
                  height: 1.24,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (parts.dose.isNotEmpty)
              TextSpan(
                text: '${parts.drug.isNotEmpty ? ' ' : ''}${parts.dose}',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 14.4,
                  height: 1.24,
                  fontWeight: FontWeight.w400,
                ),
              ),
            if (parts.qualifier.isNotEmpty)
              TextSpan(
                text: ' ${parts.qualifier}',
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 13.4,
                  height: 1.24,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MedicationTextParts {
  final String drug;
  final String dose;
  final String qualifier;

  const _MedicationTextParts({
    required this.drug,
    required this.dose,
    required this.qualifier,
  });

  factory _MedicationTextParts.from(String value) {
    final trimmed = value.trim();
    final bracketQualifierMatch = RegExp(
      r'\s*\[([^\[\]]+)\]\s*$',
    ).firstMatch(trimmed);
    final withoutBracketQualifier = bracketQualifierMatch == null
        ? trimmed
        : trimmed.substring(0, bracketQualifierMatch.start).trim();
    final bracketQualifier = bracketQualifierMatch?.group(1)?.trim() ?? '';

    final qualifierMatch = RegExp(
      r'\s+(?=(?:si|se|cuando|quando|'
      r'en\s+caso|em\s+caso)\b|\()',
      caseSensitive: false,
    ).firstMatch(withoutBracketQualifier);

    final main = qualifierMatch == null
        ? withoutBracketQualifier
        : withoutBracketQualifier.substring(0, qualifierMatch.start).trim();

    final inlineQualifier = qualifierMatch == null
        ? ''
        : withoutBracketQualifier.substring(qualifierMatch.start).trim();
    final qualifier = <String>[
      inlineQualifier,
      bracketQualifier,
    ].where((part) => part.isNotEmpty).join(' ');

    final doseMatch = RegExp(r'\b\d+(?:[.,]\d+)?').firstMatch(main);

    if (doseMatch == null) {
      return _MedicationTextParts(drug: main, dose: '', qualifier: qualifier);
    }

    return _MedicationTextParts(
      drug: main.substring(0, doseMatch.start).trim(),
      dose: main.substring(doseMatch.start).trim(),
      qualifier: qualifier,
    );
  }
}

class _BulletLine extends StatelessWidget {
  final String text;
  final HomeV2Palette palette;
  final bool warning;

  const _BulletLine({
    required this.text,
    required this.palette,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = warning
        ? Theme.of(context).colorScheme.error
        : palette.textPrimary;

    return Padding(
      padding: const EdgeInsets.only(top: 3, left: 8),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '• ',
              style: TextStyle(
                color: color,
                fontSize: 13.5,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: text,
              style: TextStyle(
                color: color,
                fontSize: 13.5,
                height: 1.25,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinnedLine extends StatelessWidget {
  final String text;
  final HomeV2Palette palette;

  const _PinnedLine({required this.text, required this.palette});

  @override
  Widget build(BuildContext context) {
    final normalized = _normalizeGuardiaNoteLabel(text);
    final nextStep = RegExp(
      r'^(Próximo paso|Próximo passo)\s*:\s*(.*)$',
      caseSensitive: false,
      unicode: true,
    ).firstMatch(normalized);

    return Padding(
      key: ValueKey('guardia_note_${text.hashCode}'),
      padding: const EdgeInsets.only(top: 5),
      child: nextStep == null
          ? Text(
              normalized,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 13.5,
                height: 1.25,
                fontWeight: FontWeight.w400,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(
                  key: const ValueKey('guardia_next_step_section'),
                  title: nextStep.group(1)!,
                  palette: palette,
                ),
                const SizedBox(height: 5),
                Text(
                  nextStep.group(2)!.trim(),
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 13.5,
                    height: 1.25,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
    );
  }
}

class _PartialLine extends StatelessWidget {
  final String text;
  final HomeV2Palette palette;

  const _PartialLine({required this.text, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        text,
        style: TextStyle(
          color: palette.textPrimary,
          fontSize: 13.7,
          height: 1.22,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _StreamingCursor extends StatelessWidget {
  final HomeV2Palette palette;

  const _StreamingCursor({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Text(
      '▌',
      key: const ValueKey('guardia_streaming_cursor'),
      style: TextStyle(
        color: palette.accent,
        fontSize: 13,
        height: 1,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}

class _FooterActions extends StatelessWidget {
  final HomeV2Palette palette;
  final bool isSpanish;
  final VoidCallback onCopy;
  final VoidCallback? onTts;
  final bool ttsPlaying;
  final bool ttsReady;

  const _FooterActions({
    required this.palette,
    required this.isSpanish,
    required this.onCopy,
    required this.onTts,
    required this.ttsPlaying,
    required this.ttsReady,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          _currentTime(),
          style: TextStyle(
            fontSize: 10,
            color: palette.textMuted.withValues(alpha: 0.42),
          ),
        ),
        const Spacer(),
        if (onTts != null && ttsReady) ...[
          GestureDetector(
            key: const ValueKey('guardia_tts_action'),
            onTap: onTts,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  ttsPlaying
                      ? Icons.stop_circle_rounded
                      : Icons.volume_up_rounded,
                  size: 13,
                  color: ttsPlaying
                      ? palette.accent
                      : palette.textSecondary.withValues(alpha: 0.58),
                ),
                const SizedBox(width: 3),
                Text(
                  ttsPlaying
                      ? (isSpanish ? 'Detener' : 'Parar')
                      : (isSpanish ? 'Escuchar' : 'Ouvir'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: ttsPlaying
                        ? palette.accent
                        : palette.textSecondary.withValues(alpha: 0.58),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
        ],
        GestureDetector(
          key: const ValueKey('guardia_copy_action'),
          onTap: onCopy,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.copy_rounded,
                size: 12,
                color: palette.textMuted.withValues(alpha: 0.42),
              ),
              const SizedBox(width: 3),
              Text(
                'Copiar',
                style: TextStyle(
                  fontSize: 10,
                  color: palette.textMuted.withValues(alpha: 0.42),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _currentTime() {
    final now = DateTime.now();

    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
  }
}

enum _RawSection {
  none,
  immediate,
  pharmacologic,
  firstLine,
  secondLine,
  exams,
  evolution,
  questions,
  keyPoints,
  alert,
  hardStop,
  note,
  ignored,
}

class _RawGuardiaSections {
  final String diagnosis;
  final List<String> immediate;
  final List<String> firstLine;
  final List<String> secondLine;
  final List<String> unclassified;
  final List<String> exams;
  final List<String> evolution;
  final List<String> questions;
  final List<String> keyPoints;
  final List<String> alerts;
  final List<String> hardStops;
  final List<String> notes;
  final List<String> fallbackLines;

  const _RawGuardiaSections({
    required this.diagnosis,
    required this.immediate,
    required this.firstLine,
    required this.secondLine,
    required this.unclassified,
    required this.exams,
    required this.evolution,
    required this.questions,
    required this.keyPoints,
    required this.alerts,
    required this.hardStops,
    required this.notes,
    required this.fallbackLines,
  });

  factory _RawGuardiaSections.parse(String rawText) {
    var diagnosis = '';
    final immediate = <String>[];
    final firstLine = <String>[];
    final secondLine = <String>[];
    final unclassified = <String>[];
    final exams = <String>[];
    final evolution = <String>[];
    final questions = <String>[];
    final keyPoints = <String>[];
    final alerts = <String>[];
    final hardStops = <String>[];
    final notes = <String>[];
    final fallbackLines = <String>[];
    var section = _RawSection.none;

    for (final rawLine
        in rawText
            .replaceAll('\r\n', '\n')
            .replaceAll('\r', '\n')
            .split('\n')) {
      final trimmed = rawLine.trim();

      if (trimmed.isEmpty) continue;

      if (_GuardiaDisplayContent._isBracketedPureClinicalActionLine(trimmed))
        continue;

      if (trimmed.startsWith('🟥') || trimmed.startsWith('🔴')) {
        final candidate = _cleanLine(trimmed);

        // MEDCASES_IA_PLANTAO_LIST_FOLLOWUP_RENDER_CONTINUITY_V1_B_R1_R1
        // Um cabeçalho genérico de conduta injetado pelo finalizer é
        // delimitador interno, não diagnóstico.
        final redHeadingSection = _sectionFor(candidate);
        if (redHeadingSection == _RawSection.immediate) {
          section = _RawSection.immediate;
        } else if (_isActionLikeClinicalLine(candidate)) {
          _addText(immediate, candidate);
        } else if (candidate.isNotEmpty) {
          diagnosis = candidate;
        }
        continue;
      }

      final inline = _inlineSectionFor(trimmed);

      if (inline != null) {
        section = inline.section;

        if (inline.content.isNotEmpty) {
          switch (inline.section) {
            case _RawSection.exams:
              _addText(exams, inline.content);
              break;
            case _RawSection.evolution:
              _addText(evolution, inline.content);
              break;
            case _RawSection.questions:
              _addText(questions, inline.content);
              break;
            case _RawSection.alert:
              _addText(alerts, inline.content);
              break;
            case _RawSection.hardStop:
              _addText(hardStops, inline.content);
              break;
            case _RawSection.note:
              _addText(notes, inline.content);
              break;
            case _RawSection.ignored:
              break;
            case _RawSection.none:
            case _RawSection.immediate:
            case _RawSection.pharmacologic:
            case _RawSection.firstLine:
            case _RawSection.secondLine:
            case _RawSection.keyPoints:
              break;
          }
        }

        continue;
      }

      if (trimmed.startsWith('📌')) {
        section = _RawSection.note;
        final note = _cleanLine(trimmed);

        if (note.isNotEmpty) {
          _addText(notes, note);
        }

        continue;
      }

      final heading = _sectionFor(trimmed);

      if (heading != null) {
        section = heading;
        continue;
      }

      final cleaned = _cleanLine(trimmed);

      if (cleaned.isEmpty) continue;

      switch (section) {
        case _RawSection.immediate:
          _addText(immediate, cleaned);
          break;
        case _RawSection.pharmacologic:
          _addText(unclassified, cleaned);
          break;
        case _RawSection.firstLine:
          _addText(firstLine, cleaned);
          break;
        case _RawSection.secondLine:
          _addText(secondLine, cleaned);
          break;
        case _RawSection.exams:
          _addText(exams, cleaned);
          break;
        case _RawSection.evolution:
          _addText(evolution, cleaned);
          break;
        case _RawSection.questions:
          _addText(questions, cleaned);
          break;
        case _RawSection.keyPoints:
          _addText(keyPoints, cleaned);
          break;
        case _RawSection.alert:
          _addText(alerts, cleaned);
          break;
        case _RawSection.hardStop:
          _addText(hardStops, cleaned);
          break;
        case _RawSection.note:
          _addText(notes, cleaned);
          break;
        case _RawSection.none:
          if (_isActionLikeClinicalLine(cleaned)) {
            _addText(immediate, cleaned);
          } else if (!_isSummaryClinicalLine(cleaned)) {
            _addText(fallbackLines, cleaned);
          }
          break;
        case _RawSection.ignored:
          break;
      }
    }

    return _RawGuardiaSections(
      diagnosis: diagnosis,
      immediate: immediate,
      firstLine: firstLine,
      secondLine: secondLine,
      unclassified: unclassified,
      exams: exams,
      evolution: evolution,
      questions: questions,
      keyPoints: keyPoints,
      alerts: alerts,
      hardStops: hardStops,
      notes: notes,
      fallbackLines: fallbackLines,
    );
  }

  static ({_RawSection section, String content})? _inlineSectionFor(
    String rawLine,
  ) {
    final prepared = rawLine
        .trim()
        .replaceAll(RegExp(r'[*_`#]+'), '')
        .replaceFirst(RegExp(r'^[📖🔑📌⚠️🟥🔴💊🔄⛔🚨🚩\-\*•\s]+'), '')
        .trim();

    final match = RegExp(
      r'^(alerta(?:\s+cl[ií]nico)?|hard\s+stop|red\s+flags?|'
      r'avalia[cç][aã]o\s+inicial|evaluaci[oó]n\s+inicial|'
      r'exames\s+complementares|ex[aá]menes\s+complementarios|'
      r'monitoriza[cç][aã]o\s+da\s+evolu[cç][aã]o|'
      r'monitoramento\s+da\s+evolu[cç][aã]o|'
      r'monitorizaci[oó]n\s+de(?:\s+la)?\s+evoluci[oó]n|'
      r'monitoreo\s+de(?:\s+la)?\s+evoluci[oó]n|'
      r'perguntas[\s-]+chave|perguntas\s+importantes|'
      r'perguntas\s+para\s+orienta[cç][aã]o|'
      r'preguntas\s+clave|preguntas\s+importantes|'
      r'preguntas\s+para\s+orientaci[oó]n|'
      r'pr[oó]ximo(?:\s+(?:paso|passo))?|siguiente\s+paso)'
      r'\s*:\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(prepared);

    if (match == null) return null;

    final heading = _normalize(match.group(1) ?? '');
    final content = _cleanLine(match.group(2) ?? '');

    if (heading == 'avaliacao inicial' || heading == 'evaluacion inicial') {
      return (section: _RawSection.immediate, content: content);
    }

    if (heading == 'exames complementares' ||
        heading == 'examenes complementarios') {
      return (section: _RawSection.exams, content: content);
    }

    if (heading == 'monitorizacao da evolucao' ||
        heading == 'monitoramento da evolucao' ||
        heading == 'monitorizacion de la evolucion' ||
        heading == 'monitorizacion de evolucion' ||
        heading == 'monitoreo de la evolucion' ||
        heading == 'monitoreo de evolucion') {
      return (section: _RawSection.evolution, content: content);
    }

    if (heading == 'perguntas chave' ||
        heading == 'perguntas importantes' ||
        heading == 'perguntas para orientacao' ||
        heading == 'preguntas clave' ||
        heading == 'preguntas importantes' ||
        heading == 'preguntas para orientacion') {
      return (section: _RawSection.questions, content: content);
    }

    if (heading == 'alerta' || heading == 'alerta clinico') {
      return (section: _RawSection.alert, content: content);
    }

    if (heading == 'hard stop' ||
        heading == 'red flag' ||
        heading == 'red flags') {
      return (section: _RawSection.hardStop, content: content);
    }

    return (section: _RawSection.ignored, content: '');
  }

  static _RawSection? _sectionFor(String rawLine) {
    final value = _normalize(_cleanHeading(rawLine));

    if (value == 'conducta' ||
        value == 'conduta' ||
        value == 'conducta inmediata' ||
        value == 'conduta imediata' ||
        value == 'conducta clinica inmediata' ||
        value == 'conduta clinica imediata' ||
        value == 'evaluacion inicial' ||
        value == 'avaliacao inicial' ||
        value == 'hacer ahora' ||
        value == 'faca agora') {
      return _RawSection.immediate;
    }

    // MEDCASES_PLANTAO_RENDERER_ADVANCED_CONTINUATION_FINAL_PRESERVATION_V1_B_R0_R5
    // Headings terapêuticos avançados são delimitadores clínicos do raw.
    // Seus bullets devem permanecer no bucket flat visível, nunca em fallback.
    if (value == 'estratificacion de riesgo' ||
        value == 'estratificacion del riesgo' ||
        value == 'estratificacao de risco' ||
        value == 'estratificacao do risco' ||
        value == 'estrategia invasiva' ||
        value == 'monitorizacion continua' ||
        value == 'monitorizacao continua' ||
        value == 'manejo de complicaciones' ||
        value == 'manejo de complicacoes') {
      return _RawSection.immediate;
    }

    if (value == 'tratamiento' ||
        value == 'tratamento' ||
        value == 'tratamiento farmacologico' ||
        value == 'tratamento farmacologico' ||
        value == 'droga' ||
        value == 'droga de eleccion' ||
        value == 'droga de escolha' ||
        value == 'farmacos e doses' ||
        value == 'farmacos y dosis') {
      return _RawSection.pharmacologic;
    }

    if (value == '1 linea' ||
        value == '1a linea' ||
        value == '1er linea' ||
        value == 'primera linea' ||
        value == '1 linha' ||
        value == '1a linha' ||
        value == 'primeira linha') {
      return _RawSection.firstLine;
    }

    if (value == '2 linea' ||
        value == '2a linea' ||
        value == 'segunda linea' ||
        value == '2 linha' ||
        value == '2a linha' ||
        value == 'segunda linha') {
      return _RawSection.secondLine;
    }

    if (value == 'exames complementares' ||
        value == 'examenes complementarios') {
      return _RawSection.exams;
    }

    if (value == 'monitorizacao da evolucao' ||
        value == 'monitoramento da evolucao' ||
        value == 'monitorizacion de la evolucion' ||
        value == 'monitorizacion de evolucion' ||
        value == 'monitoreo de la evolucion' ||
        value == 'monitoreo de evolucion') {
      return _RawSection.evolution;
    }

    if (value == 'perguntas chave' ||
        value == 'perguntas importantes' ||
        value == 'perguntas para orientacao' ||
        value == 'preguntas clave' ||
        value == 'preguntas importantes' ||
        value == 'preguntas para orientacion') {
      return _RawSection.questions;
    }

    if (value == 'puntos clave' ||
        value == 'pontos chave' ||
        value == 'pontos chaves' ||
        value == 'meta' ||
        value == 'metas' ||
        value == 'objetivo' ||
        value == 'objetivos') {
      return _RawSection.keyPoints;
    }

    if (value == 'alerta' || value == 'alerta clinico') {
      return _RawSection.alert;
    }

    if (value == 'hard stop' ||
        value == 'hard stops' ||
        value == 'red flag' ||
        value == 'red flags') {
      return _RawSection.hardStop;
    }

    if (value.startsWith('resumo') ||
        value.startsWith('resumen') ||
        value == 'siguiente paso' ||
        value == 'proximo paso' ||
        value == 'proximo passo' ||
        value == 'proximo') {
      return _RawSection.ignored;
    }

    return null;
  }

  static String _cleanHeading(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[*_`#]+'), '')
        .replaceFirst(RegExp(r'^[📖🔑📌⚠️🟥🔴💊🔄⛔🚨🚩\-\*•\s]+'), '')
        .replaceAll(RegExp(r'[:\s]+$'), '')
        .trim();
  }

  static String _cleanLine(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[*_`#]+'), '')
        .replaceFirst(RegExp(r'^[📖🔑📌⚠️🟥🔴💊🔄⛔🚨🚩\-\*•\s]+'), '')
        .replaceAll(RegExp(r'[\s.;]+$'), '')
        .trim();
  }

  static void _addText(List<String> target, String value) {
    final normalized = _normalize(value);

    if (normalized.isEmpty) return;

    final exists = target.any((item) => _normalize(item) == normalized);

    if (!exists) target.add(value);
  }

  static String _normalize(String value) {
    return _normalizeClinicalText(value);
  }
}

/// Mantém o streaming clínico progressivo, mas impede que uma seção de
/// segurança terminal seja promovida antes de a resposta estar finalizada.
///
/// Durante streaming, o texto anterior ao marcador continua visível. A cauda
/// iniciada por `HARD STOP` ou `RED FLAGS` fica retida e é entregue integralmente ao parser
/// quando [isStreaming] se torna falso.
abstract final class GuardiaStreamingPresentation {
  // MEDCASES_PLANTAO_RENDERER_ADVANCED_CONTINUATION_FINAL_PRESERVATION_V1_B_R0_R5
  // 🚩 sozinho não é RED FLAGS. Freeze somente em fronteira explícita de segurança.
  static final RegExp _hardStopBoundary = RegExp(
    r'^[ \t]*(?:[-*•][ \t]*)?'
    r'(?:(?:⛔|🚫|🛑)[^\r\n]*|'
    r'(?:🔴[ \t]*)?(?:[*_`#]+[ \t]*)*'
    r'hard[ \t]+stop(?:[ \t]*[*_`#]+)?[ \t]*(?::[^\r\n]*|$)|'
    r'(?:🚩[ \t]*)?(?:[*_`#]+[ \t]*)*'
    r'red[ \t]+flags?(?:[ \t]*[*_`#]+)?[ \t]*(?::[^\r\n]*|$))'
    r'(?:\r?\n|$)',
    caseSensitive: false,
    multiLine: true,
  );

  static String stableBeforeHardStop({
    required String rawText,
    required bool isStreaming,
  }) {
    if (!isStreaming || rawText.isEmpty) return rawText;
    final boundary = _hardStopBoundary.firstMatch(rawText);
    if (boundary == null) return rawText;
    return rawText.substring(0, boundary.start).trimRight();
  }
}

class _GuardiaDisplayContent {
  final String diagnosis;
  final List<String> immediate;
  final List<String> firstLine;
  final List<String> secondLine;
  final List<String> unclassified;
  final List<String> exams;
  final List<String> evolution;
  final List<String> questions;
  final List<String> keyPoints;
  final List<String> alerts;
  final List<String> hardStops;
  final List<String> notes;
  final List<String> fallbackLines;

  const _GuardiaDisplayContent({
    required this.diagnosis,
    required this.immediate,
    required this.firstLine,
    required this.secondLine,
    required this.unclassified,
    required this.exams,
    required this.evolution,
    required this.questions,
    required this.keyPoints,
    required this.alerts,
    required this.hardStops,
    required this.notes,
    required this.fallbackLines,
  });

  bool get hasMedication =>
      firstLine.isNotEmpty || secondLine.isNotEmpty || unclassified.isNotEmpty;

  bool get isDifferential {
    final normalized = _normalizeClinicalText(diagnosis);
    return normalized.contains('diferenciais prioritarios') ||
        normalized.contains('diferenciales prioritarios');
  }

  bool get hasStructuredContent =>
      diagnosis.isNotEmpty ||
      immediate.isNotEmpty ||
      hasMedication ||
      exams.isNotEmpty ||
      evolution.isNotEmpty ||
      questions.isNotEmpty ||
      keyPoints.isNotEmpty ||
      alerts.isNotEmpty ||
      hardStops.isNotEmpty ||
      notes.isNotEmpty;

  bool get hasContentBeforeMedication =>
      diagnosis.isNotEmpty || immediate.isNotEmpty;

  bool get hasContentBeforeExams =>
      diagnosis.isNotEmpty || immediate.isNotEmpty || hasMedication;

  bool get hasContentBeforeEvolution =>
      hasContentBeforeExams || exams.isNotEmpty;

  bool get hasContentBeforeQuestions =>
      hasContentBeforeEvolution || evolution.isNotEmpty;

  bool get hasContentBeforeKeyPoints =>
      hasContentBeforeQuestions || questions.isNotEmpty;

  bool get hasContentBeforeAlerts =>
      hasContentBeforeKeyPoints || keyPoints.isNotEmpty;

  bool get hasContentBeforeHardStops =>
      hasContentBeforeAlerts || alerts.isNotEmpty;

  bool get hasContentBeforeNotes =>
      hasContentBeforeHardStops || hardStops.isNotEmpty;

  factory _GuardiaDisplayContent.from({
    required String rawText,
    required ClinicalStructuredOutput? output,
  }) {
    final parsed = _RawGuardiaSections.parse(rawText);

    final hasContinuationSections =
        parsed.exams.isNotEmpty ||
        parsed.evolution.isNotEmpty ||
        parsed.questions.isNotEmpty;

    final firstLine =
        !hasContinuationSections &&
            output != null &&
            output.primeiraLinha.isNotEmpty
        ? _medicationTexts(output.primeiraLinha)
        : parsed.firstLine;

    final secondLine =
        !hasContinuationSections &&
            output != null &&
            output.segundaLinha.isNotEmpty
        ? _medicationTexts(output.segundaLinha)
        : parsed.secondLine;

    final classified = <String>{
      if (output != null)
        for (final item in <ClinicalPrescriptionItem>[
          ...output.primeiraLinha,
          ...output.segundaLinha,
        ])
          _medicationIdentity(item),
    };

    final typedUnclassified = hasContinuationSections || output == null
        ? const <String>[]
        : output.prescricao
              .where((item) => !classified.contains(_medicationIdentity(item)))
              .map(_medicationText)
              .toList(growable: false);

    final unclassified = _mergeClinicalText(
      typedUnclassified,
      parsed.unclassified,
    );

    final medicationLines = <String>[
      ...firstLine,
      ...secondLine,
      ...unclassified,
    ];

    var immediate = hasContinuationSections
        ? List<String>.of(parsed.immediate)
        : _mergeClinicalText(
            output?.condutaImediataItens ?? const <String>[],
            parsed.immediate,
          );

    if (!hasContinuationSections && immediate.isEmpty && output != null) {
      final fallback = output.condutaImediata.trim();
      final normalizedFallback = _normalizeClinicalText(fallback);

      final duplicatesMedication = output.prescricao.any((item) {
        return normalizedFallback.contains(
              _normalizeClinicalText(item.farmaco),
            ) &&
            normalizedFallback.contains(_normalizeClinicalText(item.posologia));
      });

      if (fallback.isNotEmpty && !duplicatesMedication) {
        immediate = <String>[fallback];
      }
    }

    final typedDiagnosis = output?.diagnosticoHeuristico.trim() ?? '';
    final diagnosis = !_isActionLikeClinicalLine(typedDiagnosis)
        ? (typedDiagnosis.isNotEmpty ? typedDiagnosis : parsed.diagnosis)
        : parsed.diagnosis;

    if (!hasContinuationSections && _isActionLikeClinicalLine(typedDiagnosis)) {
      immediate = _mergeClinicalText(immediate, <String>[typedDiagnosis]);
    }

    immediate = immediate
        .where(
          (line) =>
              !_isContractHeadingLine(line) &&
              !_isContinuationClinicalLine(line) &&
              !_duplicatesClinicalLine(line, medicationLines),
        )
        .toList(growable: false);

    var mergedKeyPoints = _withoutSummaryLines(
      hasContinuationSections
          ? parsed.keyPoints
          : _mergeClinicalText(
              output?.pontosChave ?? const <String>[],
              parsed.keyPoints,
            ),
    );

    final inlineAlerts = mergedKeyPoints
        .map(_inlineAlertContent)
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    final alerts = _withoutSummaryLines(
      _mergeClinicalText(parsed.alerts, inlineAlerts),
    );

    final sourceHardStops = _withoutSummaryLines(
      hasContinuationSections
          ? parsed.hardStops
          : _mergeClinicalText(
              output?.hardStops ?? const <String>[],
              parsed.hardStops,
            ),
    );

    final rawHardStops = hasContinuationSections
        ? sourceHardStops
        : sourceHardStops
              .expand(_splitInlinePinnedHardStopClinicalLine)
              .toList(growable: false);

    final demotedHardStops = hasContinuationSections
        ? const <String>[]
        : rawHardStops
              .where(
                (line) =>
                    _isGeneralRecommendationClinicalLine(line) ||
                    _isBracketedPureClinicalActionLine(line) ||
                    _isImmediateAntibioticTreatmentActionLine(line),
              )
              .toList(growable: false);

    final hardStops = rawHardStops
        .where((line) => !_duplicatesClinicalLine(line, demotedHardStops))
        .toList(growable: false);

    if (!hasContinuationSections && demotedHardStops.isNotEmpty) {
      mergedKeyPoints = _mergeClinicalText(mergedKeyPoints, demotedHardStops);
    }

    final notes = parsed.notes
        .where((line) => !_duplicatesClinicalLine(line, rawHardStops))
        .toList(growable: false);

    final excludedFromKeyPoints = <String>[
      ...medicationLines,
      ...immediate,
      ...parsed.exams,
      ...parsed.evolution,
      ...parsed.questions,
      ...alerts,
      ...hardStops,
      ...notes,
    ];

    final keyPoints = mergedKeyPoints
        .where(
          (line) =>
              !_isInlineAlertClinicalLine(line) &&
              !_isContinuationClinicalLine(line) &&
              !_duplicatesClinicalLine(line, excludedFromKeyPoints),
        )
        .toList(growable: false);

    final fallbackLines = _withoutSummaryLines(
      parsed.fallbackLines.where(
        (line) =>
            !_isActionLikeClinicalLine(line) &&
            !_isInlineAlertClinicalLine(line) &&
            !_isContinuationClinicalLine(line) &&
            !_isContractHeadingLine(line) &&
            _normalizeClinicalText(line) != _normalizeClinicalText(diagnosis),
      ),
    );

    return _GuardiaDisplayContent(
      diagnosis: diagnosis,
      immediate: List<String>.unmodifiable(immediate),
      firstLine: List<String>.unmodifiable(firstLine),
      secondLine: List<String>.unmodifiable(secondLine),
      unclassified: List<String>.unmodifiable(unclassified),
      exams: List<String>.unmodifiable(parsed.exams),
      evolution: List<String>.unmodifiable(parsed.evolution),
      questions: List<String>.unmodifiable(parsed.questions),
      keyPoints: List<String>.unmodifiable(keyPoints),
      alerts: List<String>.unmodifiable(alerts),
      hardStops: List<String>.unmodifiable(hardStops),
      notes: List<String>.unmodifiable(notes),
      fallbackLines: List<String>.unmodifiable(fallbackLines),
    );
  }

  static List<String> _splitInlinePinnedHardStopClinicalLine(String value) {
    final markerIndex = value.indexOf('📌');

    if (markerIndex <= 0) {
      return <String>[value];
    }

    final blocker = value.substring(0, markerIndex).trim();
    final action = value.substring(markerIndex + '📌'.length).trim();

    if (blocker.isEmpty ||
        action.isEmpty ||
        !_isImmediateAntibioticTreatmentActionLine(action)) {
      return <String>[value];
    }

    return <String>[blocker, action];
  }

  static bool _isImmediateAntibioticTreatmentActionLine(String value) {
    final normalized = _normalizeClinicalText(value);

    return normalized.startsWith(
          'iniciar tratamento antibiotico de imediato',
        ) ||
        normalized.startsWith('iniciar tratamento antibiotico imediatamente') ||
        normalized.startsWith('iniciar tratamiento antibiotico de inmediato') ||
        normalized.startsWith(
          'iniciar tratamiento antibiotico inmediatamente',
        ) ||
        normalized.startsWith('iniciar antibiotico de imediato') ||
        normalized.startsWith('iniciar antibiotico imediatamente') ||
        normalized.startsWith('iniciar antibiotico de inmediato') ||
        normalized.startsWith('iniciar antibiotico inmediatamente') ||
        normalized.startsWith('iniciar antibioticos rapidamente');
  }

  static bool _isBracketedPureClinicalActionLine(String value) {
    final normalized = value.trimLeft().toLowerCase();

    return normalized.startsWith('[ação clínica pura') ||
        normalized.startsWith('[acción clínica pura');
  }

  static List<String> _mergeClinicalText(
    Iterable<String> primary,
    Iterable<String> fallback,
  ) {
    final result = <String>[];
    final seen = <String>{};

    for (final item in <String>[...primary, ...fallback]) {
      final value = item.trim();
      final identity = _normalizeClinicalText(value);

      if (identity.isEmpty || !seen.add(identity)) {
        continue;
      }

      result.add(value);
    }

    return result;
  }

  static List<String> _withoutSummaryLines(Iterable<String> values) {
    return values
        .where((value) => !_isSummaryClinicalLine(value))
        .toList(growable: false);
  }

  static String _inlineAlertContent(String value) {
    final prepared = value
        .trim()
        .replaceAll(RegExp(r'[*_`#]+'), '')
        .replaceFirst(RegExp(r'^[📖🔑📌⚠️🟥🔴💊🔄⛔🚨🚩\-\*•\s]+'), '')
        .trim();

    final match = RegExp(
      r'^alerta(?:\s+cl[ií]nico)?\s*:\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(prepared);

    if (match == null) return '';

    return (match.group(1) ?? '')
        .replaceFirst(RegExp(r'^[\-\*•\s]+'), '')
        .trim();
  }

  static bool _isInlineAlertClinicalLine(String value) {
    final normalized = _normalizeClinicalText(value);

    return normalized == 'alerta' ||
        normalized == 'alerta clinico' ||
        normalized.startsWith('alerta ') ||
        normalized.startsWith('alerta clinico ');
  }

  static bool _isContractHeadingLine(String value) {
    final normalized = _normalizeClinicalText(value);

    return normalized == 'conduta' ||
        normalized == 'conducta' ||
        normalized == 'conduta imediata' ||
        normalized == 'conducta inmediata' ||
        normalized == 'conduta clinica imediata' ||
        normalized == 'conducta clinica inmediata' ||
        normalized == 'avaliacao inicial' ||
        normalized == 'evaluacion inicial' ||
        normalized == 'tratamiento' ||
        normalized == 'tratamento' ||
        normalized == 'tratamiento farmacologico' ||
        normalized == 'tratamento farmacologico' ||
        normalized == 'puntos clave' ||
        normalized == 'pontos chave' ||
        normalized == 'exames complementares' ||
        normalized == 'examenes complementarios' ||
        normalized == 'monitorizacao da evolucao' ||
        normalized == 'monitoramento da evolucao' ||
        normalized == 'monitorizacion de la evolucion' ||
        normalized == 'monitoreo de la evolucion' ||
        normalized == 'perguntas chave' ||
        normalized == 'perguntas importantes' ||
        normalized == 'perguntas para orientacao' ||
        normalized == 'preguntas clave' ||
        normalized == 'preguntas importantes' ||
        normalized == 'preguntas para orientacion' ||
        normalized == 'hard stop' ||
        normalized == 'red flag' ||
        normalized == 'red flags' ||
        normalized == 'alerta' ||
        normalized == 'alerta clinico';
  }

  static bool _isContinuationClinicalLine(String value) {
    final normalized = _normalizeClinicalText(value);

    return normalized == 'proximo' ||
        normalized.startsWith('proximo ') ||
        normalized == 'proximo paso' ||
        normalized.startsWith('proximo paso ') ||
        normalized == 'proximo passo' ||
        normalized.startsWith('proximo passo ') ||
        normalized == 'siguiente paso' ||
        normalized.startsWith('siguiente paso ');
  }

  static bool _duplicatesClinicalLine(
    String value,
    Iterable<String> displayed,
  ) {
    final identity = _normalizeClinicalText(value);

    if (identity.isEmpty) return false;

    for (final candidate in displayed) {
      final candidateIdentity = _normalizeClinicalText(candidate);

      if (candidateIdentity.isEmpty) continue;

      if (identity == candidateIdentity) {
        return true;
      }
    }

    return false;
  }

  static List<String> _medicationTexts(List<ClinicalPrescriptionItem> items) {
    return items
        .map(_medicationText)
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  static String _medicationText(ClinicalPrescriptionItem item) {
    return <String>[
      item.farmaco.trim(),
      item.posologia.trim(),
    ].where((value) => value.isNotEmpty).join(' ');
  }

  static String _medicationIdentity(ClinicalPrescriptionItem item) {
    return '${_normalizeClinicalText(item.farmaco)}|'
        '${_normalizeClinicalText(item.posologia)}';
  }
}

bool _isGeneralRecommendationClinicalLine(String value) {
  final normalized = _normalizeClinicalText(value);

  if (normalized.isEmpty) return false;

  return RegExp(
    r'^(?:reavaliar|reevaluar|avaliar|evaluar|considerar|'
    r'incluir|educar|monitorar|monitorear|solicitar|'
    r'orientar|acompanhar|vigiar|controlar)\b',
  ).hasMatch(normalized);
}

bool _isSummaryClinicalLine(String value) {
  final normalized = _normalizeClinicalText(value);

  return normalized.startsWith('resumo') || normalized.startsWith('resumen');
}

bool _isActionLikeClinicalLine(String value) {
  final normalized = _normalizeClinicalText(value);

  if (normalized.isEmpty) return false;

  if (RegExp(r'^(?:si|se)\b').hasMatch(normalized)) {
    return true;
  }

  if (RegExp(
    r'^(?:administrar|avaliar|evaluar|monitorar|monitorizar|'
    r'confirmar|investigar|iniciar|realizar|planificar|planejar|solicitar|'
    r'descartar|buscar|tratar|reduzir|reducir|controlar|'
    r'hidratar|suspender|usar|evitar|repetir|ajustar|'
    r'considerar|manejo|tratamiento|tratamento)\b',
  ).hasMatch(normalized)) {
    return true;
  }

  final hasDose = RegExp(
    r'\b\d+(?:[.,]\d+)?\s*(?:mg|mcg|g|ml|u|ui)\b',
  ).hasMatch(normalized);

  final hasRoute = RegExp(r'\b(?:iv|ev|vo|sl|sc|im|io)\b').hasMatch(normalized);

  return hasDose && hasRoute;
}

String _normalizeClinicalText(String value) {
  return value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('â', 'a')
      .replaceAll('é', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ç', 'c')
      .replaceAll('ª', '')
      .replaceAll('º', '')
      .replaceAll(RegExp(r'[*_`#]+'), '')
      .replaceAll(RegExp(r'[^a-z0-9%/]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
