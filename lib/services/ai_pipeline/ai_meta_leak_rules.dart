import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Rule identities contain only trusted patterns; diagnostics never expose text.
class MetaLeakRule {
  const MetaLeakRule(this.ruleId, this.patternId, this.pattern);
  final String ruleId;
  final String patternId;
  final String pattern;
}

class AiMetaLeakRules {
  static const rules = <MetaLeakRule>[
    MetaLeakRule(
        'META_LEAK_INTERNAL_PROMPT', 'meta_04b26b7edd1a', r'\[MANDATO'),
    MetaLeakRule(
        'META_LEAK_INTERNAL_PROMPT', 'meta_c63b06e8916a', r'\[MODO PLANT'),
    MetaLeakRule(
        'META_LEAK_INTERNAL_PROMPT', 'meta_20a6c8f1aa39', r'\[MODO ESTU'),
    MetaLeakRule(
        'META_LEAK_INTERNAL_PROMPT', 'meta_5114cf104c73', r'\[CONTRACT'),
    MetaLeakRule(
        'META_LEAK_LANGUAGE_CHECK', 'meta_c28fa075563a', r'\[TRAVA DE IDIOMA'),
    MetaLeakRule(
        'META_LEAK_INTERNAL_PROMPT', 'meta_56a0572220b8', r'\[AI_ROUTER'),
    MetaLeakRule(
        'META_LEAK_INTERNAL_PROMPT', 'meta_32f82be969b5', r'\[REFOR[ÇC]O'),
    MetaLeakRule(
        'META_LEAK_INTERNAL_PROMPT', 'meta_236334be06ab', r'\[SOBERANIA'),
    MetaLeakRule(
        'META_LEAK_INTERNAL_PROMPT', 'meta_498490a95f1f', r'\[IN[ÍI]CIO'),
    MetaLeakRule('META_LEAK_INTERNAL_PROMPT', 'meta_2a5e0ba697c1', r'\[SYSTEM'),
    MetaLeakRule('META_LEAK_INTERNAL_PROMPT', 'meta_d87c158c4288', r'\[PROMPT'),
    MetaLeakRule('META_LEAK_DEBUG_LABEL', 'meta_7a4784cad741', r'\[CAMADA'),
    MetaLeakRule('META_LEAK_DEBUG_LABEL', 'meta_814f9870dad7', r'\[SISTEMA'),
    MetaLeakRule(
        'META_LEAK_INTERNAL_PROMPT', 'meta_5d2aab5e0b17', r'\[CONTEXTO RAG\]'),
    MetaLeakRule('META_LEAK_INTERNAL_PROMPT', 'meta_d8ca9b270759',
        r'RESPONDA\s+ESTRITAMENTE'),
    MetaLeakRule('META_LEAK_INTERNAL_PROMPT', 'meta_4319541032e5',
        r'RESPONDA\s+[ÚU]NICA\s+E\s+EXCLUSIVAMENTE'),
    MetaLeakRule('META_LEAK_INTERNAL_PROMPT', 'meta_d4d785ff646c',
        r'TEMPLATE\s+DE\s+\d+\s+LINHAS'),
    MetaLeakRule('META_LEAK_INTERNAL_PROMPT', 'meta_4f1147ae41f0',
        r'NESTA\s+ORDEM\s+EXATA'),
    MetaLeakRule('META_LEAK_INTERNAL_PROMPT', 'meta_cde890980934',
        r'PROIBIDO\s+CRIAR\s+INTRODU'),
    MetaLeakRule('META_LEAK_DEBUG_LABEL', 'meta_d2f0a7d53158',
        r'INSTRUÇÃO\s+DE\s+SISTEMA'),
    MetaLeakRule(
        'META_LEAK_INTERNAL_PROMPT', 'meta_e2eed11dc244', r'PROMPT\s+INTERNO'),
    MetaLeakRule('META_LEAK_INTERNAL_PROMPT', 'meta_4b04ab18f25e',
        r'SYSTEM\s+INSTRUCTION'),
    MetaLeakRule(
        'META_LEAK_INTERNAL_PROMPT', 'meta_4db98643d9c7', r'SMART\s+ROUTER'),
    MetaLeakRule(
        'META_LEAK_INTERNAL_PROMPT', 'meta_4c9a158535d5', r'LAZY\s+M[ÓO]DULO'),
    MetaLeakRule(
        'META_LEAK_LANGUAGE_CHECK', 'meta_8c28d275f1c8', r'IDIOMA\s+SOBERANO'),
    MetaLeakRule('META_LEAK_LANGUAGE_CHECK', 'meta_413e765a5a97',
        r'TRAVA\s+DE\s+IDIOMA'),
    MetaLeakRule(
        'META_LEAK_INTERNAL_PROMPT', 'meta_2746e2ad2073', r'IRREVOG[ÁA]VEL'),
    MetaLeakRule('META_LEAK_INTERNAL_PROMPT', 'meta_e38fc6b31c18',
        r'IGNORAR\s+COMPLETAMENTE\s+o\s+idioma'),
    MetaLeakRule(
        'META_LEAK_LANGUAGE_CHECK', 'meta_2c85b4c43403', r'✗\s+PROIBIDO:'),
    MetaLeakRule('META_LEAK_LANGUAGE_CHECK', 'meta_cbad5f93d64d',
        r'✓\s+OBRIGAT[ÓO]RIO:'),
    MetaLeakRule('META_LEAK_LANGUAGE_CHECK', 'meta_93655b6e8059',
        r'100%\s+ESPA[ÑN]OL\s+PURO'),
    MetaLeakRule('META_LEAK_LANGUAGE_CHECK', 'meta_f9dc94d77ed9',
        r'100%\s+PORTUGU[ÊE]S'),
    MetaLeakRule('META_LEAK_INTERNAL_PROMPT', 'meta_a46c33426d67',
        r'<instructions[^>]*>'),
    MetaLeakRule('META_LEAK_INTERNAL_PROMPT', 'meta_82dbb99cf0f9',
        r'</instructions\s*>'),
    MetaLeakRule('META_LEAK_INTERNAL_PROMPT', 'meta_70197f3253fe',
        r'<system_rules[^>]*>'),
    MetaLeakRule('META_LEAK_INTERNAL_PROMPT', 'meta_e502cd9f82ce',
        r'</system_rules\s*>'),
    MetaLeakRule('META_LEAK_INTERNAL_PROMPT', 'meta_217f62c81d3d',
        r'<response_template>'),
    MetaLeakRule('META_LEAK_INTERNAL_PROMPT', 'meta_32d6684f45a3',
        r'</response_template>'),
    MetaLeakRule(
        'META_LEAK_INTERNAL_PROMPT', 'meta_029329e15ce5', r'<context_rag>'),
    MetaLeakRule(
        'META_LEAK_INTERNAL_PROMPT', 'meta_a9ec4ee876e4', r'</context_rag>'),
    MetaLeakRule('META_LEAK_INTERNAL_PROMPT', 'meta_539fa341c8f6',
        r'OUTPUT_STARTS_HERE'),
    MetaLeakRule('META_LEAK_INTERNAL_PROMPT', 'meta_1f6f98cb2ff1',
        r'END_OF_INSTRUCTIONS'),
    MetaLeakRule(
        'META_LEAK_DEBUG_LABEL', 'meta_36b405a7e7b0', r'TEMA\s+DESTE\s+TURNO'),
    MetaLeakRule('META_LEAK_CLINICAL_CONTEXT_LABEL', 'meta_8f0bc377732f',
        r'CONTEXTO\s+CL[ÍI]NICO'),
    MetaLeakRule('META_LEAK_DEBUG_LABEL', 'meta_dcc037ba4ccc', r'COMPLEJIDAD'),
    MetaLeakRule('META_LEAK_INTERNAL_PROMPT', 'meta_67385cc5e082',
        r'COMPLEXIDADE\s+DETECTADA'),
    MetaLeakRule('META_LEAK_DEBUG_LABEL', 'meta_e14335fbf1e0',
        r'AUTORIDADE\s+DE\s+MATRIZ'),
    MetaLeakRule('META_LEAK_DEBUG_LABEL', 'meta_0075a44f0c24',
        r'HISTORY\s+POISON\s+GUARD'),
    MetaLeakRule(
        'META_LEAK_DEBUG_LABEL', 'meta_7fc19fa1ab0e', r'ANTI.LEAK\s+ABSOLUTO'),
    MetaLeakRule(
        'META_LEAK_DEBUG_LABEL', 'meta_4d2b0190497d', r'CAMADA\s+[A-Z]\s+—'),
    MetaLeakRule('META_LEAK_DEBUG_LABEL', 'meta_007c2fdac441', r'HARD\s+CAPS'),
    MetaLeakRule(
        'META_LEAK_DEBUG_LABEL', 'meta_80d932cc1281', r'BUILD\s+\d+\s+(—|:)'),
    MetaLeakRule(
        'META_LEAK_REASONING_HEADER', 'meta_6a1e77885196', r'^Vou\s+responder'),
    MetaLeakRule('META_LEAK_REASONING_HEADER', 'meta_99dc9c79364a',
        r'^Vamos\s+analisar'),
    MetaLeakRule(
        'META_LEAK_REASONING_HEADER', 'meta_7fbf1e361c92', r'^Segue\s+abaixo'),
    MetaLeakRule(
        'META_LEAK_REASONING_HEADER', 'meta_f8aee54db349', r'^Aqui\s+est[áa]'),
    MetaLeakRule('META_LEAK_REASONING_HEADER', 'meta_0760f28aa004',
        r'^Com\s+base\s+na\s+solicita[çc][ãa]o'),
    MetaLeakRule(
        'META_LEAK_REASONING_HEADER', 'meta_e3ab2844a2bb', r'^Resposta:'),
    MetaLeakRule(
        'META_LEAK_REASONING_HEADER', 'meta_9797f67428fb', r'^An[áa]lise:'),
    MetaLeakRule('META_LEAK_REASONING_HEADER', 'meta_35569190febe',
        r'^Explica[çc][ãa]o:'),
    MetaLeakRule(
        'META_LEAK_REASONING_HEADER', 'meta_022293b7e248', r'^Racioc[íi]nio'),
    MetaLeakRule(
        'META_LEAK_REASONING_HEADER', 'meta_8fd479e628a1', r'^Pensamento'),
    MetaLeakRule(
        'META_LEAK_REASONING_HEADER', 'meta_98ac70f86774', r'^Processando'),
    MetaLeakRule('META_LEAK_REASONING_HEADER', 'meta_2a4d8f15e12a',
        r'^Modo\s+Plant[ãa]o'),
    MetaLeakRule('META_LEAK_REASONING_HEADER', 'meta_81d762ce6ba1',
        r'^Formato\s+Plant[ãa]o'),
    MetaLeakRule(
        'META_LEAK_REASONING_HEADER', 'meta_0c5411453262', r'^Primeiro,'),
    MetaLeakRule(
        'META_LEAK_REASONING_HEADER', 'meta_b880c3b0342e', r'^Primeiro\s+vou'),
    MetaLeakRule(
        'META_LEAK_REASONING_HEADER', 'meta_c72078280a9d', r'^Primeiramente'),
    MetaLeakRule('META_LEAK_REASONING_HEADER', 'meta_37877c9107e4',
        r'^Voy\s+a\s+responder'),
    MetaLeakRule('META_LEAK_REASONING_HEADER', 'meta_3dbd17f89159',
        r'^Vamos\s+a\s+analizar'),
    MetaLeakRule('META_LEAK_REASONING_HEADER', 'meta_f13b7a2460ab',
        r'^Aqu[íi]\s+est[áa]'),
    MetaLeakRule('META_LEAK_REASONING_HEADER', 'meta_a0ee0f0f33cd',
        r'^Con\s+base\s+en\s+la\s+solicitud'),
    MetaLeakRule(
        'META_LEAK_REASONING_HEADER', 'meta_c3260b8ea38b', r'^Respuesta:'),
    MetaLeakRule(
        'META_LEAK_REASONING_HEADER', 'meta_cefa0817a7ee', r'^An[áa]lisis:'),
    MetaLeakRule(
        'META_LEAK_REASONING_HEADER', 'meta_89c289e5872b', r'^Explicaci[oó]n:'),
    MetaLeakRule(
        'META_LEAK_REASONING_HEADER', 'meta_16e31144235a', r'^Razonamiento'),
    MetaLeakRule(
        'META_LEAK_REASONING_HEADER', 'meta_5799878ecec8', r'^Pensamiento'),
    MetaLeakRule(
        'META_LEAK_REASONING_HEADER', 'meta_aff61d563ceb', r'^Procesando'),
    MetaLeakRule('META_LEAK_REASONING_HEADER', 'meta_da64b4990861',
        r'^Modo\s+Guard[íi]a'),
    MetaLeakRule('META_LEAK_REASONING_HEADER', 'meta_891dc7fd1c34',
        r'^Formato\s+Guard[íi]a'),
    MetaLeakRule(
        'META_LEAK_REASONING_HEADER', 'meta_d8bae3a764e4', r'^Primero,'),
    MetaLeakRule(
        'META_LEAK_REASONING_HEADER', 'meta_da27dac94bb2', r'^Let\s+me\s+'),
    MetaLeakRule(
        'META_LEAK_REASONING_HEADER', 'meta_c54c9055c31a', r'^I\s+will\s+'),
    MetaLeakRule('META_LEAK_REASONING_HEADER', 'meta_985af5edb935',
        r'^I\s+need\s+to\s+'),
    MetaLeakRule(
        'META_LEAK_REASONING_HEADER', 'meta_4aa96df1c3f3', r'^Here\s+is\s+'),
    MetaLeakRule(
        'META_LEAK_REASONING_HEADER', 'meta_b61969d5e675', r'^Here\s+are\s+'),
    MetaLeakRule('META_LEAK_REASONING_HEADER', 'meta_54d31294fd51',
        r'^Based\s+on\s+the\s+'),
    MetaLeakRule(
        'META_LEAK_REASONING_HEADER', 'meta_58674a362592', r'^Analysis:'),
    MetaLeakRule(
        'META_LEAK_REASONING_HEADER', 'meta_cab2ab3ea669', r'^Reasoning:'),
    MetaLeakRule(
        'META_LEAK_REASONING_HEADER', 'meta_60971e302d36', r'^Processing'),
  ];
  static final legacyPattern = RegExp(
      '(${rules.map((r) => r.pattern).join('|')})',
      caseSensitive: false,
      multiLine: true);
  // Only Study narrows the clinical phrase to an explicit internal label.
  // Plantão retains its pre-existing decisions.
  static const _contextLabel =
      r'^\s*(?:[-*>]\s*)?(?:\*\*)?(?:\[CONTEXTO\s+CL[ÍI]NICO\]|CONTEXTO\s+CL[ÍI]NICO(?:\*\*)?\s*[:=])';
  static String _pattern(MetaLeakRule rule, bool study) =>
      study && rule.ruleId == 'META_LEAK_CLINICAL_CONTEXT_LABEL'
          ? _contextLabel
          : rule.pattern;
  static final studyPattern = RegExp(
      '(${rules.map((r) => _pattern(r, true)).join('|')})',
      caseSensitive: false,
      multiLine: true);
  static RegExp pattern({bool study = false}) =>
      study ? studyPattern : legacyPattern;

  static MetaLeakRule? match(String line, {bool study = false}) {
    final first = pattern(study: study).firstMatch(line);
    if (first == null) return null;
    return rules.firstWhere((r) =>
        RegExp(_pattern(r, study), caseSensitive: false, multiLine: true)
            .matchAsPrefix(line, first.start) !=
        null);
  }

  static Map<String, Object?> metadata(MetaLeakRule rule, String line,
      {required int lineIndex, required String locale}) {
    final quantities = RegExp(
            r'(?<![\d.,])\d+(?:[.,]\d+)?(?:\s*[–-]\s*\d+(?:[.,]\d+)?)?\s*(?:mg|mcg|µg|g|kg|mL|L|UI|mEq|mmol|%|h|min)\b(?:/(?:kg|h|min|d|L))?',
            caseSensitive: false)
        .allMatches(line.replaceAll('**', ''))
        .map((m) => sha256
            .convert(utf8.encode(m[0]!
                .toLowerCase()
                .replaceAll(',', '.')
                .replaceAll(RegExp(r'\s+'), '')
                .replaceAll('–', '-')))
            .toString())
        .toList();
    return {
      'ruleId': rule.ruleId,
      'reasonCode': 'META_LEAK_LINE_REMOVED',
      'lineIndex': lineIndex,
      'patternId': rule.patternId,
      'containsNumericQuantity': quantities.isNotEmpty,
      'quantityHash': quantities,
      'lineLength': line.length,
      'locale': locale.startsWith('es') ? 'es' : 'pt'
    };
  }
}
