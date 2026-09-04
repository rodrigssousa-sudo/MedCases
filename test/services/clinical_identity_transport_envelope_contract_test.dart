import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/clinical_identity_transport_envelope.dart';

void main() {
  group('ClinicalIdentityTransportEnvelope', () {
    const realAlias = "agitacao_psicomotora";

    test('extracts exactly one structured active protocol alias', () {
      final payload =
          ClinicalIdentityTransportEnvelope.fromStructuredSystemPrompt(
        'CABECALHO\nPROTOCOLO_CLINICO_ATIVO: $realAlias\nRODAPE',
      );

      expect(payload['clinicalIdentityAlias'], realAlias);
      expect(payload.length, 1);
    });

    test('Spanish ACTIVO tag is supported', () {
      final payload =
          ClinicalIdentityTransportEnvelope.fromStructuredSystemPrompt(
        'PROTOCOLO_CLINICO_ACTIVO: $realAlias',
      );

      expect(payload['clinicalIdentityAlias'], realAlias);
    });

    test('free text never becomes identity', () {
      final payload =
          ClinicalIdentityTransportEnvelope.fromStructuredSystemPrompt(
        'Paciente con $realAlias y dolor toracico.',
      );

      expect(payload, isEmpty);
    });

    test('multiple different protocol markers fail closed', () {
      final payload =
          ClinicalIdentityTransportEnvelope.fromStructuredSystemPrompt(
        'PROTOCOLO_CLINICO_ATIVO: $realAlias\n'
        'PROTOCOLO_CLINICO_ATIVO: outro_protocolo',
      );

      expect(payload, isEmpty);
    });

    test('duplicate same marker remains unambiguous', () {
      final payload =
          ClinicalIdentityTransportEnvelope.fromStructuredSystemPrompt(
        'PROTOCOLO_CLINICO_ATIVO: $realAlias\n'
        'PROTOCOLO_CLINICO_ATIVO: $realAlias',
      );

      expect(payload['clinicalIdentityAlias'], realAlias);
    });
  });
}
