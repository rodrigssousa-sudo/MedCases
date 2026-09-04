import 'plantao_drug_original_input_identity_extractor.dart';

class PlantaoDrugOriginalInputIntentResolver {
  const PlantaoDrugOriginalInputIntentResolver();

  PlantaoDrugOriginalInputIntent resolve({
    required String originalUserInput,
    required String legacyQueryIntent,
    required bool legacyDirectQuery,
  }) {
    final normalized =
        PlantaoDrugOriginalInputIdentityExtractor.normalizeForBoundary(
          originalUserInput,
        );
    if (normalized.isEmpty) return PlantaoDrugOriginalInputIntent.none;

    final padded = ' $normalized ';
    if (legacyQueryIntent == 'interacao' ||
        _containsAny(padded, const <String>[
          ' interacao ',
          ' interaccion ',
          ' interage ',
          ' interactua ',
          ' junto com ',
          ' combinacao ',
          ' combinacion ',
          ' compatibilidade ',
          ' compatibilidad ',
          ' associar ',
          ' asociar ',
        ])) {
      return PlantaoDrugOriginalInputIntent.interaction;
    }

    if (_containsAny(padded, const <String>[
      ' diluicao ',
      ' dilucion ',
      ' diluir ',
      ' reconstituicao ',
      ' reconstitucion ',
      ' reconstituir ',
      ' reconstituir ',
      ' solvente ',
    ])) {
      return PlantaoDrugOriginalInputIntent.dilution;
    }

    if (_containsAny(padded, const <String>[
      ' infusao ',
      ' infusion ',
      ' bomba de infusao ',
      ' bomba de infusion ',
      ' velocidade de infusao ',
      ' velocidad de infusion ',
      ' gotejamento ',
      ' goteo ',
      ' gotas por minuto ',
    ])) {
      return PlantaoDrugOriginalInputIntent.infusion;
    }

    if (_containsAny(padded, const <String>[
      ' dose ',
      ' dosagem ',
      ' dosificacion ',
      ' dosis ',
      ' posologia ',
      ' mg kg ',
      ' mcg kg ',
      ' intervalo de administracao ',
      ' intervalo de administracion ',
    ])) {
      return PlantaoDrugOriginalInputIntent.dosage;
    }

    if (legacyQueryIntent == 'farmaco' ||
        legacyQueryIntent == 'psicofarmaco' ||
        _containsAny(padded, const <String>[
          ' farmaco ',
          ' medicamento ',
          ' remedio ',
          ' bula ',
          ' prospecto ',
          ' efeito adverso ',
          ' efeitos adversos ',
          ' efecto adverso ',
          ' efectos adversos ',
          ' contraindicacao ',
          ' contraindicacion ',
          ' indicacao ',
          ' indicacion ',
          ' mecanismo de acao ',
          ' mecanismo de accion ',
          ' ajuste renal ',
          ' ajuste hepatico ',
        ])) {
      return PlantaoDrugOriginalInputIntent.drugInformation;
    }

    final tokens = normalized.split(' ');
    final singleCanonicalCandidate =
        tokens.length == 1 && normalized.length >= 3 && normalized.length <= 64;
    final shortDirectCandidate =
        legacyDirectQuery && tokens.length <= 4 && normalized.length <= 96;

    if (singleCanonicalCandidate || shortDirectCandidate) {
      return PlantaoDrugOriginalInputIntent.drugInformation;
    }

    return PlantaoDrugOriginalInputIntent.none;
  }

  static bool _containsAny(String padded, Iterable<String> needles) {
    for (final needle in needles) {
      if (padded.contains(needle)) return true;
    }
    return false;
  }
}
