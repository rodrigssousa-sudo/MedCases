/// Contrato canônico tipado das estruturas de resposta do modo Plantão.
///
/// V1 shadow:
/// - não participa ainda do roteamento produtivo;
/// - não substitui as matrizes legadas;
/// - não altera provider, parser ou renderer;
/// - não contém emojis;
/// - idioma muda apenas labels/templates, nunca o model id.
enum PlantaoResponseModelId {
  casoClinicoEmergencia,
  efeitosAdversosMedicamentosos,
  infusaoTitulacaoDesmame,
  arritmia,
  disturbioEletrolitico,
  gasometriaAcidoBase,
  antibioticoterapia,
  sepseChoqueSeptico,
  intoxicacaoExogena,
  trauma,
  avc,
  dorToracicaAguda,
  dispneiaAguda,
  paradaCardiorrespiratoria,
  choque,
  viaAereaVentilacaoMecanica,
  lesaoRenalAguda,
  hemorragia,
  criseHipertensiva,
  alteracaoLaboratorialCalculoClinico,
  consultaClinicaGeral,
  farmacoIsolado,
}

extension PlantaoResponseModelIdWireName on PlantaoResponseModelId {
  String get wireName => switch (this) {
        PlantaoResponseModelId.casoClinicoEmergencia =>
          'caso_clinico_emergencia',
        PlantaoResponseModelId.efeitosAdversosMedicamentosos =>
          'efeitos_adversos_medicamentosos',
        PlantaoResponseModelId.infusaoTitulacaoDesmame =>
          'infusao_titulacao_desmame',
        PlantaoResponseModelId.arritmia => 'arritmia',
        PlantaoResponseModelId.disturbioEletrolitico =>
          'disturbio_eletrolitico',
        PlantaoResponseModelId.gasometriaAcidoBase => 'gasometria_acido_base',
        PlantaoResponseModelId.antibioticoterapia => 'antibioticoterapia',
        PlantaoResponseModelId.sepseChoqueSeptico => 'sepse_choque_septico',
        PlantaoResponseModelId.intoxicacaoExogena => 'intoxicacao_exogena',
        PlantaoResponseModelId.trauma => 'trauma',
        PlantaoResponseModelId.avc => 'avc',
        PlantaoResponseModelId.dorToracicaAguda => 'dor_toracica_aguda',
        PlantaoResponseModelId.dispneiaAguda => 'dispneia_aguda',
        PlantaoResponseModelId.paradaCardiorrespiratoria =>
          'parada_cardiorrespiratoria',
        PlantaoResponseModelId.choque => 'choque',
        PlantaoResponseModelId.viaAereaVentilacaoMecanica =>
          'via_aerea_ventilacao_mecanica',
        PlantaoResponseModelId.lesaoRenalAguda => 'lesao_renal_aguda',
        PlantaoResponseModelId.hemorragia => 'hemorragia',
        PlantaoResponseModelId.criseHipertensiva => 'crise_hipertensiva',
        PlantaoResponseModelId.alteracaoLaboratorialCalculoClinico =>
          'alteracao_laboratorial_calculo_clinico',
        PlantaoResponseModelId.consultaClinicaGeral => 'consulta_clinica_geral',
        PlantaoResponseModelId.farmacoIsolado => 'farmaco_isolado',
      };
}

class PlantaoLocalizedText {
  final String pt;
  final String es;

  const PlantaoLocalizedText({
    required this.pt,
    required this.es,
  });

  String forLanguage(String languageCode) =>
      languageCode.toLowerCase() == 'es' ? es : pt;
}

class PlantaoResponseSectionContract {
  /// Chave estrutural estável, independente do idioma.
  final String key;

  /// Label visual/localizada da seção.
  final PlantaoLocalizedText label;

  const PlantaoResponseSectionContract({
    required this.key,
    required this.label,
  });
}

class PlantaoResponseContract {
  final PlantaoResponseModelId id;

  /// Ponte temporária com a matriz produtiva histórica.
  ///
  /// Existe apenas para shadow/equivalence. Não deve ser o identificador
  /// canônico da nova arquitetura.
  final int legacyMatrixNumber;

  /// Template semântico do título, sem decoração visual.
  final PlantaoLocalizedText titleTemplate;

  /// Ordem canônica das seções deste modelo.
  ///
  /// V1 não declara required/optional. Essa decisão fica para uma fase
  /// posterior, após equivalência estrutural e revisão do conteúdo.
  final List<PlantaoResponseSectionContract> sections;

  const PlantaoResponseContract({
    required this.id,
    required this.legacyMatrixNumber,
    required this.titleTemplate,
    required this.sections,
  });
}

abstract final class PlantaoResponseContractRegistry {
  static const contracts = <PlantaoResponseContract>[
    PlantaoResponseContract(
      id: PlantaoResponseModelId.casoClinicoEmergencia,
      legacyMatrixNumber: 1,
      titleTemplate: PlantaoLocalizedText(
        pt: '[NOME CLÍNICO ESPECÍFICO — máximo 5 palavras]',
        es: '[NOMBRE CLÍNICO ESPECÍFICO — máximo 5 palabras]',
      ),
      sections: [
        PlantaoResponseSectionContract(
          key: 'conduta_imediata',
          label: PlantaoLocalizedText(
            pt: 'Conduta imediata',
            es: 'Conducta inmediata',
          ),
        ),
        PlantaoResponseSectionContract(
          key: 'farmacologia',
          label: PlantaoLocalizedText(
            pt: 'Farmacologia',
            es: 'Farmacología',
          ),
        ),
        PlantaoResponseSectionContract(
          key: 'limite_critico',
          label: PlantaoLocalizedText(
            pt: 'Limite crítico',
            es: 'Límite crítico',
          ),
        ),
        PlantaoResponseSectionContract(
          key: 'proximo_passo',
          label: PlantaoLocalizedText(
            pt: 'Próximo passo',
            es: 'Próximo paso',
          ),
        ),
      ],
    ),
    PlantaoResponseContract(
      id: PlantaoResponseModelId.efeitosAdversosMedicamentosos,
      legacyMatrixNumber: 2,
      titleTemplate: PlantaoLocalizedText(
        pt: 'TOXICIDADE — [FÁRMACO]',
        es: 'TOXICIDAD — [FÁRMACO]',
      ),
      sections: [
        PlantaoResponseSectionContract(
          key: 'reacoes_frequentes',
          label: PlantaoLocalizedText(
            pt: 'Reações frequentes',
            es: 'Reacciones frecuentes',
          ),
        ),
        PlantaoResponseSectionContract(
          key: 'sinal_gravidade',
          label: PlantaoLocalizedText(
            pt: 'Sinal de gravidade',
            es: 'Signo de gravedad',
          ),
        ),
        PlantaoResponseSectionContract(
          key: 'manejo',
          label: PlantaoLocalizedText(pt: 'Manejo', es: 'Manejo'),
        ),
        PlantaoResponseSectionContract(
          key: 'interacao_critica',
          label: PlantaoLocalizedText(
            pt: 'Interação crítica',
            es: 'Interacción crítica',
          ),
        ),
      ],
    ),
    PlantaoResponseContract(
      id: PlantaoResponseModelId.infusaoTitulacaoDesmame,
      legacyMatrixNumber: 3,
      titleTemplate: PlantaoLocalizedText(
        pt: 'INFUSÃO — [FÁRMACO]',
        es: 'INFUSIÓN — [FÁRMACO]',
      ),
      sections: [
        PlantaoResponseSectionContract(
          key: 'diluicao',
          label: PlantaoLocalizedText(pt: 'Diluição', es: 'Dilución'),
        ),
        PlantaoResponseSectionContract(
          key: 'dose_inicial',
          label: PlantaoLocalizedText(
            pt: 'Dose inicial',
            es: 'Dosis inicial',
          ),
        ),
        PlantaoResponseSectionContract(
          key: 'alvo',
          label: PlantaoLocalizedText(pt: 'Alvo', es: 'Objetivo'),
        ),
        PlantaoResponseSectionContract(
          key: 'desmame',
          label: PlantaoLocalizedText(pt: 'Desmame', es: 'Retirada'),
        ),
      ],
    ),
    PlantaoResponseContract(
      id: PlantaoResponseModelId.arritmia,
      legacyMatrixNumber: 4,
      titleTemplate: PlantaoLocalizedText(
        pt: 'ARRITMIA — [NOME]',
        es: 'ARRITMIA — [NOMBRE]',
      ),
      sections: [
        PlantaoResponseSectionContract(
          key: 'estabilidade',
          label: PlantaoLocalizedText(pt: 'Estabilidade', es: 'Estabilidad'),
        ),
        PlantaoResponseSectionContract(
          key: 'conduta',
          label: PlantaoLocalizedText(pt: 'Conduta', es: 'Conducta'),
        ),
        PlantaoResponseSectionContract(
          key: 'farmacologia',
          label: PlantaoLocalizedText(
            pt: 'Farmacologia',
            es: 'Farmacología',
          ),
        ),
        PlantaoResponseSectionContract(
          key: 'nao_fazer',
          label: PlantaoLocalizedText(pt: 'Não fazer', es: 'No hacer'),
        ),
        PlantaoResponseSectionContract(
          key: 'proximo_passo',
          label: PlantaoLocalizedText(
            pt: 'Próximo passo',
            es: 'Próximo paso',
          ),
        ),
      ],
    ),
    PlantaoResponseContract(
      id: PlantaoResponseModelId.disturbioEletrolitico,
      legacyMatrixNumber: 5,
      titleTemplate: PlantaoLocalizedText(
        pt: '[DISTÚRBIO ELETROLÍTICO] — [GRAVIDADE]',
        es: '[TRASTORNO ELECTROLÍTICO] — [GRAVEDAD]',
      ),
      sections: [
        PlantaoResponseSectionContract(
          key: 'valor_critico',
          label: PlantaoLocalizedText(
            pt: 'Valor crítico',
            es: 'Valor crítico',
          ),
        ),
        PlantaoResponseSectionContract(
          key: 'conduta',
          label: PlantaoLocalizedText(pt: 'Conduta', es: 'Conducta'),
        ),
        PlantaoResponseSectionContract(
          key: 'correcao',
          label: PlantaoLocalizedText(pt: 'Correção', es: 'Corrección'),
        ),
        PlantaoResponseSectionContract(
          key: 'monitorizacao',
          label: PlantaoLocalizedText(
            pt: 'Monitorização',
            es: 'Monitorización',
          ),
        ),
      ],
    ),
    PlantaoResponseContract(
      id: PlantaoResponseModelId.gasometriaAcidoBase,
      legacyMatrixNumber: 6,
      titleTemplate: PlantaoLocalizedText(
        pt: '[DISTÚRBIO ÁCIDO-BASE]',
        es: '[TRASTORNO ÁCIDO-BASE]',
      ),
      sections: [
        PlantaoResponseSectionContract(
          key: 'padrao',
          label: PlantaoLocalizedText(pt: 'Padrão', es: 'Patrón'),
        ),
        PlantaoResponseSectionContract(
          key: 'compensacao_esperada',
          label: PlantaoLocalizedText(
            pt: 'Compensação esperada',
            es: 'Compensación esperada',
          ),
        ),
        PlantaoResponseSectionContract(
          key: 'conduta',
          label: PlantaoLocalizedText(pt: 'Conduta', es: 'Conducta'),
        ),
        PlantaoResponseSectionContract(
          key: 'erro_comum',
          label: PlantaoLocalizedText(pt: 'Erro comum', es: 'Error común'),
        ),
        PlantaoResponseSectionContract(
          key: 'proximo_passo',
          label: PlantaoLocalizedText(
            pt: 'Próximo passo',
            es: 'Próximo paso',
          ),
        ),
      ],
    ),
    PlantaoResponseContract(
      id: PlantaoResponseModelId.antibioticoterapia,
      legacyMatrixNumber: 7,
      titleTemplate: PlantaoLocalizedText(
        pt: 'ANTIBIÓTICO — [NOME]',
        es: 'ANTIBIÓTICO — [NOMBRE]',
      ),
      sections: [
        PlantaoResponseSectionContract(
          key: 'cobertura',
          label: PlantaoLocalizedText(pt: 'Cobertura', es: 'Cobertura'),
        ),
        PlantaoResponseSectionContract(
          key: 'dose',
          label: PlantaoLocalizedText(pt: 'Dose', es: 'Dosis'),
        ),
        PlantaoResponseSectionContract(
          key: 'contraindicacoes',
          label: PlantaoLocalizedText(
            pt: 'Contraindicações',
            es: 'Contraindicaciones',
          ),
        ),
        PlantaoResponseSectionContract(
          key: 'proximo_passo',
          label: PlantaoLocalizedText(
            pt: 'Próximo passo',
            es: 'Próximo paso',
          ),
        ),
      ],
    ),
    PlantaoResponseContract(
      id: PlantaoResponseModelId.sepseChoqueSeptico,
      legacyMatrixNumber: 8,
      titleTemplate: PlantaoLocalizedText(
        pt: '[SEPSE OU CHOQUE SÉPTICO] — [FOCO]',
        es: '[SEPSIS O SHOCK SÉPTICO] — [FOCO]',
      ),
      sections: [
        PlantaoResponseSectionContract(
          key: 'bundle_primeira_hora',
          label: PlantaoLocalizedText(
            pt: 'Bundle da primeira hora',
            es: 'Bundle de la primera hora',
          ),
        ),
        PlantaoResponseSectionContract(
          key: 'vasopressor',
          label: PlantaoLocalizedText(pt: 'Vasopressor', es: 'Vasopresor'),
        ),
        PlantaoResponseSectionContract(
          key: 'meta',
          label: PlantaoLocalizedText(pt: 'Meta', es: 'Objetivo'),
        ),
        PlantaoResponseSectionContract(
          key: 'monitorizacao',
          label: PlantaoLocalizedText(
            pt: 'Monitorização',
            es: 'Monitorización',
          ),
        ),
      ],
    ),
    PlantaoResponseContract(
      id: PlantaoResponseModelId.intoxicacaoExogena,
      legacyMatrixNumber: 9,
      titleTemplate: PlantaoLocalizedText(
        pt: 'INTOXICAÇÃO — [AGENTE]',
        es: 'INTOXICACIÓN — [AGENTE]',
      ),
      sections: [
        PlantaoResponseSectionContract(
          key: 'abcde',
          label: PlantaoLocalizedText(pt: 'ABCDE', es: 'ABCDE'),
        ),
        PlantaoResponseSectionContract(
          key: 'antidoto',
          label: PlantaoLocalizedText(pt: 'Antídoto', es: 'Antídoto'),
        ),
        PlantaoResponseSectionContract(
          key: 'complicacao_fatal',
          label: PlantaoLocalizedText(
            pt: 'Complicação fatal',
            es: 'Complicación fatal',
          ),
        ),
        PlantaoResponseSectionContract(
          key: 'observacao',
          label: PlantaoLocalizedText(pt: 'Observação', es: 'Observación'),
        ),
      ],
    ),
    PlantaoResponseContract(
      id: PlantaoResponseModelId.trauma,
      legacyMatrixNumber: 10,
      titleTemplate: PlantaoLocalizedText(
        pt: 'TRAUMA — [TIPO]',
        es: 'TRAUMA — [TIPO]',
      ),
      sections: [
        PlantaoResponseSectionContract(
          key: 'abcde',
          label: PlantaoLocalizedText(pt: 'ABCDE', es: 'ABCDE'),
        ),
        PlantaoResponseSectionContract(
          key: 'sinal_alarme',
          label: PlantaoLocalizedText(
            pt: 'Sinal de alarme',
            es: 'Signo de alarma',
          ),
        ),
        PlantaoResponseSectionContract(
          key: 'medida_imediata',
          label: PlantaoLocalizedText(
            pt: 'Medida imediata',
            es: 'Medida inmediata',
          ),
        ),
        PlantaoResponseSectionContract(
          key: 'destino',
          label: PlantaoLocalizedText(pt: 'Destino', es: 'Destino'),
        ),
      ],
    ),
    PlantaoResponseContract(
      id: PlantaoResponseModelId.avc,
      legacyMatrixNumber: 11,
      titleTemplate: PlantaoLocalizedText(
        pt: 'AVC — [ISQUÊMICO OU HEMORRÁGICO]',
        es: 'ACV — [ISQUÉMICO O HEMORRÁGICO]',
      ),
      sections: [
        PlantaoResponseSectionContract(
          key: 'janela',
          label: PlantaoLocalizedText(
            pt: 'Janela terapêutica',
            es: 'Ventana terapéutica',
          ),
        ),
        PlantaoResponseSectionContract(
          key: 'exame_imediato',
          label: PlantaoLocalizedText(
            pt: 'Exame imediato',
            es: 'Estudio inmediato',
          ),
        ),
        PlantaoResponseSectionContract(
          key: 'conduta',
          label: PlantaoLocalizedText(pt: 'Conduta', es: 'Conducta'),
        ),
        PlantaoResponseSectionContract(
          key: 'nao_usar',
          label: PlantaoLocalizedText(pt: 'Não usar', es: 'No usar'),
        ),
        PlantaoResponseSectionContract(
          key: 'destino',
          label: PlantaoLocalizedText(pt: 'Destino', es: 'Destino'),
        ),
      ],
    ),
    PlantaoResponseContract(
      id: PlantaoResponseModelId.dorToracicaAguda,
      legacyMatrixNumber: 12,
      titleTemplate: PlantaoLocalizedText(
        pt: 'DOR TORÁCICA — ORIENTAÇÃO CLÍNICA',
        es: 'DOLOR TORÁCICO — ORIENTACIÓN CLÍNICA',
      ),
      sections: [
        PlantaoResponseSectionContract(
          key: 'diagnosticos_nao_perder',
          label: PlantaoLocalizedText(
            pt: 'Diagnósticos que não podem ser perdidos',
            es: 'Diagnósticos que no deben pasarse por alto',
          ),
        ),
        PlantaoResponseSectionContract(
          key: 'exames_imediatos',
          label: PlantaoLocalizedText(
            pt: 'Exames imediatos',
            es: 'Estudios inmediatos',
          ),
        ),
        PlantaoResponseSectionContract(
          key: 'tratamento_inicial',
          label: PlantaoLocalizedText(
            pt: 'Conduta inicial',
            es: 'Conducta inicial',
          ),
        ),
        PlantaoResponseSectionContract(
          key: 'sinais_alarme',
          label: PlantaoLocalizedText(
            pt: 'Sinais de alarme',
            es: 'Signos de alarma',
          ),
        ),
        PlantaoResponseSectionContract(
          key: 'proximo_passo',
          label: PlantaoLocalizedText(
            pt: 'Próximo passo',
            es: 'Próximo paso',
          ),
        ),
      ],
    ),
    PlantaoResponseContract(
      id: PlantaoResponseModelId.dispneiaAguda,
      legacyMatrixNumber: 13,
      titleTemplate: PlantaoLocalizedText(
        pt: 'DISPNEIA — ORIENTAÇÃO CLÍNICA',
        es: 'DISNEA — ORIENTACIÓN CLÍNICA',
      ),
      sections: [
        PlantaoResponseSectionContract(
          key: 'suporte',
          label: PlantaoLocalizedText(pt: 'Suporte', es: 'Soporte'),
        ),
        PlantaoResponseSectionContract(
          key: 'principais_hipoteses',
          label: PlantaoLocalizedText(
            pt: 'Possibilidades clínicas prioritárias',
            es: 'Posibilidades clínicas prioritarias',
          ),
        ),
        PlantaoResponseSectionContract(
          key: 'tratamento',
          label: PlantaoLocalizedText(pt: 'Conduta inicial', es: 'Conducta inicial'),
        ),
        PlantaoResponseSectionContract(
          key: 'proximo_passo',
          label: PlantaoLocalizedText(
            pt: 'Próximo passo',
            es: 'Próximo paso',
          ),
        ),
      ],
    ),
    PlantaoResponseContract(
      id: PlantaoResponseModelId.paradaCardiorrespiratoria,
      legacyMatrixNumber: 14,
      titleTemplate: PlantaoLocalizedText(
        pt: 'PCR — [RITMO]',
        es: 'PCR — [RITMO]',
      ),
      sections: [
        PlantaoResponseSectionContract(
          key: 'conduta_acls',
          label: PlantaoLocalizedText(
            pt: 'Conduta ACLS',
            es: 'Conducta ACLS',
          ),
        ),
        PlantaoResponseSectionContract(
          key: 'medicacao',
          label: PlantaoLocalizedText(pt: 'Medicação', es: 'Medicación'),
        ),
        PlantaoResponseSectionContract(
          key: 'ciclo',
          label: PlantaoLocalizedText(pt: 'Ciclo', es: 'Ciclo'),
        ),
        PlantaoResponseSectionContract(
          key: 'causas_reversiveis',
          label: PlantaoLocalizedText(
            pt: 'Causas reversíveis',
            es: 'Causas reversibles',
          ),
        ),
      ],
    ),
    PlantaoResponseContract(
      id: PlantaoResponseModelId.choque,
      legacyMatrixNumber: 15,
      titleTemplate: PlantaoLocalizedText(
        pt: 'CHOQUE — [TIPO]',
        es: 'SHOCK — [TIPO]',
      ),
      sections: [
        PlantaoResponseSectionContract(
          key: 'identificacao',
          label: PlantaoLocalizedText(
            pt: 'Identificação',
            es: 'Identificación',
          ),
        ),
        PlantaoResponseSectionContract(
          key: 'conduta_imediata',
          label: PlantaoLocalizedText(
            pt: 'Conduta imediata',
            es: 'Conducta inmediata',
          ),
        ),
        PlantaoResponseSectionContract(
          key: 'vasopressor',
          label: PlantaoLocalizedText(pt: 'Vasopressor', es: 'Vasopresor'),
        ),
        PlantaoResponseSectionContract(
          key: 'meta',
          label: PlantaoLocalizedText(pt: 'Meta', es: 'Objetivo'),
        ),
        PlantaoResponseSectionContract(
          key: 'proximo_passo',
          label: PlantaoLocalizedText(
            pt: 'Próximo passo',
            es: 'Próximo paso',
          ),
        ),
      ],
    ),
    PlantaoResponseContract(
      id: PlantaoResponseModelId.viaAereaVentilacaoMecanica,
      legacyMatrixNumber: 16,
      titleTemplate: PlantaoLocalizedText(
        pt: 'VIA AÉREA / VM — [INDICAÇÃO OU MODO]',
        es: 'VÍA AÉREA / VM — [INDICACIÓN O MODO]',
      ),
      sections: [
        PlantaoResponseSectionContract(
          key: 'parametros_iniciais',
          label: PlantaoLocalizedText(
            pt: 'Parâmetros iniciais',
            es: 'Parámetros iniciales',
          ),
        ),
        PlantaoResponseSectionContract(
          key: 'alvos',
          label: PlantaoLocalizedText(pt: 'Alvos', es: 'Objetivos'),
        ),
        PlantaoResponseSectionContract(
          key: 'alerta',
          label: PlantaoLocalizedText(pt: 'Alerta', es: 'Alerta'),
        ),
        PlantaoResponseSectionContract(
          key: 'proximo_passo',
          label: PlantaoLocalizedText(
            pt: 'Próximo passo',
            es: 'Próximo paso',
          ),
        ),
      ],
    ),
    PlantaoResponseContract(
      id: PlantaoResponseModelId.lesaoRenalAguda,
      legacyMatrixNumber: 17,
      titleTemplate: PlantaoLocalizedText(
        pt: 'LRA — [ESTÁGIO KDIGO]',
        es: 'LRA — [ESTADIO KDIGO]',
      ),
      sections: [
        PlantaoResponseSectionContract(
          key: 'criterio',
          label: PlantaoLocalizedText(pt: 'Critério', es: 'Criterio'),
        ),
        PlantaoResponseSectionContract(
          key: 'conduta',
          label: PlantaoLocalizedText(pt: 'Conduta', es: 'Conducta'),
        ),
        PlantaoResponseSectionContract(
          key: 'ajustes',
          label: PlantaoLocalizedText(pt: 'Ajustes', es: 'Ajustes'),
        ),
        PlantaoResponseSectionContract(
          key: 'indicacoes_dialise',
          label: PlantaoLocalizedText(
            pt: 'Indicações de diálise',
            es: 'Indicaciones de diálisis',
          ),
        ),
        PlantaoResponseSectionContract(
          key: 'proximo_passo',
          label: PlantaoLocalizedText(
            pt: 'Próximo passo',
            es: 'Próximo paso',
          ),
        ),
      ],
    ),
    PlantaoResponseContract(
      id: PlantaoResponseModelId.hemorragia,
      legacyMatrixNumber: 18,
      titleTemplate: PlantaoLocalizedText(
        pt: 'HEMORRAGIA — [SÍTIO E GRAVIDADE]',
        es: 'HEMORRAGIA — [SITIO Y GRAVEDAD]',
      ),
      sections: [
        PlantaoResponseSectionContract(
          key: 'gravidade',
          label: PlantaoLocalizedText(pt: 'Gravidade', es: 'Gravedad'),
        ),
        PlantaoResponseSectionContract(
          key: 'conduta',
          label: PlantaoLocalizedText(pt: 'Conduta', es: 'Conducta'),
        ),
        PlantaoResponseSectionContract(
          key: 'hemoderivados',
          label: PlantaoLocalizedText(
            pt: 'Hemoderivados',
            es: 'Hemoderivados',
          ),
        ),
        PlantaoResponseSectionContract(
          key: 'controle_fonte',
          label: PlantaoLocalizedText(
            pt: 'Controle da fonte',
            es: 'Control de la fuente',
          ),
        ),
      ],
    ),
    PlantaoResponseContract(
      id: PlantaoResponseModelId.criseHipertensiva,
      legacyMatrixNumber: 19,
      titleTemplate: PlantaoLocalizedText(
        pt: 'CRISE HIPERTENSIVA — [EMERGÊNCIA OU URGÊNCIA]',
        es: 'CRISIS HIPERTENSIVA — [EMERGENCIA O URGENCIA]',
      ),
      sections: [
        PlantaoResponseSectionContract(
          key: 'lesao_orgao_alvo',
          label: PlantaoLocalizedText(
            pt: 'Lesão de órgão-alvo',
            es: 'Lesión de órgano diana',
          ),
        ),
        PlantaoResponseSectionContract(
          key: 'conduta',
          label: PlantaoLocalizedText(pt: 'Conduta', es: 'Conducta'),
        ),
        PlantaoResponseSectionContract(
          key: 'farmaco_escolha',
          label: PlantaoLocalizedText(
            pt: 'Fármaco de escolha',
            es: 'Fármaco de elección',
          ),
        ),
        PlantaoResponseSectionContract(
          key: 'meta',
          label: PlantaoLocalizedText(pt: 'Meta', es: 'Objetivo'),
        ),
        PlantaoResponseSectionContract(
          key: 'proximo_passo',
          label: PlantaoLocalizedText(
            pt: 'Próximo passo',
            es: 'Próximo paso',
          ),
        ),
      ],
    ),
    PlantaoResponseContract(
      id: PlantaoResponseModelId.alteracaoLaboratorialCalculoClinico,
      legacyMatrixNumber: 20,
      titleTemplate: PlantaoLocalizedText(
        pt: '[ACHADO LABORATORIAL OU CÁLCULO] — [PARÂMETRO]',
        es: '[HALLAZGO DE LABORATORIO O CÁLCULO] — [PARÁMETRO]',
      ),
      sections: [
        PlantaoResponseSectionContract(
          key: 'achado',
          label: PlantaoLocalizedText(pt: 'Achado', es: 'Hallazgo'),
        ),
        PlantaoResponseSectionContract(
          key: 'causas_provaveis',
          label: PlantaoLocalizedText(
            pt: 'Causas prováveis',
            es: 'Causas probables',
          ),
        ),
        PlantaoResponseSectionContract(
          key: 'limiar_intervencao',
          label: PlantaoLocalizedText(
            pt: 'Intervir se',
            es: 'Intervenir si',
          ),
        ),
        PlantaoResponseSectionContract(
          key: 'correcao',
          label: PlantaoLocalizedText(pt: 'Correção', es: 'Corrección'),
        ),
        PlantaoResponseSectionContract(
          key: 'proximo_passo',
          label: PlantaoLocalizedText(
            pt: 'Próximo passo',
            es: 'Próximo paso',
          ),
        ),
      ],
    ),
    PlantaoResponseContract(
      id: PlantaoResponseModelId.consultaClinicaGeral,
      legacyMatrixNumber: 21,
      titleTemplate: PlantaoLocalizedText(
        pt: '[ASSUNTO CLÍNICO — máximo 4 palavras]',
        es: '[TEMA CLÍNICO — máximo 4 palabras]',
      ),
      sections: [
        PlantaoResponseSectionContract(
          key: 'resumo',
          label: PlantaoLocalizedText(pt: 'Resumo', es: 'Resumen'),
        ),
        PlantaoResponseSectionContract(
          key: 'pontos_chave',
          label: PlantaoLocalizedText(
            pt: 'Pontos-chave',
            es: 'Puntos clave',
          ),
        ),
        PlantaoResponseSectionContract(
          key: 'alerta_clinico',
          label: PlantaoLocalizedText(
            pt: 'Alerta clínico',
            es: 'Alerta clínico',
          ),
        ),
        PlantaoResponseSectionContract(
          key: 'proximo_passo',
          label: PlantaoLocalizedText(
            pt: 'Próximo passo',
            es: 'Próximo paso',
          ),
        ),
      ],
    ),
    PlantaoResponseContract(
      id: PlantaoResponseModelId.farmacoIsolado,
      legacyMatrixNumber: 22,
      titleTemplate: PlantaoLocalizedText(
        pt: '[FÁRMACO] — [CLASSE FARMACOLÓGICA]',
        es: '[FÁRMACO] — [CLASE FARMACOLÓGICA]',
      ),
      sections: [
        PlantaoResponseSectionContract(
          key: 'uso_principal',
          label: PlantaoLocalizedText(
            pt: 'Uso principal',
            es: 'Uso principal',
          ),
        ),
        PlantaoResponseSectionContract(
          key: 'alternativa',
          label: PlantaoLocalizedText(pt: 'Alternativa', es: 'Alternativa'),
        ),
        PlantaoResponseSectionContract(
          key: 'contraindicacoes',
          label: PlantaoLocalizedText(
            pt: 'Contraindicações',
            es: 'Contraindicaciones',
          ),
        ),
        PlantaoResponseSectionContract(
          key: 'monitorizacao',
          label: PlantaoLocalizedText(
            pt: 'Monitorização',
            es: 'Monitorización',
          ),
        ),
        PlantaoResponseSectionContract(
          key: 'alerta',
          label: PlantaoLocalizedText(pt: 'Alerta', es: 'Alerta'),
        ),
      ],
    ),
  ];

  static PlantaoResponseContract byId(PlantaoResponseModelId id) {
    for (final contract in contracts) {
      if (contract.id == id) return contract;
    }
    throw StateError('Contrato Plantão não encontrado para ${id.name}');
  }

  static PlantaoResponseContract byLegacyMatrix(int matrixNumber) {
    for (final contract in contracts) {
      if (contract.legacyMatrixNumber == matrixNumber) return contract;
    }
    throw StateError(
      'Contrato Plantão não encontrado para matriz $matrixNumber',
    );
  }
}
