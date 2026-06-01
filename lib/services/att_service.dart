// att_service.dart — App Tracking Transparency (Apple Guideline 5.1.2)
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  GUIA DE IMPLEMENTAÇÃO COMPLETO — ATT no MedCases Pro                  ║
// ╠══════════════════════════════════════════════════════════════════════════╣
// ║  1. ADICIONAR DEPENDÊNCIA ao pubspec.yaml:                             ║
// ║     app_tracking_transparency: ^3.0.6                                  ║
// ║                                                                        ║
// ║  2. DESCOMENTAR o código desta classe após instalar o pacote.          ║
// ║                                                                        ║
// ║  3. CHAMAR AttService.requestIfNeeded() em main() ANTES do runApp(),  ║
// ║     OU logo após o primeiro login do usuário (melhor UX).             ║
// ║                                                                        ║
// ║  4. NSUserTrackingUsageDescription JÁ ADICIONADA em:                  ║
// ║     • ios/Runner/Info.plist                                            ║
// ║     • ios/Runner/pt-BR.lproj/InfoPlist.strings                        ║
// ╚══════════════════════════════════════════════════════════════════════════╝
//
// CONTEXTO LEGAL:
//   • iOS 14.5+ exige o pop-up ATT antes de coletar o IDFA do dispositivo.
//   • Firebase Analytics coleta um identificador anônimo — tecnicamente não
//     é o IDFA, mas a Apple aplica ATT de forma ampla para qualquer coleta
//     de dados de uso que possa ser vinculada ao usuário através de apps.
//   • Para MedCases Pro (app médico B2B), o risco de rejeição sem ATT é
//     MÉDIO — especialmente se Firebase Analytics ou Crashlytics estiverem
//     ativos e o Apple reviewer notar identificadores sendo enviados.
//   • RECOMENDAÇÃO: ativar ATT se usar Firebase Analytics; opcional se só
//     usar Firebase Auth + Firestore sem Analytics.
//
// FLUXO CORRETO DE UX (Apple Best Practices):
//   1. Mostrar PRIMEIRO uma tela "pré-ATT" explicando o motivo (PreAttSheet)
//   2. Só então chamar requestTrackingAuthorization() para o pop-up nativo
//   3. Aceito → Firebase Analytics permanece ativo
//   4. Negado → desabilitar Firebase Analytics (não rastrear)
//
// ESTADOS POSSÍVEIS:
//   • notDetermined  → ainda não pediu (primeira vez)
//   • authorized     → usuário aceitou → Analytics ativo
//   • denied         → usuário recusou → Analytics desabilitado
//   • restricted     → MDM/parental controls bloqueou
//   • limited        → iOS 15+ modo limitado

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── INSTRUÇÃO: Adicione app_tracking_transparency ao pubspec.yaml e ───────────
// descomente os imports abaixo depois de rodar `flutter pub get`:
//
// import 'package:app_tracking_transparency/app_tracking_transparency.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ATT SERVICE — lógica principal
// ═══════════════════════════════════════════════════════════════════════════
class AttService {
  static const _kAttAsked = 'att_permission_asked_v1';

  // ── Ponto de entrada principal ──────────────────────────────────────────
  // Chame este método UMA vez no boot do app, após o primeiro login.
  // Exibe a PreAttSheet antes do pop-up nativo do iOS.
  //
  // Uso em main.dart:
  //   // No _MainShellState.initState() após autenticação bem-sucedida:
  //   if (!kIsWeb && Platform.isIOS) {
  //     WidgetsBinding.instance.addPostFrameCallback((_) async {
  //       await AttService.requestIfNeeded(context, lang: p.lang);
  //     });
  //   }
  static Future<void> requestIfNeeded(
    BuildContext context, {
    String lang = 'pt',
  }) async {
    // Não faz nada em Web ou Android
    if (kIsWeb || !Platform.isIOS) return;

    // Verifica se já foi pedido antes (evita mostrar duas vezes)
    final prefs = await SharedPreferences.getInstance();
    final alreadyAsked = prefs.getBool(_kAttAsked) ?? false;
    if (alreadyAsked) return;

    // ── PASSO 1: Verifica o status atual sem perguntar ainda ──────────────
    // Se já tiver status (ex: usuario resetou o sistema), não precisa de
    // pré-tela — vai direto para a lógica de analytics.
    //
    // INSTRUÇÃO: Descomente após instalar app_tracking_transparency:
    //
    // final initialStatus = await AppTrackingTransparency.trackingAuthorizationStatus;
    // if (initialStatus != TrackingStatus.notDetermined) {
    //   await prefs.setBool(_kAttAsked, true);
    //   _applyAnalyticsConsent(initialStatus == TrackingStatus.authorized);
    //   return;
    // }

    // ── PASSO 2: Exibe a PreAttSheet (tela explicativa antes do pop-up) ──
    if (!context.mounted) return;
    final shouldRequest = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => PreAttSheet(lang: lang),
        ) ??
        false;

    if (!shouldRequest) {
      // Usuário fechou sem confirmar — agenda para próximo boot
      return;
    }

    // ── PASSO 3: Pop-up nativo do iOS ─────────────────────────────────────
    await prefs.setBool(_kAttAsked, true);

    // INSTRUÇÃO: Descomente após instalar app_tracking_transparency:
    //
    // // Pequeno delay para o sheet fechar antes do pop-up nativo aparecer
    // await Future.delayed(const Duration(milliseconds: 300));
    // final status = await AppTrackingTransparency.requestTrackingAuthorization();
    // _applyAnalyticsConsent(status == TrackingStatus.authorized);

    // PLACEHOLDER: sem o pacote, apenas registra que foi pedido
    debugPrint('[ATT] Pop-up nativo seria exibido aqui. '
        'Instale app_tracking_transparency e descomente o código.');
  }

  // ── Aplica o consentimento ao Firebase Analytics ──────────────────────
  // Quando o usuário RECUSA, desabilitar Analytics evita rejeições futuras
  // e é exigido pelas diretrizes de privacidade da Apple e LGPD.
  //
  // INSTRUÇÃO: Descomente e adapte conforme o pacote Analytics usado:
  //
  // static void _applyAnalyticsConsent(bool authorized) {
  //   if (authorized) {
  //     // Firebase Analytics: habilitar coleta
  //     // FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
  //     debugPrint('[ATT] Analytics AUTORIZADO pelo usuário.');
  //   } else {
  //     // Firebase Analytics: desabilitar coleta
  //     // FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(false);
  //     debugPrint('[ATT] Analytics NEGADO — coleta desabilitada.');
  //   }
  // }

  /// Reseta o flag de "já pediu" (útil para testes em debug).
  static Future<void> resetForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAttAsked);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PRE-ATT SHEET — tela explicativa antes do pop-up nativo
// ═══════════════════════════════════════════════════════════════════════════
// Apple recomenda FORTEMENTE exibir uma tela própria antes do pop-up nativo,
// pois o pop-up nativo é mostrado UMA única vez — se o usuário recusar sem
// entender o motivo, você perde a permissão para sempre.
//
// Esta sheet explica em linguagem acessível:
//   • O que é coletado (dados anônimos de uso, não dados médicos)
//   • Para que serve (melhorar a IA clínica)
//   • O que NÃO é coletado (dados de pacientes, conteúdo de consultas)
// ═══════════════════════════════════════════════════════════════════════════
class PreAttSheet extends StatelessWidget {
  final String lang;
  const PreAttSheet({super.key, this.lang = 'pt'});

  static const Color _kGreen = Color(0xFF0D7A55);

  @override
  Widget build(BuildContext context) {
    final isEs = lang == 'es';
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg   = dark ? const Color(0xFF111B14) : Colors.white;
    final textPrimary   = dark ? Colors.white    : const Color(0xFF0F1C14);
    final textSecondary = dark ? Colors.white70  : const Color(0xFF445555);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 20, top: 8),
              decoration: BoxDecoration(
                color: dark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Ícone
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.bar_chart_rounded,
                color: _kGreen, size: 32),
          ),
          const SizedBox(height: 16),

          // Título
          Text(
            isEs
                ? 'Ayúdanos a mejorar MedCases Pro'
                : 'Ajude-nos a melhorar o MedCases Pro',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // Descrição principal
          Text(
            isEs
                ? 'En la siguiente pantalla, el iOS te preguntará si permites que '
                  'MedCases Pro recopile datos anónimos de uso.'
                : 'Na próxima tela, o iOS perguntará se você permite que o '
                  'MedCases Pro colete dados anônimos de uso.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14, height: 1.5, color: textSecondary),
          ),
          const SizedBox(height: 20),

          // O que coletamos
          _AttBullet(
            icon: Icons.check_circle_outline_rounded,
            iconColor: _kGreen,
            dark: dark,
            text: isEs
                ? 'Módulos mais utilizados (ex: calculadora, protocolos)'
                : 'Módulos mais usados (ex: calculadora, protocolos)',
          ),
          _AttBullet(
            icon: Icons.check_circle_outline_rounded,
            iconColor: _kGreen,
            dark: dark,
            text: isEs
                ? 'Tiempo de respuesta de la IA (para optimizar velocidad)'
                : 'Tempo de resposta da IA (para otimizar velocidade)',
          ),
          const SizedBox(height: 8),

          // O que NÃO coletamos
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF1D4ED8).withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFF1D4ED8).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.security_rounded,
                    color: Color(0xFF1D4ED8), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isEs
                        ? 'Nunca recopilamos datos de pacientes, contenido de '
                          'consultas ni información médica identificable.'
                        : 'Nunca coletamos dados de pacientes, conteúdo de '
                          'consultas ou informações médicas identificáveis.',
                    style: TextStyle(
                      fontSize: 12,
                      color: dark
                          ? const Color(0xFF93C5FD)
                          : const Color(0xFF1D4ED8),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Botões
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(
                      color: dark ? Colors.white24 : Colors.grey[300]!),
                ),
                child: Text(
                  isEs ? 'Ahora no' : 'Agora não',
                  style: TextStyle(
                      color: dark ? Colors.white60 : Colors.grey[600]),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: _kGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  isEs ? 'Continuar' : 'Continuar',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _AttBullet extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final bool     dark;
  final String   text;

  const _AttBullet({
    required this.icon,
    required this.iconColor,
    required this.dark,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: dark ? Colors.white70 : const Color(0xFF445555),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
