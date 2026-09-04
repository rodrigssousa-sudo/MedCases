import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/plantao_machine_native_context_prefetch.dart';

class _DiagnosticFake
    implements
        PlantaoMachineNativeRegistrySource,
        PlantaoMachineNativeRegistryDiagnosticSource {
  _DiagnosticFake({
    required this.bulkIdentityStatus,
    this.directIdentityStatus = PlantaoMachineNativeRegistryReadStatus.ok,
    this.failCollection,
    this.failStatus = PlantaoMachineNativeRegistryReadStatus.permissionDenied,
    this.bulkIdentityRows = const <Map<String, dynamic>>[],
  });

  final PlantaoMachineNativeRegistryReadStatus bulkIdentityStatus;
  final PlantaoMachineNativeRegistryReadStatus directIdentityStatus;
  final String? failCollection;
  final PlantaoMachineNativeRegistryReadStatus failStatus;
  final List<Map<String, dynamic>> bulkIdentityRows;

  final Map<String, PlantaoMachineNativeRegistryReadDiagnostic> _diag =
      <String, PlantaoMachineNativeRegistryReadDiagnostic>{};

  static const identity = <String, dynamic>{
    'id': 'anafilaxia',
    'enabled': true,
    'canonicalKey': 'anafilaxia',
    'canonicalPathologyKey': 'anafilaxia',
    'aliases': <String>['anafilaxia', 'choque anafilactico'],
  };

  static const protocol = <String, dynamic>{
    'id': 'anafilaxia',
    'enabled': true,
    'canonicalPathologyKey': 'anafilaxia',
    'protocolKey': 'legacy_protocol::anafilaxia',
    'guidelineVersion': 'TEST_CURRENT',
    'priority': 100,
  };

  static const management = <String, dynamic>{
    'id': 'anafilaxia',
    'enabled': true,
    'canonicalPathologyKey': 'anafilaxia',
    'protocolKey': 'legacy_protocol::anafilaxia',
    'guidelineVersion': 'TEST_CURRENT',
    'clinicalReviewDate': '2026-09-01',
    'managementReady': true,
    'provenancePolicy': 'AUTHORITATIVE_CURRENT_OR_FAIL_CLOSED',
    'resolutionPolicy': 'authoritative_current_machine_management',
    'initialActions': <Map<String, String>>[
      <String, String>{
        'key': 'epinephrine_im',
        'pt': 'Adrenalina IM imediatamente.',
        'es': 'Adrenalina IM inmediatamente.',
      },
      <String, String>{
        'key': 'shock_fluid',
        'pt': 'Em choque, acesso IV e cristaloide isotônico rápido.',
        'es': 'En shock, acceso IV y cristaloide isotónico rápido.',
      },
    ],
    'conditionalActions': <Map<String, String>>[
      <String, String>{
        'key': 'repeat_epinephrine',
        'pt':
            'Repetir adrenalina IM em 5 minutos se persistirem problemas ABC.',
        'es':
            'Repetir adrenalina IM a los 5 minutos si persisten problemas ABC.',
      },
    ],
    'contraindicatedActions': <Map<String, String>>[
      <String, String>{
        'key': 'routine_steroid',
        'pt': 'Usar corticoide de rotina como tratamento da anafilaxia.',
        'es': 'Usar corticoide de rutina como tratamiento de la anafilaxia.',
      },
    ],
    'monitoring': <Map<String, String>>[
      <String, String>{
        'key': 'monitoring',
        'pt': 'Monitorizar ECG, PA e SpO2 continuamente.',
        'es': 'Monitorizar ECG, PA y SpO2 continuamente.',
      },
    ],
    'reassessment': <Map<String, String>>[
      <String, String>{
        'key': 'reassessment',
        'pt': 'Reavaliar ABC e resposta em 5 minutos.',
        'es': 'Reevaluar ABC y respuesta a los 5 minutos.',
      },
    ],
    'escalationCriteria': <Map<String, String>>[
      <String, String>{
        'key': 'escalation',
        'pt': 'Após 2 doses IM adequadas com persistência grave, escalar.',
        'es': 'Tras 2 dosis IM adecuadas con persistencia grave, escalar.',
      },
    ],
  };

  void _record(
    String collection,
    String operation,
    PlantaoMachineNativeRegistryReadStatus status,
    int rows,
  ) {
    _diag[collection] = PlantaoMachineNativeRegistryReadDiagnostic(
      collection: collection,
      operation: operation,
      status: status,
      rows: rows,
    );
  }

  @override
  PlantaoMachineNativeRegistryReadDiagnostic? diagnosticFor(
    String collection,
  ) => _diag[collection];

  @override
  Future<List<Map<String, dynamic>>> loadEnabled(String collection) async {
    if (collection != PlantaoMachineNativeContextPrefetch.identities) {
      _record(
        collection,
        'loadEnabled',
        PlantaoMachineNativeRegistryReadStatus.ok,
        0,
      );
      return const <Map<String, dynamic>>[];
    }
    final rows = bulkIdentityStatus == PlantaoMachineNativeRegistryReadStatus.ok
        ? bulkIdentityRows
        : const <Map<String, dynamic>>[];
    _record(collection, 'loadEnabled', bulkIdentityStatus, rows.length);
    return rows;
  }

  @override
  Future<List<Map<String, dynamic>>> loadPathology(
    String collection,
    String canonicalKey, {
    String fieldPath = 'canonicalPathologyKey',
  }) async {
    if (collection == PlantaoMachineNativeContextPrefetch.identities) {
      final rows =
          directIdentityStatus == PlantaoMachineNativeRegistryReadStatus.ok &&
              canonicalKey == 'anafilaxia'
          ? <Map<String, dynamic>>[identity]
          : const <Map<String, dynamic>>[];
      _record(
        collection,
        'loadPathology:$fieldPath',
        directIdentityStatus,
        rows.length,
      );
      return rows;
    }

    if (collection == failCollection) {
      _record(collection, 'loadPathology:$fieldPath', failStatus, 0);
      return const <Map<String, dynamic>>[];
    }

    late final List<Map<String, dynamic>> rows;
    if (collection == PlantaoMachineNativeContextPrefetch.protocols) {
      rows = <Map<String, dynamic>>[protocol];
    } else if (collection == PlantaoMachineNativeContextPrefetch.management) {
      rows = <Map<String, dynamic>>[management];
    } else {
      rows = const <Map<String, dynamic>>[];
    }
    _record(
      collection,
      'loadPathology:$fieldPath',
      PlantaoMachineNativeRegistryReadStatus.ok,
      rows.length,
    );
    return rows;
  }
}

void main() {
  const physicalCase =
      'Mujer de 34 años, minutos después de ingerir maní desarrolla urticaria '
      'generalizada, edema labial, disnea con sibilancias, mareo y PA 82/48 '
      'mmHg. FC 124 lpm, SpO2 91%. Está consciente pero muy sintomática. '
      '¿Cuál es el diagnóstico y cuál es la conducta inmediata en orden de '
      'prioridad? Incluye tratamiento de primera línea, monitorización, '
      'reevaluación y criterios de escalamiento.';

  group('M59 physical machine-native registry read-plane', () {
    test(
      'bulk identity timeout can recover through canonical phenotype point read',
      () async {
        final source = _DiagnosticFake(
          bulkIdentityStatus: PlantaoMachineNativeRegistryReadStatus.timeout,
        );
        final prefetch = PlantaoMachineNativeContextPrefetch(
          source: source,
          cacheTtl: Duration.zero,
        );

        final result = await prefetch.prefetch(
          userText: physicalCase,
          language: 'es',
        );

        expect(result.authoritative, isTrue);
        expect(result.canonicalPathologyKey, 'anafilaxia');
        expect(
          result.reason,
          'authoritative_pack_ready_via_phenotype_read_fallback',
        );
        expect(result.registryReadFailed, isFalse);
      },
    );

    test(
      'bulk and canonical identity permission denial is explicit and fail closed',
      () async {
        final source = _DiagnosticFake(
          bulkIdentityStatus:
              PlantaoMachineNativeRegistryReadStatus.permissionDenied,
          directIdentityStatus:
              PlantaoMachineNativeRegistryReadStatus.permissionDenied,
        );
        final prefetch = PlantaoMachineNativeContextPrefetch(
          source: source,
          cacheTtl: Duration.zero,
        );

        final result = await prefetch.prefetch(
          userText: physicalCase,
          language: 'es',
        );

        expect(result.authoritative, isFalse);
        expect(result.registryReadFailed, isTrue);
        expect(result.canonicalPathologyKey, 'anafilaxia');
        expect(
          result.reason,
          'registry_read_failed:permission_denied:clinical_identity_registry',
        );
      },
    );

    test(
      'successful but empty bulk identity read recovers through canonical point read',
      () async {
        final source = _DiagnosticFake(
          bulkIdentityStatus: PlantaoMachineNativeRegistryReadStatus.ok,
        );
        final prefetch = PlantaoMachineNativeContextPrefetch(
          source: source,
          cacheTtl: Duration.zero,
        );

        final result = await prefetch.prefetch(
          userText: physicalCase,
          language: 'es',
        );

        expect(result.authoritative, isTrue);
        expect(result.registryReadFailed, isFalse);
        expect(
          result.reason,
          'authoritative_pack_ready_via_phenotype_read_fallback',
        );
        expect(result.canonicalPathologyKey, 'anafilaxia');
      },
    );

    test(
      'downstream management permission denial identifies exact collection',
      () async {
        final source = _DiagnosticFake(
          bulkIdentityStatus: PlantaoMachineNativeRegistryReadStatus.ok,
          bulkIdentityRows: const <Map<String, dynamic>>[
            _DiagnosticFake.identity,
          ],
          failCollection: PlantaoMachineNativeContextPrefetch.management,
          failStatus: PlantaoMachineNativeRegistryReadStatus.permissionDenied,
        );
        final prefetch = PlantaoMachineNativeContextPrefetch(
          source: source,
          cacheTtl: Duration.zero,
        );

        final result = await prefetch.prefetch(
          userText: physicalCase,
          language: 'es',
        );

        expect(result.authoritative, isFalse);
        expect(result.registryReadFailed, isTrue);
        expect(result.canonicalPathologyKey, 'anafilaxia');
        expect(
          result.reason,
          'registry_read_failed:permission_denied:clinical_management_rules',
        );
      },
    );

    test(
      'source observability contains safe metadata and typed error classes',
      () {
        final source = File(
          'lib/services/plantao_machine_native_context_prefetch.dart',
        ).readAsStringSync();

        expect(source, contains('M59_REGISTRY_READ_DIAGNOSTICS_V1'));
        expect(source, contains('[M59_REGISTRY_READ]'));
        expect(source, contains('on TimeoutException'));
        expect(source, contains('on FirebaseException catch (error)'));
        expect(
          source,
          contains('source as PlantaoMachineNativeRegistryDiagnosticSource'),
        );
        expect(source, contains("'permission-denied'"));
        expect(source, contains("'unauthenticated'"));
        expect(source, contains("'unavailable'"));
        expect(source, contains("'failed-precondition'"));

        final recordStart = source.indexOf('void _recordRead({');
        final recordEnd = source.indexOf(
          '\n  @override\n  Future<List<Map<String, dynamic>>> loadEnabled',
          recordStart,
        );
        expect(recordStart, isNonNegative);
        expect(recordEnd, greaterThan(recordStart));
        final recordReadBody = source.substring(recordStart, recordEnd);

        for (final forbidden in <String>[
          'userText',
          'canonicalKey}',
          'd.data()',
          'providerInput',
          'finalText',
          'rawText',
          'snap.docs',
        ]) {
          expect(recordReadBody, isNot(contains(forbidden)), reason: forbidden);
        }
        expect(recordReadBody, contains("'[M59_REGISTRY_READ] '"));
        expect(recordReadBody, contains(r"'operation=$operation '"));
        expect(recordReadBody, contains(r"'collection=$collection '"));
        expect(recordReadBody, contains(r"'status=${status.token} '"));
        expect(recordReadBody, contains(r"'rows=$rows '"));

        // M59_R4_TEST_LITERAL_ESCAPE_GUARD
        expect(recordReadBody, isNotEmpty);

        expect(source, isNot(contains('.collection(collection).add(')));
        expect(source, isNot(contains('WriteBatch')));
        expect(source, isNot(contains('runTransaction(')));
      },
    );

    test(
      'recognized registry failure blocks before the one productive provider call',
      () {
        final screen = File('lib/screens/ai_screen.dart').readAsStringSync();
        final prefetch = screen.indexOf(
          'M56C_MACHINE_NATIVE_REGISTRY_PREFETCH',
        );
        final guard = screen.indexOf(
          'M59_MACHINE_NATIVE_REGISTRY_FAIL_CLOSED_BEFORE_PROVIDER',
          prefetch,
        );
        final send = screen.indexOf('await p.sendAiMessage(', prefetch);

        expect(prefetch, isNonNegative);
        expect(guard, greaterThan(prefetch));
        expect(send, greaterThan(guard));

        final block = screen.substring(guard, send);
        expect(block, contains('m56cMachineContext.registryReadFailed'));
        expect(
          block,
          contains('m56cMachineContext.canonicalPathologyKey != null'),
        );
        expect(block, contains('[M59_REGISTRY_FAIL_CLOSED]'));
        expect(block, contains("_messages.add(_ChatMsg(role: 'ai'"));
        expect(block, contains('return;'));
      },
    );

    test('Study remains outside machine-native fail-closed branch', () {
      final screen = File('lib/screens/ai_screen.dart').readAsStringSync();
      final guard = screen.indexOf(
        'M59_MACHINE_NATIVE_REGISTRY_FAIL_CLOSED_BEFORE_PROVIDER',
      );
      final send = screen.indexOf('await p.sendAiMessage(', guard);
      final block = screen.substring(guard, send);
      expect(block, contains('if (!_longResponse &&'));
    });
  });
}
