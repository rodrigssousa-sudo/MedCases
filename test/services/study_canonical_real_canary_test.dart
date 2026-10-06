import 'package:medcases/services/study_continuation_resolver.dart';
import 'package:medcases/services/study/study_canonical_continuation.dart';
import 'package:medcases/services/study/study_canonical_schema.dart';
import 'package:medcases/services/study/study_canonical_response.dart';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_service.dart';
import 'package:medcases/services/ai_smart_router.dart';
import 'package:medcases/services/ai_gateway_service.dart';
import 'package:medcases/services/gemini_service_v2.dart';
import 'package:medcases/services/ai_pipeline/ai_request_contract.dart';
import 'package:medcases/services/ai/safety/clinical_request_safety.dart';
import 'package:medcases/services/ai/safety/clinical_safety_flow.dart';
import 'package:medcases/services/study_response_contract.dart';
import 'package:medcases/screens/ai/widgets/clinical_reference_resolver.dart';
import 'package:medcases/screens/ai/widgets/ai_failure_message.dart';
import 'study_global_validation_regression_test.dart' show finalizeStudyFixture;

void main() {
  test(
      'real canonical Study: one generation, paired localization and unchanged safety',
      () async {
    final port = int.parse(Platform.environment['STUDY_QA_BRIDGE_PORT']!);
    final client = HttpClient();
    addTearDown(client.close);
    final selected = Platform.environment['STUDY_QA_QUERIES']?.split('|');
    for (final query in [
      'Cetoacidosis',
      'Síndrome nefrótico',
      'Síndrome nefrítico',
      'Sepse',
      'IAM',
      'Asma',
      'Metformina',
      'AVC',
      'Anemia',
      'Hiperkalemia'
    ]) {
      if (selected != null && !selected.contains(query)) continue;
      const lang = 'es';
      final internal =
          ClinicalReferenceResolver.resolveStudy(userText: query)?.lines ??
              const <String>[];
      final context = ClinicalRequestContext(
          requestId: 'synthetic-qa',
          sessionId: 'synthetic-qa',
          uid: 'authorized-qa',
          mode: AiRequestMode.estudo,
          language: lang,
          userQuery: query,
          memory: ClinicalSafetyMemory().capture(
              uid: 'authorized-qa',
              sessionId: 'synthetic-qa',
              userQuery: query),
          evidence: ClinicalEvidenceBundle(),
          studyReferenceRecords: internal,
          createdAt: DateTime.now());
      expect(context.mayGenerate, isTrue, reason: query);
      final base = AiService.buildClinicalSystemPrompt(
          lang: lang,
          matchedProtocolSummaries: [],
          matchedDrugSummaries: [],
          userQuery: query,
          isFirstMessage: true,
          isPlantaoMode: false);
      final routed = AiSmartRouter.build(
          userMessage: query,
          systemPrompt: base,
          isPlantaoMode: false,
          appLanguage: lang);
      final prompt = prepareAiRequestPrompt(
              mode: AiRequestMode.estudo,
              systemPrompt:
                  '${routed.finalPrompt}${StudyResponseContract.forLanguage(lang)}')
          .systemPrompt;
      print('STUDY_PROMPT_METADATA=${jsonEncode({
            'chars': prompt.length,
            'educational_contract':
                prompt.contains(StudyResponseContract.contract),
            'broad_disease_coverage':
                prompt.contains('Para o nome isolado de uma doença')
          })}');
      final request =
          await client.postUrl(Uri.parse('http://127.0.0.1:$port/study'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'query': query,
        'prompt': StudyCanonicalResponse.prompt(prompt),
        'mode': 'estudo',
        'lang': lang,
        'maxOutputTokens': StudyCanonicalSchema.maxOutputTokens,
        'generationConfig': StudyCanonicalSchema.generationConfig,
        'canonical': true,
        'replay': Platform.environment['STUDY_QA_REPLAY'] == '1'
      }));
      final response = await request.close();
      final payload = jsonDecode(await utf8.decoder.bind(response).join())
          as Map<String, dynamic>;
      expect(response.statusCode, 200, reason: payload['error'] as String?);
      final providerRaw = (payload['wire'] as String)
          .split('\n')
          .where((l) => l.startsWith('data: {'))
          .map((l) => jsonDecode(l.substring(6)))
          .expand((e) => (e['candidates'] as List? ?? []))
          .expand((c) => (c['content']?['parts'] as List? ?? []))
          .where((p) => p['thought'] != true && p['text'] is String)
          .map((p) => p['text'] as String)
          .join();
      print('STUDY_RAW_ENCODING=${jsonEncode({
            'query': query,
            'rawChars': providerRaw.length,
            'startsObject': providerRaw.trimLeft().startsWith('{'),
            'startsArray': providerRaw.trimLeft().startsWith('['),
            'startsFence': providerRaw.trimLeft().startsWith('```'),
            'factMarkers':
                RegExp(r'"type"\s*:\s*"fact"').allMatches(providerRaw).length
          })}');
      final chunks = await GeminiServiceV2.decodeResponseForTesting(
              Stream.value(utf8.encode(payload['wire'] as String)))
          .toList();
      for (final chunk in chunks) {
        context.studyReferences.addGrounding(chunk.groundedSources);
      }
      final diagnostic = StudyCanonicalDecoder(lang);
      diagnostic.add(chunks.map((c) => c.text).join());
      diagnostic.finish();
      print('STUDY_WIRE_SHAPE=${jsonEncode(diagnostic.diagnostics)}');
      final localized = await StudyCanonicalResponse.localize(
              Stream.fromIterable(chunks),
              language: lang,
              references: context.studyReferences)
          .toList();
      final canonical = localized.last.studySnapshot;
      print('STUDY_CANONICAL_BINDING=${jsonEncode({
            'query': query,
            'issues': localized.last.studyCanonicalIssues,
            'providerChars': chunks.map((c) => c.text).join().length,
            'localizedChars': localized.map((c) => c.text).join().length
          })}');
      expect(canonical, isNotNull, reason: '$query canonical integration');
      final ptAudit = canonical!.audit('pt');
      final esAudit = canonical.audit('es');
      expect(ptAudit, esAudit, reason: '$query identical canonical identities');
      expect(ptAudit['droppedFacts'], 0);
      final pt = canonical.blocks('pt', includeContinuation: true).join();
      final es = canonical.blocks('es', includeContinuation: true).join();
      for (final language in ['pt', 'es']) {
        final view = language == 'pt' ? pt : es;
        final continuation = StudyContinuationResolver.resolve(
            rawText: view,
            isStudyMode: true,
            isSafeCard: false,
            isStreaming: false,
            lastUserMessage: query,
            languageCode: language);
        final id = ptAudit['ctaId'] as String;
        final pair = StudyCanonicalContinuation.choices[id]!;
        expect(continuation.label, pair[language == 'es' ? 1 : 0]);
        expect(continuation.question, pair[language == 'es' ? 3 : 2]);
        expect(continuation.displayText,
            isNot(contains(StudyCanonicalContinuation.prefix)));
      }
      final raw = localized.map((c) => c.text).join();
      expect(context.studyReferences.present(es).trim(), raw.trim());
      final ptContext = ClinicalRequestContext(
          requestId: 'synthetic-pt',
          sessionId: 'synthetic-qa',
          uid: 'authorized-qa',
          mode: AiRequestMode.estudo,
          language: 'pt',
          userQuery: query,
          memory: context.memory,
          evidence: ClinicalEvidenceBundle(),
          studyReferenceRecords: context.studyReferences.records,
          createdAt: DateTime.now());
      final ptUi = StudyResponseContract.normalizePresentation(
          ClinicalSafetyFlow(ptContext).present(await finalizeStudyFixture(
              ClinicalSafetyFlow(ptContext).present(pt), 'pt')));
      print('STUDY_CANONICAL_PARITY=${jsonEncode({
            'query': query,
            ...ptAudit,
            'ptChars': pt.length,
            'esChars': es.length,
            'ptUiChars': ptUi.length,
            'generationCount': 1
          })}');

      String fingerprint(String value) =>
          sha256.convert(utf8.encode(value)).toString();
      Set<String> doseHashes(String text) => RegExp(
              r'(?<![\d.,])\d+(?:[.,]\d+)?(?:\s*[–-]\s*\d+(?:[.,]\d+)?)?\s*(?:mg|mcg|µg|g|mL|UI|mEq|mmol)\b(?:/(?:kg|h|min|d|L))?',
              caseSensitive: false)
          .allMatches(text.replaceAll('**', ''))
          .map((m) => fingerprint(m[0]!
              .toLowerCase()
              .replaceAll(',', '.')
              .replaceAll(RegExp(r'\s+'), '')
              .replaceAll('–', '-')))
          .toSet();
      final removals = <Map<String, Object>>[];
      final flow =
          ClinicalSafetyFlow(context, onStudyRemoval: (reason, fragment) {
        removals.add({
          'reason': reason,
          'chars': fragment.length,
          'sha256': fingerprint(fragment),
          'dose_hashes': doseHashes(fragment).toList(),
          'invalid_value_word_substring':
              RegExp(r'NaN|Infinity|fict[ií]ci|inventad', caseSensitive: false)
                  .hasMatch(fragment),
          'invalid_value_standalone_literal':
              RegExp(r'\b(?:NaN|Infinity)\b', caseSensitive: false)
                  .hasMatch(fragment),
          'nan_inside_recombinant_word':
              RegExp(r'recombinante', caseSensitive: false).hasMatch(fragment),
          'zero_or_negative_numeric_values': RegExp(
                  r'(?<![\d.,])(-?\d+(?:[.,]\d+)?)\s*(?:mg|mcg|g|ml|ui)\b',
                  caseSensitive: false)
              .allMatches(fragment)
              .where((m) => num.parse(m[1]!.replaceAll(',', '.')) <= 0)
              .length,
          'has_named_fluid': RegExp(r'cristaloid|cristal[oó]ide|salin|ringer',
                  caseSensitive: false)
              .hasMatch(fragment)
        });
      });
      final projected = StudyResponseContract.project(raw);
      final safe = flow.present(projected.clinicalAnswer);
      // Incomplete provider output must be reported, never passed as complete.
      final finish = chunks.lastWhere((c) => c.isDone).finishReason;
      final callback =
          finish == 'STOP' ? await finalizeStudyFixture(safe, lang) : safe;
      final ui =
          StudyResponseContract.normalizePresentation(flow.present(callback));
      bool has(String expression, String value) =>
          RegExp(expression, caseSensitive: false).hasMatch(value);
      final record = <String, dynamic>{
        'query': query,
        'provider': payload['provider'],
        'finish': finish,
        'provider_chars': raw.length,
        'post_safety_chars': safe.length,
        'callback_chars': callback.length,
        'ui_chars': ui.length,
        'retention': callback.isEmpty ? 0 : ui.length / callback.length,
        'answer_present': ui.length > 200,
        'generic_refusal': AiFailureMessage.recognize(ui) != null ||
            ui == flow.studyNoSafeContentMessage,
        'internal_debug_text':
            StudyResponseContract.project(ui).hadInternalText,
        'verified_reference_count': context.studyReferences.records.length,
        'definition': has(r'definici|concepto|\bes (?:un|una)', ui),
        'pathophysiology':
            has(r'fisiopatolog|fisiopatol[oó]g|mecanismo|patog[eé]nesis', ui),
        'raw_pathophysiology':
            has(r'fisiopatolog|fisiopatol[oó]g|mecanismo|patog[eé]nesis', raw),
        'canonical_snapshot_received': true,
        'diagnosis': has(r'diagn[oó]st|criterios', ui),
        'causes': has(r'etiolog|causas', ui),
        'treatment': has(r'tratamiento|manejo', ui),
        'monitoring': has(r'monitor|seguimiento|vigilancia', ui),
        'raw_standard_dose': has(r'\d+(?:[.,]\d+)?\s*(?:mg|mcg|UI|mL)\b', raw),
        'ui_standard_dose': has(r'\d+(?:[.,]\d+)?\s*(?:mg|mcg|UI|mL)\b', ui),
      };
      final missing =
          doseHashes(context.studyReferences.present(projected.clinicalAnswer))
              .difference(doseHashes(ui));
      record['removed_fragments'] = removals;
      record['missing_dose_hashes'] = missing.toList();
      record['all_numeric_doses_preserved'] = missing.isEmpty;
      print('STUDY_REAL_METADATA=${jsonEncode(record)}');
      expect(doseHashes(pt).difference(doseHashes(ptUi)), isEmpty,
          reason: '$query PT numeric retention');
      expect(missing, isEmpty, reason: '$query numeric dose retention');
      expect(record['answer_present'], true, reason: query);
      expect(record['generic_refusal'], false, reason: query);
      expect(record['internal_debug_text'], false, reason: query);
      expect(record['retention'] as num, greaterThanOrEqualTo(.9),
          reason: query);
      expect(finish, 'STOP', reason: query);
      if (record['raw_standard_dose'] == true)
        expect(record['ui_standard_dose'], true, reason: query);
      if (query == 'Cetoacidosis' || query == 'Síndrome nefrótico') {
        for (final key in [
          'definition',
          'pathophysiology',
          'diagnosis',
          'treatment',
          if (query == 'Cetoacidosis') 'monitoring',
          if (query == 'Síndrome nefrótico') 'causes'
        ]) {
          expect(record[key], true, reason: '$query $key');
        }
      }
    }
  },
      skip: !Platform.environment.containsKey('STUDY_QA_BRIDGE_PORT'),
      timeout: const Timeout(Duration(minutes: 30)));
}
