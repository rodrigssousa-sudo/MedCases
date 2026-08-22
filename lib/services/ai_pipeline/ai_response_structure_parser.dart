import '../../models/clinical_structured_output.dart';
import '../plantao_pipeline.dart';
import 'ai_request_contract.dart';

enum AiStructuredOutputStatus {
  absent,
  valid,
  invalid,
}

/// Resultado imutável da interpretação estrutural.
///
/// O texto não é reescrito nesta camada. O parser apenas produz representações
/// tipadas adicionais para consumidores posteriores.
class AiResponseStructureOutcome {
  final String text;
  final AiRequestMode mode;

  final PlantaoResponse? plantaoResponse;

  final ClinicalStructuredOutput? clinicalOutput;
  final AiStructuredOutputStatus structuredOutputStatus;
  final String? structuredOutputErrorCode;

  const AiResponseStructureOutcome({
    required this.text,
    required this.mode,
    required this.plantaoResponse,
    required this.clinicalOutput,
    required this.structuredOutputStatus,
    this.structuredOutputErrorCode,
  });

  bool get hasPlantaoResponse => plantaoResponse != null;

  bool get hasClinicalOutput => clinicalOutput != null;

  bool get hasInvalidStructuredOutput =>
      structuredOutputStatus == AiStructuredOutputStatus.invalid;
}

/// Fronteira reutilizável do parser de âncoras do modo Plantão.
abstract class AiPlantaoParserPort {
  PlantaoResponse? parse(String text);
}

/// Adaptador para o [PlantaoParser] já existente.
///
/// Nenhuma âncora, validação ou regra clínica é reproduzida nesta camada.
class ExistingPlantaoParserPort implements AiPlantaoParserPort {
  const ExistingPlantaoParserPort();

  @override
  PlantaoResponse? parse(String text) {
    return PlantaoParser.parse(text);
  }
}

/// Proprietário canônico da interpretação estrutural da resposta.
///
/// Responsabilidades:
/// - delegar o texto do modo Plantão ao parser existente;
/// - preservar [ClinicalStructuredOutput] já tipado;
/// - converter mapas válidos usando o modelo canônico;
/// - sinalizar payload estruturado não nulo e inválido.
///
/// Fora do escopo:
/// - remover code fences;
/// - converter JSON textual para âncoras;
/// - modificar Markdown;
/// - aplicar estética;
/// - alterar o texto final.
class AiResponseStructureParser {
  final AiPlantaoParserPort plantaoParser;

  const AiResponseStructureParser({
    this.plantaoParser = const ExistingPlantaoParserPort(),
  });

  AiResponseStructureOutcome parse({
    required String text,
    required AiRequestMode mode,
    Object? structuredOutput,
  }) {
    final structured = _parseStructuredOutput(structuredOutput);

    final plantaoResponse =
        mode == AiRequestMode.plantao ? plantaoParser.parse(text) : null;

    return AiResponseStructureOutcome(
      text: text,
      mode: mode,
      plantaoResponse: plantaoResponse,
      clinicalOutput: structured.output,
      structuredOutputStatus: structured.status,
      structuredOutputErrorCode: structured.errorCode,
    );
  }
}

({
  ClinicalStructuredOutput? output,
  AiStructuredOutputStatus status,
  String? errorCode,
}) _parseStructuredOutput(Object? raw) {
  if (raw == null) {
    return (
      output: null,
      status: AiStructuredOutputStatus.absent,
      errorCode: null,
    );
  }

  if (raw is ClinicalStructuredOutput) {
    return (
      output: raw,
      status: AiStructuredOutputStatus.valid,
      errorCode: null,
    );
  }

  if (raw is! Map) {
    return (
      output: null,
      status: AiStructuredOutputStatus.invalid,
      errorCode: 'clinical_structured_output_invalid_root',
    );
  }

  try {
    final output = ClinicalStructuredOutput.fromJson(
      Map<String, dynamic>.from(raw),
    );

    return (
      output: output,
      status: AiStructuredOutputStatus.valid,
      errorCode: null,
    );
  } on FormatException catch (error) {
    return (
      output: null,
      status: AiStructuredOutputStatus.invalid,
      errorCode: error.message.toString(),
    );
  } on TypeError {
    return (
      output: null,
      status: AiStructuredOutputStatus.invalid,
      errorCode: 'clinical_structured_output_invalid_type',
    );
  }
}
