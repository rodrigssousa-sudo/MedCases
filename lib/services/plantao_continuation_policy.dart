import 'ai_next_action_engine.dart';
import 'ai_pipeline/plantao/contracts/plantao_continuation_type.dart';
import 'ai_pipeline/plantao/contracts/plantao_section.dart';

/// Conservative UX policy for Plantão continuation.
///
/// The canonical NextActionEngine remains the first owner. This layer never
/// changes clinical truth and never calls network/provider/Firestore. It only
/// removes filler/repeated generic continuations and points to an unanswered
/// follow-up dimension already supported by the typed continuation contract.
final class PlantaoContinuationPolicy {
  const PlantaoContinuationPolicy._();

  static const SmartNextAction _empty = SmartNextAction(
    label: '',
    promptToSend: '',
  );

  static SmartNextAction resolve({
    required SmartNextAction baseAction,
    required String lastUserMessage,
    required String lastAiResponse,
    required List<String> chatHistory,
    required String languageCode,
  }) {
    final es = languageCode.trim().toLowerCase().startsWith('es');
    final hasBaseAction =
        baseAction.label.trim().isNotEmpty &&
        baseAction.promptToSend.trim().isNotEmpty;

    final label = hasBaseAction ? _fold(baseAction.label) : '';
    final genericTreatment =
        hasBaseAction &&
        (label == 'conductas y dosis' || label == 'condutas e dosagens');
    final genericEvolution =
        hasBaseAction &&
        (label == 'estudios y evolucion' || label == 'exames e evolucao');

    final visible = _fold(lastAiResponse);

    if (_terminalDispositionCovered(visible)) {
      return _empty;
    }

    if (hasBaseAction && !genericTreatment && !genericEvolution) {
      return _alreadyCoveredAction(
            baseAction,
            lastUserMessage: lastUserMessage,
            chatHistory: chatHistory,
          )
          ? _empty
          : baseAction;
    }
    final historicalVisible = _fold(chatHistory.join('\n'));

    final management = _managementCovered(visible);
    final reassessment = _reassessmentCovered(visible);
    final monitoring = _monitoringCovered(visible);
    final worsening = _worseningCovered(visible);
    final disposition = _dispositionCovered(visible);
    final exams = _examsCovered(visible);

    final historicalManagement = _managementCovered(historicalVisible);
    final historicalReassessment = _reassessmentCovered(historicalVisible);
    final historicalMonitoring = _monitoringCovered(historicalVisible);
    final historicalWorsening = _worseningCovered(historicalVisible);

    final hasClinicalProgress =
        management ||
        reassessment ||
        monitoring ||
        worsening ||
        disposition ||
        exams;

    if (!hasBaseAction && !hasClinicalProgress) {
      return _empty;
    }

    final completeAcrossRecentThread =
        disposition &&
        (management || historicalManagement) &&
        (reassessment || historicalReassessment) &&
        (monitoring || historicalMonitoring) &&
        (worsening || historicalWorsening);

    if (completeAcrossRecentThread) {
      return _empty;
    }

    if (management && reassessment && monitoring && worsening && disposition) {
      return _empty;
    }

    if (hasBaseAction && genericTreatment && !management) {
      return _alreadyCoveredAction(
            baseAction,
            lastUserMessage: lastUserMessage,
            chatHistory: chatHistory,
          )
          ? _empty
          : baseAction;
    }

    if (hasBaseAction && genericEvolution && !exams && !monitoring) {
      return _alreadyCoveredAction(
            baseAction,
            lastUserMessage: lastUserMessage,
            chatHistory: chatHistory,
          )
          ? _empty
          : baseAction;
    }

    final candidates = <SmartNextAction>[
      if (management && !reassessment)
        SmartNextAction(
          label: es ? 'Reevaluar respuesta' : 'Reavaliar resposta',
          promptToSend: es
              ? '¿Qué respuesta clínica debo reevaluar tras las intervenciones ya realizadas?'
              : 'Que resposta clínica devo reavaliar após as intervenções já realizadas?',
          continuationType: PlantaoContinuationType.examsEvolution,
          requestedSections: const <PlantaoSection>[
            PlantaoSection.responseCriteria,
            PlantaoSection.evolution,
          ],
        ),
      if (!monitoring)
        SmartNextAction(
          label: es ? 'Vigilar evolución' : 'Acompanhar evolução',
          promptToSend: es
              ? '¿Qué parámetros debo vigilar ahora y qué cambios indican mala evolución?'
              : 'Quais parâmetros devo acompanhar agora e quais mudanças indicam piora?',
          continuationType: PlantaoContinuationType.examsEvolution,
          requestedSections: const <PlantaoSection>[
            PlantaoSection.monitoring,
            PlantaoSection.evolution,
          ],
        ),
      // MEDCASES_PLANTAO_DESTINATION_PRIORITY_AFTER_COMPLETE_ACUTE_CORE_V1_B_R0
      // Exames genéricos não competem com o único gap ainda decisório quando
      // manejo, reavaliação, monitorização e piora/escalonamento já existem.
      if (management && reassessment && monitoring && worsening && !disposition)
        SmartNextAction(
          label: 'Definir destino',
          promptToSend: es
              ? '¿Qué criterios definen observación, ingreso, UCI o alta en este caso?'
              : 'Quais critérios definem observação, internação, UTI ou alta neste caso?',
          continuationType: PlantaoContinuationType.prognosisDisposition,
          requestedSections: const <PlantaoSection>[
            PlantaoSection.disposition,
            PlantaoSection.evolution,
            PlantaoSection.worseningCriteria,
          ],
        ),
      if (genericEvolution && !exams)
        SmartNextAction(
          label: es ? 'Completar estudios' : 'Completar exames',
          promptToSend: es
              ? '¿Qué estudios complementarios todavía aportan información útil en este caso, sin repetir lo ya realizado?'
              : 'Quais exames complementares ainda acrescentam informação útil neste caso, sem repetir o que já foi realizado?',
          continuationType: PlantaoContinuationType.examsEvolution,
          requestedSections: const <PlantaoSection>[PlantaoSection.exams],
        ),
      if (!worsening)
        SmartNextAction(
          label: es ? 'Si no responde' : 'Se não responder',
          promptToSend: es
              ? '¿Qué hacer si no responde y qué criterios obligan a escalar?'
              : 'O que fazer se não responder e quais critérios exigem escalonamento?',
          continuationType: PlantaoContinuationType.examsEvolution,
          requestedSections: const <PlantaoSection>[
            PlantaoSection.responseCriteria,
            PlantaoSection.worseningCriteria,
            PlantaoSection.evolution,
          ],
        ),
      if (!disposition)
        SmartNextAction(
          label: 'Definir destino',
          promptToSend: es
              ? '¿Qué criterios definen observación, ingreso, UCI o alta en este caso?'
              : 'Quais critérios definem observação, internação, UTI ou alta neste caso?',
          continuationType: PlantaoContinuationType.prognosisDisposition,
          requestedSections: const <PlantaoSection>[
            PlantaoSection.disposition,
            PlantaoSection.evolution,
            PlantaoSection.worseningCriteria,
          ],
        ),
    ];

    for (final candidate in candidates) {
      if (!_alreadyCoveredAction(
        candidate,
        lastUserMessage: lastUserMessage,
        chatHistory: chatHistory,
      )) {
        return candidate;
      }
    }

    return _empty;
  }

  static bool _managementCovered(String text) {
    final heading = _hasAny(text, const <String>[
      'conducta inmediata',
      'conduta imediata',
      'tratamiento farmacologico',
      'tratamento farmacologico',
      'manejo inmediato',
      'manejo inicial',
    ]);
    final executable = _hasAny(text, const <String>[
      'primera linea',
      'primeira linha',
      'mg/kg',
      ' mg ',
      ' dosis ',
      ' dose ',
      'administrar',
      'acceso iv',
      'acesso iv',
    ]);
    return heading && executable;
  }

  static bool _reassessmentCovered(String text) => _hasAny(text, const <String>[
    'reevaluar',
    'reavaliar',
    'reevaluacion',
    'reavaliacao',
    'respuesta clinica',
    'resposta clinica',
    'despues de cada intervencion',
    'apos cada intervencao',
  ]);

  static bool _monitoringCovered(String text) => _hasAny(text, const <String>[
    'monitorizacion',
    'monitorizacao',
    'monitoracao',
    'monitoreo',
    'observar hasta',
    'observar ate',
    'vigilar',
    'spo2',
    'saturacion',
    'saturacao',
  ]);

  static bool _worseningCovered(String text) => _hasAny(text, const <String>[
    'red flags',
    'escalamiento',
    'escalonamento',
    'criterios de escal',
    ' uci',
    ' uti',
    'shock',
    'refractar',
    'deterioro',
    'piora',
    'hipoxemia',
    'obstruccion de via aerea',
    'obstrucao de via aerea',
  ]);

  // M65_POST_EXPLICIT_DESTINATION_TERMINAL_V1
  // Strict terminal closure for automatic continuation UX.
  //
  // Complete destination may arrive as an explicit Destino/Disposición owner
  // with admission + discharge, or as the physical four-way criteria contract:
  // Observación + Ingreso/Internación + UCI/UTI + Alta.
  //
  // Isolated UCI escalation, monitoring-only "observar hasta..." language, and
  // a lone admission/discharge mention are intentionally non-terminal.
  static bool _terminalDispositionCovered(String text) {
    final hasExplicitDestinationOwner = _hasAny(text, const <String>[
      'destino del paciente',
      'destino do paciente',
      'disposicion del paciente',
      'disposicao do paciente',
      'destino:',
      'disposicion:',
      'disposicao:',
    ]);

    final hasFourWayCriteriaLead = _hasAny(text, const <String>[
      'criterios para observacion',
      'criterios de observacion',
      'criterios para observacao',
      'criterios de observacao',
    ]);

    final hasObservation =
        text.contains('observacion') || text.contains('observacao');
    final hasAdmission =
        text.contains('ingreso') ||
        text.contains('internacion') ||
        text.contains('internacao');
    final hasCriticalCare =
        text.contains(' uci') ||
        text.startsWith('uci') ||
        text.contains(' uti') ||
        text.startsWith('uti');
    final hasDischarge = text.contains('alta');

    final explicitOwnedPlan =
        hasExplicitDestinationOwner && hasAdmission && hasDischarge;
    final completeFourWayPlan =
        hasFourWayCriteriaLead &&
        hasObservation &&
        hasAdmission &&
        hasCriticalCare &&
        hasDischarge;

    return explicitOwnedPlan || completeFourWayPlan;
  }

  static bool _dispositionCovered(String text) {
    // Monitoring language such as "observar hasta la resolución" is NOT a
    // destination plan. Escalation to UCI is also not disposition by itself.
    return _hasAny(text, const <String>[
      'destino:',
      'destino del paciente',
      'destino do paciente',
      'disposicion:',
      'disposicao:',
      'criterios de alta',
      'criterios para el alta',
      'criterios para alta',
      'alta hospitalaria',
      'alta solo',
      'alta si',
      'alta apenas',
      'alta somente',
      'criterios de ingreso',
      'criterios para ingreso',
      'indicacion de ingreso',
      'indicar ingreso',
      'ingreso hospitalario',
      'requiere ingreso',
      'internacion',
      'internacao',
      'hospitalizar',
      'hospitalizacion si',
      'hospitalizacao se',
    ]);
  }

  static bool _examsCovered(String text) => _hasAny(text, const <String>[
    'examenes',
    'exames',
    'laboratorio',
    'imagen',
    'imagem',
    'ecg',
    'troponina',
    'gasometria',
    'tomografia',
    'ecografia',
    'ultrassom',
  ]);

  static bool _hasAny(String text, List<String> markers) =>
      markers.any(text.contains);

  static bool _alreadyCoveredAction(
    SmartNextAction action, {
    required String lastUserMessage,
    required List<String> chatHistory,
  }) {
    final candidates = <String>[lastUserMessage, ...chatHistory];
    final promptFolded = _fold(action.promptToSend);
    final labelFolded = _fold(action.label);
    final promptTokens = _tokens(action.promptToSend);
    final labelTokens = _tokens(action.label);

    for (final item in candidates) {
      final foldedItem = _fold(item);
      if (foldedItem.isEmpty) continue;
      if (promptFolded.isNotEmpty &&
          (foldedItem.contains(promptFolded) ||
              (foldedItem.length >= 24 && promptFolded.contains(foldedItem)))) {
        return true;
      }
      if (labelFolded.length >= 8 && foldedItem.contains(labelFolded)) {
        return true;
      }
      final other = _tokens(item);
      if (_overlap(promptTokens, other) >= 0.70) return true;
      if (labelTokens.length >= 2 && _overlap(labelTokens, other) >= 0.80) {
        return true;
      }
    }
    return false;
  }

  static double _overlap(Set<String> a, Set<String> b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final intersection = a.intersection(b).length;
    final union = a.union(b).length;
    return union == 0 ? 0 : intersection / union;
  }

  static const Set<String> _stop = <String>{
    'este',
    'esta',
    'caso',
    'debo',
    'deve',
    'quais',
    'cuales',
    'qual',
    'cual',
    'para',
    'como',
    'apos',
    'tras',
    'ahora',
    'agora',
    'clinica',
    'clinico',
    'clinicos',
    'realizadas',
    'realizados',
    'hacer',
    'fazer',
    'neste',
    'nesse',
  };

  static Set<String> _tokens(String value) => _fold(value)
      .split(RegExp(r'[^a-z0-9]+'))
      .where((token) => token.length >= 4 && !_stop.contains(token))
      .toSet();

  static String _fold(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[áàâãä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[íìîï]'), 'i')
      .replaceAll(RegExp(r'[óòôõö]'), 'o')
      .replaceAll(RegExp(r'[úùûü]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll('ñ', 'n')
      .replaceAll('¿', '')
      .replaceAll('¡', '')
      .replaceAll(RegExp(r'\s+'), ' ');
}
