import '../ai/safety/ai_stream_trace.dart';
/// Request-owned append-only projection of safety-filtered cumulative text.
/// Completed markdown lines are immutable; an incomplete tail stays buffered.
class StableResponseBlocks {
  final List<String> _blocks = [];
  final Set<String> _seen = {};
  String _sourcePrefix = '';
  List<String> get blocks => List.unmodifiable(_blocks);
  String get text => _blocks.join('\n\n');
  String _key(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');

  List<String> _candidates(String snapshot, bool complete) {
    final lines = snapshot.replaceAll('\r\n', '\n').split('\n');
    if (!complete && !RegExp(r'[.!?]$').hasMatch(lines.last.trimRight()))
      lines.removeLast();
    final result = <String>[];
    var group = <String>[];
    var fenced = false;
    for (final line in lines) {
      if (line.trimLeft().startsWith('```')) {
        group.add(line);
        fenced = !fenced;
        if (!fenced) {
          result.add(group.join('\n'));
          group = [];
        }
        continue;
      }
      if (fenced) {
        group.add(line);
        continue;
      }
      if (line.contains('|')) {
        group.add(line);
        continue;
      }
      if (group.isNotEmpty) {
        result.add(group.join('\n'));
        group = [];
      }
      result.add(line);
    }
    if (complete && group.isNotEmpty) {
      if (fenced) group.add('```');
      result.add(group.join('\n'));
    }
    return result;
  }

  String accept(String snapshot, {bool complete = false}) {
    if (complete) {
      AiStreamTrace.mark('STABLE_COMPLETE_INPUT_CHARS', snapshot.length);
      AiStreamTrace.mark('STABLE_EXISTING_BLOCKS_CHARS', text.length);
    }
    var lines = _candidates(snapshot, complete);
    var start = 0;
    if (_blocks.isNotEmpty) {
      final anchor = lines.lastIndexWhere((s) => _key(s) == _key(_blocks.last));
      if (complete) AiStreamTrace.mark('STABLE_SNAPSHOT_ANCHOR_FOUND', anchor >= 0 ? 1 : 0);
      // A replay/rewrite without our latest committed anchor cannot replace it.
      if (anchor < 0) {
        if (_sourcePrefix.isEmpty || !snapshot.startsWith(_sourcePrefix)) {
          // Final snapshots have passed the presentation/safety pipeline. A
          // missing streaming anchor must not discard their remaining content.
          // Reconcile from that final snapshot, never retain stale fragments
          // which the final safety pass may have removed. Partial replay policy
          // remains unchanged.
          if (complete && snapshot.trim().isNotEmpty) {
            _blocks.clear();
            _seen.clear();
            for (final line in lines) {
              final key = _key(line);
              if (key.isNotEmpty && _seen.add(key)) _blocks.add(line.trim());
            }
            _sourcePrefix = snapshot;
            AiStreamTrace.mark('STABLE_BRANCH_FINAL_SNAPSHOT_RECONCILE', 1);
            AiStreamTrace.mark('STABLE_RETURNED_BLOCKS_CHARS', text.length);
            return text;
          }
          if (complete) {
            AiStreamTrace.mark('STABLE_BRANCH_ANCHOR_MISSING_RETURN_OLD', 1);
            AiStreamTrace.mark('STABLE_REASON_PREFIX_EMPTY', _sourcePrefix.isEmpty ? 1 : 0);
            AiStreamTrace.mark('STABLE_RETURNED_BLOCKS_CHARS', text.length);
          }
          return text;
        }
        if (complete) AiStreamTrace.mark('STABLE_BRANCH_PREFIX_APPEND', 1);
        lines = _candidates(snapshot.substring(_sourcePrefix.length), complete);
      } else {
        if (complete) AiStreamTrace.mark('STABLE_BRANCH_ANCHOR_APPEND', 1);
        start = anchor + 1;
      }
    }
    for (final line in lines.skip(start)) {
      final key = _key(line);
      if (key.isEmpty || !_seen.add(key)) continue;
      _blocks.add(line.trim());
    }
    if (complete || snapshot.endsWith('\n') || RegExp(r'[.!?]$').hasMatch(snapshot.trimRight())) {
      _sourcePrefix = snapshot;
    }
    if (complete) AiStreamTrace.mark('STABLE_RETURNED_BLOCKS_CHARS', text.length);
    return text;
  }
}
