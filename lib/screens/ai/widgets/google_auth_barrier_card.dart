import 'package:flutter/material.dart';

class GoogleAuthBarrierCard extends StatelessWidget {
  final bool dark;
  final String lang;
  final VoidCallback? onConnect;
  const GoogleAuthBarrierCard({
    super.key,
    required this.dark,
    required this.lang,
    this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final isEs = lang == 'es';
    final cardBg = dark ? const Color(0xFF1E2128) : Colors.white;
    final borderColor =
        dark ? const Color(0xFF2D3340) : const Color(0xFFE5E0D8);
    final titleColor = dark ? Colors.white : const Color(0xFF1A1D23);
    final subtitleColor =
        dark ? Colors.white.withOpacity(0.55) : Colors.black.withOpacity(0.45);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28.0),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(dark ? 0.40 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Google logo icon ─────────────────────────────────────────
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      dark ? const Color(0xFF252930) : const Color(0xFFF5F3EE),
                  border: Border.all(
                    color: borderColor,
                    width: 1.0,
                  ),
                ),
                child: const Center(
                  child: Text(
                    'G',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4285F4), // Google blue
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Headline ─────────────────────────────────────────────────
              Text(
                isEs ? 'Conecta tu cuenta Google' : 'Conecte sua conta Google',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                  letterSpacing: -0.3,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),

              // ── Subtitle / value prop ─────────────────────────────────────
              Text(
                isEs
                    ? 'para activar la Inteligencia Artificial Gratuita'
                    : 'para ativar a Inteligência Artificial Gratuita',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: subtitleColor,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),

              // ── CTA Button ───────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onConnect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4285F4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '🔑',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isEs ? 'Conectar con Google' : 'Conectar com o Google',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
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
