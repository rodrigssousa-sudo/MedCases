import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/screens/tools_patient_import.dart',
  ).readAsStringSync();

  String classSlice(String name) {
    final declaration = RegExp(
      'class\\s+$name\\s+extends\\s+StatelessWidget\\s*\\{',
    ).firstMatch(source);
    expect(declaration, isNotNull, reason: 'Classe ausente: $name');
    final open = source.indexOf('{', declaration!.start);
    var depth = 0;
    for (var index = open; index < source.length; index++) {
      final char = source[index];
      if (char == '{') depth++;
      if (char == '}') depth--;
      if (depth == 0) return source.substring(declaration.start, index + 1);
    }
    fail('Classe sem fechamento: $name');
  }

  test('V1-L-R1-R5 — owner visual real continua sendo _PatientListItem', () {
    final item = classSlice('_PatientListItem');
    expect(item, contains('onTap: onTap'));
    expect(source, contains('onTap: () => widget.onSelected(session)'));
  });

  test('V1-L-R1-R5 — linha é flat e não cria card sobre o bottom sheet', () {
    final item = classSlice('_PatientListItem');
    expect(item, contains('Material('));
    expect(item, contains('InkWell('));
    expect(item, contains('Padding('));
    expect(item, isNot(contains('Card(')));
    expect(item, isNot(contains('BoxDecoration(')));
    expect(item, isNot(contains('Border.all(')));
  });

  test('V1-L-R1-R5 — inicial sai e marcador de gravidade ocupa a esquerda', () {
    final item = classSlice('_PatientListItem');
    expect(item, contains('_explicitSeverityToken()'));
    expect(item, contains('ColoredBox('));
    expect(item, contains('SizedBox(width: 5, height: 48)'));
    expect(item, isNot(contains('final initial =')));
    expect(item, isNot(contains('[0].toUpperCase()')));
  });

  test('V1-L-R1-R5 — pacientes são separados por linha delicada', () {
    expect(source, contains('separatorBuilder: (_, __) => Divider('));
    expect(source, contains('thickness: 0.6'));
    expect(source, contains('color: itemBorder.withOpacity(0.55)'));
  });

  test('V1-L-R1-R5 — raios e ícones elétricos não permanecem', () {
    expect(source, isNot(contains('⚡')));
    for (final token in <String>[
      'Icons.bolt',
      'Icons.flash_on',
      'Icons.electric_bolt',
    ]) {
      expect(source, isNot(contains(token)), reason: token);
    }
  });

  test('V1-L-R1-R5 — sincronização R2-R3 permanece intacta', () {
    expect(
      source,
      contains('InternacionFirestoreService.sessionsStream(uid)'),
    );
    expect(source, contains('_sessions = patientsSessions;'));
    expect(
      source,
      isNot(contains('InternacionFirestoreService.loadAllSessions')),
    );
    expect(
      source,
      contains(
        '[V1-K-R2-R3][TOOLS_PATIENTS] mesma fonte visual de Pacientes',
      ),
    );
  });
}
