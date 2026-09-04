import 'package:flutter/material.dart';

import '../../models/clinical_structured_output.dart';

/// Apresentação puramente visual do ClinicalStructuredOutput.
///
/// Não conhece provider, streaming, rede, histórico, scroll ou persistência.
/// O posicionamento acima ou abaixo do texto será responsabilidade da AI Screen.
class StructuredClinicalOutputView extends StatelessWidget {
  final ClinicalStructuredOutput output;
  final bool isPlantaoMode;
  final String languageCode;

  const StructuredClinicalOutputView({
    super.key,
    required this.output,
    required this.isPlantaoMode,
    required this.languageCode,
  });

  bool get _isSpanish => languageCode.toLowerCase().startsWith('es');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final immediateSection = _ClinicalSectionCard(
      key: const ValueKey('clinical_immediate_section'),
      icon: isPlantaoMode ? Icons.emergency_rounded : Icons.school_rounded,
      title: isPlantaoMode
          ? (_isSpanish ? 'Acción inmediata' : 'Ação imediata')
          : (_isSpanish ? 'Síntesis clínica' : 'Síntese clínica'),
      accentColor: isPlantaoMode ? colors.error : colors.primary,
      compact: isPlantaoMode,
      children: [
        _ClinicalField(
          key: const ValueKey('clinical_diagnosis_field'),
          label: _isSpanish ? 'Hipótesis principal' : 'Hipótese principal',
          value: output.diagnosticoHeuristico,
          emphasized: true,
          compact: isPlantaoMode,
        ),
        SizedBox(height: isPlantaoMode ? 7 : 12),
        _ClinicalField(
          key: const ValueKey('clinical_conduct_field'),
          label: _isSpanish ? 'Conducta inmediata' : 'Conduta imediata',
          value: output.condutaImediata,
          compact: isPlantaoMode,
        ),
      ],
    );

    final prescriptionSection = output.prescricao.isEmpty
        ? null
        : _ClinicalSectionCard(
            key: const ValueKey('clinical_prescription_section'),
            icon: Icons.medication_rounded,
            title: isPlantaoMode
                ? (_isSpanish ? 'Fármacos y dosis' : 'Fármacos e doses')
                : (_isSpanish
                    ? 'Prescripción estructurada'
                    : 'Prescrição estruturada'),
            accentColor: colors.tertiary,
            compact: isPlantaoMode,
            children: [
              for (var index = 0;
                  index < output.prescricao.length;
                  index++) ...[
                _PrescriptionRow(
                  key: ValueKey('clinical_prescription_item_$index'),
                  index: index,
                  item: output.prescricao[index],
                  prominent: isPlantaoMode,
                ),
                if (index < output.prescricao.length - 1)
                  isPlantaoMode
                      ? const SizedBox(height: 6)
                      : const Divider(height: 24),
              ],
            ],
          );

    final children = <Widget>[];

    if (isPlantaoMode) {
      if (prescriptionSection != null) {
        children.add(prescriptionSection);
        children.add(const SizedBox(height: 6));
      }

      children.add(immediateSection);
    } else {
      children.add(immediateSection);

      if (prescriptionSection != null) {
        children.add(const SizedBox(height: 12));
        children.add(prescriptionSection);
      }
    }

    return Semantics(
      container: true,
      label: _isSpanish
          ? 'Resumen clínico estructurado'
          : 'Resumo clínico estruturado',
      child: Column(
        key: const ValueKey('structured_clinical_output'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _ClinicalSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accentColor;
  final bool compact;
  final List<Widget> children;

  const _ClinicalSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.accentColor,
    required this.children,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(compact ? 12 : 18),
        border: Border.all(
          color: accentColor.withValues(
            alpha: compact ? 0.20 : 0.24,
          ),
          width: compact ? 0.8 : 1,
        ),
      ),
      child: Padding(
        padding: compact
            ? const EdgeInsets.fromLTRB(11, 9, 11, 10)
            : const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: accentColor.withValues(
                      alpha: compact ? 0.10 : 0.12,
                    ),
                    borderRadius: BorderRadius.circular(
                      compact ? 8 : 10,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(compact ? 5 : 8),
                    child: Icon(
                      icon,
                      size: compact ? 16 : 19,
                      color: accentColor,
                    ),
                  ),
                ),
                SizedBox(width: compact ? 8 : 10),
                Expanded(
                  child: Text(
                    title,
                    style: (compact
                            ? theme.textTheme.titleSmall
                            : theme.textTheme.titleMedium)
                        ?.copyWith(
                      fontWeight: compact ? FontWeight.w800 : FontWeight.w700,
                      letterSpacing: compact ? -0.1 : null,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 7 : 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ClinicalField extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;
  final bool compact;

  const _ClinicalField({
    super.key,
    required this.label,
    required this.value,
    this.emphasized = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            fontSize: compact ? 10.2 : null,
            fontWeight: compact ? FontWeight.w800 : FontWeight.w700,
            letterSpacing: compact ? 0.55 : 0.7,
          ),
        ),
        SizedBox(height: compact ? 2 : 5),
        SelectableText(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontSize: compact ? 13.2 : null,
            height: compact ? 1.25 : 1.42,
            fontWeight: emphasized
                ? FontWeight.w700
                : (compact ? FontWeight.w600 : FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

class _PrescriptionRow extends StatelessWidget {
  final int index;
  final ClinicalPrescriptionItem item;
  final bool prominent;

  const _PrescriptionRow({
    super.key,
    required this.index,
    required this.item,
    this.prominent = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (prominent) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: colors.tertiaryContainer.withValues(alpha: 0.48),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: colors.tertiary.withValues(alpha: 0.24),
            width: 0.8,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(9, 7, 10, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.medication_liquid_rounded,
                  size: 17,
                  color: colors.tertiary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      item.farmaco,
                      key: ValueKey('clinical_prescription_drug_$index'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onTertiaryContainer,
                        fontSize: 13.2,
                        height: 1.18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SelectableText(
                      item.posologia,
                      key: ValueKey('clinical_prescription_dose_$index'),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colors.onTertiaryContainer,
                        fontSize: 14.2,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.1,
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.circle,
          size: 7,
          color: colors.tertiary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                item.farmaco,
                key: ValueKey('clinical_prescription_drug_$index'),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              SelectableText(
                item.posologia,
                key: ValueKey('clinical_prescription_dose_$index'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.4,
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
