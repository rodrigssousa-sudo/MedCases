import 'package:flutter/material.dart';

class BrandMark extends StatelessWidget {
  final bool small;
  const BrandMark({super.key, this.small = false});

  @override
  Widget build(BuildContext context) {
    final size = small ? 36.0 : 48.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(small ? 10.0 : 14.0),
      child: Image.asset(
        'assets/icon/app_icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _Fallback(small: small),
      ),
    );
  }
}

// Fallback caso a imagem não carregue
class _Fallback extends StatelessWidget {
  final bool small;
  const _Fallback({required this.small});

  @override
  Widget build(BuildContext context) {
    final size = small ? 36.0 : 48.0;
    final fontSize = small ? 11.0 : 13.0;
    final borderRadius = small ? 10.0 : 14.0;
    final innerRadius = small ? 7.0 : 10.0;
    final margin = small ? 5.0 : 6.0;

    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF07110d), Color(0xFF075f45)],
        ),
      ),
      child: Center(
        child: Container(
          margin: EdgeInsets.all(margin),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(innerRadius),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF07110d), Color(0xFF075f45)],
            ),
          ),
          child: Center(
            child: Text('M+', style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFFFE8A6),
            )),
          ),
        ),
      ),
    );
  }
}
