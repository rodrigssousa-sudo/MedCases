/// Study owns explanatory content; the shared renderer owns only typography.
class StudyResponseContract {
  static const maxOutputTokens = 8192;
  static const referencePolicy =
      'REFERÊNCIAS DO ESTUDO: use apenas registros internos realmente fornecidos '
      'ou fontes confirmadas pelo grounding desta requisição. Priorize guidelines '
      'oficiais, sociedades médicas, OMS/WHO, CDC, ministérios, reguladores, PubMed '
      'e fontes primárias/revisões confiáveis. Nunca invente DOI, PMID, URL, título, '
      'autor, guideline ou ano. Bibliografias sugeridas não comprovam consulta. '
      'Sem referência específica disponível, ensine o conteúdo seguro e informe '
      'no idioma ativo que nenhuma referência específica foi anexada; não bloqueie '
      'a explicação nem preencha referências por suposição. A seleção das fontes '
      'não muda conforme o idioma PT/ES.';
  static const contract = '<instructions id="estudo_rules">\n'
      'MODO ESTUDO — resposta didática e estruturada.\n'
      'PRIORIDADE: responder, ensinar, estruturar e referenciar em uma geração útil. '
      'Contexto e repositório enriquecem; não autorizam a existência da resposta. '
      'Cobertura didática orienta qualidade, não bloqueia uma explicação útil '
      'nem exige uma nova geração por uma seção ausente. '
      'Responda ao aspecto solicitado com profundidade proporcional à pergunta. '
      'Use um título #, seções ## e subseções ### apenas quando relevantes. '
      'Inclua conceito, mecanismo/fisiopatologia, achados, raciocínio clínico '
      'explicável, diagnóstico, tratamento, pontos-chave e resumo conforme a pergunta; '
      'Para o nome isolado de uma doença, inclua definição, fisiopatologia, causas, '
      'diagnóstico e tratamento; acrescente monitorização quando pertinente. '
      'não imponha todas as seções. Use parágrafos curtos, comparações úteis e '
      'negrito seletivo. Não comprima ao formato operacional do Plantão e não '
      'conte linhas/palavras nem numere linhas. Sem emojis decorativos. '
      'Consulta geral: explique primeiro; tratamento e doses padrão sustentadas '
      'são permitidos, incluindo dose inicial, faixa, via, frequência, duração, '
      'máximo e ajustes gerais sustentados. Doença grave, farmacologia, emergência, '
      'ausência de catálogo ou falha de grounding não bloqueiam conteúdo educacional. '
      'Cálculo individual explicitamente pedido requer apenas os dados pertinentes. '
      'Se uma parte não puder ser respondida com segurança, limite apenas essa '
      'parte e preserve definição, fisiopatologia, diagnóstico, tratamento e monitorização. '
      'Não invente fatos, pacientes, doses ou referências. Use referências reais '
      'somente quando fornecidas/verificadas. Preserve o assunto e aprofunde '
      'o aspecto pedido nos follow-ups sem repetir a resposta anterior.\n'
      '$referencePolicy\n'
      'OUTPUT ONLY THE USER-FACING STUDY ANSWER. '
      'Não exponha deliberação interna, constraint checking, self-validation, '
      'language checks, schema notes, parser diagnostics, notas de reparo ou '
      'rascunhos. Raciocínio clínico didático não é uma descrição do processo '
      'interno do modelo.\n'
      'Metadados finais opcionais, separados do texto da resposta:\n'
      '[NEXT_ACTION_LABEL: rótulo contextual curto no idioma ativo]\n'
      '[NEXT_ACTION_PROMPT: pergunta de aprofundamento do mesmo assunto]\n'
      '</instructions>\n';

  static String forLanguage(String language) => language.startsWith('es')
      ? 'Entrega únicamente la respuesta didáctica final para el usuario, '
          'íntegramente en español. Conserva la estructura Markdown, los '
          'párrafos breves y las explicaciones relevantes. No publiques '
          'comprobaciones de idioma, restricciones, notas internas ni números '
          'de línea. Termina las frases; no cortes información para contar líneas.\n'
      : 'Entregue somente a resposta didática final para o usuário, inteiramente '
          'em português. Preserve a estrutura Markdown, os parágrafos curtos '
          'e as explicações relevantes. Não publique verificações de idioma, '
          'restrições, notas internas ou números de linha. Termine as frases; '
          'não corte informação para contar linhas.\n';

  static final _internalTags = RegExp(
      r'<(thinking|think|analysis|scratchpad|internal_notes|internal_diagnostics|instructions|system_rules|response_template)\b[^>]*>[\s\S]*?(?:</\1\s*>|$)',
      caseSensitive: false);
  static final _lineLabel =
      RegExp(r'^\s*(?:Line|Línea|Linha)\s+\d+\s*:\s*', caseSensitive: false);
  static final _diagnosticStart = RegExp(
      r"^(?:let[’']s\s+review\s+constraints|let\s+me\s+(?:think|review|check|analyze)|"
      r'(?:internal|self)[ -]?(?:validation|review|check|diagnostics|notes|reasoning)|'
      r"user input analysis|the user[’']?s? (?:input|request)|i need to (?:provide|answer|check)|"
      r'revis[ãa]o interna|revisi[oó]n interna|constraint checking|scratchpad|'
      r'schema repair|parser diagnostics|output_starts_here|end_of_instructions|'
      r'(?:system_rules|instructions|response_template)\b)',
      caseSensitive: false);
  static final _diagnosticLine = RegExp(
      r'^(?:(?:language|idioma)\s*:|checked\s*[.!:]?$|anti-\s*$|'
      r'(?:anti[- ](?:leak|cot)|constraints?|self[- ]check|schema|format(?:ting)?)\s*:|'
      r'\[(?:MANDATO|CONTRACT|TRAVA|SISTEMA|SYSTEM|PROMPT|CAMADA|REVISAO_INTERNA|REVISION_INTERNA)\b)',
      caseSensitive: false);
  static final _answerStart = RegExp(
      r'^(?:final answer|respuesta final|resposta final|clinicalAnswer)\s*:\s*',
      caseSensitive: false);

  /// Stateful *within the snapshot*: transport chunk boundaries cannot split a
  /// diagnostic marker past the filter. In streaming, keep the unfinished line
  /// buffered. No clinical substring is deleted merely for mentioning "anti".
  static StudyResponseProjection project(String input, {bool complete = true}) {
    var removed = 0;
    final reasons = <String>{};
    var source = input.replaceAllMapped(_internalTags, (match) {
      removed++;
      reasons.add('INTERNAL_TAG');
      return '';
    });
    if (!complete && !source.endsWith('\n')) {
      final lastBreak = source.lastIndexOf('\n');
      source = lastBreak < 0 ? '' : source.substring(0, lastBreak + 1);
    }
    final clinical = <String>[];
    var diagnostics = false;
    for (var line in source.split('\n')) {
      if (_lineLabel.hasMatch(line)) {
        line = line.replaceFirst(_lineLabel, '');
        removed++;
        reasons.add('INTERNAL_LINE_LABEL');
      }
      final plain = line.trim().replaceFirst(RegExp(r'^[#*`>\s-]+'), '');
      if (_diagnosticStart.hasMatch(plain)) {
        diagnostics = true;
        removed++;
        reasons.add('INTERNAL_DIAGNOSTIC_BLOCK');
        continue;
      }
      if (_diagnosticLine.hasMatch(plain)) {
        removed++;
        reasons.add('INTERNAL_DIAGNOSTIC_LINE');
        continue;
      }
      if (_answerStart.hasMatch(plain)) {
        diagnostics = false;
        line = plain.replaceFirst(_answerStart, '');
      } else if (RegExp(r'^#{1,3}\s+\S').hasMatch(line.trimLeft())) {
        diagnostics = false;
      }
      if (diagnostics) {
        if (line.trim().isNotEmpty) removed++;
        continue;
      }
      clinical.add(line);
    }
    return StudyResponseProjection(
      clinicalAnswer: complete
          ? clinical.join('\n').trim()
          : clinical.join('\n').trimLeft(),
      removedFragments: removed,
      reasonCodes: Set.unmodifiable(reasons),
    );
  }

  /// Presentation only. Preserve explanatory headings, case, facts and order.
  static String normalizePresentation(String text, {bool complete = true}) =>
      String.fromCharCodes(project(text, complete: complete)
          .clinicalAnswer
          // The continuation resolver consumes these fields separately. They
          // must not flash as Markdown while the stream notifier is active.
          .replaceAll(
              RegExp(r'\[NEXT_ACTION_(?:LABEL|PROMPT):[^\]]*(?:\]|$)'), '')
          .runes
          .where((cp) => !((cp >= 0x1F000 && cp <= 0x1FAFF) ||
              (cp >= 0x2600 && cp <= 0x27BF) ||
              cp == 0xFE0F ||
              cp == 0x200D)));
}

class StudyResponseProjection {
  const StudyResponseProjection(
      {required this.clinicalAnswer,
      required this.removedFragments,
      required this.reasonCodes});
  final String clinicalAnswer;
  final int removedFragments;
  final Set<String> reasonCodes;
  bool get hadInternalText => removedFragments != 0;
}
