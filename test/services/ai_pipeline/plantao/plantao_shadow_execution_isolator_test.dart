import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_shadow_execution_isolator.dart';

void main() {
  test('launch returns before delayed shadow work completes', () async {
    const isolator = PlantaoShadowExecutionIsolator();
    final completed = Completer<void>();
    final stopwatch = Stopwatch()..start();

    isolator.launch(() async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      completed.complete();
    });

    stopwatch.stop();

    expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 30)));
    expect(completed.isCompleted, isFalse);

    await completed.future.timeout(const Duration(seconds: 1));
  });

  test('asynchronous failure is contained and reported once', () async {
    const isolator = PlantaoShadowExecutionIsolator();
    final failure = Completer<Object>();
    final zoneErrors = <Object>[];

    await runZonedGuarded(() async {
      isolator.launch(
        () async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          throw StateError('remote unavailable');
        },
        onFailure: (error, stackTrace) {
          if (!failure.isCompleted) {
            failure.complete(error);
          }
        },
      );

      final error = await failure.future.timeout(const Duration(seconds: 1));
      expect(error, isA<StateError>());
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }, (error, stackTrace) {
      zoneErrors.add(error);
    });

    expect(zoneErrors, isEmpty);
  });

  test('synchronous failure is contained and reported', () async {
    const isolator = PlantaoShadowExecutionIsolator();
    final failure = Completer<Object>();

    isolator.launch(
      () {
        throw ArgumentError('invalid shadow contract');
      },
      onFailure: (error, stackTrace) {
        failure.complete(error);
      },
    );

    expect(
      await failure.future.timeout(const Duration(seconds: 1)),
      isA<ArgumentError>(),
    );
  });

  test('failure handler exception cannot affect launch caller', () async {
    const isolator = PlantaoShadowExecutionIsolator();
    final zoneErrors = <Object>[];

    await runZonedGuarded(() async {
      isolator.launch(
        () async {
          throw StateError('shadow failure');
        },
        onFailure: (error, stackTrace) {
          throw StateError('observer failure');
        },
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));
    }, (error, stackTrace) {
      zoneErrors.add(error);
    });

    expect(zoneErrors, hasLength(1));
    expect(zoneErrors.single.toString(), contains('observer failure'));
  });

  test('constants declare strict non-productive contract', () {
    expect(PlantaoShadowExecutionIsolator.shadowOnly, isTrue);
    expect(
      PlantaoShadowExecutionIsolator.productiveAwaitEnabled,
      isFalse,
    );
    expect(
      PlantaoShadowExecutionIsolator.productiveMutationEnabled,
      isFalse,
    );
    expect(PlantaoShadowExecutionIsolator.persistenceEnabled, isFalse);
  });
}
