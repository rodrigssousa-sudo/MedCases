// MEDCASES_PRODUCTIVE_SECOND_BRAND_BATCH_4A_V2_B_R1_AI_WIDGETS
import 'package:flutter/material.dart';

import '../../calculadora_screen.dart';
import '../../../services/ai_next_action_engine.dart';
import '../../../services/plantao_continuation_policy.dart';
import '../../../services/ai_pipeline/plantao/contracts/plantao_continuation_type.dart';
import '../../../services/ai_pipeline/plantao/contracts/plantao_section.dart';
import '../../../services/external_tool_link_engine.dart';
import 'action_button_policy.dart';
import 'action_card_button.dart';
import 'plantao_continuation_button.dart';

// ═════════════════════════════════════════════════════════════════════════════
// ActionButtonsRow — Build 192: linha de botões de ação unificados
//
// Substitui _SmartNextActionChip + _ExternalToolButton (stacked).
// Layout: dois botões lado a lado. Empilha apenas se largura < 340 px.
// Cor azul institucional (IA) vs roxo calculadora (Deep Link).
// Espaçamento após resposta: 16 px acima. Espaçamento antes de evidência: 20 px.
// ═════════════════════════════════════════════════════════════════════════════
class ActionButtonsRow extends StatelessWidget {
  final String lastUserMessage;
  final String lastAiResponse;
  final bool isPlantaoMode;
  final String lang;
  final bool dark;
  final List<String> chatHistory;
  final void Function(
    String prompt, {
    required String visibleLabel,
    required bool isStudyNext,
    required PlantaoContinuationType continuationType,
    required List<PlantaoSection> requestedSections,
  }) onActionTap;
  // BUILD 232: link pre-resolvido pelo pai com cache de deduplicacao.
  final ExternalToolLink? cachedLink;
  // BUILD 300: Modo Estudo — prompt e label dinâmico via tag [NEXT_ACTION_PROMPT:...]
  // Quando presentes e !isPlantaoMode, o botão azul usa esses valores em vez
  // do NextActionEngine genérico.
  final String studyNextPrompt;
  final String studyNextLabel;
  // BUILD 308 [FISIOP_DEDUP]: Último prompt de Estudo enviado pelo usuário.
  // Se o studyNextPrompt atual repete o mesmo quadrante de Fisiopatologia,
  // o botão é redirecionado para prompt de avanço linear.
  final String lastSentStudyPrompt;

  /// Oculta somente a ação de IA desta linha.
  ///
  /// Ferramentas externas permanecem visíveis quando a continuação pedagógica
  /// já foi migrada para StudyContinuationButton.
  final bool suppressAiAction;

  // Cores institucionais -- imutaveis por design
  // Azul institucional IA (mesmo do AppBar/primary)
  // Verde Pasto — identidade visual MedCases para ação/ferramenta
  // BRAND GREEN PASTO: ação/ferramenta canônica = 0xFF0E8000
  static const _kToolBtn = Color(0xFF0E8000);

  const ActionButtonsRow({
    super.key,
    required this.lastUserMessage,
    required this.lastAiResponse,
    required this.isPlantaoMode,
    required this.lang,
    required this.dark,
    required this.onActionTap,
    required this.cachedLink,
    this.chatHistory = const [],
    this.studyNextPrompt = '',
    this.studyNextLabel = '',
    this.lastSentStudyPrompt = '',
    this.suppressAiAction = false,
  });

  @override
  Widget build(BuildContext context) {
    // ── Motor IA: Smart Next Action (local, zero rede) ────────────────────────
    final action = suppressAiAction
        ? const SmartNextAction(
            label: '',
            promptToSend: '',
          )
        : NextActionEngine.build(
            lastUserMessage: lastUserMessage,
            lastAiResponse: lastAiResponse,
            isPlantaoMode: isPlantaoMode,
            currentLanguage: lang,
            chatHistory: chatHistory,
          );

    // MEDCASES_PLANTAO_CONTINUATION_FINAL_SURGICAL_V1_B_R0
    // NextActionEngine remains canonical. This local layer only avoids
    // repeating already-covered Plantão follow-up domains.
    final effectivePlantaoAction = isPlantaoMode
        ? PlantaoContinuationPolicy.resolve(
            baseAction: action,
            lastUserMessage: lastUserMessage,
            lastAiResponse: lastAiResponse,
            chatHistory: chatHistory,
            languageCode: lang,
          )
        : action;

    // BUILD 232: ExternalToolLink vem pre-resolvido do cache do pai.
    // Nao chama ExternalToolLinkEngine.build() aqui -- elimina duplicacao em rebuilds.
    final link = cachedLink;

    final studyAction = ActionButtonPolicy.resolveStudyAction(
      isPlantaoMode: isPlantaoMode,
      studyNextPrompt: studyNextPrompt,
      studyNextLabel: studyNextLabel,
      lastSentStudyPrompt: lastSentStudyPrompt,
      languageCode: lang,
    );
    final hasStudyNext = studyAction.hasStudyNext;

    // Historical canonical predicate remains a real runtime seam.
    final bool canonicalActionAvailable =
        hasStudyNext || action.label.isNotEmpty;

    // Plantão can surface a useful local gap even when NextActionEngine
    // intentionally returned no generic filler action.
    final bool effectivePlantaoAvailable =
        isPlantaoMode && effectivePlantaoAction.label.isNotEmpty;

    final bool showAiBtn = !suppressAiAction &&
        (canonicalActionAvailable || effectivePlantaoAvailable);

    // Nenhum botão disponível → sem widget
    // Modo Estudo: sempre mostra o botão se hasStudyNext=true, mesmo sem action
    if (!showAiBtn && link == null) {
      return const SizedBox.shrink();
    }

    final effectiveStudyPrompt = studyAction.prompt;
    final effectiveStudyLabel = studyAction.label;

    // BUILD 301: label do botão azul — 100% dinâmico via tag [NEXT_ACTION_LABEL].
    // hasStudyNext=true → studyNextLabel vem direto da tag gerada pela IA.
    // Fallback neutro só para Modo Plantão ou resposta de Estudo sem tags
    // (não deve ocorrer em produção, mas defensivo).
    final aiLabel = hasStudyNext
        ? effectiveStudyLabel
        : (action.label.isNotEmpty
            ? action.label
            : (lang == 'es' ? 'Avanzar Estudio' : 'Avançar Estudo'));

    // ── ORDEM VISUAL 02 M2: Emoji Stripper ───────────────────────────────────
    // Remove emojis e símbolos especiais do início dos labels antes de exibir.
    // O ActionCardButton já tem ícone vetorial próprio — emoji no texto é poluição.
    // Regex: strip qualquer char que não seja letra (incluindo acentos À-ÿ) ou dígito.
    // Exemplos: '💊 Abrir Amiodarona' → 'Abrir Amiodarona'
    //           '⚗️ Potássio (eletrólitos)' → 'Potássio (eletrólitos)'
    //           '✨ Aprofundar Fisiopatologia >' → 'Aprofundar Fisiopatologia >'
    final cleanLinkLabel =
        link == null ? '' : ActionButtonPolicy.sanitizeToolLabel(link.label);
    // Label do botão Calculadora — Build 223: usa link.label (context-aware)
    // ORDEM VISUAL 02: emoji stripped antes de passar para ActionCardButton.title.
    // A decisão de qual calculadora abrir acontece no pipeline (ExternalToolLinkEngine),
    // nunca aqui. A UI apenas consome o label já resolvido e higienizado.

    return Padding(
      // 16 px acima da resposta (spacing entre resposta e botões)
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Empilha somente em telas muito estreitas (< 340 px disponíveis)
          final stacked = constraints.maxWidth < 340;

          // BUILD 300: botão azul dinâmico no Modo Estudo.
          // hasStudyNext=true → usa effectiveStudyPrompt (com dedup guard BUILD 308).
          // hasStudyNext=false → comportamento clássico via NextActionEngine.
          // showAiBtn foi resolvido acima, respeitando suppressAiAction.
          final aiBtn = showAiBtn
              ? (isPlantaoMode && !hasStudyNext
                  ? (effectivePlantaoAction.label.isNotEmpty
                      ? PlantaoContinuationButton(
                          label: effectivePlantaoAction.label,
                          accentColor: _kToolBtn,
                          dark: dark,
                          onTap: () => onActionTap(
                            effectivePlantaoAction.promptToSend,
                            visibleLabel: effectivePlantaoAction.label,
                            isStudyNext: false,
                            continuationType:
                                effectivePlantaoAction.continuationType,
                            requestedSections:
                                effectivePlantaoAction.requestedSections,
                          ),
                        )
                      : null)
                  : ActionCardButton(
                  title: aiLabel,
                  icon: Icons.auto_awesome_rounded,
                  accentColor: _kToolBtn,
                  dark: dark,
                  onTap: () => onActionTap(
                    hasStudyNext ? effectiveStudyPrompt : action.promptToSend,
                    visibleLabel: aiLabel,
                    isStudyNext:
                        hasStudyNext, // BUILD 308: sinaliza botão de Estudo
                    continuationType: hasStudyNext
                        ? PlantaoContinuationType.freeFollowUp
                        : action.continuationType,
                    requestedSections: hasStudyNext
                        ? const <PlantaoSection>[]
                        : action.requestedSections,
                  ),
                ))
              : null;

          final calcBtn = link != null
              ? ActionCardButton(
                  title: cleanLinkLabel.isNotEmpty
                      ? cleanLinkLabel
                      : link.label, // ORDEM VISUAL 02: emoji stripped
                  icon: Icons.calculate_rounded,
                  accentColor: _kToolBtn,
                  dark: dark,
                  onTap: () {
                    // CACHE-FIRST SINGLE-NAV:
                    // never await disk/cache resolution before opening the screen.
                    // CalculadoraScreen owns local-vs-online source selection.
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            CalculadoraScreen(initialUrl: link.url),
                      ),
                    );
                  },
                )
              : null;

          // Apenas um botão presente
          if (aiBtn == null && calcBtn != null) {
            return SizedBox(width: double.infinity, child: calcBtn);
          }
          if (calcBtn == null && aiBtn != null) {
            return SizedBox(width: double.infinity, child: aiBtn);
          }
          if (aiBtn == null || calcBtn == null) return const SizedBox.shrink();

          // Ambos presentes
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                aiBtn,
                const SizedBox(height: 8),
                calcBtn,
              ],
            );
          }

          // Layout lado a lado — espaço igual, crescimento simétrico
          return Row(
            children: [
              Expanded(child: aiBtn),
              const SizedBox(width: 8),
              Expanded(child: calcBtn),
            ],
          );
        },
      ),
    );
  }
}
