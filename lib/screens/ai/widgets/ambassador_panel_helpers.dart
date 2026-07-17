import 'package:flutter/material.dart';

class AmbassadorSectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const AmbassadorSectionHeader({
    super.key,
    required this.icon,
    required this.label,
  });
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: const Color(0xFFD4AF37), size: 16),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                color: Color(0xFFFFE8A6),
                fontSize: 13,
                fontWeight: FontWeight.w800)),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 0.5, color: const Color(0x44D4AF37))),
      ]);
}

class AmbassadorGoldButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const AmbassadorGoldButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = const Color(0xFFD4AF37),
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 15),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );
}
