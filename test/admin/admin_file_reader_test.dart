import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/admin/admin_file_reader.dart';

void main() {
  Matcher code(String value) => isA<AdminFileReadException>()
      .having((e) => e.reasonCode, 'reasonCode', value);
  test('web picker stream works without bytes or local path', () async {
    final file = PlatformFile(
        name: 'guide.json',
        size: 4,
        readStream: Stream.fromIterable([
          [1, 2],
          [3, 4]
        ]));
    expect(await AdminFileReader.read(file, maxBytes: 4), [1, 2, 3, 4]);
  });
  test('bytes at allowed limit remain intact', () async {
    final bytes = Uint8List(1024 * 1024);
    expect(
        (await AdminFileReader.read(
                PlatformFile(
                    name: 'large.pdf', size: bytes.length, bytes: bytes),
                maxBytes: bytes.length))
            .length,
        bytes.length);
  });
  test('stream cannot bypass declared size', () async {
    final file = PlatformFile(
        name: 'guide.json',
        size: 1,
        readStream: Stream.fromIterable([
          [1, 2],
          [3, 4]
        ]));
    await expectLater(AdminFileReader.read(file, maxBytes: 3),
        throwsA(code('FILE_TOO_LARGE')));
  });
  test('empty, unavailable, failed streams have bounded reason codes',
      () async {
    await expectLater(
        AdminFileReader.read(
            PlatformFile(name: 'x', size: 0, bytes: Uint8List(0)),
            maxBytes: 8),
        throwsA(code('FILE_EMPTY')));
    await expectLater(
        AdminFileReader.read(PlatformFile(name: 'x', size: 1), maxBytes: 8),
        throwsA(code('FILE_READ_UNAVAILABLE')));
    await expectLater(
        AdminFileReader.read(
            PlatformFile(
                name: 'x',
                size: 1,
                readStream: Stream.error(StateError('private-path'))),
            maxBytes: 8),
        throwsA(code('FILE_READ_FAILED')));
  });
  test('declared oversize rejected before stream consumption', () async {
    var consumed = false;
    Stream<List<int>> data() async* {
      consumed = true;
      yield [1];
    }

    await expectLater(
        AdminFileReader.read(
            PlatformFile(name: 'x', size: 9, readStream: data()),
            maxBytes: 8),
        throwsA(code('FILE_TOO_LARGE')));
    expect(consumed, false);
  });
}
