import 'dart:io';

void main() {
  final v2 =
      File('lib/screens/admin_v2/admin_v2_screen.dart').readAsStringSync();

  final forbidden = <String>[
    'admin_screen.dart',
    '_openLegacyAdmin',
    'Operações atuais',
    'AdminScreen(currentAdmin:',
    'class _IncidentRow',
    'class _LegacyBridge',
    'class _FoundationSection',
  ];

  for (final token in forbidden) {
    if (v2.contains(token)) {
      throw StateError('Legacy/dead token remains: $token');
    }
  }

  final required = <String>[
    'ADMIN_V2_LEGACY_BRIDGE_FINAL_REMOVAL_V1',
    '_AdminSection.dashboard',
    '_AdminSection.users',
    '_AdminSection.subscriptions',
    '_AdminSection.aiCosts',
    '_AdminSection.errors',
    '_AdminSection.content',
    '_AdminSection.communication',
    '_AdminSection.audit',
    '_AdminSection.settings',
    'AdminClinicalGuideEditorScreen',
    'class _EmptyState extends StatelessWidget',
    'admin_notifications',
    'global_push_campaigns',
    'email_campaigns',
    'admin_incidents',
    'admin_audit_logs',
    'admin_ai_metrics/realtime',
    'app_config/maintenance',
    'app_updates/current',
  ];

  for (final token in required) {
    if (!v2.contains(token)) {
      throw StateError('Required Admin V2 owner lost: $token');
    }
  }

  print('ADMIN_V2_LEGACY_BRIDGE_FINAL_REMOVAL_V1_CONTRACT=PASS');
  print('LEGACY_NAVIGATION_REMOVED=PASS');
  print('LEGACY_IMPORT_REMOVED=PASS');
  print('DEAD_CLASSES_REMOVED=PASS');
  print('V2_FUNCTIONAL_OWNERS_PRESERVED=PASS');
}
