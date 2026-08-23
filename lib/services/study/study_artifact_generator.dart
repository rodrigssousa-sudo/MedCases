import '../../models/study_workspace_model.dart';
import '../ai_service.dart';

final class StudyArtifactGenerator {
  const StudyArtifactGenerator._();

  static Future<StudyArtifact> generate({
    required Study study,
    required StudyArtifactType type,
    required bool isEs,
  }) async {
    if (type == StudyArtifactType.finalPdf) {
      throw UnsupportedError('final_pdf_owned_by_export_service');
    }

    final context = study.buildContext(isEs: isEs);

    final result = await AiService.chat(
      apiKey: '',
      userMessage:
          """
ESTUDO: ${study.title}

OBJETIVO:
${_instruction(type, isEs)}

MATERIAL ACEITO — ÚNICA FONTE FACTUAL:
$context
""",
      systemPrompt: _systemPrompt(type, isEs),
      history: const <Map<String, String>>[],
      maxTokens: _maxTokens(type),
      isPlantaoMode: false,
    );

    if (result.isError || result.text.trim().isEmpty) {
      throw StateError(
        'study_generation_failed:${result.errorCode ?? "empty"}',
      );
    }

    final clean = _cleanResult(result.text, type: type);
    if (clean.isEmpty) {
      throw StateError('study_generation_failed:empty_after_cleanup');
    }

    return StudyArtifact(
      id: 'artifact_${type.name}_${DateTime.now().toUtc().microsecondsSinceEpoch}',
      type: type,
      title: _title(type, isEs),
      content: clean,
      createdAtUtc: DateTime.now().toUtc(),
      sourceIds: study.acceptedSources
          .map((source) => source.id)
          .toList(growable: false),
    );
  }

  static String _systemPrompt(StudyArtifactType type, bool isEs) {
    final language = isEs ? 'español' : 'português';

    if (type == StudyArtifactType.visualSummary) {
      return """
Você é MEDCASES — MODO ESTUDO.

Use SOMENTE o MATERIAL ACEITO como fonte factual.
Não invente conhecimento ausente.
Idioma obrigatório: $language.

Sua saída será renderizada como um RESUMO VISUAL premium.
Retorne APENAS JSON válido, sem Markdown, sem ``` e sem texto antes/depois.

SCHEMA OBRIGATÓRIO:
{
  "title": "título curto do tema",
  "overview": "síntese central em 2 a 4 frases contínuas",
  "sections": [
    {
      "title": "subtema curto",
      "body": "explicação clara em 2 a 5 frases"
    }
  ],
  "keyPoints": [
    "ponto-chave completo e autoexplicativo"
  ],
  "takeaway": "síntese final de revisão em 1 a 3 frases"
}

REGRAS:
- Gere de 3 a 6 sections quando o material sustentar essa divisão.
- Gere de 4 a 8 keyPoints quando houver conteúdo suficiente.
- Escreva frases naturais, com pontos e vírgulas.
- NÃO use Interlocutor A/B, Locutor 1/2 ou Speaker 1/2.
- NÃO organize por falantes; organize por conceitos.
- NÃO use *, **, #, bullets Markdown ou títulos decorativos.
- Elimine conversa lateral, cumprimentos, logística e repetições sem valor.
- Preserve números, doses, unidades, critérios, negações e classificações.
- Se o material não tiver conteúdo acadêmico substantivo, assuma isso
  claramente no overview e não invente matéria.
""";
    }

    final presentation = type == StudyArtifactType.fullSummary
        ? """
RESUMO COMPLETO — CONTRATO RÍGIDO:
- Escreva em PROSA CONTÍNUA, natural, acadêmica e realmente resumida.
- Use parágrafos coesos, frases completas, pontos, vírgulas e progressão lógica.
- Integre conceitos relacionados; não copie a estrutura fragmentada da fala.
- NÃO use bullets, listas numeradas, tabela, mapa mental, Markdown, #, **.
- NÃO use Interlocutor A/B, Locutor 1/2 ou Speaker 1/2.
- Sintetize o SIGNIFICADO, não reorganize mecanicamente frases transcritas.
- Remova repetições, hesitações, vícios de linguagem e ruído conversacional.
- Se não houver conteúdo acadêmico substantivo, não invente matéria.
"""
        : """
APRESENTAÇÃO DOS DEMAIS PRODUTOS:
- Não use preâmbulos meta.
- Não use Interlocutor A/B, Locutor 1/2 ou Speaker 1/2.
- Estruture por CONCEITOS, não por falantes.
- Markdown é permitido quando ajuda mapa mental, flashcards, perguntas ou tabela.
""";

    return """
Você é MEDCASES — MODO ESTUDO, um assistente acadêmico de alta qualidade.

Use SOMENTE o MATERIAL ACEITO como fonte factual.
Não misture outros chats, pacientes, memória clínica ou conhecimento externo.
Não invente fatos ausentes.
Se houver conflito ou incerteza na fonte, torne isso explícito.

Preserve doses, números, unidades, classificações, critérios, negações,
relações causais, exemplos relevantes e sequência temporal quando importante.

Idioma final obrigatório: $language.

$presentation

PROVENIÊNCIA:
Use proveniência para rastreabilidade, não para poluir a leitura.
Não repita timestamps em toda frase.
Use no máximo uma referência compacta por bloco quando necessária.

QUALIDADE:
Corrija fluidez gramatical sem alterar o sentido factual.
Elimine repetições e ruído da fala.
Não atribua diagnóstico, conduta, causalidade ou conclusão não sustentada.
""";
  }

  static String _instruction(StudyArtifactType type, bool isEs) {
    final pt = <StudyArtifactType, String>{
      StudyArtifactType.visualSummary:
          'Crie um resumo visual estruturado, fiel e imediatamente revisável.',
      StudyArtifactType.fullSummary:
          'Produza um resumo completo e aprofundado em prosa acadêmica contínua.',
      StudyArtifactType.examSummary:
          'Produza um resumo de alta retenção para prova, denso e claro.',
      StudyArtifactType.mindMap:
          'Crie um mapa mental hierárquico por conceitos, com Markdown limpo.',
      StudyArtifactType.flashcards:
          'Crie flashcards pergunta → resposta objetivos e abrangentes.',
      StudyArtifactType.questionsAndAnswers:
          'Crie perguntas e respostas discursivas progressivas.',
      StudyArtifactType.multipleChoice:
          'Crie questões de múltipla escolha com 4 alternativas e justificativa.',
      StudyArtifactType.oralExam:
          'Simule prova oral com perguntas progressivas e respostas-modelo.',
      StudyArtifactType.keyPoints:
          'Extraia pontos-chave por importância, removendo ruído.',
      StudyArtifactType.comparisonTable:
          'Crie tabela comparativa Markdown quando houver entidades comparáveis.',
      StudyArtifactType.finalPdf: 'PDF final pertence ao exportador.',
    };

    final es = <StudyArtifactType, String>{
      StudyArtifactType.visualSummary:
          'Crea un resumen visual estructurado, fiel y listo para repasar.',
      StudyArtifactType.fullSummary:
          'Produce un resumen completo y profundo en prosa académica continua.',
      StudyArtifactType.examSummary:
          'Produce un resumen de alta retención para examen, denso y claro.',
      StudyArtifactType.mindMap:
          'Crea un mapa mental jerárquico por conceptos con Markdown limpio.',
      StudyArtifactType.flashcards:
          'Crea flashcards pregunta → respuesta objetivos y completos.',
      StudyArtifactType.questionsAndAnswers:
          'Crea preguntas y respuestas discursivas progresivas.',
      StudyArtifactType.multipleChoice:
          'Crea preguntas de opción múltiple con 4 alternativas y justificación.',
      StudyArtifactType.oralExam:
          'Simula examen oral con preguntas progresivas y respuestas modelo.',
      StudyArtifactType.keyPoints:
          'Extrae puntos clave por importancia eliminando ruido.',
      StudyArtifactType.comparisonTable:
          'Crea tabla comparativa Markdown cuando existan entidades comparables.',
      StudyArtifactType.finalPdf: 'El PDF final pertenece al exportador.',
    };

    return (isEs ? es : pt)[type]!;
  }

  static int _maxTokens(StudyArtifactType type) {
    switch (type) {
      case StudyArtifactType.visualSummary:
        return 3200;
      case StudyArtifactType.fullSummary:
        return 5200;
      case StudyArtifactType.examSummary:
        return 4000;
      case StudyArtifactType.mindMap:
      case StudyArtifactType.questionsAndAnswers:
      case StudyArtifactType.oralExam:
        return 3800;
      case StudyArtifactType.flashcards:
      case StudyArtifactType.multipleChoice:
      case StudyArtifactType.keyPoints:
      case StudyArtifactType.comparisonTable:
        return 3500;
      case StudyArtifactType.finalPdf:
        return 2500;
    }
  }

  static String _cleanResult(String value, {required StudyArtifactType type}) {
    var clean = value
        .trim()
        .replaceFirst(
          RegExp(r'^```(?:json|markdown|md|text)?\s*', caseSensitive: false),
          '',
        )
        .replaceFirst(RegExp(r'\s*```$'), '')
        .trim();

    if (type == StudyArtifactType.visualSummary) return clean;

    for (final pattern in <RegExp>[
      RegExp(
        r'^\s*\*{0,2}MEDCASES\s*[-—:]\s*MODO\s+(?:ESTUDIO|ESTUDO)'
        r'\*{0,2}\s*',
        caseSensitive: false,
      ),
      RegExp(
        r'^\s*(?:A continuación|A continuacion|A seguir|Aqui está|Aqui esta)'
        r'[^:\n]{0,120}:\s*',
        caseSensitive: false,
      ),
    ]) {
      clean = clean.replaceFirst(pattern, '').trimLeft();
    }

    if (type == StudyArtifactType.fullSummary) {
      clean = clean
          .replaceAll(RegExp(r'^\s*#{1,6}\s*', multiLine: true), '')
          .replaceAll('**', '')
          .replaceAll('__', '')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .trim();
    }

    return clean;
  }

  static String _title(StudyArtifactType type, bool isEs) {
    final pt = <StudyArtifactType, String>{
      StudyArtifactType.visualSummary: 'Resumo visual',
      StudyArtifactType.fullSummary: 'Resumo completo',
      StudyArtifactType.examSummary: 'Resumo para prova',
      StudyArtifactType.mindMap: 'Mapa mental',
      StudyArtifactType.flashcards: 'Flashcards',
      StudyArtifactType.questionsAndAnswers: 'Perguntas e respostas',
      StudyArtifactType.multipleChoice: 'Múltipla escolha',
      StudyArtifactType.oralExam: 'Prova oral',
      StudyArtifactType.keyPoints: 'Pontos-chave',
      StudyArtifactType.comparisonTable: 'Tabela comparativa',
      StudyArtifactType.finalPdf: 'PDF final',
    };

    final es = <StudyArtifactType, String>{
      StudyArtifactType.visualSummary: 'Resumen visual',
      StudyArtifactType.fullSummary: 'Resumen completo',
      StudyArtifactType.examSummary: 'Resumen para examen',
      StudyArtifactType.mindMap: 'Mapa mental',
      StudyArtifactType.flashcards: 'Flashcards',
      StudyArtifactType.questionsAndAnswers: 'Preguntas y respuestas',
      StudyArtifactType.multipleChoice: 'Opción múltiple',
      StudyArtifactType.oralExam: 'Examen oral',
      StudyArtifactType.keyPoints: 'Puntos clave',
      StudyArtifactType.comparisonTable: 'Tabla comparativa',
      StudyArtifactType.finalPdf: 'PDF final',
    };

    return (isEs ? es : pt)[type]!;
  }
}
