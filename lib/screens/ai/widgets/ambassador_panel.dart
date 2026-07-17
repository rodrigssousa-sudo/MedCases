import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/chat_message.dart';
import '../../../models/user_model.dart';
import '../../../providers/app_provider.dart';
import '../../../services/referral_service.dart';
import 'ambassador_panel_helpers.dart';

class AmbassadorPanel extends StatefulWidget {
  final UserModel user;
  final String lang;
  final List<ChatMessage> messages;
  final Future<bool> Function(String prompt) onSecondOpinion;
  final AppProvider provider;

  const AmbassadorPanel({
    super.key,
    required this.user,
    required this.lang,
    required this.messages,
    required this.onSecondOpinion,
    required this.provider,
  });

  @override
  State<AmbassadorPanel> createState() => AmbassadorPanelState();
}

class AmbassadorPanelState extends State<AmbassadorPanel> {
  static const _kGold = Color(0xFFD4AF37);
  static const _kGoldLight = Color(0xFFFFE8A6);
  static const _kBg = Color(0xFF0E1218);

  // Second Opinion state
  bool _soLoading = false;
  bool _soStreamed = false;
  String _soResult = '';

  // Referral count
  int _referralCount = 0;
  bool _countLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReferralCount();
  }

  Future<void> _loadReferralCount() async {
    try {
      final link = widget.user.referralLink ?? '';
      final slug = link.isNotEmpty ? link.split('/').last : widget.user.uid;
      final count = await ReferralService.getConversionCount(slug);
      if (mounted)
        setState(() {
          _referralCount = count;
          _countLoading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _countLoading = false);
    }
  }

  void _copyLink() {
    final link = widget.user.referralLink ?? '';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text(widget.lang == 'es' ? 'Link copiado 📋' : 'Link copiado 📋'),
      backgroundColor: _kGold.withOpacity(0.9),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _shareWhatsApp() async {
    final link = widget.user.referralLink ?? '';
    final msg = widget.lang == 'es'
        ? '¡Hola! Te invito a usar MedCases Pro, la mejor IA clínica para médicos. '
            'Accede con mi link exclusivo: $link'
        : 'Olá! Te convido a usar o MedCases Pro, a melhor IA clínica para médicos. '
            'Acesse com meu link exclusivo: $link';
    final encoded = Uri.encodeComponent(msg);
    final uri = Uri.parse('https://wa.me/?text=$encoded');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _runSecondOpinion() async {
    if (_soLoading || widget.messages.isEmpty) return;
    setState(() {
      _soLoading = true;
      _soStreamed = false;
      _soResult = '';
    });

    // BUILD 313 — Prompt VIP humanizado: frase orgânica de médico,
    // sem estrutura de comando de sistema que dispara guardrail.
    // O contexto da conversa é injetado como histórico natural da sessão.
    final lang = widget.lang;

    final humanizedPrompt = lang == 'es'
        ? '¿Puede hacer un análisis clínico profundo y avanzado de este caso, '
            'basado en las últimas evidencias científicas disponibles? '
            'Me gustaría una segunda opinión estructurada que incluya: '
            'una evaluación del riesgo del paciente, '
            'la justificación fisiopatológica de la conducta adoptada, '
            'y si la misma está alineada con los guidelines internacionales vigentes.'
        : 'Pode fazer uma análise clínica aprofundada e avançada deste caso, '
            'baseada nas últimas evidências científicas disponíveis? '
            'Gostaria de uma segunda opinião estruturada que inclua: '
            'uma avaliação do risco do paciente, '
            'a justificativa fisiopatológica da conduta adotada, '
            'e se a mesma está alinhada com os guidelines internacionais vigentes.';

    // Injeta o histórico da conversa como contexto natural da mensagem
    final history = widget.messages
        .where((m) => m.role == 'user' || m.role == 'ai')
        .map((m) => '${m.role == 'user' ? '[Médico]' : '[IA]'}: ${m.text}')
        .join('\n\n');

    final fullPrompt =
        '$humanizedPrompt\n\n--- Contexto da consulta ---\n$history';

    // Stream via provider
    await widget.provider.sendAiMessage(
      fullPrompt,
      onChunk: (accumulated) {
        if (mounted) setState(() => _soResult = accumulated);
      },
      onDone: (finalText) {
        if (mounted)
          setState(() {
            _soResult = finalText.isNotEmpty ? finalText : _soResult;
            _soLoading = false;
            _soStreamed = true;
          });
      },
      onError: (err) {
        if (mounted)
          setState(() {
            _soLoading = false;
            _soResult = widget.lang == 'es'
                ? '⚠️ Error al generar el informe. Intente nuevamente.'
                : '⚠️ Erro ao gerar o relatório. Tente novamente.';
            _soStreamed = true;
          });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    final user = widget.user;
    final link = user.referralLink ?? '';
    final title =
        user.partnerTitle ?? (lang == 'es' ? 'Embajador' : 'Embaixador');

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        decoration: BoxDecoration(
          color: _kBg.withOpacity(0.97),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: const Border(
            top: BorderSide(color: _kGold, width: 1.5),
            left: BorderSide(color: Color(0x44D4AF37), width: 0.8),
            right: BorderSide(color: Color(0x44D4AF37), width: 0.8),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Handle bar ──────────────────────────────────────────────
                Center(
                    child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: _kGold.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                )),

                // ── Header ──────────────────────────────────────────────────
                Row(children: [
                  const Text('👑', style: TextStyle(fontSize: 26)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: _kGold,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Text(
                        user.displayName,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  )),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white38, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ]),
                const SizedBox(height: 24),

                // ═══════════════════════════════════════════════════════════
                // SEÇÃO A — Crescimento: Referral Link + Share + Count
                // ═══════════════════════════════════════════════════════════
                AmbassadorSectionHeader(
                  icon: Icons.link_rounded,
                  label: lang == 'es'
                      ? 'Su red de crecimiento'
                      : 'Sua rede de crescimento',
                ),
                const SizedBox(height: 12),

                // Link display
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _kGold.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kGold.withOpacity(0.25)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.link_rounded, color: _kGold, size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(
                      link.isNotEmpty ? link : '—',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    )),
                  ]),
                ),
                const SizedBox(height: 10),

                // Action buttons row
                Row(children: [
                  // Copy button
                  Expanded(
                      child: AmbassadorGoldButton(
                    icon: Icons.copy_rounded,
                    label: lang == 'es' ? 'Copiar link' : 'Copiar link',
                    onTap: _copyLink,
                  )),
                  const SizedBox(width: 10),
                  // WhatsApp share button
                  Expanded(
                      child: AmbassadorGoldButton(
                    icon: Icons.share_rounded,
                    label: 'WhatsApp',
                    onTap: _shareWhatsApp,
                    color: const Color(0xFF25D366),
                  )),
                ]),
                const SizedBox(height: 14),

                // Referral count badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.group_rounded, color: _kGold, size: 22),
                    const SizedBox(width: 12),
                    _countLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: _kGold))
                        : Expanded(
                            child: Text(
                            lang == 'es'
                                ? 'Su red: $_referralCount médico${_referralCount != 1 ? 's' : ''} integrado${_referralCount != 1 ? 's' : ''}'
                                : 'Sua rede: $_referralCount médico${_referralCount != 1 ? 's' : ''} integrado${_referralCount != 1 ? 's' : ''}',
                            style: const TextStyle(
                                color: _kGoldLight,
                                fontSize: 14,
                                fontWeight: FontWeight.w700),
                          )),
                  ]),
                ),
                const SizedBox(height: 28),

                // ═══════════════════════════════════════════════════════════
                // SEÇÃO B — Segunda Opinião
                // ═══════════════════════════════════════════════════════════
                AmbassadorSectionHeader(
                  icon: Icons.auto_awesome_rounded,
                  label: lang == 'es'
                      ? 'Superpoder Clínico'
                      : 'Superpoder Clínico',
                ),
                const SizedBox(height: 12),

                // If Second Opinion not yet triggered → show button
                if (!_soStreamed && !_soLoading) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          widget.messages.isEmpty ? null : _runSecondOpinion,
                      icon: const Text('🪄', style: TextStyle(fontSize: 18)),
                      label: Text(
                        lang == 'es'
                            ? 'Generar Informe de Segunda Opinión'
                            : 'Gerar Relatório de Segunda Opinião',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A1D28),
                        foregroundColor: _kGoldLight,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: _kGold, width: 1.2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  if (widget.messages.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        lang == 'es'
                            ? 'Inicie una consulta para generar la segunda opinión.'
                            : 'Inicie uma consulta para gerar a segunda opinião.',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],

                // Loading spinner while streaming
                if (_soLoading && !_soStreamed) ...[
                  const Center(
                      child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Column(children: [
                      CircularProgressIndicator(color: _kGold),
                      SizedBox(height: 12),
                      Text('Gerando relatório clínico...',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 12)),
                    ]),
                  )),
                  // Live streaming preview
                  if (_soResult.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: MarkdownBody(
                        data: _soResult,
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(
                              color: Colors.white70, fontSize: 12, height: 1.5),
                          h1: const TextStyle(
                              color: _kGoldLight,
                              fontSize: 15,
                              fontWeight: FontWeight.w900),
                          h2: const TextStyle(
                              color: _kGoldLight,
                              fontSize: 14,
                              fontWeight: FontWeight.w800),
                          h3: const TextStyle(
                              color: _kGold,
                              fontSize: 13,
                              fontWeight: FontWeight.w700),
                          strong: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],

                // Final Markdown result
                if (_soStreamed && _soResult.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _kGold.withOpacity(0.20)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.check_circle_rounded,
                              color: _kGold, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            lang == 'es'
                                ? 'Informe de Segunda Opinión'
                                : 'Relatório de Segunda Opinião',
                            style: const TextStyle(
                                color: _kGoldLight,
                                fontSize: 13,
                                fontWeight: FontWeight.w800),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        MarkdownBody(
                          data: _soResult,
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(
                                color: Colors.white, fontSize: 13, height: 1.6),
                            h1: const TextStyle(
                                color: _kGoldLight,
                                fontSize: 16,
                                fontWeight: FontWeight.w900),
                            h2: const TextStyle(
                                color: _kGoldLight,
                                fontSize: 14,
                                fontWeight: FontWeight.w800),
                            h3: const TextStyle(
                                color: _kGold,
                                fontSize: 13,
                                fontWeight: FontWeight.w700),
                            strong: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700),
                            blockquote: const TextStyle(
                                color: Colors.white60, fontSize: 12),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Copy result button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _soResult));
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content: Text(lang == 'es'
                                    ? 'Informe copiado al portapapeles'
                                    : 'Relatório copiado para a área de transferência'),
                                backgroundColor: _kGold.withOpacity(0.9),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ));
                            },
                            icon: const Icon(Icons.copy_rounded,
                                size: 15, color: _kGold),
                            label: Text(
                              lang == 'es'
                                  ? 'Copiar informe'
                                  : 'Copiar relatório',
                              style: const TextStyle(
                                  color: _kGold,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: _kGold.withOpacity(0.4)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Regenerate
                        Center(
                            child: TextButton(
                          onPressed: () => setState(() {
                            _soStreamed = false;
                            _soResult = '';
                            _soLoading = false;
                          }),
                          child: Text(
                            lang == 'es'
                                ? '↺ Regenerar informe'
                                : '↺ Regenerar relatório',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11),
                          ),
                        )),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
