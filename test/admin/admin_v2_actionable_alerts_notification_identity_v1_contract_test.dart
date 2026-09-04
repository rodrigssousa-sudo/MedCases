import 'dart:io';

void main() {
  final admin =
      File('lib/screens/admin_v2/admin_v2_screen.dart').readAsStringSync();
  final functions =
      File('functions/index.js').readAsStringSync();

  final requiredAdminTokens = <String>[
    'ADMIN_V2_ACTIONABLE_ALERTS_NOTIFICATION_IDENTITY_V1',
    'Isto não é uma falha do sistema.',
    'Como resolver: abra Comunicação > Notificações',
    r'Onde resolver: ${alert.sourceLabel}',
    'Novo usuário cadastrado',
    "row['userName']",
    "row['userEmail']",
    "row['userProfession']",
    "row['userInstitution']",
    'if (!read && canMarkRead)',
    "sourceLabel: 'Comunicação > Notificações'",
    "sourceLabel: 'Erros > Críticos'",
    "sourceLabel: 'Comunicação > Push global'",
    "sourceLabel: 'Comunicação > E-mail'",
    "sourceLabel: 'Configurações > Sistema'",
  ];

  for (final token in requiredAdminTokens) {
    if (!admin.contains(token)) {
      throw StateError('Missing actionable UX token: $token');
    }
  }

  final requiredBackendTokens = <String>[
    "type:            'new_user'",
    'userName',
    'userEmail',
    'userProfession',
    'userInstitution',
    'userStatus',
  ];

  for (final token in requiredBackendTokens) {
    if (!functions.contains(token)) {
      throw StateError('Missing notification backend field: $token');
    }
  }

  if (admin.contains(
    "title: '\$unread notificação(ões) administrativa(s) não lida(s)'",
  )) {
    throw StateError('Old ambiguous unread-alert copy still present');
  }

  if (admin.contains('Operações atuais')) {
    throw StateError('Legacy sidebar entry regressed');
  }

  print(
    'ADMIN_V2_ACTIONABLE_ALERTS_NOTIFICATION_IDENTITY_V1_CONTRACT=PASS',
  );
  print('AUDIT_ALERT_MEANING=PASS');
  print('AUDIT_RESOLUTION_GUIDANCE=PASS');
  print('NEW_USER_NAME_EMAIL=PASS');
  print('BACKEND_NOTIFICATION_FIELDS_REUSED=PASS');
}
