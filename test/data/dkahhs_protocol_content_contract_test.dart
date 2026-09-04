import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String b(String s, String id) {
  final p = s.indexOf("id: '$id'");
  expect(p, greaterThanOrEqualTo(0));
  final a = s.lastIndexOf('ProtocolModel(', p);
  final n = s.indexOf('\n  ProtocolModel(', p + 1);
  return s.substring(a, n < 0 ? s.length : n);
}

void main() {
  late String p, s;
  setUpAll(() {
    final x = File('lib/data/protocols_database.dart').readAsStringSync();
    p = b(x, 'cad_shh');
    s = b(x, 'cetoacidose_diabetica');
  });
  test('ORR003/017/022 content contract', () {
    for (final x in [p, s]) {
      expect(x, isNot(contains('K+ <3,3')));
      expect(x, isNot(contains('K+ ≥3,3')));
      expect(x, isNot(contains('Meta glicêmica: queda 50–75')));
      expect(x, isNot(contains('Meta glucémica: caída 50–75')));
      expect(x, isNot(contains('Meta: queda glicêmica 50–75')));
      expect(x, isNot(contains('Meta: caída glucémica 50–75')));
      expect(x, isNot(contains('50–75 mg/dL/h')));
      expect(x, isNot(contains('K+ ≥3,5')));
      expect(x, contains('90–120 mg/dL/h'));
      expect(x, contains('AVISO SC'));
      expect(x, contains('NÃO autorada/validada/executável'));
      expect(x, contains('NO autorada/validada/ejecutable'));
    }
  });
  test('post-resolution transition remains separate', () {
    expect(p, contains('Transição segura para insulina SC'));
    expect(s, contains('Transição para insulina SC'));
  });
}
