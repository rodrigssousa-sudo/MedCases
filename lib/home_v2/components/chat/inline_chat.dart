// ============================================================================
// MEDCASES PRO
// HOME V2
// INLINE CHAT — ADAPTADOR OFICIAL DO CHAT REAL
// ============================================================================
//
// Este componente não possui motor, controller, streaming ou persistência
// próprios.
//
// Toda a funcionalidade é delegada ao HomeInlineChat auditado da Home legada,
// que continua sendo a implementação canônica enquanto ocorre a migração
// incremental do frontend.
//
// Os componentes provisórios anteriores permanecem preservados no repositório
// para classificação e eventual remoção em etapa separada e auditada.
// ============================================================================

import 'package:flutter/material.dart';

import '../../../screens/home_screen.dart' show HomeInlineChat;

/// Adaptador público utilizado pela arquitetura Home V2.
///
/// Mantém a Home V2 desacoplada da implementação privada do chat legado,
/// reutilizando integralmente o fluxo real de autenticação, streaming,
/// histórico, persistência e transferência para a tela completa de IA.
class InlineChat extends StatelessWidget {
  const InlineChat({
    required this.dark,
    required this.isEs,
    required this.onNavigateToAi,
    super.key,
  });

  /// Tema visual já resolvido pelo consumidor da Home V2.
  final bool dark;

  /// `true` para espanhol e `false` para português.
  final bool isEs;

  /// Callback oficial do shell para navegar até a aba de IA.
  final ValueChanged<int> onNavigateToAi;

  @override
  Widget build(BuildContext context) {
    return HomeInlineChat(
      dark: dark,
      isEs: isEs,
      onNavigateToAi: onNavigateToAi,
    );
  }
}
