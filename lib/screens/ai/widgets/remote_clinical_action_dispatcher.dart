import 'package:flutter/material.dart';

import '../../../models/remote_clinical_response.dart';
import 'remote_clinical_content_sheet.dart';

typedef RemoteClinicalPromptDispatcher = Future<void> Function(String prompt);
typedef RemoteClinicalContentLoader = Future<Map<String, dynamic>?> Function(
  String contentRef,
);

enum RemoteClinicalActionDispatchResult {
  dispatchedPrompt,
  openedContent,
  ignoredEmptyPrompt,
  ignoredMissingContentRef,
  contentUnavailable,
  unsupportedActionType,
}

class RemoteClinicalActionDispatcher {
  final RemoteClinicalPromptDispatcher onPrompt;
  final RemoteClinicalContentLoader loadContentRef;

  const RemoteClinicalActionDispatcher({
    required this.onPrompt,
    required this.loadContentRef,
  });

  Future<RemoteClinicalActionDispatchResult> dispatch(
    BuildContext context,
    RemoteClinicalAction action,
  ) async {
    switch (action.actionType) {
      case 'dispatch_prompt':
        final prompt = action.prompt.trim();
        if (prompt.isEmpty) {
          return RemoteClinicalActionDispatchResult.ignoredEmptyPrompt;
        }
        await onPrompt(prompt);
        return RemoteClinicalActionDispatchResult.dispatchedPrompt;

      case 'open_content_ref':
        final contentRef = action.contentRef.trim();
        if (contentRef.isEmpty) {
          return RemoteClinicalActionDispatchResult.ignoredMissingContentRef;
        }

        final content = await loadContentRef(contentRef);
        if (content == null || content.isEmpty) {
          return RemoteClinicalActionDispatchResult.contentUnavailable;
        }
        if (!context.mounted) {
          return RemoteClinicalActionDispatchResult.contentUnavailable;
        }

        await RemoteClinicalContentSheet.show(
          context,
          title: action.label,
          content: content,
        );
        return RemoteClinicalActionDispatchResult.openedContent;

      default:
        return RemoteClinicalActionDispatchResult.unsupportedActionType;
    }
  }
}
