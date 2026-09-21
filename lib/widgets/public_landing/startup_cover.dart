import 'package:flutter/material.dart';

/// Same visual identity as the app splash, covering the landing iframe load.
class StartupCover extends StatelessWidget {
  const StartupCover({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, size) {
        return ColoredBox(
          color: const Color(0xFF0F1116),
          child: Stack(children: [
            Positioned(
                top: -size.maxHeight * .04,
                right: -70,
                child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0D6B57).withValues(alpha: .055)))),
            Positioned(
                bottom: size.maxHeight * .12,
                left: -50,
                child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0D6B57).withValues(alpha: .035)))),
            Positioned(
                top: size.maxHeight * .27,
                left: 0,
                right: 0,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Image.asset('assets/icon/splash_mplus_premium.png',
                      width: 150, height: 150, fit: BoxFit.contain),
                  const SizedBox(height: 24),
                  const Text('MedCases Pro',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  Text('IA Clínica de bolso',
                      style: TextStyle(
                          fontSize: 12,
                          color: const Color(0xFF0D6B57).withValues(alpha: .85),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.1)),
                ])),
            Positioned(
                bottom: 72,
                left: 0,
                right: 0,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: const Color(0xFF0D6B57).withValues(alpha: .7))),
                  const SizedBox(height: 16),
                  Text('Carregando dados clínicos...',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: .42),
                          letterSpacing: .6)),
                ])),
          ]),
        );
      });
}
