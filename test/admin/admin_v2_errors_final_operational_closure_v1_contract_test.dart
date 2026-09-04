import 'dart:io';

void main() {
  final admin =
      File('lib/screens/admin_v2/admin_v2_screen.dart').readAsStringSync();
  final rules = File('firestore.rules').readAsStringSync();

  final requiredAdmin = <String>[
    'ADMIN_V2_ERRORS_FINAL_OPERATIONAL_CLOSURE_V1',
    'return _ErrorsHealthCenterSection(',
    "const allowedStatuses = <String>{'open', 'investigating', 'resolved'};",
    "'Reabrir incidente'",
    "incident.status != 'open'",
    "incident.status != 'investigating'",
    "incident.status != 'resolved'",
    "'resolvedBy':",
    "status == 'resolved' ? widget.currentAdmin.uid : null",
    "'resolvedAt': status == 'resolved' ? DateTime.now() : null",
  ];

  for (final token in requiredAdmin) {
    if (!admin.contains(token)) {
      throw StateError('Missing Admin errors closure token: $token');
    }
  }

  if (admin.contains('class _ErrorsCenter extends StatelessWidget')) {
    throw StateError('Dead legacy _ErrorsCenter still present');
  }

  if (!admin.contains('class _EmptyState extends StatelessWidget')) {
    throw StateError('Shared _EmptyState class was removed');
  }

  if ('class _EmptyState extends StatelessWidget'
      .allMatches(admin)
      .length != 1) {
    throw StateError('Shared _EmptyState class count changed');
  }

  final requiredRules = <String>[
    'ADMIN_V2_ERRORS_FINAL_OPERATIONAL_CLOSURE_V1_RULES',
    'function isSupervisor()',
    'match /admin_incidents/{document=**}',
    'allow read: if isAdmin() || isSupervisor();',
    'allow create, update, delete: if isAdmin();',
  ];

  for (final token in requiredRules) {
    if (!rules.contains(token)) {
      throw StateError('Missing errors role rules token: $token');
    }
  }

  final ruleLines = rules.split('\n');
  final incidentStart = ruleLines.indexWhere(
    (line) => line.contains('match /admin_incidents/{document=**} {'),
  );

  if (incidentStart < 0) {
    throw StateError('admin_incidents rules block start missing');
  }

  var depth = 0;
  var incidentEnd = -1;

  for (var i = incidentStart; i < ruleLines.length; i++) {
    final line = ruleLines[i];
    depth += '{'.allMatches(line).length;
    depth -= '}'.allMatches(line).length;

    if (i > incidentStart && depth == 0) {
      incidentEnd = i;
      break;
    }
  }

  if (incidentEnd < 0) {
    throw StateError('admin_incidents rules block end missing');
  }

  final exactIncidentBlock =
      ruleLines.sublist(incidentStart, incidentEnd + 1).join('\n');

  if (!exactIncidentBlock.contains(
    'allow read: if isAdmin() || isSupervisor();',
  )) {
    throw StateError('Supervisor read contract missing in admin_incidents');
  }

  if (!exactIncidentBlock.contains(
    'allow create, update, delete: if isAdmin();',
  )) {
    throw StateError('Admin mutation contract missing in admin_incidents');
  }

  if (exactIncidentBlock.contains('allow read, write: if isAdmin();')) {
    throw StateError('Old broad incident rule remains inside admin_incidents');
  }

  if (exactIncidentBlock.contains(
    'allow create, update, delete: if isSupervisor();',
  )) {
    throw StateError('Supervisor mutation must remain denied');
  }

  print('ADMIN_V2_ERRORS_FINAL_OPERATIONAL_CLOSURE_V1_CONTRACT=PASS');
  print('REOPEN_UI=PASS');
  print('REOPEN_METADATA_CLEAR=PASS');
  print('STATUS_ALLOWLIST=PASS');
  print('SUPERVISOR_READ_ONLY=PASS');
  print('ADMIN_INCIDENTS_RULE_BLOCK_PARSER=PASS');
  print('LEGACY_ERRORS_CENTER_REMOVED=PASS');
  print('SHARED_EMPTY_STATE_PRESERVED=PASS');
}
