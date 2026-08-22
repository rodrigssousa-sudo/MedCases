import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../../providers/ai_chat_provider.dart';
import '../../../providers/app_provider.dart';

class AiStatusSheet extends StatefulWidget {
  final String userEmail;
  final String userName;
  final String lang;
  final bool dark;
  final bool hasAi;
  final bool geminiConnected;
  final String geminiEmail;
  final bool geminiLoading;
  final bool keyLoading;

  const AiStatusSheet({
    super.key,
    required this.userEmail,
    required this.userName,
    required this.lang,
    required this.dark,
    required this.hasAi,
    this.geminiConnected = false,
    this.geminiEmail = '',
    this.geminiLoading = false,
    this.keyLoading = false,
  });

  @override
  State<AiStatusSheet> createState() => AiStatusSheetState();
}

class AiStatusSheetState extends State<AiStatusSheet> {
  bool get _isEs => widget.lang == 'es';
  bool _connectTriggeredByUser =
      false; // guard: só mostra erro se o usuário tocou

  Future<void> _handleGoogleConnect() async {
    // Marca que esta conexão foi iniciada explicitamente pelo usuário.
    // Isso impede que qualquer chamada interna/acidental mostre o banner.
    _connectTriggeredByUser = true;
    final p = context.read<AppProvider>();

    // connectGemini() retorna:
    //   true  → conectou com sucesso
    //   false → falha real (cancelou, erro de rede)
    //   null  → redirect OAuth iniciado (Safari/web) — página vai recarregar
    final result = await p.connectGemini();
    if (!mounted) return;

    if (result == null) {
      // Redirect iniciado — mostra feedback e aguarda o reload
      // O modal HTML já está visível; o usuário está vendo "Entrar com Google"
      // Não mostramos SnackBar de erro aqui — a página vai recarregar em breve
      // Build 188: debugPrint removido do hot path
    } else if (result == false && _connectTriggeredByUser) {
      // Falha real — mostra erro
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEs
              ? 'No se pudo conectar con Google. Intente de nuevo.'
              : 'Não foi possível conectar com o Google. Tente novamente.'),
          backgroundColor: const Color(0xFFB91C1C),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        ),
      );
    }
    _connectTriggeredByUser = false;
  }

  Future<void> _handleGoogleDisconnect() async {
    final p = context.read<AppProvider>();
    await p.disconnectGemini();
  }

  @override
  Widget build(BuildContext context) {
    // MEDCASES_AI_STATUS_SHEET_RESTYLE_V1_B_R0
    // Visual-only cutover. Connection/auth state and callbacks remain canonical.
    return Consumer<AiChatProvider>(
      builder: (context, aiChat, _) {
        final dark = widget.dark;
        final isEs = _isEs;
        final geminiConn = aiChat.geminiConnected;
        final geminiEmail = aiChat.geminiEmail;
        final geminiLoading = aiChat.geminiLoading;
        final hasAnyAi = aiChat.hasAnyAi;

        final sheetBg =
            dark ? const Color(0xFF1A1D23) : const Color(0xFFECF1F3);
        final surface =
            dark ? const Color(0xFF252930) : const Color(0xFFFFFFFF);
        final border =
            dark ? const Color(0xFF374151) : const Color(0xFFE7EBEF);
        final divider =
            dark ? const Color(0xFF374151) : const Color(0xFFE1E7ED);
        final text =
            dark ? const Color(0xFFFFFFFF) : const Color(0xFF05070A);
        final sub =
            dark ? const Color(0xFFA7B0BA) : const Color(0xFF59636E);
        final muted =
            dark ? const Color(0xFF7D8793) : const Color(0xFF8A939D);
        final accent =
            dark ? const Color(0xFF00C781) : const Color(0xFF008F66);
        final accentSoft =
            dark ? accent.withValues(alpha: 0.12) : const Color(0xFFE5F4EE);
        const danger = Color(0xFFEF4444);
        const googleBlue = Color(0xFF1A73E8);

        final bool serverActive =
            !geminiLoading && !widget.keyLoading && hasAnyAi;

        final String badgeLabel;
        if (geminiLoading || widget.keyLoading) {
          badgeLabel = 'Conectando...';
        } else if (serverActive) {
          badgeLabel = isEs ? 'Servidor activo' : 'Servidor ativo';
        } else {
          badgeLabel = 'Servidor offline';
        }

        final String modeLabel = isEs
            ? 'SERVIDOR MEDCASES IA — INTEGRADO A GOOGLE GEMINI'
            : 'SERVIDOR MEDCASES IA — INTEGRADO AO GOOGLE GEMINI';

        final String modesLabel = isEs
            ? '+1000 FÁRMACOS — MODO ESTUDIO — MODO GUARDIA'
            : '+1000 FÁRMACOS — MODO ESTUDO — MODO PLANTÃO';

        Widget flatSurface({
          required Widget child,
          EdgeInsetsGeometry padding =
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        }) {
          return Container(
            width: double.infinity,
            padding: padding,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: border, width: 0.6),
            ),
            child: child,
          );
        }

        Widget clinicalInfoRow({
          required IconData icon,
          required String title,
          required String body,
          bool dimmed = false,
        }) {
          final rowColor = dimmed ? muted : accent;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: rowColor.withValues(alpha: dark ? 0.12 : 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: rowColor),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        color: dimmed ? muted : text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 12.2,
                        fontWeight: FontWeight.w500,
                        height: 1.32,
                        color: dimmed ? muted : sub,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.92,
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                18,
                12,
                18,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: dark
                          ? const Color(0xFF59636E)
                          : const Color(0xFFC9D0D7),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  flatSurface(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: dark
                                    ? const Color(0xFF1A1D23)
                                    : const Color(0xFFF5F7F8),
                                borderRadius: BorderRadius.circular(6),
                                border:
                                    Border.all(color: border, width: 0.6),
                              ),
                              child: SvgPicture.asset(
                                'assets/icons/home_v2/ic_ia.svg',
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (widget.userName.isNotEmpty)
                                    Text(
                                      widget.userName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w800,
                                        height: 1.15,
                                        color: text,
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.userEmail.isNotEmpty
                                        ? widget.userEmail
                                        : (isEs ? 'Sin cuenta' : 'Sem conta'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.2,
                                      fontWeight: FontWeight.w500,
                                      color: sub,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: (geminiLoading || widget.keyLoading)
                                    ? muted.withValues(alpha: 0.10)
                                    : serverActive
                                        ? accentSoft
                                        : danger.withValues(alpha: 0.09),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: (geminiLoading || widget.keyLoading)
                                      ? muted.withValues(alpha: 0.35)
                                      : serverActive
                                          ? accent.withValues(alpha: 0.35)
                                          : danger.withValues(alpha: 0.32),
                                  width: 0.6,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (geminiLoading || widget.keyLoading)
                                    SizedBox(
                                      width: 8,
                                      height: 8,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.2,
                                        color: muted,
                                      ),
                                    )
                                  else
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color:
                                            serverActive ? accent : danger,
                                      ),
                                    ),
                                  const SizedBox(width: 6),
                                  Text(
                                    badgeLabel,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: (geminiLoading ||
                                              widget.keyLoading)
                                          ? muted
                                          : serverActive
                                              ? accent
                                              : danger,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(height: 0.6, color: divider),
                        const SizedBox(height: 13),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.psychology_alt_rounded,
                              size: 17,
                              color: accent,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                modeLabel,
                                style: TextStyle(
                                  fontSize: 12.2,
                                  fontWeight: FontWeight.w800,
                                  height: 1.28,
                                  color: text,
                                  letterSpacing: 0.15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.medication_outlined,
                              size: 16,
                              color: sub,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                modesLabel,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                  color: sub,
                                  letterSpacing: 0.15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 9),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              geminiConn
                                  ? Icons.account_circle_outlined
                                  : Icons.cloud_done_outlined,
                              size: 16,
                              color: geminiConn ? accent : sub,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                geminiConn && geminiEmail.isNotEmpty
                                    ? geminiEmail
                                    : modeLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: sub,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (geminiConn)
                    flatSurface(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: googleBlue.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.account_circle_rounded,
                              color: googleBlue,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Google conectado',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: text,
                                  ),
                                ),
                                if (geminiEmail.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    geminiEmail,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.8,
                                      fontWeight: FontWeight.w500,
                                      color: sub,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: geminiLoading
                                ? null
                                : _handleGoogleDisconnect,
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: danger.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: danger.withValues(alpha: 0.30),
                                  width: 0.6,
                                ),
                              ),
                              child: geminiLoading
                                  ? const SizedBox(
                                      width: 13,
                                      height: 13,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: danger,
                                      ),
                                    )
                                  : const Text(
                                      'Desconectar',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: danger,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            geminiLoading ? null : _handleGoogleConnect,
                        icon: geminiLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.8,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.account_circle_rounded,
                                size: 20,
                              ),
                        label: Text(
                          isEs
                              ? 'Conectar con Google'
                              : 'Conectar com Google',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              accent.withValues(alpha: 0.45),
                          elevation: 0,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  if (!geminiConn) ...[
                    const SizedBox(height: 7),
                    Text(
                      isEs
                          ? '3 pasos · usa tu propia cuenta de Google'
                          : '3 passos · use sua própria conta Google',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.2,
                        fontWeight: FontWeight.w500,
                        color: muted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  flatSurface(
                    padding: const EdgeInsets.all(13),
                    child: Column(
                      children: [
                        clinicalInfoRow(
                          icon: Icons.auto_awesome_rounded,
                          title: isEs
                              ? 'Base clínica activa'
                              : 'Base clínica ativa',
                          body: isEs
                              ? 'Protocolos y fármacos responden de forma inmediata.'
                              : 'Protocolos e fármacos respondem instantaneamente.',
                        ),
                        const SizedBox(height: 12),
                        Container(height: 0.6, color: divider),
                        const SizedBox(height: 12),
                        clinicalInfoRow(
                          icon: Icons.hub_outlined,
                          title: isEs
                              ? 'Gemini · GPT enriquece lo que la base no cubre'
                              : 'Gemini · GPT enriquece o que a base não cobre',
                          body: isEs
                              ? 'Las preguntas fuera de la base se responden con conocimiento médico global.'
                              : 'Perguntas fora da base são respondidas com conhecimento médico global.',
                          dimmed: !hasAnyAi,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text(
                        'Entendido',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
