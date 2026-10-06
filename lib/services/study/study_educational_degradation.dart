import 'dart:convert';
import '../../models/study_clinical_snapshot.dart';

/// Presentation-only recovery. Original records and strict audit remain failed.
/// Never guesses a missing translation, quantity, clinical condition or dose.
class StudyEducationalDegradation {
  static bool numeric(Map<String, dynamic> record) =>
      RegExp(r'\d|\b(?:NaN|Infinity)\b').hasMatch(jsonEncode(record['localization'])) ||
      ((record['clinical'] as Map?)?['items'] as List? ?? []).any((i) =>
          i is Map && ['quantity', 'frequency', 'route'].contains(i['kind']));

  static bool safeAtoms(Map<String, dynamic> record) {
    final labels = jsonEncode(record['localization']);
    if (RegExp(r'\b(?:NaN|Infinity|debug|system_prompt|chain.of.thought|STUDY_CANONICAL)\b|```|\\u0000', caseSensitive: false).hasMatch(labels)) return false;
    for (final i in ((record['clinical'] as Map?)?['items'] as List? ?? [])) {
      if (i is! Map) return false;
      if (['quantity', 'frequency'].contains(i['kind'])) {
        if (i.containsKey('amount')) {
          final a=i['amount'], u=i['upper'];
          if (a is! num || !a.isFinite || a < 0 ||
              (u != null && (u is! num || !u.isFinite || u < a))) return false;
        } else {
          // Legacy atoms are already shared; reject reversed ranges and
          // non-finite literals rather than attempting to repair numbers.
          final value=i['value'];
          if (value is! String || RegExp(r'\b(?:NaN|Infinity)\b',caseSensitive:false).hasMatch(value)) return false;
          final range=RegExp(r'(\d+(?:[.,]\d+)?)\s*[–-]\s*(\d+(?:[.,]\d+)?)').firstMatch(value);
          if (range!=null && double.parse(range[1]!.replaceAll(',','.'))>double.parse(range[2]!.replaceAll(',','.'))) return false;
        }
      }
    }
    return true;
  }

  static Map<String,dynamic>? recover(Map<String,dynamic> record, String reason) {
    if (record['type']!='fact' || record['clinical'] is! Map) return null;
    final c=record['clinical'] as Map;
    final items=c['items'];
    if (items is! List || record['localization'] is! Map) return null;
    // A condition pointing to an existing concept is a taxonomy error. In an
    // explanatory/diagnostic fact its ordered text and numeric atoms are still
    // fully bound. Operational regimens never get this numeric exception.
    if (reason=='study_snapshot_condition_binding' && safeAtoms(record)) {
      final numericFact=numeric(record);
      const educational={'definition','pathophysiology','diagnosis','classification','manifestations','causes','key_points','summary'};
      final refs=c['conditionIds'];
      final refsExist=refs is List && refs.every((id)=>items.any((i)=>i is Map && i['id']==id && ['concept','condition'].contains(i['kind'])));
      if (!numericFact || (educational.contains(c['section']) && ['explain','assess'].contains(c['actionId']) && refsExist)) {
        final copy=jsonDecode(jsonEncode(record)) as Map<String,dynamic>;
        copy['clinical']['conditionIds']=<String>[];
        copy['_educationalFallback']=true;
        try { StudyClinicalSnapshot.validateRecord(copy); return copy; } on FormatException { /* isolate independent complete prose below */ }
      }
    }
    // On unsafe/unbound numeric facts preserve only independently complete
    // paired sentences. Never stitch remnants across a removed numeric atom.
    final labels=record['localization'] as Map;
    final kept=<Map<String,dynamic>>[];final pairs=<String,dynamic>{};
    const proseKinds={'concept','condition','action','monitoring','warning','relation'};
    for(final raw in items) {
      if(raw is! Map || !proseKinds.contains(raw['kind']) || raw['id'] is! String) continue;
      final id=raw['id'] as String,pair=labels[id];
      if(pair is! Map || pair.length!=2) continue;
      bool complete(Object? text)=>text is String && text.trim().split(RegExp(r'\s+')).length>=4 &&
        RegExp(r'[.!?]$').hasMatch(text.trim()) &&
        !RegExp(r'^(?:seg[uú]n|conforme|com|con|para|por|sem|sin|e|y|mas|pero|at[eé]|hasta|ap[oó]s|despu[eé]s|antes|neste|en este)\b',caseSensitive:false).hasMatch(text.trim()) && !RegExp(r'\d|\b(?:NaN|Infinity|debug|system_prompt|chain.of.thought|STUDY_CANONICAL)\b|[{}]|```',caseSensitive:false).hasMatch(text);
      if(!complete(pair['pt'])||!complete(pair['es'])) continue;
      kept.add(Map<String,dynamic>.from(raw));pairs[id]=pair;
    }
    if(kept.isEmpty) return null;
    final copy=jsonDecode(jsonEncode(record)) as Map<String,dynamic>;
    copy['clinical']['items']=kept;copy['clinical']['conditionIds']=<String>[];
    copy['localization']=pairs;copy['_educationalFallback']=true;
    try { StudyClinicalSnapshot.validateRecord(copy);return copy; } on FormatException { return null; }
  }
}
