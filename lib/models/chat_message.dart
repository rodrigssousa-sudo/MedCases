import 'clinical_structured_output.dart';

/// Mensagem canônica da interface de chat.
///
/// Mantém identidade estável durante streaming, edição, restauração de sessão
/// e associação fail-closed do Structured Clinical Output.
class ChatMessage {
  final String id;
  final String role;
  final String text;

  /// Metadado clínico estruturado associado ao texto definitivo da mensagem.
  ///
  /// Permanece volátil até que a persistência estruturada seja formalmente
  /// versionada e habilitada.
  final ClinicalStructuredOutput? clinicalOutput;

  ChatMessage({
    required this.role,
    required this.text,
    this.clinicalOutput,
  }) : id = '${role}_${DateTime.now().microsecondsSinceEpoch}';

  ChatMessage.withId({
    required this.id,
    required this.role,
    required this.text,
    this.clinicalOutput,
  });

  bool get isUser => role == 'user';

  bool get isAssistant =>
      role == 'ai' || role == 'assistant' || role == 'model';

  ChatMessage copyWith({
    String? id,
    String? role,
    String? text,
    ClinicalStructuredOutput? clinicalOutput,
    bool clearClinicalOutput = false,
  }) {
    return ChatMessage.withId(
      id: id ?? this.id,
      role: role ?? this.role,
      text: text ?? this.text,
      clinicalOutput:
          clearClinicalOutput ? null : clinicalOutput ?? this.clinicalOutput,
    );
  }
}
