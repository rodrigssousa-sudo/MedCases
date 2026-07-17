import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/ai_chat_provider.dart';
import '../../../providers/app_provider.dart';
import 'info_row.dart';

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
    // BUILD 326: Consumer<AiChatProvider> em vez de Consumer<AppProvider>.
    // Apenas este widget reconstrói quando Gemini conecta/desconecta —
    // o restante da ai_screen NÃO é afetado.
    return Consumer<AiChatProvider>(
      builder: (context, aiChat, _) {
        final dark = widget.dark;
        final isEs = _isEs;
        final geminiConn = aiChat.geminiConnected;
        final geminiEmail = aiChat.geminiEmail;
        final geminiLoading = aiChat.geminiLoading;
        final hasAnyAi = aiChat.hasAnyAi;

        final bg = dark ? const Color(0xFF0F1A14) : Colors.white;
        final cardBg = dark ? const Color(0xFF2D3340) : const Color(0xFFF5F7F5);
        final divCol = dark ? Colors.white12 : Colors.black.withOpacity(0.08);
        final sub = dark ? Colors.white54 : Colors.black54;
        final text = dark ? Colors.white : const Color(0xFF1A1D23);
        const green = Color(0xFF10B981);
        const blue = Color(0xFF1A73E8); // cor Google azul

        // BUILD 337-AI-TEXTS: Badge do monitor de servidor
        // Ativo → pílula verde 'Servidor Activo' (Es) / 'Servidor Ativo' (Pt)
        // Offline → pílula vermelha 'Servidor Offline'
        final String badgeLabel;
        if (geminiLoading || widget.keyLoading) {
          badgeLabel = isEs ? 'Conectando...' : 'Conectando...';
        } else if (hasAnyAi) {
          badgeLabel = isEs ? 'Servidor Activo' : 'Servidor Ativo';
        } else {
          badgeLabel = 'Servidor Offline';
        }
        // Cor da pílula: verde quando ativo, vermelho quando offline
        final bool serverActive =
            !geminiLoading && !widget.keyLoading && hasAnyAi;

        // BUILD 337-AI-TEXTS: Linha 1 — cabeçalho unificado de servidor
        // Fixo em todos os estados: descreve a integração do servidor
        const String modeLabel =
            'SERVIDOR MEDCASES IA — INTEGRADO A GOOGLE GEMINI';

        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Drag handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: dark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2)),
            ),

            // ── Card principal — conta + status da IA ────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: hasAnyAi
                      ? [
                          const Color(0xFF064E35),
                          const Color(0xFF1B5E3B),
                          const Color(0xFF10B981)
                        ]
                      : [
                          dark
                              ? const Color(0xFF2D3340)
                              : const Color(0xFFF0F4F1),
                          dark
                              ? const Color(0xFF1E2E22)
                              : const Color(0xFFE8F0EA)
                        ],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SUPER ORDEM MASTER 12 M3: Logo M+ dourado premium substitui avatar de letra/ícone de cérebro
                    Row(children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(13),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF1A1100), Color(0xFF2C1E00)],
                          ),
                          border: Border.all(
                            color: const Color(0xFFD4AF37).withOpacity(0.40),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                                color:
                                    const Color(0xFFD4AF37).withOpacity(0.18),
                                blurRadius: 10,
                                offset: const Offset(0, 3)),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'M+',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFD4AF37), // ouro premium
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.userName.isNotEmpty)
                            Text(widget.userName,
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: hasAnyAi ? Colors.white : text),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          Text(
                              widget.userEmail.isNotEmpty
                                  ? widget.userEmail
                                  : (isEs ? 'Sin cuenta' : 'Sem conta'),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: hasAnyAi
                                      ? Colors.white.withOpacity(0.65)
                                      : sub),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      )),
                      // Badge status
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          // BUILD 337: verde=ativo, vermelho=offline (pílula do monitor)
                          color: (geminiLoading || widget.keyLoading)
                              ? Colors.white.withOpacity(0.08)
                              : (serverActive
                                  ? Colors.white.withOpacity(0.15)
                                  : const Color(0xFFB91C1C).withOpacity(0.18)),
                          border: Border.all(
                              color: (geminiLoading || widget.keyLoading)
                                  ? Colors.white.withOpacity(0.15)
                                  : (serverActive
                                      ? Colors.white.withOpacity(0.3)
                                      : const Color(0xFFEF4444)
                                          .withOpacity(0.40))),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (geminiLoading || widget.keyLoading)
                            SizedBox(
                              width: 8,
                              height: 8,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.2,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            )
                          else
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(right: 5),
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  // Verde quando ativo, vermelho quando offline
                                  color: serverActive
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444)),
                            ),
                          const SizedBox(width: 5),
                          Text(badgeLabel,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: (geminiLoading || widget.keyLoading)
                                      ? Colors.white.withOpacity(0.5)
                                      : (serverActive
                                          ? Colors.white
                                          : const Color(0xFFEF4444)))),
                        ]),
                      ),
                    ]),

                    const SizedBox(height: 16),
                    Divider(
                        color:
                            hasAnyAi ? Colors.white.withOpacity(0.15) : divCol,
                        height: 1),
                    const SizedBox(height: 14),

                    // Linha: modo de operação
                    Row(children: [
                      Icon(Icons.psychology_rounded,
                          size: 14,
                          color:
                              hasAnyAi ? Colors.white.withOpacity(0.7) : sub),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(modeLabel,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: hasAnyAi ? Colors.white : text))),
                    ]),
                    const SizedBox(height: 8),

                    // BUILD 337 Linha 2: +1000 fármacos · modos (acréscimo/fármacos)
                    Row(children: [
                      Icon(Icons.medication_rounded,
                          size: 14,
                          color:
                              hasAnyAi ? Colors.white.withOpacity(0.6) : sub),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(
                              isEs
                                  ? '+1000 FÁRMACOS — MODO ESTUDIO — MODO GUARDIA'
                                  : '+1000 FÁRMACOS — MODO ESTUDO — MODO PLANTÃO',
                              style: TextStyle(
                                  fontSize: 11,
                                  letterSpacing: 0.3,
                                  color: hasAnyAi
                                      ? Colors.white.withOpacity(0.7)
                                      : sub))),
                    ]),

                    // BUILD 337 Linha 3: modelo unificado LLM — sempre visível
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(
                          geminiConn
                              ? Icons.account_circle_rounded
                              : Icons.cloud_done_rounded,
                          size: 14,
                          color: const Color(0xFF10B981).withOpacity(0.8)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(
                              geminiConn && geminiEmail.isNotEmpty
                                  ? geminiEmail
                                  : 'SERVIDOR MEDCASES IA — INTEGRADO AO GOOGLE GEMINI — GPT MINI 4',
                              style: TextStyle(
                                  fontSize: 11,
                                  letterSpacing:
                                      geminiConn && geminiEmail.isNotEmpty
                                          ? 0.0
                                          : 0.2,
                                  color: hasAnyAi
                                      ? Colors.white.withOpacity(0.65)
                                      : sub),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)),
                    ]),
                  ]),
            ),

            const SizedBox(height: 14),

            // ── Botão principal: Conectar com Google / Desconectar ────────
            if (geminiConn)
              // Conectado — mostra email + botão desconectar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFF1A73E8).withOpacity(0.25)),
                ),
                child: Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: blue.withOpacity(0.12),
                    ),
                    child: const Center(
                      child: Icon(Icons.account_circle_rounded,
                          color: blue, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isEs ? 'Google conectado' : 'Google conectado',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: text)),
                      if (geminiEmail.isNotEmpty)
                        Text(geminiEmail,
                            style: TextStyle(fontSize: 11, color: sub),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                    ],
                  )),
                  GestureDetector(
                    onTap: geminiLoading ? null : _handleGoogleDisconnect,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: const Color(0xFFB91C1C).withOpacity(0.1),
                        border: Border.all(
                            color: const Color(0xFFB91C1C).withOpacity(0.25)),
                      ),
                      child: geminiLoading
                          ? SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: const Color(0xFFEF4444).withOpacity(0.7),
                              ),
                            )
                          : Text(isEs ? 'Desconectar' : 'Desconectar',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFEF4444))),
                    ),
                  ),
                ]),
              )
            else
              // Não conectado — botão proeminente "Conectar com Google"
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: geminiLoading ? null : _handleGoogleConnect,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: blue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: blue.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      elevation: 0),
                  child: geminiLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.account_circle_rounded, size: 20),
                            const SizedBox(width: 8),
                            // BUILD 337: botão de gatilho OAuth — texto canônico
                            Text('Conectar con Google ➔ IA Clínica',
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700)),
                          ],
                        ),
                ),
              ),

            const SizedBox(height: 2),

            // BUILD 337: subtexto do botão OAuth
            // '3 clics · usa tu propria cuenta Google' — sem mencionar clave API
            if (!geminiConn)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 4),
                child: Text('3 clics · usa tu propria cuenta Google',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11, color: sub, fontWeight: FontWeight.w500)),
              ),

            const SizedBox(height: 14),

            // ── Explicação do modo híbrido ─────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: divCol)),
              // BUILD 337-AI-TEXTS: cards de benefícios — arquitetura de mensagem definitiva
              child: Column(children: [
                // Card 1 — Base clínica ativa (ícone de faísca)
                InfoRow(
                  icon: Icons.auto_awesome_rounded,
                  iconColor: green,
                  dark: dark,
                  label: isEs ? 'Base clínica activa' : 'Base clínica ativa',
                  sub: 'Protocolos e fármacos respondem instantaneamente.',
                ),
                const SizedBox(height: 10),
                // Card 2 — Gemini · GPT enriquece (ícone de hub/IA)
                InfoRow(
                  icon: Icons.hub_rounded,
                  iconColor: hasAnyAi ? green : sub,
                  dark: dark,
                  label: isEs
                      ? 'Gemini · GPT enriquece lo que la base no cubre'
                      : 'Gemini · GPT enriquece o que a base não cobre',
                  sub:
                      'Perguntas fora da base são respondidas com conhecimento médico global.',
                  dimmed: !hasAnyAi,
                ),
              ]),
            ),

            const SizedBox(height: 16),

            // ── Botão fechar ────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                    backgroundColor: green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    elevation: 0),
                child: Text(isEs ? 'Entendido' : 'Entendido',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        );
      },
    );
  }
}
