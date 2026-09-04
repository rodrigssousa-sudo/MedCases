import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';

void main() {
  group('GuardiaStreamingPresentation', () {
    test('preserves ordinary progressive streaming', () {
      const raw =
          '🟥 DOR TORÁCICA\n'
          '🚨 Conduta imediata:\n'
          '• Monitorizar\n';

      expect(
        GuardiaStreamingPresentation.stableBeforeHardStop(
          rawText: raw,
          isStreaming: true,
        ),
        raw,
      );
    });

    test('retains emoji hard-stop tail until final state', () {
      const raw =
          '🟥 DOR TORÁCICA\n'
          '🔑 Pontos-chave:\n'
          '• ECG imediato\n'
          '\n'
          '⛔ HARD STOP:\n'
          '• Choque cardiogênico\n'
          '\n'
          '📌 Reavaliar em 10 minutos\n';

      final streaming =
          GuardiaStreamingPresentation.stableBeforeHardStop(
        rawText: raw,
        isStreaming: true,
      );

      expect(streaming, contains('ECG imediato'));
      expect(streaming, isNot(contains('HARD STOP')));
      expect(streaming, isNot(contains('Choque cardiogênico')));
      expect(streaming, isNot(contains('Reavaliar em 10 minutos')));
    });

    test('retains plain hard-stop heading until final state', () {
      const raw =
          'Conduta imediata:\n'
          '• Monitorizar\n'
          'HARD STOP:\n'
          '• Não administrar nitrato se PAS < 90 mmHg\n';

      final streaming =
          GuardiaStreamingPresentation.stableBeforeHardStop(
        rawText: raw,
        isStreaming: true,
      );

      expect(streaming, contains('Monitorizar'));
      expect(streaming, isNot(contains('HARD STOP')));
      expect(streaming, isNot(contains('nitrato')));
    });

    test('hides the tail as soon as the terminal emoji arrives', () {
      const raw =
          'Conduta imediata:\n'
          '• Monitorizar\n'
          '⛔\n';

      final streaming =
          GuardiaStreamingPresentation.stableBeforeHardStop(
        rawText: raw,
        isStreaming: true,
      );

      expect(streaming, contains('Monitorizar'));
      expect(streaming, isNot(contains('⛔')));
    });

    test('retains red-circle hard-stop heading until final state', () {
      const raw =
          'Conduta imediata:\n'
          '• Monitorizar\n'
          '🔴 HARD STOP:\n'
          '• Acionar suporte avançado\n';

      final streaming =
          GuardiaStreamingPresentation.stableBeforeHardStop(
        rawText: raw,
        isStreaming: true,
      );

      expect(streaming, contains('Monitorizar'));
      expect(streaming, isNot(contains('HARD STOP')));
      expect(streaming, isNot(contains('suporte avançado')));
    });

    test('returns the complete response after finalization', () {
      const raw =
          'Conduta imediata:\n'
          '• Monitorizar\n'
          '⛔ HARD STOP:\n'
          '• Não administrar nitrato se PAS < 90 mmHg\n'
          '📌 Reavaliar\n';

      expect(
        GuardiaStreamingPresentation.stableBeforeHardStop(
          rawText: raw,
          isStreaming: false,
        ),
        raw,
      );
    });

    test('does not truncate an ordinary sentence mentioning hard stop', () {
      const raw =
          'Pontos-chave:\n'
          '• Registrar o hard stop clínico no prontuário.\n';

      expect(
        GuardiaStreamingPresentation.stableBeforeHardStop(
          rawText: raw,
          isStreaming: true,
        ),
        raw,
      );
    });
  });
}
