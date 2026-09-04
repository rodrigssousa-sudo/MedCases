import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/plantao_machine_native_context_prefetch.dart';

class _PermissionDeniedPrimary
    implements
        PlantaoMachineNativeRegistrySource,
        PlantaoMachineNativeRegistryDiagnosticSource {
  final Map<String, PlantaoMachineNativeRegistryReadDiagnostic> _diagnostics =
      <String, PlantaoMachineNativeRegistryReadDiagnostic>{};

  void _deny(String collection, String operation) {
    _diagnostics[collection] = PlantaoMachineNativeRegistryReadDiagnostic(
      collection: collection,
      operation: operation,
      status: PlantaoMachineNativeRegistryReadStatus.permissionDenied,
      rows: 0,
      firestoreCode: 'permission-denied',
    );
  }

  @override
  PlantaoMachineNativeRegistryReadDiagnostic? diagnosticFor(
    String collection,
  ) => _diagnostics[collection];

  @override
  Future<List<Map<String, dynamic>>> loadEnabled(String collection) async {
    _deny(collection, 'loadEnabled');
    return const <Map<String, dynamic>>[];
  }

  @override
  Future<List<Map<String, dynamic>>> loadPathology(
    String collection,
    String canonicalKey, {
    String fieldPath = 'canonicalPathologyKey',
  }) async {
    _deny(collection, 'loadPathology:$fieldPath');
    return const <Map<String, dynamic>>[];
  }
}

class _AlwaysFailFallback
    implements
        PlantaoMachineNativeRegistrySource,
        PlantaoMachineNativeRegistryDiagnosticSource {
  final Map<String, PlantaoMachineNativeRegistryReadDiagnostic> _diagnostics =
      <String, PlantaoMachineNativeRegistryReadDiagnostic>{};

  void _fail(String collection, String operation) {
    _diagnostics[collection] = PlantaoMachineNativeRegistryReadDiagnostic(
      collection: collection,
      operation: operation,
      status: PlantaoMachineNativeRegistryReadStatus.otherError,
      rows: 0,
    );
  }

  @override
  PlantaoMachineNativeRegistryReadDiagnostic? diagnosticFor(
    String collection,
  ) => _diagnostics[collection];

  @override
  Future<List<Map<String, dynamic>>> loadEnabled(String collection) async {
    _fail(collection, 'loadEnabled');
    return const <Map<String, dynamic>>[];
  }

  @override
  Future<List<Map<String, dynamic>>> loadPathology(
    String collection,
    String canonicalKey, {
    String fieldPath = 'canonicalPathologyKey',
  }) async {
    _fail(collection, 'loadPathology:$fieldPath');
    return const <Map<String, dynamic>>[];
  }
}

const physicalCase = '''
Mujer de 34 años, minutos después de ingerir maní desarrolla urticaria generalizada, edema labial, disnea con sibilancias, mareo y PA 82/48 mmHg. FC 124 lpm, SpO2 91%. Está consciente pero muy sintomática.

¿Cuál es el diagnóstico y cuál es la conducta inmediata en orden de prioridad? Incluye tratamiento de primera línea, monitorización, reevaluación y criterios de escalamiento.
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('M60 exact frozen Phase24 bundled authority failover', () {
    test(
      'bundled runtime loadEnabled exposes exact Phase24 enabled registry counts',
      () async {
        final source = PlantaoBundledPhase24MachineNativeRegistrySource();

        final identities = await source.loadEnabled(
          PlantaoMachineNativeContextPrefetch.identities,
        );
        final protocols = await source.loadEnabled(
          PlantaoMachineNativeContextPrefetch.protocols,
        );
        final classifications = await source.loadEnabled(
          PlantaoMachineNativeContextPrefetch.classifications,
        );
        final management = await source.loadEnabled(
          PlantaoMachineNativeContextPrefetch.management,
        );
        final actions = await source.loadEnabled(
          PlantaoMachineNativeContextPrefetch.actions,
        );
        final content = await source.loadEnabled(
          PlantaoMachineNativeContextPrefetch.content,
        );

        // Phase24 stores 94 classification documents in the frozen snapshot,
        // but only 40 are enabled for runtime resolution. The bundled source
        // intentionally mirrors Firestore loadEnabled semantics.
        expect(identities, hasLength(270));
        expect(protocols, hasLength(270));
        expect(classifications, hasLength(40));
        expect(management, hasLength(270));
        expect(actions, hasLength(364));
        expect(content, hasLength(364));
        expect(
          identities.length +
              protocols.length +
              classifications.length +
              management.length +
              actions.length +
              content.length,
          1578,
        );
      },
    );

    test(
      'frozen bundled asset still contains all 1632 raw Phase24 documents',
      () {
        final decoded =
            jsonDecode(
                  File(
                    'assets/clinical/clinical_registry_phase24_authoritative270.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;

        expect(decoded['identities'], hasLength(270));
        expect(decoded['protocols'], hasLength(270));
        expect(decoded['classifications'], hasLength(94));
        expect(decoded['managementRules'], hasLength(270));
        expect(decoded['actions'], hasLength(364));
        expect(decoded['content'], hasLength(364));
        expect(
          (decoded['identities'] as List).length +
              (decoded['protocols'] as List).length +
              (decoded['classifications'] as List).length +
              (decoded['managementRules'] as List).length +
              (decoded['actions'] as List).length +
              (decoded['content'] as List).length,
          1632,
        );
      },
    );

    test(
      'physical permission denial recovers to authoritative anaphylaxis pack',
      () async {
        final source = PlantaoFailoverMachineNativeRegistrySource(
          primary: _PermissionDeniedPrimary(),
          fallback: PlantaoBundledPhase24MachineNativeRegistrySource(),
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
        expect(result.canonicalPathologyKey, 'anafilaxia');
        expect(result.contextPack, isNotNull);
        expect(result.contextPack!.requiredActions, isNotEmpty);
        expect(result.providerPromptBlock, contains('requiredActions='));
        expect(result.providerPromptBlock, contains('monitoring='));
        expect(result.providerPromptBlock, contains('reassessment='));
        expect(result.providerPromptBlock, contains('escalationCriteria='));
      },
    );

    test(
      'identity canonical point lookup succeeds from bundled source',
      () async {
        final source = PlantaoBundledPhase24MachineNativeRegistrySource();
        final rows = await source.loadPathology(
          PlantaoMachineNativeContextPrefetch.identities,
          'anafilaxia',
          fieldPath: 'canonicalKey',
        );

        expect(rows, hasLength(1));
        expect(rows.single['canonicalKey'], 'anafilaxia');
      },
    );

    test('if both sources fail M59 fail-closed semantics remain', () async {
      final source = PlantaoFailoverMachineNativeRegistrySource(
        primary: _PermissionDeniedPrimary(),
        fallback: _AlwaysFailFallback(),
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
        'registry_read_failed:other_error:clinical_identity_registry',
      );
    });

    test(
      'default source is failover and M59 fail-closed code is preserved',
      () {
        final prefetchSource = File(
          'lib/services/plantao_machine_native_context_prefetch.dart',
        ).readAsStringSync();
        final screen = File('lib/screens/ai_screen.dart').readAsStringSync();

        expect(
          prefetchSource,
          contains(
            '_source = source ?? PlantaoFailoverMachineNativeRegistrySource();',
          ),
        );
        expect(prefetchSource, contains('M59_REGISTRY_READ_DIAGNOSTICS_V1'));
        expect(
          screen,
          contains('M59_MACHINE_NATIVE_REGISTRY_FAIL_CLOSED_BEFORE_PROVIDER'),
        );
      },
    );

    test('failover observability excludes patient and provider text', () {
      final source = File(
        'lib/services/plantao_machine_native_context_prefetch.dart',
      ).readAsStringSync();
      final start = source.indexOf('void _logFailover({');
      final end = source.indexOf(
        '\n  @override\n  Future<List<Map<String, dynamic>>> loadEnabled',
        start,
      );
      expect(start, isNonNegative);
      expect(end, greaterThan(start));
      final body = source.substring(start, end);
      for (final forbidden in <String>[
        'userText',
        'providerInput',
        'rawText',
        'finalText',
        'd.data()',
        'canonicalKey',
      ]) {
        expect(body, isNot(contains(forbidden)), reason: forbidden);
      }
      expect(body, contains('[M60_REGISTRY_FAILOVER]'));
      expect(body, contains('primary_status='));
      expect(body, contains('fallback_status='));
    });
  });
}
