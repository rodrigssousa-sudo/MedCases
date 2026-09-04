import 'package:flutter/material.dart';

import '../../../models/remote_clinical_response.dart';
import 'remote_clinical_action_dispatcher.dart';
import 'remote_clinical_response_renderer.dart';

class RemoteClinicalRuntimeBridge {
  const RemoteClinicalRuntimeBridge._();

  static RemoteClinicalResponse? parse(Object? payload) {
    if (payload is Map<String, dynamic>) {
      return _safeParse(payload);
    }

    if (payload is Map) {
      return _safeParse(
        payload.map(
          (key, value) => MapEntry(key.toString(), value),
        ),
      );
    }

    return null;
  }

  static RemoteClinicalResponse? _safeParse(
    Map<String, dynamic> payload,
  ) {
    try {
      final response = RemoteClinicalResponse.fromJson(payload);

      if (response.schemaVersion != 'clinical_response_v1') {
        return null;
      }

      if (response.isReady && !response.supportsImmutableLocalReveal) {
        return null;
      }

      return response;
    } catch (_) {
      return null;
    }
  }
}

class RemoteClinicalRuntimeSurface extends StatelessWidget {
  final Object payload;
  final RemoteClinicalActionDispatcher actionDispatcher;
  final Widget Function(BuildContext context, String visibleText) textBuilder;
  final Widget fallback;

  const RemoteClinicalRuntimeSurface({
    super.key,
    required this.payload,
    required this.actionDispatcher,
    required this.textBuilder,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final response = RemoteClinicalRuntimeBridge.parse(payload);

    if (response == null) return fallback;

    return RemoteClinicalResponseRenderer(
      response: response,
      textBuilder: textBuilder,
      onAction: (action) {
        actionDispatcher.dispatch(context, action);
      },
    );
  }
}
