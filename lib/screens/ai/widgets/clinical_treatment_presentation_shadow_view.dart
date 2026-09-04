import 'package:flutter/material.dart';
import 'package:medcases/home_v2/theme/home_v2_palette.dart';
import 'package:medcases/models/clinical_treatment_presentation.dart';

/// PHASE3I-J2F5: typed treatment renderer shadow.
///
/// Test-only visual surface. It is deliberately disconnected from
/// GuardiaClinicalResponseView, AppProvider and every productive screen.
final class ClinicalTreatmentPresentationShadowView extends StatelessWidget {
  const ClinicalTreatmentPresentationShadowView({
    super.key,
    required this.presentation,
    required this.dark,
    required this.languageCode,
  });

  final ClinicalTreatmentPresentation presentation;
  final bool dark;
  final String languageCode;

  bool get _isSpanish => languageCode.trim().toLowerCase().startsWith('es');

  @override
  Widget build(BuildContext context) {
    final palette = HomeV2Palette.resolve(dark);
    final groups = _groups();

    return Column(
      key: const ValueKey('typed_treatment_shadow_root'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < groups.length; index++) ...[
          if (index > 0) const SizedBox(height: 10),
          _ShadowSection(
            group: groups[index],
            palette: palette,
          ),
        ],
      ],
    );
  }

  List<_ShadowGroup> _groups() {
    return <_ShadowGroup>[
      _relationGroup(
        relation: ClinicalTreatmentRelation.concomitant,
        pt: 'Tratamento concomitante',
        es: 'Tratamiento concomitante',
      ),
      _relationGroup(
        relation: ClinicalTreatmentRelation.alternative,
        pt: 'Alternativas',
        es: 'Alternativas',
      ),
      _relationGroup(
        relation: ClinicalTreatmentRelation.conditional,
        pt: 'Uso condicional',
        es: 'Uso condicional',
      ),
      _relationGroup(
        relation: ClinicalTreatmentRelation.adjunct,
        pt: 'Tratamento adjuvante',
        es: 'Tratamiento adyuvante',
      ),
      _relationGroup(
        relation: ClinicalTreatmentRelation.rescue,
        pt: 'Resgate',
        es: 'Rescate',
      ),
      _relationGroup(
        relation: ClinicalTreatmentRelation.sequenceStep,
        pt: 'Sequência terapêutica',
        es: 'Secuencia terapéutica',
      ),
      _relationGroup(
        relation: ClinicalTreatmentRelation.contraindicated,
        pt: 'Contraindicado',
        es: 'Contraindicado',
        warning: true,
      ),
      _relationGroup(
        relation: ClinicalTreatmentRelation.unclassified,
        pt: 'Tratamento não classificado',
        es: 'Tratamiento no clasificado',
      ),
      _flagGroup(
        type: ClinicalSafetyFlagType.alert,
        pt: 'Alerta clínico',
        es: 'Alerta clínico',
        warning: true,
      ),
      _flagGroup(
        type: ClinicalSafetyFlagType.hardStop,
        pt: 'HARD STOP',
        es: 'HARD STOP',
        warning: true,
        hardStop: true,
      ),
    ].where((group) => group.lines.isNotEmpty).toList(growable: false);
  }

  _ShadowGroup _relationGroup({
    required ClinicalTreatmentRelation relation,
    required String pt,
    required String es,
    bool warning = false,
  }) {
    final items = presentation.itemsFor(relation);

    return _ShadowGroup(
      key: 'typed_relation_${relation.name}',
      title: _isSpanish ? es : pt,
      warning: warning,
      hardStop: false,
      lines: items
          .map(
            (item) => _ShadowLine(
              text: item.text,
              detail: _detailFor(item),
            ),
          )
          .toList(growable: false),
    );
  }

  _ShadowGroup _flagGroup({
    required ClinicalSafetyFlagType type,
    required String pt,
    required String es,
    required bool warning,
    bool hardStop = false,
  }) {
    return _ShadowGroup(
      key: 'typed_flag_${type.name}',
      title: _isSpanish ? es : pt,
      warning: warning,
      hardStop: hardStop,
      lines: presentation
          .flagsFor(type)
          .map((flag) => _ShadowLine(text: flag.text))
          .toList(growable: false),
    );
  }

  String _detailFor(ClinicalTreatmentPresentationItem item) {
    final details = <String>[
      if (item.condition.isNotEmpty)
        '${_isSpanish ? 'Condición' : 'Condição'}: ${item.condition}',
      if (item.rationale.isNotEmpty)
        '${_isSpanish ? 'Justificación' : 'Justificativa'}: ${item.rationale}',
    ];
    return details.join(' · ');
  }
}

final class _ShadowGroup {
  const _ShadowGroup({
    required this.key,
    required this.title,
    required this.lines,
    required this.warning,
    required this.hardStop,
  });

  final String key;
  final String title;
  final List<_ShadowLine> lines;
  final bool warning;
  final bool hardStop;
}

final class _ShadowLine {
  const _ShadowLine({
    required this.text,
    this.detail = '',
  });

  final String text;
  final String detail;
}

final class _ShadowSection extends StatelessWidget {
  const _ShadowSection({
    required this.group,
    required this.palette,
  });

  final _ShadowGroup group;
  final HomeV2Palette palette;

  @override
  Widget build(BuildContext context) {
    final warningColor = Theme.of(context).colorScheme.error;
    final titleColor = group.warning ? warningColor : palette.textPrimary;

    return Column(
      key: ValueKey(group.key),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${group.title}:',
          key: ValueKey('${group.key}_title'),
          style: TextStyle(
            color: titleColor,
            fontSize: group.hardStop ? 13.4 : 13.2,
            height: 1.18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        for (var index = 0; index < group.lines.length; index++)
          _ShadowTreatmentLine(
            key: ValueKey('${group.key}_item_$index'),
            line: group.lines[index],
            palette: palette,
            warning: group.warning,
          ),
      ],
    );
  }
}

final class _ShadowTreatmentLine extends StatelessWidget {
  const _ShadowTreatmentLine({
    super.key,
    required this.line,
    required this.palette,
    required this.warning,
  });

  final _ShadowLine line;
  final HomeV2Palette palette;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color =
        warning ? Theme.of(context).colorScheme.error : palette.textPrimary;
    final detailColor =
        warning ? color.withValues(alpha: 0.82) : palette.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(top: 3, left: 8),
      child: Semantics(
        label: line.detail.isEmpty ? line.text : '${line.text}. ${line.detail}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '• ',
                    style: TextStyle(
                      color: color,
                      fontSize: 14.2,
                      height: 1.24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: line.text,
                    style: TextStyle(
                      color: color,
                      fontSize: 14.2,
                      height: 1.24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (line.detail.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 1),
                child: Text(
                  line.detail,
                  style: TextStyle(
                    color: detailColor,
                    fontSize: 12.4,
                    height: 1.22,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
