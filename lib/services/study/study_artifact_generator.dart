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
      throw UnsupportedError('final_pdf_next_phase');
    }

    final context = study.buildContext(isEs: isEs);
    final result = await AiService.chat(
      apiKey: '',
      userMessage:
          """
ESTUDIO: ${study.title}

TAREA:
${_instruction(type, isEs)}

CONTEXTO ACEPTADO DEL ESTUDIO:
$context
""",
      systemPrompt:
          """
Eres MEDCASES — MODO ESTUDIO.
Usa solamente el CONTEXTO ACEPTADO DEL ESTUDIO como fuente factual.
No mezcles pacientes, otros chats ni memoria clínica.
No inventes datos ausentes.
Si las fuentes discrepan, dilo.
Preserva dosis, números, unidades y negaciones.
Usa procedencia breve cuando exista (PDF · pág., Audio · mm:ss,
Imagen · N, Texto · bloque).
Idioma final obligatorio: ${isEs ? "español" : "português"}.
""",
      history: const <Map<String, String>>[],
      maxTokens: 3500,
      isPlantaoMode: false,
    );

    if (result.isError || result.text.trim().isEmpty) {
      throw StateError(
        'study_generation_failed:${result.errorCode ?? "empty"}',
      );
    }

    return StudyArtifact(
      id:
          'artifact_${type.name}_'
          '${DateTime.now().toUtc().microsecondsSinceEpoch}',
      type: type,
      title: _title(type, isEs),
      content: result.text.trim(),
      createdAtUtc: DateTime.now().toUtc(),
      sourceIds: study.acceptedSources
          .map((source) => source.id)
          .toList(growable: false),
    );
  }

  static String _instruction(StudyArtifactType type, bool es) {
    final pt = <StudyArtifactType, String>{
      StudyArtifactType.fullSummary:
          'Crie um resumo completo, estruturado e fiel.',
      StudyArtifactType.examSummary:
          'Crie um resumo de alta retenção para prova.',
      StudyArtifactType.mindMap: 'Crie um mapa mental textual hierárquico.',
      StudyArtifactType.flashcards:
          'Crie flashcards pergunta → resposta curtos e abrangentes.',
      StudyArtifactType.questionsAndAnswers:
          'Crie perguntas e respostas discursivas progressivas.',
      StudyArtifactType.multipleChoice:
          'Crie questões de múltipla escolha com 4 alternativas, gabarito e justificativa.',
      StudyArtifactType.oralExam:
          'Simule uma prova oral com pergunta e resposta-modelo.',
      StudyArtifactType.keyPoints: 'Extraia os pontos-chave por importância.',
      StudyArtifactType.comparisonTable:
          'Crie uma tabela comparativa Markdown apenas com dados suportados.',
      StudyArtifactType.finalPdf: 'PDF final é outro owner.',
    };

    final spanish = <StudyArtifactType, String>{
      StudyArtifactType.fullSummary:
          'Crea un resumen completo, estructurado y fiel.',
      StudyArtifactType.examSummary:
          'Crea un resumen de alta retención para examen.',
      StudyArtifactType.mindMap: 'Crea un mapa mental textual jerárquico.',
      StudyArtifactType.flashcards:
          'Crea flashcards pregunta → respuesta breves y completos.',
      StudyArtifactType.questionsAndAnswers:
          'Crea preguntas y respuestas discursivas progresivas.',
      StudyArtifactType.multipleChoice:
          'Crea preguntas de opción múltiple con 4 alternativas, respuesta y justificación.',
      StudyArtifactType.oralExam:
          'Simula un examen oral con pregunta y respuesta modelo.',
      StudyArtifactType.keyPoints: 'Extrae los puntos clave por importancia.',
      StudyArtifactType.comparisonTable:
          'Crea una tabla comparativa Markdown solo con datos sustentados.',
      StudyArtifactType.finalPdf: 'PDF final pertenece a otro owner.',
    };

    return (es ? spanish : pt)[type]!;
  }

  static String _title(StudyArtifactType type, bool es) {
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
    return (es ? spanish : pt)[type]!;
  }
}
