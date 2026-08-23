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
      id:
          'artifact_${type.name}_'
          '${DateTime.now().toUtc().microsecondsSinceEpoch}',
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

    final presentation = type == StudyArtifactType.fullSummary
        ? """
RESUMO COMPLETO — CONTRATO RÍGIDO:
- Escreva em PROSA CONTÍNUA, natural, acadêmica e realmente resumida.
- Use parágrafos coesos, frases completas, pontos, vírgulas e progressão lógica.
- Integre conceitos relacionados; não copie a estrutura fragmentada da fala.
- NÃO use bullets, listas numeradas, tabela, mapa mental, Markdown, #, **,
  blocos de código ou títulos decorativos.
- NÃO comece com MEDCASES, MODO ESTUDO, "Aqui está", "A seguir",
  "A continuación", "Presento el resumen" ou qualquer preâmbulo meta.
- NÃO use "Interlocutor A/B", "Locutor 1/2", "Speaker 1/2" nem diarização
  artificial. Se nomes ou papéis não forem explícitos e indispensáveis,
  integre as ideias sem rotular falantes.
- Sintetize o SIGNIFICADO, não reorganize mecanicamente frases transcritas.
- Remova repetições, hesitações, vícios de linguagem e ruído conversacional.
- Conversa lateral, logística, cumprimentos, táxi, tempo disponível e outros
  detalhes sociais sem valor acadêmico devem ser omitidos ou comprimidos.
- Se o material não tiver conteúdo acadêmico substantivo suficiente, diga isso
  claramente em um parágrafo curto. Não invente matéria médica/acadêmica.
- Seja completo, aprofundado e claro, mas evite repetição.
"""
        : """
APRESENTAÇÃO DOS DEMAIS PRODUTOS:
- Não use preâmbulos meta como "Aqui está", "A continuación" ou "MEDCASES".
- Não use "Interlocutor A/B", "Locutor 1/2" ou "Speaker 1/2" salvo se a
  distinção entre pessoas for factual e indispensável.
- Estruture por CONCEITOS, não por falantes.
- Markdown é permitido somente quando ajuda o formato solicitado, como mapa
  mental, flashcards, perguntas ou tabela. O aplicativo renderizará Markdown.
""";

    return """
Você é MEDCASES — MODO ESTUDO, um assistente acadêmico de alta qualidade.

Use SOMENTE o MATERIAL ACEITO como fonte factual.
Não misture outros chats, pacientes, memória clínica ou conhecimento externo.
Não invente fatos ausentes.
Se houver conflito ou incerteza na fonte, torne isso explícito.

Preserve com máxima fidelidade doses, números, unidades, classificações,
critérios, negações, relações causais, exemplos relevantes e sequência
temporal quando academicamente importante.

Idioma final obrigatório: $language.

$presentation

PROVENIÊNCIA:
A proveniência serve para rastreabilidade, não para poluir a leitura.
Não repita "(Áudio · 00:31)" em toda frase.
No resumo completo e no resumo para prova, use no máximo uma referência
compacta por parágrafo quando realmente necessária ou uma linha breve de
fontes ao final. Nunca invente página ou timestamp.

QUALIDADE:
Corrija a fluidez gramatical sem alterar o sentido factual.
Elimine repetições e ruído da fala.
Não atribua diagnóstico, conduta, causalidade ou conclusão que a fonte
não sustente.
""";
  }

  static String _instruction(StudyArtifactType type, bool isEs) {
    final pt = <StudyArtifactType, String>{
      StudyArtifactType.fullSummary:
          'Produza um resumo completo e aprofundado do conteúdo substantivo. '
          'Construa uma narrativa acadêmica contínua em parágrafos, integrando '
          'conceitos relacionados, explicações, relações, exemplos, números e '
          'detalhes relevantes. Organize o raciocínio na ordem mais clara para '
          'estudo, sem copiar a estrutura fragmentada da transcrição.',
      StudyArtifactType.examSummary:
          'Produza um resumo de alta retenção para prova. Seja denso, claro e '
          'fiel. Priorize conceitos centrais, relações, critérios, diferenças '
          'e detalhes que realmente podem ser cobrados. Elimine ruído da fala.',
      StudyArtifactType.mindMap:
          'Crie um mapa mental textual hierárquico baseado nos CONCEITOS do '
          'material, não nos falantes. Use Markdown limpo com tópicos curtos e '
          'relações claras. Nunca use Interlocutor A/B.',
      StudyArtifactType.flashcards:
          'Crie flashcards pergunta → resposta objetivos e abrangentes, '
          'baseados somente no conteúdo substantivo. Elimine conversa lateral.',
      StudyArtifactType.questionsAndAnswers:
          'Crie perguntas e respostas discursivas progressivas, priorizando '
          'compreensão, integração e pontos importantes do material.',
      StudyArtifactType.multipleChoice:
          'Crie questões de múltipla escolha com 4 alternativas, gabarito e '
          'justificativa. Não introduza conhecimento não sustentado pela fonte.',
      StudyArtifactType.oralExam:
          'Simule uma prova oral com perguntas progressivas e respostas-modelo '
          'claras, completas e estritamente sustentadas pelo material.',
      StudyArtifactType.keyPoints:
          'Extraia os pontos-chave por importância, eliminando ruído, '
          'repetições e detalhes logísticos sem valor acadêmico.',
      StudyArtifactType.comparisonTable:
          'Crie uma tabela comparativa Markdown somente quando o material '
          'realmente contiver entidades comparáveis. Não force comparações.',
      StudyArtifactType.finalPdf: 'PDF final pertence ao exportador.',
    };

    final spanish = <StudyArtifactType, String>{
      StudyArtifactType.fullSummary:
          'Produce un resumen completo y profundo del contenido sustantivo. '
          'Construye una narrativa académica continua en párrafos, integrando '
          'conceptos relacionados, explicaciones, relaciones, ejemplos, '
          'números y detalles relevantes. Organiza el razonamiento en el orden '
          'más claro para estudiar, sin copiar la estructura fragmentada de la '
          'transcripción.',
      StudyArtifactType.examSummary:
          'Produce un resumen de alta retención para examen. Sé denso, claro '
          'y fiel. Prioriza conceptos centrales, relaciones, criterios, '
          'diferencias y detalles evaluables. Elimina el ruido conversacional.',
      StudyArtifactType.mindMap:
          'Crea un mapa mental textual jerárquico basado en los CONCEPTOS del '
          'material, no en los hablantes. Usa Markdown limpio con tópicos '
          'breves y relaciones claras. Nunca uses Interlocutor A/B.',
      StudyArtifactType.flashcards:
          'Crea flashcards pregunta → respuesta objetivos y completos, '
          'basados solo en el contenido sustantivo. Elimina conversación lateral.',
      StudyArtifactType.questionsAndAnswers:
          'Crea preguntas y respuestas discursivas progresivas que prioricen '
          'comprensión, integración y puntos importantes del material.',
      StudyArtifactType.multipleChoice:
          'Crea preguntas de opción múltiple con 4 alternativas, respuesta y '
          'justificación, sin introducir conocimiento no sustentado.',
      StudyArtifactType.oralExam:
          'Simula un examen oral con preguntas progresivas y respuestas modelo '
          'claras, completas y estrictamente sustentadas por el material.',
      StudyArtifactType.keyPoints:
          'Extrae los puntos clave por importancia, eliminando ruido, '
          'repeticiones y detalles logísticos sin valor académico.',
      StudyArtifactType.comparisonTable:
          'Crea una tabla comparativa Markdown solo si el material contiene '
          'entidades realmente comparables. No fuerces comparaciones.',
      StudyArtifactType.finalPdf: 'El PDF final pertenece al exportador.',
    };

    return (isEs ? spanish : pt)[type]!;
  }

  static int _maxTokens(StudyArtifactType type) {
    switch (type) {
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
          RegExp(r'^```(?:markdown|md|text)?\s*', caseSensitive: false),
          '',
        )
        .replaceFirst(RegExp(r'\s*```$'), '')
        .trim();

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
      RegExp(
        r'^\s*(?:Presento|Apresento)\s+[^:\n]{0,120}:\s*',
        caseSensitive: false,
      ),
    ]) {
      clean = clean.replaceFirst(pattern, '').trimLeft();
    }

    if (type == StudyArtifactType.fullSummary) {
      clean = clean
          .replaceAll(RegExp(r'(?m)^\s*#{1,6}\s*'), '')
          .replaceAll('**', '')
          .replaceAll('__', '')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .trim();
    }

    return clean;
  }

  static String _title(StudyArtifactType type, bool isEs) {
    const pt = <StudyArtifactType, String>{
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

    const spanish = <StudyArtifactType, String>{
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

    return (isEs ? spanish : pt)[type]!;
  }
}
