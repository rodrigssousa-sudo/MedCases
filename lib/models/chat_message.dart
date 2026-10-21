import 'canonical_clinical_snapshot.dart';
import 'clinical_structured_output.dart';

/// Mensagem canônica da interface de chat.
///
/// Mantém identidade estável durante streaming, edição, restauração de sessão
/// e associação fail-closed do Structured Clinical Output.
class ChatMessage {
  final String id;
  final DateTime? createdAt;
  final String role;
  final String text;
  final bool preserveReferenceText;
  final CanonicalClinicalSnapshot? referenceDocument;

  /// Display-only provenance for deterministic action-button user messages.
  /// [text] remains canonical for provider/history/routing/editing.
  final String? userDisplayText;

  /// Metadado clínico estruturado associado ao texto definitivo da mensagem.
  ///
  /// Permanece volátil até que a persistência estruturada seja formalmente
  /// versionada e habilitada.
  final ClinicalStructuredOutput? clinicalOutput;

  ChatMessage({
    required this.role,
    required this.text,
    DateTime? createdAt,
    this.preserveReferenceText = false,
    this.referenceDocument,
    this.userDisplayText,
    this.clinicalOutput,
  })  : createdAt = createdAt ?? DateTime.now(),
        id = '${role}_${DateTime.now().microsecondsSinceEpoch}';

  ChatMessage.withId({
    required this.id,
    this.createdAt,
    required this.role,
    required this.text,
    this.preserveReferenceText = false,
    this.referenceDocument,
    this.userDisplayText,
    this.clinicalOutput,
  });

  static DateTime? parseTimestamp(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is num && value > 0 && value < 253402300800000) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
    }
    return null;
  }

  static DateTime? timeFromLegacyId(String? id) {
    final match =
        RegExp(r'^(?:ai|assistant|user|model)_(\d{16})$').firstMatch(id ?? '');
    final micros = int.tryParse(match?.group(1) ?? '');
    return micros == null
        ? null
        : DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true);
  }

  bool get isUser => role == 'user';

  bool get isAssistant =>
      role == 'ai' || role == 'assistant' || role == 'model';

  ChatMessage copyWith({
    String? id,
    String? role,
    String? text,
    bool? preserveReferenceText,
    String? userDisplayText,
    bool clearUserDisplayText = false,
    ClinicalStructuredOutput? clinicalOutput,
    bool clearClinicalOutput = false,
  }) {
    return ChatMessage.withId(
      id: id ?? this.id,
      createdAt: createdAt,
      role: role ?? this.role,
      text: text ?? this.text,
      preserveReferenceText:
          preserveReferenceText ?? this.preserveReferenceText,
      referenceDocument:
          text == null || text == this.text ? referenceDocument : null,
      userDisplayText:
          clearUserDisplayText ? null : userDisplayText ?? this.userDisplayText,
      clinicalOutput:
          clearClinicalOutput ? null : clinicalOutput ?? this.clinicalOutput,
    );
  }
}
