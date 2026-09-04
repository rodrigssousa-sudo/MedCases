import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/library_screen.dart').readAsStringSync();
  });

  test('Guide search remains guide-only and aligned to title row', () {
    expect(source, contains('GUIDE_SEARCH_EXACT_TITLE_ROW_GUIDE_ONLY'));
    expect(
      source,
      matches(
        RegExp(
          r'if \(isGuide\)\s*Positioned\(\s*'
          r'// GUIDE_SEARCH_EXACT_TITLE_ROW_GUIDE_ONLY\s*'
          r'top: topbarContentTop,\s*'
          r'right: 8,\s*'
          r'height: topbarHeight,',
        ),
      ),
    );
    expect(source, matches(RegExp(r'Icons\.search_rounded,\s*size:\s*30')));
    expect(source, contains('onPressed: _showGuidePortalSearch'));
  });

  test('Guide topbar Liquid Glass belongs to _LibraryTopbarBg only', () {
    expect(source, contains('GUIDE_PORTAL_NO_GLOBAL_GLASS_V1_B_R1'));
    expect(source, isNot(contains('GUIDE_CLINICAL_TOPBAR_LIQUID_GLASS')));

    final start = source.indexOf('class _LibraryTopbarBg');
    final end = source.indexOf('class _LibraryTopbarContent', start);
    expect(start, isNonNegative);
    expect(end, greaterThan(start));

    final bg = source.substring(start, end);

    expect(bg, contains('MEDCASES_GUIA_CLINICO_TRUE_LIQUID_GLASS_V1_B_R1'));
    expect(
      bg,
      matches(
        RegExp(r'ImageFilter\.blur\(\s*sigmaX:\s*16,\s*sigmaY:\s*16\s*\)'),
      ),
    );
    expect(bg, contains('blurRadius: 14'));
    expect(bg, contains('spreadRadius: -8'));
    expect(bg, contains('width: 0.7'));
    expect(bg, contains('liquidSpecular'));
  });

  test('Simulation branch remains its previous blur-14 contract', () {
    final classStart = source.indexOf('class _LibraryTopbarBg');
    final guideStart = source.indexOf(
      'MEDCASES_GUIA_CLINICO_TRUE_LIQUID_GLASS_V1_B_R1',
      classStart,
    );
    expect(classStart, isNonNegative);
    expect(guideStart, greaterThan(classStart));

    // Scope starts at the class owner, BEFORE if (flatSimulation).
    final simulationOwner = source.substring(classStart, guideStart);

    expect(simulationOwner, contains('if (flatSimulation)'));
    expect(simulationOwner, contains('MEDCASES_SIMULACAO_HOME_TOPBAR_V1_B_R0'));
    expect(
      simulationOwner,
      matches(
        RegExp(r'ImageFilter\.blur\(\s*sigmaX:\s*14,\s*sigmaY:\s*14\s*\)'),
      ),
    );
    expect(
      simulationOwner,
      contains('const Color(0xFF252930).withOpacity(0.70)'),
    );
    expect(simulationOwner, contains('const Color(0xFFE2E7EC)'));
  });

  test('Guide title remains bilingual and canonical', () {
    expect(source, contains("'GUÍA CLÍNICA'"));
    expect(source, contains("'GUIA CLÍNICO'"));
    expect(source, contains('canonicalHomeStyle: true'));
    expect(source, contains('fontSize: canonicalHomeStyle ? 16 : 20'));
    expect(source, contains('FontWeight.w900'));
    expect(source, contains('letterSpacing: canonicalHomeStyle ? 1.2 : 0.4'));
  });

  test('Portal search pagination and native bridge remain intact', () {
    expect(source, contains('class _GuidePortalSearchDelegate'));
    expect(source, contains('Future<void> _loadMoreGuides()'));
    expect(source, contains('NotificationListener<ScrollNotification>'));
    expect(source, contains('scrollDirection: Axis.horizontal'));
    expect(source, contains('ClinicalGuidesEditorialService.loadById(g.id)'));
    expect(source, contains('_openPdf(g);'));
  });
}
