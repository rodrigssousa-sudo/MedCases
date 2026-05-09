import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/brand_mark.dart';

class MaintenanceScreen extends StatelessWidget {
  final String message;

  const MaintenanceScreen({super.key, this.message = ''});

  static const _kDark  = Color(0xFF07110d);
  static const _kGreen = Color(0xFF075f45);
  static const _kGold  = Color(0xFFC5A365);
  static const _kGoldL = Color(0xFFFFE8A6);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Logo ─────────────────────────────────────────────────────
              const BrandMark(small: false),
              const SizedBox(height: 40),

              // ── Ícone de manutenção ───────────────────────────────────────
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kGreen.withValues(alpha: 0.12),
                  border: Border.all(
                    color: _kGold.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.construction_rounded,
                    size: 40,
                    color: _kGold,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // ── Título ────────────────────────────────────────────────────
              const Text(
                'Sistema em Manutenção',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Sistema en Mantenimiento',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.35),
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 28),

              // ── Mensagem customizável (se houver) ────────────────────────
              if (message.trim().isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: _kGreen.withValues(alpha: 0.10),
                    border: Border.all(
                      color: _kGold.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.80),
                      height: 1.55,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ── Mensagem padrão ───────────────────────────────────────────
              if (message.trim().isEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withValues(alpha: 0.04),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Text(
                    'Estamos realizando melhorias no sistema para oferecer uma experiência ainda melhor.\n\nEstamos realizando mejoras en el sistema para ofrecer una mejor experiencia.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.50),
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ── Rodapé ────────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kGold.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Voltamos em breve  ·  Volvemos pronto',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _kGoldL.withValues(alpha: 0.55),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kGold.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 3),

              // ── Botão discreto de logout (para usuários comuns saírem) ───
              GestureDetector(
                onTap: () async => AuthService.logout(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white.withValues(alpha: 0.05),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'Sair / Salir',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
