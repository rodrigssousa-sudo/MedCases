/// ClinicalSessionMemory — Memória clínica estruturada da sessão atual
///
/// Design principles:
///   • Estado em memória RAM — NUNCA persiste em banco ou disco
///   • Serialização condicional — buildMemoryBlock() retorna '' se estado vazio
///   • Isolamento de tema — resetIfTopicChanged() limpa estado ao mudar assunto
///   • Thread-safe por design — singleton por Provider/contexto de chat
///   • Injetado como parâmetro opcional em buildClinicalSystemPrompt()
///
/// Ciclo de vida:
///   ChatScreen cria instância → passa para AiService a cada turno →
///   AiService serializa via buildMemoryBlock() → injeta no system prompt →
///   ChatScreen atualiza estado após cada resposta via update*() helpers
class ClinicalSessionMemory {

  // ── Estado clínico estruturado ─────────────────────────────────────────────

  /// Problemas ativos identificados na conversa (ex: "IAM anterior, EAP atual")
  final List<String> activeProblems = [];

  /// Hipóteses de trabalho em discussão (ex: "TEP vs pneumonia")
  final List<String> workingDiagnoses = [];

  /// Medicamentos citados/prescritos na conversa
  final List<String> previousMeds = [];

  /// Alergias mencionadas
  final List<String> allergies = [];

  /// Status hemodinâmico registrado (ex: "hipotenso, PA 80/50")
  String? hemodynamicStatus;

  /// Exames laboratoriais/imagem citados (ex: "Trop 2.4, Lactato 4.2")
  final List<String> previousLabs = [];

  /// Nível de risco atual: 'low' | 'moderate' | 'high' | 'critical'
  String currentRiskLevel = 'low';

  /// Antibióticos iniciados (controle de stewardship)
  final List<String> antibioticsStarted = [];

  /// Ajustes terapêuticos registrados (ex: "dose de noradrenalina dobrada")
  final List<String> therapeuticAdjustments = [];

  /// Evolução clínica: 'improving' | 'stable' | 'deteriorating' | ''
  String clinicalEvolution = '';

  /// Tema dominante da sessão — usado para detectar mudança de assunto
  String _dominantTopic = '';

  /// Número de turnos no tema atual — threshold para considerar tema estabelecido
  int _topicTurnCount = 0;

  // ── API pública de atualização ─────────────────────────────────────────────

  /// Adiciona problema ativo se não duplicado (normalizado para lowercase)
  void addProblem(String problem) {
    final normalized = problem.trim().toLowerCase();
    if (normalized.isNotEmpty && !activeProblems.any((p) => p.toLowerCase() == normalized)) {
      activeProblems.add(problem.trim());
    }
  }

  /// Adiciona hipótese diagnóstica se não duplicada
  void addDiagnosis(String dx) {
    final normalized = dx.trim().toLowerCase();
    if (normalized.isNotEmpty && !workingDiagnoses.any((d) => d.toLowerCase() == normalized)) {
      workingDiagnoses.add(dx.trim());
    }
  }

  /// Adiciona medicamento citado se não duplicado
  void addMedication(String med) {
    final normalized = med.trim().toLowerCase();
    if (normalized.isNotEmpty && !previousMeds.any((m) => m.toLowerCase() == normalized)) {
      previousMeds.add(med.trim());
    }
  }

  /// Adiciona alergia se não duplicada
  void addAllergy(String allergy) {
    final normalized = allergy.trim().toLowerCase();
    if (normalized.isNotEmpty && !allergies.any((a) => a.toLowerCase() == normalized)) {
      allergies.add(allergy.trim());
    }
  }

  /// Adiciona exame ou resultado laboratorial
  void addLab(String lab) {
    final normalized = lab.trim().toLowerCase();
    if (normalized.isNotEmpty && !previousLabs.any((l) => l.toLowerCase() == normalized)) {
      previousLabs.add(lab.trim());
    }
  }

  /// Adiciona antibiótico iniciado
  void addAntibiotic(String atb) {
    final normalized = atb.trim().toLowerCase();
    if (normalized.isNotEmpty && !antibioticsStarted.any((a) => a.toLowerCase() == normalized)) {
      antibioticsStarted.add(atb.trim());
    }
  }

  /// Registra ajuste terapêutico
  void addTherapeuticAdjustment(String adjustment) {
    if (adjustment.trim().isNotEmpty) {
      therapeuticAdjustments.add(adjustment.trim());
    }
  }

  /// Atualiza status hemodinâmico (sobrescreve — sempre o mais recente)
  void updateHemodynamics(String status) {
    hemodynamicStatus = status.trim().isEmpty ? null : status.trim();
  }

  /// Atualiza nível de risco
  void updateRiskLevel(String level) {
    const valid = {'low', 'moderate', 'high', 'critical'};
    if (valid.contains(level)) currentRiskLevel = level;
  }

  /// Atualiza evolução clínica
  void updateEvolution(String evolution) {
    const valid = {'improving', 'stable', 'deteriorating', ''};
    if (valid.contains(evolution)) clinicalEvolution = evolution;
  }

  // ── Detecção de mudança de tema e reset ──────────────────────────────────

  /// Verifica se a query indica mudança clara de assunto e, se sim, reseta estado.
  ///
  /// Lógica AGRESSIVA (Part B — context contamination fix):
  ///   • Qualquer mudança de tema detectada (≥1 turno) dispara reset imediato.
  ///   • Threshold foi reduzido de ≥2 para ≥1 porque um único turno sobre
  ///     Cistite já polui o contexto quando o usuário muda para Parkinson.
  ///   • Segurança clínica > continuidade narrativa: falso reset (pergunta
  ///     de follow-up detectada como novo tema) é muito menos danoso do que
  ///     uma alucinação por contexto vazado de conversa anterior.
  bool resetIfTopicChanged(String newQuery) {
    final newTopic = _extractTopicSignature(newQuery);

    if (_dominantTopic.isEmpty) {
      // Primeira query — estabelece tema
      _dominantTopic = newTopic;
      _topicTurnCount = 1;
      return false;
    }

    final isSameTopic = _topicsOverlap(_dominantTopic, newTopic);

    if (isSameTopic) {
      _topicTurnCount++;
      return false;
    }

    // ── RESET AGRESSIVO: qualquer mudança de tema (≥1 turno) → reset total ──
    // Threshold anterior ≥2 era conservador e causava contaminação quando
    // o tema anterior tinha apenas 1 turno (ex: Cistite → Parkinson sem reset).
    // Agora ≥1 garante que QUALQUER virada de tema limpa a memória clínica.
    reset();
    _dominantTopic = newTopic;
    _topicTurnCount = 1;
    return true;
  }

  /// Reseta toda a memória clínica (chamado na mudança de tema ou manualmente)
  void reset() {
    activeProblems.clear();
    workingDiagnoses.clear();
    previousMeds.clear();
    allergies.clear();
    previousLabs.clear();
    antibioticsStarted.clear();
    therapeuticAdjustments.clear();
    hemodynamicStatus = null;
    currentRiskLevel = 'low';
    clinicalEvolution = '';
    _dominantTopic = '';
    _topicTurnCount = 0;
  }

  // ── Serialização para o prompt ───────────────────────────────────────────

  /// Retorna bloco de memória formatado para injeção no system prompt.
  ///
  /// Retorna '' se não houver dados clínicos úteis (evita bloco vazio no prompt).
  /// Bloco é curto e limpo — máximo ~8 linhas para não inflar o prompt.
  String buildMemoryBlock(bool isEs) {
    if (_isEmpty) return '';

    final buf = StringBuffer();
    buf.writeln(isEs
        ? '[CONTEXTO_CLINICO_SESION — usar para coherencia longitudinal, no repetir]'
        : '[CONTEXTO_CLINICO_SESSAO — usar para coerencia longitudinal, nao repetir]');

    if (activeProblems.isNotEmpty) {
      buf.writeln(isEs
          ? '- Problemas activos: ${activeProblems.join(', ')}'
          : '- Problemas ativos: ${activeProblems.join(', ')}');
    }

    if (workingDiagnoses.isNotEmpty) {
      buf.writeln(isEs
          ? '- Hipotesis en discusion: ${workingDiagnoses.join(' / ')}'
          : '- Hipoteses em discussao: ${workingDiagnoses.join(' / ')}');
    }

    if (previousMeds.isNotEmpty) {
      buf.writeln(isEs
          ? '- Farmacos citados: ${previousMeds.join(', ')}'
          : '- Farmacos citados: ${previousMeds.join(', ')}');
    }

    if (allergies.isNotEmpty) {
      buf.writeln(isEs
          ? '- Alergias: ${allergies.join(', ')}'
          : '- Alergias: ${allergies.join(', ')}');
    }

    if (hemodynamicStatus != null) {
      buf.writeln(isEs
          ? '- Hemodinamica: $hemodynamicStatus'
          : '- Hemodinamica: $hemodynamicStatus');
    }

    if (previousLabs.isNotEmpty) {
      buf.writeln(isEs
          ? '- Examenes/labs: ${previousLabs.join(', ')}'
          : '- Exames/labs: ${previousLabs.join(', ')}');
    }

    if (antibioticsStarted.isNotEmpty) {
      buf.writeln(isEs
          ? '- ATB iniciados: ${antibioticsStarted.join(', ')}'
          : '- ATB iniciados: ${antibioticsStarted.join(', ')}');
    }

    if (therapeuticAdjustments.isNotEmpty) {
      // Último ajuste apenas — evita bloco longo
      buf.writeln(isEs
          ? '- Ultimo ajuste: ${therapeuticAdjustments.last}'
          : '- Ultimo ajuste: ${therapeuticAdjustments.last}');
    }

    if (clinicalEvolution.isNotEmpty) {
      final evoEs = switch (clinicalEvolution) {
        'improving'    => 'mejorando',
        'deteriorating'=> 'deteriorando',
        _              => 'estable',
      };
      final evoPt = switch (clinicalEvolution) {
        'improving'    => 'melhorando',
        'deteriorating'=> 'deteriorando',
        _              => 'estavel',
      };
      buf.writeln(isEs ? '- Evolucion: $evoEs' : '- Evolucao: $evoPt');
    }

    if (currentRiskLevel == 'high' || currentRiskLevel == 'critical') {
      buf.writeln(isEs
          ? '- Riesgo actual: ${currentRiskLevel == 'critical' ? 'CRITICO' : 'ALTO'}'
          : '- Risco atual: ${currentRiskLevel == 'critical' ? 'CRITICO' : 'ALTO'}');
    }

    buf.write(isEs ? '[FIN_CONTEXTO_SESION]' : '[FIM_CONTEXTO_SESSAO]');
    return buf.toString();
  }

  // ── Helpers privados ─────────────────────────────────────────────────────

  bool get _isEmpty =>
      activeProblems.isEmpty &&
      workingDiagnoses.isEmpty &&
      previousMeds.isEmpty &&
      allergies.isEmpty &&
      previousLabs.isEmpty &&
      antibioticsStarted.isEmpty &&
      therapeuticAdjustments.isEmpty &&
      hemodynamicStatus == null &&
      clinicalEvolution.isEmpty &&
      currentRiskLevel == 'low';

  /// Extrai assinatura temática de uma query (primeiras 3 palavras significativas)
  String _extractTopicSignature(String query) {
    const stopwords = {
      'de', 'da', 'do', 'e', 'em', 'o', 'a', 'os', 'as', 'um', 'uma',
      'para', 'com', 'no', 'na', 'por', 'que', 'se', 'como',
      'el', 'la', 'los', 'las', 'un', 'una', 'en', 'y', 'es', 'del',
    };
    final words = query
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3 && !stopwords.contains(w))
        .take(3)
        .toList();
    return words.join('_');
  }

  /// Verifica overlap temático — compartilham pelo menos 1 palavra-chave
  bool _topicsOverlap(String topic1, String topic2) {
    if (topic1.isEmpty || topic2.isEmpty) return false;
    final t1 = Set<String>.from(topic1.split('_'));
    final t2 = Set<String>.from(topic2.split('_'));
    return t1.intersection(t2).isNotEmpty;
  }
}
