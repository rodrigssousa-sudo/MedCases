import 'dart:io';

void main() {
  final admin =
      File('lib/screens/admin_v2/admin_v2_screen.dart').readAsStringSync();
  final model =
      File('lib/models/user_model.dart').readAsStringSync();
  final rules =
      File('firestore.rules').readAsStringSync();

  for (final token in <String>[
    'ADMIN_V2_SUPERVISOR_LOGIN_SAFE_SURFACE_FIX_V1',
    'if (!admin.isAdmin && !admin.isSupervisor)',
    'Supervisor/Admin/Master',
    'widget.currentAdmin.isSupervisor',
    'for (final item in currentAdmin.isSupervisor',
    'item.\$1 == _AdminSection.errors',
    'item.\$1 == _AdminSection.communication',
    'item.\$1 == _AdminSection.settings',
    "'SUPERVISOR'",
  ]) {
    if (!admin.contains(token)) {
      throw StateError('Missing Supervisor contract: $token');
    }
  }

  for (final token in <String>[
    "(_AdminSection.dashboard, Icons.dashboard_outlined, 'Dashboard')",
    "(_AdminSection.users, Icons.group_outlined, 'Usuários')",
    "(_AdminSection.subscriptions, Icons.credit_card_outlined, 'Assinaturas')",
    "(_AdminSection.aiCosts, Icons.auto_awesome_outlined, 'IA & Custos')",
    "(_AdminSection.errors, Icons.monitor_heart_outlined, 'Erros')",
    "(_AdminSection.content, Icons.menu_book_outlined, 'Conteúdo')",
    "(_AdminSection.communication, Icons.campaign_outlined, 'Comunicação')",
    "(_AdminSection.audit, Icons.fact_check_outlined, 'Auditoria')",
    "(_AdminSection.settings, Icons.settings_outlined, 'Configurações')",
  ]) {
    if (!admin.contains(token)) {
      throw StateError('Original Admin/Master nav lost: $token');
    }
  }

  if (!model.contains(
    'bool get isAdmin     => role == UserRole.admin || role == UserRole.master;',
  )) {
    throw StateError('UserModel isAdmin changed');
  }
  if (!model.contains(
    'bool get isSupervisor => role == UserRole.supervisor;',
  )) {
    throw StateError('Supervisor getter missing');
  }
  if (!rules.contains('allow read: if isAdmin() || isSupervisor();')) {
    throw StateError('Supervisor read contract missing');
  }
  if (admin.contains('Operações atuais')) {
    throw StateError('Legacy navigation regressed');
  }

  print('ADMIN_V2_SUPERVISOR_LOGIN_SAFE_SURFACE_FIX_V1_CONTRACT=PASS');
  print('SUPERVISOR_LOGIN_ALLOWED=PASS');
  print('SUPERVISOR_SURFACE_LIMITED=PASS');
  print('ADMIN_MASTER_ORIGINAL_NAV_PRESERVED=PASS');
  print('SUPERVISOR_ROLE_MODEL_UNCHANGED=PASS');
  print('SUPERVISOR_RULES_PRESERVED=PASS');
}
