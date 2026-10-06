import 'package:flutter/material.dart';
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
  Widget build(BuildContext context) => Consumer<AiChatProvider>(
      builder: (context, ai, _) => ClinicalConnectionPanel(
            dark: widget.dark,
            lang: widget.lang,
            userName: widget.userName,
            userEmail: widget.userEmail,
            googleConnected: ai.geminiConnected,
            googleEmail: ai.geminiEmail,
            loading: ai.geminiLoading || ai.aiKeyLoading,
            serverAvailable: ai.hasAnyAi,
            baseAvailable: context.select<AppProvider, bool>((p) =>
                p.protocolsDB.isNotEmpty || p.drugsDB.isNotEmpty),
            onConnect: _handleGoogleConnect,
            onDisconnect: _handleGoogleDisconnect,
            onClose: () => Navigator.pop(context),
          ));
}

/// Shared product identity; state and OAuth remain owned by existing providers.
class ClinicalConnectionPanel extends StatelessWidget {
  const ClinicalConnectionPanel(
      {super.key,
      required this.dark,
      required this.lang,
      required this.userName,
      required this.userEmail,
      required this.googleConnected,
      required this.googleEmail,
      required this.loading,
      required this.serverAvailable,
      required this.baseAvailable,
      required this.onConnect,
      required this.onDisconnect,
      required this.onClose});
  final bool dark, googleConnected, loading, serverAvailable, baseAvailable;
  final String lang, userName, userEmail, googleEmail;
  final VoidCallback onConnect, onDisconnect, onClose;

  @override
  Widget build(BuildContext context) {
    final es = lang.startsWith('es');
    final text = dark ? const Color(0xffeceff2) : const Color(0xff202830);
    final secondary = dark ? const Color(0xffadb9c7) : const Color(0xff526172);
    final accent = dark ? const Color(0xff7cccb8) : const Color(0xff126c59);
    Widget row(String label, bool available, {String? detail}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(available ? Icons.check_circle_outline : Icons.info_outline,
              size: 20, color: available ? accent : secondary),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: TextStyle(fontSize: 15, height: 1.4, color: text)),
                if (detail != null && detail.isNotEmpty)
                  Text(detail,
                      style: TextStyle(
                          fontSize: 13, height: 1.4, color: secondary))
              ])),
        ]));
    return Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .9),
        decoration: BoxDecoration(
            color: dark ? const Color(0xff1a1d23) : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20))),
        child: SafeArea(
            top: false,
            child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                    24, 20, 24, 20 + MediaQuery.viewInsetsOf(context).bottom),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('MedCases Clinical',
                          style: TextStyle(
                              fontSize: 23,
                              height: 1.22,
                              fontWeight: FontWeight.w700,
                              color: text)),
                      const SizedBox(height: 20),
                      Text(
                          userEmail.isEmpty
                              ? (es
                                  ? 'Cuenta no conectada'
                                  : 'Conta não conectada')
                              : (es ? 'Cuenta conectada' : 'Conta conectada'),
                          style: TextStyle(fontSize: 13, color: secondary)),
                      if (userName.isNotEmpty)
                        Text(userName,
                            style: TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                fontWeight: FontWeight.w600,
                                color: text)),
                      if (userEmail.isNotEmpty)
                        Text(userEmail,
                            style: TextStyle(
                                fontSize: 14, height: 1.5, color: secondary)),
                      const SizedBox(height: 16),
                      Divider(color: secondary.withValues(alpha: .22)),
                      row(
                          loading
                              ? (es ? 'Conectando…' : 'Conectando…')
                              : serverAvailable
                                  ? (es ? 'Servidor activo' : 'Servidor ativo')
                                  : (es
                                      ? 'Servidor no disponible'
                                      : 'Servidor indisponível'),
                          serverAvailable && !loading),
                      row(
                          googleConnected
                              ? 'Google conectado'
                              : (es
                                  ? 'Google no conectado'
                                  : 'Google não conectado'),
                          googleConnected,
                          detail: googleConnected ? googleEmail : null),
                      Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                              onPressed: loading
                                  ? null
                                  : googleConnected
                                      ? onDisconnect
                                      : onConnect,
                              style: TextButton.styleFrom(
                                  foregroundColor: accent,
                                  minimumSize: const Size(48, 48)),
                              child: Text(googleConnected
                                  ? 'Desconectar'
                                  : es
                                      ? 'Conectar con Google'
                                      : 'Conectar com Google'))),
                      row(
                          baseAvailable
                              ? (es
                                  ? 'Base clínica disponible'
                                  : 'Base clínica disponível')
                              : (es
                                  ? 'Base clínica no disponible'
                                  : 'Base clínica indisponível'),
                          baseAvailable),
                      Divider(color: secondary.withValues(alpha: .22)),
                      const SizedBox(height: 12),
                      Text(es ? 'Cobertura' : 'Cobertura',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: text)),
                      const SizedBox(height: 6),
                      Text(
                          es
                              ? 'Base de fármacos · Modo Guardia · Modo Estudio'
                              : 'Base de fármacos · Modo Plantão · Modo Estudo',
                          style: TextStyle(
                              fontSize: 14, height: 1.5, color: secondary)),
                      const SizedBox(height: 14),
                      Text(
                          es
                              ? 'MedCases Clinical combina la base MedCases con modelos de IA para ampliar las respuestas cuando es necesario.'
                              : 'O MedCases Clinical combina a base MedCases com modelos de IA para ampliar respostas quando necessário.',
                          style: TextStyle(
                              fontSize: 14, height: 1.5, color: secondary)),
                      const SizedBox(height: 20),
                      FilledButton(
                          onPressed: onClose,
                          style: FilledButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor:
                                  dark ? const Color(0xff14201e) : Colors.white,
                              minimumSize: const Size(48, 48)),
                          child: const Text('Entendido')),
                    ]))));
  }
}
