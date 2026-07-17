import 'package:flutter/material.dart';

class AiErrorBanner extends StatelessWidget {
  final String lang;
  final bool isGeminiError;
  final VoidCallback onFix;

  const AiErrorBanner({
    super.key,
    required this.lang,
    required this.isGeminiError,
    required this.onFix,
  });

  @override
  Widget build(BuildContext context) {
    final isEs = lang == 'es';

    final String message;
    if (isGeminiError) {
      message = isEs
          ? 'Sesión Google expirada — toca para reconectar'
          : 'Sessão Google expirada — toque para reconectar';
    } else {
      message = isEs
          ? 'Clave API inválida — toca para configurar'
          : 'Chave API inválida — toque para configurar';
    }

    return GestureDetector(
      onTap: onFix,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: const Color(0xFFB91C1C).withValues(alpha: 0.12),
        child: Row(
          children: [
            Icon(
              isGeminiError
                  ? Icons.account_circle_outlined
                  : Icons.error_outline_rounded,
              color: const Color(0xFFEF4444),
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFEF4444),
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFEF4444),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
