// MEDCASES_PRODUCTIVE_SECOND_BRAND_BATCH_4A_V2_B_R1_AI_WIDGETS
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Card de desconexão — "IA Desconectada"
// Exibido como overlay centralizado quando a IA não está conectada.
// Some automaticamente ao conectar (isConnected = true).
// ─────────────────────────────────────────────────────────────────────────────
class EmptyChat extends StatelessWidget {
  final bool dark;
  final String lang;
  final bool isConnected;
  final VoidCallback? onConnectApi;
  const EmptyChat({
    super.key,
    required this.dark,
    required this.lang,
    this.isConnected = false,
    this.onConnectApi,
  });

  @override
  Widget build(BuildContext context) {
    // Se a IA já está conectada, o card não é renderizado
    if (isConnected) return const SizedBox.shrink();

    final isEs = lang == 'es';

    // BUILD 283 ORDEM 10.3: WiFi-off icon + "CONECTAR IA" gold — área clicável inteira
    // SUPER ORDEM MASTER 308 M3: CTA visual central elegante
    // Mensagem limpa em tipografia premium — desaparece ao conectar
    return GestureDetector(
      onTap: onConnectApi,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Ícone sutil ──────────────────────────────────────────────
              Icon(
                Icons.lock_outline_rounded,
                size: 36,
                color: const Color(0xFF0D6B57).withValues(alpha: 0.35),
              ),
              const SizedBox(height: 20),

              // ── Mensagem principal ───────────────────────────────────────
              Text(
                isEs
                    ? 'Conecte su cuenta para liberar\nel asistente clínico inteligente.'
                    : 'Conecte a sua conta para liberar\no assistente clínico inteligente.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.62),
                  height: 1.55,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 22),

              // ── CTA toque ────────────────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: const Color(0xFF0D6B57).withValues(alpha: 0.35),
                    width: 1,
                  ),
                  color: const Color(0xFF0D6B57).withValues(alpha: 0.07),
                ),
                child: Text(
                  isEs
                      ? 'Conectar ahora'
                      : 'Conectar agora', // BUILD 334-FORENSE: tradução ES corrigida
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0D6B57),
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
