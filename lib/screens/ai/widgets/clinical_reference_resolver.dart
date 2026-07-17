import '../../../data/evidence_database.dart';
import '../../../data/protocols_database.dart';
import '../../../models/drug_model.dart';
import '../../../models/protocol_model.dart';

class ClinicalReferenceData {
  final List<String> lines;
  final String sourceType;
  final String? protocolId;
  final List<String> drugKeys;

  const ClinicalReferenceData({
    required this.lines,
    required this.sourceType,
    this.protocolId,
    this.drugKeys = const [],
  });
}

/// Resolve referências clínicas sem acessar estado de UI ou Provider.
///
/// Hierarquia:
/// 1. Um único fármaco reconhecido → evidência específica do fármaco.
/// 2. Vários fármacos ou tema clínico → referências do protocolo correspondente.
/// 3. Sem correspondência segura → bibliografia clínica geral já adotada no app.
class ClinicalReferenceResolver {
  ClinicalReferenceResolver._();

  static final RegExp _pharmacologicalContextPattern = RegExp(
    r'\b(dosis|dose|administr|mg\/kg|mcg\/kg|infus[ií]on|bolo|iv|im|sc|'
    r'ampollas?|comprimido|antibi[oó]tico|analg[eé]sico|sedaci[oó]n|'
    r'anticoagulante|vasopressor|broncodilatador|farmacol[oó]gic)\b',
    caseSensitive: false,
  );

  static const List<String> _drugKeywords = [
    'adenosina',
    'amiodarona',
    'noradrenalina',
    'adrenalina',
    'epinefrina',
    'atropina',
    'morfina',
    'fentanil',
    'fentanilo',
    'ketamina',
    'midazolam',
    'propofol',
    'dexmedetomidina',
    'haloperidol',
    'metoprolol',
    'furosemida',
    'dobutamina',
    'dopamina',
    'vasopresina',
    'nitroglicerina',
    'heparina',
    'enoxaparina',
    'rivaroxabana',
    'varfarina',
    'clopidogrel',
    'salbutamol',
    'dexametasona',
    'insulina',
    'metformina',
    'omeprazol',
    'ondansetrona',
    'enalapril',
    'losartana',
    'paracetamol',
    'ibuprofeno',
    'tramadol',
    'naloxona',
    'succinilcolina',
    'ceftriaxona',
    'vancomicina',
    'meropenem',
    'piperacilina',
    'fluconazol',
    'aciclovir',
    'sulfato de magnesio',
    'ácido tranexámico',
    'levetiracetam',
    'fenitoína',
    'clonazepam',
  ];

  static ClinicalReferenceData resolve({
    required String userText,
    required String aiText,
    required String lang,
  }) {
    final isEs = lang == 'es';
    final drugs = _detectDrugs(aiText);

    if (drugs.length == 1) {
      final ev = drugs.single;
      return ClinicalReferenceData(
        sourceType: 'single_drug',
        drugKeys: [ev.drugKey],
        lines: [
          isEs ? 'Fármaco: ${ev.displayName}' : 'Fármaco: ${ev.displayName}',
          isEs
              ? 'Fuente principal: ${ev.primarySource}'
              : 'Fonte principal: ${ev.primarySource}',
          isEs
              ? 'Directriz: ${ev.guidelineSource}'
              : 'Diretriz: ${ev.guidelineSource}',
          isEs
              ? 'Nivel de evidencia: ${ev.evidenceLevel} — ${ev.recommendation}'
              : 'Nível de evidência: ${ev.evidenceLevel} — ${ev.recommendation}',
          isEs
              ? 'Revisado en: ${ev.lastReviewed}'
              : 'Revisado em: ${ev.lastReviewed}',
          isEs
              ? 'Observación: confirmar contraindicaciones, función renal y ajuste individual.'
              : 'Observação: confirmar contraindicações, função renal e ajuste individual.',
        ],
      );
    }

    final protocol = _matchProtocol(userText, aiText);
    if (protocol != null) {
      final references = protocol.getList(protocol.references, lang);
      final title = protocol.getField(protocol.title, lang);
      final lines = <String>[
        isEs ? 'Tema clínico: $title' : 'Tema clínico: $title',
      ];

      if (references.isNotEmpty) {
        lines.add(
          isEs
              ? 'Directriz principal: ${references.first}'
              : 'Diretriz principal: ${references.first}',
        );
      }
      if (references.length > 1) {
        lines.add(
          isEs
              ? 'Referencia complementaria: ${references[1]}'
              : 'Referência complementar: ${references[1]}',
        );
      }

      lines.addAll([
        isEs
            ? 'Farmacología: Goodman & Gilman, 14.ª ed.'
            : 'Farmacologia: Goodman & Gilman, 14ª ed.',
        isEs
            ? 'Medicina interna: Harrison, 21.ª ed.'
            : 'Medicina interna: Harrison, 21ª ed.',
        isEs
            ? 'Observación: confirmar contraindicaciones, interacciones y protocolo institucional.'
            : 'Observação: confirmar contraindicações, interações e protocolo institucional.',
      ]);

      return ClinicalReferenceData(
        sourceType:
            drugs.length > 1 ? 'polypharmacy_protocol' : 'clinical_protocol',
        protocolId: protocol.id,
        drugKeys: drugs.map((e) => e.drugKey).toList(growable: false),
        lines: lines,
      );
    }

    return ClinicalReferenceData(
      sourceType:
          drugs.length > 1 ? 'polypharmacy_fallback' : 'general_fallback',
      drugKeys: drugs.map((e) => e.drugKey).toList(growable: false),
      lines: [
        isEs
            ? 'Medicina interna: Harrison, 21.ª ed.'
            : 'Medicina interna: Harrison, 21ª ed.',
        isEs
            ? 'Farmacología: Goodman & Gilman, 14.ª ed.'
            : 'Farmacologia: Goodman & Gilman, 14ª ed.',
        'Actualización clínica: UpToDate',
        isEs
            ? 'Observación: confirmar directrices de la especialidad y protocolo institucional.'
            : 'Observação: confirmar diretrizes da especialidade e protocolo institucional.',
      ],
    );
  }

  static List<DrugEvidenceModel> _detectDrugs(String text) {
    if (!_pharmacologicalContextPattern.hasMatch(text)) {
      return const [];
    }

    final normalized = _normalize(text);
    final found = <String, DrugEvidenceModel>{};

    for (final keyword in _drugKeywords) {
      if (!normalized.contains(_normalize(keyword))) continue;
      final evidence = getGlobalEvidence(keyword);
      if (evidence != null) {
        found[evidence.drugKey] = evidence;
      }
    }

    return found.values.toList(growable: false);
  }

  static ProtocolModel? _matchProtocol(String userText, String aiText) {
    final query = _normalize(userText);
    final responseHead = _normalize(
      aiText.length > 280 ? aiText.substring(0, 280) : aiText,
    );

    final terms = query
        .split(RegExp(r'\s+'))
        .where((term) => term.length >= 2)
        .where((term) => !_stopWords.contains(term))
        .toSet();

    ProtocolModel? best;
    var bestScore = 0;

    for (final protocol in protocolsDatabase) {
      final id = _normalize(protocol.id.replaceAll('_', ' '));
      final title = _normalize(
        '${protocol.title['pt'] ?? ''} ${protocol.title['es'] ?? ''}',
      );

      var score = 0;
      for (final term in terms) {
        if (id.contains(term)) score += 5;
        if (title.contains(term)) score += 4;
      }

      if (query.isNotEmpty && (id.contains(query) || title.contains(query))) {
        score += 8;
      }

      final titleTerms = title
          .split(RegExp(r'\s+'))
          .where((term) => term.length >= 3)
          .where((term) => !_stopWords.contains(term));
      for (final term in titleTerms) {
        if (responseHead.contains(term)) score += 1;
      }

      if (score > bestScore) {
        bestScore = score;
        best = protocol;
      }
    }

    return bestScore >= 4 ? best : null;
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('â', 'a')
      .replaceAll('é', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ç', 'c')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static const Set<String> _stopWords = {
    'a',
    'o',
    'e',
    'de',
    'da',
    'do',
    'das',
    'dos',
    'em',
    'com',
    'para',
    'por',
    'um',
    'uma',
    'el',
    'la',
    'los',
    'las',
    'del',
    'en',
    'con',
    'que',
    'como',
    'qual',
    'cuál',
  };
}
