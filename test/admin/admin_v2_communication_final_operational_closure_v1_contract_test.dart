import 'dart:io';

String exactRuleBlock(String rules, String marker) {
  final lines = rules.split('\n');
  final start = lines.indexWhere((line) => line.contains(marker));
  if (start < 0) {
    throw StateError('Rule block missing: $marker');
  }

  var depth = 0;
  var end = -1;

  for (var i = start; i < lines.length; i++) {
    depth += '{'.allMatches(lines[i]).length;
    depth -= '}'.allMatches(lines[i]).length;

    if (i > start && depth == 0) {
      end = i;
      break;
    }
  }

  if (end < 0) {
    throw StateError('Rule block end missing: $marker');
  }

  return lines.sublist(start, end + 1).join('\n');
}

void main() {
  final admin =
      File('lib/screens/admin_v2/admin_v2_screen.dart').readAsStringSync();
  final rules = File('firestore.rules').readAsStringSync();

  final markReadStart =
      admin.indexOf('Future<void> _markNotificationRead(');
  final markReadEnd =
      admin.indexOf('Future<void> _confirmAndSendPush()', markReadStart);

  if (markReadStart < 0 ||
      markReadEnd < 0 ||
      markReadEnd <= markReadStart) {
    throw StateError('Mark-read owner range invalid');
  }

  final markReadOwner = admin.substring(markReadStart, markReadEnd);
  if (!markReadOwner.contains('if (!_canMutate || _busy) return;')) {
    throw StateError('Mark-read mutation guard missing from owner');
  }

  final requiredAdmin = <String>[
    'ADMIN_V2_COMMUNICATION_FINAL_OPERATIONAL_CLOSURE_V1',
    "'sentBy': widget.currentAdmin.uid",
    "'sentByEmail': widget.currentAdmin.email.toString().trim()",
    "'createdBy': widget.currentAdmin.uid",
    "'createdByEmail': widget.currentAdmin.email.toString().trim()",
    'canMarkRead: _canMutate',
    'final bool canMarkRead;',
    'if (!read && canMarkRead)',
    'if (!_canMutate || _busy) return;',
    'final users = _canMutate',
    '? await _AdminUsersRestLoader.load()',
    ': const <Map<String, dynamic>>[];',
  ];

  for (final token in requiredAdmin) {
    if (!admin.contains(token)) {
      throw StateError('Missing Communication Admin token: $token');
    }
  }

  final emailjs = exactRuleBlock(
    rules,
    'match /app_config/emailjs {',
  );
  final emails = exactRuleBlock(
    rules,
    'match /email_campaigns/{document=**} {',
  );
  final notifications = exactRuleBlock(
    rules,
    'match /admin_notifications/{notificationId} {',
  );
  final push = exactRuleBlock(
    rules,
    'match /global_push_campaigns/{campaignId} {',
  );

  if (!emailjs.contains('allow read: if isAdmin() || isSupervisor();') ||
      !emailjs.contains('allow write: if isMaster();')) {
    throw StateError('EmailJS role contract failed');
  }

  if (!emails.contains('allow read: if isAdmin() || isSupervisor();') ||
      !emails.contains('allow create, update, delete: if isAdmin();')) {
    throw StateError('Email campaigns role contract failed');
  }

  if (!notifications.contains(
        'allow read:   if isAdmin() || isSupervisor();',
      ) ||
      !notifications.contains('allow update: if isAdmin();')) {
    throw StateError('Admin notifications role contract failed');
  }

  if (!push.contains(
        'allow read:   if isAdmin() || isSupervisor();',
      ) ||
      !push.contains(
        "request.resource.data.get('sentBy', '') == request.auth.uid",
      )) {
    throw StateError('Global push role/create contract failed');
  }

  if (emailjs.contains('allow write: if isAdmin();')) {
    throw StateError('EmailJS write still broad');
  }

  print('ADMIN_V2_COMMUNICATION_FINAL_OPERATIONAL_CLOSURE_V1_CONTRACT=PASS');
  print('PUSH_SENTBY_PAYLOAD_RULE_ALIGNMENT=PASS');
  print('SUPERVISOR_COMMUNICATION_READ_ONLY=PASS');
  print('SUPERVISOR_NOTIFICATION_MUTATION_BLOCK=PASS');
  print('MARK_READ_ACTIVE_OWNER_GUARD=PASS');
  print('SUPERVISOR_USERS_DIRECTORY_BYPASS=PASS');
  print('EMAILJS_MASTER_WRITE_ENFORCEMENT=PASS');
}
