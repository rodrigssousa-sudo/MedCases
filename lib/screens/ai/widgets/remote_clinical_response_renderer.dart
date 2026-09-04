import 'package:flutter/material.dart';

import '../../../models/remote_clinical_response.dart';
import 'immutable_local_progressive_reveal.dart';
import 'remote_clinical_action_button.dart';

typedef RemoteClinicalActionHandler = void Function(
  RemoteClinicalAction action,
);

class RemoteClinicalResponseRenderer extends StatelessWidget {
  final RemoteClinicalResponse response;
  final RemoteClinicalActionHandler onAction;
  final Widget Function(BuildContext context, String visibleText) textBuilder;
  final Widget? waitingForFactsBuilder;

  const RemoteClinicalResponseRenderer({
    super.key,
    required this.response,
    required this.onAction,
    required this.textBuilder,
    this.waitingForFactsBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (response.isWaitingForFacts) {
      return waitingForFactsBuilder ??
          _WaitingForFactsCard(
            response: response,
            onAction: onAction,
          );
    }

    if (!response.isReady) {
      return const SizedBox.shrink();
    }

    final primary = response.primaryAction;
    final classification = response.classificationAction;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (response.supportsImmutableLocalReveal)
          ImmutableLocalProgressiveReveal(
            committedText: response.text,
            builder: textBuilder,
          )
        else
          textBuilder(context, response.text),
        if (primary?.isRenderable == true ||
            classification?.isRenderable == true) ...[
          const SizedBox(height: 12),
          if (primary?.isRenderable == true)
            RemoteClinicalActionButton(
              action: primary!,
              onPressed: () => onAction(primary),
            ),
          if (primary?.isRenderable == true &&
              classification?.isRenderable == true)
            const SizedBox(height: 8),
          if (classification?.isRenderable == true)
            RemoteClinicalActionButton(
              action: classification!,
              secondary: true,
              onPressed: () => onAction(classification),
            ),
        ],
      ],
    );
  }
}

class _WaitingForFactsCard extends StatelessWidget {
  final RemoteClinicalResponse response;
  final RemoteClinicalActionHandler onAction;

  const _WaitingForFactsCard({
    required this.response,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final missingFacts = response.classification.missingFacts;
    final action = response.primaryAction;
    final classificationAction = response.classificationAction;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            response.language.toLowerCase().startsWith('pt')
                ? 'Faltam dados para definir a classificação com segurança.'
                : 'Faltan datos para definir la clasificación con seguridad.',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (missingFacts.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final fact in missingFacts)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $fact',
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
          if (action?.isRenderable == true) ...[
            const SizedBox(height: 10),
            RemoteClinicalActionButton(
              action: action!,
              onPressed: () => onAction(action),
            ),
          ],
          if (classificationAction?.isRenderable == true) ...[
            const SizedBox(height: 8),
            RemoteClinicalActionButton(
              action: classificationAction!,
              secondary: true,
              onPressed: () => onAction(classificationAction),
            ),
          ],
        ],
      ),
    );
  }
}
