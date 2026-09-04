import 'package:flutter/material.dart';
import 'package:medcases/home_v2/theme/home_v2_palette.dart';
import 'package:medcases/models/clinical_structured_output.dart';
import 'package:medcases/services/well_formed_utf16.dart';
import 'package:medcases/screens/ai/widgets/clinical_treatment_presentation_shadow_view.dart';

/// PHASE3I-J2F10B: controlled productive visual integration.
const bool _typedTreatmentVisualEnabledByDefault = bool.fromEnvironment(
  'MEDCASES_TYPED_TREATMENT_VISUAL',
  defaultValue: true,
);

// MEDCASES_TRUE_LAST_UTF16_RENDER_BOUNDARY_V1
String _guardiaUtf16Safe(String value) => WellFormedUtf16.normalize(value);

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

    final notifierText = _guardiaUtf16Safe(
      widget.streamingTextNotifier?.value ?? '',
    ).trim();

    if (!widget.isStreaming && widget.rawText.trim().isNotEmpty) {
      _displayText = _guardiaUtf16Safe(widget.rawText);
    } else if (notifierText.isNotEmpty) {
      _displayText = notifierText;
    } else if (oldWidget.rawText != widget.rawText ||
        oldWidget.isStreaming != widget.isStreaming) {
      _displayText = _guardiaUtf16Safe(widget.rawText);
    }
  }

  @override
  void dispose() {
    _detachNotifier();
    super.dispose();
  }

  String _initialText() {
    final notifierText = _guardiaUtf16Safe(
      widget.streamingTextNotifier?.value ?? '',
    ).trim();

    if (!widget.isStreaming && widget.rawText.trim().isNotEmpty) {
      return widget.rawText;
    }

    return notifierText.isNotEmpty
        ? notifierText
        : _guardiaUtf16Safe(widget.rawText);
  }

  void _attachNotifier(ValueNotifier<String>? notifier) {
    _attachedNotifier = notifier;
    notifier?.addListener(_handleStreamingSnapshot);

    final snapshot = _guardiaUtf16Safe(notifier?.value ?? '');

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

    final snapshot = _guardiaUtf16Safe(_attachedNotifier?.value ?? '');

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
        ? _guardiaUtf16Safe(widget.rawText)
        : (_displayText.trim().isNotEmpty
              ? _guardiaUtf16Safe(_displayText)
              : _guardiaUtf16Safe(widget.rawText));
    final stablePresentationText = _guardiaUtf16Safe(
      GuardiaStreamingPresentation.stableBeforeHardStop(
        rawText: _guardiaUtf16Safe(effectiveText),
        isStreaming: widget.isStreaming,
      ),
    );
    // PLANTAO_VISIBLE_NO_EMOJI_PRESENTATION_V1
    // O parser recebe o RAW canônico intacto; emojis são removidos somente da projeção visual.
    final visiblePresentationText = _guardiaUtf16Safe(
      GuardiaNoEmojiPresentation.clean(
        _guardiaUtf16Safe(stablePresentationText),
      ),
    );
    // MEDCASES_PLANTAO_MARKDOWN_TABLE_TRUE_RENDER_V1
    // MEDCASES_PLANTAO_STREAMING_MARKDOWN_TABLE_NO_RAW_FLASH_V1
    final tableSourceText = widget.isStreaming
        ? GuardiaMarkdownTableProjection.sanitizeStreamingText(
            stablePresentationText,
          )
        : stablePresentationText;
    final tableProjection = GuardiaMarkdownTableProjection.parse(
      tableSourceText,
    );
    final content = _GuardiaDisplayContent.from(
      rawText: tableProjection.textWithoutTables,
      output: widget.output,
    );
    final m67DestinationTable = tableProjection.tables.any(
      _guardiaM67IsDestinationTable,
    );
    final m67Limitations = _guardiaM67ExtractLimitations(
      tableProjection.textWithoutTables,
    );
    final m67LimitationNorms = m67Limitations
        .map(_normalizeClinicalText)
        .toSet();
    final m67HardStops = content.hardStops
        .where((item) {
          final normalized = _normalizeClinicalText(item);
          return !_guardiaM67IsLimitationsHeading(item) &&
              !m67LimitationNorms.contains(normalized);
        })
        .toList(growable: false);

    final m67PriorBaseTitleProjection = _GuardiaTitleProjection.resolve(
      diagnosis: content.diagnosis,
      userText: widget.userText,
      isContinuation: widget.userInitiatedByAction,
      isSpanish: _isSpanish,
    );
    final baseTitleProjection = m67DestinationTable
        ? _GuardiaTitleProjection(
            headerTitle: _isSpanish
                ? 'Destino del paciente'
                : 'Destino do paciente',
            diagnosisCore: m67PriorBaseTitleProjection.diagnosisCore,
            demoteDiagnosisToHypothesis: false,
          )
        : m67PriorBaseTitleProjection;
    // M77_R10_R3: preserve the existing generic direct-topic authority through
    // later M54/M55E canonicalization. This does not add a pathology-specific
    // branch: it reuses the same semantic owner already used by title resolve.
    final m77DirectExplicitTopicTitle = !widget.userInitiatedByAction
        ? _guardiaExplicitDirectTopicTitle(
            userText: widget.userText,
            userNorm: _normalizeClinicalText(widget.userText),
            isSpanish: _isSpanish,
          )
        : null;
    final m54RawConcreteDiseaseTitle = !widget.userInitiatedByAction
        ? _guardiaM54RawConcreteDiseaseTitle(stablePresentationText)
        : null;
    final m54DiagnosisCore = baseTitleProjection.diagnosisCore.trim();
    final m54CanonicalDiseaseTitle =
        _guardiaConcreteClinicalIdentity(
          _normalizeClinicalText(m54DiagnosisCore),
        )
        ? m54DiagnosisCore
        : null;
    final m54DiseaseTitle =
        m54RawConcreteDiseaseTitle ?? m54CanonicalDiseaseTitle;
    final m54GenericBaseTitle = _guardiaM54GenericTopLevelTitle(
      baseTitleProjection.headerTitle,
    );
    var titleProjection =
        !widget.userInitiatedByAction &&
            !baseTitleProjection.demoteDiagnosisToHypothesis &&
            m54GenericBaseTitle &&
            m54DiseaseTitle != null
        ? _GuardiaTitleProjection(
            headerTitle: m54DiseaseTitle,
            diagnosisCore: m54DiseaseTitle,
            demoteDiagnosisToHypothesis: false,
          )
        : baseTitleProjection;
    final m55eDiseaseTitle = widget.userInitiatedByAction
        ? titleProjection.headerTitle
        : GuardiaM55ePresentationPolicy.canonicalDiseaseTitle(
            parsedDiagnosis: titleProjection.diagnosisCore,
            rawText: stablePresentationText,
            isSpanish: _isSpanish,
          );
    if (!widget.userInitiatedByAction &&
        !titleProjection.demoteDiagnosisToHypothesis &&
        m55eDiseaseTitle.isNotEmpty) {
      final m55eUserNorm = _normalizeClinicalText(widget.userText);
      final m55eDependentTaskTitle =
          _guardiaDependentTaskOnlyFollowup(m55eUserNorm)
          ? _guardiaTaskAwareTitle(
              userNorm: m55eUserNorm,
              isSpanish: _isSpanish,
            )
          : null;
      final m55eHeaderTitle = m55eDependentTaskTitle != null
          ? '$m55eDependentTaskTitle — $m55eDiseaseTitle'
          : m55eDiseaseTitle;
      titleProjection = _GuardiaTitleProjection(
        headerTitle: m55eHeaderTitle,
        diagnosisCore: m55eDiseaseTitle,
        demoteDiagnosisToHypothesis: false,
      );
    }
    if (!widget.userInitiatedByAction &&
        m77DirectExplicitTopicTitle != null &&
        m77DirectExplicitTopicTitle.trim().isNotEmpty) {
      titleProjection = _GuardiaTitleProjection(
        headerTitle: m77DirectExplicitTopicTitle,
        diagnosisCore: m77DirectExplicitTopicTitle,
        demoteDiagnosisToHypothesis: false,
      );
    }
    final displayDiagnosis = titleProjection.headerTitle.trim();
    final displayImmediate =
        GuardiaM55ePresentationPolicy.withoutDuplicatedDiseaseTitle(
          items: content.immediate,
          title: displayDiagnosis,
        );
    final keyPointsAreHypotheses =
        titleProjection.demoteDiagnosisToHypothesis &&
        _guardiaKeyPointsContainHypothesis(content.keyPoints);
    final hasUserCertaintyContext = widget.userText.trim().isNotEmpty;
    final hasExplicitConfirmedDiagnosis =
        _guardiaUserTextHasExplicitConfirmedDiagnosis(widget.userText);
    final allowMedicationPresentation =
        !content.isDifferential &&
        (hasExplicitConfirmedDiagnosis ||
            !hasUserCertaintyContext ||
            !titleProjection.demoteDiagnosisToHypothesis);
    final usesRedFlagsLabel = RegExp(
      r'^[ \t]*(?:[-*•][ \t]*)?(?:🚩[ \t]*)?'
      r'(?:[*_`#]+[ \t]*)*red[ \t]+flags?[ \t]*(?::|$)',
      caseSensitive: false,
      multiLine: true,
    ).hasMatch(visiblePresentationText);

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
          if (displayDiagnosis.isNotEmpty) ...[
            _DiagnosisHeader(
              diagnosis: titleProjection.headerTitle,
              palette: palette,
            ),
          ],
          if (displayImmediate.isNotEmpty) ...[
            if (displayDiagnosis.isNotEmpty)
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
            for (final item in displayImmediate)
              _BulletLine(text: item, palette: palette),
          ],
          if (allowMedicationPresentation && useTypedTreatmentVisual) ...[
            if (content.hasContentBeforeMedication) const SizedBox(height: 20),
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
            if (content.hasContentBeforeMedication) const SizedBox(height: 20),
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
          if (GuardiaMarkdownTableProjection.hasClassificationTables(
            tableProjection.tables,
          )) ...[
            // M55E_R4_CLASSIFICATION_HEADING_FROM_SUPER_AUDIT
            _SectionTitle(
              key: const ValueKey('guardia_classification_section'),
              title: _isSpanish ? 'Clasificación' : 'Classificação',
              palette: palette,
            ),
            const SizedBox(height: 5),
            const SizedBox(height: 10),
            for (
              var tableIndex = 0;
              tableIndex < tableProjection.tables.length;
              tableIndex++
            )
              if (GuardiaMarkdownTableProjection.isClassificationTable(
                tableProjection.tables[tableIndex],
              ))
                Padding(
                  padding: EdgeInsets.only(
                    bottom: tableIndex == tableProjection.tables.length - 1
                        ? 0
                        : 10,
                  ),
                  child: _GuardiaMarkdownTable(
                    key: ValueKey('guardia_markdown_table_$tableIndex'),
                    table: tableProjection.tables[tableIndex],
                    fitToViewport: true,
                  ),
                ),
          ],
          if (content.exams.isNotEmpty) ...[
            if (content.hasContentBeforeExams) const SizedBox(height: 20),
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
            if (content.hasContentBeforeEvolution) const SizedBox(height: 20),
            _SectionTitle(
              key: const ValueKey('guardia_evolution_section'),
              title: _isSpanish
                  ? 'Monitorización y reevaluación'
                  : 'Monitorização e reavaliação',
              palette: palette,
            ),
            const SizedBox(height: 5),
            for (final item in content.evolution)
              _BulletLine(text: item, palette: palette),
          ],
          if (content.questions.isNotEmpty) ...[
            if (content.hasContentBeforeQuestions) const SizedBox(height: 20),
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
            if (content.hasContentBeforeKeyPoints) const SizedBox(height: 20),
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
            if (content.hasContentBeforeAlerts) const SizedBox(height: 20),
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
          if (!useTypedTreatmentVisual && m67HardStops.isNotEmpty) ...[
            if (content.hasContentBeforeHardStops) const SizedBox(height: 20),
            if (usesRedFlagsLabel)
              _SectionTitle(
                key: const ValueKey('guardia_hard_stop_section'),
                title: _isSpanish
                    ? 'Red flags/escalamiento'
                    : 'Red flags/escalonamento',
                palette: palette,
                warning: true,
              )
            else
              _SectionTitle(
                key: const ValueKey('guardia_hard_stop_section'),
                title: _isSpanish
                    ? 'Red flags/escalamiento'
                    : 'Red flags/escalonamento',
                palette: palette,
                warning: true,
              ),
            const SizedBox(height: 5),
            for (final item in m67HardStops)
              _BulletLine(text: item, palette: palette, warning: true),
          ],
          if (m67Limitations.isNotEmpty) ...[
            if (m67HardStops.isNotEmpty) const SizedBox(height: 12),
            _SectionTitle(
              key: const ValueKey('guardia_limitations_section'),
              title: _isSpanish
                  ? 'Limitaciones / datos faltantes'
                  : 'Limitações / dados faltantes',
              palette: palette,
            ),
            const SizedBox(height: 5),
            for (final item in m67Limitations)
              _BulletLine(text: item, palette: palette),
          ],
          if (content.notes.isNotEmpty) ...[
            if (content.hasContentBeforeNotes) const SizedBox(height: 20),
            for (final item in content.notes)
              _PinnedLine(text: item, palette: palette),
          ],
          if (GuardiaMarkdownTableProjection.hasNonClassificationTables(
            tableProjection.tables,
          )) ...[
            const SizedBox(height: 10),
            for (
              var tableIndex = 0;
              tableIndex < tableProjection.tables.length;
              tableIndex++
            )
              if (!GuardiaMarkdownTableProjection.isClassificationTable(
                tableProjection.tables[tableIndex],
              ))
                Padding(
                  padding: EdgeInsets.only(
                    bottom: tableIndex == tableProjection.tables.length - 1
                        ? 0
                        : 10,
                  ),
                  child: _GuardiaMarkdownTable(
                    key: ValueKey('guardia_markdown_table_$tableIndex'),
                    table: tableProjection.tables[tableIndex],
                  ),
                ),
          ],
          if (content.fallbackLines.isNotEmpty &&
              (widget.isStreaming || !content.hasStructuredContent)) ...[
            if (content.hasStructuredContent) const SizedBox(height: 5),
            if (widget.userInitiatedByAction) const SizedBox(height: 14),
            for (final item in content.fallbackLines)
              widget.userInitiatedByAction
                  ? _ContinuationRefinedLine(text: item, palette: palette)
                  : _PartialLine(
                      text: GuardiaM55ePresentationPolicy.visibleText(item),
                      palette: palette,
                    ),
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

// M54_PHYSICAL_GLOBAL_DISEASE_TITLE_CONTRACT_V2
//
// Initial Plantão responses must not lose a concrete pathology/topic heading.
// IMPORTANT: dependent follow-up task titles remain authoritative. M54 only
// overrides a forbidden GENERIC top-level title.
String? _guardiaM54RawConcreteDiseaseTitle(String rawText) {
  for (final rawLine
      in rawText.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    final match = RegExp(
      r'^[🟥🔴]\s*(.+?)\s*$',
      unicode: true,
    ).firstMatch(line);
    if (match == null) return null;

    final core = _guardiaDiagnosisCore(match.group(1) ?? '');
    final normalized = _normalizeClinicalText(core);
    if (!_guardiaConcreteClinicalIdentity(normalized)) return null;
    return core;
  }
  return null;
}

bool _guardiaM54GenericTopLevelTitle(String title) {
  final normalized = _normalizeClinicalText(_guardiaDiagnosisCore(title));
  return <String>{
    'conducta clinica',
    'conduta clinica',
    'conducta inmediata',
    'conduta imediata',
    'clasificacion del paciente',
    'classificacao do paciente',
    'orientacion clinica',
    'orientacao clinica',
  }.contains(normalized);
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

    // PLANTAO_PRESENTATION_IDENTITY_LONG_FORM_TASK_TITLE_V1
    final longFormIdentitySupport =
        _guardiaLongFormUserSupportsDiagnosisIdentity(
          userNorm: userNorm,
          diagnosisNorm: diagnosisNorm,
          diagnosisBaseNorm: diagnosisBaseNorm,
        );
    final taskAwareTitle = _guardiaTaskAwareTitle(
      userNorm: userNorm,
      isSpanish: isSpanish,
    );
    // M65_CONTINUATION_REFINED_PRESENTATION_V1
    final continuationActionTitle = isContinuation
        ? _guardiaContinuationActionTitle(
            userNorm: userNorm,
            isSpanish: isSpanish,
          )
        : null;

    final directTopicOverride = !explicit && !longFormIdentitySupport
        ? directTopicTitle
        : null;
    final dependentTaskIdentityTitle =
        !longFormIdentitySupport &&
            taskAwareTitle != null &&
            _guardiaDependentTaskOnlyFollowup(userNorm) &&
            _guardiaConcreteClinicalIdentity(diagnosisNorm)
        ? '$taskAwareTitle — $core'
        : null;
    final hasUserCertaintyContext = userNorm.isNotEmpty;
    final keep =
        core.isNotEmpty &&
        (isContinuation ||
            !hasUserCertaintyContext ||
            (!differential && (explicit || longFormIdentitySupport)));
    return _GuardiaTitleProjection(
      headerTitle:
          continuationActionTitle ??
          directTopicOverride ??
          (keep
              ? core
              : (dependentTaskIdentityTitle ??
                    taskAwareTitle ??
                    (isSpanish
                        ? 'Orientación clínica'
                        : 'Orientação clínica'))),
      diagnosisCore: core.isEmpty ? diagnosis.trim() : core,
      demoteDiagnosisToHypothesis:
          directTopicOverride == null &&
          continuationActionTitle == null &&
          taskAwareTitle == null &&
          core.isNotEmpty &&
          !keep,
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
  final diagnosisHas =
      diagnosisNorm.contains('diverticulitis') ||
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

bool _guardiaLongFormUserSupportsDiagnosisIdentity({
  required String userNorm,
  required String diagnosisNorm,
  required String diagnosisBaseNorm,
}) {
  if (userNorm.isEmpty || diagnosisNorm.isEmpty) return false;

  const aliasGroups = <Set<String>>[
    <String>{'iamcest', 'iamcsst', 'stemi'},
    <String>{'iamest', 'iamsst', 'iamssst', 'nstemi'},
    <String>{'tep', 'tromboembolismo pulmonar', 'embolia pulmonar'},
    <String>{'epoc', 'dpoc'},
  ];

  for (final group in aliasGroups) {
    final userHas = group.any(userNorm.contains);
    final diagnosisHas =
        group.any(diagnosisNorm.contains) ||
        group.any(diagnosisBaseNorm.contains);
    if (userHas && diagnosisHas) return true;
  }

  // PLANTAO_PRESENTATION_STEMI_LONG_FORM_EQUIVALENCE_V2
  //
  // The provider may emit the same confirmed STEMI phenotype without the
  // IAMCEST/STEMI acronym. Treat those forms as the same presentation identity
  // only when ST elevation is affirmative. Explicit NSTE/negated elevation
  // remains a hard mismatch.
  bool isStemiAlias(String value) =>
      <String>['iamcest', 'iamcsst', 'stemi'].any(value.contains);

  bool isLongFormStemi(String value) {
    final myocardialInfarction = <String>[
      'infarto agudo de miocardio',
      'infarto agudo do miocardio',
      'infarto agudo de miocardio',
      'acute myocardial infarction',
    ].any(value.contains);

    final negatedElevation = <String>[
      'sin elevacion del st',
      'sin elevacion del segmento st',
      'sin supradesnivel',
      'sem elevacao do st',
      'sem elevacao do segmento st',
      'sem supradesnivel',
      'sem supradesnivelamento',
      'without st elevation',
      'non st elevation',
    ].any(value.contains);

    if (!myocardialInfarction || negatedElevation) return false;

    final affirmativeElevation = <String>[
      'con elevacion del st',
      'con elevacion del segmento st',
      'con segmento st elevado',
      'con st elevado',
      'con aumento del st',
      'con aumento del segmento st',
      'com elevacao do st',
      'com elevacao do segmento st',
      'com segmento st elevado',
      'com st elevado',
      'com aumento do st',
      'supradesnivel de st',
      'supradesnivelamento de st',
      'supra de st',
      'st elevation',
    ].any(value.contains);

    return affirmativeElevation;
  }

  final diagnosisCorpus = '$diagnosisNorm $diagnosisBaseNorm';
  if ((isStemiAlias(userNorm) && isLongFormStemi(diagnosisCorpus)) ||
      (isLongFormStemi(userNorm) && isStemiAlias(diagnosisCorpus))) {
    return true;
  }

  const weak = <String>{
    'agudo',
    'aguda',
    'grave',
    'clinico',
    'clinica',
    'paciente',
    'dolor',
    'sindrome',
    'diagnostico',
    'tratamiento',
    'tratamento',
    'manejo',
    'conducta',
    'conduta',
    'confirmado',
    'confirmada',
  };

  Set<String> strongTokens(String value) => value
      .split(RegExp(r'\s+'))
      .where((token) => token.length >= 5)
      .where((token) => !weak.contains(token))
      .toSet();

  final userTokens = strongTokens(userNorm);
  final diagnosisTokens = <String>{
    ...strongTokens(diagnosisNorm),
    ...strongTokens(diagnosisBaseNorm),
  };
  final overlap = userTokens.intersection(diagnosisTokens);

  return overlap.length >= 2 || overlap.any((token) => token.length >= 7);
}

bool _guardiaDependentTaskOnlyFollowup(String userNorm) {
  if (userNorm.isEmpty || userNorm.length > 180) return false;

  final hasDependentLead = <String>[
    'y ',
    'e ',
    'y cual ',
    'y que ',
    'e qual ',
    'e que ',
    'ahora ',
    'agora ',
  ].any(userNorm.startsWith);

  final hasTask = <String>[
    'clasificacion',
    'classificacao',
    'tratamiento',
    'tratamento',
    'farmacologico',
    'farmacologica',
    'manejo',
    'conducta',
    'conduta',
  ].any(userNorm.contains);

  return hasDependentLead && hasTask;
}

bool _guardiaConcreteClinicalIdentity(String diagnosisNorm) {
  if (diagnosisNorm.isEmpty) return false;
  return !<String>[
    'clasificacion',
    'classificacao',
    'conducta',
    'conduta',
    'tratamiento',
    'tratamento',
    'orientacion',
    'orientacao',
  ].any(diagnosisNorm.startsWith);
}

String? _guardiaTaskAwareTitle({
  required String userNorm,
  required bool isSpanish,
}) {
  if (userNorm.isEmpty) return null;

  if (<String>[
    'classificacao',
    'clasificacion',
    'classification',
    'gravidade',
    'gravedad',
    'severity',
    'estratific',
    'risco',
    'riesgo',
    'risk',
  ].any(userNorm.contains)) {
    return isSpanish ? 'Clasificación' : 'Classificação';
  }

  if (<String>[
    'tratamiento farmacologico',
    'tratamento farmacologico',
    'prescripcion',
    'prescricao',
    'medicacion',
    'medicacao',
    'farmacologico',
    'farmacologica',
  ].any(userNorm.contains)) {
    return isSpanish ? 'Tratamiento farmacológico' : 'Tratamento farmacológico';
  }

  if (<String>[
    'tratamiento',
    'tratamento',
    'manejo',
    'conducta',
    'conduta',
  ].any(userNorm.contains)) {
    return isSpanish ? 'Conducta clínica' : 'Conduta clínica';
  }

  return null;
}

String? _guardiaContinuationActionTitle({
  required String userNorm,
  required bool isSpanish,
}) {
  if (userNorm.isEmpty) return null;

  bool hasAny(List<String> tokens) =>
      tokens.any((token) => userNorm.contains(token));

  if (hasAny(const <String>[
    'definir destino',
    'destino del paciente',
    'destino do paciente',
  ])) {
    return isSpanish ? 'Destino del paciente' : 'Destino do paciente';
  }

  if (hasAny(const <String>[
    'completar estudios',
    'estudios y evolucion',
    'estudios e evolucion',
    'completar exames',
    'exames e evolucao',
  ])) {
    return isSpanish ? 'Estudios complementarios' : 'Exames complementares';
  }

  if (hasAny(const <String>[
    'vigilar evolucion',
    'acompanhar evolucao',
    'monitorizar evolucion',
    'monitorar evolucao',
  ])) {
    return isSpanish
        ? 'Monitorización y reevaluación'
        : 'Monitorização e reavaliação';
  }

  if (hasAny(const <String>['reevaluar respuesta', 'reavaliar resposta'])) {
    return isSpanish ? 'Reevaluación clínica' : 'Reavaliação clínica';
  }

  if (hasAny(const <String>['si no responde', 'se nao responder'])) {
    return isSpanish ? 'Si no responde' : 'Se não responder';
  }

  return null;
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

  final tokenCount = normalized
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .length;
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

// M70B_AIRY_MAJOR_SECTION_RHYTHM_V1
// M69_SINGLE_TITLE_DIVIDER_CLEAN_SECTION_RHYTHM_V1
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
    final parts = _MedicationTextParts.from(_guardiaUtf16Safe(text));

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
                fontWeight:
                    FontWeight.w400 /* M78_MEDICATION_BODY_HIERARCHY_ONLY_V1 */,
              ),
            ),
            if (parts.drug.isNotEmpty)
              TextSpan(
                text: parts.drug,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 14.4,
                  height: 1.24,
                  fontWeight: FontWeight.w400, // M78 medication body regular
                ),
              ),
            if (parts.dose.isNotEmpty)
              TextSpan(
                text: '${parts.drug.isNotEmpty ? ' ' : ''}${parts.dose}',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 14.4,
                  height: 1.24,
                  fontWeight: parts.drug.isEmpty
                      ? FontWeight.w700
                      : FontWeight.w400, // M79_STANDALONE_DOSE_LIST_EMPHASIS_V1
                ),
              ),
            if (parts.qualifier.isNotEmpty)
              TextSpan(
                text: parts.qualifier.startsWith(';')
                    ? parts.qualifier
                    : ' ${parts.qualifier}',
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
    // M68_PHARMA_NATURAL_SEPARATOR_V1 behavioral-owner
    // M67_GLOBAL_TREATMENT_PRESENTATION_V1
    final originalTrimmed = value.trim();
    final semicolonIndex = originalTrimmed.indexOf(';');
    final trimmed = semicolonIndex < 0
        ? originalTrimmed
        : originalTrimmed.substring(0, semicolonIndex).trim();
    final semicolonQualifier = semicolonIndex < 0
        ? ''
        : originalTrimmed.substring(semicolonIndex).trim();
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
      semicolonQualifier,
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
              text: _guardiaUtf16Safe(text),
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

class _GuardiaMarkdownTableData {
  const _GuardiaMarkdownTableData({required this.headers, required this.rows});

  final List<String> headers;
  final List<List<String>> rows;
}

class _GuardiaMarkdownTableProjectionResult {
  const _GuardiaMarkdownTableProjectionResult({
    required this.textWithoutTables,
    required this.tables,
  });

  final String textWithoutTables;
  final List<_GuardiaMarkdownTableData> tables;
}

/// Detecta tabelas Markdown GFM no texto final do Plantão e as separa do
/// parser clínico linha-a-linha. Assim as linhas `| ... |` nunca viram uma
/// lista/fallback visual e são materializadas por um Table Flutter verdadeiro.
// M55E_FINAL_PHYSICAL_SURFACE_V1
abstract final class GuardiaM55ePresentationPolicy {
  static String visibleText(String value) {
    if (value.isEmpty) return value;
    final out = StringBuffer();
    for (final rune in value.runes) {
      final pictographic =
          (rune >= 0x1F000 && rune <= 0x1FAFF) ||
          (rune >= 0x2600 && rune <= 0x27BF) ||
          rune == 0xFE0F ||
          rune == 0x200D ||
          rune == 0x20E3;
      if (!pictographic) out.writeCharCode(rune);
    }
    return out.toString().replaceAll(RegExp(r'[ \t]+\n'), '\n').trimRight();
  }

  static String canonicalDiseaseTitle({
    required String parsedDiagnosis,
    required String rawText,
    required bool isSpanish,
  }) {
    var candidate = visibleText(parsedDiagnosis).trim();
    if (!_isConcreteTitle(candidate)) candidate = _firstConcreteTitle(rawText);
    if (candidate.isEmpty) return '';
    final folded = _fold(candidate);
    final explicitStemi =
        folded.contains('iamcest') ||
        folded.contains('iamcsst') ||
        folded.contains('stemi') ||
        (folded.contains('infarto') &&
            folded.contains('elev') &&
            folded.contains('st'));
    if (explicitStemi) {
      return isSpanish
          ? 'INFARTO AGUDO DE MIOCARDIO CON ELEVACIÓN DEL ST (IAMCEST)'
          : 'INFARTO AGUDO DO MIOCÁRDIO COM ELEVAÇÃO DO ST (IAMCSST)';
    }
    return candidate;
  }

  static List<String> withoutDuplicatedDiseaseTitle({
    required List<String> items,
    required String title,
  }) => items
      .where((item) => !sameClinicalIdentity(item, title))
      .toList(growable: false);

  static bool sameClinicalIdentity(String left, String right) {
    final a = _fold(visibleText(left));
    final b = _fold(visibleText(right));
    if (a.isEmpty || b.isEmpty) return false;
    if (a == b) return true;
    final aStemi =
        a.contains('iamcest') || a.contains('iamcsst') || a.contains('stemi');
    final bStemi =
        b.contains('iamcest') || b.contains('iamcsst') || b.contains('stemi');
    return aStemi && bStemi;
  }

  static String _firstConcreteTitle(String rawText) {
    for (final raw in rawText.split('\n')) {
      final line = visibleText(raw)
          .trim()
          .replaceAll(RegExp(r'^[*_`#\s]+'), '')
          .replaceAll(RegExp(r'[*_`#\s]+$'), '')
          .trim();
      if (_isConcreteTitle(line)) return line;
    }
    return '';
  }

  static bool _isConcreteTitle(String value) {
    final line = value.trim();
    if (line.isEmpty ||
        line.length > 180 ||
        line.startsWith('|') ||
        line.startsWith('-') ||
        line.startsWith('•') ||
        RegExp(r'^[0-9]+[.)]\s').hasMatch(line)) {
      return false;
    }
    return !RegExp(
      // M55E_R6_GENERIC_CLINICAL_TASK_TITLE_NEGATION_V1
      r'^(conducta clinica inmediata|conduta clinica imediata|conducta clinica|conduta clinica|conducta inmediata|conduta imediata|tratamiento farmacologico|tratamento farmacologico|clasificacion|classificacao|clasificacion del paciente|classificacao do paciente|puntos clave|pontos chave|red flags|sinais de alerta|hard stop)(:|$)',
    ).hasMatch(_fold(line));
  }

  static String _fold(String value) => value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('ä', 'a')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('ë', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ì', 'i')
      .replaceAll('î', 'i')
      .replaceAll('ï', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ò', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ö', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ù', 'u')
      .replaceAll('û', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ç', 'c')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[*_`#]+'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

abstract final class GuardiaMarkdownTableProjection {
  // M55D_CLASSIFICATION_TABLE_SEMANTIC_SLOT_V1
  static bool isClassificationTable(_GuardiaMarkdownTableData table) {
    final header = _foldSemanticHeader(table.headers.join(' '));
    if (header.contains('clasificacion') ||
        header.contains('classificacao') ||
        header.contains('classification')) {
      return true;
    }
    final categoryLike =
        header.contains('categoria') || header.contains('category');
    final resultLike =
        header.contains('resultado') ||
        header.contains('result') ||
        header.contains('final');
    return categoryLike && resultLike;
  }

  static bool hasClassificationTables(List<_GuardiaMarkdownTableData> tables) =>
      tables.any(isClassificationTable);

  static bool hasNonClassificationTables(
    List<_GuardiaMarkdownTableData> tables,
  ) => tables.any((table) => !isClassificationTable(table));

  static String _foldSemanticHeader(String value) => value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('ä', 'a')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('ë', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ì', 'i')
      .replaceAll('î', 'i')
      .replaceAll('ï', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ò', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ö', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ù', 'u')
      .replaceAll('û', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ç', 'c')
      .replaceAll('ñ', 'n');

  // Streaming table fragments are not valid GFM yet. Hide the incomplete
  // trailing fragment while preserving the largest complete table prefix.
  static String sanitizeStreamingText(String rawText) {
    if (rawText.trim().isEmpty) return rawText;

    final normalized = rawText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    final lines = normalized.split('\n');
    if (lines.isEmpty) return rawText;

    var end = lines.length - 1;
    while (end >= 0 && lines[end].trim().isEmpty) {
      end--;
    }
    if (end < 0) return rawText;

    var start = end;
    while (start >= 0 && lines[start].trimLeft().startsWith('|')) {
      start--;
    }
    start++;

    if (start > end || !lines[start].trimLeft().startsWith('|')) {
      return rawText;
    }

    final prefix = lines.sublist(0, start);
    final candidate = lines.sublist(start, end + 1);

    String rebuild(List<String> visibleCandidate) {
      return <String>[...prefix, ...visibleCandidate].join('\n').trimRight();
    }

    if (candidate.length < 2) {
      return rebuild(const <String>[]);
    }

    final header = _splitRow(candidate[0]);
    if (header.length < 2) {
      return rebuild(const <String>[]);
    }

    final separator = _splitRow(candidate[1]);
    if (separator.length != header.length ||
        !separator.every(_isSeparatorCell)) {
      return rebuild(const <String>[]);
    }

    var completeLineCount = 2;

    for (var index = 2; index < candidate.length; index++) {
      final row = _splitRow(candidate[index]);
      if (row.length != header.length) {
        break;
      }
      completeLineCount = index + 1;
    }

    if (completeLineCount < 3) {
      return rebuild(const <String>[]);
    }

    return rebuild(candidate.sublist(0, completeLineCount));
  }

  static final RegExp _separatorCell = RegExp(r'^:?-{3,}:?$');

  static _GuardiaMarkdownTableProjectionResult parse(String rawText) {
    if (rawText.trim().isEmpty) {
      return _GuardiaMarkdownTableProjectionResult(
        textWithoutTables: rawText,
        tables: const <_GuardiaMarkdownTableData>[],
      );
    }

    final normalized = rawText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized.split('\n');
    final remaining = <String>[];
    final tables = <_GuardiaMarkdownTableData>[];

    var index = 0;
    while (index < lines.length) {
      if (index + 1 < lines.length) {
        final header = _splitRow(lines[index]);
        final separator = _splitRow(lines[index + 1]);

        final isTableStart =
            header.length >= 2 &&
            separator.length == header.length &&
            separator.every(_isSeparatorCell);

        if (isTableStart) {
          final rows = <List<String>>[];
          var cursor = index + 2;

          while (cursor < lines.length) {
            final row = _splitRow(lines[cursor]);
            if (row.length < 2) break;

            rows.add(
              List<String>.generate(
                header.length,
                (cellIndex) => cellIndex < row.length ? row[cellIndex] : '',
                growable: false,
              ),
            );
            cursor++;
          }

          tables.add(
            _GuardiaMarkdownTableData(
              headers: List<String>.unmodifiable(header),
              rows: List<List<String>>.unmodifiable(rows),
            ),
          );

          // Mantém uma fronteira textual para não colar semanticamente as
          // seções que estavam antes/depois da tabela.
          if (remaining.isNotEmpty && remaining.last.trim().isNotEmpty) {
            remaining.add('');
          }
          index = cursor;
          continue;
        }
      }

      remaining.add(lines[index]);
      index++;
    }

    return _GuardiaMarkdownTableProjectionResult(
      textWithoutTables: remaining.join('\n'),
      tables: List<_GuardiaMarkdownTableData>.unmodifiable(tables),
    );
  }

  static bool _isSeparatorCell(String value) {
    return _separatorCell.hasMatch(value.trim());
  }

  static List<String> _splitRow(String line) {
    var value = line.trim();
    if (!value.contains('|')) return const <String>[];

    if (value.startsWith('|')) value = value.substring(1);
    if (value.endsWith('|')) value = value.substring(0, value.length - 1);
    if (!value.contains('|')) return const <String>[];

    final cells = <String>[];
    var buffer = StringBuffer();
    var escaped = false;

    for (var i = 0; i < value.length; i++) {
      final char = value[i];

      if (escaped) {
        if (char != '|') buffer.write('\\');
        buffer.write(char);
        escaped = false;
        continue;
      }

      if (char == '\\') {
        escaped = true;
        continue;
      }

      if (char == '|') {
        cells.add(_cleanCell(buffer.toString()));
        buffer = StringBuffer();
        continue;
      }

      buffer.write(char);
    }

    if (escaped) buffer.write('\\');
    cells.add(_cleanCell(buffer.toString()));
    return cells;
  }

  static String _cleanCell(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'\*\*|__|`'), '')
        .trim();
  }
}

// M67_DIFF_SCOPED_GENERICITY_GATE
bool _guardiaM67IsLimitationsHeading(String value) {
  final normalized = _normalizeClinicalText(value)
      .replaceAll(RegExp(r'[^a-z0-9áéíóúüñãõâêôç]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  final isSpanish =
      normalized.contains('limitaciones') &&
      normalized.contains('datos') &&
      (normalized.contains('faltantes') || normalized.contains('ausentes'));
  final isPortuguese =
      normalized.contains('limitacoes') &&
      normalized.contains('dados') &&
      (normalized.contains('faltantes') || normalized.contains('ausentes'));

  return isSpanish || isPortuguese;
}

bool _guardiaM67IsMajorSectionHeading(String value) {
  final n = _normalizeClinicalText(value);
  return <String>{
    'conducta inmediata',
    'conduta imediata',
    'tratamiento farmacologico',
    'tratamento farmacologico',
    'clasificacion',
    'classificacao',
    'monitorizacion y reevaluacion',
    'monitorizacao e reavaliacao',
    'monitorizacion de la evolucion',
    'monitorizacao da evolucao',
    'puntos clave',
    'pontos chave',
    'red flags',
    'red flags escalamiento',
    'red flags escalonamento',
    'examenes complementarios',
    'exames complementares',
    'preguntas clave',
    'perguntas chave',
  }.contains(n);
}

String _guardiaM67CleanBullet(String value) {
  return value
      .trim()
      .replaceAll(RegExp(r'^[\-\*•]\s*'), '')
      .replaceAll(RegExp(r'^\d+[.)]\s*'), '')
      .replaceAll(RegExp(r'[*_`#]+'), '')
      .trim();
}

List<String> _guardiaM67ExtractLimitations(String rawText) {
  final out = <String>[];
  var active = false;

  for (final raw
      in rawText.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;

    final withoutColon = line.replaceFirst(RegExp(r':\s*$'), '');
    if (_guardiaM67IsLimitationsHeading(withoutColon)) {
      active = true;
      continue;
    }
    if (!active) continue;

    if (_guardiaM67IsMajorSectionHeading(withoutColon) ||
        line.startsWith('|')) {
      break;
    }

    final cleaned = _guardiaM67CleanBullet(line);
    if (cleaned.isNotEmpty && !out.contains(cleaned)) {
      out.add(cleaned);
    }
  }

  return List<String>.unmodifiable(out);
}

bool _guardiaM67IsDestinationTable(_GuardiaMarkdownTableData table) {
  if (table.headers.length != 2 || table.rows.length < 4) return false;

  final labels = table.rows
      .where((row) => row.isNotEmpty)
      .map((row) => _normalizeClinicalText(row.first))
      .toList(growable: false);

  bool hasAny(bool Function(String value) test) => labels.any(test);

  final observation = hasAny(
    (value) => value == 'observacion' || value == 'observacao',
  );
  final admission = hasAny(
    (value) =>
        value == 'ingreso' ||
        value == 'internacion' ||
        value == 'internacao' ||
        value == 'admissao',
  );
  final critical = hasAny(
    (value) =>
        value == 'uci' ||
        value == 'uti' ||
        value.contains('cuidados intensivos'),
  );
  final discharge = hasAny(
    (value) =>
        value == 'alta' ||
        value == 'alta hospitalaria' ||
        value == 'alta hospitalar',
  );

  return observation && admission && critical && discharge;
}

class _GuardiaM67DestinationTableVertical extends StatelessWidget {
  const _GuardiaM67DestinationTableVertical({required this.table});

  final _GuardiaMarkdownTableData table;

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style;

    return Column(
      key: const ValueKey('guardia_destination_table_vertical'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var index = 0; index < table.rows.length; index++)
          if (table.rows[index].length >= 2)
            Padding(
              padding: EdgeInsets.only(top: index == 0 ? 2 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    table.rows[index][0],
                    style: base.copyWith(
                      fontSize: 16.0,
                      height: 1.28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    table.rows[index][1],
                    style: base.copyWith(
                      fontSize: 14.4,
                      height: 1.48,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _GuardiaMarkdownTable extends StatelessWidget {
  const _GuardiaMarkdownTable({
    super.key,
    required this.table,
    this.fitToViewport = false,
  });

  final _GuardiaMarkdownTableData table;
  final bool fitToViewport;

  @override
  Widget build(BuildContext context) {
    if (_guardiaM67IsDestinationTable(table)) {
      return _GuardiaM67DestinationTableVertical(table: table);
    }

    final theme = Theme.of(context);
    final divider = theme.dividerColor.withOpacity(0.58);
    final headerBackground = theme.colorScheme.primary.withOpacity(
      theme.brightness == Brightness.dark ? 0.12 : 0.07,
    );

    Widget buildTable({Map<int, TableColumnWidth>? columnWidths}) => Container(
      decoration: BoxDecoration(
        border: Border.all(color: divider, width: 0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: columnWidths,
        defaultColumnWidth: const IntrinsicColumnWidth(),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: TableBorder(
          horizontalInside: BorderSide(color: divider, width: 0.6),
          verticalInside: BorderSide(color: divider, width: 0.6),
        ),
        children: <TableRow>[
          TableRow(
            decoration: BoxDecoration(color: headerBackground),
            children: <Widget>[
              for (final header in table.headers)
                _GuardiaMarkdownTableCell(text: header, header: true),
            ],
          ),
          for (final row in table.rows)
            TableRow(
              children: <Widget>[
                for (final cell in row)
                  _GuardiaMarkdownTableCell(text: cell, header: false),
              ],
            ),
        ],
      ),
    );

    if (fitToViewport && table.headers.length == 2) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : MediaQuery.of(context).size.width - 32;
          return SizedBox(
            width: width,
            child: buildTable(
              columnWidths: const <int, TableColumnWidth>{
                0: FractionColumnWidth(0.38),
                1: FractionColumnWidth(0.62),
              },
            ),
          );
        },
      );
    }

    final viewportWidth = MediaQuery.of(context).size.width;
    final minWidth = viewportWidth > 314 ? viewportWidth - 34 : 280.0;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth),
        child: buildTable(),
      ),
    );
  }
}

class _GuardiaMarkdownTableCell extends StatelessWidget {
  const _GuardiaMarkdownTableCell({required this.text, required this.header});

  final String text;
  final bool header;

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Text(
        text,
        softWrap: true,
        style: base.copyWith(
          fontSize: header ? 12.5 : 12.3,
          height: 1.34,
          fontWeight: header ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

// M66_CONTINUATION_TYPOGRAPHY_VERTICAL_RHYTHM_V1
class _ContinuationRefinedLine extends StatelessWidget {
  final String text;
  final HomeV2Palette palette;

  const _ContinuationRefinedLine({required this.text, required this.palette});

  static final RegExp _standaloneHeading = RegExp(
    r'^(?:\d+[.)]\s*)?(?:observaci[oó]n|observa[cç][aã]o|ingreso|'
    r'internaci[oó]n|interna[cç][aã]o|uci|uti|alta)\s*:?\s*$',
    caseSensitive: false,
  );

  static final RegExp _labelBody = RegExp(
    r'^((?:\d+[.)]\s*)?[^:]{2,58}:)\s*(.+)$',
    caseSensitive: false,
  );

  @override
  Widget build(BuildContext context) {
    final value = _guardiaUtf16Safe(text).trim();
    if (value.isEmpty) {
      return const SizedBox(height: 4);
    }

    if (_standaloneHeading.hasMatch(value)) {
      final title = value.replaceFirst(RegExp(r':\s*$'), '');
      return Padding(
        key: ValueKey('guardia_continuation_heading_${text.hashCode}'),
        padding: const EdgeInsets.only(top: 18, bottom: 4),
        child: Text(
          title,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 16.0,
            height: 1.28,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final labeled = _labelBody.firstMatch(value);
    if (labeled != null) {
      return Padding(
        key: ValueKey('guardia_continuation_labeled_${text.hashCode}'),
        padding: const EdgeInsets.only(top: 12),
        child: RichText(
          text: TextSpan(
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 14.4,
              height: 1.48,
              fontWeight: FontWeight.w400,
            ),
            children: <InlineSpan>[
              TextSpan(
                text: '${labeled.group(1)} ',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(text: _guardiaUtf16Safe(labeled.group(2) ?? '')),
            ],
          ),
        ),
      );
    }

    return Padding(
      key: ValueKey('guardia_continuation_body_${text.hashCode}'),
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        value,
        style: TextStyle(
          color: palette.textPrimary,
          fontSize: 14.4,
          height: 1.48,
          fontWeight: FontWeight.w400,
        ),
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

      final exactPhysicalTail = _exactPhysicalTailSectionFor(trimmed);
      if (exactPhysicalTail != null) {
        section = exactPhysicalTail.section;
        if (exactPhysicalTail.content.isNotEmpty) {
          switch (exactPhysicalTail.section) {
            case _RawSection.evolution:
              _addText(evolution, exactPhysicalTail.content);
              break;
            case _RawSection.keyPoints:
              _addText(keyPoints, exactPhysicalTail.content);
              break;
            case _RawSection.hardStop:
              _addText(hardStops, exactPhysicalTail.content);
              break;
            case _RawSection.none:
            case _RawSection.immediate:
            case _RawSection.pharmacologic:
            case _RawSection.firstLine:
            case _RawSection.secondLine:
            case _RawSection.exams:
            case _RawSection.questions:
            case _RawSection.alert:
            case _RawSection.note:
            case _RawSection.ignored:
              break;
          }
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

  // MEDCASES_GUARDIA_EXACT_PHYSICAL_TAIL_ROUTER_V1_B_R0
  // Somente aliases já emitidos pelo contrato clínico físico. O raw usado por
  // Copiar/TTS/histórico não é alterado; apenas o bucket visual é recuperado.
  static ({_RawSection section, String content})? _exactPhysicalTailSectionFor(
    String rawLine,
  ) {
    final prepared = rawLine
        .trim()
        .replaceAll(RegExp(r'[*_`#]+'), '')
        .replaceFirst(RegExp(r'^[📖🔑📌⚠️🟥🔴💊🔄⛔🚨🚩\-\*•\s]+'), '')
        .trim();

    final match = RegExp(
      r'^(monitorizaci[oó]n\s+y\s+reevaluaci[oó]n|'
      r'monitoriza[cç][aã]o\s+e\s+reavalia[cç][aã]o|'
      r'monitoramento\s+e\s+reavalia[cç][aã]o|'
      r'puntos?\s*[-–—]?\s*clave|'
      r'pontos?\s*[-–—]?\s*chaves?|'
      r'red\s+flags?\s*(?:/|y|e)\s*(?:escalamiento|escalonamento))'
      r'\s*:?\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(prepared);

    if (match == null) return null;

    final heading = _normalize(match.group(1) ?? '');
    final content = _cleanLine(match.group(2) ?? '');

    if (heading.startsWith('monitor')) {
      return (section: _RawSection.evolution, content: content);
    }
    if (heading.startsWith('punto') || heading.startsWith('ponto')) {
      return (section: _RawSection.keyPoints, content: content);
    }
    return (section: _RawSection.hardStop, content: content);
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
    final safeValue = _guardiaUtf16Safe(value);
    final normalized = _normalize(safeValue);

    if (normalized.isEmpty) return;

    final exists = target.any(
      (item) => _normalize(_guardiaUtf16Safe(item)) == normalized,
    );

    if (!exists) target.add(safeValue);
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

/// Projeção visual sem emojis do Plantão.
///
/// Não altera palavras, números, doses, vias, intervalos, classificação ou
/// qualquer conteúdo clínico. Os marcadores continuam disponíveis no raw
/// canônico para parser, persistência e auditoria.
// PLANTAO_CONFIRMED_CASE_RX_SURFACE_V1
//
// A confirmação explícita no texto do médico é evidência de certeza clínica
// suficiente para permitir a superfície de medicação já estruturada no DTO.
// Isso NÃO cria fármacos/doses e NÃO vence um verdadeiro diferencial.
bool _guardiaUserTextHasExplicitConfirmedDiagnosis(String value) {
  var q = value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('ä', 'a')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('ë', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ì', 'i')
      .replaceAll('î', 'i')
      .replaceAll('ï', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ò', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ö', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ù', 'u')
      .replaceAll('û', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ç', 'c')
      .replaceAll('ñ', 'n');

  q = q.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (q.isEmpty) return false;

  final negatedConfirmation = RegExp(
    r'\b(?:no|sin|nao|sem)\s+(?:esta\s+)?'
    r'(?:confirmado|confirmada|diagnosticado|diagnosticada|confirmed)\b',
  ).hasMatch(q);
  if (negatedConfirmation) return false;

  return RegExp(
    r'\b(?:confirmado|confirmada|diagnostico confirmado|'
    r'diagnosticado|diagnosticada|confirmed)\b',
  ).hasMatch(q);
}

abstract final class GuardiaNoEmojiPresentation {
  static const List<String> _markers = <String>[
    '🟥',
    '🚨',
    '💊',
    '🔑',
    '🚩',
    '📌',
    '⛔',
    '🔴',
    '⚠️',
    '⚠',
    '🚫',
    '🛑',
  ];

  static String clean(String value) {
    if (value.isEmpty) return value;
    var out = value;
    for (final marker in _markers) {
      out = out.replaceAll(marker, '');
    }
    return out.split('\n').map((line) => line.trimRight()).join('\n');
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

    final unclassified = _mergeMedicationTextSemantically(
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

  // PLANTAO_SEMANTIC_MEDICATION_DEDUPE_V1
  static List<String> _mergeMedicationTextSemantically(
    Iterable<String> primary,
    Iterable<String> fallback,
  ) {
    final result = <String>[];
    final seen = <String>{};

    for (final item in <String>[...primary, ...fallback]) {
      final value = item.trim();
      final identity = _medicationSemanticIdentity(value);
      if (identity.isEmpty || !seen.add(identity)) continue;
      result.add(value);
    }
    return result;
  }

  static String _medicationSemanticIdentity(String value) {
    var normalized = _normalizeClinicalText(value);
    if (normalized.isEmpty) return '';

    normalized = normalized
        .replaceAll(
          RegExp(
            r'^(?:administrar|administre|iniciar|inicie|continuar|continua|'
            r'mantener|manter|seguir|infusion|infusao)\s+',
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'\b(?:infusion|infusao|continua|continuo|continuar|'
            r'mantener|manter)\b',
          ),
          ' ',
        )
        .replaceAll(
          RegExp(
            r'\b(?:para|como)\s+(?:mantener|manter)?\s*'
            r'(?:la\s+|a\s+)?(?:anticoagulacion|anticoagulacao)\b.*$',
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return normalized;
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
