import '../../../data/evidence_database.dart';
import '../../../models/drug_model.dart';

/// Detecta evidência farmacológica associada ao texto final da IA.
///
/// Não acessa estado, contexto ou engines de navegação.
class DrugEvidenceDetector {
  DrugEvidenceDetector._();

  static final RegExp _pharmacologicalContextPattern = RegExp(
    r'\b(dosis|dose|administr|mg\/kg|mcg\/kg|infus[ií]on|bolo|IV|IM|SC|'
    r'ampollas?|comprimido|antibi[oó]tico|analgésico|sedaci[oó]n|'
    r'anticoagulante|vasopressor|broncodilatador)\b',
    caseSensitive: false,
  );

  static const List<String> _priorityDrugKeywords = [
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

  static DrugEvidenceModel? detect(String text) {
    if (!_pharmacologicalContextPattern.hasMatch(text)) {
      return null;
    }

    final normalizedText = text.toLowerCase();

    for (final keyword in _priorityDrugKeywords) {
      if (!normalizedText.contains(keyword)) {
        continue;
      }

      final evidence = getGlobalEvidence(keyword);
      if (evidence != null) {
        return evidence;
      }
    }

    return null;
  }
}
