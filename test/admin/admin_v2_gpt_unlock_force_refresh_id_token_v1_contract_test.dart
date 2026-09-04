import 'dart:io';

void main() {
  final source = File(
    'lib/screens/admin_v2/admin_v2_screen.dart',
  ).readAsStringSync();

  const helperName = 'callAdminCallable';
  final helperNamePos = source.indexOf(helperName);
  if (helperNamePos < 0) {
    throw StateError('callAdminCallable missing');
  }

  final helperStart = source.lastIndexOf('static ', helperNamePos);
  if (helperStart < 0) {
    throw StateError('callAdminCallable start missing');
  }

  final nextStatic = source.indexOf(
    '\n  static ',
    helperNamePos + helperName.length,
  );
  final helperEnd = nextStatic > helperStart ? nextStatic : source.length;
  final helper = source.substring(helperStart, helperEnd);

  for (final token in <String>[
    'Future<http.Response> send(String legacyBearer) async',
    'GPT_UNLOCK_FORCE_REFRESH_ID_TOKEN_V1',
    'await user.getIdToken(true)',
    "'Authorization': 'Bearer \$bearer'",
    "'data'",
  ]) {
    if (!helper.contains(token)) {
      throw StateError('Missing GPT helper token: $token');
    }
  }

  if (helper.contains('send(String bearer)')) {
    throw StateError('Legacy nested send owner still present');
  }

  if (!source.contains('adminSetGptOperationalState')) {
    throw StateError('GPT callable callsite missing');
  }

  print(
    'ADMIN_V2_GPT_UNLOCK_FORCE_REFRESH_ID_TOKEN_V1_CONTRACT=PASS',
  );
  print('NESTED_SEND_OWNER_SCOPED_CONTRACT=PASS');
}
