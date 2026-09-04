import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String block(String source, String start, String end) {
  final a = source.indexOf(start);
  final b = source.indexOf(end, a + start.length);
  expect(a, greaterThanOrEqualTo(0), reason: 'start missing: $start');
  expect(b, greaterThan(a), reason: 'end missing: $end');
  return source.substring(a, b);
}

void main() {
  late String source;
  late String detail;
  late String body;
  late String sectionShell;

  setUpAll(() {
    source = File('lib/screens/protocols_screen.dart').readAsStringSync();
    detail = block(
      source,
      'class _SimulationProtocolDetailPage extends StatelessWidget {',
      '// MEDCASES_SIMULATION_REFS_EVIDENCE_FLAT_COLLAPSIBLE_V1_B_R0',
    );
    body = detail
        .substring(detail.indexOf('        body: SingleChildScrollView('));
    sectionShell = block(
      source,
      'class _SimulationFlatSectionShell extends StatelessWidget {',
      'class _SimulationFlatTextSection extends StatelessWidget {',
    );
  });

  group('Simulation detail flat clinical reading V1-B-R9', () {
    test('keeps canonical route and 48px glass topbar', () {
      expect(
          source, contains('MEDCASES_SIMULATION_FULL_PAGE_NAVIGATION_V1_B_R0'));
      expect(source, contains('openSimulationProtocolPage('));
      expect(detail, contains('Size.fromHeight(48)'));
      expect(detail, contains('ImageFilter.blur(sigmaX: 14, sigmaY: 14)'));
      expect(detail, contains('BorderSide(color: topbarDivider, width: 0.7)'));
      expect('pageTitle,'.allMatches(detail).length, 1);
    });

    test('removes the giant nested surface and opens the reading width', () {
      expect(
        source,
        contains('MEDCASES_SIMULATION_DETAIL_FLAT_CLINICAL_READING_V1_B_R9'),
      );
      expect(
        body,
        contains('MEDCASES_SIMULATION_DETAIL_FLAT_CANVAS_V1_B_R9'),
      );
      expect(body, contains('EdgeInsets.fromLTRB(16, 8, 16, 100)'));
      expect(
        body,
        isNot(contains('MEDCASES_SIMULATION_CASE_SINGLE_SURFACE_CARD_V1_B_R0')),
      );
      expect(body, isNot(contains('EdgeInsets.fromLTRB(16, 14, 16, 18)')));
      expect(body, isNot(contains('BorderRadius.circular(6)')));
      expect(body, isNot(contains('Border.all(')));
    });

    test('uses a compact bilingual clinical reading header', () {
      expect(
        body,
        contains('MEDCASES_SIMULATION_DETAIL_READING_HEADER_V1_B_R9'),
      );
      expect(body, contains("'LECTURA CLÍNICA COMPLETA'"));
      expect(body, contains("'LEITURA CLÍNICA COMPLETA'"));
      expect(body, contains("'Reconoce • Decide • Revisa'"));
      expect(body, contains("'Reconheça • Decida • Revise'"));
      expect(body, contains('Icons.route_outlined'));
      expect(body, contains('width: 44'));
      expect(body, contains('height: 44'));
      expect(body, contains('p.toggleFavProtocol(protocol.id)'));
    });

    test('section hierarchy is neutral while accents remain functional', () {
      expect(sectionShell, contains('EdgeInsets.fromLTRB(0, 12, 0, 14)'));
      expect(sectionShell, contains('Icon(icon, size: 15, color: accent)'));
      expect(sectionShell, contains('header: true'));
      expect(sectionShell, contains('fontSize: 11'));
      expect(sectionShell, contains('color: sectionTitle'));
      expect(sectionShell, contains('BorderSide(color: divider, width: 0.55)'));
      expect(sectionShell, isNot(contains('Border.all(')));
      expect(sectionShell, isNot(contains('LinearGradient(')));
      expect(sectionShell, isNot(contains('BoxShadow(')));
    });

    test('all clinical content evidence and safety contracts stay present', () {
      expect(detail, contains('...visibleClinicalContent'));
      expect(detail, contains('_SimulationReferencesEvidenceDisclosure('));
      expect(detail, contains('protocolReferences: protocolReferences'));
      expect(detail, contains('evidenceRecords: evidenceRecords'));
      expect(detail, contains('const PharmacologicalDisclaimer()'));
      expect(source, contains('_SimulationFlatClassificationSection('));
      expect(source, contains('_SimulationFlatDrugsLinesSection('));
      expect(source, contains('ProtocolChecklistWidget('));
    });
  });
}
