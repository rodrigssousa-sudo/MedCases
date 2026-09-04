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

  if (!admin.contains('Alterações críticas exigem Master.')) {
    throw StateError('Settings UI Master-only copy missing');
  }

  if (!admin.contains('widget.currentAdmin.isMaster')) {
    throw StateError('Settings UI Master guard missing');
  }

  if (!rules.contains('ADMIN_V2_SETTINGS_MASTER_RULE_HARDENING_V1')) {
    throw StateError('Settings Master rule marker missing');
  }

  final maintenance = exactRuleBlock(
    rules,
    'match /app_config/maintenance {',
  );

  final updates = exactRuleBlock(
    rules,
    'match /app_updates/{document=**} {',
  );

  if (!maintenance.contains('allow read: if isAuthed();')) {
    throw StateError('Maintenance read contract changed');
  }

  if (!maintenance.contains('allow write: if isMaster();')) {
    throw StateError('Maintenance Master-only write missing');
  }

  if (maintenance.contains('allow write: if isAdmin();')) {
    throw StateError('Maintenance Admin write still allowed');
  }

  if (!updates.contains('allow read: if true;')) {
    throw StateError('App updates public read contract changed');
  }

  if (!updates.contains('allow write: if isMaster();')) {
    throw StateError('App updates Master-only write missing');
  }

  if (updates.contains('allow write: if isAdmin();')) {
    throw StateError('App updates Admin write still allowed');
  }

  print('ADMIN_V2_SETTINGS_MASTER_RULE_HARDENING_V1_CONTRACT=PASS');
  print('SETTINGS_UI_RULE_ROLE_PARITY=PASS');
  print('MAINTENANCE_MASTER_WRITE_ONLY=PASS');
  print('APP_UPDATES_MASTER_WRITE_ONLY=PASS');
  print('READ_CONTRACTS_PRESERVED=PASS');
}
