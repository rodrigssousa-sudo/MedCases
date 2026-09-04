import '../../models/study_workspace_model.dart';
import '../ai_service.dart';
import 'study_context_chunker.dart';

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

    // MEDCASES_STUDY_ADAPTIVE_SUMMARY_DEPTH_V1
    final sourceCharacters = _sourceCharacterCount(study);
    final context = await _buildHierarchicalContext(
      study,
      type: type,
      isEs: isEs,
    );
    final lengthDirective = _lengthDirective(
      type,
      sourceCharacters: sourceCharacters,
      isEs: isEs,
    );

    final result = await AiService.chat(
      apiKey: '',
      userMessage: """
ESTUDO: ${study.title}

OBJETIVO:
${_instruction(type, isEs)}

$lengthDirective

MATERIAL ACEITO — ÚNICA FONTE FACTUAL:
$context
""",
      systemPrompt: _systemPrompt(type, isEs),
      history: const <Map<String, String>>[],
      maxTokens: _maxTokens(type, sourceCharacters: sourceCharacters),
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

  static Future<String> _buildHierarchicalContext(
    Study study, {
    required StudyArtifactType type,
    required bool isEs,
  }) async {
    final isFullSummary = type == StudyArtifactType.fullSummary;
    final contextCeiling = isFullSummary ? 120000 : 90000;
    final mapTokenBudget = isFullSummary ? 5600 : 4200;
    final reduceTokenBudget = isFullSummary ? 7000 : 5000;

    final chunks = StudyContextChunker.build(study: study, isEs: isEs);
    if (chunks.length == 1) return chunks.single.value;

    var level = <String>[];

    for (final chunk in chunks) {
      final result = await AiService.chat(
        apiKey: '',
        userMessage: """
BLOCO ${chunk.index}/${chunk.total}

${chunk.value}
""",
        systemPrompt: _mapPrompt(isEs),
        history: const <Map<String, String>>[],
        maxTokens: mapTokenBudget,
        isPlantaoMode: false,
      );

      if (result.isError || result.text.trim().isEmpty) {
        throw StateError(
          'study_hierarchical_map_failed:${result.errorCode ?? "empty"}',
        );
      }
      level.add(result.text.trim());
    }

    while (_joinedLength(level) > contextCeiling) {
      final joined = level.join('\n\n===== MAP BLOCK =====\n\n');
      final partitions = StudyContextChunker.splitText(
        joined,
        maxCharacters: 42000,
      );
      final reduced = <String>[];

      for (var i = 0; i < partitions.length; i++) {
        final result = await AiService.chat(
          apiKey: '',
          userMessage: """
CONSOLIDAÇÃO ${i + 1}/${partitions.length}

${partitions[i]}
""",
          systemPrompt: _reducePrompt(isEs),
          history: const <Map<String, String>>[],
          maxTokens: reduceTokenBudget,
          isPlantaoMode: false,
        );

        if (result.isError || result.text.trim().isEmpty) {
          throw StateError(
            'study_hierarchical_reduce_failed:'
            '${result.errorCode ?? "empty"}',
          );
        }
        reduced.add(result.text.trim());
      }

      if (_joinedLength(reduced) >= _joinedLength(level) &&
          _joinedLength(reduced) > contextCeiling) {
        throw StateError('study_hierarchical_reduce_not_converging');
      }
      level = reduced;
    }

    return level.join('\n\n===== CONSOLIDATED BLOCK =====\n\n');
  }

  static int _joinedLength(List<String> values) =>
      values.fold<int>(0, (sum, value) => sum + value.length + 40);

  static String _mapPrompt(bool isEs) => isEs
      ? """
Eres MEDCASES — MODO ESTUDIO.
Este es SOLO un fragmento de una fuente mayor.
Crea una consolidación factual DENSA y fiel para una etapa posterior.
No hagas el producto final. No inventes conocimiento externo.
Conserva TODOS los conceptos académicos sustantivos, dosis, números,
unidades, criterios, clasificaciones, negaciones, contraindicaciones,
relaciones causales y excepciones. Elimina solo repetición y ruido.
Mantén la proveniencia incluida en el bloque.
"""
      : """
Você é MEDCASES — MODO ESTUDO.
Este é APENAS um fragmento de uma fonte maior.
Crie uma consolidação factual DENSA e fiel para uma etapa posterior.
Não faça o produto final. Não invente conhecimento externo.
Preserve TODOS os conceitos acadêmicos substantivos, doses, números,
unidades, critérios, classificações, negações, contraindicações,
relações causais e exceções. Remova apenas repetição e ruído.
Mantenha a proveniência incluída no bloco.
""";

  static String _reducePrompt(bool isEs) => isEs
      ? """
Eres MEDCASES — MODO ESTUDIO.
Consolida varios mapas parciales en un único contexto factual denso.
No produzcas todavía el resumen final.
No inventes ni añadas conocimiento externo.
NO pierdas dosis, números, unidades, criterios, clasificaciones,
negaciones, contraindicaciones, excepciones ni relaciones causales.
Deduplica únicamente información realmente repetida.
"""
      : """
Você é MEDCASES — MODO ESTUDO.
Consolide vários mapas parciais em um único contexto factual denso.
Ainda não produza o resumo final.
Não invente nem acrescente conhecimento externo.
NÃO perca doses, números, unidades, critérios, classificações,
negações, contraindicações, exceções nem relações causais.
Deduplicate apenas informação realmente repetida.
""";

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

    // MEDCASES_STUDY_FULL_SUMMARY_DIDACTIC_V2
    // MEDCASES_STUDY_COMPARISON_TABLE_DIDACTIC_V2
    final presentation = type == StudyArtifactType.fullSummary
        ? """
RESUMO COMPLETO — CONTRATO DIDÁTICO:
- Escreva em PROSA ACADÊMICA DIDÁTICA, clara e aprofundada; não faça parede de texto.
- Organize o conteúdo em BLOCOS TEMÁTICOS curtos conforme o material sustentar.
- Use títulos temáticos simples em linha própria, sem #, ** ou títulos decorativos.
- Cada parágrafo deve ter preferencialmente 2 a 4 frases e cerca de 45 a 90 palavras.
- Separe parágrafos e mudanças de ideia com UMA LINHA EM BRANCO.
- Nunca concentre vários conceitos independentes em um único parágrafo longo.
- Bullets são permitidos APENAS quando a informação for naturalmente enumerável,
  como critérios, etapas, classificações, doses, diferenças ou sequências; use de
  3 a 7 itens curtos e autoexplicativos, sem transformar todo o resumo em lista.
- Não use tabela no resumo completo; tabela pertence ao produto comparativo.
- Integre conceitos relacionados e preserve progressão lógica entre os blocos.
- NÃO use Interlocutor A/B, Locutor 1/2 ou Speaker 1/2.
- Sintetize o SIGNIFICADO, não reorganize mecanicamente frases transcritas.
- Remova repetições, hesitações, vícios de linguagem e ruído conversacional.
- Preserve doses, números, unidades, critérios, classificações, negações e exceções.
- Se não houver conteúdo acadêmico substantivo, não invente matéria.
"""
        : type == StudyArtifactType.comparisonTable
            ? """
TABELA COMPARATIVA — CONTRATO DIDÁTICO:
- Retorne Markdown de tabela VÁLIDO e diretamente renderizável, sem preâmbulo.
- Compare somente entidades realmente comparáveis e somente dados sustentados.
- Prefira 2 a 5 colunas no total: 1ª coluna = CRITÉRIO; demais = entidades.
- Se houver mais de 4 entidades ou comparação excessivamente larga, DIVIDA em
  duas ou mais tabelas temáticas menores em vez de criar uma megatabela.
- Cada linha deve comparar o MESMO parâmetro em todas as entidades.
- Cabeçalhos devem ser curtos, específicos e estáveis.
- Cada célula deve conter uma informação direta e curta; evite parágrafos.
- Preserve unidades, números, limiares, doses, categorias e diferenças relevantes.
- Use frases nominais ou qualificadores separados por ponto e vírgula quando preciso.
- Evite células redundantes, repetição do nome da entidade e texto explicativo longo.
- Não invente colunas ou critérios para preencher espaços.
- Se o material não sustentar comparação real, declare isso brevemente e não force tabela.
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
          'Produza um resumo completo e aprofundado em prosa acadêmica didática, com blocos temáticos e parágrafos curtos de leitura fácil.',
      StudyArtifactType.examSummary:
          'Produza um resumo de alta retenção para prova, denso e claro.',
      StudyArtifactType.mindMap: 'Crie um MAPA MENTAL PROFISSIONAL, conciso e visualmente hierárquico. '
          'A primeira linha deve ser # TEMA CENTRAL contendo SOMENTE o assunto '
          'acadêmico principal, sem minutos, timestamps, fonte, número da aula, '
          'nome de arquivo ou metadados. Depois use de 4 a 8 categorias principais '
          'como ## Categoria. Logo abaixo de cada categoria escreva uma única linha '
          '- Resumo: ... com síntese de no máximo 140 caracteres. Opcionalmente use '
          'até 2 detalhes curtos por categoria, cada um com no máximo 90 caracteres. '
          'Não copie parágrafos, não use paredes de texto, não repita o tema, não use '
          'Interlocutor A/B e não force categorias que a fonte não sustenta.',
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
          'Crie tabela comparativa Markdown didática, com critério na primeira coluna, células curtas e no máximo quatro entidades por tabela.',
      StudyArtifactType.finalPdf: 'PDF final pertence ao exportador.',
    };

    final es = <StudyArtifactType, String>{
      StudyArtifactType.visualSummary:
          'Crea un resumen visual estructurado, fiel y listo para repasar.',
      StudyArtifactType.fullSummary:
          'Produce un resumen completo y profundo en prosa académica didáctica, con bloques temáticos y párrafos cortos de lectura fácil.',
      StudyArtifactType.examSummary:
          'Produce un resumen de alta retención para examen, denso y claro.',
      StudyArtifactType.mindMap: 'Crea un MAPA MENTAL PROFESIONAL, conciso y visualmente jerárquico. '
          'La primera línea debe ser # TEMA CENTRAL con SOLO el tema académico '
          'principal, sin minutos, timestamps, fuente, número de clase, nombre de '
          'archivo ni metadatos. Luego usa de 4 a 8 categorías principales como '
          '## Categoría. Debajo de cada categoría escribe una sola línea '
          '- Resumen: ... con una síntesis de máximo 140 caracteres. Opcionalmente '
          'usa hasta 2 detalles breves por categoría, cada uno de máximo 90 '
          'caracteres. No copies párrafos, no uses muros de texto, no repitas el '
          'tema, no uses Interlocutor A/B y no fuerces categorías no sustentadas.',
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
          'Crea tabla comparativa Markdown didáctica, con criterio en la primera columna, celdas breves y máximo cuatro entidades por tabla.',
      StudyArtifactType.finalPdf: 'El PDF final pertenece al exportador.',
    };

    return (isEs ? es : pt)[type]!;
  }

  static int _sourceCharacterCount(Study study) {
    return study.acceptedSources.fold<int>(
      0,
      (sum, source) => sum + source.text.trim().length,
    );
  }

  static String _lengthDirective(
    StudyArtifactType type, {
    required int sourceCharacters,
    required bool isEs,
  }) {
    if (type == StudyArtifactType.fullSummary) {
      final target = sourceCharacters >= 90000
          ? (isEs ? '4.500 a 6.000 palabras' : '4.500 a 6.000 palavras')
          : sourceCharacters >= 50000
              ? (isEs ? '3.200 a 4.500 palabras' : '3.200 a 4.500 palavras')
              : sourceCharacters >= 28000
                  ? (isEs ? '2.200 a 3.400 palabras' : '2.200 a 3.400 palavras')
                  : (isEs ? '1.400 a 2.400 palabras' : '1.400 a 2.400 palavras');

      return isEs
          ? """
PROFUNDIDAD DEL PRODUCTO:
- Este es el producto MÁS COMPLETO del estudio.
- La extensión debe crecer con la cantidad de material aceptado.
- Para este volumen de fuente, apunta aproximadamente a $target cuando el
  contenido académico lo sustente.
- NO comprimas una clase larga en pocas páginas solo por ser un "resumen".
- Cubre todos los temas sustantivos, incluidos subtemas secundarios útiles,
  relaciones, mecanismos, criterios, clasificaciones, ejemplos y excepciones.
- Reduce repetición y ruido, NO cobertura académica.
- Mantén párrafos cortos, títulos temáticos y espacio entre ideas.
"""
          : """
PROFUNDIDADE DO PRODUTO:
- Este é o produto MAIS COMPLETO do estudo.
- A extensão deve crescer com a quantidade de material aceito.
- Para este volume de fonte, busque aproximadamente $target quando o
  conteúdo acadêmico sustentar essa profundidade.
- NÃO comprima uma aula longa em poucas páginas apenas por ser um "resumo".
- Cubra todos os temas substantivos, inclusive subtemas secundários úteis,
  relações, mecanismos, critérios, classificações, exemplos e exceções.
- Reduza repetição e ruído, NÃO cobertura acadêmica.
- Mantenha parágrafos curtos, títulos temáticos e espaço entre ideias.
""";
    }

    if (type == StudyArtifactType.examSummary) {
      return isEs
          ? """
PROFUNDIDAD DEL PRODUCTO:
- Este es un producto INTERMEDIO, menor que el Resumen completo y mayor que
  el Resumen visual.
- Prioriza lo examinable, criterios, clasificaciones, mecanismos, fórmulas,
  diferencias y trampas frecuentes.
- Mantén cobertura amplia sin reproducir toda la clase.
"""
          : """
PROFUNDIDADE DO PRODUTO:
- Este é um produto INTERMEDIÁRIO, menor que o Resumo completo e maior que
  o Resumo visual.
- Priorize o que é cobrável em prova, critérios, classificações, mecanismos,
  fórmulas, diferenças e armadilhas frequentes.
- Mantenha cobertura ampla sem reproduzir toda a aula.
""";
    }

    if (type == StudyArtifactType.visualSummary) {
      return isEs
          ? """
PROFUNDIDAD DEL PRODUCTO:
- Este es el producto MÁS CORTO y escaneable.
- Prioriza síntesis visual y revisión rápida; no intentes igualar la
  profundidad del Resumen completo.
"""
          : """
PROFUNDIDADE DO PRODUTO:
- Este é o produto MAIS CURTO e escaneável.
- Priorize síntese visual e revisão rápida; não tente igualar a profundidade
  do Resumo completo.
""";
    }

    return '';
  }

  static int _maxTokens(
    StudyArtifactType type, {
    required int sourceCharacters,
  }) {
    switch (type) {
      case StudyArtifactType.visualSummary:
        return 3200;
      case StudyArtifactType.fullSummary:
        if (sourceCharacters >= 90000) return 12000;
        if (sourceCharacters >= 50000) return 10000;
        if (sourceCharacters >= 28000) return 8000;
        return 6500;
      case StudyArtifactType.examSummary:
        if (sourceCharacters >= 70000) return 6200;
        if (sourceCharacters >= 32000) return 5400;
        return 4800;
      case StudyArtifactType.mindMap:
        return 2200;
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
