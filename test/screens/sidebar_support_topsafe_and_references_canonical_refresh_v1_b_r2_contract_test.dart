import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const supportPath = 'lib/screens/support_ticket_screen.dart';
  const referencesPath = 'lib/screens/fontes_screen.dart';
  const mainPath = 'lib/main.dart';

  test('support safe-top patch is display-only and contract remains present',
      () {
    final source = File(supportPath).readAsStringSync();

    expect(source, contains('MEDCASES_SIDEBAR_SUPPORT_TOPSAFE_V1_B_R2'));
    expect(source, contains('MediaQuery.paddingOf(context).top + 12'));

    for (final literal in <String>[
      'Feedback y Soporte',
      'Enviar al soporte',
      'Mis solicitudes',
      'Privacidad:',
    ]) {
      expect(source, contains(literal), reason: literal);
    }

    expect(source, contains('SupportTicketScreen'));
    expect(source, contains('SafeArea('));
  });

  test('references screen uses canonical MedCases 2026 presentation', () {
    final source = File(referencesPath).readAsStringSync();

    expect(
      source,
      contains('MEDCASES_SIDEBAR_REFERENCES_CANONICAL_REFRESH_V1_B_R2'),
    );
    expect(source, contains('class FontesScreen extends StatefulWidget'));
    expect(source, contains('this.routeContext'));
    expect(source, contains('required this.isEs'));
    expect(source, contains('final bool isEs;'));
    expect(source, contains('final isEs = widget.isEs;'));
    expect(source, contains('Color(0xFF009C3B)'));
    expect(source, contains('height: 48'));
    expect(source, contains('width: 36'));
    expect(source, contains('Fuentes y directrices'));
    expect(source, contains('Fontes e diretrizes'));
    expect(source, contains('Base bibliográfica clínica'));
    expect(source, contains('200+ temas clínicos'));
    expect(source, contains('600+ referencias curadas'));
    expect(source, contains('Actualización 2026'));
    expect(source, contains('ChoiceChip('));
    expect(source, contains('TextField('));
    expect(source, contains('launchUrl('));
    expect(source, contains('LaunchMode.externalApplication'));
    expect(source, contains('Icons.open_in_new_rounded'));
    expect(source, contains('SafeArea('));
    expect(source, isNot(contains('bottomNavigationBar:')));
  });

  test('sidebar route and global shell owners remain untouched in main', () {
    final source = File(mainPath).readAsStringSync();

    expect(source, contains('class MainShell extends StatefulWidget'));
    expect(source, contains('class _AppDrawer extends StatefulWidget'));
    expect(source, contains('FontesScreen('));
    expect(source, contains('SupportTicketScreen'));
    expect(source, contains("p.lang == 'es' ? 'Fuentes' : 'Fontes'"));
    expect(source, contains('_LegalBar('));
  });

  test('expanded clinical resolver remains the reference source of truth', () {
    final source = File(
      'lib/screens/ai/widgets/clinical_reference_resolver.dart',
    ).readAsStringSync();

    for (var i = 1; i <= 10; i++) {
      final id = i.toString().padLeft(2, '0');
      expect(source, contains('_top150Batch${id}Domains'));
    }

    for (var i = 11; i <= 30; i++) {
      expect(source, contains('_top200ExpansionBatch${i}Domains'));
    }

    expect(
      File('assets/clinical/clinical_registry_phase24_authoritative270.json')
          .existsSync(),
      isTrue,
    );
  });
}
