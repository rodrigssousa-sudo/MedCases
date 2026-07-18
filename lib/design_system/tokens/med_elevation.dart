import 'package:flutter/material.dart';

/// Escala oficial de elevação e sombras do MedCases Next.
abstract final class MedElevation {
  static const List<BoxShadow> none = <BoxShadow>[];

  static const List<BoxShadow> small = <BoxShadow>[
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> medium = <BoxShadow>[
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 10,
      offset: Offset(0, 3),
    ),
  ];

  static const List<BoxShadow> large = <BoxShadow>[
    BoxShadow(
      color: Color(0x24000000),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> overlay = <BoxShadow>[
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
  ];
}
