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

    return Semantics(
      container: true,
      label: _isSpanish
          ? 'Resumen clínico estructurado'
          : 'Resumo clínico estruturado',
      child: Column(
        key: const ValueKey('structured_clinical_output'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ClinicalSectionCard(
            key: const ValueKey('clinical_immediate_section'),
            icon:
                isPlantaoMode ? Icons.emergency_rounded : Icons.school_rounded,
            title: isPlantaoMode
                ? (_isSpanish ? 'Acción inmediata' : 'Ação imediata')
                : (_isSpanish ? 'Síntesis clínica' : 'Síntese clínica'),
            accentColor: isPlantaoMode ? colors.error : colors.primary,
            children: [
              _ClinicalField(
                key: const ValueKey('clinical_diagnosis_field'),
                label:
                    _isSpanish ? 'Hipótesis principal' : 'Hipótese principal',
                value: output.diagnosticoHeuristico,
                emphasized: true,
              ),
              const SizedBox(height: 12),
              _ClinicalField(
                key: const ValueKey('clinical_conduct_field'),
                label: _isSpanish ? 'Conducta inmediata' : 'Conduta imediata',
                value: output.condutaImediata,
              ),
            ],
          ),
          if (output.prescricao.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ClinicalSectionCard(
              key: const ValueKey('clinical_prescription_section'),
              icon: Icons.medication_rounded,
              title: _isSpanish
                  ? 'Prescripción estructurada'
                  : 'Prescrição estruturada',
              accentColor: colors.tertiary,
              children: [
                for (var index = 0;
                    index < output.prescricao.length;
                    index++) ...[
                  _PrescriptionRow(
                    key: ValueKey('clinical_prescription_item_$index'),
                    item: output.prescricao[index],
                  ),
                  if (index < output.prescricao.length - 1)
                    const Divider(height: 24),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ClinicalSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accentColor;
  final List<Widget> children;

  const _ClinicalSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.accentColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      icon,
                      size: 19,
                      color: accentColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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

  const _ClinicalField({
    super.key,
    required this.label,
    required this.value,
    this.emphasized = false,
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
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 5),
        SelectableText(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            height: 1.42,
            fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _PrescriptionRow extends StatelessWidget {
  final ClinicalPrescriptionItem item;

  const _PrescriptionRow({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

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
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              SelectableText(
                item.posologia,
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
